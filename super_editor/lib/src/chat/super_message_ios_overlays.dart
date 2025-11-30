import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/src/chat/super_message.dart' show SuperMessageDocumentLayerBuilder;
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/default_editor/document_gestures_touch_ios.dart';
import 'package:super_editor/src/infrastructure/content_layers.dart';
import 'package:super_editor/src/infrastructure/flutter/flutter_scheduler.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/ios_document_controls.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/magnifier.dart';
import 'package:super_editor/src/infrastructure/platforms/mobile_documents.dart';
import 'package:super_editor/src/infrastructure/platforms/platform.dart';
import 'package:super_editor/src/infrastructure/read_only_use_cases.dart';
import 'package:super_editor/src/super_reader/read_only_document_ios_touch_interactor.dart';

/// Adds and removes an iOS-style editor toolbar, as dictated by an ancestor
/// [SuperReaderIosControlsScope].
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
  SuperReaderIosControlsController? _controlsContext;

  @visibleForTesting
  bool get wantsToDisplayToolbar => _controlsContext!.shouldShowToolbar.value;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _controlsContext = SuperReaderIosControlsScope.rootOf(context);

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
        shouldShowToolbar: _controlsContext!.shouldShowToolbar,
        toolbarFocalPoint: _controlsContext!.toolbarFocalPoint,
        floatingToolbarBuilder:
            _controlsContext!.toolbarBuilder ?? widget.defaultToolbarBuilder ?? (_, __, ___) => const SizedBox(),
        createOverlayControlsClipper: _controlsContext!.createOverlayControlsClipper,
        showDebugPaint: false,
      ),
    );
  }
}

/// Adds and removes an iOS-style editor magnifier, as dictated by an ancestor
/// [SuperReaderIosControlsScope].
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
  SuperReaderIosControlsController? _controlsContext;

  @visibleForTesting
  bool get wantsToDisplayMagnifier => _controlsContext!.shouldShowMagnifier.value;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _controlsContext = SuperReaderIosControlsScope.rootOf(context);

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
      valueListenable: _controlsContext!.shouldShowMagnifier,
      builder: (context, shouldShowMagnifier, child) {
        return _controlsContext!.magnifierBuilder != null //
            ? _controlsContext!.magnifierBuilder!(
                context,
                DocumentKeys.magnifier,
                _controlsContext!.magnifierFocalPoint,
                shouldShowMagnifier,
              )
            : _buildDefaultMagnifier(
                context,
                DocumentKeys.magnifier,
                _controlsContext!.magnifierFocalPoint,
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
      handleColor: _controlsContext!.handleColor,
    );
  }
}

/// A [SuperReaderLayerBuilder], which builds a [IosHandlesDocumentLayer],
/// which displays iOS-style handles.
class SuperMessageIosHandlesDocumentLayerBuilder implements SuperMessageDocumentLayerBuilder {
  const SuperMessageIosHandlesDocumentLayerBuilder({
    this.handleColor,
  });

  final Color? handleColor;

  @override
  ContentLayerWidget build(BuildContext context, ReadOnlyContext readerContext) {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return const ContentLayerProxyWidget(child: SizedBox());
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
          SuperReaderIosControlsScope.maybeRootOf(context)?.handleColor ??
          Theme.of(context).primaryColor,
      shouldCaretBlink: ValueNotifier<bool>(false),
    );
  }
}
