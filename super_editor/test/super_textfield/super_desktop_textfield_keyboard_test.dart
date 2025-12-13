import 'package:flutter/material.dart' hide SelectableText;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_text_field_test.dart';

void main() {
  group('SuperDesktopTextField', () {
    group('on any desktop', () {
      group('inserts character', () {
        testWidgetsOnDesktop('in empty text', (tester) async {
          await _pumpEmptySuperTextField(tester);
          await tester.placeCaretInSuperTextField(0);

          await tester.typeKeyboardText("f");

          expect(SuperTextFieldInspector.findText().toPlainText(), "f");
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 1));
        });

        testWidgetsOnDesktop('in middle of text', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('--><--'),
            ),
          );
          await tester.placeCaretInSuperTextField(3);

          await tester.typeKeyboardText("f");

          expect(SuperTextFieldInspector.findText().toPlainText(), "-->f<--");
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 4));
        });

        testWidgetsOnDesktop('at end of text', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('-->'),
            ),
          );
          await tester.placeCaretInSuperTextField(3);

          await tester.typeKeyboardText("f");

          expect(SuperTextFieldInspector.findText().toPlainText(), "-->f");
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 4));
        });

        testWidgetsOnDesktop('and replaces selected text', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('-->REPLACE<--'),
            ),
          );
          await tester.selectSuperTextFieldText(2, 10);

          await tester.typeKeyboardText("f");

          expect(SuperTextFieldInspector.findText().toPlainText(), "-->f<--");
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 4));
        });
      });

      group('inserts line', () {
        testWidgetsOnDesktop('when ENTER is pressed in middle of text', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('this is some text'),
            ),
          );
          await tester.placeCaretInSuperTextField(8);

          await tester.pressEnter();

          expect(SuperTextFieldInspector.findText().toPlainText(), "this is \nsome text");
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 9));
        });

        testWidgetsOnDesktop('when ENTER is pressed at beginning of text', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('this is some text'),
            ),
          );
          await tester.placeCaretInSuperTextField(0);

          await tester.pressEnter();

          expect(SuperTextFieldInspector.findText().toPlainText(), "\nthis is some text");
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 1));
        });

        testWidgetsOnDesktop('when ENTER is pressed at end of text', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('this is some text'),
            ),
          );
          await tester.placeCaretInSuperTextField(17);

          await tester.pressEnter();

          expect(SuperTextFieldInspector.findText().toPlainText(), "this is some text\n");
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 18));
        });
      });

      group('move caret upstream', () {
        testWidgetsOnDesktop('LEFT ARROW does nothing at beginning of text blob', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('This is some text'),
            ),
          );
          await tester.placeCaretInSuperTextField(0);

          // Try moving left by character.
          await tester.pressLeftArrow();
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection.collapsed(offset: 0),
          );

          // Try moving left by word.
          await tester.pressAltLeftArrow();
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection.collapsed(offset: 0),
          );

          // Try moving left to beginning of line.
          await tester.pressCmdLeftArrow();
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection.collapsed(offset: 0),
          );
        });

        testWidgetsOnDesktop('LEFT ARROW moves left by character', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('This is some text'),
            ),
          );
          await tester.placeCaretInSuperTextField(2);

          await tester.pressLeftArrow();
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection.collapsed(offset: 1),
          );
        });

        // TODO: This test is skipped because I think #549 is making this use-case
        // impossible in the test. This test verifies that when a caret is at the
        // beginning of a line, pressing LEFT doesn't move upstream by a character,
        // it just moves the caret from DOWNSTREAM to UPSTREAM.
        testWidgetsOnDesktop('LEFT ARROW moves to previous line by character', (tester) async {
          await _pumpSuperTextField(
              tester,
              AttributedTextEditingController(
                text: AttributedText(_multilineLayoutText),
              ));
          await tester.placeCaretInSuperTextField(18);

          final textLayout = SuperTextFieldInspector.findProseTextLayout();
          // ignore: avoid_print
          print("Line count: ${textLayout.getLineCount()}");
          // ignore: avoid_print
          print("End of line 1: ${textLayout.getPositionAtEndOfLine(const TextPosition(offset: 0))}");
          // ignore: avoid_print
          print("End of line 2: ${textLayout.getPositionAtEndOfLine(const TextPosition(offset: 18))}");
          // ignore: avoid_print
          print("End of line 3: ${textLayout.getPositionAtEndOfLine(const TextPosition(offset: 31))}");
          // ignore: avoid_print
          print("Selection before left arrow: ${SuperTextFieldInspector.findSelection()}");
          // ignore: avoid_print
          print(
              "Caret offset for 18 upstream: ${textLayout.getOffsetForCaret(const TextPosition(offset: 18, affinity: TextAffinity.upstream))}");
          // ignore: avoid_print
          print("Caret offset for 18 downstream: ${textLayout.getOffsetForCaret(const TextPosition(offset: 18))}");

          await tester.pressLeftArrow();
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection.collapsed(offset: 18, affinity: TextAffinity.upstream),
          );

          // We should have gone from line 2 to line 1. Make double sure by
          // checking that the bounding box for the character that's now selected
          // sits at the top of the text box.
          //
          // The given offset is "16", which represents selection of the 17th
          // character.
          //
          // We give a tiny bit of wiggle room on the value because when this test
          // is run on Windows and Linux CI, there is some kind of precision error
          // that results in a tiny positive number instead of zero.
          expect(textLayout.getCharacterBox(const TextPosition(offset: 16))?.top, lessThan(0.1));

          // On Linux CI, the "top" is a very tiny negative number, so we check for that value
          // instead of the check that we actually want to do.
          //
          // From CI:
          // Expected: a value greater than or equal to <0>
          //   Actual: <-7.152557373046875e-7>
          //    Which: is not a value greater than or equal to <0>
          // expect(textLayout.getCharacterBox(const TextPosition(offset: 16)).top, greaterThanOrEqualTo(0));
          expect(textLayout.getCharacterBox(const TextPosition(offset: 16))?.top, greaterThanOrEqualTo(-0.000001));
        }, skip: true);

        testWidgetsOnDesktop('SHIFT + LEFT ARROW expands left by character', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('This is some text'),
            ),
          );
          await tester.placeCaretInSuperTextField(2);

          await tester.pressShiftLeftArrow();
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection(
              baseOffset: 2,
              extentOffset: 1,
            ),
          );
        });

        testWidgetsOnDesktop('LEFT ARROW collapses downstream selection on left side', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('super text field'),
            ),
          );
          // TODO: we begin 1 character ahead of where we should because
          // of #549 - update the start offset when that bug is fixed.
          await tester.selectSuperTextFieldText(5, 10);

          await tester.pressLeftArrow();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 6));
        });

        testWidgetsOnDesktop('LEFT ARROW collapses upstream selection on left side', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('super text field'),
            ),
          );
          // TODO: we begin 1 character behind where we should because
          // of #549 - update the start offset when that bug is fixed.
          await tester.selectSuperTextFieldText(11, 6);

          await tester.pressLeftArrow();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 6));
        });
      });

      group('move caret downstream', () {
        testWidgetsOnDesktop('RIGHT ARROW does nothing at end of text', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('super text field'),
            ),
          );
          await tester.placeCaretInSuperTextField(16);

          await tester.pressRightArrow();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 16));
        });

        testWidgetsOnDesktop('RIGHT ARROW moves right by character', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('super text field'),
            ),
          );
          await tester.placeCaretInSuperTextField(2);

          await tester.pressRightArrow();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 3));
        });

        // TODO: This test is skipped because I think #549 is making this use-case
        // impossible in the test. This test verifies that when a caret is at the
        // end of a line, pressing RIGHT doesn't move downstream by a character,
        // it just moves the caret from UPSTREAM to DOWNSTREAM.
        testWidgetsOnDesktop('RIGHT ARROW moves to next line by character', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText(_multilineLayoutText),
            ),
          );
          await tester.placeCaretInSuperTextField(18, null, TextAffinity.upstream);

          await tester.pressRightArrow();

          expect(SuperTextFieldInspector.findSelection(),
              const TextSelection.collapsed(offset: 18, affinity: TextAffinity.downstream));

          // We should have gone from line 1 to line 2. Make double sure by
          // checking that the bounding box for the character that's now selected
          // does not sit at the top of the text box.
          expect(SuperTextFieldInspector.findProseTextLayout().getCharacterBox(const TextPosition(offset: 18))?.top,
              isNonZero);
        });

        testWidgetsOnDesktop('SHIFT + RIGHT ARROW expands right by character', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('super text field'),
            ),
          );
          await tester.placeCaretInSuperTextField(2);

          await tester.pressShiftRightArrow();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection(baseOffset: 2, extentOffset: 3));
        });

        testWidgetsOnDesktop('RIGHT ARROW collapses downstream selection on right side', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('super text field'),
            ),
          );
          // TODO: we begin 1 character ahead of where we should because
          // of #549 - update the start offset when that bug is fixed.
          await tester.selectSuperTextFieldText(5, 10);

          await tester.pressRightArrow();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 10));
        });

        testWidgetsOnDesktop('RIGHT ARROW collapses upstream selection on right side', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('super text field'),
            ),
          );
          // TODO: we begin 1 character after of where we should because
          // of #549 - update the start offset when that bug is fixed.
          await tester.selectSuperTextFieldText(11, 6);

          await tester.pressRightArrow();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 10));
        });
      });

      group('move caret up', () {
        testWidgetsOnDesktop('UP ARROW moves to start of text when in first line', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText(_multilineLayoutText),
            ),
          );
          await tester.placeCaretInSuperTextField(5);

          await tester.pressUpArrow();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 0));
        });

        testWidgetsOnDesktop('UP ARROW moves to previous line', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText(_multilineLayoutText),
            ),
          );
          await tester.placeCaretInSuperTextField(18);

          await tester.pressUpArrow();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 0));
        });

        testWidgetsOnDesktop('SHIFT + UP ARROW expands to previous line', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText(_multilineLayoutText),
            ),
          );
          await tester.placeCaretInSuperTextField(18);

          await tester.pressShiftUpArrow();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection(baseOffset: 18, extentOffset: 0));
        });

        testWidgetsOnDesktop('UP ARROW preserves horizontal position in previous line', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText(_multilineLayoutText),
            ),
          );
          await tester.placeCaretInSuperTextField(23);

          await tester.pressUpArrow();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 5));
        });
      });

      group('move caret down', () {
        testWidgetsOnDesktop('DOWN ARROW moves to end of text when in last line', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText(_multilineLayoutText),
            ),
          );
          await tester.placeCaretInSuperTextField(50);

          await tester.pressDownArrow();

          expect(SuperTextFieldInspector.findSelection(),
              const TextSelection.collapsed(offset: _multilineLayoutText.length));
        });

        testWidgetsOnDesktop('DOWN ARROW moves to next line', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText(_multilineLayoutText),
            ),
          );
          await tester.placeCaretInSuperTextField(0);

          await tester.pressDownArrow();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 18));
        });

        testWidgetsOnDesktop('SHIFT + DOWN ARROW expands to next line', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText(_multilineLayoutText),
            ),
          );
          await tester.placeCaretInSuperTextField(0);

          await tester.pressShiftDownArrow();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection(baseOffset: 0, extentOffset: 18));
        });

        testWidgetsOnDesktop('DOWN ARROW preserves horizontal position in next line', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText(_multilineLayoutText),
            ),
          );
          await tester.placeCaretInSuperTextField(5);

          await tester.pressDownArrow();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 23));
        });
      });

      group('delete text', () {
        testWidgetsOnDesktop('BACKSPACE does nothing when text is empty', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText(),
            ),
          );
          await tester.placeCaretInSuperTextField(0);

          await tester.pressBackspace();

          expect(SuperTextFieldInspector.findText().toPlainText(), "");
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 0));
        });

        testWidgetsOnDesktop('BACKSPACE deletes the previous character', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText("this is some text"),
            ),
          );
          await tester.placeCaretInSuperTextField(2);

          await tester.pressBackspace();

          expect(SuperTextFieldInspector.findText().toPlainText(), "tis is some text");
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 1));
        });

        testWidgetsOnDesktop('BACKSPACE deletes selection when selection is expanded', (tester) async {
          // TODO: We create the controller outside the pump so that we can
          // explicitly set its selection because of bug #549.
          final controller = AttributedTextEditingController(
            text: AttributedText(_multilineLayoutText),
          );
          await _pumpSuperTextField(
            tester,
            controller,
          );
          // TODO: this select line should be all we need, but for #549
          await tester.selectSuperTextFieldText(0, 10);
          // TODO: get rid of this explicit selection when #549 is fixed
          controller.selection = const TextSelection(baseOffset: 0, extentOffset: 10);

          await tester.pressBackspace();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 0));
          expect(SuperTextFieldInspector.findText().toPlainText(),
              "is long enough to be multiline in the available space");
        });

        testWidgetsOnDesktop('DELETE does nothing when text is empty', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText(),
            ),
          );
          await tester.placeCaretInSuperTextField(0);

          await tester.pressDelete();

          expect(SuperTextFieldInspector.findText().toPlainText(), "");
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 0));
        });

        testWidgetsOnDesktop('DELETE does nothing at end of text', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText("this is some text"),
            ),
          );
          await tester.placeCaretInSuperTextField(17);

          await tester.pressDelete();

          expect(SuperTextFieldInspector.findText().toPlainText(), "this is some text");
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 17));
        });

        testWidgetsOnDesktop('DELETE deletes the next character', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText("this is some text"),
            ),
          );
          await tester.placeCaretInSuperTextField(2);

          await tester.pressDelete();

          expect(SuperTextFieldInspector.findText().toPlainText(), "ths is some text");
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 2));
        });

        testWidgetsOnDesktop('DELETE deletes selected text', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText("this is some text"),
            ),
          );
          // TODO: the starting offset is one index to the left because
          // of #549
          await tester.selectSuperTextFieldText(7, 13);

          await tester.pressDelete();

          expect(SuperTextFieldInspector.findText().toPlainText(), "this is text");
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 8));
        });
      });
    });

    group('on Mac', () {
      group('copy text', () {
        testWidgetsOnMac('CMD + C copies selected text', (tester) async {
          tester.simulateClipboard();
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('This is some text'),
            ),
          );

          // TODO: we begin 1 character ahead of where we should because
          // of #549 - update the start offset when that bug is fixed.
          await tester.selectSuperTextFieldText(4, 12);

          await tester.pressCmdC();

          // Ensure that the expected text was copied to the clipboard.
          expect(tester.getSimulatedClipboardContent(), 'is some');
        });

        testWidgetsOnMac('CTL + C does NOT copy selected text', (tester) async {
          tester.simulateClipboard();
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('This is some text'),
            ),
          );

          // TODO: we begin 1 character ahead of where we should because
          // of #549 - update the start offset when that bug is fixed.
          await tester.selectSuperTextFieldText(4, 12);

          await tester.pressCtlC();

          // Ensure that a copy didn't happen.
          expect(tester.getSimulatedClipboardContent(), null);
        });

        testWidgetsOnMac('C does NOT copy text without CMD', (tester) async {
          tester.simulateClipboard();
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('This is some text'),
            ),
          );

          // TODO: we begin 1 character ahead of where we should because
          // of #549 - update the start offset when that bug is fixed.
          await tester.selectSuperTextFieldText(4, 12);

          await tester.sendKeyEvent(LogicalKeyboardKey.keyC);

          // Ensure that a copy didn't happen.
          expect(tester.getSimulatedClipboardContent(), null);
        });

        testWidgetsOnMac('CMD does NOT copy text without C', (tester) async {
          tester.simulateClipboard();
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('This is some text'),
            ),
          );

          // TODO: we begin 1 character ahead of where we should because
          // of #549 - update the start offset when that bug is fixed.
          await tester.selectSuperTextFieldText(4, 12);

          await tester.sendKeyEvent(LogicalKeyboardKey.metaLeft);

          // Ensure that a copy didn't happen.
          expect(tester.getSimulatedClipboardContent(), null);
        });
      });

      group('paste text', () {
        testWidgetsOnMac('CMD + V pastes clipboard text', (tester) async {
          tester.setSimulatedClipboardContent("this is clipboard text");

          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(text: AttributedText("Pasted content: ")),
          );
          await tester.placeCaretInSuperTextField(16);

          await tester.pressCmdV();

          // Ensure that the clipboard text was pasted into the SuperTextField
          expect(SuperTextFieldInspector.findText().toPlainText(), 'Pasted content: this is clipboard text');
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 38));
        });

        testWidgetsOnMac('CTL + V does NOT paste clipboard text', (tester) async {
          tester.setSimulatedClipboardContent("this is clipboard text");

          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(text: AttributedText("Pasted content: ")),
          );
          await tester.placeCaretInSuperTextField(16);

          await tester.pressCtlV();

          // Ensure that the clipboard text was NOT pasted into the SuperTextField.
          expect(SuperTextFieldInspector.findText().toPlainText(), 'Pasted content: ');
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 16));
        });

        testWidgetsOnMac('V does NOT paste text without CMD', (tester) async {
          tester.setSimulatedClipboardContent("this is clipboard text");

          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(text: AttributedText("Pasted content: ")),
          );
          await tester.placeCaretInSuperTextField(16);

          await tester.sendKeyEvent(LogicalKeyboardKey.keyV);

          // Ensure that the clipboard text was NOT pasted into the SuperTextField.
          expect(SuperTextFieldInspector.findText().toPlainText(), 'Pasted content: v');
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 17));
        });

        testWidgetsOnMac('V does NOT paste text without CMD', (tester) async {
          tester.setSimulatedClipboardContent("this is clipboard text");

          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(text: AttributedText("Pasted content: ")),
          );
          await tester.placeCaretInSuperTextField(16);

          await tester.sendKeyEvent(LogicalKeyboardKey.metaLeft);

          // Ensure that the clipboard text was NOT pasted into the SuperTextField.
          expect(SuperTextFieldInspector.findText().toPlainText(), 'Pasted content: ');
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 16));
        });
      });

      group('select all', () {
        testWidgetsOnMac('CMD + A selects all text', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('This is some text'),
            ),
          );
          await tester.placeCaretInSuperTextField(0);

          await tester.pressCmdA();

          // Ensure that all text in the SuperTextField is selected.
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection(
              baseOffset: 0,
              extentOffset: 17,
            ),
          );
        });

        testWidgetsOnMac('CTL + A does NOT select all', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('This is some text'),
            ),
          );
          await tester.placeCaretInSuperTextField(0);

          await tester.pressCtlA();

          // Ensure that SuperTextField text wasn't selected.
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection.collapsed(offset: 0),
          );
        });

        testWidgetsOnMac('A does NOT select all without CMD', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('This is some text'),
            ),
          );
          await tester.placeCaretInSuperTextField(0);

          await tester.sendKeyEvent(LogicalKeyboardKey.keyA);

          // Ensure that SuperTextField text wasn't selected.
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection.collapsed(offset: 1),
          );
        });

        testWidgetsOnMac('CMD does NOT select all without A', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('This is some text'),
            ),
          );
          await tester.placeCaretInSuperTextField(0);

          await tester.pressCtlA();

          // Ensure that SuperTextField text wasn't selected.
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection.collapsed(offset: 0),
          );
        });
      });

      group('move caret upstream', () {
        testWidgetsOnMac('ALT + LEFT ARROW moves left by word', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('This is some text'),
            ),
          );
          await tester.placeCaretInSuperTextField(12);

          await tester.pressAltLeftArrow();
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection.collapsed(offset: 8),
          );
        });

        testWidgetsOnMac('SHIFT + ALT + LEFT ARROW expands left by word', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('This is some text'),
            ),
          );
          await tester.placeCaretInSuperTextField(12);

          await tester.pressShiftAltLeftArrow();
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection(baseOffset: 12, extentOffset: 8),
          );
        });

        testWidgetsOnMac('CMD + LEFT ARROW moves left to beginning of line', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('This is some text'),
            ),
          );
          await tester.placeCaretInSuperTextField(12);

          await tester.pressCmdLeftArrow();
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection.collapsed(offset: 0),
          );
        });

        testWidgetsOnMac('CMD + SHIFT + LEFT ARROW expands left to beginning of line', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('This is some text'),
            ),
          );
          await tester.placeCaretInSuperTextField(12);

          await tester.pressShiftCmdLeftArrow();
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection(
              baseOffset: 12,
              extentOffset: 0,
            ),
          );
        });

        testWidgetsOnMac('CTL + A moves caret to start of line', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('this is some text'),
            ),
          );
          await tester.placeCaretInSuperTextField(5);

          await tester.pressCtlA();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 0));
        });

        testWidgetsOnMac('CTL + A does nothing at start of line', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('this is some text'),
            ),
          );
          await tester.placeCaretInSuperTextField(0);

          await tester.pressCtlA();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 0));
        });
      });

      group('move caret downstream', () {
        testWidgetsOnMac('ALT + RIGHT ARROW moves right by word', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('super text field'),
            ),
          );
          await tester.placeCaretInSuperTextField(6);

          await tester.pressAltRightArrow();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 10));
        });

        testWidgetsOnMac('ALT/CMD + RIGHT ARROW does nothing at end of text', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('super text field'),
            ),
          );
          await tester.placeCaretInSuperTextField(16);

          await tester.pressAltRightArrow();
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 16));

          await tester.pressCmdRightArrow();
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 16));
        });

        testWidgetsOnMac('SHIFT + ALT + RIGHT ARROW expands right by word', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('super text field'),
            ),
          );
          await tester.placeCaretInSuperTextField(6);

          await tester.pressShiftAltRightArrow();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection(baseOffset: 6, extentOffset: 10));
        });

        testWidgetsOnMac('CMD + RIGHT ARROW moves right to end of line', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('super text field'),
            ),
          );
          await tester.placeCaretInSuperTextField(6);

          await tester.pressCmdRightArrow();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 16));
        });

        testWidgetsOnMac('SHIFT + CMD + RIGHT ARROW expands right to end of line', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('super text field'),
            ),
          );
          await tester.placeCaretInSuperTextField(6);

          await tester.pressShiftCmdRightArrow();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection(baseOffset: 6, extentOffset: 16));
        });

        testWidgetsOnMac('CTL + E moves caret to end of line', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('this is some text'),
            ),
          );
          await tester.placeCaretInSuperTextField(5);

          await tester.pressCtlE();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 17));
        });

        testWidgetsOnMac('CTL + E does nothing at end of line', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('this is some text'),
            ),
          );
          await tester.placeCaretInSuperTextField(17);

          await tester.pressCtlE();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 17));
        });
      });

      group('delete text', () {
        testWidgetsOnMac('ALT + BACKSPACE deletes the upstream word', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText("this is some text"),
            ),
          );
          await tester.placeCaretInSuperTextField(4);

          await tester.pressAltBackspace();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 0));
          expect(SuperTextFieldInspector.findText().toPlainText(), " is some text");
        });

        testWidgetsOnMac('ALT + BACKSPACE deletes until beginning of word', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText("this is some text"),
            ),
          );
          await tester.placeCaretInSuperTextField(2);

          await tester.pressAltBackspace();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 0));
          expect(SuperTextFieldInspector.findText().toPlainText(), "is is some text");
        });

        testWidgetsOnMac('ALT + BACKSPACE deletes previous word with caret after whitespace', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText("this is some text"),
            ),
          );
          await tester.placeCaretInSuperTextField(8);

          await tester.pressAltBackspace();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 5));
          expect(SuperTextFieldInspector.findText().toPlainText(), "this some text");
        });

        testWidgetsOnMac('ALT + BACKSPACE deletes expanded selection', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText(_multilineLayoutText),
            ),
          );
          await tester.selectSuperTextFieldText(0, 10);

          await tester.pressAltBackspace();

          // TODO: When #549 is fixed, I expect this offset to change to 0, and the first
          // character of the expected text to be deleted.
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 1));
          expect(SuperTextFieldInspector.findText().toPlainText(),
              "tis long enough to be multiline in the available space");
        });

        testWidgetsOnMac('CMD + BACKSPACE deletes partial line before caret (flowed multiline)', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText(_multilineLayoutText),
            ),
          );
          await tester.placeCaretInSuperTextField(28);

          await tester.pressCmdBackspace();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 18));
          expect(SuperTextFieldInspector.findText().toPlainText(),
              "this text is long be multiline in the available space");
        });

        // TODO: When #549 is fixed, un-skip this test. The problem is that we need
        // to place the caret at the end of a line, but TextAffinity doesn't seem to
        // be working correctly.
        testWidgetsOnMac('CMD + BACKSPACE deletes entire line (flowed multiline)', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText(_multilineLayoutText),
            ),
          );
          await tester.placeCaretInSuperTextField(31, null, TextAffinity.upstream);

          await tester.pressCmdBackspace();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 18));
          expect(
              SuperTextFieldInspector.findText().toPlainText(), "this text is long multiline in the available space");
        }, skip: true);

        testWidgetsOnMac('CMD + BACKSPACE deletes partial line before caret (explicit newlines)', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText("This is line 1\nThis is line 2\nThis is line 3"),
            ),
          );
          await tester.placeCaretInSuperTextField(23);

          await tester.pressCmdBackspace();

          expect(SuperTextFieldInspector.findText().toPlainText(), "This is line 1\nline 2\nThis is line 3");
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 15));
        });

        testWidgetsOnMac('CMD + BACKSPACE deletes entire line (explicit newlines)', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText("This is line 1\nThis is line 2\nThis is line 3"),
            ),
          );
          await tester.placeCaretInSuperTextField(29, null, TextAffinity.upstream);

          await tester.pressCmdBackspace();

          expect(SuperTextFieldInspector.findText().toPlainText(), "This is line 1\n\nThis is line 3");
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 15));
        });

        testWidgetsOnMac('CMD + BACKSPACE deletes selection when selection is expanded', (tester) async {
          // TODO: We create the controller outside the pump so that we can
          // explicitly set its selection because of bug #549.
          final controller = AttributedTextEditingController(
            text: AttributedText(_multilineLayoutText),
          );
          await _pumpSuperTextField(
            tester,
            controller,
          );
          // TODO: this select line should be all we need, but for #549
          await tester.selectSuperTextFieldText(0, 10);
          // TODO: get rid of this explicit selection when #549 is fixed
          controller.selection = const TextSelection(baseOffset: 0, extentOffset: 10);

          await tester.pressCmdBackspace();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 0));
          expect(SuperTextFieldInspector.findText().toPlainText(),
              "is long enough to be multiline in the available space");
        });

        testWidgetsOnMac('CMD + BACKSPACE does nothing when selection is at start of line', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText(_multilineLayoutText),
            ),
          );
          await tester.placeCaretInSuperTextField(18);

          await tester.pressCmdBackspace();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 18));
          expect(SuperTextFieldInspector.findText().toPlainText(), _multilineLayoutText);
        });
      });

      group('shortcuts for Windows and Linux do nothing', () {
        testWidgetsOnMac("HOME", (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText("this is some text"),
            ),
          );
          await tester.placeCaretInSuperTextField(5);

          await tester.pressHome();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 5));
        });

        testWidgetsOnMac("END", (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText("this is some text"),
            ),
          );
          await tester.placeCaretInSuperTextField(5);

          await tester.pressEnd();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 5));
        });

        testWidgetsOnMac("CTRL + LEFT ARROW", (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText("this is some text"),
            ),
          );
          await tester.placeCaretInSuperTextField(5);

          await tester.pressCtlLeftArrow();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 4));
        });

        testWidgetsOnMac("CTRL + RIGHT ARROW", (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText("this is some text"),
            ),
          );
          await tester.placeCaretInSuperTextField(5);

          await tester.pressCtlRightArrow();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 6));
        });
      });
    });

    group('on Windows', () {
      group('move caret upstream', () {
        testWidgetsOnWindows('LEFT ARROW does nothing when ALT is pressed', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText("super text field"),
            ),
          );
          await tester.placeCaretInSuperTextField(10);

          await tester.pressAltLeftArrow();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 10));
        });
      });

      group('move caret downstream', () {
        testWidgetsOnWindows('RIGHT ARROW does nothing when ALT is pressed', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText("super text field"),
            ),
          );
          await tester.placeCaretInSuperTextField(10);

          await tester.pressAltRightArrow();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 10));
        });
      });
    });

    group('on Linux', () {
      group('move caret upstream', () {
        testWidgetsOnLinux('ALT + LEFT ARROW moves left by character', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('This is some text'),
            ),
          );
          await tester.placeCaretInSuperTextField(12);

          await tester.pressAltLeftArrow();
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection.collapsed(offset: 11),
          );
        });
      });

      group('move caret downstream', () {
        testWidgetsOnLinux('ALT + RIGHT ARROW moves right by character', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('This is some text'),
            ),
          );
          await tester.placeCaretInSuperTextField(12);

          await tester.pressAltRightArrow();
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection.collapsed(offset: 13),
          );
        });
      });
    });

    group('on Windows + Linux', () {
      group('copy text', () {
        testWidgetsOnWindowsAndLinux('control+c copies selected text', (tester) async {
          tester.simulateClipboard();
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('This is some text'),
            ),
          );

          // TODO: we begin 1 character ahead of where we should because
          // of #549 - update the start offset when that bug is fixed.
          await tester.selectSuperTextFieldText(4, 12);

          await tester.pressCtlC();

          // Ensure that the expected text was copied to the clipboard.
          expect(tester.getSimulatedClipboardContent(), 'is some');
        });

        testWidgetsOnWindowsAndLinux('CMD + C does NOT copy selected text', (tester) async {
          tester.simulateClipboard();
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('This is some text'),
            ),
          );

          // TODO: we begin 1 character ahead of where we should because
          // of #549 - update the start offset when that bug is fixed.
          await tester.selectSuperTextFieldText(4, 12);

          await tester.pressCmdC();

          // Ensure that a copy didn't happen.
          expect(tester.getSimulatedClipboardContent(), null);
        });

        testWidgetsOnWindowsAndLinux('it ignores C without CTL', (tester) async {
          tester.simulateClipboard();
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('This is some text'),
            ),
          );

          // TODO: we begin 1 character ahead of where we should because
          // of #549 - update the start offset when that bug is fixed.
          await tester.selectSuperTextFieldText(4, 12);

          await tester.sendKeyEvent(LogicalKeyboardKey.keyC);

          // Ensure that a copy didn't happen.
          expect(tester.getSimulatedClipboardContent(), null);
        });

        testWidgetsOnWindowsAndLinux('it ignores control without C', (tester) async {
          tester.simulateClipboard();
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('This is some text'),
            ),
          );

          // TODO: we begin 1 character ahead of where we should because
          // of #549 - update the start offset when that bug is fixed.
          await tester.selectSuperTextFieldText(4, 12);

          await tester.sendKeyEvent(LogicalKeyboardKey.controlLeft);

          // Ensure that a copy didn't happen.
          expect(tester.getSimulatedClipboardContent(), null);
        });
      });

      group('paste text', () {
        testWidgetsOnWindowsAndLinux('control+v pastes clipboard text', (tester) async {
          tester.setSimulatedClipboardContent("this is clipboard text");

          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(text: AttributedText("Pasted content: ")),
          );
          await tester.placeCaretInSuperTextField(16);

          await tester.pressCtlV();

          // Ensure that the clipboard text was pasted into the SuperTextField
          expect(SuperTextFieldInspector.findText().toPlainText(), 'Pasted content: this is clipboard text');
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 38));
        });

        testWidgetsOnWindowsAndLinux('cmd+v does NOT paste clipboard text', (tester) async {
          tester.setSimulatedClipboardContent("this is clipboard text");

          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(text: AttributedText("Pasted content: ")),
          );
          await tester.placeCaretInSuperTextField(16);

          await tester.pressCmdV();

          // Ensure that the clipboard text was NOT pasted into the SuperTextField.
          expect(SuperTextFieldInspector.findText().toPlainText(), 'Pasted content: ');
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 16));
        });

        testWidgetsOnWindowsAndLinux('it ignores v-key without control', (tester) async {
          tester.setSimulatedClipboardContent("this is clipboard text");

          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(text: AttributedText("Pasted content: ")),
          );
          await tester.placeCaretInSuperTextField(16);

          await tester.sendKeyEvent(LogicalKeyboardKey.keyV);

          // Ensure that the clipboard text was NOT pasted into the SuperTextField.
          expect(SuperTextFieldInspector.findText().toPlainText(), 'Pasted content: v');
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 17));
        });

        testWidgetsOnWindowsAndLinux('it ignores control without v-key', (tester) async {
          tester.setSimulatedClipboardContent("this is clipboard text");

          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(text: AttributedText("Pasted content: ")),
          );
          await tester.placeCaretInSuperTextField(16);

          await tester.sendKeyEvent(LogicalKeyboardKey.controlLeft);

          // Ensure that the clipboard text was NOT pasted into the SuperTextField.
          expect(SuperTextFieldInspector.findText().toPlainText(), 'Pasted content: ');
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 16));
        });
      });

      group('select all', () {
        testWidgetsOnWindowsAndLinux('control+a selects all text', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('This is some text'),
            ),
          );
          await tester.placeCaretInSuperTextField(0);

          await tester.pressCtlA();

          // Ensure that all text in the SuperTextField is selected.
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection(
              baseOffset: 0,
              extentOffset: 17,
            ),
          );
        });

        testWidgetsOnWindowsAndLinux('cmd+a does NOT select all', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('This is some text'),
            ),
          );
          await tester.placeCaretInSuperTextField(0);

          await tester.pressCmdA();

          // Ensure that SuperTextField text wasn't selected.
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection.collapsed(offset: 0),
          );
        });

        testWidgetsOnWindowsAndLinux('it ignores a-key without control', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('This is some text'),
            ),
          );
          await tester.placeCaretInSuperTextField(0);

          await tester.sendKeyEvent(LogicalKeyboardKey.keyA);

          // Ensure that SuperTextField text wasn't selected.
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection.collapsed(offset: 1),
          );
        });

        testWidgetsOnWindowsAndLinux('it ignores control without a-key', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('This is some text'),
            ),
          );
          await tester.placeCaretInSuperTextField(0);

          await tester.sendKeyEvent(LogicalKeyboardKey.controlLeft);

          // Ensure that SuperTextField text wasn't selected.
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection.collapsed(offset: 0),
          );
        });
      });

      group('move caret upstream', () {
        testWidgetsOnWindowsAndLinux('CTL + LEFT ARROW moves left by word', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText("super text field"),
            ),
          );
          await tester.placeCaretInSuperTextField(10);

          await tester.pressCtlLeftArrow();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 6));
        });

        testWidgetsOnWindowsAndLinux('SHIFT + CTL + LEFT ARROW expands left by word', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText("super text field"),
            ),
          );
          await tester.placeCaretInSuperTextField(10);

          await tester.pressShiftCtlLeftArrow();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection(baseOffset: 10, extentOffset: 6));
        });

        testWidgetsOnWindowsAndLinux('HOME moves left to beginning of line with auto-wrapping lines', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText("this is a text big enough that will cause auto line wrapping"),
            ),
          );

          // Place caret at the second line at "wrapping|"
          // We avoid placing the caret in the first line to make sure HOME doesn't move caret
          // all the way to the beginning of the text
          await tester.placeCaretInSuperTextField(60);

          await tester.pressHome();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 47));
        });

        testWidgetsOnWindowsAndLinux('HOME moves left to beginning of line with explicit new lines', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText("super text field\nthis is second line"),
            ),
          );

          // Place caret at the second line at "|second"
          // We avoid placing the caret in the first line to make sure HOME doesn't move caret
          // all the way to the beginning of the text
          await tester.placeCaretInSuperTextField(26);

          await tester.pressHome();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 17));
        });
      });

      group('move caret downstream', () {
        testWidgetsOnWindowsAndLinux('CTL + RIGHT ARROW moves right by word', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText("super text field"),
            ),
          );
          await tester.placeCaretInSuperTextField(6);

          await tester.pressCtlRightArrow();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 10));
        });

        testWidgetsOnWindowsAndLinux('SHIFT + CTL + RIGHT ARROW expands by word', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText("super text field"),
            ),
          );
          await tester.placeCaretInSuperTextField(6);

          await tester.pressShiftCtlRightArrow();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection(baseOffset: 6, extentOffset: 10));
        });

        testWidgetsOnWindowsAndLinux('END moves right to end of line with auto-wrapping lines', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText("this is a text big enough that will cause auto line wrapping"),
            ),
          );

          // Place caret at the first line at "|this"
          // We avoid placing the caret in the second line to make sure END doesn't move caret
          // all the way to the end of the text
          await tester.placeCaretInSuperTextField(0);

          await tester.pressEnd();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 14));
        });

        testWidgetsOnWindowsAndLinux('END moves right to end of line with explicit new lines', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText("super text field\nthis is second line"),
            ),
          );

          // Place caret at the first line at "|super"
          // We avoid placing the caret in the second line to make sure END doesn't move caret
          // all the way to the end of the text
          await tester.placeCaretInSuperTextField(0);

          await tester.pressEnd();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 16));
        });
      });

      group('delete text', () {
        testWidgetsOnWindowsAndLinux('CTL + BACKSPACE deletes the upstream word', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText("this is some text"),
            ),
          );
          await tester.placeCaretInSuperTextField(4);

          await tester.pressCtlBackspace();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 0));
          expect(SuperTextFieldInspector.findText().toPlainText(), " is some text");
        });

        testWidgetsOnWindowsAndLinux('CTL + BACKSPACE deletes until beginning of word', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText("this is some text"),
            ),
          );
          await tester.placeCaretInSuperTextField(2);

          await tester.pressCtlBackspace();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 0));
          expect(SuperTextFieldInspector.findText().toPlainText(), "is is some text");
        });

        testWidgetsOnWindowsAndLinux('CTL + BACKSPACE deletes previous word with caret after whitespace',
            (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText("this is some text"),
            ),
          );
          await tester.placeCaretInSuperTextField(8);

          await tester.pressCtlBackspace();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 5));
          expect(SuperTextFieldInspector.findText().toPlainText(), "this some text");
        });

        testWidgetsOnWindowsAndLinux('CTL + BACKSPACE deletes expanded selection', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText(_multilineLayoutText),
            ),
          );
          await tester.selectSuperTextFieldText(0, 10);

          await tester.pressCtlBackspace();

          // TODO: When #549 is fixed, I expect the selection offset to change to 0, and the
          // first letter of the final text to be deleted.
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 1));
          expect(SuperTextFieldInspector.findText().toPlainText(),
              "tis long enough to be multiline in the available space");
        });
      });

      group('shortcuts for Mac do nothing', () {
        testWidgetsOnWindowsAndLinux('CTL + E', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText("this is some text"),
            ),
          );
          await tester.placeCaretInSuperTextField(5);

          await tester.pressCtlE();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 5));
        });

        testWidgetsOnWindowsAndLinux('CMD + LEFT ARROW', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText("this is some text"),
            ),
          );
          await tester.placeCaretInSuperTextField(5);

          await tester.pressCmdLeftArrow();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 4));
        });

        testWidgetsOnWindowsAndLinux('CMD + RIGHT ARROW', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText("this is some text"),
            ),
          );
          await tester.placeCaretInSuperTextField(5);

          await tester.pressCmdRightArrow();

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 6));
        });
      });
    });
  });
}

// Based on experiments, the text is laid out as follows (at 320px wide):
//
//  (0)this text is long (18 - upstream)
// (18)enough to be (31 - upstream)
// (31)multiline in the (48 - upstream)
// (48)available space(63)
const _multilineLayoutText = 'this text is long enough to be multiline in the available space';

Future<void> _pumpEmptySuperTextField(WidgetTester tester) async {
  await _pumpSuperTextField(
    tester,
    AttributedTextEditingController(text: AttributedText('')),
  );
}

Future<void> _pumpSuperTextField(
  WidgetTester tester,
  AttributedTextEditingController controller, {
  int? minLines,
  int? maxLines,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      // The Center allows the content to be smaller than the display
      home: Center(
        // This SizedBox, combined with the font size in the TextStyle,
        // determines the text line wrapping, which is critical for the
        // tests in this suite.
        child: SizedBox(
          width: 320,
          child: SuperTextField(
            textController: controller,
            minLines: minLines,
            maxLines: maxLines,
            lineHeight: 18,
            textStyleBuilder: (_) {
              return const TextStyle(
                // This font size, combined with the layout width below, are
                // critical to determining the text line wrapping.
                fontSize: 18,
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // The following code prints the bounding box for every
  // character of text in the layout. You can use that info
  // to figure out where line breaks occur.
  // final textLayout = SuperTextFieldInspector.findProseTextLayout();
  // for (int i = 0; i < _multilineLayoutText.length; ++i) {
  //   print('$i: ${textLayout.getCharacterBox(TextPosition(offset: i))}');
  // }
}
