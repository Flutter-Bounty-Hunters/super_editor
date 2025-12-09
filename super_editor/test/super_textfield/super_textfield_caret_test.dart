import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_text_field_test.dart';
import 'package:super_text_layout/super_text_layout.dart';

void main() {
  group("SuperTextField caret", () {
    // Duration to switch between visible and invisible
    const flashPeriod = Duration(milliseconds: 500);

    testWidgetsOnDesktop("blinks at rest", (tester) async {
      // Configure BlinkController to animate, otherwise it won't blink
      BlinkController.indeterminateAnimationsEnabled = true;
      addTearDown(() => BlinkController.indeterminateAnimationsEnabled = false);

      await tester.pumpWidget(
        _buildScaffold(
          child: SuperTextField(
            textStyleBuilder: (_) => const TextStyle(fontSize: 16),
          ),
        ),
      );

      // Press tab to focus SuperTextField
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      // Ensure caret is visible at start
      expect(_isCaretVisible(tester), true);

      // Trigger a frame with an ellapsed time equal to the flashPeriod,
      // so the caret should change from visible to invisible
      await tester.pump(flashPeriod);

      // Ensure caret is invisible after the flash period
      expect(_isCaretVisible(tester), false);

      // Trigger another frame to make caret visible again
      await tester.pump(flashPeriod);

      // Ensure caret is visible
      expect(_isCaretVisible(tester), true);
    });

    testWidgetsOnDesktop("does NOT blink while typing", (tester) async {
      // Configure BlinkController to animate, otherwise it won't blink
      BlinkController.indeterminateAnimationsEnabled = true;
      addTearDown(() => BlinkController.indeterminateAnimationsEnabled = false);

      // Interval between each key is pressed.
      final typingInterval = (flashPeriod ~/ 2);

      await tester.pumpWidget(
        _buildScaffold(
          child: SuperTextField(
            textStyleBuilder: (_) => const TextStyle(fontSize: 16),
          ),
        ),
      );

      // Press tab to focus SuperTextField
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      // Type after half of the flash period
      await tester.pump(typingInterval);
      await tester.typeKeyboardText("a");
      // Ensure that typing keeps caret visible
      expect(_isCaretVisible(tester), true);

      // Type after half of the flash period
      await tester.pump(typingInterval);
      await tester.typeKeyboardText("b");
      // Ensure that typing keeps caret visible
      expect(_isCaretVisible(tester), true);

      // Type after half of the flash period
      await tester.pump(typingInterval);
      await tester.typeKeyboardText("c");
      // Ensure that typing keeps caret visible
      expect(_isCaretVisible(tester), true);

      // Type after half of the flash period
      await tester.pump(typingInterval);
      await tester.typeKeyboardText("d");
      // Ensure that typing keeps caret visible
      expect(_isCaretVisible(tester), true);
    });

    testWidgetsOnAllPlatforms("is NOT displayed without a text selection", (tester) async {
      await tester.pumpWidget(
        _buildScaffold(
          child: const SuperTextField(),
        ),
      );
      await tester.pump();

      expect(_isCaretPresent(tester), isFalse);
    });

    testWidgetsOnAllPlatforms("is displayed with focus and a collapsed text selection", (tester) async {
      final controller = AttributedTextEditingController(
        selection: const TextSelection.collapsed(offset: 0),
      );

      await tester.pumpWidget(
        _buildScaffold(
          child: SuperTextField(
            focusNode: FocusNode()..requestFocus(),
            textController: controller,
          ),
        ),
      );
      await tester.pump();

      expect(_isCaretPresent(tester), isTrue);
    });

    testWidgetsOnMobile("is NOT displayed with focus and an expanded text selection", (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText("Hello, world!"),
        selection: const TextSelection(baseOffset: 0, extentOffset: 5),
      );

      await tester.pumpWidget(
        _buildScaffold(
          child: SuperTextField(
            focusNode: FocusNode()..requestFocus(),
            textController: controller,
          ),
        ),
      );
      await tester.pump();

      expect(_isCaretPresent(tester), isFalse);
    });

    testWidgetsOnAllPlatforms("uses the given caretStyle", (tester) async {
      final controller = AttributedTextEditingController(
        selection: const TextSelection.collapsed(offset: 0),
      );

      const caretStyle = CaretStyle(
        color: Colors.red,
        width: 5,
        borderRadius: BorderRadius.all(Radius.circular(2.0)),
      );

      await tester.pumpWidget(
        _buildScaffold(
          child: SuperTextField(
            focusNode: FocusNode()..requestFocus(),
            textController: controller,
            caretStyle: caretStyle,
          ),
        ),
      );
      await tester.pump();

      final caret = tester.widget<TextLayoutCaret>(find.byType(TextLayoutCaret));

      expect(caret.style.color, caretStyle.color);
      expect(caret.style.width, caretStyle.width);
      expect(caret.style.borderRadius, caretStyle.borderRadius);
    });

    testWidgetsOnMobile("does not blink while dragging the caret", (tester) async {
      addTearDown(() => BlinkController.indeterminateAnimationsEnabled = false);

      final controller = AttributedTextEditingController(
        text: AttributedText(
          'SuperTextField with a content that spans multiple lines of text to test scrolling with  a scrollbar.',
        ),
      );

      await tester.pumpWidget(
        _buildScaffold(
          child: SuperTextField(
            textController: controller,
          ),
        ),
      );

      await tester.placeCaretInSuperTextField(0);

      // Configure BlinkController to animate, otherwise it won't blink.
      BlinkController.indeterminateAnimationsEnabled = true;

      // Drag caret by a small distance so that we trigger a user drag event.
      // This drag event is continued down below so that we can check for caret blinking
      // during a user drag.
      final TestGesture gesture = await tester.dragCaretByDistanceInSuperTextField(const Offset(100, 100));
      addTearDown(() => gesture.removePointer());

      // Check for the caret visibility across 3-4 frames and ensure it doesn't blink.
      // Test in half-flash period intervals as we don't know how much time has passed and
      // we might get unlucky and check the visibility when the caret is momentarily
      // invisible.

      // Ensure caret is visible.
      expect(_isCaretVisible(tester), true);

      await tester.pump(flashPeriod ~/ 2);

      // Ensure caret is visible.
      expect(_isCaretVisible(tester), true);

      await tester.pump(flashPeriod ~/ 2);

      // Ensure caret is visible.
      expect(_isCaretVisible(tester), true);

      await tester.pump(flashPeriod ~/ 2);

      // Ensure caret is visible.
      expect(_isCaretVisible(tester), true);
    });

    testWidgetsOnMobile("does not blink while dragging expanded handles", (tester) async {
      addTearDown(() => BlinkController.indeterminateAnimationsEnabled = false);

      final controller = AttributedTextEditingController(
        text: AttributedText(
          'SuperTextField with a content that spans multiple lines of text to test scrolling with  a scrollbar.',
        ),
      );

      await tester.pumpWidget(
        _buildScaffold(
          child: SuperTextField(
            textController: controller,
          ),
        ),
      );

      await tester.doubleTapAtSuperTextField(0);

      // Configure BlinkController to animate, otherwise it won't blink.
      BlinkController.indeterminateAnimationsEnabled = true;

      // Drag the upstream selection handle by a small distance so that we trigger a
      // user drag event. This drag event is continued down below so that we can check
      // for caret blinking during a user drag.
      final TestGesture upstreamHandleGesture =
          await tester.dragUpstreamMobileHandleByDistanceInSuperTextField(const Offset(100, 100));
      addTearDown(() => upstreamHandleGesture.removePointer());

      // Check for the caret visibility across 3-4 frames and ensure it doesn't blink.
      // Test in half-flash period intervals as we don't know how much time has passed and
      // we might get unlucky and check the visibility when the caret is momentarily
      // invisible.

      // Ensure caret is visible.
      expect(_isCaretVisible(tester), true);

      await tester.pump(flashPeriod ~/ 2);

      // Ensure caret is visible.
      expect(_isCaretVisible(tester), true);

      await tester.pump(flashPeriod ~/ 2);

      // Ensure caret is visible.
      expect(_isCaretVisible(tester), true);

      await tester.pump(flashPeriod ~/ 2);

      // Ensure caret is visible.
      expect(_isCaretVisible(tester), true);

      // End the current drag gesture before we start the downstream handle drag.
      // We don't want multiple gesture pointers active at the same time.
      await upstreamHandleGesture.up();
      await tester.pump();

      // Drag the downstream selection handle by a small distance so that we trigger a
      // user drag event. This drag event is continued down below so that we can check
      // for caret blinking during a user drag.
      final TestGesture downstreamHandleGesture =
          await tester.dragDownstreamMobileHandleByDistanceInSuperTextField(const Offset(100, 100));
      addTearDown(() => downstreamHandleGesture.removePointer());

      // Check for the caret visibility across 3-4 frames and ensure it doesn't blink.
      // Test in half-flash period intervals as we don't know how much time has passed and
      // we might get unlucky and check the visibility when the caret is momentarily
      // invisible.

      // Ensure caret is visible.
      expect(_isCaretVisible(tester), true);

      await tester.pump(flashPeriod ~/ 2);

      // Ensure caret is visible.
      expect(_isCaretVisible(tester), true);

      await tester.pump(flashPeriod ~/ 2);

      // Ensure caret is visible.
      expect(_isCaretVisible(tester), true);

      await tester.pump(flashPeriod ~/ 2);

      // Ensure caret is visible.
      expect(_isCaretVisible(tester), true);
    });

    testWidgetsOnAndroid("does not blink while dragging collapsed handle", (tester) async {
      addTearDown(() => BlinkController.indeterminateAnimationsEnabled = false);

      final controller = AttributedTextEditingController(
        text: AttributedText(
          'SuperTextField with a content that spans multiple lines of text to test scrolling with  a scrollbar.',
        ),
      );

      await tester.pumpWidget(
        _buildScaffold(
          child: SuperTextField(
            textController: controller,
          ),
        ),
      );

      await tester.placeCaretInSuperTextField(0);

      // Configure BlinkController to animate, otherwise it won't blink.
      BlinkController.indeterminateAnimationsEnabled = true;

      // Drag the collapsed handle by a small distance so that we trigger a
      // user drag event. This drag event is continued down below so that we
      // can check for caret blinking during a user drag.
      final TestGesture gesture =
          await tester.dragAndroidCollapsedHandleByDistanceInSuperTextField(const Offset(100, 100));
      addTearDown(() => gesture.removePointer());

      // Check for the caret visibility across 3-4 frames and ensure it doesn't blink.
      // Test in half-flash period intervals as we don't know how much time has passed and
      // we might get unlucky and check the visibility when the caret is momentarily
      // invisible.

      // Ensure caret is visible.
      expect(_isCaretVisible(tester), true);

      await tester.pump(flashPeriod ~/ 2);

      // Ensure caret is visible.
      expect(_isCaretVisible(tester), true);

      await tester.pump(flashPeriod ~/ 2);

      // Ensure caret is visible.
      expect(_isCaretVisible(tester), true);

      await tester.pump(flashPeriod ~/ 2);

      // Ensure caret is visible.
      expect(_isCaretVisible(tester), true);
    });
  });
}

Widget _buildScaffold({
  required Widget child,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 300,
        child: child,
      ),
    ),
  );
}

bool _isCaretPresent(WidgetTester tester) {
  final caretMatches = find.byType(TextLayoutCaret).evaluate();
  if (caretMatches.isEmpty) {
    return false;
  }
  final caretState = (caretMatches.single as StatefulElement).state as TextLayoutCaretState;
  return caretState.isCaretPresent;
}

bool _isCaretVisible(WidgetTester tester) {
  final customPaint = find.byWidgetPredicate((widget) => widget is CustomPaint && widget.painter is CaretPainter);
  final caretPainter = tester.widget<CustomPaint>(customPaint.last).painter as CaretPainter;
  return caretPainter.blinkController!.opacity == 1.0;
}
