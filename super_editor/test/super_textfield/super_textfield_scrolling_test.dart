import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/src/infrastructure/text_input.dart';
import 'package:super_editor/src/super_textfield/super_textfield.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:super_editor/super_text_field_test.dart';

import '../test_tools.dart';

void main() {
  group("SuperTextField > scrolling >", () {
    group("single line >", () {
      testWidgetsOnAllPlatforms("scroll bar doesn't appear when empty", (tester) async {
        await _pumpSingleLineTextField(tester);

        // The bug that originally caused an issue with empty scrolling (#1749) didn't have
        // a scrollable distance until the 2nd frame. Therefore, we pump one extra frame.
        await tester.pump();
        await tester.pump();

        // Ensure that the text field isn't scrollable (the content shouldn't exceed the viewport).
        expect(SuperTextFieldInspector.hasScrollableExtent(), isFalse);
      });

      testWidgetsOnAllPlatforms("scroll bar doesn't appear when viewport width slightly shrinks", (tester) async {
        // Display a text field without an icon to the right.
        await _pumpSingleLineTextField(tester);

        // Pump a new frame where we add an icon to the right of the text field, slightly
        // reducing the width of the text field.
        await _pumpSingleLineTextField(tester, showClearIcon: true);

        // Ensure that the text field isn't scrollable (the content shouldn't exceed the viewport).
        expect(SuperTextFieldInspector.hasScrollableExtent(), isFalse);
      });

      testWidgetsOnAllPlatforms("auto scrolls when the user types beyond viewport edge", (tester) async {
        const textFieldWidth = 400.0;

        final controller = AttributedTextEditingController();
        await _pumpSingleLineTextField(
          tester,
          controller: controller,
          width: textFieldWidth,
        );

        // Place the caret at the beginning of the text.
        await tester.placeCaretInSuperTextField(0);

        // Ensure the text field has a selection.
        expect(SuperTextFieldInspector.findSelection()!.isValid, isTrue);

        // Type characters to the right, well beyond the right edge of the
        // viewport. Ensure that the caret remains visible at all times.
        const textToType = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus sed sagittis urna.";
        for (int i = 0; i < textToType.length; i += 1) {
          await tester.typeImeText(textToType[i]);
          await tester.pump();

          // Ensure that the caret is still visible.
          // TODO: Change lessThanOrEqualTo() to strictly lessThan() after #1770
          expect(SuperTextFieldInspector.findCaretRectInViewport()!.left, lessThanOrEqualTo(textFieldWidth),
              reason: "Failed to auto-scroll on character $i - '${textToType[i]}'");
        }
      });

      testWidgetsOnArbitraryDesktop("auto scrolls when caret moves beyond viewport edge", (tester) async {
        const textFieldWidth = 400.0;

        await _pumpSingleLineTextField(
          tester,
          controller: AttributedTextEditingController(
            text: AttributedText(
                "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus sed sagittis urna. Aenean mattis ante justo, quis sollicitudin metus interdum id. Aenean ornare urna ac enim consequat mollis. In aliquet convallis efficitur. Phasellus convallis purus in fringilla scelerisque. Ut ac orci a turpis egestas lobortis. Morbi aliquam dapibus sem, vitae sodales arcu ultrices eu. Duis vulputate mauris quam, eleifend pulvinar quam blandit eget."),
          ),
          width: textFieldWidth,
        );

        // Place the caret at the beginning of the text.
        await tester.placeCaretInSuperTextField(0);

        // Ensure the text field has a selection.
        expect(SuperTextFieldInspector.findSelection()!.isValid, isTrue);

        // Move the caret to the right a large number of times, such that it's
        // guaranteed to push beyond the right edge of the viewport. Ensure that
        // the caret remains visible at all times.
        for (int i = 0; i < 100; i += 1) {
          await tester.pressRightArrow();
          await tester.pump();

          // Ensure that the caret is still visible.
          // TODO: Change lessThanOrEqualTo() to strictly lessThan() after #1770
          expect(SuperTextFieldInspector.findCaretRectInViewport()!.left, lessThanOrEqualTo(textFieldWidth));
        }
      });

      testWidgetsOnMobile("auto scrolls when caret is dragged into auto-scroll region", (tester) async {
        const textFieldWidth = 400.0;

        await _pumpSingleLineTextField(
          tester,
          controller: AttributedTextEditingController(
            text: AttributedText(
                "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus sed sagittis urna. Aenean mattis ante justo, quis sollicitudin metus interdum id."),
          ),
          width: textFieldWidth,
        );

        // Place the caret at the beginning of the text.
        await tester.placeCaretInSuperTextField(0);

        // Ensure the text field has a selection.
        expect(SuperTextFieldInspector.findSelection()!.isValid, isTrue);

        // Drag the caret from the left side of the text field to the right side
        // of the text field and hold it in the auto-scroll region.
        final drag = await tester.dragCaretByDistanceInSuperTextField(const Offset(textFieldWidth, 0));

        // While holding the caret in the auto-scroll region, we expect the scroll offset to
        // increase on every frame, until we get to the end.
        var scrollOffset = SuperTextFieldInspector.findScrollOffset()!;
        var previousScrollOffset = scrollOffset;
        do {
          previousScrollOffset = scrollOffset;

          // Pump a frame to auto-scroll to the right. Pass a duration that's long enough
          // to pass the minimum auto-scroll time in SuperTextField.
          await tester.pump(const Duration(milliseconds: 50));

          scrollOffset = SuperTextFieldInspector.findScrollOffset()!;

          // Ensure that we haven't exceeded the max scroll offset. If there's a bug that allows
          // us to exceed the max scroll offset, this test might run forever.
          expect(
            SuperTextFieldInspector.findScrollOffset(),
            lessThanOrEqualTo(SuperTextFieldInspector.findMaxScrollOffset()!),
            reason:
                "While auto-scrolling to the right, we exceeded the max scroll offset of the text field, which should never be allowed to happen",
          );
        } while (scrollOffset > previousScrollOffset);

        // Now that we've auto-scrolled as far to the right as possible, we should be
        // at the max scroll offset.
        expect(SuperTextFieldInspector.findScrollOffset(), SuperTextFieldInspector.findMaxScrollOffset());

        // Drag all the way back to the left side of the text field.
        //
        // +20 to get past the auto-scroll boundary and then also add some
        // scroll speed for a faster test run. Note: it seems that we need
        // at least +2 to even trigger aut-scroll. The rest is for speed.
        // This might be due to touch slop, or possibly some other gesture
        // detail that impacts how far we initially dragged to the right.
        await tester.dragContinuation(drag, const Offset(-(textFieldWidth + 20), 0));

        // Now that we auto-scrolled all the way to the right, auto-scroll back all the way to
        // the left.
        do {
          previousScrollOffset = scrollOffset;

          // Pump a frame to auto-scroll to the right. Pass a duration that's long enough
          // to pass the minimum auto-scroll time in SuperTextField.
          await tester.pump(const Duration(milliseconds: 50));

          scrollOffset = SuperTextFieldInspector.findScrollOffset()!;

          // Ensure that we haven't exceeded the min scroll offset. If there's a bug that allows
          // us to exceed the min scroll offset, this test might run forever.
          expect(
            SuperTextFieldInspector.findScrollOffset(),
            greaterThanOrEqualTo(0),
            reason:
                "While auto-scrolling to the left, we exceeded the min scroll offset of the text field, which should never be allowed to happen",
          );
        } while (previousScrollOffset > scrollOffset);

        // Now that we've auto-scrolled as far to the left as possible, we should be
        // at the min scroll offset.
        expect(SuperTextFieldInspector.findScrollOffset(), 0);

        // Release the gesture so the test can end.
        await drag.up();
      });
    });
  });
}

Future<void> _pumpSingleLineTextField(
  WidgetTester tester, {
  AttributedTextEditingController? controller,
  double? width,
  bool showClearIcon = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width ?? 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SuperTextField(
                        textController: controller,
                        hintBuilder: _createHintBuilder("Hint text..."),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                        minLines: 1,
                        maxLines: 1,
                        inputSource: TextInputSource.ime,
                      ),
                    ),
                    if (showClearIcon) //
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(Icons.clear, size: 16),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

WidgetBuilder _createHintBuilder(String hintText) {
  return (BuildContext context) {
    return Text(
      hintText,
      style: const TextStyle(color: Colors.grey),
    );
  };
}
