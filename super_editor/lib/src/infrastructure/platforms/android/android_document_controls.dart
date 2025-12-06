import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/document_gestures_touch_android.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/content_layers.dart';
import 'package:super_editor/src/infrastructure/documents/document_layers.dart';
import 'package:super_editor/src/infrastructure/documents/selection_leader_document_layer.dart';
import 'package:super_editor/src/infrastructure/flutter/flutter_scheduler.dart';
import 'package:super_editor/src/infrastructure/platforms/mobile_documents.dart';
import 'package:super_editor/src/infrastructure/render_sliver_ext.dart';
import 'package:super_text_layout/super_text_layout.dart';

/// A document layer that positions a leader widget around the user's selection,
/// as a focal point for an Android-style toolbar display.
///
/// By default, the toolbar focal point [LeaderLink] is obtained from an ancestor
/// [SuperEditorAndroidControlsScope].
class AndroidToolbarFocalPointDocumentLayer extends DocumentLayoutLayerStatefulWidget {
  const AndroidToolbarFocalPointDocumentLayer({
    Key? key,
    required this.document,
    required this.selection,
    required this.toolbarFocalPointLink,
    this.showDebugLeaderBounds = false,
  }) : super(key: key);

  /// The editor's [Document], which is used to find the start and end of
  /// the user's expanded selection.
  final Document document;

  /// The current user's selection within a document.
  final ValueListenable<DocumentSelection?> selection;

  /// The [LeaderLink], which is attached to the toolbar focal point bounds.
  ///
  /// By default, this [LeaderLink] is obtained from an ancestor [SuperEditorAndroidControlsScope].
  /// If [toolbarFocalPointLink] is non-null, it's used instead of the ancestor value.
  final LeaderLink toolbarFocalPointLink;

  /// Whether to paint colorful bounds around the leader widgets, for debugging purposes.
  final bool showDebugLeaderBounds;

  @override
  DocumentLayoutLayerState<ContentLayerStatefulWidget, Rect> createState() =>
      _AndroidToolbarFocalPointDocumentLayerState();
}

class _AndroidToolbarFocalPointDocumentLayerState
    extends DocumentLayoutLayerState<AndroidToolbarFocalPointDocumentLayer, Rect> {
  @override
  void initState() {
    super.initState();

    widget.selection.addListener(_onSelectionChange);
  }

  @override
  void didUpdateWidget(AndroidToolbarFocalPointDocumentLayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.selection != oldWidget.selection) {
      oldWidget.selection.removeListener(_onSelectionChange);
      widget.selection.addListener(_onSelectionChange);
    }
  }

  @override
  void dispose() {
    widget.selection.removeListener(_onSelectionChange);

    super.dispose();
  }

  void _onSelectionChange() {
    // Re-calculate the selection visual bounds by running setState().
    setStateAsSoonAsPossible(() {
      // The selection bounds, and Leader build, will take place in methods that
      // run in response to setState().
    });
  }

  @override
  Rect? computeLayoutDataWithDocumentLayout(
      BuildContext contentLayersContext, BuildContext documentContext, DocumentLayout documentLayout) {
    final documentSelection = widget.selection.value;
    if (documentSelection == null) {
      return null;
    }

    final selectedComponent = documentLayout.getComponentByNodeId(widget.selection.value!.extent.nodeId);
    if (selectedComponent == null) {
      // Assume that we're in a momentary transitive state where the document layout
      // just gained or lost a component. We expect this method to run again in a moment
      // to correct for this.
      return null;
    }

    return documentLayout.getRectForSelection(
      documentSelection.base,
      documentSelection.extent,
    );
  }

  @override
  Widget doBuild(BuildContext context, Rect? expandedSelectionBounds) {
    if (expandedSelectionBounds == null) {
      return const SizedBox();
    }

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fromRect(
            rect: expandedSelectionBounds,
            child: Leader(
              link: widget.toolbarFocalPointLink,
              child: widget.showDebugLeaderBounds
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          width: 4,
                          color: const Color(0xFFFF00FF),
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

// TODO: should we de-dup AndroidHandlesDocumentLayer with the iOS version? It's mostly the same.

/// A document layer that displays an Android-style caret, and positions [Leader]s for the Android
/// collapsed and expanded drag handles.
///
/// This layer positions and paints the caret directly, rather than using `Leader`s and `Follower`s,
/// because its position is based on the document layout, rather than the user's gesture behavior.
class AndroidHandlesDocumentLayer extends DocumentLayoutLayerStatefulWidget {
  const AndroidHandlesDocumentLayer({
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
  DocumentLayoutLayerState<AndroidHandlesDocumentLayer, DocumentSelectionLayout> createState() =>
      AndroidControlsDocumentLayerState();
}

@visibleForTesting
class AndroidControlsDocumentLayerState
    extends DocumentLayoutLayerState<AndroidHandlesDocumentLayer, DocumentSelectionLayout>
    with SingleTickerProviderStateMixin {
  late BlinkController _caretBlinkController;

  SuperEditorAndroidControlsController? _controlsController;

  DocumentSelection? _previousSelection;

  @override
  void initState() {
    super.initState();
    _caretBlinkController = BlinkController.withTimer();

    _previousSelection = widget.selection.value;
    widget.selection.addListener(_onSelectionChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_controlsController != null) {
      _controlsController!.shouldCaretBlink.removeListener(_onBlinkModeChange);
      _controlsController!.caretJumpToOpaqueSignal.removeListener(_caretJumpToOpaque);
      _controlsController!.shouldShowCollapsedHandle.removeListener(_onShouldShowCollapsedHandleChange);
      _controlsController!.areSelectionHandlesAllowed.removeListener(_onSelectionHandlesAllowedChange);
    }

    _controlsController = SuperEditorAndroidControlsScope.rootOf(context);
    _controlsController!.shouldCaretBlink.addListener(_onBlinkModeChange);
    _controlsController!.caretJumpToOpaqueSignal.addListener(_caretJumpToOpaque);
    _controlsController!.areSelectionHandlesAllowed.addListener(_onSelectionHandlesAllowedChange);

    /// Listen for changes about whether we want to show the collapsed handle
    /// or whether we want to show expanded handles for a selection. We listen to
    /// this because there are some situations where the desired handle type is
    /// ambiguous, such as when when the user drags an expanded handle such that
    /// the selection collapses. In that case, the selection is collapsed but we want
    /// to show the expanded handle. This signal clarifies which one we want.
    _controlsController!.shouldShowCollapsedHandle.addListener(_onShouldShowCollapsedHandleChange);
    _onBlinkModeChange();
  }

  @override
  void didUpdateWidget(AndroidHandlesDocumentLayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.selection != oldWidget.selection) {
      oldWidget.selection.removeListener(_onSelectionChange);
      widget.selection.addListener(_onSelectionChange);
    }
  }

  @override
  void dispose() {
    widget.selection.removeListener(_onSelectionChange);
    _controlsController?.shouldCaretBlink.removeListener(_onBlinkModeChange);
    _controlsController!.shouldShowCollapsedHandle.removeListener(_onShouldShowCollapsedHandleChange);
    _controlsController!.areSelectionHandlesAllowed.removeListener(_onSelectionHandlesAllowedChange);

    _caretBlinkController.dispose();
    super.dispose();
  }

  @visibleForTesting
  Rect? get caret => layoutData?.caret;

  @visibleForTesting
  Color get caretColor => widget.caretColor ?? _controlsController?.controlsColor ?? Theme.of(context).primaryColor;

  @visibleForTesting
  bool get isCaretDisplayed => layoutData?.caret != null;

  @visibleForTesting
  bool get isCaretVisible => _caretBlinkController.opacity == 1.0 && isCaretDisplayed;

  @visibleForTesting
  Duration get caretFlashPeriod => _caretBlinkController.flashPeriod;

  @visibleForTesting
  bool get isUpstreamHandleDisplayed => layoutData?.upstream != null;

  @visibleForTesting
  bool get isDownstreamHandleDisplayed => layoutData?.downstream != null;

  void _onSelectionChange() {
    final newSelection = widget.selection.value;
    if (newSelection != null && newSelection.isCollapsed) {
      // Check for caret movement, because the caret should jump to opaque whenever it moves.
      // This can happen when the user taps to move the caret, or when the user presses keyboard
      // key sot move the caret.
      if (_previousSelection != null &&
          _previousSelection!.isCollapsed &&
          !_previousSelection!.extent.isEquivalentTo(newSelection.extent)) {
        // The caret moved from one place to another.
        _controlsController!.jumpCaretToOpaque();
      }
      // Else, the selection went from null to non-null, or from caret to expanded. In these other
      // cases, other areas of the system will ensure that the caret jumps to opaque.
    }
    _previousSelection = newSelection;

    setState(() {
      // Schedule a new layout computation because the caret and/or handles need to move.
    });
  }

  void _onBlinkModeChange() {
    if (_controlsController!.shouldCaretBlink.value) {
      _caretBlinkController.startBlinking();
    } else {
      _caretBlinkController.stopBlinking();
    }
  }

  void _caretJumpToOpaque() {
    _caretBlinkController.jumpToOpaque();
  }

  void _onShouldShowCollapsedHandleChange() {
    // The controller went from wanting a collapsed handle to wanting expanded handles,
    // or vis-a-versa. This signal is relevant to us because of an ambiguous handle situation.
    // The user might drag an expanded handle such  that the selection is collapsed, in which
    // case we still want to show an expanded handle. Similarly, if the user then releases that
    // expanded handle, we should switch to a collapsed handle for the same selection. This
    // method tells us that the desired handle type has changed. Re-run layout and build to
    // ensure that we're showing the correct handle.
    setState(() {
      //
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
      editorGesturesLog.finer("Not building overlay handles because there's no selection.");
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        if (layoutData.caret != null) //
          _buildCaret(caret: layoutData.caret!),
        if (layoutData.upstream != null && layoutData.downstream != null)
          ..._buildExpandedHandleLeaders(
            upstream: layoutData.upstream!,
            downstream: layoutData.downstream!,
          ),
      ],
    );
  }

  Widget _buildCaret({
    required Rect caret,
  }) {
    return Positioned(
      left: caret.left,
      top: caret.top,
      height: caret.height,
      width: widget.caretWidth,
      child: Leader(
        link: _controlsController!.collapsedHandleFocalPoint,
        child: ListenableBuilder(
          listenable: _caretBlinkController,
          builder: (context, child) {
            return ColoredBox(
              key: DocumentKeys.caret,
              color: caretColor.withValues(alpha: _caretBlinkController.opacity),
            );
          },
        ),
      ),
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

// TODO: Can we get rid of this controller after migrating to compositional approach
/// Controls the display of drag handles, a magnifier, and a
/// floating toolbar, assuming Android-style behavior for the
/// handles.
class AndroidDocumentGestureEditingController extends GestureEditingController {
  AndroidDocumentGestureEditingController({
    required super.selectionLinks,
    required super.magnifierFocalPointLink,
    required super.overlayController,
  });

  @override
  void dispose() {
    _collapsedHandleAutoHideTimer?.cancel();
    super.dispose();
  }

  /// Whether or not a caret should be displayed.
  bool get hasCaret => caretTop != null;

  /// The offset of the top of the caret, or `null` if no caret should
  /// be displayed.
  ///
  /// When the caret is drawn, the caret will have a thickness. That width
  /// should be placed either on the left or right of this offset, based on
  /// whether the [caretAffinity] is upstream or downstream, respectively.
  Offset? get caretTop => _caretTop;
  Offset? _caretTop;

  /// The height of the caret, or `null` if no caret should be displayed.
  double? get caretHeight => _caretHeight;
  double? _caretHeight;

  /// Updates the caret's size and position.
  ///
  /// The [top] offset is in the document layout's coordinate space.
  void updateCaret({
    Offset? top,
    double? height,
  }) {
    bool changed = false;
    if (top != null) {
      _caretTop = top;
      changed = true;
    }
    if (height != null) {
      _caretHeight = height;
      changed = true;
    }

    if (changed) {
      notifyListeners();
    }
  }

  /// Removes the caret from the display.
  void removeCaret() {
    if (!hasCaret) {
      return;
    }

    _caretTop = null;
    _caretHeight = null;
    notifyListeners();
  }

  void allowHandles() => _allowedToShowHandles = true;

  void disallowHandles() => _allowedToShowHandles = false;

  /// Whether or not the overlay is allowed to show handles, regardless of selection.
  ///
  /// When this is `false`, the handles should be hidden, even if there's a selection,
  /// and the handles have valid visual offsets.
  ///
  /// When this is `true`, the handles MAY be shown, assuming all other necessary
  /// conditions are met, e.g., there's a selection.
  bool _allowedToShowHandles = true;

  /// Whether a collapsed handle should be displayed.
  bool get shouldDisplayCollapsedHandle => _allowedToShowHandles && _collapsedHandleOffset != null;

  /// The offset of the collapsed handle focal point, within the coordinate space
  /// of the document layout, or `null` if no collapsed handle should be displayed.
  Offset? get collapsedHandleOffset => _collapsedHandleOffset;
  Offset? _collapsedHandleOffset;
  set collapsedHandleOffset(Offset? offset) {
    if (offset != _collapsedHandleOffset) {
      _collapsedHandleOffset = offset;
      notifyListeners();
    }
  }

  /// Whether the expanded handles (base + extent) should be displayed.
  bool get shouldDisplayExpandedHandles =>
      _allowedToShowHandles && _upstreamHandleOffset != null && _downstreamHandleOffset != null;

  /// The offset of the upstream handle focal point, within the coordinate space
  /// of the document layout, or `null` if no upstream handle should be displayed.
  Offset? get upstreamHandleOffset => _upstreamHandleOffset;
  Offset? _upstreamHandleOffset;
  set upstreamHandleOffset(Offset? offset) {
    if (offset != _upstreamHandleOffset) {
      _upstreamHandleOffset = offset;
      notifyListeners();
    }
  }

  /// The offset of the downstream handle focal point, within the coordinate space
  /// of the document layout, or `null` if no downstream handle should be displayed.
  Offset? get downstreamHandleOffset => _downstreamHandleOffset;
  Offset? _downstreamHandleOffset;
  set downstreamHandleOffset(Offset? offset) {
    if (offset != _downstreamHandleOffset) {
      _downstreamHandleOffset = offset;
      notifyListeners();
    }
  }

  final Duration _collapsedHandleAutoHideDuration = const Duration(seconds: 4);
  Timer? _collapsedHandleAutoHideTimer;

  /// Whether the collapsed handle should be faded out for the purpose of
  /// auto-hiding while the user is inactive.
  bool get isCollapsedHandleAutoHidden => _isCollapsedHandleAutoHidden;
  bool _isCollapsedHandleAutoHidden = false;

  /// Starts a countdown that, if reached, fades out the collapsed drag handle.
  void startCollapsedHandleAutoHideCountdown() {
    _collapsedHandleAutoHideTimer?.cancel();
    _collapsedHandleAutoHideTimer = Timer(_collapsedHandleAutoHideDuration, _hideCollapsedHandle);
  }

  /// Cancels a countdown that started with [startCollapsedHandleAutoHideCountdown].
  void cancelCollapsedHandleAutoHideCountdown() {
    _collapsedHandleAutoHideTimer?.cancel();
  }

  void _hideCollapsedHandle() {
    if (!_isCollapsedHandleAutoHidden) {
      _isCollapsedHandleAutoHidden = true;
      notifyListeners();
    }
  }

  /// Brings back a faded-out collapsed drag handle.
  void unHideCollapsedHandle() {
    if (_isCollapsedHandleAutoHidden) {
      _isCollapsedHandleAutoHidden = false;
      notifyListeners();
    }
  }
}
