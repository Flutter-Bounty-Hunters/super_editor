import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show Colors, Theme;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:overlord/follow_the_leader.dart';
import 'package:super_editor/src/chat/super_message.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/default_editor/document_gestures_touch_android.dart';
import 'package:super_editor/src/infrastructure/content_layers.dart';
import 'package:super_editor/src/infrastructure/flutter/empty_box.dart';
import 'package:super_editor/src/infrastructure/flutter/flutter_scheduler.dart';
import 'package:super_editor/src/infrastructure/platforms/android/android_document_controls.dart';
import 'package:super_editor/src/infrastructure/platforms/android/drag_handle_selection.dart';
import 'package:super_editor/src/infrastructure/platforms/android/magnifier.dart';
import 'package:super_editor/src/infrastructure/platforms/android/selection_handles.dart';
import 'package:super_editor/src/infrastructure/platforms/android/toolbar.dart';
import 'package:super_editor/src/infrastructure/platforms/mobile_documents.dart';
import 'package:super_editor/src/infrastructure/read_only_use_cases.dart';
import 'package:super_editor/src/infrastructure/touch_controls.dart';

/// Adds and removes an Android-style editor controls overlay, as dictated by an ancestor
/// [SuperEditorAndroidControlsScope].
class SuperMessageAndroidControlsOverlayManager extends StatefulWidget {
  const SuperMessageAndroidControlsOverlayManager({
    super.key,
    this.tapRegionGroupId,
    required this.editor,
    required this.getDocumentLayout,
    this.defaultToolbarBuilder,
    this.showDebugPaint = false,
    this.child,
  });

  /// {@macro super_editor_tap_region_group_id}
  final String? tapRegionGroupId;

  final Editor editor;
  final DocumentLayoutResolver getDocumentLayout;

  final DocumentFloatingToolbarBuilder? defaultToolbarBuilder;

  /// Paints some extra visual ornamentation to help with
  /// debugging, when `true`.
  final bool showDebugPaint;

  final Widget? child;

  @override
  State<SuperMessageAndroidControlsOverlayManager> createState() => SuperMessageAndroidControlsOverlayManagerState();
}

@visibleForTesting
class SuperMessageAndroidControlsOverlayManagerState extends State<SuperMessageAndroidControlsOverlayManager> {
  final _boundsKey = GlobalKey();
  final _overlayController = OverlayPortalController();

  SuperEditorAndroidControlsController? _controlsController;
  late FollowerAligner _toolbarAligner;

  // The type of handle that the user started dragging, e.g., upstream or downstream.
  //
  // The drag handle type varies independently from the drag selection bound.
  HandleType? _dragHandleType;
  AndroidTextFieldDragHandleSelectionStrategy? _dragHandleSelectionStrategy;

  final _dragHandleSelectionGlobalFocalPoint = ValueNotifier<Offset?>(null);
  final _magnifierFocalPoint = ValueNotifier<Offset?>(null);

  late final DocumentHandleGestureDelegate _upstreamHandleGesturesDelegate;
  late final DocumentHandleGestureDelegate _downstreamHandleGesturesDelegate;

  @override
  void initState() {
    super.initState();

    widget.editor.composer.selectionNotifier.addListener(_onSelectionChange);

    _upstreamHandleGesturesDelegate = DocumentHandleGestureDelegate(
      onTap: () {
        // Register tap down to win gesture arena ASAP.
      },
      onPanStart: (details) => _onHandlePanStart(details, HandleType.upstream),
      onPanUpdate: _onHandlePanUpdate,
      onPanEnd: (details) => _onHandlePanEnd(details, HandleType.upstream),
      onPanCancel: () => _onHandlePanCancel(HandleType.upstream),
    );

    _downstreamHandleGesturesDelegate = DocumentHandleGestureDelegate(
      onTap: () {
        // Register tap down to win gesture arena ASAP.
      },
      onPanStart: (details) => _onHandlePanStart(details, HandleType.downstream),
      onPanUpdate: _onHandlePanUpdate,
      onPanEnd: (details) => _onHandlePanEnd(details, HandleType.downstream),
      onPanCancel: () => _onHandlePanCancel(HandleType.downstream),
    );

    onNextFrame((_) {
      // Call `show()` at the end of the frame because calling during a build
      // process blows up.
      _overlayController.show();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _controlsController = SuperEditorAndroidControlsScope.rootOf(context);
    // TODO: Replace CupertinoPopoverToolbarAligner aligner with a generic aligner because this code runs on Android.
    _toolbarAligner = CupertinoPopoverToolbarAligner(
      toolbarVerticalOffsetAbove: 20,
      toolbarVerticalOffsetBelow: 90,
    );
  }

  @override
  void didUpdateWidget(SuperMessageAndroidControlsOverlayManager oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.editor.composer.selectionNotifier != oldWidget.editor.composer.selectionNotifier) {
      oldWidget.editor.composer.selectionNotifier.removeListener(_onSelectionChange);
      widget.editor.composer.selectionNotifier.addListener(_onSelectionChange);
    }
  }

  @override
  void dispose() {
    widget.editor.composer.selectionNotifier.removeListener(_onSelectionChange);
    super.dispose();
  }

  @visibleForTesting
  bool get wantsToDisplayToolbar => _controlsController!.shouldShowToolbar.value;

  @visibleForTesting
  bool get wantsToDisplayMagnifier => _controlsController!.shouldShowMagnifier.value;

  void _onSelectionChange() {
    final selection = widget.editor.composer.selection;
    if (selection == null) {
      return;
    }

    if (selection.isCollapsed &&
        _controlsController!.shouldShowExpandedHandles.value == true &&
        _dragHandleType == null) {
      // The selection is collapsed, but the expanded handles are visible and the user isn't dragging a handle.
      // This can happen when the selection is expanded, and the user deletes the selected text. The only situation
      // where the expanded handles should be visible when the selection is collapsed is when the selection
      // collapses while the user is dragging an expanded handle, which isn't the case here. Hide the handles.
      _controlsController!
        ..hideCollapsedHandle()
        ..hideExpandedHandles()
        ..hideMagnifier()
        ..hideToolbar()
        ..blinkCaret();
    }

    if (!selection.isCollapsed && _controlsController!.shouldShowCollapsedHandle.value == true) {
      // The selection is expanded, but the collapsed handle is visible. This can happen when the
      // selection is collapsed and the user taps the "Select All" button. There isn't any situation
      // where the collapsed handle should be visible when the selection is expanded. Hide the collapsed
      // handle and show the expanded handles.
      _controlsController!
        ..hideCollapsedHandle()
        ..showExpandedHandles()
        ..hideMagnifier();
    }
  }

  void _updateDragHandleSelection(DocumentSelection newSelection, SelectionChangeType changeType) {
    if (newSelection != widget.editor.composer.selection) {
      widget.editor.execute([
        ChangeSelectionRequest(newSelection, changeType, SelectionReason.userInteraction),
      ]);
      HapticFeedback.lightImpact();
    }
  }

  void _onHandlePanStart(DragStartDetails details, HandleType handleType) {
    final selection = widget.editor.composer.selection;
    if (selection == null) {
      throw Exception("Tried to drag a collapsed Android handle when there's no selection.");
    }

    final isSelectionDownstream = selection.hasDownstreamAffinity(widget.editor.document);
    _dragHandleType = handleType;
    late final DocumentPosition selectionBoundPosition;
    if (isSelectionDownstream) {
      selectionBoundPosition = handleType == HandleType.upstream ? selection.base : selection.extent;
    } else {
      selectionBoundPosition = handleType == HandleType.upstream ? selection.extent : selection.base;
    }

    // Find the global offset for the center of the caret as the selection focal point.
    final documentLayout = widget.getDocumentLayout();
    // FIXME: this logic makes sense for selecting characters, but what about images? Does it make sense to set the focal point at the center of the image?
    final centerOfContentAtOffset = documentLayout.getAncestorOffsetFromDocumentOffset(
      documentLayout.getRectForPosition(selectionBoundPosition)!.center,
    );
    _dragHandleSelectionGlobalFocalPoint.value = centerOfContentAtOffset;
    _magnifierFocalPoint.value = centerOfContentAtOffset;

    final selectionType = switch (handleType) {
      HandleType.collapsed => SelectionChangeType.pushCaret,
      HandleType.upstream => SelectionChangeType.expandSelection,
      HandleType.downstream => SelectionChangeType.expandSelection,
    };

    _dragHandleSelectionStrategy = AndroidTextFieldDragHandleSelectionStrategy(
      document: widget.editor.document,
      documentLayout: widget.getDocumentLayout(),
      select: (newSelection) => _updateDragHandleSelection(newSelection, selectionType),
    )..onHandlePanStart(details, selection, handleType);

    // Update the controls for handle dragging.
    _controlsController!
      ..cancelCollapsedHandleAutoHideCountdown()
      ..doNotBlinkCaret()
      ..showMagnifier()
      ..hideToolbar();
  }

  void _onHandlePanUpdate(DragUpdateDetails details) {
    if (_dragHandleSelectionGlobalFocalPoint.value == null) {
      throw Exception(
          "Tried to pan an Android drag handle but the focal point is null. The focal point is set when the drag begins. This shouldn't be possible.");
    }

    // Move the selection focal point by the given delta.
    _dragHandleSelectionGlobalFocalPoint.value = _dragHandleSelectionGlobalFocalPoint.value! + details.delta;

    _dragHandleSelectionStrategy!.onHandlePanUpdate(details);

    // Update the magnifier based on the latest drag handle offset.
    _moveMagnifierToDragHandleOffset(dragDx: details.delta.dx);
  }

  void _onHandlePanEnd(DragEndDetails details, HandleType handleType) {
    _dragHandleSelectionStrategy = null;
    _onHandleDragEnd(handleType);
  }

  void _onHandlePanCancel(HandleType handleType) {
    _dragHandleSelectionStrategy = null;
    _onHandleDragEnd(handleType);
  }

  void _onHandleDragEnd(HandleType handleType) {
    _dragHandleSelectionStrategy = null;
    _dragHandleType = null;
    _dragHandleSelectionGlobalFocalPoint.value = null;
    _magnifierFocalPoint.value = null;

    // Start blinking the caret again, and hide the magnifier.
    _controlsController!
      ..blinkCaret()
      ..hideMagnifier();

    if (widget.editor.composer.selection?.isCollapsed == true &&
        const [HandleType.upstream, HandleType.downstream].contains(handleType)) {
      // The user dragged an expanded handle until the selection collapsed and then released the handle.
      // While the user was dragging, the expanded handles were displayed.
      // Show the collapsed.
      _controlsController!
        ..hideExpandedHandles()
        ..showCollapsedHandle();
    }

    if (widget.editor.composer.selection?.isCollapsed == false) {
      // The selection is expanded, show the toolbar.
      _controlsController!.showToolbar();
    } else {
      // The selection is collapsed, start the auto-hide countdown for the handle.
      _controlsController!.startCollapsedHandleAutoHideCountdown();
    }
  }

  void _moveMagnifierToDragHandleOffset({
    double dragDx = 0,
  }) {
    // Move the selection to the document position that's nearest the focal point.
    final documentLayout = widget.getDocumentLayout();
    final nearestPosition = documentLayout.getDocumentPositionNearestToOffset(
      documentLayout.getDocumentOffsetFromAncestorOffset(_dragHandleSelectionGlobalFocalPoint.value!),
    )!;

    final centerOfContentInContentSpace = documentLayout.getRectForPosition(nearestPosition)!.center;

    // Move the magnifier focal point to match the drag x-offset, but always remain focused on the vertical
    // center of the line.
    final centerOfContentAtNearestPosition =
        documentLayout.getAncestorOffsetFromDocumentOffset(centerOfContentInContentSpace);
    _magnifierFocalPoint.value = Offset(
      _magnifierFocalPoint.value!.dx + dragDx,
      centerOfContentAtNearestPosition.dy,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child!,
        OverlayPortal(
          controller: _overlayController,
          overlayChildBuilder: _buildOverlay,
          child: const SizedBox(),
        ),
      ],
    );
  }

  Widget _buildOverlay(BuildContext context) {
    return TapRegion(
      groupId: widget.tapRegionGroupId,
      child: Stack(
        key: _boundsKey,
        children: [
          _buildMagnifierFocalPoint(),
          if (widget.showDebugPaint) //
            _buildDebugSelectionFocalPoint(),
          _buildMagnifier(),
          // Handles and toolbar are built after the magnifier so that they don't appear in the magnifier.
          ..._buildExpandedHandles(),
          _buildToolbar(),
        ],
      ),
    );
  }

  List<Widget> _buildExpandedHandles() {
    if (_controlsController!.expandedHandlesBuilder != null) {
      return [
        ValueListenableBuilder(
          valueListenable: _controlsController!.shouldShowExpandedHandles,
          builder: (context, shouldShow, child) {
            return _controlsController!.expandedHandlesBuilder!(
              context,
              upstreamHandleKey: DocumentKeys.upstreamHandle,
              upstreamFocalPoint: _controlsController!.upstreamHandleFocalPoint,
              upstreamGestureDelegate: _upstreamHandleGesturesDelegate,
              downstreamHandleKey: DocumentKeys.downstreamHandle,
              downstreamFocalPoint: _controlsController!.downstreamHandleFocalPoint,
              downstreamGestureDelegate: _downstreamHandleGesturesDelegate,
              shouldShow: shouldShow,
            );
          },
        )
      ];
    }

    return [
      ValueListenableBuilder(
        valueListenable: _controlsController!.shouldShowExpandedHandles,
        builder: (context, shouldShow, child) {
          if (!shouldShow) {
            return const SizedBox();
          }

          return Follower.withOffset(
            link: _controlsController!.upstreamHandleFocalPoint,
            leaderAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topRight,
            showWhenUnlinked: false,
            // Use the offset to account for the invisible expanded touch region around the handle.
            offset:
                -AndroidSelectionHandle.defaultTouchRegionExpansion.topRight * MediaQuery.devicePixelRatioOf(context),
            child: GestureDetector(
              onTapDown: _upstreamHandleGesturesDelegate.onTapDown,
              onPanStart: _upstreamHandleGesturesDelegate.onPanStart,
              onPanUpdate: _upstreamHandleGesturesDelegate.onPanUpdate,
              onPanEnd: _upstreamHandleGesturesDelegate.onPanEnd,
              onPanCancel: _upstreamHandleGesturesDelegate.onPanCancel,
              dragStartBehavior: DragStartBehavior.down,
              child: AndroidSelectionHandle(
                key: DocumentKeys.upstreamHandle,
                handleType: HandleType.upstream,
                color: _controlsController!.controlsColor ?? Theme.of(context).primaryColor,
              ),
            ),
          );
        },
      ),
      ValueListenableBuilder(
        valueListenable: _controlsController!.shouldShowExpandedHandles,
        builder: (context, shouldShow, child) {
          if (!shouldShow) {
            return const SizedBox();
          }

          return Follower.withOffset(
            link: _controlsController!.downstreamHandleFocalPoint,
            leaderAnchor: Alignment.bottomRight,
            followerAnchor: Alignment.topLeft,
            showWhenUnlinked: false,
            // Use the offset to account for the invisible expanded touch region around the handle.
            offset:
                -AndroidSelectionHandle.defaultTouchRegionExpansion.topLeft * MediaQuery.devicePixelRatioOf(context),
            child: GestureDetector(
              onTapDown: _downstreamHandleGesturesDelegate.onTapDown,
              onPanStart: _downstreamHandleGesturesDelegate.onPanStart,
              onPanUpdate: _downstreamHandleGesturesDelegate.onPanUpdate,
              onPanEnd: _downstreamHandleGesturesDelegate.onPanEnd,
              onPanCancel: _downstreamHandleGesturesDelegate.onPanCancel,
              dragStartBehavior: DragStartBehavior.down,
              child: AndroidSelectionHandle(
                key: DocumentKeys.downstreamHandle,
                handleType: HandleType.downstream,
                color: _controlsController!.controlsColor ?? Theme.of(context).primaryColor,
              ),
            ),
          );
        },
      ),
    ];
  }

  Widget _buildToolbar() {
    return ValueListenableBuilder(
      valueListenable: _controlsController!.shouldShowToolbar,
      builder: (context, shouldShow, child) {
        return shouldShow ? child! : const SizedBox();
      },
      child: Follower.withAligner(
        link: _controlsController!.toolbarFocalPoint,
        aligner: _toolbarAligner,
        boundary: const ScreenFollowerBoundary(),
        showDebugPaint: false,
        child: _toolbarBuilder(context, DocumentKeys.mobileToolbar, _controlsController!.toolbarFocalPoint),
      ),
    );
  }

  DocumentFloatingToolbarBuilder get _toolbarBuilder {
    return _controlsController!.toolbarBuilder ?? //
        widget.defaultToolbarBuilder ??
        (_, __, ___) => const SizedBox();
  }

  Widget _buildMagnifierFocalPoint() {
    return ValueListenableBuilder(
      valueListenable: _magnifierFocalPoint,
      builder: (context, focalPoint, child) {
        if (focalPoint == null) {
          return const SizedBox();
        }

        return Positioned(
          left: focalPoint.dx,
          top: focalPoint.dy,
          width: 1,
          height: 1,
          child: Leader(
            link: _controlsController!.magnifierFocalPoint,
          ),
        );
      },
    );
  }

  Widget _buildMagnifier() {
    return ValueListenableBuilder(
      valueListenable: _controlsController!.shouldShowMagnifier,
      builder: (context, shouldShow, child) {
        return _controlsController!.magnifierBuilder != null //
            ? _controlsController!.magnifierBuilder!(
                context,
                DocumentKeys.magnifier,
                _controlsController!.magnifierFocalPoint,
                shouldShow,
              )
            : _buildDefaultMagnifier(
                context,
                DocumentKeys.magnifier,
                _controlsController!.magnifierFocalPoint,
                shouldShow,
              );
      },
    );
  }

  Widget _buildDefaultMagnifier(BuildContext context, Key magnifierKey, LeaderLink focalPoint, bool isVisible) {
    if (!isVisible) {
      return const SizedBox();
    }

    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    return Follower.withOffset(
      link: _controlsController!.magnifierFocalPoint,
      offset: Offset(0, -54 * devicePixelRatio),
      leaderAnchor: Alignment.center,
      followerAnchor: Alignment.center,
      boundary: const ScreenFollowerBoundary(),
      child: AndroidMagnifyingGlass(
        key: magnifierKey,
        magnificationScale: 1.5,
        offsetFromFocalPoint: const Offset(0, -54),
      ),
    );
  }

  Widget _buildDebugSelectionFocalPoint() {
    return ValueListenableBuilder(
      valueListenable: _dragHandleSelectionGlobalFocalPoint,
      builder: (context, focalPoint, child) {
        if (focalPoint == null) {
          return const SizedBox();
        }

        return Positioned(
          left: focalPoint.dx,
          top: focalPoint.dy,
          child: FractionalTranslation(
            translation: const Offset(-0.5, -0.5),
            child: Container(
              width: 5,
              height: 5,
              color: Colors.red,
            ),
          ),
        );
      },
    );
  }
}

/// A [SuperMessageDocumentLayerBuilder] that builds an [AndroidToolbarFocalPointDocumentLayer], which
/// positions a [Leader] widget around the document selection, as a focal point for an Android
/// floating toolbar.
class SuperMessageAndroidToolbarFocalPointDocumentLayerBuilder implements SuperMessageDocumentLayerBuilder {
  const SuperMessageAndroidToolbarFocalPointDocumentLayerBuilder({
    this.showDebugLeaderBounds = false,
  });

  /// Whether to paint colorful bounds around the leader widget.
  final bool showDebugLeaderBounds;

  @override
  ContentLayerWidget build(BuildContext context, ReadOnlyContext editorContext) {
    if (defaultTargetPlatform != TargetPlatform.android ||
        // FIXME: Either create a SuperMessage version of the scope, or change to a universal scope for all use-cases.
        SuperEditorAndroidControlsScope.maybeNearestOf(context) == null) {
      // There's no controls scope. This probably means SuperEditor is configured with
      // a non-Android gesture mode. Build nothing.
      return const ContentLayerProxyWidget(child: EmptyBox());
    }

    return AndroidToolbarFocalPointDocumentLayer(
      document: editorContext.document,
      selection: editorContext.composer.selectionNotifier,
      // FIXME: Either create a SuperMessage version of the scope, or change to a universal scope for all use-cases.
      toolbarFocalPointLink: SuperEditorAndroidControlsScope.rootOf(context).toolbarFocalPoint,
      showDebugLeaderBounds: showDebugLeaderBounds,
    );
  }
}

/// A [SuperMessageLayerBuilder], which builds an [AndroidHandlesDocumentLayer],
/// which displays Android-style caret and handles.
class SuperMessageAndroidHandlesDocumentLayerBuilder implements SuperMessageDocumentLayerBuilder {
  const SuperMessageAndroidHandlesDocumentLayerBuilder({
    this.caretColor,
    this.caretWidth = 2,
  });

  /// The (optional) color of the caret (not the drag handle), by default the color
  /// defers to the root [SuperEditorAndroidControlsScope], or the app theme if the
  /// controls controller has no preference for the color.
  final Color? caretColor;

  final double caretWidth;

  @override
  ContentLayerWidget build(BuildContext context, ReadOnlyContext editContext) {
    if (defaultTargetPlatform != TargetPlatform.android ||
        // FIXME: Either create a SuperMessage version of the scope, or change to a universal scope for all use-cases.
        SuperEditorAndroidControlsScope.maybeNearestOf(context) == null) {
      // There's no controls scope. This probably means SuperEditor is configured with
      // a non-Android gesture mode. Build nothing.
      return const ContentLayerProxyWidget(child: EmptyBox());
    }

    return AndroidHandlesDocumentLayer(
      document: editContext.document,
      documentLayout: editContext.documentLayout,
      selection: editContext.composer.selectionNotifier,
      changeSelection: (newSelection, changeType, reason) {
        editContext.editor.execute([
          ChangeSelectionRequest(newSelection, changeType, reason),
          const ClearComposingRegionRequest(),
        ]);
      },
      caretWidth: caretWidth,
      caretColor: caretColor,
    );
  }
}

/// An Android floating toolbar, which includes standard buttons for [SuperMessage]s.
class DefaultAndroidSuperMessageToolbar extends StatelessWidget {
  const DefaultAndroidSuperMessageToolbar({
    super.key,
    this.floatingToolbarKey,
    required this.editor,
    required this.editorControlsController,
    required this.focalPoint,
  });

  final Key? floatingToolbarKey;
  final LeaderLink focalPoint;
  final Editor editor;
  final SuperEditorAndroidControlsController editorControlsController;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: editor.composer.selectionNotifier,
      builder: (context, selection, child) {
        return AndroidTextEditingFloatingToolbar(
          floatingToolbarKey: floatingToolbarKey,
          focalPoint: focalPoint,
          onCopyPressed: selection == null || !selection.isCollapsed //
              ? _copy
              : null,
          onSelectAllPressed: _selectAll,
        );
      },
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
