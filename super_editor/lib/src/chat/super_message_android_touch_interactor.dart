import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/document_gestures_touch_android.dart';
import 'package:super_editor/src/document_operations/selection_operations.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/document_gestures_interaction_overrides.dart';
import 'package:super_editor/src/infrastructure/documents/selection_leader_document_layer.dart';
import 'package:super_editor/src/infrastructure/flutter/eager_pan_gesture_recognizer.dart';
import 'package:super_editor/src/infrastructure/flutter/flutter_scheduler.dart';
import 'package:super_editor/src/infrastructure/flutter/overlay_with_groups.dart';
import 'package:super_editor/src/infrastructure/multi_tap_gesture.dart';
import 'package:super_editor/src/infrastructure/platforms/android/android_document_controls.dart';
import 'package:super_editor/src/infrastructure/platforms/android/long_press_selection.dart';
import 'package:super_editor/src/infrastructure/platforms/mobile_documents.dart';
import 'package:super_editor/src/infrastructure/read_only_use_cases.dart';
import 'package:super_editor/src/infrastructure/signal_notifier.dart';
import 'package:super_editor/src/infrastructure/touch_controls.dart';
import 'package:super_editor/src/super_reader/read_only_document_android_touch_interactor.dart'
    show AndroidDocumentTouchEditingControls;
import 'package:super_editor/src/super_textfield/metrics.dart';

import '../default_editor/text_tools.dart';

/// Read-only document gesture interactor that's designed for Android touch input, e.g.,
/// drag to scroll, and handles to control selection.
///
/// The primary difference between a read-only touch interactor, and an
/// editing touch interactor, is that read-only documents don't support
/// collapsed selections, i.e., caret display. When the user taps on
/// a read-only document, nothing happens. The user must drag an expanded
/// selection, or double/triple tap to select content.
class SuperMessageAndroidTouchInteractor extends StatefulWidget {
  const SuperMessageAndroidTouchInteractor({
    Key? key,
    required this.focusNode,
    this.tapRegionGroupId,
    required this.messageContext,
    required this.documentKey,
    required this.getDocumentLayout,
    required this.selectionLinks,
    this.contentTapHandler,
    required this.handleColor,
    required this.popoverToolbarBuilder,
    this.createOverlayControlsClipper,
    this.showDebugPaint = false,
    this.overlayController,
    required this.child,
  }) : super(key: key);

  final FocusNode focusNode;

  /// {@macro super_reader_tap_region_group_id}
  final String? tapRegionGroupId;

  final ReadOnlyContext messageContext;

  final GlobalKey documentKey;
  final DocumentLayout Function() getDocumentLayout;

  final SelectionLayerLinks selectionLinks;

  /// Optional handler that responds to taps on content, e.g., opening
  /// a link when the user taps on text with a link attribution.
  final ContentTapDelegate? contentTapHandler;

  /// The color of the Android-style drag handles.
  final Color handleColor;

  final WidgetBuilder popoverToolbarBuilder;

  /// Creates a clipper that applies to overlay controls, preventing
  /// the overlay controls from appearing outside the given clipping
  /// region.
  ///
  /// If no clipper factory method is provided, then the overlay controls
  /// will be allowed to appear anywhere in the overlay in which they sit
  /// (probably the entire screen).
  final CustomClipper<Rect> Function(BuildContext overlayContext)? createOverlayControlsClipper;

  /// Shows, hides, and positions a floating toolbar and magnifier.
  final MagnifierAndToolbarController? overlayController;

  final bool showDebugPaint;

  final Widget child;

  @override
  State createState() => _SuperMessageAndroidTouchInteractorState();
}

class _SuperMessageAndroidTouchInteractorState extends State<SuperMessageAndroidTouchInteractor>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // Overlay controller that displays editing controls, e.g., drag handles,
  // magnifier, and toolbar.
  final _overlayPortalController =
      GroupedOverlayPortalController(displayPriority: OverlayGroupPriority.editingControls);
  final _overlayPortalRebuildSignal = SignalNotifier();
  late AndroidDocumentGestureEditingController _editingController;
  final _magnifierFocalPointLink = LeaderLink();

  Offset? _globalStartDragOffset;
  Offset? _dragStartInDoc;
  Offset? _startDragPositionOffset;
  Offset? _globalDragOffset;
  SelectionHandleType? _handleType;

  /// Shows, hides, and positions a floating toolbar and magnifier.
  late MagnifierAndToolbarController _overlayController;

  Timer? _tapDownLongPressTimer;
  Offset? _globalTapDownOffset;
  bool get _isLongPressInProgress => _longPressStrategy != null;
  AndroidDocumentLongPressSelectionStrategy? _longPressStrategy;
  final _longPressMagnifierGlobalOffset = ValueNotifier<Offset?>(null);

  final _interactor = GlobalKey();

  @override
  void initState() {
    super.initState();

    widget.focusNode.addListener(_onFocusChange);
    if (widget.focusNode.hasFocus) {
      _showEditingControlsOverlay();
    }

    _overlayController = widget.overlayController ?? MagnifierAndToolbarController();

    _editingController = AndroidDocumentGestureEditingController(
      selectionLinks: widget.selectionLinks,
      magnifierFocalPointLink: _magnifierFocalPointLink,
      overlayController: _overlayController,
    );

    widget.messageContext.document.addListener(_onDocumentChange);
    widget.messageContext.composer.selectionNotifier.addListener(_onSelectionChange);

    // If we already have a selection, we need to display the caret.
    if (widget.messageContext.composer.selection != null) {
      _onSelectionChange();
    }

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(SuperMessageAndroidTouchInteractor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
    }

    if (widget.messageContext.document != oldWidget.messageContext.document) {
      oldWidget.messageContext.document.removeListener(_onDocumentChange);
      widget.messageContext.document.addListener(_onDocumentChange);
    }

    if (widget.messageContext.composer != oldWidget.messageContext.composer) {
      oldWidget.messageContext.composer.selectionNotifier.removeListener(_onSelectionChange);
      widget.messageContext.composer.selectionNotifier.addListener(_onSelectionChange);
    }

    if (widget.overlayController != oldWidget.overlayController) {
      _overlayController = widget.overlayController ?? MagnifierAndToolbarController();
      _editingController.overlayController = _overlayController;
    }

    // Selection has changed, we need to update the caret.
    if (widget.messageContext.composer.selection != oldWidget.messageContext.composer.selection) {
      _onSelectionChange();
    }
  }

  @override
  void reassemble() {
    super.reassemble();

    if (widget.focusNode.hasFocus) {
      // On Hot Reload we need to remove any visible overlay controls and then
      // bring them back a frame later to avoid having the controls attempt
      // to access the layout of the text. The text layout is not immediately
      // available upon Hot Reload. Accessing it results in an exception.
      // TODO: this was copied from Super Textfield, see if the timing
      //       problem exists for documents, too.
      _removeEditingOverlayControls();

      onNextFrame((_) => _showEditingControlsOverlay());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // We dispose the EditingController on the next frame because
    // the ListenableBuilder that uses it throws an error if we
    // dispose of it here.
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _editingController.dispose();
    });

    widget.messageContext.document.removeListener(_onDocumentChange);
    widget.messageContext.composer.selectionNotifier.removeListener(_onSelectionChange);

    widget.focusNode.removeListener(_onFocusChange);

    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // The available screen dimensions may have changed, e.g., due to keyboard
    // appearance/disappearance. Reflow the layout. Use a post-frame callback
    // to give the rest of the UI a chance to reflow, first.
    onNextFrame((_) {
      _updateHandlesAfterSelectionOrLayoutChange();

      setState(() {
        // reflow document layout
      });
    });
  }

  void _onFocusChange() {
    if (widget.focusNode.hasFocus) {
      // TODO: the text field only showed the editing controls if the text input
      //       client wasn't attached yet. Do we need a similar check here?
      _showEditingControlsOverlay();
    } else {
      _removeEditingOverlayControls();
    }
  }

  void _onDocumentChange(_) {
    _editingController.hideToolbar();

    onNextFrame((_) {
      // The user may have changed the type of node, e.g., paragraph to
      // blockquote, which impacts the caret size and position. Reposition
      // the caret on the next frame.
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
      _editingController
        ..removeCaret()
        ..hideToolbar()
        ..collapsedHandleOffset = null
        ..upstreamHandleOffset = null
        ..downstreamHandleOffset = null
        ..collapsedHandleOffset = null
        ..cancelCollapsedHandleAutoHideCountdown();
    } else if (!newSelection.isCollapsed) {
      _positionExpandedHandles();
    }
  }

  /// Returns the layout for the current document, which answers questions
  /// about the locations and sizes of visual components within the layout.
  DocumentLayout get _docLayout => widget.getDocumentLayout();

  /// Returns the render box for the interactor gesture detector.
  RenderBox get interactorBox => _interactor.currentContext!.findRenderObject() as RenderBox;

  Offset _getDocumentOffsetFromGlobalOffset(Offset globalOffset) {
    return _docLayout.getDocumentOffsetFromAncestorOffset(globalOffset);
  }

  /// Converts the given [interactorOffset] from the [DocumentInteractor]'s coordinate
  /// space to the [DocumentLayout]'s coordinate space.
  Offset _interactorOffsetToDocOffset(Offset interactorOffset) {
    final globalOffset = interactorBox.localToGlobal(interactorOffset);
    return _docLayout.getDocumentOffsetFromAncestorOffset(globalOffset);
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
      document: widget.messageContext.document,
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
    _editingController
      ..disallowHandles()
      ..hideMagnifier()
      ..showToolbar();
    _positionToolbar();
    _overlayPortalRebuildSignal.notifyListeners();

    widget.focusNode.requestFocus();
  }

  void _onTapUp(TapUpDetails details) {
    // Stop waiting for a long-press to start.
    _globalTapDownOffset = null;
    _tapDownLongPressTimer?.cancel();

    // Cancel any on-going long-press.
    if (_isLongPressInProgress) {
      _longPressStrategy = null;
      _longPressMagnifierGlobalOffset.value = null;

      // We hide the selection handles when long-press dragging, despite having
      // an expanded selection. Allow the handles to come back.
      _editingController.allowHandles();
      _overlayPortalRebuildSignal.notifyListeners();

      return;
    }

    readerGesturesLog.info("Tap down on document");
    final docOffset = _interactorOffsetToDocOffset(details.localPosition);
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

    if (docPosition == null) {
      _clearSelection();
      _editingController.hideToolbar();
      widget.focusNode.requestFocus();

      return;
    }

    final selection = widget.messageContext.composer.selection;
    final didTapOnExistingSelection =
        selection != null && widget.messageContext.document.doesSelectionContainPosition(selection, docPosition);
    if (didTapOnExistingSelection) {
      // Toggle the toolbar display when the user taps on the collapsed caret,
      // or on top of an existing selection.
      _editingController.toggleToolbar();
    } else {
      // The user tapped somewhere else in the document. Hide the toolbar.
      _editingController.hideToolbar();
      _clearSelection();
    }

    widget.focusNode.requestFocus();
  }

  void _onDoubleTapDown(TapDownDetails details) {
    readerGesturesLog.info("Double tap down on document");
    final docOffset = _interactorOffsetToDocOffset(details.localPosition);
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
      // The user tapped a non-selectable component, so we can't select a word.
      // The editor will remain focused and selection will remain in the nearest
      // selectable component, as set in _onTapUp.
      final tappedComponent = _docLayout.getComponentByNodeId(docPosition.nodeId)!;
      if (!tappedComponent.isVisualSelectionSupported()) {
        return;
      }

      final wordSelection = getWordSelection(docPosition: docPosition, docLayout: _docLayout);
      var didSelectContent = wordSelection != null;
      if (wordSelection != null) {
        _setSelection(wordSelection);
      }

      if (!didSelectContent) {
        final blockSelection = getBlockSelection(docPosition);
        if (blockSelection != null) {
          _setSelection(blockSelection);
          didSelectContent = true;
        }
      }

      if (widget.messageContext.composer.selection != null) {
        if (!widget.messageContext.composer.selection!.isCollapsed) {
          _editingController.showToolbar();
          _positionToolbar();
        }
      }
    }

    widget.focusNode.requestFocus();
  }

  void _onTripleTapDown(TapDownDetails details) {
    readerGesturesLog.info("Triple down down on document");
    final docOffset = _interactorOffsetToDocOffset(details.localPosition);
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
      // The user tapped a non-selectable component, so we can't select a paragraph.
      // The editor will remain focused and selection will remain in the nearest
      // selectable component, as set in _onTapUp.
      final tappedComponent = _docLayout.getComponentByNodeId(docPosition.nodeId)!;
      if (!tappedComponent.isVisualSelectionSupported()) {
        return;
      }

      final paragraphSelection = getParagraphSelection(
        docPosition: docPosition,
        docLayout: _docLayout,
      );
      if (paragraphSelection != null) {
        _setSelection(paragraphSelection);
      }
    }

    widget.focusNode.requestFocus();
  }

  void _onPanStart(DragStartDetails details) {
    // Stop waiting for a long-press to start, if a long press isn't already in-progress.
    _globalTapDownOffset = null;
    _tapDownLongPressTimer?.cancel();

    _globalStartDragOffset = details.globalPosition;
    _dragStartInDoc = _getDocumentOffsetFromGlobalOffset(details.globalPosition);
    _startDragPositionOffset = _dragStartInDoc!;

    if (_isLongPressInProgress) {
      _longPressStrategy!.onLongPressDragStart(details);
    }

    // Tell the overlay where to put the magnifier.
    _longPressMagnifierGlobalOffset.value = details.globalPosition;

    _editingController
      ..hideToolbar()
      ..showMagnifier();
    _overlayPortalRebuildSignal.notifyListeners();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isLongPressInProgress) {
      _globalDragOffset = details.globalPosition;

      final fingerDragDelta = _globalDragOffset! - _globalStartDragOffset!;
      final fingerDocumentOffset = _docLayout.getDocumentOffsetFromAncestorOffset(details.globalPosition);
      final fingerDocumentPosition = _docLayout.getDocumentPositionNearestToOffset(
        _startDragPositionOffset! + fingerDragDelta,
      );
      _longPressStrategy!.onLongPressDragUpdate(fingerDocumentOffset, fingerDocumentPosition);
      return;
    }
  }

  void _updateLongPressSelection(DocumentSelection newSelection) {
    if (newSelection != widget.messageContext.composer.selection) {
      _setSelection(newSelection);
      HapticFeedback.lightImpact();
    }

    // Note: this needs to happen even when the selection doesn't change, in case
    // some controls, like a magnifier, need to follower the user's finger.
    _updateOverlayControlsOnLongPressDrag();
  }

  void _updateOverlayControlsOnLongPressDrag() {
    final extentDocumentOffset =
        _docLayout.getRectForPosition(widget.messageContext.composer.selection!.extent)!.center;
    final extentGlobalOffset = _docLayout.getAncestorOffsetFromDocumentOffset(extentDocumentOffset);

    _longPressMagnifierGlobalOffset.value = extentGlobalOffset;
    _overlayPortalRebuildSignal.notifyListeners();
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isLongPressInProgress) {
      _onLongPressEnd();
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
  }

  void _onLongPressEnd() {
    _longPressStrategy!.onLongPressEnd();

    // Cancel any on-going long-press.
    _longPressStrategy = null;
    _longPressMagnifierGlobalOffset.value = null;

    _editingController
      ..allowHandles()
      ..hideMagnifier();
    if (!widget.messageContext.composer.selection!.isCollapsed) {
      _editingController.showToolbar();
      _positionToolbar();
    }
    _overlayPortalRebuildSignal.notifyListeners();
  }

  void _showEditingControlsOverlay() {
    _overlayPortalController.show();
  }

  void _removeEditingOverlayControls() {
    _overlayPortalController.hide();
  }

  void _onHandleDragStart(HandleType handleType, Offset globalOffset) {
    final selectionAffinity = widget.messageContext.document.getAffinityForSelection(
      widget.messageContext.composer.selection!,
    );
    switch (handleType) {
      case HandleType.collapsed:
        // no-op for read-only documents
        break;
      case HandleType.upstream:
        _handleType = selectionAffinity == TextAffinity.downstream
            ? SelectionHandleType.upstream
            : SelectionHandleType.downstream;
        break;
      case HandleType.downstream:
        _handleType = selectionAffinity == TextAffinity.downstream
            ? SelectionHandleType.downstream
            : SelectionHandleType.upstream;
        break;
    }

    _globalStartDragOffset = globalOffset;
    final handleOffsetInInteractor = interactorBox.globalToLocal(globalOffset);
    _dragStartInDoc = _interactorOffsetToDocOffset(handleOffsetInInteractor);

    _startDragPositionOffset = _docLayout
        .getRectForPosition(
          _handleType == SelectionHandleType.upstream
              ? widget.messageContext.composer.selection!.base
              : widget.messageContext.composer.selection!.extent,
        )!
        .center;
  }

  void _onHandleDragUpdate(Offset globalOffset) {
    _globalDragOffset = globalOffset;

    _updateSelectionForNewDragHandleLocation();

    _editingController.showMagnifier();
  }

  void _updateSelectionForNewDragHandleLocation() {
    final docDragDelta = _globalDragOffset! - _globalStartDragOffset!;
    final docDragPosition = _docLayout.getDocumentPositionNearestToOffset(_startDragPositionOffset! + docDragDelta);

    if (docDragPosition == null) {
      return;
    }

    if (_handleType == SelectionHandleType.upstream) {
      _setSelection(widget.messageContext.composer.selection!.copyWith(
        base: docDragPosition,
      ));
    } else if (_handleType == SelectionHandleType.downstream) {
      _setSelection(widget.messageContext.composer.selection!.copyWith(
        extent: docDragPosition,
      ));
    }
  }

  void _onHandleDragEnd() {
    _editingController.hideMagnifier();

    _dragStartInDoc = null;

    if (widget.messageContext.composer.selection!.isCollapsed) {
      // The selection is collapsed. Read-only documents don't display
      // collapsed selections. Clear the selection.
      _clearSelection();
    } else {
      _editingController.showToolbar();
      _positionToolbar();
    }
  }

  void _positionExpandedHandles() {
    final selection = widget.messageContext.composer.selection;
    if (selection == null) {
      readerGesturesLog.shout("Tried to update expanded handle offsets but there is no document selection");
      return;
    }
    if (selection.isCollapsed) {
      readerGesturesLog.shout("Tried to update expanded handle offsets but the selection is collapsed");
      return;
    }

    // Calculate the new rectangles for the upstream and downstream handles.
    final baseHandleRect = _docLayout.getRectForPosition(selection.base)!;
    final extentHandleRect = _docLayout.getRectForPosition(selection.extent)!;
    final affinity = widget.messageContext.document.getAffinityBetween(base: selection.base, extent: selection.extent);
    late Rect upstreamHandleRect = affinity == TextAffinity.downstream ? baseHandleRect : extentHandleRect;
    late Rect downstreamHandleRect = affinity == TextAffinity.downstream ? extentHandleRect : baseHandleRect;

    _editingController
      ..removeCaret()
      ..collapsedHandleOffset = null
      ..upstreamHandleOffset = upstreamHandleRect.bottomLeft
      ..downstreamHandleOffset = downstreamHandleRect.bottomRight
      ..cancelCollapsedHandleAutoHideCountdown();
  }

  void _positionToolbar() {
    if (!_editingController.shouldDisplayToolbar) {
      return;
    }

    final selection = widget.messageContext.composer.selection!;
    if (selection.isCollapsed) {
      readerGesturesLog.warning(
          "Tried to position toolbar for a collapsed selection in a read-only interactor. Collapsed selections shouldn't exist.");
      return;
    }

    late Rect selectionRect;
    Offset toolbarTopAnchor;
    Offset toolbarBottomAnchor;

    // TODO: The following behavior looks like its calculating a bounding box. Should we use
    //       getRectForSelection instead?
    final baseRectInDoc = _docLayout.getRectForPosition(selection.base)!;
    final extentRectInDoc = _docLayout.getRectForPosition(selection.extent)!;
    final selectionRectInDoc = Rect.fromPoints(
      Offset(
        min(baseRectInDoc.left, extentRectInDoc.left),
        min(baseRectInDoc.top, extentRectInDoc.top),
      ),
      Offset(
        max(baseRectInDoc.right, extentRectInDoc.right),
        max(baseRectInDoc.bottom, extentRectInDoc.bottom),
      ),
    );
    selectionRect = Rect.fromPoints(
      _docLayout.getGlobalOffsetFromDocumentOffset(selectionRectInDoc.topLeft),
      _docLayout.getGlobalOffsetFromDocumentOffset(selectionRectInDoc.bottomRight),
    );

    // TODO: fix the horizontal placement
    //       The logic to position the toolbar horizontally is wrong.
    //       The toolbar should appear horizontally centered between the
    //       left-most and right-most edge of the selection. However, the
    //       left-most and right-most edge of the selection may not match
    //       the handle locations. Consider the situation where multiple
    //       lines/blocks of content are selected, but both handles sit near
    //       the left side of the screen. This logic will position the
    //       toolbar near the left side of the content, when the toolbar should
    //       instead be centered across the full width of the document.
    toolbarTopAnchor = selectionRect.topCenter - const Offset(0, gapBetweenToolbarAndContent);
    toolbarBottomAnchor = selectionRect.bottomCenter + const Offset(0, gapBetweenToolbarAndContent);

    _editingController.positionToolbar(
      topAnchor: toolbarTopAnchor,
      bottomAnchor: toolbarBottomAnchor,
    );
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
          child: OverlayPortal(
            controller: _overlayPortalController,
            overlayChildBuilder: _buildControlsOverlay,
            child: RawGestureDetector(
              key: _interactor,
              behavior: HitTestBehavior.translucent,
              gestures: <Type, GestureRecognizerFactory>{
                EagerPanGestureRecognizer: GestureRecognizerFactoryWithHandlers<EagerPanGestureRecognizer>(
                  () => EagerPanGestureRecognizer(),
                  (EagerPanGestureRecognizer recognizer) {
                    recognizer
                      ..shouldAccept = () {
                        if (_globalTapDownOffset == null) {
                          return false;
                        }
                        return _isLongPressInProgress;
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
        ),
      ],
    );
  }

  Widget _buildControlsOverlay(BuildContext context) {
    return TapRegion(
      groupId: widget.tapRegionGroupId,
      child: ListenableBuilder(
        listenable: _overlayPortalRebuildSignal,
        builder: (context, child) {
          return AndroidDocumentTouchEditingControls(
            editingController: _editingController,
            documentKey: widget.documentKey,
            documentLayout: _docLayout,
            createOverlayControlsClipper: widget.createOverlayControlsClipper,
            handleColor: widget.handleColor,
            onHandleDragStart: _onHandleDragStart,
            onHandleDragUpdate: _onHandleDragUpdate,
            onHandleDragEnd: _onHandleDragEnd,
            popoverToolbarBuilder: widget.popoverToolbarBuilder,
            longPressMagnifierGlobalOffset: _longPressMagnifierGlobalOffset,
            showDebugPaint: false,
          );
        },
      ),
    );
  }
}
