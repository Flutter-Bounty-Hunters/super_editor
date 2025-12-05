import 'dart:async';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/default_editor/document_gestures_touch_android.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';
import 'package:super_editor/src/default_editor/text_tools.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/document_gestures_interaction_overrides.dart';
import 'package:super_editor/src/infrastructure/flutter/eager_pan_gesture_recognizer.dart';
import 'package:super_editor/src/infrastructure/flutter/flutter_scheduler.dart';
import 'package:super_editor/src/infrastructure/multi_tap_gesture.dart';
import 'package:super_editor/src/infrastructure/platforms/android/long_press_selection.dart';

/// Document gesture interactor that's designed for Android touch input, e.g.,
/// drag to scroll, and handles to control selection.
class SuperMessageAndroidTouchInteractor extends StatefulWidget {
  const SuperMessageAndroidTouchInteractor({
    Key? key,
    required this.focusNode,
    required this.editor,
    required this.getDocumentLayout,
    this.contentTapHandlers,
    this.showDebugPaint = false,
    required this.child,
  }) : super(key: key);

  final FocusNode focusNode;

  final Editor editor;
  final DocumentLayout Function() getDocumentLayout;

  /// Optional list of handlers that respond to taps on content, e.g., opening
  /// a link when the user taps on text with a link attribution.
  ///
  /// If a handler returns [TapHandlingInstruction.halt], no subsequent handlers
  /// nor the default tap behavior will be executed.
  final List<ContentTapDelegate>? contentTapHandlers;

  final bool showDebugPaint;

  final Widget child;

  @override
  State<SuperMessageAndroidTouchInteractor> createState() => _SuperMessageAndroidTouchInteractorState();
}

class _SuperMessageAndroidTouchInteractorState extends State<SuperMessageAndroidTouchInteractor>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  SuperEditorAndroidControlsController? _controlsController;

  Offset? _globalTapDownOffset;
  Offset? _globalStartDragOffset;
  Offset? _dragStartInDoc;
  Offset? _startDragPositionOffset;
  Offset? _globalDragOffset;

  final _magnifierGlobalOffset = ValueNotifier<Offset?>(null);

  Timer? _tapDownLongPressTimer;
  bool get _isLongPressInProgress => _longPressStrategy != null;
  AndroidDocumentLongPressSelectionStrategy? _longPressStrategy;

  bool _isCaretDragInProgress = false;

  // Cached view metrics to ignore unnecessary didChangeMetrics calls.
  Size? _lastSize;
  ViewPadding? _lastInsets;

  final _interactor = GlobalKey();

  @override
  void initState() {
    super.initState();

    widget.editor.document.addListener(_onDocumentChange);
    widget.editor.composer.selectionNotifier.addListener(_onSelectionChange);

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final view = View.of(context);
    _lastSize = view.physicalSize;
    _lastInsets = view.viewInsets;

    _controlsController = SuperEditorAndroidControlsScope.rootOf(context);
  }

  @override
  void didUpdateWidget(SuperMessageAndroidTouchInteractor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.editor.document != oldWidget.editor.document) {
      oldWidget.editor.document.removeListener(_onDocumentChange);
      widget.editor.document.addListener(_onDocumentChange);
    }

    if (widget.editor.composer.selectionNotifier != oldWidget.editor.composer.selectionNotifier) {
      oldWidget.editor.composer.selectionNotifier.removeListener(_onSelectionChange);
      widget.editor.composer.selectionNotifier.addListener(_onSelectionChange);
    }
  }

  @override
  void didChangeMetrics() {
    // It is possible to get the notification even though the metrics for view are same.
    final view = View.of(context);
    final size = view.physicalSize;
    final insets = view.viewInsets;
    if (size == _lastSize &&
        _lastInsets?.left == insets.left &&
        _lastInsets?.right == insets.right &&
        _lastInsets?.top == insets.top &&
        _lastInsets?.bottom == insets.bottom) {
      return;
    }
    _lastSize = size;
    _lastInsets = insets;

    // The available screen dimensions may have changed, e.g., due to keyboard
    // appearance/disappearance. Reflow the layout. Use a post-frame callback
    // to give the rest of the UI a chance to reflow, first.
    onNextFrame((_) {
      setState(() {
        // reflow document layout
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    widget.editor.document.removeListener(_onDocumentChange);
    widget.editor.composer.selectionNotifier.removeListener(_onSelectionChange);

    super.dispose();
  }

  /// Returns the layout for the current document, which answers questions
  /// about the locations and sizes of visual components within the layout.
  DocumentLayout get _docLayout => widget.getDocumentLayout();

  Offset _getDocumentOffsetFromGlobalOffset(Offset globalOffset) {
    return _docLayout.getDocumentOffsetFromAncestorOffset(globalOffset);
  }

  /// Returns the render box for the interactor gesture detector.
  RenderBox get interactorBox => _interactor.currentContext!.findRenderObject() as RenderBox;

  void _onDocumentChange(_) {
    // The user might start typing when the toolbar is visible. Hide it.
    _controlsController!.hideToolbar();
  }

  void _onSelectionChange() {
    if (widget.editor.composer.selection == null) {
      _controlsController!
        ..hideCollapsedHandle()
        ..hideExpandedHandles()
        ..hideMagnifier()
        ..hideToolbar();
      return;
    }
  }

  void _onTapDown(TapDownDetails details) {
    _globalTapDownOffset = details.globalPosition;
    _tapDownLongPressTimer?.cancel();
    _tapDownLongPressTimer = Timer(kLongPressTimeout, _onLongPressDown);
  }

  void _onTapCancel() {
    _tapDownLongPressTimer?.cancel();
    _tapDownLongPressTimer = null;
  }

  // Runs when a tap down has lasted long enough to signify a long-press.
  void _onLongPressDown() {
    _longPressStrategy = AndroidDocumentLongPressSelectionStrategy(
      document: widget.editor.document,
      documentLayout: _docLayout,
      select: _updateLongPressSelection,
    );

    final didLongPressSelectionStart = _longPressStrategy!.onLongPressStart(
      tapDownDocumentOffset: _getDocumentOffsetFromGlobalOffset(_globalTapDownOffset!),
    );
    if (!didLongPressSelectionStart) {
      _longPressStrategy = null;
      return;
    }

    // A long-press selection is in progress. Initially show the toolbar, but nothing else.
    _controlsController!
      ..hideCollapsedHandle()
      ..hideExpandedHandles()
      ..hideMagnifier()
      ..showToolbar();

    widget.focusNode.requestFocus();
  }

  void _onTapUp(TapUpDetails details) {
    print("_onTapUp() on message");
    // Stop waiting for a long-press to start.
    _tapDownLongPressTimer?.cancel();

    // Cancel any on-going long-press.
    if (_isLongPressInProgress) {
      _onLongPressEnd();
      _longPressStrategy = null;
      _magnifierGlobalOffset.value = null;
      return;
    }

    editorGesturesLog.info("Tap down on document");
    final docOffset = _getDocumentOffsetFromGlobalOffset(details.globalPosition);
    editorGesturesLog.fine(" - document offset: $docOffset");

    if (widget.contentTapHandlers != null) {
      for (final handler in widget.contentTapHandlers!) {
        final result = handler.onTap(
          DocumentTapDetails(
            documentLayout: _docLayout,
            layoutOffset: docOffset,
            globalOffset: details.globalPosition,
          ),
        );
        if (result == TapHandlingInstruction.halt) {
          // The custom tap handler doesn't want us to react at all
          // to the tap.
          return;
        }
      }
    }

    final docPosition = _docLayout.getDocumentPositionNearestToOffset(docOffset);
    editorGesturesLog.fine(" - tapped document position: $docPosition");

    if (docPosition == null) {
      _clearSelection();
    }

    final selection = widget.editor.composer.selection;
    if (selection != null && docPosition != null && !selection.containsPosition(widget.editor.document, docPosition)) {
      // The user tapped outside the current selection. Clear the selection.
      _clearSelection();
    }

    _showAndHideEditingControlsAfterTapSelection();

    widget.focusNode.requestFocus();
  }

  void _onDoubleTapDown(TapDownDetails details) {
    editorGesturesLog.info("Double tap down on document");
    final docOffset = _getDocumentOffsetFromGlobalOffset(details.globalPosition);
    editorGesturesLog.fine(" - document offset: $docOffset");

    if (widget.contentTapHandlers != null) {
      for (final handler in widget.contentTapHandlers!) {
        final result = handler.onDoubleTap(
          DocumentTapDetails(
            documentLayout: _docLayout,
            layoutOffset: docOffset,
            globalOffset: details.globalPosition,
          ),
        );
        if (result == TapHandlingInstruction.halt) {
          // The custom tap handler doesn't want us to react at all
          // to the tap.
          return;
        }
      }
    }

    final docPosition = _docLayout.getDocumentPositionNearestToOffset(docOffset);
    editorGesturesLog.fine(" - tapped document position: $docPosition");

    if (docPosition != null) {
      final tappedComponent = _docLayout.getComponentByNodeId(docPosition.nodeId)!;
      if (!tappedComponent.isVisualSelectionSupported()) {
        // The user tapped a non-selectable component, so we can't select a word.
        // The editor will remain focused and selection will remain in the nearest
        // selectable component, as set in _onTapUp.
        return;
      }

      bool didSelectContent = _selectWordAt(
        docPosition: docPosition,
        docLayout: _docLayout,
      );

      if (!didSelectContent) {
        didSelectContent = _selectBlockAt(docPosition);
      }

      if (!didSelectContent) {
        // Place the document selection at the location where the
        // user tapped.
        _selectPosition(docPosition);
      }
    } else {
      _clearSelection();
    }

    _showAndHideEditingControlsAfterTapSelection();

    widget.focusNode.requestFocus();
  }

  bool _selectBlockAt(DocumentPosition position) {
    if (position.nodePosition is! UpstreamDownstreamNodePosition) {
      return false;
    }

    widget.editor.execute([
      ChangeSelectionRequest(
        DocumentSelection(
          base: DocumentPosition(
            nodeId: position.nodeId,
            nodePosition: const UpstreamDownstreamNodePosition.upstream(),
          ),
          extent: DocumentPosition(
            nodeId: position.nodeId,
            nodePosition: const UpstreamDownstreamNodePosition.downstream(),
          ),
        ),
        SelectionChangeType.placeCaret,
        SelectionReason.userInteraction,
      ),
      const ClearComposingRegionRequest(),
    ]);

    return true;
  }

  void _onTripleTapDown(TapDownDetails details) {
    editorGesturesLog.info("Triple tap down on document");
    final docOffset = _getDocumentOffsetFromGlobalOffset(details.globalPosition);
    editorGesturesLog.fine(" - document offset: $docOffset");

    if (widget.contentTapHandlers != null) {
      for (final handler in widget.contentTapHandlers!) {
        final result = handler.onTripleTap(
          DocumentTapDetails(
            documentLayout: _docLayout,
            layoutOffset: docOffset,
            globalOffset: details.globalPosition,
          ),
        );
        if (result == TapHandlingInstruction.halt) {
          // The custom tap handler doesn't want us to react at all
          // to the tap.
          return;
        }
      }
    }

    final docPosition = _docLayout.getDocumentPositionNearestToOffset(docOffset);
    editorGesturesLog.fine(" - tapped document position: $docPosition");
    if (docPosition != null) {
      // The user tapped a non-selectable component, so we can't select a paragraph.
      // The editor will remain focused and selection will remain in the nearest
      // selectable component, as set in _onTapUp.
      final tappedComponent = _docLayout.getComponentByNodeId(docPosition.nodeId)!;
      if (!tappedComponent.isVisualSelectionSupported()) {
        return;
      }

      final didSelectParagraph = _selectParagraphAt(
        docPosition: docPosition,
        docLayout: _docLayout,
      );
      if (!didSelectParagraph) {
        // Place the document selection at the location where the
        // user tapped.
        _selectPosition(docPosition);
      }
    } else {
      _clearSelection();
    }

    _showAndHideEditingControlsAfterTapSelection();

    widget.focusNode.requestFocus();
  }

  void _showAndHideEditingControlsAfterTapSelection() {
    if (widget.editor.composer.selection == null) {
      // There's no selection. Hide all controls.
      _controlsController!
        ..hideCollapsedHandle()
        ..hideExpandedHandles()
        ..hideMagnifier()
        ..hideToolbar()
        ..doNotBlinkCaret();
    } else if (!widget.editor.composer.selection!.isCollapsed) {
      // The selection is expanded.
      _controlsController!
        ..hideCollapsedHandle()
        ..showExpandedHandles()
        ..showToolbar()
        ..hideMagnifier()
        ..doNotBlinkCaret();
    }
  }

  void _onPanStart(DragStartDetails details) {
    // Stop waiting for a long-press to start, if a long press isn't already in-progress.
    _tapDownLongPressTimer?.cancel();

    _globalStartDragOffset = details.globalPosition;
    _dragStartInDoc = _getDocumentOffsetFromGlobalOffset(details.globalPosition);

    _startDragPositionOffset = _dragStartInDoc!;

    if (_isLongPressInProgress) {
      _onLongPressPanStart(details);
      return;
    }

    final isTapOverCaret = _isOverCaret(_globalTapDownOffset!);

    if (isTapOverCaret) {
      _onCaretDragPanStart(details);
      return;
    }
  }

  bool _isOverCaret(Offset globalOffset) {
    if (widget.editor.composer.selection?.isCollapsed != true) {
      return false;
    }

    final collapsedPosition = widget.editor.composer.selection?.extent;
    if (collapsedPosition == null) {
      return false;
    }

    final extentRect = _docLayout.getRectForPosition(collapsedPosition)!;
    final caretRect = Rect.fromLTWH(extentRect.left - 1, extentRect.center.dy, 1, 1).inflate(24);

    final tapDocumentOffset = widget.getDocumentLayout().getDocumentOffsetFromAncestorOffset(_globalTapDownOffset!);
    return caretRect.contains(tapDocumentOffset);
  }

  void _onLongPressPanStart(DragStartDetails details) {
    _longPressStrategy!.onLongPressDragStart(details);

    // Tell the overlay where to put the magnifier.
    _magnifierGlobalOffset.value = details.globalPosition;

    _controlsController!
      ..hideToolbar()
      ..showMagnifier();
  }

  void _onCaretDragPanStart(DragStartDetails details) {
    _isCaretDragInProgress = true;

    // Tell the overlay where to put the magnifier.
    _magnifierGlobalOffset.value = details.globalPosition;

    _controlsController!
      ..doNotBlinkCaret()
      ..hideToolbar()
      ..showMagnifier();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _globalDragOffset = details.globalPosition;

    if (_isLongPressInProgress) {
      _onLongPressPanUpdate(details);
      return;
    }

    if (_isCaretDragInProgress) {
      _onCaretDragPanUpdate(details);
      return;
    }
  }

  void _onLongPressPanUpdate(DragUpdateDetails details) {
    final fingerDragDelta = _globalDragOffset! - _globalStartDragOffset!;
    final fingerDocumentOffset = _docLayout.getDocumentOffsetFromAncestorOffset(details.globalPosition);
    final fingerDocumentPosition = _docLayout.getDocumentPositionNearestToOffset(
      _startDragPositionOffset! + fingerDragDelta,
    );
    _longPressStrategy!.onLongPressDragUpdate(fingerDocumentOffset, fingerDocumentPosition);
  }

  void _onCaretDragPanUpdate(DragUpdateDetails details) {
    final fingerDragDelta = _globalDragOffset! - _globalStartDragOffset!;
    final fingerDocumentPosition = _docLayout.getDocumentPositionNearestToOffset(
      _startDragPositionOffset! + fingerDragDelta,
    )!;
    if (fingerDocumentPosition != widget.editor.composer.selection!.extent) {
      HapticFeedback.lightImpact();
    }
    _selectPosition(fingerDocumentPosition);
  }

  void _updateLongPressSelection(DocumentSelection newSelection) {
    if (newSelection != widget.editor.composer.selection) {
      _select(newSelection);
      HapticFeedback.lightImpact();
    }

    // Note: this needs to happen even when the selection doesn't change, in case
    // some controls, like a magnifier, need to follower the user's finger.
    _updateOverlayControlsOnLongPressDrag();
  }

  void _updateOverlayControlsOnLongPressDrag() {
    final extentDocumentOffset = _docLayout.getRectForPosition(widget.editor.composer.selection!.extent)!.center;
    final extentGlobalOffset = _docLayout.getAncestorOffsetFromDocumentOffset(extentDocumentOffset);

    _magnifierGlobalOffset.value = extentGlobalOffset;
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isLongPressInProgress) {
      _onLongPressEnd();
      return;
    }

    if (_isCaretDragInProgress) {
      _onCaretDragEnd();
      return;
    }
  }

  void _onPanCancel() {
    // When _tapDownLongPressTimer is not null we're waiting for either tapUp or tapCancel,
    // which will deal with the long press.
    if (_tapDownLongPressTimer == null && _isLongPressInProgress) {
      _onLongPressEnd();
      return;
    }

    if (_isCaretDragInProgress) {
      _onCaretDragEnd();
      return;
    }
  }

  void _onLongPressEnd() {
    _longPressStrategy!.onLongPressEnd();

    // Cancel any on-going long-press.
    _longPressStrategy = null;
    _magnifierGlobalOffset.value = null;

    _controlsController!.hideMagnifier();
    if (!widget.editor.composer.selection!.isCollapsed) {
      _controlsController!
        ..showExpandedHandles()
        ..showToolbar();
    }
  }

  void _onCaretDragEnd() {
    _isCaretDragInProgress = false;

    _magnifierGlobalOffset.value = null;

    _controlsController!
      ..blinkCaret()
      ..hideMagnifier();
    if (!widget.editor.composer.selection!.isCollapsed) {
      _controlsController!
        ..showExpandedHandles()
        ..showToolbar();
    }
  }

  bool _selectWordAt({
    required DocumentPosition docPosition,
    required DocumentLayout docLayout,
  }) {
    final newSelection = getWordSelection(docPosition: docPosition, docLayout: docLayout);
    if (newSelection != null) {
      widget.editor.execute([
        ChangeSelectionRequest(
          newSelection,
          SelectionChangeType.expandSelection,
          SelectionReason.userInteraction,
        ),
        const ClearComposingRegionRequest(),
      ]);
      return true;
    } else {
      return false;
    }
  }

  bool _selectParagraphAt({
    required DocumentPosition docPosition,
    required DocumentLayout docLayout,
  }) {
    final newSelection = getParagraphSelection(docPosition: docPosition, docLayout: docLayout);
    if (newSelection != null) {
      widget.editor.execute([
        ChangeSelectionRequest(
          newSelection,
          SelectionChangeType.expandSelection,
          SelectionReason.userInteraction,
        ),
        const ClearComposingRegionRequest(),
      ]);
      return true;
    } else {
      return false;
    }
  }

  void _selectPosition(DocumentPosition position) {
    editorGesturesLog.fine("Setting document selection to $position");
    widget.editor.execute([
      ChangeSelectionRequest(
        DocumentSelection.collapsed(
          position: position,
        ),
        SelectionChangeType.placeCaret,
        SelectionReason.userInteraction,
      ),
      const ClearComposingRegionRequest(),
    ]);
  }

  void _select(DocumentSelection newSelection) {
    widget.editor.execute([
      ChangeSelectionRequest(
        newSelection,
        SelectionChangeType.expandSelection,
        SelectionReason.userInteraction,
      ),
      const ClearComposingRegionRequest(),
    ]);
  }

  void _clearSelection() {
    editorGesturesLog.fine("Clearing document selection");
    widget.editor.execute([
      const ClearSelectionRequest(),
      const ClearComposingRegionRequest(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final gestureSettings = MediaQuery.maybeOf(context)?.gestureSettings;
    // PanGestureRecognizer is above contents to have first pass at gestures, but it only accepts
    // gestures that are over caret or handles or when a long press is in progress.
    // TapGestureRecognizer is below contents so that it doesn't interferes with buttons and other
    // tappable widgets.
    return Stack(
      children: [
        // Layer below
        Positioned.fill(
          child: RawGestureDetector(
            behavior: HitTestBehavior.translucent,
            gestures: <Type, GestureRecognizerFactory>{
              TapSequenceGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapSequenceGestureRecognizer>(
                () => TapSequenceGestureRecognizer(),
                (TapSequenceGestureRecognizer recognizer) {
                  recognizer
                    ..onTapDown = _onTapDown
                    ..onTapCancel = _onTapCancel
                    ..onTapUp = _onTapUp
                    ..onDoubleTapDown = _onDoubleTapDown
                    ..onTripleTapDown = _onTripleTapDown
                    ..gestureSettings = gestureSettings;
                },
              ),
            },
          ),
        ),
        widget.child,
        // Layer above
        Positioned.fill(
          child: RawGestureDetector(
            key: _interactor,
            behavior: HitTestBehavior.translucent,
            gestures: <Type, GestureRecognizerFactory>{
              EagerPanGestureRecognizer: GestureRecognizerFactoryWithHandlers<EagerPanGestureRecognizer>(
                () => EagerPanGestureRecognizer(),
                (EagerPanGestureRecognizer instance) {
                  instance
                    ..shouldAccept = () {
                      if (_globalTapDownOffset == null) {
                        return false;
                      }
                      return _isOverCaret(_globalTapDownOffset!) || _isLongPressInProgress;
                    }
                    ..dragStartBehavior = DragStartBehavior.down
                    ..onStart = _onPanStart
                    ..onUpdate = _onPanUpdate
                    ..onEnd = _onPanEnd
                    ..onCancel = _onPanCancel
                    ..gestureSettings = gestureSettings;
                },
              ),
            },
          ),
        ),
      ],
    );
  }
}
