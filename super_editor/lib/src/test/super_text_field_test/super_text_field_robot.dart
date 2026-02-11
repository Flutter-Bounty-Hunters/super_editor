import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/infrastructure/platforms/android/selection_handles.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/selection_handles.dart';
import 'package:super_editor/src/test/super_text_field_test/super_text_field_inspector.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart';

/// Extensions on [WidgetTester] for interacting with a [SuperTextField] the way
/// a user would.
extension SuperTextFieldRobot on WidgetTester {
  /// Taps to place a caret at the given [offset].
  ///
  /// {@template supertextfield_finder}
  /// By default, this method expects a single [SuperTextField] in the widget tree and
  /// finds it `byType`. To specify one [SuperTextField] among many, pass a [superTextFieldFinder].
  /// {@endtemplate}
  Future<void> placeCaretInSuperTextField(int offset,
      [Finder? superTextFieldFinder, TextAffinity affinity = TextAffinity.downstream]) async {
    final fieldFinder =
        SuperTextFieldInspector.findInnerPlatformTextField(superTextFieldFinder ?? find.byType(SuperTextField));
    final match = fieldFinder.evaluate().single.widget;
    bool found = false;
    final scrollDelta = SuperTextFieldInspector.findScrollOffset(superTextFieldFinder)!;
    final scrollOffset =
        SuperTextFieldInspector.isSingleLine(superTextFieldFinder) ? Offset(scrollDelta, 0) : Offset(0, scrollDelta);

    if (match is SuperDesktopTextField) {
      final didTap = await _tapAtTextPositionOnDesktop(
          state<SuperDesktopTextFieldState>(fieldFinder), offset, affinity, scrollOffset);
      if (!didTap) {
        throw Exception("The desired text offset wasn't tappable in SuperTextField: $offset");
      }
      found = true;
    } else if (match is SuperAndroidTextField) {
      final didTap = await _tapAtTextPositionOnAndroid(
          state<SuperAndroidTextFieldState>(fieldFinder), offset, affinity, scrollOffset);
      if (!didTap) {
        throw Exception("The desired text offset wasn't tappable in SuperTextField: $offset");
      }
      found = true;
    } else if (match is SuperIOSTextField) {
      final didTap =
          await _tapAtTextPositionOnIOS(state<SuperIOSTextFieldState>(fieldFinder), offset, affinity, scrollOffset);
      if (!didTap) {
        throw Exception("The desired text offset wasn't tappable in SuperTextField: $offset");
      }
      found = true;
    }

    if (found) {
      await pumpAndSettle(kTapTimeout);
    } else {
      throw Exception("Couldn't find a SuperTextField with the given Finder: $fieldFinder");
    }
  }

  Future<void> tapOnCaretInSuperTextField([Finder? superTextFieldFinder]) async {
    final caretLayerFinder = find.descendant(
      of: superTextFieldFinder ?? find.byType(SuperTextField),
      matching: find.byType(TextLayoutCaret),
    );
    expect(caretLayerFinder, findsOne);

    final caretLayerElement = caretLayerFinder.evaluate().first as StatefulElement;
    final caretLayerState = caretLayerElement.state as TextLayoutCaretState;
    final caretGeometry = caretLayerState.globalCaretGeometry!;

    await tapAt(caretGeometry.center);
    await pump();
  }

  Future<TestGesture> dragCaretByDistanceInSuperTextField(Offset delta, [Finder? superTextFieldFinder]) async {
    final caretLayerFinder = find.descendant(
      of: superTextFieldFinder ?? find.byType(SuperTextField),
      matching: find.byType(TextLayoutCaret),
    );
    expect(caretLayerFinder, findsOne);

    final caretLayerElement = caretLayerFinder.evaluate().first as StatefulElement;
    final caretLayerState = caretLayerElement.state as TextLayoutCaretState;
    final caretGeometry = caretLayerState.globalCaretGeometry!;

    final gesture = await startGesture(caretGeometry.center);
    await pump(kTapMinTime);

    for (int i = 0; i < 50; i += 1) {
      await gesture.moveBy(delta / 50);
      await pump(const Duration(milliseconds: 50));
    }

    return gesture;
  }

  Future<TestGesture> dragAndroidCollapsedHandleByDistanceInSuperTextField(Offset delta,
      [Finder? superTextFieldFinder]) async {
    // Ensure that the collapsed handle is visible.
    expect(SuperTextFieldInspector.isAndroidCollapsedHandleVisible(superTextFieldFinder), isTrue);

    // TODO: lookup the actual handle size and offset when follow_the_leader correctly reports global bounds for followers
    // Use our knowledge that the handle sits directly beneath the caret to drag it.
    final caretLayerFinder = find.descendant(
      of: superTextFieldFinder ?? find.byType(SuperTextField),
      matching: find.byType(TextLayoutCaret),
    );
    expect(caretLayerFinder, findsOne);

    final caretLayerElement = caretLayerFinder.evaluate().first as StatefulElement;
    final caretLayerState = caretLayerElement.state as TextLayoutCaretState;
    final caretBottom = caretLayerState.globalCaretGeometry!.bottomCenter;
    final handleCenter = caretBottom + const Offset(0, 12);

    final gesture = await startGesture(handleCenter);
    await pump(kTapMinTime);

    for (int i = 0; i < 50; i += 1) {
      await gesture.moveBy(delta / 50);
      await pump(const Duration(milliseconds: 50));
    }

    return gesture;
  }

  /// Drags the [SuperTextField] upstream handle by the given delta and
  /// returns the [TestGesture] used to perform the drag.
  ///
  /// {@macro supertextfield_finder}
  Future<TestGesture> dragUpstreamMobileHandleByDistanceInSuperTextField(
    Offset delta, [
    Finder? superTextFieldFinder,
  ]) async {
    final fieldFinder =
        SuperTextFieldInspector.findInnerPlatformTextField(superTextFieldFinder ?? find.byType(SuperTextField));
    final match = fieldFinder.evaluate().single.widget;

    if (match is SuperAndroidTextField) {
      return _dragAndroidUpstreamHandleByDistanceInSuperTextField(delta, fieldFinder);
    }

    if (match is SuperIOSTextField) {
      return _dragIOSUpstreamHandleByDistanceInSuperTextField(delta, fieldFinder);
    }

    throw Exception("Couldn't find a SuperTextField with the given Finder: $fieldFinder");
  }

  /// Drags the [SuperTextField] downstream handle by the given delta and
  /// returns the [TestGesture] used to perform the drag.
  ///
  /// {@macro supertextfield_finder}
  Future<TestGesture> dragDownstreamMobileHandleByDistanceInSuperTextField(
    Offset delta, [
    Finder? superTextFieldFinder,
  ]) async {
    final fieldFinder =
        SuperTextFieldInspector.findInnerPlatformTextField(superTextFieldFinder ?? find.byType(SuperTextField));
    final match = fieldFinder.evaluate().single.widget;

    if (match is SuperAndroidTextField) {
      return _dragAndroidDownstreamHandleByDistanceInSuperTextField(delta, fieldFinder);
    }

    if (match is SuperIOSTextField) {
      return _dragIOSDownstreamHandleByDistanceInSuperTextField(delta, fieldFinder);
    }

    throw Exception("Couldn't find a SuperTextField with the given Finder: $fieldFinder");
  }

  /// Drags the [SuperAndroidTextField] upstream handle by the given delta and
  /// returns the [TestGesture] used to perform the drag.
  ///
  /// {@macro supertextfield_finder}
  Future<TestGesture> _dragAndroidUpstreamHandleByDistanceInSuperTextField(
    Offset delta, [
    Finder? superTextFieldFinder,
  ]) async {
    // TODO: lookup the actual handle size and offset when follow_the_leader correctly reports global bounds for followers
    // Use our knowledge that the handle sits directly beneath the caret to drag it.
    final handleFinder = find.descendant(
      of: superTextFieldFinder ?? find.byType(SuperAndroidTextField),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is AndroidSelectionHandle && //
            widget.handleType == HandleType.upstream,
      ),
    );

    expect(handleFinder, findsOne);

    return await _dragHandleByDistanceInSuperTextField(handleFinder, delta);
  }

  /// Drags the [SuperAndroidTextField] downstream handle by the given delta and
  /// returns the [TestGesture] used to perform the drag.
  ///
  /// {@macro supertextfield_finder}
  Future<TestGesture> _dragAndroidDownstreamHandleByDistanceInSuperTextField(
    Offset delta, [
    Finder? superTextFieldFinder,
  ]) async {
    // TODO: lookup the actual handle size and offset when follow_the_leader correctly reports global bounds for followers
    // Use our knowledge that the handle sits directly beneath the caret to drag it.
    final handleFinder = find.descendant(
      of: superTextFieldFinder ?? find.byType(SuperAndroidTextField),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is AndroidSelectionHandle && //
            widget.handleType == HandleType.downstream,
      ),
    );

    expect(handleFinder, findsOne);

    return await _dragHandleByDistanceInSuperTextField(handleFinder, delta);
  }

  /// Drags the [SuperIOSTextField] upstream handle by the given delta and
  /// returns the [TestGesture] used to perform the drag.
  ///
  /// {@macro supertextfield_finder}
  Future<TestGesture> _dragIOSUpstreamHandleByDistanceInSuperTextField(
    Offset delta, [
    Finder? superTextFieldFinder,
  ]) async {
    // TODO: lookup the actual handle size and offset when follow_the_leader correctly reports global bounds for followers
    // Use our knowledge that the handle sits directly beneath the caret to drag it.
    final handleFinder = find.descendant(
      of: superTextFieldFinder ?? find.byType(SuperIOSTextField),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is IOSSelectionHandle && //
            widget.handleType == HandleType.upstream,
      ),
    );

    expect(handleFinder, findsOne);

    return await _dragHandleByDistanceInSuperTextField(handleFinder, delta);
  }

  /// Drags the [SuperIOSTextField] downstream handle by the given delta and
  /// returns the [TestGesture] used to perform the drag.
  ///
  /// {@macro supertextfield_finder}
  Future<TestGesture> _dragIOSDownstreamHandleByDistanceInSuperTextField(
    Offset delta, [
    Finder? superTextFieldFinder,
  ]) async {
    // TODO: lookup the actual handle size and offset when follow_the_leader correctly reports global bounds for followers
    // Use our knowledge that the handle sits directly beneath the caret to drag it.
    final handleFinder = find.descendant(
      of: superTextFieldFinder ?? find.byType(SuperIOSTextField),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is IOSSelectionHandle && //
            widget.handleType == HandleType.downstream,
      ),
    );

    expect(handleFinder, findsOne);

    return await _dragHandleByDistanceInSuperTextField(handleFinder, delta);
  }

  /// Drags the [SuperTextField] handle found by [superTextFieldHandleFinder] by
  /// the given delta and returns the [TestGesture] used to perform the drag.
  ///
  /// Can be used to drag [SuperTextField] collapsed or expanded selection handles.
  Future<TestGesture> _dragHandleByDistanceInSuperTextField(
    Finder superTextFieldHandleFinder,
    Offset delta,
  ) async {
    final handleCenter = getCenter(superTextFieldHandleFinder);

    final gesture = await startGesture(handleCenter);
    await pump(kTapMinTime);

    for (int i = 0; i < 50; i += 1) {
      await gesture.moveBy(delta / 50);
      await pump(const Duration(milliseconds: 50));
    }

    return gesture;
  }

  /// Tap on an Android collapsed drag handle.
  ///
  /// {@macro supertextfield_finder}
  Future<void> tapOnAndroidCollapsedHandle([Finder? superTextFieldFinder]) async {
    final handleElement = find
        .byWidgetPredicate(
          (widget) =>
              widget is AndroidSelectionHandle && //
              widget.handleType == HandleType.collapsed,
        )
        .evaluate()
        .firstOrNull;
    assert(handleElement != null, "Tried to press down on Android collapsed handle but no handle was found.");
    final renderHandle = handleElement!.renderObject as RenderBox;
    final handleCenter = renderHandle.localToGlobal(renderHandle.size.center(Offset.zero));

    await tapAt(handleCenter);
  }

  /// Taps in a [SuperTextField] at the given [offset]
  ///
  /// {@macro supertextfield_finder}
  Future<void> tapAtSuperTextField(
    int offset, {
    Finder? superTextFieldFinder,
    TextAffinity affinity = TextAffinity.downstream,
    int buttons = kPrimaryButton,
  }) async {
    await _tapAtSuperTextField(offset, 1, superTextFieldFinder, affinity, buttons);
  }

  /// Double taps in a [SuperTextField] at the given [offset]
  ///
  /// {@macro supertextfield_finder}
  Future<void> doubleTapAtSuperTextField(int offset,
      [Finder? superTextFieldFinder, TextAffinity affinity = TextAffinity.downstream]) async {
    await _tapAtSuperTextField(offset, 2, superTextFieldFinder, affinity);
  }

  /// Triple taps in a [SuperTextField] at the given [offset]
  ///
  /// {@macro supertextfield_finder}
  Future<void> tripleTapAtSuperTextField(int offset,
      [Finder? superTextFieldFinder, TextAffinity affinity = TextAffinity.downstream]) async {
    await _tapAtSuperTextField(offset, 3, superTextFieldFinder, affinity);
  }

  Future<void> _tapAtSuperTextField(int offset, int tapCount,
      [Finder? superTextFieldFinder,
      TextAffinity affinity = TextAffinity.downstream,
      int buttons = kPrimaryButton]) async {
    // TODO: De-duplicate this behavior with placeCaretInSuperTextField
    final fieldFinder =
        SuperTextFieldInspector.findInnerPlatformTextField(superTextFieldFinder ?? find.byType(SuperTextField));
    final match = fieldFinder.evaluate().single.widget;
    final scrollDelta = SuperTextFieldInspector.findScrollOffset(superTextFieldFinder)!;
    final scrollOffset =
        SuperTextFieldInspector.isSingleLine(superTextFieldFinder) ? Offset(scrollDelta, 0) : Offset(0, scrollDelta);

    if (match is SuperDesktopTextField) {
      final superDesktopTextField = state<SuperDesktopTextFieldState>(fieldFinder);
      for (int i = 1; i <= tapCount; i++) {
        bool didTap = await _tapAtTextPositionOnDesktop(
          superDesktopTextField,
          offset,
          affinity,
          scrollOffset,
          buttons,
        );
        if (!didTap) {
          throw Exception("The desired text offset wasn't tappable in SuperTextField: $offset");
        }
        await pump(tapCount > 1 ? kDoubleTapMinTime : kDoubleTapTimeout);
      }

      await pumpAndSettle();

      return;
    }

    if (match is SuperAndroidTextField) {
      for (int i = 1; i <= tapCount; i++) {
        bool didTap = await _tapAtTextPositionOnAndroid(
          state<SuperAndroidTextFieldState>(fieldFinder),
          offset,
          affinity,
          scrollOffset,
          buttons,
        );
        if (!didTap) {
          throw Exception("The desired text offset wasn't tappable in SuperTextField: $offset");
        }
        await pump(tapCount > 1 ? kDoubleTapMinTime : kDoubleTapTimeout);
      }

      await pumpAndSettle();

      return;
    }

    if (match is SuperIOSTextField) {
      for (int i = 1; i <= tapCount; i++) {
        bool didTap = await _tapAtTextPositionOnIOS(
          state<SuperIOSTextFieldState>(fieldFinder),
          offset,
          affinity,
          scrollOffset,
          buttons,
        );
        if (!didTap) {
          throw Exception("The desired text offset wasn't tappable in SuperTextField: $offset");
        }
        await pump(tapCount > 1 ? kDoubleTapMinTime : kDoubleTapTimeout);
      }

      await pumpAndSettle();

      return;
    }

    throw Exception("Couldn't find a SuperTextField with the given Finder: $fieldFinder");
  }

  Future<bool> _tapAtTextPositionOnDesktop(
    SuperDesktopTextFieldState textField,
    int offset, [
    TextAffinity textAffinity = TextAffinity.downstream,
    Offset scrollOffset = Offset.zero,
    int buttons = kPrimaryButton,
  ]) async {
    final textFieldBox = textField.context.findRenderObject() as RenderBox;
    return await _tapAtTextPositionInTextLayout(
      textField.textLayout,
      textField.textLayoutOffsetInField,
      textFieldBox,
      offset,
      textAffinity,
      scrollOffset,
      buttons,
    );
  }

  Future<bool> _tapAtTextPositionOnAndroid(
    SuperAndroidTextFieldState textField,
    int offset, [
    TextAffinity textAffinity = TextAffinity.downstream,
    Offset scrollOffset = Offset.zero,
    int buttons = kPrimaryButton,
  ]) async {
    final textFieldBox = textField.context.findRenderObject() as RenderBox;
    return await _tapAtTextPositionInTextLayout(
      textField.textLayout,
      textField.textLayoutOffsetInField,
      textFieldBox,
      offset,
      textAffinity,
      scrollOffset,
      buttons,
    );
  }

  Future<bool> _tapAtTextPositionOnIOS(
    SuperIOSTextFieldState textField,
    int offset, [
    TextAffinity textAffinity = TextAffinity.downstream,
    Offset scrollOffset = Offset.zero,
    int buttons = kPrimaryButton,
  ]) async {
    final textFieldBox = textField.context.findRenderObject() as RenderBox;
    return await _tapAtTextPositionInTextLayout(
      textField.textLayout,
      textField.textLayoutOffsetInField,
      textFieldBox,
      offset,
      textAffinity,
      scrollOffset,
      buttons,
    );
  }

  Future<bool> _tapAtTextPositionInTextLayout(
    TextLayout textLayout,
    Offset textOffsetInField, // i.e., the padding around the text
    RenderBox textFieldBox,
    int offset, [
    TextAffinity textAffinity = TextAffinity.downstream,
    Offset scrollOffset = Offset.zero,
    int buttons = kPrimaryButton,
  ]) async {
    final textPositionOffset = textLayout.getOffsetForCaret(
      TextPosition(offset: offset, affinity: textAffinity),
    );

    // Adjust the text offset from text layout coordinates to text field viewport coordinates
    // by adding the scroll offset.
    Offset adjustedOffset = textPositionOffset - scrollOffset;

    // When upgrading Superlist to Flutter 3, some tests showed a caret offset
    // dy of -0.2. This didn't happen everywhere, but it did happen some places.
    // Until we get to the bottom of this issue, we'll add a constant offset to
    // make up for this.
    adjustedOffset += const Offset(0, 0.2);

    // There's a problem on Windows and Linux where we get -0.0 instead of 0.0.
    // We adjust the offset to get rid of the -0.0, because a -0.0 fails the
    // Rect bounds check. (https://github.com/flutter/flutter/issues/100033)
    adjustedOffset = Offset(
      adjustedOffset.dx,
      // I tried checking "== -0.0" but it didn't catch the problem. This
      // approach looks for an arbitrarily small epsilon and then interprets
      // any such bounds as zero.
      adjustedOffset.dy.abs() < 1e-6 ? 0.0 : adjustedOffset.dy,
    );

    if (adjustedOffset.dx == textFieldBox.size.width) {
      adjustedOffset += const Offset(-10, 0);
    }

    if (!textFieldBox.size.contains(adjustedOffset)) {
      throw Exception(
        "Couldn't tap at text position because it's not visible. Text field viewport size: ${textFieldBox.size}, text offset in viewport $adjustedOffset. Raw text offset: $textPositionOffset). Text field scroll offset: $scrollOffset",
      );
    }

    final globalTapOffset = textOffsetInField + adjustedOffset + textFieldBox.localToGlobal(Offset.zero);
    await tapAt(
      globalTapOffset,
      buttons: buttons,
    );
    return true;
  }

  Future<void> selectSuperTextFieldText(int start, int end, [Finder? superTextFieldFinder]) async {
    final fieldFinder =
        SuperTextFieldInspector.findInnerPlatformTextField(superTextFieldFinder ?? find.byType(SuperTextField));
    final match = fieldFinder.evaluate().single.widget;

    if (match is SuperDesktopTextField) {
      final didSelectText = await _selectTextOnDesktop(state<SuperDesktopTextFieldState>(fieldFinder), start, end);
      if (!didSelectText) {
        throw Exception("One or both of the desired text offsets weren't tappable in SuperTextField: $start -> $end");
      }

      // Pump and settle so that the gesture recognizer doesn't retain pending timers.
      await pumpAndSettle();

      return;
    }

    if (match is SuperAndroidTextField) {
      throw Exception("Selecting text on an Android SuperTextField is not yet supported");
    }

    if (match is SuperIOSTextField) {
      throw Exception("Selecting text on an iOS SuperTextField is not yet supported");
    }

    throw Exception("Couldn't find a SuperTextField with the given Finder: $fieldFinder");
  }

  Future<bool> _selectTextOnDesktop(SuperDesktopTextFieldState textField, int start, int end) async {
    final startTextPositionOffset = textField.textLayout.getOffsetForCaret(TextPosition(offset: start));
    final endTextPositionOffset = textField.textLayout.getOffsetForCaret(TextPosition(offset: end));
    final textFieldBox = textField.context.findRenderObject() as RenderBox;

    // When upgrading Superlist to Flutter 3, some tests showed a caret offset
    // dy of -0.2. This didn't happen everywhere, but it did happen some places.
    // Until we get to the bottom of this issue, we'll add a constant offset to
    // make up for this.
    Offset adjustedStartOffset = startTextPositionOffset + const Offset(0, 0.2);
    Offset adjustedEndOffset = endTextPositionOffset + const Offset(0, 0.2);

    // There's a problem on Windows and Linux where we get -0.0 instead of 0.0.
    // We adjust the offset to get rid of the -0.0, because a -0.0 fails the
    // Rect bounds check. (https://github.com/flutter/flutter/issues/100033)
    adjustedStartOffset = Offset(
      adjustedStartOffset.dx,
      // I tried checking "== -0.0" but it didn't catch the problem. This
      // approach looks for an arbitrarily small epsilon and then interprets
      // any such bounds as zero.
      adjustedStartOffset.dy.abs() < 1e-6 ? 0.0 : adjustedStartOffset.dy,
    );
    adjustedEndOffset = Offset(
      adjustedEndOffset.dx,
      adjustedEndOffset.dy.abs() < 1e-6 ? 0.0 : adjustedEndOffset.dy,
    );

    if (!textFieldBox.size.contains(adjustedStartOffset)) {
      return false;
    }
    if (!textFieldBox.size.contains(adjustedEndOffset)) {
      return false;
    }

    final globalStartDragOffset = adjustedStartOffset + textFieldBox.localToGlobal(Offset.zero);
    final globalEndDragOffset = adjustedEndOffset + textFieldBox.localToGlobal(Offset.zero);

    await dragFrom(
      globalStartDragOffset,
      globalEndDragOffset - globalStartDragOffset,
      kind: PointerDeviceKind.mouse,
    );

    return true;
  }
}
