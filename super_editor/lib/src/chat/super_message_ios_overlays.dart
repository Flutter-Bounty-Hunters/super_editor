import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    show Theme, TextButton, ColorScheme, Colors, ThemeData, kMinInteractiveDimension, NoSplash, MaterialTapTargetSize;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:overlord/follow_the_leader.dart';
import 'package:overlord/overlord.dart';
import 'package:super_editor/src/chat/super_message.dart' show SuperMessageDocumentLayerBuilder;
import 'package:super_editor/src/chat/super_message_ios_touch_interactor.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/default_editor/document_gestures_touch_ios.dart';
import 'package:super_editor/src/infrastructure/content_layers.dart';
import 'package:super_editor/src/infrastructure/flutter/empty_box.dart';
import 'package:super_editor/src/infrastructure/flutter/flutter_scheduler.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/colors.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/ios_document_controls.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/magnifier.dart';
import 'package:super_editor/src/infrastructure/platforms/mobile_documents.dart';
import 'package:super_editor/src/infrastructure/platforms/platform.dart';
import 'package:super_editor/src/infrastructure/document_context.dart';

/// Adds and removes an iOS-style editor toolbar, as dictated by an ancestor
/// [SuperMessageIosControlsScope].
class SuperMessageIosToolbarOverlayManager extends StatefulWidget {
  const SuperMessageIosToolbarOverlayManager({
    super.key,
    this.tapRegionGroupId,
    this.defaultToolbarBuilder,
    this.child,
  });

  /// {@macro super_reader_tap_region_group_id}
  final String? tapRegionGroupId;

  final DocumentFloatingToolbarBuilder? defaultToolbarBuilder;

  final Widget? child;

  @override
  State<SuperMessageIosToolbarOverlayManager> createState() => SuperMessageIosToolbarOverlayManagerState();
}

@visibleForTesting
class SuperMessageIosToolbarOverlayManagerState extends State<SuperMessageIosToolbarOverlayManager> {
  final OverlayPortalController _overlayPortalController = OverlayPortalController();
  SuperMessageIosControlsController? _controlsController;

  @visibleForTesting
  bool get wantsToDisplayToolbar => _controlsController!.shouldShowToolbar.value;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _controlsController = SuperMessageIosControlsScope.rootOf(context);

    // It's possible that `didChangeDependencies` is called during build when pushing a route
    // that has a delegated transition. We need to wait until the next frame to show the overlay,
    // otherwise this widget crashes, since we can't call `OverlayPortalController.show` during build.
    onNextFrame((timeStamp) {
      _overlayPortalController.show();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child!,
        OverlayPortal(
          controller: _overlayPortalController,
          overlayChildBuilder: _buildToolbar,
          child: const SizedBox(),
        ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return TapRegion(
      groupId: widget.tapRegionGroupId,
      child: IosFloatingToolbarOverlay(
        shouldShowToolbar: _controlsController!.shouldShowToolbar,
        toolbarFocalPoint: _controlsController!.toolbarFocalPoint,
        floatingToolbarBuilder:
            _controlsController!.toolbarBuilder ?? widget.defaultToolbarBuilder ?? (_, __, ___) => const SizedBox(),
        createOverlayControlsClipper: _controlsController!.createOverlayControlsClipper,
        showDebugPaint: false,
      ),
    );
  }
}

/// Adds and removes an iOS-style editor magnifier, as dictated by an ancestor
/// [SuperMessageIosControlsScope].
class SuperMessageIosMagnifierOverlayManager extends StatefulWidget {
  const SuperMessageIosMagnifierOverlayManager({
    super.key,
    this.child,
  });

  final Widget? child;

  @override
  State<SuperMessageIosMagnifierOverlayManager> createState() => SuperMessageIosMagnifierOverlayManagerState();
}

@visibleForTesting
class SuperMessageIosMagnifierOverlayManagerState extends State<SuperMessageIosMagnifierOverlayManager>
    with SingleTickerProviderStateMixin {
  final OverlayPortalController _overlayPortalController = OverlayPortalController();
  SuperMessageIosControlsController? _controlsController;

  @visibleForTesting
  bool get wantsToDisplayMagnifier => _controlsController!.shouldShowMagnifier.value;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _controlsController = SuperMessageIosControlsScope.rootOf(context);

    // It's possible that `didChangeDependencies` is called during build when pushing a route
    // that has a delegated transition. We need to wait until the next frame to show the overlay,
    // otherwise this widget crashes, since we can't call `OverlayPortalController.show` during build.
    onNextFrame((timeStamp) {
      _overlayPortalController.show();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child!,
        OverlayPortal(
          controller: _overlayPortalController,
          overlayChildBuilder: _buildMagnifier,
          child: const SizedBox(),
        ),
      ],
    );
  }

  Widget _buildMagnifier(BuildContext context) {
    // Display a magnifier that tracks a focal point.
    //
    // When the user is dragging an overlay handle, SuperEditor
    // position a Leader with a LeaderLink. This magnifier follows that Leader
    // via the LeaderLink.
    return ValueListenableBuilder(
      valueListenable: _controlsController!.shouldShowMagnifier,
      builder: (context, shouldShowMagnifier, child) {
        return _controlsController!.magnifierBuilder != null //
            ? _controlsController!.magnifierBuilder!(
                context,
                DocumentKeys.magnifier,
                _controlsController!.magnifierFocalPoint,
                shouldShowMagnifier,
              )
            : _buildDefaultMagnifier(
                context,
                DocumentKeys.magnifier,
                _controlsController!.magnifierFocalPoint,
                shouldShowMagnifier,
              );
      },
    );
  }

  Widget _buildDefaultMagnifier(BuildContext context, Key magnifierKey, LeaderLink magnifierFocalPoint, bool visible) {
    if (CurrentPlatform.isWeb) {
      // Defer to the browser to display overlay controls on mobile.
      return const SizedBox();
    }

    return IOSFollowingMagnifier.roundedRectangle(
      magnifierKey: magnifierKey,
      show: visible,
      leaderLink: magnifierFocalPoint,
      // The magnifier is centered with the focal point. Translate it so that it sits
      // above the focal point and leave a few pixels between the bottom of the magnifier
      // and the focal point. This value was chosen empirically.
      offsetFromFocalPoint: Offset(0, (-defaultIosMagnifierSize.height / 2) - 20),
      handleColor: _controlsController!.handleColor,
    );
  }
}

/// A [SuperMessageDocumentLayerBuilder], which builds a [IosHandlesDocumentLayer],
/// which displays iOS-style handles.
class SuperMessageIosHandlesDocumentLayerBuilder implements SuperMessageDocumentLayerBuilder {
  const SuperMessageIosHandlesDocumentLayerBuilder({
    this.handleColor,
  });

  final Color? handleColor;

  @override
  ContentLayerWidget build(BuildContext context, DocumentContext readerContext) {
    if (defaultTargetPlatform != TargetPlatform.iOS || SuperMessageIosControlsScope.maybeNearestOf(context) == null) {
      // There's no controls scope. This probably means SuperEditor is configured with
      // a non-iOS gesture mode. Build nothing.
      return const ContentLayerProxyWidget(child: EmptyBox());
    }

    return IosHandlesDocumentLayer(
      document: readerContext.document,
      documentLayout: readerContext.documentLayout,
      selection: readerContext.composer.selectionNotifier,
      changeSelection: (newSelection, changeType, reason) {
        readerContext.editor.execute([
          ChangeSelectionRequest(
            newSelection,
            changeType,
            reason,
          ),
        ]);
      },
      handleColor: handleColor ??
          SuperMessageIosControlsScope.maybeRootOf(context)?.handleColor ??
          Theme.of(context).primaryColor,
      shouldCaretBlink: ValueNotifier<bool>(false),
    );
  }
}

/// An iOS floating toolbar, which includes standard buttons for [SuperMessage]s.
class DefaultIOSSuperMessageToolbar extends StatelessWidget {
  const DefaultIOSSuperMessageToolbar({
    super.key,
    this.floatingToolbarKey,
    required this.editor,
    required this.messageControlsController,
    required this.focalPoint,
  });

  final Key? floatingToolbarKey;
  final LeaderLink focalPoint;
  final Editor editor;
  final SuperMessageIosControlsController messageControlsController;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: editor.composer.selectionNotifier,
      builder: (context, selection, child) {
        // Note: We have to use a custom toolbar, instead of the official iOS context menu, because
        // in Flutter's infinite wisdom they decided to only support the iOS context menu when there's
        // an open IME connection.
        return _buildToolbar(context);
      },
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Theme(
      data: ThemeData(
        colorScheme: brightness == Brightness.light //
            ? const ColorScheme.light(primary: Colors.black)
            : const ColorScheme.dark(primary: Colors.white),
      ),
      child: CupertinoPopoverToolbar(
        key: floatingToolbarKey,
        focalPoint: LeaderMenuFocalPoint(link: focalPoint),
        elevation: 8.0,
        backgroundColor: brightness == Brightness.dark //
            ? iOSToolbarDarkBackgroundColor
            : iOSToolbarLightBackgroundColor,
        activeButtonTextColor: brightness == Brightness.dark //
            ? iOSToolbarDarkArrowActiveColor
            : iOSToolbarLightArrowActiveColor,
        inactiveButtonTextColor: brightness == Brightness.dark //
            ? iOSToolbarDarkArrowInactiveColor
            : iOSToolbarLightArrowInactiveColor,
        children: [
          _buildButton(
            onPressed: _copy,
            title: 'Copy',
          ),
          _buildButton(
            onPressed: _selectAll,
            title: 'Select All',
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String title,
    required VoidCallback onPressed,
  }) {
    // TODO: Bring this back after its updated to support theming (Overlord #17)
    // return CupertinoPopoverToolbarMenuItem(
    //   label: title,
    //   onPressed: onPressed,
    // );

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(kMinInteractiveDimension, 0),
        padding: EdgeInsets.zero,
        splashFactory: NoSplash.splashFactory,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w300,
          ),
        ),
      ),
    );
  }

  void _copy() {
    final textToCopy = _textInSelection(
      document: editor.document,
      documentSelection: editor.composer.selection!,
    );
    _saveToClipboard(textToCopy);
  }

  void _selectAll() {
    if (editor.document.isEmpty) {
      return;
    }

    editor.execute([
      ChangeSelectionRequest(
        DocumentSelection(
          base: DocumentPosition(
            nodeId: editor.document.first.id,
            nodePosition: editor.document.first.beginningPosition,
          ),
          extent: DocumentPosition(
            nodeId: editor.document.last.id,
            nodePosition: editor.document.last.endPosition,
          ),
        ),
        SelectionChangeType.expandSelection,
        SelectionReason.userInteraction,
      ),
    ]);
  }

  Future<void> _saveToClipboard(String text) {
    return Clipboard.setData(ClipboardData(text: text));
  }

  String _textInSelection({
    required Document document,
    required DocumentSelection documentSelection,
  }) {
    final selectedNodes = document.getNodesInside(
      documentSelection.base,
      documentSelection.extent,
    );

    final buffer = StringBuffer();
    for (int i = 0; i < selectedNodes.length; ++i) {
      final selectedNode = selectedNodes[i];
      dynamic nodeSelection;

      if (i == 0) {
        // This is the first node and it may be partially selected.
        final baseSelectionPosition = selectedNode.id == documentSelection.base.nodeId
            ? documentSelection.base.nodePosition
            : documentSelection.extent.nodePosition;

        final extentSelectionPosition =
            selectedNodes.length > 1 ? selectedNode.endPosition : documentSelection.extent.nodePosition;

        nodeSelection = selectedNode.computeSelection(
          base: baseSelectionPosition,
          extent: extentSelectionPosition,
        );
      } else if (i == selectedNodes.length - 1) {
        // This is the last node and it may be partially selected.
        final nodePosition = selectedNode.id == documentSelection.base.nodeId
            ? documentSelection.base.nodePosition
            : documentSelection.extent.nodePosition;

        nodeSelection = selectedNode.computeSelection(
          base: selectedNode.beginningPosition,
          extent: nodePosition,
        );
      } else {
        // This node is fully selected. Copy the whole thing.
        nodeSelection = selectedNode.computeSelection(
          base: selectedNode.beginningPosition,
          extent: selectedNode.endPosition,
        );
      }

      final nodeContent = selectedNode.copyContent(nodeSelection);
      if (nodeContent != null) {
        buffer.write(nodeContent);
        if (i < selectedNodes.length - 1) {
          buffer.writeln();
        }
      }
    }
    return buffer.toString();
  }
}
