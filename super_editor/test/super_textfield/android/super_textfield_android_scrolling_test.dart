import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/src/infrastructure/multi_tap_gesture.dart';
import 'package:super_editor/super_text_field.dart';
import 'package:super_editor/super_text_field_test.dart';

void main() {
  group("SuperTextField > scrolling >", () {
    testWidgetsOnAndroid('auto-scrolls to caret position upon widget initialization', (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText("This is long text that extends beyond the right side of the text field."),
      );
      controller.selection = TextSelection.collapsed(offset: controller.text.length);

      // Pump the widget tree with a SuperTextField with a maxWidth smaller
      // than the text width.
      await _pumpTestApp(
        tester,
        textController: controller,
        minLines: 1,
        maxLines: 1,
        // This width is important because it determines how far we need to drag the caret
        // to the right to enter the auto-scroll region.
        maxWidth: 200,
      );

      // Ensure that the text field auto-scrolled to the end, where the caret should be placed.
      expect(SuperTextFieldInspector.isScrolledToEnd(), isTrue);
    });

    testWidgetsOnAndroid('single-line auto-scrolls to the right by caret', (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText("This is long text that extends beyond the right side of the text field."),
      );

      // Pump the widget tree with a SuperTextField with a maxWidth smaller
      // than the text width.
      await _pumpTestApp(
        tester,
        textController: controller,
        minLines: 1,
        maxLines: 1,
        // This width is important because it determines how far we need to drag the caret
        // to the right to enter the auto-scroll region.
        maxWidth: 200,
      );

      await tester.placeCaretInSuperTextField(0);
      expect(controller.selection.extentOffset, 0);

      // Drag caret from left side of text field to right side of text field, into the
      // right auto-scroll region.
      final gesture = await tester.dragCaretByDistanceInSuperTextField(const Offset(220, 0));

      // Pump a few more frames and ensure that every frame moves the caret further.
      int previousCaretPosition = controller.selection.extentOffset;
      for (int i = 0; i < 10; i += 1) {
        await tester.pump(const Duration(milliseconds: 50));
        final newCaretPosition = controller.selection.extentOffset;
        expect(newCaretPosition, greaterThan(previousCaretPosition),
            reason: "Caret position didn't move on drag frame $i");
        previousCaretPosition = newCaretPosition;
      }

      // Log the scroll offset to make sure that the scroll offset doesn't jump back
      // to the left when we move out of the auto-scroll region. This is a glitch that
      // we saw in #1673.
      final scrollOffsetAfterAutoScroll = SuperTextFieldInspector.findScrollOffset();

      // Drag back to the left to leave the auto-scroll region.
      await gesture.moveBy(const Offset(-50, 0));
      await tester.pump();

      // Pump a few frames to ensure that the selection isn't jumping around
      // in a glitchy manner.
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      // Ensure that when we moved slightly back to the left, to move out of the auto-scroll
      // region, the scroll offset didn't jump somewhere else.
      expect(SuperTextFieldInspector.findScrollOffset(), scrollOffsetAfterAutoScroll);

      // Release the gesture.
      await gesture.up();

      // Ensure that the scroll offset didn't change after we released.
      expect(SuperTextFieldInspector.findScrollOffset(), scrollOffsetAfterAutoScroll);
    });

    testWidgetsOnAndroid('single-line auto-scrolls to the right by handle', (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText("This is long text that extends beyond the right side of the text field."),
      );

      // Pump the widget tree with a SuperTextField with a maxWidth smaller
      // than the text width.
      await _pumpTestApp(
        tester,
        textController: controller,
        minLines: 1,
        maxLines: 1,
        // This width is important because it determines how far we need to drag the caret
        // to the right to enter the auto-scroll region.
        maxWidth: 200,
      );

      await tester.placeCaretInSuperTextField(0);
      expect(controller.selection.extentOffset, 0);

      // Drag handle from left side of text field to right side of text field, into the
      // right auto-scroll region.
      final gesture = await tester.dragAndroidCollapsedHandleByDistanceInSuperTextField(const Offset(190, 0));

      // Pump a few more frames and ensure that every frame moves the caret further.
      int previousCaretPosition = controller.selection.extentOffset;
      for (int i = 0; i < 10; i += 1) {
        await tester.pump(const Duration(milliseconds: 50));
        final newCaretPosition = controller.selection.extentOffset;
        expect(newCaretPosition, greaterThan(previousCaretPosition),
            reason: "Caret position didn't move on drag frame $i");
        previousCaretPosition = newCaretPosition;
      }

      // Log the scroll offset to make sure that the scroll offset doesn't jump back
      // to the left when we move out of the auto-scroll region. This is a glitch that
      // we saw in #1673.
      final scrollOffsetAfterAutoScroll = SuperTextFieldInspector.findScrollOffset();

      // Drag back to the left to leave the auto-scroll region.
      await gesture.moveBy(const Offset(-50, 0));
      await tester.pump();

      // Pump a few frames to ensure that the selection isn't jumping around
      // in a glitchy manner.
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      // Ensure that when we moved slightly back to the left, to move out of the auto-scroll
      // region, the scroll offset didn't jump somewhere else.
      expect(SuperTextFieldInspector.findScrollOffset(), scrollOffsetAfterAutoScroll);

      // Release the gesture.
      await gesture.up();

      // Ensure that the scroll offset didn't change after we released.
      expect(SuperTextFieldInspector.findScrollOffset(), scrollOffsetAfterAutoScroll);

      // When working on #1673 I found that specifically when dragging to the right using
      // the handle (not caret), the text field jumps all the way to the end of the text.
      // Make sure we're not at the end of the text.
      expect(SuperTextFieldInspector.isScrolledToEnd(), isFalse);
    });

    testWidgetsOnAndroid('single-line auto-scrolls to the left', (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText("This is long text that extends beyond the right side of the text field."),
      );
      controller.selection = TextSelection.collapsed(offset: controller.text.length);

      // Pump the widget tree with a SuperTextField with a maxWidth smaller
      // than the text width.
      await _pumpTestApp(
        tester,
        textController: controller,
        minLines: 1,
        maxLines: 1,
        // This width is important because it determines how far we need to drag the caret
        // to the right to enter the auto-scroll region.
        maxWidth: 200,
        // Add padding to leave room to see the caret at the very end of the
        // text.
        padding: const EdgeInsets.symmetric(horizontal: 2),
        autofocus: true,
      );

      // Ensure we're starting scrolled to the end.
      expect(SuperTextFieldInspector.isScrolledToEnd(), isTrue);

      // Drag caret from right side of text field to left side of text field, into the
      // left auto-scroll region.
      final gesture = await tester.dragCaretByDistanceInSuperTextField(const Offset(-220, 0));

      // Pump a few more frames and ensure that every frame moves the caret further.
      int previousCaretPosition = controller.selection.extentOffset;
      for (int i = 0; i < 10; i += 1) {
        await tester.pump(const Duration(milliseconds: 50));
        final newCaretPosition = controller.selection.extentOffset;
        expect(newCaretPosition, lessThan(previousCaretPosition),
            reason: "Caret position didn't move on drag frame $i");
        previousCaretPosition = newCaretPosition;
      }

      // Log the scroll offset to make sure that the scroll offset doesn't jump back
      // to the left when we move out of the auto-scroll region. This is a glitch that
      // we saw in #1673.
      final scrollOffsetAfterAutoScroll = SuperTextFieldInspector.findScrollOffset();

      // Drag back to the right to leave the auto-scroll region.
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump();

      // Pump a few frames to ensure that we're the selection isn't jumping around
      // in a glitchy manner.
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // Ensure that when we moved slightly back to the right, to move out of the auto-scroll
      // region, the scroll offset didn't jump somewhere else.
      expect(SuperTextFieldInspector.findScrollOffset(), scrollOffsetAfterAutoScroll);

      // Release the gesture.
      await gesture.up();
    });

    testWidgetsOnAndroid('single-line drag does nothing without a selection', (tester) async {
      // Test explanation: I experimented with single-line text fields in a few iOS apps
      // and I found that dragging in an area away from the caret doesn't have any effect.
      // It doesn't scroll the text field, it doesn't move the caret, nothing.
      final controller = AttributedTextEditingController(
        text: AttributedText("This is long text that extends beyond the right side of the text field."),
      );

      // Pump the widget tree with a SuperTextField with a maxWidth smaller
      // than the text width.
      await _pumpTestApp(
        tester,
        textController: controller,
        minLines: 1,
        maxLines: 1,
        // This width is important because it determines whether the text fits, or
        // if scrolling is available.
        maxWidth: 200,
      );

      // Ensure there's no selection and no focus.
      expect(SuperTextFieldInspector.findSelection()!.isValid, isFalse);
      expect(SuperTextFieldInspector.hasFocus(), isFalse);

      // Drag from right to left.
      await tester.drag(find.byType(SuperTextField), const Offset(-100, 0));

      // Ensure the scroll offset didn't change and there's still no selection or focus.
      expect(SuperTextFieldInspector.findScrollOffset()!, 0);
      expect(SuperTextFieldInspector.findSelection()!.isValid, isFalse);
      expect(SuperTextFieldInspector.hasFocus(), isFalse);

      // Pump with enough time to expire the tap recognizer timer.
      await tester.pump(kTapTimeout);
    });

    testWidgetsOnAndroid('single-line drag does nothing with collapsed selection', (tester) async {
      // Test explanation: I experimented with single-line text fields in a few iOS apps
      // and I found that dragging in an area away from the caret doesn't have any effect.
      // It doesn't scroll the text field, it doesn't move the caret, nothing.
      final controller = AttributedTextEditingController(
        text: AttributedText("This is long text that extends beyond the right side of the text field."),
      );

      // Pump the widget tree with a SuperTextField with a maxWidth smaller
      // than the text width.
      await _pumpTestApp(
        tester,
        textController: controller,
        minLines: 1,
        maxLines: 1,
        // This width is important because it determines whether the text fits, or
        // if scrolling is available.
        maxWidth: 200,
      );

      // Place a caret in the field.
      await tester.placeCaretInSuperTextField(0);

      // Ensure there's a selection with focus.
      expect(SuperTextFieldInspector.findSelection()!.isValid, isTrue);
      expect(SuperTextFieldInspector.hasFocus(), isTrue);

      // Drag from right to left, far away from the caret.
      final selectionBeforeDrag = SuperTextFieldInspector.findSelection();
      await tester.drag(find.byType(SuperTextField), const Offset(100, 0));

      // Ensure the scroll offset and the selection didn't change.
      expect(SuperTextFieldInspector.findScrollOffset()!, 0);
      expect(SuperTextFieldInspector.findSelection(), selectionBeforeDrag);

      // Pump with enough time to expire the tap recognizer timer.
      await tester.pump(kTapTimeout);
    });
  });
}

Future<void> _pumpTestApp(
  WidgetTester tester, {
  required AttributedTextEditingController textController,
  required int minLines,
  required int maxLines,
  double? maxWidth,
  double? maxHeight,
  EdgeInsets? padding,
  bool autofocus = false,
}) async {
  final focusNode = FocusNode();
  if (autofocus) {
    focusNode.requestFocus();
  }

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth ?? double.infinity,
              maxHeight: maxHeight ?? double.infinity,
            ),
            child: SuperTextField(
              focusNode: focusNode,
              textController: textController,
              lineHeight: 20,
              textStyleBuilder: (_) => const TextStyle(fontSize: 20),
              minLines: minLines,
              maxLines: maxLines,
              padding: padding,
            ),
          ),
        ),
      ),
    ),
  );

  // The first frame might have a zero viewport height. Pump a second frame to account for the final viewport size.
  await tester.pump();
}
