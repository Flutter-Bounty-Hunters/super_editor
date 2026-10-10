import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/infrastructure/platforms/android/selection_handles.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/selection_handles.dart';
import 'package:super_editor/super_editor.dart';

/// Extensions on [WidgetTester] for interacting with a [SuperReader] the way
/// a user would.
extension SuperReaderRobot on WidgetTester {
  /// Simulates a double tap at the given [offset] within the paragraph with the given
  /// [nodeId].
  Future<void> doubleTapInParagraph(String nodeId, int offset, [Finder? superReaderFinder]) async {
    await _tapInParagraph(nodeId, offset, 2, superReaderFinder);
  }

  /// Simulates a triple tap at the given [offset] within the paragraph with the given
  /// [nodeId].
  Future<void> tripleTapInParagraph(String nodeId, int offset, [Finder? superReaderFinder]) async {
    await _tapInParagraph(nodeId, offset, 3, superReaderFinder);
  }

  /// Simulates a double tap at the given [offset] within the paragraph with the
  /// given [nodeId], leaving the pointer down after the second tap, and returns
  /// the [TestGesture] so that a test can drag it, or release it.
  Future<TestGesture> doubleTapDownInParagraph(String nodeId, int offset, [Finder? superReaderFinder]) async {
    final globalTapOffset = _findGlobalOffsetForTextPosition(nodeId, offset, superReaderFinder);

    final gesture = await startGesture(globalTapOffset);
    await gesture.up();
    await pump(kTapMinTime + const Duration(milliseconds: 1));

    await gesture.down(globalTapOffset);
    await pump(kTapMinTime + const Duration(milliseconds: 1));
    await pump();

    return gesture;
  }

  Future<void> _tapInParagraph(String nodeId, int offset, int tapCount, [Finder? superReaderFinder]) async {
    final globalTapOffset = _findGlobalOffsetForTextPosition(nodeId, offset, superReaderFinder);

    // Tap the desired number of times in SuperReader at the given position.
    for (int i = 0; i < tapCount; i += 1) {
      await tapAt(globalTapOffset);
      await pump(kTapMinTime + const Duration(milliseconds: 1));
    }

    await pumpAndSettle();
  }

  /// Returns the global offset of the text [offset] within the paragraph with
  /// the given [nodeId].
  Offset _findGlobalOffsetForTextPosition(String nodeId, int offset, [Finder? superReaderFinder]) {
    late final Finder layoutFinder;
    if (superReaderFinder != null) {
      layoutFinder = find.descendant(of: superReaderFinder, matching: find.byType(SingleColumnDocumentLayout));
    } else {
      layoutFinder = find.byType(SingleColumnDocumentLayout);
    }
    final documentLayoutElement = layoutFinder.evaluate().single as StatefulElement;
    final documentLayout = documentLayoutElement.state as DocumentLayout;

    // Collect the various text UI artifacts needed to find the
    // desired caret offset.
    final componentState = documentLayout.getComponentByNodeId(nodeId) as State;
    late final GlobalKey textComponentKey;
    if (componentState is ProxyDocumentComponent) {
      textComponentKey = componentState.childDocumentComponentKey;
    } else {
      textComponentKey = componentState.widget.key as GlobalKey;
    }

    final textLayout = (textComponentKey.currentState as TextComponentState).textLayout;
    final textRenderBox = textComponentKey.currentContext!.findRenderObject() as RenderBox;

    // Calculate the global tap position based on the TextLayout and desired
    // TextPosition.
    final position = TextPosition(offset: offset);
    // For the local tap offset, we add a small vertical adjustment downward. This
    // prevents flaky edge effects, which might occur if we try to tap exactly at the
    // top of the line. In general, we could use the caret height to choose a vertical
    // offset, but the caret height is null when the text is empty. So we use a
    // hard-coded value, instead.
    final localTapOffset = textLayout.getOffsetForCaret(position) + const Offset(0, 5);

    // TODO: check that the tap offset is visible within the viewport. Add option to
    // auto-scroll, or throw exception when it's not tappable.

    return localTapOffset + textRenderBox.localToGlobal(Offset.zero);
  }

  /// Taps at the center of the content at the given [position] within a [SuperReader].
  ///
  /// {@macro superreader_finder}
  Future<void> tapAtDocumentPosition(DocumentPosition position, [Finder? superReaderFinder]) async {
    final documentLayout = _findDocumentLayout(superReaderFinder);
    final positionRectInDoc = documentLayout.getRectForPosition(position)!;
    final globalTapOffset = documentLayout.getAncestorOffsetFromDocumentOffset(positionRectInDoc.center);

    await tapAt(globalTapOffset);
  }

  /// Simulates a user drag that begins at the [from] [DocumentPosition]
  /// and drags a [delta] amount from that point.
  ///
  /// The drag simulation also introduces a very small x and y adjustment
  /// to ensure that the drag rectangle never has a zero-width or a
  /// zero-height, because such a drag rectangle wouldn't be seen as
  /// intersecting any content.
  ///
  /// Provide a [pointerDeviceKind] to override the device kind used in the gesture.
  /// If [pointerDeviceKind] is `null`, it defaults to [PointerDeviceKind.touch]
  /// on mobile, and [PointerDeviceKind.mouse] on other platforms.
  Future<void> dragSelectDocumentFromPositionByOffset({
    required DocumentPosition from,
    required Offset delta,
    PointerDeviceKind? pointerDeviceKind,
    Finder? superReaderFinder,
  }) async {
    final documentLayout = _findDocumentLayout(superReaderFinder);

    final dragStartRect = documentLayout.getRectForPosition(from)!;
    // TODO: use startDragFromPosition to start the drag instead of re-implementing it here

    // We select an initial drag offset that sits furthest from the drag
    // direction. Dragging recognition waits for a certain amount of drag
    // slop before reporting a drag event. It's possible for a pointer or
    // finger movement to move outside of a piece of content before the
    // drag is ever reported. This results in an unexpected start position
    // for the drag. To minimize this likelihood, we select a corner of
    // the target content that sits furthest from the drag direction.
    late Offset dragStartOffset;
    if (delta.dy < 0 || delta.dx < 0) {
      if (delta.dx < 0) {
        // We're dragging up and left. To capture the content at `from`,
        // drag from bottom right.
        dragStartOffset = documentLayout.getAncestorOffsetFromDocumentOffset(dragStartRect.bottomRight);
      } else {
        // We're dragging up and right. To capture the content at `from`,
        // drag from bottom left.
        dragStartOffset = documentLayout.getAncestorOffsetFromDocumentOffset(dragStartRect.bottomLeft);
      }
    } else {
      if (delta.dx < 0) {
        // We're dragging down and left. To capture the content at `from`,
        // drag from top right.
        dragStartOffset = documentLayout.getAncestorOffsetFromDocumentOffset(dragStartRect.topRight);
      } else {
        // We're dragging down and right. To capture the content at `from`,
        // drag from top left.
        dragStartOffset = documentLayout.getAncestorOffsetFromDocumentOffset(dragStartRect.topLeft);
      }
    }

    final deviceKind = pointerDeviceKind ??
        (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android
            ? PointerDeviceKind.touch
            : PointerDeviceKind.mouse);

    // Simulate the drag.
    final gesture = await startGesture(dragStartOffset, kind: deviceKind);

    // Move slightly so that a "pan start" is reported.
    //
    // The slight offset moves in both directions so that we're
    // guaranteed to have a drag rectangle with a non-zero width and
    // a non-zero height. For example, consider a delta of
    // Offset(300, 0). Without a slight adjustment, that drag rectangle
    // would have a zero height and therefore it wouldn't report any
    // content overlap.
    await gesture.moveBy(const Offset(2, 2));

    // Move by the desired delta.
    await gesture.moveBy(delta);

    // Release the drag and settle.
    await endDocumentDragGesture(gesture);
  }

  /// Simulates a user drag that begins at the [from] [DocumentPosition]
  /// and returns the simulated gesture for further control.
  ///
  /// Make sure to remove the pointer when you're done with the [TestGesture].
  Future<TestGesture> startDocumentDragFromPosition({
    required DocumentPosition from,
    Alignment startAlignmentWithinPosition = Alignment.center,
    Finder? superReaderFinder,
    PointerDeviceKind deviceKind = PointerDeviceKind.mouse,
  }) async {
    final documentLayout = _findDocumentLayout(superReaderFinder);

    // Find the global offset to start the drag gesture.
    Rect dragStartRect = documentLayout.getRectForPosition(from)!.deflate(1);
    final globalDocTopLeft = documentLayout.getGlobalOffsetFromDocumentOffset(Offset.zero);
    dragStartRect = dragStartRect.translate(globalDocTopLeft.dx, globalDocTopLeft.dy);
    final dragStartOffset = startAlignmentWithinPosition.withinRect(dragStartRect);

    // Simulate the drag.
    final gesture = await startGesture(dragStartOffset, kind: deviceKind);
    await pump();

    // Move a tiny amount to start the pan gesture.
    await gesture.moveBy(const Offset(2, 2));
    await pump();

    return gesture;
  }

  /// Ends a drag gesture that's simulated with the given [gesture].
  ///
  /// To end the drag gesture, the point is released from surface and then
  /// the pointer is removed from the gesture simulator.
  Future<void> endDocumentDragGesture(TestGesture gesture) async {
    await gesture.up();
    await gesture.removePointer();
    await pumpAndSettle();
  }

  Future<TestGesture> pressDownOnDownstreamMobileHandle() async {
    final handleElement = find
        .byWidgetPredicate((widget) =>
            (widget is AndroidSelectionHandle && widget.handleType == HandleType.downstream) ||
            (widget is IOSSelectionHandle && widget.handleType == HandleType.downstream))
        .evaluate()
        .firstOrNull;
    assert(handleElement != null, "Tried to press down on downstream handle but no handle was found.");
    final renderHandle = handleElement!.renderObject as RenderBox;
    final handleCenter = renderHandle.localToGlobal(renderHandle.size.center(Offset.zero));

    final gesture = await startGesture(handleCenter);
    return gesture;
  }

  Future<TestGesture> pressDownOnUpstreamMobileHandle() async {
    final handleElement = find
        .byWidgetPredicate((widget) =>
            (widget is AndroidSelectionHandle && widget.handleType == HandleType.upstream) ||
            (widget is IOSSelectionHandle && widget.handleType == HandleType.upstream))
        .evaluate()
        .firstOrNull;
    assert(handleElement != null, "Tried to press down on upstream handle but no handle was found.");
    final renderHandle = handleElement!.renderObject as RenderBox;
    final handleCenter = renderHandle.localToGlobal(renderHandle.size.center(Offset.zero));

    final gesture = await startGesture(handleCenter);
    return gesture;
  }

  DocumentLayout _findDocumentLayout([Finder? superReaderFinder]) {
    late final Finder layoutFinder;
    if (superReaderFinder != null) {
      layoutFinder = find.descendant(of: superReaderFinder, matching: find.byType(SingleColumnDocumentLayout));
    } else {
      layoutFinder = find.byType(SingleColumnDocumentLayout);
    }
    final documentLayoutElement = layoutFinder.evaluate().single as StatefulElement;
    return documentLayoutElement.state as DocumentLayout;
  }
}
