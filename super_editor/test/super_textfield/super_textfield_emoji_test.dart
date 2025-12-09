import 'package:flutter/material.dart' hide SelectableText;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_text_field_test.dart';

void main() {
  group('SuperTextField with keyboard', () {
    group('containing only one emoji', () {
      testWidgetsOnAllPlatforms("moves caret upstream around the emoji", (tester) async {
        await _pumpSuperTextFieldEmojiTest(
          tester,
          text: '🐢',
        );

        // TODO: placing caret on the right side of the emoji at the end of the text isn't working correctly
        // #549 - update to place caret at the end and remove the call to pressRightArrow when that bug is fixed.
        // Place caret at the beginning of the text
        await tester.placeCaretInSuperTextField(0);
        // Move caret to the right
        await tester.pressRightArrow();

        // Ensure we are at the end of the text
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 2),
        );

        // Press left arrow key to move the selection to the beginning of the text
        await tester.pressLeftArrow();

        // Ensure caret is at the beginning of the text
        expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 0));
      });

      testWidgetsOnAllPlatforms("expands selection upstream around the emoji", (tester) async {
        await _pumpSuperTextFieldEmojiTest(
          tester,
          text: '🐢',
        );

        // TODO: placing caret on the right side of the emoji at the end of the text isn't working correctly
        // #549 - update to place caret at the end and remove the call to pressRightArrow when that bug is fixed.
        // Place caret at the beginning of the text
        await tester.placeCaretInSuperTextField(0);
        // Move caret to the right
        await tester.pressRightArrow();

        // Ensure we are at the end of the text
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 2),
        );

        // Press shift + left arrow key to expand the selection to the left
        await tester.pressShiftLeftArrow();

        // Ensure that the emoji is selected
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection(
            baseOffset: 2,
            extentOffset: 0,
          ),
        );
      });

      testWidgetsOnAllPlatforms("moves caret downstream around the emoji", (tester) async {
        await _pumpSuperTextFieldEmojiTest(
          tester,
          text: '🐢',
        );

        // Place caret before the emoji
        await tester.placeCaretInSuperTextField(0);

        // Ensure we are at the beginning of the text
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 0),
        );

        // Press right arrow key to move the selection to the right
        await tester.pressRightArrow();

        // Ensure caret is at the end of the text
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 2),
        );
      });

      testWidgetsOnAllPlatforms("expands selection downstream around the emoji", (tester) async {
        await _pumpSuperTextFieldEmojiTest(
          tester,
          text: '🐢',
        );

        // Place caret before the emoji
        await tester.placeCaretInSuperTextField(0);

        // Ensure we are at the beginning of the text
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 0),
        );

        // Press shift + right arrow key to expand the selection to the right
        await tester.pressShiftRightArrow();

        // Ensure that the emoji is selected
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection(
            baseOffset: 0,
            extentOffset: 2,
          ),
        );
      });

      testWidgetsOnAllPlatforms("selects the emoji on double tap", (tester) async {
        await _pumpSuperTextFieldEmojiTest(
          tester,
          text: '🐢',
        );

        await tester.doubleTapAtSuperTextField(0);

        // Ensure that the emoji is selected
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection(
            baseOffset: 0,
            extentOffset: 2,
          ),
        );
      });
    });

    group('containing only two consecutive emojis', () {
      testWidgetsOnAllPlatforms("moves caret upstream around the emoji", (tester) async {
        await _pumpSuperTextFieldEmojiTest(
          tester,
          text: '🐢🐢',
        );

        // TODO: placing caret on the right side of the emoji at the end of the text isn't working correctly
        // #549 - update to place caret at the end and remove the calls to pressRightArrow when that bug is fixed.
        // Place caret at the beginning of the text
        await tester.placeCaretInSuperTextField(0);
        // Move caret to the right
        await tester.pressRightArrow();
        // Move caret to the right
        await tester.pressRightArrow();

        // Ensure we are at the end of the text
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 4),
        );

        // Press left arrow key to move the selection to the left
        await tester.pressLeftArrow();

        // Ensure caret is between the two emojis
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 2),
        );

        // Press left arrow key to move the selection to the left
        await tester.pressLeftArrow();

        // Ensure caret is at the beginning of the text
        expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 0));
      });

      testWidgetsOnAllPlatforms("expands selection upstream around the emoji", (tester) async {
        await _pumpSuperTextFieldEmojiTest(
          tester,
          text: '🐢🐢',
        );

        // TODO: placing caret on the right side of the emoji at the end of the text isn't working correctly
        // #549 - update to place caret at the end and remove the calls to pressRightArrow when that bug is fixed.
        // Place caret at the beginning of the text
        await tester.placeCaretInSuperTextField(0);
        // Move caret to the right
        await tester.pressRightArrow();
        // Move caret to the right
        await tester.pressRightArrow();

        // Ensure we are at the end of the text
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 4),
        );

        // Press shift + left arrow key to expand the selection to the left
        await tester.pressShiftLeftArrow();

        // Ensure that the last emoji is selected
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection(
            baseOffset: 4,
            extentOffset: 2,
          ),
        );

        // Press shift + left arrow key to expand the selection to the left
        await tester.pressShiftLeftArrow();

        // Ensure the whole text is selected
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection(
            baseOffset: 4,
            extentOffset: 0,
          ),
        );
      });

      testWidgetsOnAllPlatforms("moves caret downstream around the emoji", (tester) async {
        await _pumpSuperTextFieldEmojiTest(
          tester,
          text: '🐢🐢',
        );

        // Place caret before the first emoji
        await tester.placeCaretInSuperTextField(0);

        // Ensure we are at the beginning of the text
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 0),
        );

        // Press right arrow key to move the selection to the right
        await tester.pressRightArrow();

        // Ensure caret is between the two emojis
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 2),
        );

        // Press right arrow key to move the selection to the right
        await tester.pressRightArrow();

        // Ensure caret is at the end of the text
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 4),
        );
      });

      testWidgetsOnAllPlatforms("expands selection downstream around the emoji", (tester) async {
        await _pumpSuperTextFieldEmojiTest(
          tester,
          text: '🐢🐢',
        );

        // Place caret before the first emoji
        await tester.placeCaretInSuperTextField(0);

        // Ensure we are at the beginning of the text
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 0),
        );

        // Press shift + right arrow key to expand the selection to the right
        await tester.pressShiftRightArrow();

        // Ensure the first emoji is selected
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection(
            baseOffset: 0,
            extentOffset: 2,
          ),
        );

        // Press shift + right arrow key to expand the selection to the right
        await tester.pressShiftRightArrow();

        // Ensure we selected the whole text
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection(
            baseOffset: 0,
            extentOffset: 4,
          ),
        );
      });
    });

    group('containing emojis and non-emojis', () {
      testWidgetsOnAllPlatforms("moves caret upstream around the text", (tester) async {
        await _pumpSuperTextFieldEmojiTest(
          tester,
          text: 'a🐢b',
        );

        // Place caret at |b
        await tester.placeCaretInSuperTextField(3);

        // Ensure we are after the emoji
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 3),
        );

        // Press left arrow key to move the selection to the left
        await tester.pressLeftArrow();

        // Ensure we are between the emoji and the 'a'
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 1),
        );

        // Press left arrow key to move the selection to the left
        await tester.pressLeftArrow();

        // Ensure caret is at the beginning of the text
        expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 0));
      });

      testWidgetsOnAllPlatforms("expands selection upstream around the text", (tester) async {
        await _pumpSuperTextFieldEmojiTest(
          tester,
          text: 'a🐢b',
        );

        // Place caret at |b
        await tester.placeCaretInSuperTextField(3);

        // Ensure we are after the emoji
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 3),
        );

        // Press shift + left arrow key to expand the selection to the left
        await tester.pressShiftLeftArrow();

        // Ensure we selected the emoji
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection(
            baseOffset: 3,
            extentOffset: 1,
          ),
        );

        // Press shift + left arrow key to expand the selection to the left
        await tester.pressShiftLeftArrow();

        // Ensure "a🐢" is selected
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection(
            baseOffset: 3,
            extentOffset: 0,
          ),
        );
      });

      testWidgetsOnAllPlatforms("moves caret downstream around the text", (tester) async {
        await _pumpSuperTextFieldEmojiTest(
          tester,
          text: 'a🐢b',
        );

        // Place caret at the beginning of the text
        await tester.placeCaretInSuperTextField(0);

        // Ensure we are at the beginning of the text
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 0),
        );

        // Press right arrow key to move the selection to the right
        await tester.pressRightArrow();

        // Ensure we are at a|
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 1),
        );

        // Press right arrow key to move the selection to the right
        await tester.pressRightArrow();

        // Ensure caret is after the emoji
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 3),
        );
      });

      testWidgetsOnAllPlatforms("expands selection downstream around the text", (tester) async {
        await _pumpSuperTextFieldEmojiTest(
          tester,
          text: 'a🐢b',
        );

        // Place caret at the beginning of the text
        await tester.placeCaretInSuperTextField(0);

        // Ensure we are at the beginning of the text
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 0),
        );

        // Press shift + right arrow key to expand the selection to the right
        await tester.pressShiftRightArrow();

        // Ensure 'a' is selected
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection(
            baseOffset: 0,
            extentOffset: 1,
          ),
        );

        // Press shift + right arrow key to expand the selection to the right
        await tester.pressShiftRightArrow();

        // Ensure "a🐢" is selected
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection(
            baseOffset: 0,
            extentOffset: 3,
          ),
        );
      });

      testWidgetsOnAndroid('deletes emojis with BACKSPACE', (tester) async {
        await _pumpSuperTextFieldEmojiTest(
          tester,
          configuration: SuperTextFieldPlatformConfiguration.android,
          text: 'This is a text with an emoji 🐢',
        );

        // Place the caret at the end of the text field.
        await tester.placeCaretInSuperTextField(SuperTextFieldInspector.findText().length);

        // Press backspace to delete the previous character.
        await tester.pressBackspace();

        // Ensure the emoji is deleted.
        expect(SuperTextFieldInspector.findText().toPlainText(), 'This is a text with an emoji ');
      });
    });
  });
}

Future<void> _pumpSuperTextFieldEmojiTest(
  WidgetTester tester, {
  required String text,
  SuperTextFieldPlatformConfiguration configuration = SuperTextFieldPlatformConfiguration.desktop,
}) async {
  final controller = AttributedTextEditingController(
    text: AttributedText(text),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SuperTextField(
          configuration: configuration,
          textController: controller,
          textStyleBuilder: (_) => const TextStyle(fontSize: 16),
        ),
      ),
    ),
  );
}
