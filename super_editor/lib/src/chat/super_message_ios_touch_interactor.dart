import 'dart:async';

import 'package:flutter/foundation.dart';
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
import 'package:super_editor/src/infrastructure/platforms/mobile_documents.dart';
import 'package:super_editor/src/infrastructure/document_context.dart';
import 'package:super_editor/src/infrastructure/touch_controls.dart';

/// An [InheritedWidget] that provides shared access to a [SuperMessageIosControlsController],
/// which coordinates the state of iOS controls like drag handles, magnifier, and toolbar.
///
/// This widget and its associated controller exist so that [SuperMessage] has maximum freedom
/// in terms of where to implement iOS gestures vs handles vs the magnifier vs the toolbar.
/// Each of these responsibilities have some unique differences, which make them difficult
/// or impossible to implement within a single widget. By sharing a controller, a group of
/// independent widgets can work together to cover those various responsibilities.
///
/// Centralizing a controller in an [InheritedWidget] also allows [SuperMessage] to share that
/// control with application code outside of [SuperMessage], by placing an [SuperMessageIosControlsScope]
/// above the [SuperMessage] in the widget tree. For this reason, [SuperMessage] should access
/// the [SuperMessageIosControlsScope] through [rootOf].
class SuperMessageIosControlsScope extends InheritedWidget {
  /// Finds the highest [SuperMessageIosControlsScope] in the widget tree, above the given
  /// [context], and returns its associated [SuperMessageIosControlsController].
  static SuperMessageIosControlsController rootOf(BuildContext context) {
    final data = maybeRootOf(context);

    if (data == null) {
      throw Exception("Tried to depend upon the root IosReaderControlsScope but no such ancestor widget exists.");
    }

    return data;
  }

  static SuperMessageIosControlsController? maybeRootOf(BuildContext context) {
    InheritedElement? root;

    context.visitAncestorElements((element) {
      if (element is! InheritedElement || element.widget is! SuperMessageIosControlsScope) {
        // Keep visiting.
        return true;
      }

      root = element;

      // Keep visiting, to ensure we get the root scope.
      return true;
    });

    if (root == null) {
      return null;
    }

    // Create build dependency on the iOS controls context.
    context.dependOnInheritedElement(root!);

    // Return the current iOS controls data.
    return (root!.widget as SuperMessageIosControlsScope).controller;
  }

  /// Finds the nearest [SuperMessageIosControlsScope] in the widget tree, above the given
  /// [context], and returns its associated [SuperMessageIosControlsController].
  static SuperMessageIosControlsController nearestOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SuperMessageIosControlsScope>()!.controller;

  static SuperMessageIosControlsController? maybeNearestOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SuperMessageIosControlsScope>()?.controller;

  const SuperMessageIosControlsScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final SuperMessageIosControlsController controller;

  @override
  bool updateShouldNotify(SuperMessageIosControlsScope oldWidget) {
    return controller != oldWidget.controller;
  }
}

/// A controller, which coordinates the state of various iOS reader controls, including
/// drag handles, magnifier, and toolbar.
class SuperMessageIosControlsController {
  SuperMessageIosControlsController({
    this.handleColor,
    this.magnifierBuilder,
    this.toolbarBuilder,
    this.createOverlayControlsClipper,
  });

  void dispose() {
    _shouldShowMagnifier.dispose();
    _shouldShowToolbar.dispose();
  }

  /// Color of the text selection drag handles on iOS.
  final Color? handleColor;

  /// Whether the iOS magnifier should be displayed right now.
  ValueListenable<bool> get shouldShowMagnifier => _shouldShowMagnifier;
  final _shouldShowMagnifier = ValueNotifier<bool>(false);

  /// Shows the magnifier by setting [shouldShowMagnifier] to `true`.
  void showMagnifier() => _shouldShowMagnifier.value = true;

  /// Hides the magnifier by setting [shouldShowMagnifier] to `false`.
  void hideMagnifier() => _shouldShowMagnifier.value = false;

  /// Toggles [shouldShowMagnifier].
  void toggleMagnifier() => _shouldShowMagnifier.value = !_shouldShowMagnifier.value;

  /// Link to a location where a magnifier should be focused.
  final magnifierFocalPoint = LeaderLink();

  /// (Optional) Builder to create the visual representation of the magnifier.
  ///
  /// If [magnifierBuilder] is `null`, a default iOS magnifier is displayed.
  final DocumentMagnifierBuilder? magnifierBuilder;

  /// Whether the iOS floating toolbar should be displayed right now.
  ValueListenable<bool> get shouldShowToolbar => _shouldShowToolbar;
  final _shouldShowToolbar = ValueNotifier<bool>(false);

  /// Shows the toolbar by setting [shouldShowToolbar] to `true`.
  void showToolbar() => _shouldShowToolbar.value = true;

  /// Hides the toolbar by setting [shouldShowToolbar] to `false`.
  void hideToolbar() => _shouldShowToolbar.value = false;

  /// Toggles [shouldShowToolbar].
  void toggleToolbar() => _shouldShowToolbar.value = !_shouldShowToolbar.value;

  /// Link to a location where a toolbar should be focused.
  ///
  /// This link probably points to a rectangle, such as a bounding rectangle
  /// around the user's selection. Therefore, the toolbar builder shouldn't
  /// assume that this focal point is a single pixel.
  final toolbarFocalPoint = LeaderLink();

  /// (Optional) Builder to create the visual representation of the floating
  /// toolbar.
  ///
  /// If [toolbarBuilder] is `null`, a default iOS toolbar is displayed.
  final DocumentFloatingToolbarBuilder? toolbarBuilder;

  /// Creates a clipper that restricts where the toolbar and magnifier can
  /// appear in the overlay.
  ///
  /// If no clipper factory method is provided, then the overlay controls
  /// will be allowed to appear anywhere in the overlay in which they sit
  /// (probably the entire screen).
  final CustomClipper<Rect> Function(BuildContext overlayContext)? createOverlayControlsClipper;
}

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

  final DocumentContext messageContext;

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
  SuperMessageIosControlsController? _controlsController;

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

    _controlsController = SuperMessageIosControlsScope.rootOf(context);
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

  Offset _globalOffsetToDocumentOffset(Offset globalOffset) {
    final myBox = context.findRenderObject() as RenderBox;
    final docOffset = myBox.globalToLocal(globalOffset);
    return docOffset;
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
    final interactorOffset = interactorBox.globalToLocal(_globalTapDownOffset!);
    final tapDownDocumentOffset = _interactorOffsetToDocumentOffset(interactorOffset);
    final tapDownDocumentPosition = _docLayout.getDocumentPositionNearestToOffset(tapDownDocumentOffset);
    if (tapDownDocumentPosition == null) {
      return;
    }

    if (_isOverBaseHandle(interactorOffset) || _isOverExtentHandle(interactorOffset)) {
      // Don't do anything for long presses over the handles, because we want the user
      // to be able to drag them without worrying about how long they've pressed.
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
      _longPressStrategy = null;
      return;
    }

    _placeFocalPointNearTouchOffset();
    _controlsController!
      ..hideToolbar()
      ..showMagnifier();

    widget.focusNode.requestFocus();
  }

  void _onTapUp(TapUpDetails details) {
    // Stop waiting for a long-press to start.
    _globalTapDownOffset = null;
    _tapDownLongPressTimer?.cancel();
    _controlsController!.hideMagnifier();

    readerGesturesLog.info("Tap down on document");
    final docOffset = _globalOffsetToDocumentOffset(details.globalPosition);
    readerGesturesLog.fine(" - document offset: $docOffset");

    final selection = widget.messageContext.composer.selection;
    if (selection != null &&
        !selection.isCollapsed &&
        (_isOverBaseHandle(docOffset) || _isOverExtentHandle(docOffset))) {
      _controlsController!.toggleToolbar();
      return;
    }

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
    readerGesturesLog.info("Double tap down on document");
    final docOffset = _globalOffsetToDocumentOffset(details.globalPosition);
    readerGesturesLog.fine(" - document offset: $docOffset");

    final selection = widget.messageContext.composer.selection;
    if (selection != null &&
        !selection.isCollapsed &&
        (_isOverBaseHandle(docOffset) || _isOverExtentHandle(docOffset))) {
      return;
    }

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
    final docOffset = _globalOffsetToDocumentOffset(details.globalPosition);
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
    _updateDragStartLocation(details.globalPosition);
  }

  void _onPanStart(DragStartDetails details) {
    final myBox = context.findRenderObject() as RenderBox;
    final docOffset = myBox.globalToLocal(details.globalPosition);

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
    } else if (_isOverBaseHandle(docOffset)) {
      _dragMode = DragMode.base;
      _dragHandleType = HandleType.upstream;
    } else if (_isOverExtentHandle(docOffset)) {
      _dragMode = DragMode.extent;
      _dragHandleType = HandleType.downstream;
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

  void _onPanEnd(DragEndDetails details) {
    if (_dragMode != null) {
      _onDragSelectionEnd();
    }
  }

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
      final documentOffset = _docLayout.getDocumentOffsetFromAncestorOffset(_globalTapDownOffset!);
      docPositionToMagnify = _docLayout.getDocumentPositionNearestToOffset(documentOffset);
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
