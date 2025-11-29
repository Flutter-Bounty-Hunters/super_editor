import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/document_gestures_touch_ios.dart';
import 'package:super_editor/src/default_editor/text_tools.dart';
import 'package:super_editor/src/document_operations/selection_operations.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/document_gestures_interaction_overrides.dart';
import 'package:super_editor/src/infrastructure/flutter/eager_pan_gesture_recognizer.dart';
import 'package:super_editor/src/infrastructure/flutter/flutter_scheduler.dart';
import 'package:super_editor/src/infrastructure/multi_tap_gesture.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/long_press_selection.dart';
import 'package:super_editor/src/infrastructure/read_only_use_cases.dart';
import 'package:super_editor/src/infrastructure/touch_controls.dart';
import 'package:super_editor/src/super_reader/read_only_document_ios_touch_interactor.dart';

/// Document gesture interactor that's designed for iOS touch input, e.g.,
/// drag to scroll, double and triple tap to select content, and drag
/// selection ends to expand selection.
///
/// The primary difference between a read-only touch interactor, and an
/// editing touch interactor, is that read-only documents don't support
/// collapsed selections, i.e., caret display. When the user taps on
/// a read-only document, nothing happens. The user must drag an expanded
/// selection, or double/triple tap to select content.
class SuperMessageIosTouchInteractor extends StatefulWidget {
  const SuperMessageIosTouchInteractor({
    Key? key,
    required this.focusNode,
    required this.messageContext,
    required this.documentKey,
    required this.getDocumentLayout,
    this.contentTapHandler,
    this.showDebugPaint = false,
    required this.child,
  }) : super(key: key);

  final FocusNode focusNode;

  final ReadOnlyContext messageContext;

  final GlobalKey documentKey;
  final DocumentLayout Function() getDocumentLayout;

  /// Optional handler that responds to taps on content, e.g., opening
  /// a link when the user taps on text with a link attribution.
  final ContentTapDelegate? contentTapHandler;

  final bool showDebugPaint;

  final Widget child;

  @override
  State createState() => _SuperMessageIosTouchInteractorState();
}

class _SuperMessageIosTouchInteractorState extends State<SuperMessageIosTouchInteractor>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  SuperReaderIosControlsController? _controlsController;

  Offset? _globalStartDragOffset;
  Offset? _dragStartInDoc;
  Offset? _startDragPositionOffset;
  Offset? _globalDragOffset;
  DragMode? _dragMode;

  // TODO: HandleType is the wrong type here, we need collapsed/base/extent,
  //       not collapsed/upstream/downstream. Change the type once it's working.
  HandleType? _dragHandleType;

  final _magnifierFocalPoint = ValueNotifier<Offset?>(null);

  Timer? _tapDownLongPressTimer;
  Offset? _globalTapDownOffset;
  bool get _isLongPressInProgress => _longPressStrategy != null;
  IosLongPressSelectionStrategy? _longPressStrategy;

  final _interactor = GlobalKey();

  @override
  void initState() {
    super.initState();

    widget.messageContext.document.addListener(_onDocumentChange);

    widget.messageContext.composer.selectionNotifier.addListener(_onSelectionChange);
    // If we already have a selection, we may need to display drag handles.
    if (widget.messageContext.composer.selection != null) {
      _onSelectionChange();
    }

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _controlsController = SuperReaderIosControlsScope.rootOf(context);
  }

  @override
  void didUpdateWidget(SuperMessageIosTouchInteractor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.messageContext.document != oldWidget.messageContext.document) {
      oldWidget.messageContext.document.removeListener(_onDocumentChange);
      widget.messageContext.document.addListener(_onDocumentChange);
    }

    if (widget.messageContext.composer != oldWidget.messageContext.composer) {
      oldWidget.messageContext.composer.selectionNotifier.removeListener(_onSelectionChange);
      widget.messageContext.composer.selectionNotifier.addListener(_onSelectionChange);

      // Selection has changed, we need to update the caret.
      if (widget.messageContext.composer.selection != oldWidget.messageContext.composer.selection) {
        _onSelectionChange();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    widget.messageContext.document.removeListener(_onDocumentChange);
    widget.messageContext.composer.selectionNotifier.removeListener(_onSelectionChange);

    super.dispose();
  }

  void _onDocumentChange(_) {
    _controlsController!.hideToolbar();

    onNextFrame((_) {
      // The user may have changed the type of node, e.g., paragraph to
      // blockquote, which impacts the caret size and position. Reposition
      // the caret on the next frame.
      // TODO: find a way to only do this when something relevant changes
      _updateHandlesAfterSelectionOrLayoutChange();
    });
  }

  void _onSelectionChange() {
    // The selection change might correspond to new content that's not
    // laid out yet. Wait until the next frame to update visuals.
    onNextFrame((_) => _updateHandlesAfterSelectionOrLayoutChange());
  }

  void _updateHandlesAfterSelectionOrLayoutChange() {
    final newSelection = widget.messageContext.composer.selection;

    if (newSelection == null) {
      _controlsController!.hideToolbar();
    }
  }

  /// Returns the layout for the current document, which answers questions
  /// about the locations and sizes of visual components within the layout.
  DocumentLayout get _docLayout => widget.getDocumentLayout();

  /// Returns the render box for the interactor gesture detector.
  RenderBox get interactorBox => _interactor.currentContext!.findRenderObject() as RenderBox;

  /// Converts the given [interactorOffset] from the [DocumentInteractor]'s coordinate
  /// space to the [DocumentLayout]'s coordinate space.
  Offset _interactorOffsetToDocumentOffset(Offset interactorOffset) {
    final globalOffset = interactorBox.localToGlobal(interactorOffset);
    return _docLayout.getDocumentOffsetFromAncestorOffset(globalOffset);
  }

  void _onTapDown(TapDownDetails details) {
    print("iOS gesture: tap down");
    _globalTapDownOffset = details.globalPosition;
    _tapDownLongPressTimer?.cancel();
    _tapDownLongPressTimer = Timer(kLongPressTimeout, _onLongPressDown);
  }

  void _onTapCancel() {
    print("iOS gesture: long press cancelled");
    _tapDownLongPressTimer?.cancel();
    _tapDownLongPressTimer = null;
  }

  // Runs when a tap down has lasted long enough to signify a long-press.
  void _onLongPressDown() {
    print("iOS gesture: long press down");
    final interactorOffset = interactorBox.globalToLocal(_globalTapDownOffset!);
    final tapDownDocumentOffset = _interactorOffsetToDocumentOffset(interactorOffset);
    final tapDownDocumentPosition = _docLayout.getDocumentPositionNearestToOffset(tapDownDocumentOffset);
    if (tapDownDocumentPosition == null) {
      print(" - couldn't map tap location to a document position");
      return;
    }

    if (_isOverBaseHandle(interactorOffset) || _isOverExtentHandle(interactorOffset)) {
      // Don't do anything for long presses over the handles, because we want the user
      // to be able to drag them without worrying about how long they've pressed.
      print(" - tap is over a handle, ignoring");
      return;
    }

    _globalDragOffset = _globalTapDownOffset;
    _longPressStrategy = IosLongPressSelectionStrategy(
      document: widget.messageContext.document,
      documentLayout: _docLayout,
      select: _select,
    );
    final didLongPressSelectionStart = _longPressStrategy!.onLongPressStart(
      tapDownDocumentOffset: tapDownDocumentOffset,
    );
    if (!didLongPressSelectionStart) {
      print(" - bailing because we got a long press down without a long press start");
      _longPressStrategy = null;
      return;
    }

    print(" - hiding toolbar and showing magnifier");
    _placeFocalPointNearTouchOffset();
    _controlsController!
      ..hideToolbar()
      ..showMagnifier();

    widget.focusNode.requestFocus();
  }

  void _onTapUp(TapUpDetails details) {
    print("iOS gesture: on tap up");
    // Stop waiting for a long-press to start.
    _globalTapDownOffset = null;
    _tapDownLongPressTimer?.cancel();
    _controlsController!.hideMagnifier();

    final selection = widget.messageContext.composer.selection;
    if (selection != null &&
        !selection.isCollapsed &&
        (_isOverBaseHandle(details.localPosition) || _isOverExtentHandle(details.localPosition))) {
      _controlsController!.toggleToolbar();
      return;
    }

    readerGesturesLog.info("Tap down on document");
    final docOffset = _interactorOffsetToDocumentOffset(details.localPosition);
    readerGesturesLog.fine(" - document offset: $docOffset");

    if (widget.contentTapHandler != null) {
      final result = widget.contentTapHandler!.onTap(
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

    final docPosition = _docLayout.getDocumentPositionNearestToOffset(docOffset);
    readerGesturesLog.fine(" - tapped document position: $docPosition");
    if (docPosition != null &&
        selection != null &&
        !selection.isCollapsed &&
        widget.messageContext.document.doesSelectionContainPosition(selection, docPosition)) {
      // The user tapped on an expanded selection. Toggle the toolbar.
      _controlsController!.toggleToolbar();
      return;
    }

    _clearSelection();
    _controlsController!.hideToolbar();

    widget.focusNode.requestFocus();
  }

  void _onDoubleTapUp(TapUpDetails details) {
    print("iOS gesture: on double tap up");
    final selection = widget.messageContext.composer.selection;
    if (selection != null &&
        !selection.isCollapsed &&
        (_isOverBaseHandle(details.localPosition) || _isOverExtentHandle(details.localPosition))) {
      return;
    }

    readerGesturesLog.info("Double tap down on document");
    final docOffset = _interactorOffsetToDocumentOffset(details.localPosition);
    readerGesturesLog.fine(" - document offset: $docOffset");

    if (widget.contentTapHandler != null) {
      final result = widget.contentTapHandler!.onDoubleTap(
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

    _clearSelection();

    final docPosition = _docLayout.getDocumentPositionNearestToOffset(docOffset);
    readerGesturesLog.fine(" - tapped document position: $docPosition");
    if (docPosition != null) {
      final tappedComponent = _docLayout.getComponentByNodeId(docPosition.nodeId)!;
      if (!tappedComponent.isVisualSelectionSupported()) {
        return;
      }

      _clearSelection();

      final wordSelection = getWordSelection(docPosition: docPosition, docLayout: _docLayout);
      var didSelectContent = wordSelection != null;
      if (wordSelection != null) {
        _setSelection(wordSelection);
        didSelectContent = true;
      }

      if (!didSelectContent) {
        final blockSelection = getBlockSelection(docPosition);
        if (blockSelection != null) {
          _setSelection(blockSelection);
          didSelectContent = true;
        }
      }
    }

    final newSelection = widget.messageContext.composer.selection;
    if (newSelection == null || newSelection.isCollapsed) {
      _controlsController!.hideToolbar();
    } else {
      _controlsController!.showToolbar();
    }

    widget.focusNode.requestFocus();
  }

  void _onTripleTapUp(TapUpDetails details) {
    readerGesturesLog.info("Triple down down on document");

    final docOffset = _interactorOffsetToDocumentOffset(details.localPosition);
    readerGesturesLog.fine(" - document offset: $docOffset");

    if (widget.contentTapHandler != null) {
      final result = widget.contentTapHandler!.onTripleTap(
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

    _clearSelection();

    final docPosition = _docLayout.getDocumentPositionNearestToOffset(docOffset);
    readerGesturesLog.fine(" - tapped document position: $docPosition");
    if (docPosition != null) {
      final tappedComponent = _docLayout.getComponentByNodeId(docPosition.nodeId)!;
      if (!tappedComponent.isVisualSelectionSupported()) {
        return;
      }

      final paragraphSelection = getParagraphSelection(docPosition: docPosition, docLayout: _docLayout);
      if (paragraphSelection != null) {
        _setSelection(paragraphSelection);
      }
    }

    final selection = widget.messageContext.composer.selection;
    if (selection == null || selection.isCollapsed) {
      _controlsController!.hideToolbar();
    } else {
      _controlsController!.showToolbar();
    }

    widget.focusNode.requestFocus();
  }

  void _onPanDown(DragDownDetails details) {
    // No-op: this method is only here to beat out any ancestor
    // Scrollable that's also trying to drag.
  }

  void _onPanStart(DragStartDetails details) {
    // Stop waiting for a long-press to start, if a long press isn't already in-progress.
    _globalTapDownOffset = null;
    _tapDownLongPressTimer?.cancel();

    // TODO: to help the user drag handles instead of scrolling, try checking touch
    //       placement during onTapDown, and then pick that up here. I think the little
    //       bit of slop might be the problem.
    final selection = widget.messageContext.composer.selection;
    if (selection == null) {
      return;
    }

    if (_isLongPressInProgress) {
      _dragMode = DragMode.longPress;
      _dragHandleType = null;
      _longPressStrategy!.onLongPressDragStart();
    } else if (_isOverBaseHandle(details.localPosition)) {
      _dragMode = DragMode.base;
      _dragHandleType = HandleType.upstream;
    } else if (_isOverExtentHandle(details.localPosition)) {
      _dragMode = DragMode.extent;
      _dragHandleType = HandleType.downstream;
    } else {
      return;
    }

    _controlsController!.hideToolbar();

    _updateDragStartLocation(details.globalPosition);
  }

  bool _isOverBaseHandle(Offset interactorOffset) {
    final basePosition = widget.messageContext.composer.selection?.base;
    if (basePosition == null) {
      return false;
    }

    final baseRect = _docLayout.getRectForPosition(basePosition)!;
    // The following caretRect offset and size were chosen empirically, based
    // on trying to drag the handle from various locations near the handle.
    final caretRect = Rect.fromLTWH(baseRect.left - 24, baseRect.top - 24, 48, baseRect.height + 48);

    final docOffset = _interactorOffsetToDocumentOffset(interactorOffset);
    return caretRect.contains(docOffset);
  }

  bool _isOverExtentHandle(Offset interactorOffset) {
    final extentPosition = widget.messageContext.composer.selection?.extent;
    if (extentPosition == null) {
      return false;
    }

    final extentRect = _docLayout.getRectForPosition(extentPosition)!;
    // The following caretRect offset and size were chosen empirically, based
    // on trying to drag the handle from various locations near the handle.
    final caretRect = Rect.fromLTWH(extentRect.left - 24, extentRect.top, 48, extentRect.height + 32);

    final docOffset = _interactorOffsetToDocumentOffset(interactorOffset);
    return caretRect.contains(docOffset);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    // The user is dragging a handle. Update the document selection, and
    // auto-scroll, if needed.
    _globalDragOffset = details.globalPosition;

    if (_isLongPressInProgress) {
      final fingerDragDelta = _globalDragOffset! - _globalStartDragOffset!;
      final fingerDocumentOffset = _docLayout.getDocumentOffsetFromAncestorOffset(details.globalPosition);
      final fingerDocumentPosition = _docLayout.getDocumentPositionNearestToOffset(
        _startDragPositionOffset! + fingerDragDelta,
      );
      _longPressStrategy!.onLongPressDragUpdate(fingerDocumentOffset, fingerDocumentPosition);
    } else {
      _updateSelectionForNewDragHandleLocation();
    }

    _controlsController!.showMagnifier();

    _placeFocalPointNearTouchOffset();
  }

  void _updateSelectionForNewDragHandleLocation() {
    final docDragDelta = _globalDragOffset! - _globalStartDragOffset!;
    final docDragPosition = _docLayout.getDocumentPositionNearestToOffset(_startDragPositionOffset! + docDragDelta);

    if (docDragPosition == null) {
      return;
    }

    if (_dragHandleType == HandleType.upstream) {
      _setSelection(widget.messageContext.composer.selection!.copyWith(
        base: docDragPosition,
      ));
    } else if (_dragHandleType == HandleType.downstream) {
      _setSelection(widget.messageContext.composer.selection!.copyWith(
        extent: docDragPosition,
      ));
    }
  }

  void _onPanEnd(DragEndDetails details) {}

  void _onPanCancel() {
    if (_dragMode != null) {
      _onDragSelectionEnd();
    }
  }

  void _onDragSelectionEnd() {
    if (_dragMode == DragMode.longPress) {
      _onLongPressEnd();
    } else {
      _onHandleDragEnd();
    }
  }

  void _onLongPressEnd() {
    _longPressStrategy!.onLongPressEnd();
    _longPressStrategy = null;
    _dragMode = null;

    _updateOverlayControlsAfterFinishingDragSelection();
  }

  void _onHandleDragEnd() {
    _dragMode = null;

    _updateOverlayControlsAfterFinishingDragSelection();
  }

  void _updateOverlayControlsAfterFinishingDragSelection() {
    _controlsController!.hideMagnifier();
    if (!widget.messageContext.composer.selection!.isCollapsed) {
      _controlsController!.showToolbar();
    } else {
      // Read-only documents don't support collapsed selections.
      _clearSelection();
    }
  }

  void _select(DocumentSelection newSelection) {
    _setSelection(newSelection);
  }

  /// Updates the magnifier focal point in relation to the current drag position.
  void _placeFocalPointNearTouchOffset() {
    late DocumentPosition? docPositionToMagnify;

    if (_globalTapDownOffset != null) {
      // A drag isn't happening. Magnify the position that the user tapped.
      docPositionToMagnify = _docLayout.getDocumentPositionNearestToOffset(_globalTapDownOffset!);
    } else {
      final docDragDelta = _globalDragOffset! - _globalStartDragOffset!;
      docPositionToMagnify = _docLayout.getDocumentPositionNearestToOffset(_startDragPositionOffset! + docDragDelta);
    }

    final centerOfContentAtOffset = _interactorOffsetToDocumentOffset(
      _docLayout.getRectForPosition(docPositionToMagnify!)!.center,
    );

    _magnifierFocalPoint.value = centerOfContentAtOffset;
  }

  void _updateDragStartLocation(Offset globalOffset) {
    _globalStartDragOffset = globalOffset;
    final handleOffsetInInteractor = interactorBox.globalToLocal(globalOffset);
    _dragStartInDoc = _interactorOffsetToDocumentOffset(handleOffsetInInteractor);

    final selection = widget.messageContext.composer.selection;
    if (_dragHandleType != null && selection != null) {
      _startDragPositionOffset = _docLayout
          .getRectForPosition(
            _dragHandleType! == HandleType.upstream ? selection.base : selection.extent,
          )!
          .center;
    } else {
      // User is long-press dragging, which is why there's no drag handle type.
      // In this case, the start drag offset is wherever the user touched.
      _startDragPositionOffset = _dragStartInDoc!;
    }
  }

  void _setSelection(DocumentSelection selection) {
    widget.messageContext.editor.execute([
      ChangeSelectionRequest(
        selection,
        SelectionChangeType.clearSelection,
        SelectionReason.userInteraction,
      ),
    ]);
  }

  void _clearSelection() {
    widget.messageContext.editor.execute([
      const ChangeSelectionRequest(
        null,
        SelectionChangeType.clearSelection,
        SelectionReason.userInteraction,
      ),
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
            behavior: HitTestBehavior.opaque,
            gestures: <Type, GestureRecognizerFactory>{
              TapSequenceGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapSequenceGestureRecognizer>(
                () => TapSequenceGestureRecognizer(),
                (TapSequenceGestureRecognizer recognizer) {
                  recognizer
                    ..onTapDown = _onTapDown
                    ..onTapCancel = _onTapCancel
                    ..onTapUp = _onTapUp
                    ..onDoubleTapUp = _onDoubleTapUp
                    ..onTripleTapUp = _onTripleTapUp
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
                      final panDown = interactorBox.globalToLocal(_globalTapDownOffset!);
                      final isOverHandle = _isOverBaseHandle(panDown) || _isOverExtentHandle(panDown);
                      return isOverHandle || _isLongPressInProgress;
                    }
                    ..dragStartBehavior = DragStartBehavior.down
                    ..onDown = _onPanDown
                    ..onStart = _onPanStart
                    ..onUpdate = _onPanUpdate
                    ..onEnd = _onPanEnd
                    ..onCancel = _onPanCancel
                    ..gestureSettings = gestureSettings;
                },
              ),
            },
            child: Stack(
              children: [
                _buildMagnifierFocalPoint(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMagnifierFocalPoint() {
    return ValueListenableBuilder(
      valueListenable: _magnifierFocalPoint,
      builder: (context, magnifierOffset, child) {
        if (magnifierOffset == null) {
          return const SizedBox();
        }

        // When the user is dragging a handle in this overlay, we
        // are responsible for positioning the focal point for the
        // magnifier to follow. We do that here.
        return Positioned(
          left: magnifierOffset.dx,
          top: magnifierOffset.dy,
          child: Leader(
            link: _controlsController!.magnifierFocalPoint,
            child: const SizedBox(width: 1, height: 1),
          ),
        );
      },
    );
  }
}
