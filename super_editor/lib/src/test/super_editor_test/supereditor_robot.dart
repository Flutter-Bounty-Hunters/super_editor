import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/src/test/ime.dart';
import 'package:super_editor/super_editor.dart';

/// Extensions on [WidgetTester] for interacting with a [SuperEditor] the way
/// a user would.
extension SuperEditorRobot on WidgetTester {
  Future<void> placeCaretInComponent(
    String nodeId,
    NodePosition nodePosition, {
    Finder? superEditorFinder,
    bool settle = true,
  }) async {
    // Calculate the global tap position for the node position.
    final globalTapOffset = _findGlobalOffsetForPosition(nodeId, nodePosition);

    // TODO: check that the tap offset is visible within the viewport. Add option to
    // auto-scroll, or throw exception when it's not tappable.

    // Tap the desired number of times in SuperEditor at the given position.
    await tapAt(globalTapOffset);

    // Pump long enough to prevent the next tap from being seen as a sequence on top of these taps.
    await pump(kTapTimeout);

    if (settle) {
      await pumpAndSettle();
    }
  }

  /// Place the caret at the given [offset] in a paragraph with the given [nodeId],
  /// by simulating a user gesture.
  ///
  /// The simulated user gesture is probably a tap, but the only guarantee is that
  /// the caret is placed with a gesture.
  ///
  /// To explicitly simulate a tap within a paragraph, use [tapInParagraph].
  Future<void> placeCaretInParagraph(
    String nodeId,
    int offset, {
    TextAffinity affinity = TextAffinity.downstream,
    Finder? superEditorFinder,
  }) async {
    await _tapInParagraph(nodeId, offset, affinity, 1, superEditorFinder);
  }

  /// Simulates a tap at the given [offset] within the paragraph with the
  /// given [nodeId].
  ///
  /// This simulated interaction is intended primarily for purposes other
  /// than changing the document selection, such as tapping on a link to
  /// launch a URL.
  ///
  /// To place the caret in a paragraph, consider using [placeCaretInParagraph],
  /// which might choose a different execution path to simulate the selection
  /// change.
  Future<void> tapInParagraph(
    String nodeId,
    int offset, {
    TextAffinity affinity = TextAffinity.downstream,
    Finder? superEditorFinder,
  }) async {
    await _tapInParagraph(nodeId, offset, affinity, 1, superEditorFinder);
  }

  Future<TestGesture> tapDownInParagraph(
    String nodeId,
    int offset, {
    TextAffinity affinity = TextAffinity.downstream,
    Finder? superEditorFinder,
  }) async {
    // Calculate the global tap position based on the TextLayout and desired
    // TextPosition.
    final globalTapOffset = _findGlobalOffsetForTextPosition(nodeId, offset, affinity, superEditorFinder);

    // TODO: check that the tap offset is visible within the viewport. Add option to
    // auto-scroll, or throw exception when it's not tappable.

    return await startGesture(globalTapOffset);
  }

  Future<TestGesture> doubleTapDownInParagraph(
    String nodeId,
    int offset, {
    TextAffinity affinity = TextAffinity.downstream,
    Finder? superEditorFinder,
  }) async {
    // Calculate the global tap position based on the TextLayout and desired TextPosition.
    final globalTapOffset = _findGlobalOffsetForTextPosition(nodeId, offset, affinity, superEditorFinder);

    final gesture = await startGesture(globalTapOffset);
    await gesture.up();
    await pump(kTapMinTime + const Duration(milliseconds: 1));

    await gesture.down(globalTapOffset);
    await pump(kTapMinTime + const Duration(milliseconds: 1));
    await pump();

    return gesture;
  }

  /// Simulates a long-press at the given text [offset] within the paragraph
  /// with the given [nodeId].
  Future<void> longPressInParagraph(
    String nodeId,
    int offset, {
    TextAffinity affinity = TextAffinity.downstream,
    Finder? superEditorFinder,
  }) async {
    final gesture = await tapDownInParagraph(nodeId, offset, affinity: affinity, superEditorFinder: superEditorFinder);
    await pump(kLongPressTimeout + kPressTimeout);

    await gesture.up();
    await pump();
  }

  /// Simulates a long-press down at the given text [offset] within the paragraph
  /// with the given [nodeId], and returns the [TestGesture] so that a test can
  /// decide to drag it, or release.
  Future<TestGesture> longPressDownInParagraph(
    String nodeId,
    int offset, {
    TextAffinity affinity = TextAffinity.downstream,
    Finder? superEditorFinder,
  }) async {
    final gesture = await tapDownInParagraph(nodeId, offset, affinity: affinity, superEditorFinder: superEditorFinder);
    await pump(kLongPressTimeout + kPressTimeout);
    return gesture;
  }

  /// Simulates a double tap at the given [offset] within the paragraph with the given
  /// [nodeId].
  Future<void> doubleTapInParagraph(
    String nodeId,
    int offset, {
    TextAffinity affinity = TextAffinity.downstream,
    Finder? superEditorFinder,
  }) async {
    await _tapInParagraph(nodeId, offset, affinity, 2, superEditorFinder);
  }

  /// Simulates a triple tap at the given [offset] within the paragraph with the given
  /// [nodeId].
  Future<void> tripleTapInParagraph(
    String nodeId,
    int offset, {
    TextAffinity affinity = TextAffinity.downstream,
    Finder? superEditorFinder,
  }) async {
    await _tapInParagraph(nodeId, offset, affinity, 3, superEditorFinder);
  }

  // TODO: rename all of these related behaviors to "text" instead of "paragraph"
  Future<void> _tapInParagraph(
    String nodeId,
    int offset,
    TextAffinity affinity,
    int tapCount, [
    Finder? superEditorFinder,
  ]) async {
    // Calculate the global tap position based on the TextLayout and desired
    // TextPosition.
    final globalTapOffset = _findGlobalOffsetForTextPosition(nodeId, offset, affinity, superEditorFinder);

    // TODO: check that the tap offset is visible within the viewport. Add option to
    // auto-scroll, or throw exception when it's not tappable.

    // Tap the desired number of times in SuperEditor at the given position.
    for (int i = 0; i < tapCount; i += 1) {
      await tapAt(globalTapOffset);
      await pump(kTapMinTime + const Duration(milliseconds: 1));
    }

    // Pump long enough to prevent the next tap from being seen as a sequence on top of these taps.
    await pump(kTapTimeout);

    await pumpAndSettle();
  }

  /// Taps at the center of the content at the given [position] within a [SuperEditor].
  ///
  /// {@macro supereditor_finder}
  Future<void> tapAtDocumentPosition(DocumentPosition position, [Finder? superEditorFinder]) async {
    final documentLayout = _findDocumentLayout(superEditorFinder);
    final positionRectInDoc = _getRectForDocumentPosition(position, documentLayout, superEditorFinder);
    final globalTapOffset = documentLayout.getAncestorOffsetFromDocumentOffset(positionRectInDoc.center);

    await tapAt(globalTapOffset);
  }

  /// Double-taps at the center of the content at the given [position] within a [SuperEditor].
  ///
  /// {@macro supereditor_finder}
  Future<void> doubleTapAtDocumentPosition(DocumentPosition position, [Finder? superEditorFinder]) async {
    final documentLayout = _findDocumentLayout(superEditorFinder);
    final positionRectInDoc = documentLayout.getRectForPosition(position)!;
    final globalTapOffset = documentLayout.getAncestorOffsetFromDocumentOffset(positionRectInDoc.center);

    await tapAt(globalTapOffset);
    await pump(kTapMinTime);
    await tapAt(globalTapOffset);
  }

  /// Double-taps at the offset that's between the center of [position1] and [position2],
  /// placed between them at the given [alignment] (defaults to center).
  ///
  /// {@macro supereditor_finder}
  Future<void> doubleTapBetweenDocumentPositions(
    DocumentPosition position1,
    DocumentPosition position2, [
    Alignment alignment = Alignment.center,
    Finder? superEditorFinder,
  ]) async {
    final documentLayout = _findDocumentLayout(superEditorFinder);

    final caret1 = documentLayout.getCaretForPosition(position1);
    final caret2 = documentLayout.getCaretForPosition(position2);
    final rect = Rect.fromLTRB(caret1.x, caret1.top, caret2.x, caret1.bottom);

    final tapOffset = alignment.withinRect(rect);

    await tapAt(tapOffset);
    await pump(kTapMinTime);
    await tapAt(tapOffset);
  }

  /// Triple-taps at the center of the content at the given [position] within a [SuperEditor].
  ///
  /// {@macro supereditor_finder}
  Future<void> tripleTapAtDocumentPosition(DocumentPosition position, [Finder? superEditorFinder]) async {
    final documentLayout = _findDocumentLayout(superEditorFinder);
    final positionRectInDoc = documentLayout.getRectForPosition(position)!;
    final globalTapOffset = documentLayout.getAncestorOffsetFromDocumentOffset(positionRectInDoc.center);

    await tapAt(globalTapOffset);
    await pump(kTapMinTime);
    await tapAt(globalTapOffset);
    await pump(kTapMinTime);
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
    Finder? superEditorFinder,
  }) async {
    final documentLayout = _findDocumentLayout(superEditorFinder);

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
    Finder? superEditorFinder,
    PointerDeviceKind deviceKind = PointerDeviceKind.mouse,
  }) async {
    final documentLayout = _findDocumentLayout(superEditorFinder);

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

  Future<TestGesture> pressDownOnCollapsedMobileHandle() async {
    final handleElement = find.byKey(DocumentKeys.androidCaretHandle).evaluate().firstOrNull;
    assert(handleElement != null, "Tried to press down on Android collapsed handle but no handle was found.");
    final renderHandle = handleElement!.renderObject as RenderBox;
    final handleCenter = renderHandle.localToGlobal(renderHandle.size.center(Offset.zero));

    final gesture = await startGesture(handleCenter);
    return gesture;
  }

  Future<void> tapOnCollapsedMobileHandle() async {
    final handleElement = find.byKey(DocumentKeys.androidCaretHandle).evaluate().firstOrNull;
    assert(handleElement != null, "Tried to press down on Android collapsed handle but no handle was found.");
    final renderHandle = handleElement!.renderObject as RenderBox;
    final handleCenter = renderHandle.localToGlobal(renderHandle.size.center(Offset.zero));

    await tapAt(handleCenter);
  }

  Future<TestGesture> pressDownOnUpstreamMobileHandle() async {
    final handleElement = find.byKey(DocumentKeys.upstreamHandle).evaluate().firstOrNull;
    assert(handleElement != null, "Tried to press down on upstream handle but no handle was found.");
    final renderHandle = handleElement!.renderObject as RenderBox;
    final handleCenter = renderHandle.localToGlobal(renderHandle.size.center(Offset.zero));

    final gesture = await startGesture(handleCenter);
    return gesture;
  }

  Future<TestGesture> pressDownOnDownstreamMobileHandle() async {
    final handleElement = find.byKey(DocumentKeys.downstreamHandle).evaluate().firstOrNull;
    assert(handleElement != null, "Tried to press down on upstream handle but no handle was found.");
    final renderHandle = handleElement!.renderObject as RenderBox;
    final handleCenter = renderHandle.localToGlobal(renderHandle.size.center(Offset.zero));

    final gesture = await startGesture(handleCenter);
    return gesture;
  }

  /// Simulates typing [text], either as keyboard keys, or as insertion deltas of
  /// a software keyboard.
  ///
  /// Provide an [imeOwnerFinder] if there are multiple [ImeOwner]s in the current
  /// widget tree.
  Future<void> typeTextAdaptive(String text, [Finder? imeOwnerFinder]) async {
    if (!testTextInput.hasAnyClients) {
      // There isn't any IME connections.
      // Type using the hardware keyboard.
      await typeKeyboardText(text);
      return;
    }

    await ime.typeText(text, getter: () => imeClientGetter(imeOwnerFinder));
  }

  /// Types the given [text] into a [SuperEditor] by simulating IME text deltas from
  /// the platform.
  ///
  /// Provide an [imeOwnerFinder] if there are multiple [ImeOwner]s in the current
  /// widget tree.
  Future<void> typeImeText(String text, [Finder? imeOwnerFinder]) async {
    await ime.typeText(text, getter: () => imeClientGetter(imeOwnerFinder));
  }

  /// Simulates the user holding the spacebar and starting the floating cursor gesture.
  ///
  /// The initial offset is at (0,0).
  Future<void> startFloatingCursorGesture() async {
    await _updateFloatingCursor(action: "FloatingCursorDragState.start", offset: Offset.zero);
  }

  /// Simulates the user swiping the spacebar by [offset].
  ///
  /// (0,0) means the point where the user started the gesture.
  ///
  /// A floating cursor gesture must be started before calling this method.
  Future<void> updateFloatingCursorGesture(Offset offset) async {
    await _updateFloatingCursor(action: "FloatingCursorDragState.update", offset: offset);
  }

  /// Simulates the user releasing the spacebar and stopping the floating cursor gesture.
  ///
  /// A floating cursor gesture must be started before calling this method.
  Future<void> stopFloatingCursorGesture() async {
    await _updateFloatingCursor(action: "FloatingCursorDragState.end", offset: Offset.zero);
  }

  Offset _findGlobalOffsetForPosition(
    String nodeId,
    NodePosition position, [
    Finder? superEditorFinder,
  ]) {
    final componentKey = _findComponentKeyForNode(nodeId, superEditorFinder);
    final componentBox = componentKey.currentContext!.findRenderObject() as RenderBox;

    final localTapOffset = _findOffsetInComponentForPosition(nodeId, position, superEditorFinder);
    return componentBox.localToGlobal(localTapOffset);
  }

  Offset _findGlobalOffsetForTextPosition(
    String nodeId,
    int offset,
    TextAffinity affinity, [
    Finder? superEditorFinder,
  ]) {
    final textComponentKey = _findComponentKeyForNode(nodeId, superEditorFinder);
    final textRenderBox = textComponentKey.currentContext!.findRenderObject() as RenderBox;

    final localTapOffset = _findLocalOffsetForTextPosition(nodeId, offset, affinity, superEditorFinder);
    return localTapOffset + textRenderBox.localToGlobal(Offset.zero);
  }

  Offset _findLocalOffsetForTextPosition(
    String nodeId,
    int offset,
    TextAffinity affinity, [
    Finder? superEditorFinder,
  ]) {
    final textComponentKey = _findComponentKeyForNode(nodeId, superEditorFinder);
    final textLayout = (textComponentKey.currentState as TextComponentState).textLayout;

    // Calculate the global tap position based on the TextLayout and desired
    // TextPosition.
    final position = TextPosition(offset: offset, affinity: affinity);
    // For the local tap offset, we add a small vertical adjustment downward. This
    // prevents flaky edge effects, which might occur if we try to tap exactly at the
    // top of the line. In general, we could use the caret height to choose a vertical
    // offset, but the caret height is null when the text is empty. So we use a
    // hard-coded value, instead. We also adjust the horizontal offset by a pixel left
    // or right depending on the requested affinity. Without this the resulting selection
    // may contain an incorrect affinity if the gesture did not occur at a line break.
    return textLayout.getOffsetForCaret(position) + Offset(affinity == TextAffinity.upstream ? -1 : 1, 5);
  }

  /// Returns the bounding box around the given [position], within the associated component.
  ///
  /// If the component is a block component, the returned [Rect] will be half of its width.
  Rect _getRectForDocumentPosition(DocumentPosition position, DocumentLayout documentLayout,
      [Finder? superEditorFinder]) {
    final component = documentLayout.getComponentByNodeId(position.nodeId);
    if (component == null) {
      throw Exception('No component found for node ID: ${position.nodeId}');
    }

    if (component.getBeginningPosition() is UpstreamDownstreamNodePosition) {
      // The component is a block component. Compute the rect manually, because
      // `getRectForPosition` returns always the rect of the whole block.
      // The returned rect will be half of the width of the component.
      final componentBox = component.context.findRenderObject() as RenderBox;
      final edge = component.getEdgeForPosition(position.nodePosition);

      final positionRect = position.nodePosition == const UpstreamDownstreamNodePosition.upstream()
          // For upstream position, the edge is a zero width rect starting from the left.
          ? Rect.fromLTWH(
              edge.left,
              edge.top,
              componentBox.size.width / 2,
              componentBox.size.height,
            )
          // For downstream position, the edge is a zero width rect starting at the right.
          // Subtract half of the width to make it start from the center.
          : Rect.fromLTWH(
              edge.left - componentBox.size.width / 2,
              edge.top,
              componentBox.size.width / 2,
              componentBox.size.height,
            );

      // Translate the rect to global coordinates.
      final documentLayoutElement = _findDocumentLayoutElement(superEditorFinder);
      final docOffset = componentBox.localToGlobal(Offset.zero, ancestor: documentLayoutElement.findRenderObject());
      return positionRect.translate(docOffset.dx, docOffset.dy);
    }

    // The component isn't a block node. Use the default implementation for getRectForPosition.
    return documentLayout.getRectForPosition(position)!;
  }

  /// Finds and returns the [DocumentLayout] within the only [SuperEditor] in the
  /// widget tree, or within the [SuperEditor] found via the optional [superEditorFinder].
  DocumentLayout _findDocumentLayout([Finder? superEditorFinder]) {
    final documentLayoutElement = _findDocumentLayoutElement(superEditorFinder);
    return documentLayoutElement.state as DocumentLayout;
  }

  /// Finds and returns the document layout element within the only [SuperEditor] in the
  /// widget tree, or within the [SuperEditor] found via the optional [superEditorFinder].
  StatefulElement _findDocumentLayoutElement([Finder? superEditorFinder]) {
    late final Finder layoutFinder;
    if (superEditorFinder != null) {
      layoutFinder = find.descendant(of: superEditorFinder, matching: find.byType(SingleColumnDocumentLayout));
    } else {
      layoutFinder = find.byType(SingleColumnDocumentLayout);
    }
    return layoutFinder.evaluate().single as StatefulElement;
  }

  /// Finds the [GlobalKey] that's attached to the [DocumentComponent], which presents the
  /// given [nodeId].
  GlobalKey _findComponentKeyForNode(String nodeId, [Finder? superEditorFinder]) {
    final documentLayout = _findDocumentLayout(superEditorFinder);

    final componentState = documentLayout.getComponentByNodeId(nodeId) as State;
    if (componentState is ProxyDocumentComponent) {
      return componentState.childDocumentComponentKey;
    } else {
      return componentState.widget.key as GlobalKey;
    }
  }

  Offset _findOffsetInComponentForPosition(
    String nodeId,
    NodePosition position, [
    Finder? superEditorFinder,
  ]) {
    final componentKey = _findComponentKeyForNode(nodeId, superEditorFinder);
    final componentLayout = componentKey.currentState as DocumentComponent;
    return componentLayout.getOffsetForPosition(position);
  }

  Future<void> _updateFloatingCursor({required String action, required Offset offset}) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.textInput.name,
      SystemChannels.textInput.codec.encodeMethodCall(
        MethodCall(
          "TextInputClient.updateFloatingCursor",
          [
            -1,
            action,
            {"X": offset.dx, "Y": offset.dy}
          ],
        ),
      ),
      null,
    );
  }
}
