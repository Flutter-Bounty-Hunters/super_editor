import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/document_gestures_touch_ios.dart';
import 'package:super_editor/src/default_editor/text_tools.dart';
import 'package:super_editor/src/document_operations/selection_operations.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/content_layers.dart';
import 'package:super_editor/src/infrastructure/document_gestures.dart';
import 'package:super_editor/src/infrastructure/document_gestures_interaction_overrides.dart';
import 'package:super_editor/src/infrastructure/flutter/build_context.dart';
import 'package:super_editor/src/infrastructure/flutter/eager_pan_gesture_recognizer.dart';
import 'package:super_editor/src/infrastructure/flutter/flutter_scheduler.dart';
import 'package:super_editor/src/infrastructure/multi_tap_gesture.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/ios_document_controls.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/long_press_selection.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/magnifier.dart';
import 'package:super_editor/src/infrastructure/platforms/mobile_documents.dart';
import 'package:super_editor/src/infrastructure/platforms/platform.dart';
import 'package:super_editor/src/infrastructure/sliver_hybrid_stack.dart';
import 'package:super_editor/src/infrastructure/touch_controls.dart';
import 'package:super_editor/src/super_reader/reader_context.dart';
import 'package:super_editor/src/super_reader/super_reader.dart';

import '../core/document_composer.dart';

/// An [InheritedWidget] that provides shared access to a [SuperReaderIosControlsController],
/// which coordinates the state of iOS controls like drag handles, magnifier, and toolbar.
///
/// This widget and its associated controller exist so that [SuperReader] has maximum freedom
/// in terms of where to implement iOS gestures vs handles vs the magnifier vs the toolbar.
/// Each of these responsibilities have some unique differences, which make them difficult
/// or impossible to implement within a single widget. By sharing a controller, a group of
/// independent widgets can work together to cover those various responsibilities.
///
/// Centralizing a controller in an [InheritedWidget] also allows [SuperReader] to share that
/// control with application code outside of [SuperReader], by placing an [SuperReaderIosControlsScope]
/// above the [SuperReader] in the widget tree. For this reason, [SuperReader] should access
/// the [SuperReaderIosControlsScope] through [rootOf].
class SuperReaderIosControlsScope extends InheritedWidget {
  /// Finds the highest [SuperReaderIosControlsScope] in the widget tree, above the given
  /// [context], and returns its associated [SuperReaderIosControlsController].
  static SuperReaderIosControlsController rootOf(BuildContext context) {
    final data = maybeRootOf(context);

    if (data == null) {
      throw Exception("Tried to depend upon the root IosReaderControlsScope but no such ancestor widget exists.");
    }

    return data;
  }

  static SuperReaderIosControlsController? maybeRootOf(BuildContext context) {
    InheritedElement? root;

    context.visitAncestorElements((element) {
      if (element is! InheritedElement || element.widget is! SuperReaderIosControlsScope) {
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
    return (root!.widget as SuperReaderIosControlsScope).controller;
  }

  /// Finds the nearest [SuperReaderIosControlsScope] in the widget tree, above the given
  /// [context], and returns its associated [SuperReaderIosControlsController].
  static SuperReaderIosControlsController nearestOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SuperReaderIosControlsScope>()!.controller;

  static SuperReaderIosControlsController? maybeNearestOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SuperReaderIosControlsScope>()?.controller;

  const SuperReaderIosControlsScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final SuperReaderIosControlsController controller;

  @override
  bool updateShouldNotify(SuperReaderIosControlsScope oldWidget) {
    return controller != oldWidget.controller;
  }
}

/// A controller, which coordinates the state of various iOS reader controls, including
/// drag handles, magnifier, and toolbar.
class SuperReaderIosControlsController {
  SuperReaderIosControlsController({
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
class SuperReaderIosDocumentTouchInteractor extends StatefulWidget {
  const SuperReaderIosDocumentTouchInteractor({
    Key? key,
    required this.focusNode,
    required this.readerContext,
    required this.documentKey,
    required this.getDocumentLayout,
    required this.scrollController,
    required this.fillViewport,
    this.contentTapHandler,
    this.dragAutoScrollBoundary = const AxisOffset.symmetric(54),
    this.showDebugPaint = false,
    required this.child,
  }) : super(key: key);

  final FocusNode focusNode;

  final SuperReaderContext readerContext;

  final GlobalKey documentKey;
  final DocumentLayout Function() getDocumentLayout;

  final ScrollController scrollController;

  /// Optional handler that responds to taps on content, e.g., opening
  /// a link when the user taps on text with a link attribution.
  final ContentTapDelegate? contentTapHandler;

  /// The closest that the user's selection drag gesture can get to the
  /// document boundary before auto-scrolling.
  ///
  /// The default value is `54.0` pixels for both the leading and trailing
  /// edges.
  final AxisOffset dragAutoScrollBoundary;

  /// Whether the document gesture detector should fill the entire viewport
  /// even if the actual content is smaller.
  final bool fillViewport;

  final bool showDebugPaint;

  final Widget child;

  @override
  State createState() => _SuperReaderIosDocumentTouchInteractorState();
}

class _SuperReaderIosDocumentTouchInteractorState extends State<SuperReaderIosDocumentTouchInteractor>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // The ScrollPosition attached to the _ancestorScrollable.
  ScrollPosition? _ancestorScrollPosition;

  SuperReaderIosControlsController? _controlsController;

  late DragHandleAutoScroller _handleAutoScrolling;
  Offset? _globalStartDragOffset;
  Offset? _dragStartInDoc;
  Offset? _startDragPositionOffset;
  double? _dragStartScrollOffset;
  Offset? _globalDragOffset;
  Offset? _dragEndInInteractor;
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

    _handleAutoScrolling = DragHandleAutoScroller(
      vsync: this,
      dragAutoScrollBoundary: widget.dragAutoScrollBoundary,
      getScrollPosition: () => scrollPosition,
      getViewportBox: () => viewportBox,
    );

    widget.readerContext.document.addListener(_onDocumentChange);

    widget.readerContext.composer.selectionNotifier.addListener(_onSelectionChange);
    // If we already have a selection, we may need to display drag handles.
    if (widget.readerContext.composer.selection != null) {
      _onSelectionChange();
    }

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _controlsController = SuperReaderIosControlsScope.rootOf(context);

    _ancestorScrollPosition = context.findAncestorScrollableWithVerticalScroll?.position;
  }

  @override
  void didUpdateWidget(SuperReaderIosDocumentTouchInteractor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.readerContext.document != oldWidget.readerContext.document) {
      oldWidget.readerContext.document.removeListener(_onDocumentChange);
      widget.readerContext.document.addListener(_onDocumentChange);
    }

    if (widget.readerContext.composer != oldWidget.readerContext.composer) {
      oldWidget.readerContext.composer.selectionNotifier.removeListener(_onSelectionChange);
      widget.readerContext.composer.selectionNotifier.addListener(_onSelectionChange);

      // Selection has changed, we need to update the caret.
      if (widget.readerContext.composer.selection != oldWidget.readerContext.composer.selection) {
        _onSelectionChange();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    widget.readerContext.document.removeListener(_onDocumentChange);
    widget.readerContext.composer.selectionNotifier.removeListener(_onSelectionChange);

    _handleAutoScrolling.dispose();

    super.dispose();
  }

  void _ensureSelectionExtentIsVisible() {
    readerGesturesLog.fine("Ensuring selection extent is visible");
    final selection = widget.readerContext.composer.selection;
    if (selection == null) {
      // There's no selection. We don't need to take any action.
      return;
    }

    // Calculate the y-value of the selection extent side of the selected content so that we
    // can ensure they're visible.
    final selectionRectInDocumentLayout =
        widget.getDocumentLayout().getRectForSelection(selection.base, selection.extent)!;
    final extentOffsetInViewport =
        widget.readerContext.document.getAffinityForSelection(selection) == TextAffinity.downstream
            ? _documentOffsetToViewportOffset(selectionRectInDocumentLayout.bottomCenter)
            : _documentOffsetToViewportOffset(selectionRectInDocumentLayout.topCenter);

    _handleAutoScrolling.ensureOffsetIsVisible(extentOffsetInViewport);
  }

  Offset _documentOffsetToViewportOffset(Offset documentOffset) {
    final globalOffset = _docLayout.getGlobalOffsetFromDocumentOffset(documentOffset);
    return viewportBox.globalToLocal(globalOffset);
  }

  void _onDocumentChange(_) {
    _controlsController!.hideToolbar();

    onNextFrame((_) {
      // The user may have changed the type of node, e.g., paragraph to
      // blockquote, which impacts the caret size and position. Reposition
      // the caret on the next frame.
      // TODO: find a way to only do this when something relevant changes
      _updateHandlesAfterSelectionOrLayoutChange();

      _ensureSelectionExtentIsVisible();
    });
  }

  void _onSelectionChange() {
    // The selection change might correspond to new content that's not
    // laid out yet. Wait until the next frame to update visuals.
    onNextFrame((_) => _updateHandlesAfterSelectionOrLayoutChange());
  }

  void _updateHandlesAfterSelectionOrLayoutChange() {
    final newSelection = widget.readerContext.composer.selection;

    if (newSelection == null) {
      _controlsController!.hideToolbar();
    }
  }

  /// Returns the layout for the current document, which answers questions
  /// about the locations and sizes of visual components within the layout.
  DocumentLayout get _docLayout => widget.getDocumentLayout();

  /// Returns the `ScrollPosition` that controls the scroll offset of
  /// this widget.
  ///
  /// If this widget has an ancestor `Scrollable`, then the returned
  /// `ScrollPosition` belongs to that ancestor `Scrollable`, and this
  /// widget doesn't include a `ScrollView`.
  ///
  /// If this widget doesn't have an ancestor `Scrollable`, then this
  /// widget includes a `ScrollView` and the `ScrollView`'s position
  /// is returned.
  ScrollPosition get scrollPosition => _ancestorScrollPosition ?? widget.scrollController.position;

  /// Returns the `RenderBox` for the scrolling viewport.
  ///
  /// If this widget has an ancestor `Scrollable`, then the returned
  /// `RenderBox` belongs to that ancestor `Scrollable`.
  ///
  /// If this widget doesn't have an ancestor `Scrollable`, then this
  /// widget includes a `ScrollView` and this `State`'s render object
  /// is the viewport `RenderBox`.
  RenderBox get viewportBox => context.findViewportBox();

  /// Returns the render box for the interactor gesture detector.
  RenderBox get interactorBox => _interactor.currentContext!.findRenderObject() as RenderBox;

  /// Converts the given [interactorOffset] from the [DocumentInteractor]'s coordinate
  /// space to the [DocumentLayout]'s coordinate space.
  Offset _interactorOffsetToDocumentOffset(Offset interactorOffset) {
    final globalOffset = interactorBox.localToGlobal(interactorOffset);
    return _docLayout.getDocumentOffsetFromAncestorOffset(globalOffset);
  }

  /// Maps the given [interactorOffset] within the interactor's coordinate space
  /// to the same screen position in the viewport's coordinate space.
  ///
  /// When this interactor includes it's own `ScrollView`, the [interactorOffset]
  /// is the same as the viewport offset.
  ///
  /// When this interactor defers to an ancestor `Scrollable`, then the
  /// [interactorOffset] is transformed into the ancestor coordinate space.
  Offset _interactorOffsetInViewport(Offset interactorOffset) {
    // Viewport might be our box, or an ancestor box if we're inside someone
    // else's Scrollable.
    return viewportBox.globalToLocal(
      interactorBox.localToGlobal(interactorOffset),
    );
  }

  void _onTapDown(TapDownDetails details) {
    if (scrollPosition.isScrollingNotifier.value) {
      // The user tapped while the document was scrolling.
      // Cancel the scroll momentum.
      (scrollPosition as ScrollPositionWithSingleContext).goIdle();
      return;
    }

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
      document: widget.readerContext.document,
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

    final selection = widget.readerContext.composer.selection;
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
        widget.readerContext.document.doesSelectionContainPosition(selection, docPosition)) {
      // The user tapped on an expanded selection. Toggle the toolbar.
      _controlsController!.toggleToolbar();
      return;
    }

    _clearSelection();
    _controlsController!.hideToolbar();

    widget.focusNode.requestFocus();
  }

  void _onDoubleTapUp(TapUpDetails details) {
    final selection = widget.readerContext.composer.selection;
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

    final newSelection = widget.readerContext.composer.selection;
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

    final selection = widget.readerContext.composer.selection;
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
    final selection = widget.readerContext.composer.selection;
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

    _handleAutoScrolling.startAutoScrollHandleMonitoring();

    scrollPosition.addListener(_onAutoScrollChange);
  }

  bool _isOverBaseHandle(Offset interactorOffset) {
    final basePosition = widget.readerContext.composer.selection?.base;
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
    final extentPosition = widget.readerContext.composer.selection?.extent;
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
    _dragEndInInteractor = interactorBox.globalToLocal(details.globalPosition);
    final dragEndInViewport = _interactorOffsetInViewport(_dragEndInInteractor!);

    if (_isLongPressInProgress) {
      final fingerDragDelta = _globalDragOffset! - _globalStartDragOffset!;
      final scrollDelta = _dragStartScrollOffset! - scrollPosition.pixels;
      final fingerDocumentOffset = _docLayout.getDocumentOffsetFromAncestorOffset(details.globalPosition);
      final fingerDocumentPosition = _docLayout.getDocumentPositionNearestToOffset(
        _startDragPositionOffset! + fingerDragDelta - Offset(0, scrollDelta),
      );
      _longPressStrategy!.onLongPressDragUpdate(fingerDocumentOffset, fingerDocumentPosition);
    } else {
      _updateSelectionForNewDragHandleLocation();
    }

    _handleAutoScrolling.updateAutoScrollHandleMonitoring(
      dragEndInViewport: dragEndInViewport,
    );

    _controlsController!.showMagnifier();

    _placeFocalPointNearTouchOffset();
  }

  void _updateSelectionForNewDragHandleLocation() {
    final docDragDelta = _globalDragOffset! - _globalStartDragOffset!;
    final dragScrollDelta = _dragStartScrollOffset! - scrollPosition.pixels;
    final docDragPosition = _docLayout
        .getDocumentPositionNearestToOffset(_startDragPositionOffset! + docDragDelta - Offset(0, dragScrollDelta));

    if (docDragPosition == null) {
      return;
    }

    if (_dragHandleType == HandleType.upstream) {
      _setSelection(widget.readerContext.composer.selection!.copyWith(
        base: docDragPosition,
      ));
    } else if (_dragHandleType == HandleType.downstream) {
      _setSelection(widget.readerContext.composer.selection!.copyWith(
        extent: docDragPosition,
      ));
    }
  }

  void _onPanEnd(DragEndDetails details) {
    scrollPosition.removeListener(_onAutoScrollChange);
  }

  void _onPanCancel() {
    scrollPosition.removeListener(_onAutoScrollChange);

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

    _handleAutoScrolling.stopAutoScrollHandleMonitoring();
    scrollPosition.removeListener(_onAutoScrollChange);
  }

  void _onLongPressEnd() {
    _longPressStrategy!.onLongPressEnd();
    _longPressStrategy = null;
    _dragMode = null;

    _updateOverlayControlsAfterFinishingDragSelection();
  }

  void _onHandleDragEnd() {
    _handleAutoScrolling.stopAutoScrollHandleMonitoring();
    _dragMode = null;

    _updateOverlayControlsAfterFinishingDragSelection();
  }

  void _updateOverlayControlsAfterFinishingDragSelection() {
    _controlsController!.hideMagnifier();
    if (!widget.readerContext.composer.selection!.isCollapsed) {
      _controlsController!.showToolbar();
    } else {
      // Read-only documents don't support collapsed selections.
      _clearSelection();
    }
  }

  void _select(DocumentSelection newSelection) {
    _setSelection(newSelection);
  }

  void _onAutoScrollChange() {
    _updateDragSelection();
    _updateMagnifierFocalPointOnAutoScrollFrame();
  }

  void _updateDragSelection() {
    if (_dragStartInDoc == null) {
      return;
    }

    final dragEndInDoc = _interactorOffsetToDocumentOffset(_dragEndInInteractor!);
    final dragPosition = _docLayout.getDocumentPositionNearestToOffset(dragEndInDoc);
    readerGesturesLog.info("Selecting new position during drag: $dragPosition");

    if (dragPosition == null) {
      return;
    }

    if (_dragHandleType == null) {
      // The user is probably doing a long-press drag. Nothing for us to do here.
      return;
    }

    late DocumentPosition basePosition;
    late DocumentPosition extentPosition;
    switch (_dragHandleType!) {
      case HandleType.collapsed:
        // no-op for read-only documents
        return;
      case HandleType.upstream:
        basePosition = dragPosition;
        extentPosition = widget.readerContext.composer.selection!.extent;
        break;
      case HandleType.downstream:
        basePosition = widget.readerContext.composer.selection!.base;
        extentPosition = dragPosition;
        break;
    }

    _setSelection(DocumentSelection(
      base: basePosition,
      extent: extentPosition,
    ));
    readerGesturesLog.fine("Selected region: ${widget.readerContext.composer.selection}");
  }

  void _updateMagnifierFocalPointOnAutoScrollFrame() {
    if (_magnifierFocalPoint.value != null) {
      _placeFocalPointNearTouchOffset();
    }
  }

  /// Updates the magnifier focal point in relation to the current drag position.
  void _placeFocalPointNearTouchOffset() {
    late DocumentPosition? docPositionToMagnify;

    if (_globalTapDownOffset != null) {
      // A drag isn't happening. Magnify the position that the user tapped.
      docPositionToMagnify =
          _docLayout.getDocumentPositionNearestToOffset(_globalTapDownOffset! + Offset(0, scrollPosition.pixels));
    } else {
      final docDragDelta = _globalDragOffset! - _globalStartDragOffset!;
      final dragScrollDelta = _dragStartScrollOffset! - scrollPosition.pixels;
      docPositionToMagnify = _docLayout
          .getDocumentPositionNearestToOffset(_startDragPositionOffset! + docDragDelta - Offset(0, dragScrollDelta));
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

    final selection = widget.readerContext.composer.selection;
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

    // We need to record the scroll offset at the beginning of
    // a drag for the case that this interactor is embedded
    // within an ancestor Scrollable. We need to use this value
    // to calculate a scroll delta on every scroll frame to
    // account for the fact that this interactor is moving within
    // the ancestor scrollable, despite the fact that the user's
    // finger/mouse position hasn't changed.
    _dragStartScrollOffset = scrollPosition.pixels;
  }

  void _setSelection(DocumentSelection selection) {
    widget.readerContext.editor.execute([
      ChangeSelectionRequest(
        selection,
        SelectionChangeType.clearSelection,
        SelectionReason.userInteraction,
      ),
    ]);
  }

  void _clearSelection() {
    widget.readerContext.editor.execute([
      const ChangeSelectionRequest(
        null,
        SelectionChangeType.clearSelection,
        SelectionReason.userInteraction,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.scrollController.hasClients) {
      if (widget.scrollController.positions.length > 1) {
        // During Hot Reload, if the gesture mode was changed,
        // the widget might be built while the old gesture interactor
        // scroller is still attached to the _scrollController.
        //
        // Defer adding the listener to the next frame.
        scheduleBuildAfterBuild();
      }
    }

    final gestureSettings = MediaQuery.maybeOf(context)?.gestureSettings;
    // PanGestureRecognizer is above contents to have first pass at gestures, but it only accepts
    // gestures that are over caret or handles or when a long press is in progress.
    // TapGestureRecognizer is below contents so that it doesn't interferes with buttons and other
    // tappable widgets.
    return SliverHybridStack(
      fillViewport: widget.fillViewport,
      children: [
        // Layer below
        RawGestureDetector(
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
        widget.child,
        // Layer above
        RawGestureDetector(
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

/// Adds and removes an iOS-style editor toolbar, as dictated by an ancestor
/// [SuperReaderIosControlsScope].
class SuperReaderIosToolbarOverlayManager extends StatefulWidget {
  const SuperReaderIosToolbarOverlayManager({
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
  State<SuperReaderIosToolbarOverlayManager> createState() => SuperReaderIosToolbarOverlayManagerState();
}

@visibleForTesting
class SuperReaderIosToolbarOverlayManagerState extends State<SuperReaderIosToolbarOverlayManager> {
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
    return SliverHybridStack(
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
class SuperReaderIosMagnifierOverlayManager extends StatefulWidget {
  const SuperReaderIosMagnifierOverlayManager({
    super.key,
    this.child,
  });

  final Widget? child;

  @override
  State<SuperReaderIosMagnifierOverlayManager> createState() => SuperReaderIosMagnifierOverlayManagerState();
}

@visibleForTesting
class SuperReaderIosMagnifierOverlayManagerState extends State<SuperReaderIosMagnifierOverlayManager>
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
    return SliverHybridStack(
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
class SuperReaderIosHandlesDocumentLayerBuilder implements SuperReaderDocumentLayerBuilder {
  const SuperReaderIosHandlesDocumentLayerBuilder({
    this.handleColor,
  });

  final Color? handleColor;

  @override
  ContentLayerWidget build(BuildContext context, SuperReaderContext readerContext) {
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
      handleColor: handleColor ?? Theme.of(context).primaryColor,
      shouldCaretBlink: ValueNotifier<bool>(false),
    );
  }
}
