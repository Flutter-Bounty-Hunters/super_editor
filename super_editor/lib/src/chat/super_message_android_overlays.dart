import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show Colors, Theme;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:overlord/follow_the_leader.dart';
import 'package:super_editor/src/chat/super_message.dart';
import 'package:super_editor/src/chat/super_message_android_touch_interactor.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/default_editor/document_gestures_touch_android.dart';
import 'package:super_editor/src/infrastructure/content_layers.dart';
import 'package:super_editor/src/infrastructure/documents/document_layers.dart';
import 'package:super_editor/src/infrastructure/documents/selection_leader_document_layer.dart';
import 'package:super_editor/src/infrastructure/flutter/eager_pan_gesture_recognizer.dart';
import 'package:super_editor/src/infrastructure/flutter/empty_box.dart';
import 'package:super_editor/src/infrastructure/flutter/flutter_scheduler.dart';
import 'package:super_editor/src/infrastructure/platforms/android/android_document_controls.dart';
import 'package:super_editor/src/infrastructure/platforms/android/drag_handle_selection.dart';
import 'package:super_editor/src/infrastructure/platforms/android/magnifier.dart';
import 'package:super_editor/src/infrastructure/platforms/android/selection_handles.dart';
import 'package:super_editor/src/infrastructure/platforms/android/toolbar.dart';
import 'package:super_editor/src/infrastructure/platforms/mobile_documents.dart';
import 'package:super_editor/src/infrastructure/document_context.dart';
import 'package:super_editor/src/infrastructure/render_sliver_ext.dart';
import 'package:super_editor/src/infrastructure/touch_controls.dart';

/// Adds and removes an Android-style editor controls overlay, as dictated by an ancestor
/// [SuperMessageAndroidControlsScope].
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

  SuperMessageAndroidControlsController? _controlsController;
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

    _controlsController = SuperMessageAndroidControlsScope.rootOf(context);
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
        ..hideExpandedHandles()
        ..hideMagnifier()
        ..hideToolbar();
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
    _controlsController!.hideMagnifier();

    if (widget.editor.composer.selection?.isCollapsed == true &&
        const [HandleType.upstream, HandleType.downstream].contains(handleType)) {
      // The user dragged an expanded handle until the selection collapsed and then released the handle.
      // While the user was dragging, the expanded handles were displayed.
      // Show the collapsed.
      _controlsController!.hideExpandedHandles();
    }

    if (widget.editor.composer.selection?.isCollapsed == false) {
      // The selection is expanded, show the toolbar.
      _controlsController!.showToolbar();
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
    return OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: _buildOverlay,
      child: widget.child,
    );
  }

  Widget _buildOverlay(BuildContext context) {
    return TapRegion(
      groupId: widget.tapRegionGroupId,
      child: Stack(
        key: _boundsKey,
        clipBehavior: Clip.none,
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

    final gestureSettings = MediaQuery.maybeOf(context)?.gestureSettings;
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
            child: RawGestureDetector(
              gestures: <Type, GestureRecognizerFactory>{
                EagerPanGestureRecognizer: GestureRecognizerFactoryWithHandlers<EagerPanGestureRecognizer>(
                  () => EagerPanGestureRecognizer(),
                  (EagerPanGestureRecognizer instance) {
                    instance
                      ..shouldAccept = () {
                        return true;
                      }
                      ..dragStartBehavior = DragStartBehavior.down
                      ..onDown = (DragDownDetails details) {
                        // No-op: this method is only here to beat out any ancestor
                        // Scrollable that's also trying to drag.
                      }
                      ..onStart = _upstreamHandleGesturesDelegate.onPanStart
                      ..onUpdate = _upstreamHandleGesturesDelegate.onPanUpdate
                      ..onEnd = _upstreamHandleGesturesDelegate.onPanEnd
                      ..onCancel = _upstreamHandleGesturesDelegate.onPanCancel
                      ..gestureSettings = gestureSettings;
                  },
                ),
              },
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
            child: RawGestureDetector(
              gestures: <Type, GestureRecognizerFactory>{
                EagerPanGestureRecognizer: GestureRecognizerFactoryWithHandlers<EagerPanGestureRecognizer>(
                  () => EagerPanGestureRecognizer(),
                  (EagerPanGestureRecognizer instance) {
                    instance
                      ..shouldAccept = () {
                        return true;
                      }
                      ..dragStartBehavior = DragStartBehavior.down
                      ..onDown = (DragDownDetails details) {
                        // No-op: this method is only here to beat out any ancestor
                        // Scrollable that's also trying to drag.
                      }
                      ..onStart = _downstreamHandleGesturesDelegate.onPanStart
                      ..onUpdate = _downstreamHandleGesturesDelegate.onPanUpdate
                      ..onEnd = _downstreamHandleGesturesDelegate.onPanEnd
                      ..onCancel = _downstreamHandleGesturesDelegate.onPanCancel
                      ..gestureSettings = gestureSettings;
                  },
                ),
              },
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
  ContentLayerWidget build(BuildContext context, DocumentContext editorContext) {
    if (defaultTargetPlatform != TargetPlatform.android ||
        SuperMessageAndroidControlsScope.maybeNearestOf(context) == null) {
      // There's no controls scope. This probably means SuperMessage is configured with
      // a non-Android gesture mode. Build nothing.
      return const ContentLayerProxyWidget(child: EmptyBox());
    }

    return AndroidToolbarFocalPointDocumentLayer(
      document: editorContext.document,
      selection: editorContext.composer.selectionNotifier,
      toolbarFocalPointLink: SuperMessageAndroidControlsScope.rootOf(context).toolbarFocalPoint,
      showDebugLeaderBounds: showDebugLeaderBounds,
    );
  }
}

/// A [SuperMessageLayerBuilder], which builds an [SuperMessageAndroidHandlesDocumentLayer],
/// which displays Android-style caret and handles.
class SuperMessageAndroidHandlesDocumentLayerBuilder implements SuperMessageDocumentLayerBuilder {
  const SuperMessageAndroidHandlesDocumentLayerBuilder({
    this.caretColor,
    this.caretWidth = 2,
  });

  /// The (optional) color of the caret (not the drag handle), by default the color
  /// defers to the root [SuperMessageAndroidControlsScope], or the app theme if the
  /// controls controller has no preference for the color.
  final Color? caretColor;

  final double caretWidth;

  @override
  ContentLayerWidget build(BuildContext context, DocumentContext editContext) {
    if (defaultTargetPlatform != TargetPlatform.android ||
        SuperMessageAndroidControlsScope.maybeNearestOf(context) == null) {
      // There's no controls scope. This probably means SuperMessage is configured with
      // a non-Android gesture mode. Build nothing.
      return const ContentLayerProxyWidget(child: EmptyBox());
    }

    return SuperMessageAndroidHandlesDocumentLayer(
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

/// A document layer that displays an Android-style caret, and positions [Leader]s for the Android
/// collapsed and expanded drag handles.
///
/// This layer positions and paints the caret directly, rather than using `Leader`s and `Follower`s,
/// because its position is based on the document layout, rather than the user's gesture behavior.
class SuperMessageAndroidHandlesDocumentLayer extends DocumentLayoutLayerStatefulWidget {
  const SuperMessageAndroidHandlesDocumentLayer({
    super.key,
    required this.document,
    required this.documentLayout,
    required this.selection,
    required this.changeSelection,
    this.caretWidth = 2,
    this.caretColor,
    this.showDebugPaint = false,
  });

  final Document document;

  final DocumentLayout documentLayout;

  final ValueListenable<DocumentSelection?> selection;

  final void Function(DocumentSelection?, SelectionChangeType, String selectionReason) changeSelection;

  final double caretWidth;

  /// Color used to render the Android-style caret (not handles), by default the color
  /// is retrieved from the root [SuperEditorAndroidControlsController].
  final Color? caretColor;

  final bool showDebugPaint;

  @override
  DocumentLayoutLayerState<SuperMessageAndroidHandlesDocumentLayer, DocumentSelectionLayout> createState() =>
      SuperMessageAndroidControlsDocumentLayerState();
}

@visibleForTesting
class SuperMessageAndroidControlsDocumentLayerState
    extends DocumentLayoutLayerState<SuperMessageAndroidHandlesDocumentLayer, DocumentSelectionLayout>
    with SingleTickerProviderStateMixin {
  SuperMessageAndroidControlsController? _controlsController;

  @override
  void initState() {
    super.initState();

    widget.selection.addListener(_onSelectionChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_controlsController != null) {
      _controlsController!.areSelectionHandlesAllowed.removeListener(_onSelectionHandlesAllowedChange);
    }

    _controlsController = SuperMessageAndroidControlsScope.rootOf(context);
    _controlsController!.areSelectionHandlesAllowed.addListener(_onSelectionHandlesAllowedChange);
  }

  @override
  void didUpdateWidget(SuperMessageAndroidHandlesDocumentLayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.selection != oldWidget.selection) {
      oldWidget.selection.removeListener(_onSelectionChange);
      widget.selection.addListener(_onSelectionChange);
    }
  }

  @override
  void dispose() {
    widget.selection.removeListener(_onSelectionChange);
    _controlsController!.areSelectionHandlesAllowed.removeListener(_onSelectionHandlesAllowedChange);
    super.dispose();
  }

  @visibleForTesting
  bool get isUpstreamHandleDisplayed => layoutData?.upstream != null;

  @visibleForTesting
  bool get isDownstreamHandleDisplayed => layoutData?.downstream != null;

  void _onSelectionChange() {
    setState(() {
      // Schedule a new layout computation because the handles need to move.
    });
  }

  void _onSelectionHandlesAllowedChange() {
    setState(() {
      // The controller went from allowing selection handles to disallowing them, or vis-a-versa.
      // Rebuild this widget to show/hide the handles.
    });
  }

  @override
  DocumentSelectionLayout? computeLayoutDataWithDocumentLayout(
      BuildContext contentLayersContext, BuildContext documentContext, DocumentLayout documentLayout) {
    final selection = widget.selection.value;
    if (selection == null) {
      return null;
    }

    if (!_controlsController!.areSelectionHandlesAllowed.value) {
      // We don't want to show any selection handles.
      return null;
    }

    if (selection.isCollapsed && !_controlsController!.shouldShowExpandedHandles.value) {
      Rect caretRect = documentLayout.getEdgeForPosition(selection.extent)!;

      // Default caret width used by the Android caret.
      const caretWidth = 2;

      // Use the content's RenderBox instead of the layer's RenderBox to get the layer's width.
      //
      // ContentLayers works in four steps:
      //
      // 1. The content is built.
      // 2. The content is laid out.
      // 3. The layers are built.
      // 4. The layers are laid out.
      //
      // The computeLayoutData method is called during the layer's build, which means that the
      // layer's RenderBox is outdated, because it wasn't laid out yet for the current frame.
      // Use the content's RenderBox, which was already laid out for the current frame.
      final contentBox = documentContext.findRenderObject();
      if (contentBox != null) {
        if (contentBox is RenderSliver && contentBox.hasSize && caretRect.left + caretWidth >= contentBox.size.width) {
          // Adjust the caret position to make it entirely visible because it's currently placed
          // partially or entirely outside of the layers' bounds. This can happen for downstream selections
          // of block components that take all the available width.
          caretRect = Rect.fromLTWH(
            contentBox.size.width - caretWidth,
            caretRect.top,
            caretRect.width,
            caretRect.height,
          );
        } else if (contentBox is RenderBox &&
            contentBox.hasSize &&
            caretRect.left + caretWidth >= contentBox.size.width) {
          // Adjust the caret position to make it entirely visible because it's currently placed
          // partially or entirely outside of the layers' bounds. This can happen for downstream selections
          // of block components that take all the available width.
          caretRect = Rect.fromLTWH(
            contentBox.size.width - caretWidth,
            caretRect.top,
            caretRect.width,
            caretRect.height,
          );
        }
      }

      return DocumentSelectionLayout(
        caret: caretRect,
      );
    } else {
      return DocumentSelectionLayout(
        upstream: documentLayout.getRectForPosition(
          widget.document.selectUpstreamPosition(selection.base, selection.extent),
        )!,
        downstream: documentLayout.getRectForPosition(
          widget.document.selectDownstreamPosition(selection.base, selection.extent),
        )!,
        expandedSelectionBounds: documentLayout.getRectForSelection(
          selection.base,
          selection.extent,
        ),
      );
    }
  }

  @override
  Widget doBuild(BuildContext context, DocumentSelectionLayout? layoutData) {
    return IgnorePointer(
      child: SizedBox.expand(
        child: layoutData != null //
            ? _buildHandles(layoutData)
            : const SizedBox(),
      ),
    );
  }

  Widget _buildHandles(DocumentSelectionLayout layoutData) {
    if (widget.selection.value == null) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        if (layoutData.upstream != null && layoutData.downstream != null)
          ..._buildExpandedHandleLeaders(
            upstream: layoutData.upstream!,
            downstream: layoutData.downstream!,
          ),
      ],
    );
  }

  List<Widget> _buildExpandedHandleLeaders({
    required Rect upstream,
    required Rect downstream,
  }) {
    return [
      Positioned.fromRect(
        rect: upstream,
        child: Leader(link: _controlsController!.upstreamHandleFocalPoint),
      ),
      Positioned.fromRect(
        rect: downstream,
        child: Leader(link: _controlsController!.downstreamHandleFocalPoint),
      ),
    ];
  }
}

/// An Android floating toolbar, which includes standard buttons for [SuperMessage]s.
class DefaultAndroidSuperMessageToolbar extends StatelessWidget {
  const DefaultAndroidSuperMessageToolbar({
    super.key,
    this.floatingToolbarKey,
    required this.editor,
    required this.messageControlsController,
    required this.focalPoint,
  });

  final Key? floatingToolbarKey;
  final LeaderLink focalPoint;
  final Editor editor;
  final SuperMessageAndroidControlsController messageControlsController;

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
