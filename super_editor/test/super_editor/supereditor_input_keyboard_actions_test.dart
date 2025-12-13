import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:super_editor/super_test.dart';

import '../test_runners.dart';
import '../test_tools.dart';

void main() {
  group('Super Editor keyboard actions', () {
    group("movement >", () {
      group("Mac and iOS >", () {
        group("jumps to", () {
          testWidgetsOnApple('beginning of line with CMD + LEFT ARROW', (tester) async {
            // Start the user's selection somewhere after the beginning of the first
            // line in the first node.
            await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

            await tester.pressCmdLeftArrow();

            // Ensure that the caret moved to the beginning of the line.
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 0),
                ),
              ),
            );
          });

          testWidgetsOnApple('end of line with CMD + RIGHT ARROW', (tester) async {
            // Start the user's selection somewhere before the end of the first line
            // in the first node.
            await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

            await tester.pressCmdRightArrow();

            // Ensure that the caret moved to the end of the line. This value
            // is very fragile. If the text size or layout width changes, this value
            // will also need to change.
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 27),
                ),
              ),
            );
          });

          testWidgetsOnApple('beginning of word with ALT + LEFT ARROW', (tester) async {
            // Start the user's selection somewhere in the middle of a word.
            await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

            await tester.pressAltLeftArrow();

            // Ensure that the caret moved to the beginning of the word.
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 6),
                ),
              ),
            );
          });

          testWidgetsOnApple('end of word with ALT + RIGHT ARROW', (tester) async {
            // Start the user's selection somewhere in the middle of a word.
            await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

            await tester.pressAltRightArrow();

            // Ensure that the caret moved to the beginning of the word.
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 11),
                ),
              ),
            );
          });

          testWidgetsOnApple('beginning of paragraph with OPTION + UP ARROW', (tester) async {
            await _pumpTwoParagraphsTestApp(
              tester,
              inputSource: inputSourceVariant.currentValue!,
            );

            // Place caret at the end of the second paragraph.
            await tester.placeCaretInParagraph('2', 36);

            // Press option + up arrow.
            await tester.pressAltUpArrow();

            // Ensure that the caret moved to the beginning of the paragraph.
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: "2",
                  nodePosition: TextNodePosition(offset: 0),
                ),
              ),
            );
          }, variant: inputSourceVariant);

          testWidgetsOnApple('end of paragraph with OPTION + DOWN ARROW', (tester) async {
            await _pumpTwoParagraphsTestApp(
              tester,
              inputSource: inputSourceVariant.currentValue!,
            );

            // Place caret at the beginning of the first paragraph.
            await tester.placeCaretInParagraph('1', 0);

            // Press option + down arrow.
            await tester.pressAltDownArrow();

            // Ensure that the caret moved to the beginning of the paragraph.
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 35),
                ),
              ),
            );
          }, variant: inputSourceVariant);

          testWidgetsOnApple('beginning of document with CMD + UP ARROW', (tester) async {
            await _pumpTwoParagraphsTestApp(
              tester,
              inputSource: inputSourceVariant.currentValue!,
            );

            // Place caret at the end of the second paragraph.
            await tester.placeCaretInParagraph('2', 36);

            await tester.pressCmdUpArrow();

            // Ensure that the caret moved to the beginning of the document.
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 0),
                ),
              ),
            );
          }, variant: inputSourceVariant);

          testWidgetsOnApple('end of document with CMD + DOWN ARROW', (tester) async {
            await _pumpTwoParagraphsTestApp(
              tester,
              inputSource: inputSourceVariant.currentValue!,
            );

            // Place caret at the beginning of the first paragraph.
            await tester.placeCaretInParagraph('1', 0);

            await tester.pressCmdDownArrow();

            // Ensure that the caret moved to the end of the document.
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: "2",
                  nodePosition: TextNodePosition(offset: 36),
                ),
              ),
            );
          }, variant: inputSourceVariant);
        });

        group("expands to", () {
          testWidgetsOnApple('beginning of paragraph with SHIFT + OPTION + UP ARROW', (tester) async {
            await _pumpTwoParagraphsTestApp(
              tester,
              inputSource: inputSourceVariant.currentValue!,
            );

            // Place caret at the end of the second paragraph.
            await tester.placeCaretInParagraph('2', 36);

            // Press shift option + up arrow.
            await _pressShiftAltUpArrow(tester);

            // Ensure that the selection expanded to the beginning of the paragraph.
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection(
                base: DocumentPosition(
                  nodeId: "2",
                  nodePosition: TextNodePosition(offset: 36, affinity: TextAffinity.upstream),
                ),
                extent: DocumentPosition(
                  nodeId: "2",
                  nodePosition: TextNodePosition(offset: 0),
                ),
              ),
            );
          }, variant: inputSourceVariant);

          testWidgetsOnApple('end of paragraph with SHIFT + OPTION + DOWN ARROW', (tester) async {
            await _pumpTwoParagraphsTestApp(
              tester,
              inputSource: inputSourceVariant.currentValue!,
            );

            // Place caret at the beginning of the first paragraph.
            await tester.placeCaretInParagraph('1', 0);

            // Press shift + option + down arrow.
            await _pressShiftAltDownArrow(tester);

            // Ensure that the selection expanded to the end of the paragraph.
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection(
                base: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 0),
                ),
                extent: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 35),
                ),
              ),
            );
          }, variant: inputSourceVariant);

          testWidgetsOnApple('beginning of document with SHIFT + CMD + UP ARROW', (tester) async {
            await _pumpTwoParagraphsTestApp(
              tester,
              inputSource: inputSourceVariant.currentValue!,
            );

            // Place caret at the end of the second paragraph.
            await tester.placeCaretInParagraph('2', 36);

            await tester.pressShiftCmdUpArrow();

            // Ensure that the selection expanded to the beginning of the document.
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection(
                base: DocumentPosition(
                  nodeId: "2",
                  nodePosition: TextNodePosition(offset: 36, affinity: TextAffinity.upstream),
                ),
                extent: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 0),
                ),
              ),
            );
          }, variant: inputSourceVariant);

          testWidgetsOnApple('end of document with SHIFT + CMD + DOWN ARROW', (tester) async {
            await _pumpTwoParagraphsTestApp(
              tester,
              inputSource: inputSourceVariant.currentValue!,
            );

            // Place caret at the beginning of the first paragraph.
            await tester.placeCaretInParagraph('1', 0);

            await tester.pressShiftCmdDownArrow();

            // Ensure that the selection expanded to the end of the document.
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection(
                base: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 0),
                ),
                extent: DocumentPosition(
                  nodeId: "2",
                  nodePosition: TextNodePosition(offset: 36),
                ),
              ),
            );
          }, variant: inputSourceVariant);
        });

        testWidgetsOnApple("option + backspace: deletes a word upstream", (tester) async {
          final testContext = await tester
              .createDocument() //
              .withSingleParagraph()
              .withInputSource(inputSourceVariant.currentValue!)
              .pump();

          // Lorem ipsum| dolor sit amet...
          await tester.placeCaretInParagraph("1", 11);

          // Press option + backspace
          await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

          // Ensure that the whole word was deleted.
          final paragraphNode = testContext.findEditContext().document.first as ParagraphNode;
          expect(paragraphNode.text.toPlainText().startsWith("Lorem  dolor sit amet"), isTrue);
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 6),
              ),
            ),
          );
        }, variant: inputSourceVariant);

        testWidgetsOnApple("option + backspace: deletes a word upstream (after a space)", (tester) async {
          final testContext = await tester
              .createDocument() //
              .withSingleParagraph()
              .withInputSource(inputSourceVariant.currentValue!)
              .pump();

          // Lorem ipsum |dolor sit amet...
          await tester.placeCaretInParagraph("1", 12);

          // Press option + backspace
          await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

          // Ensure that the whole word was deleted.
          final paragraphNode = testContext.findEditContext().document.first as ParagraphNode;
          expect(paragraphNode.text.toPlainText().startsWith("Lorem dolor sit amet"), isTrue);
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 6),
              ),
            ),
          );
        }, variant: inputSourceVariant);

        testWidgetsOnApple("option + delete: deletes a word downstream", (tester) async {
          final testContext = await tester
              .createDocument() //
              .withSingleParagraph()
              .withInputSource(inputSourceVariant.currentValue!)
              .pump();

          // Lorem ipsum |dolor sit amet...
          await tester.placeCaretInParagraph("1", 12);

          // Press option + delete
          await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.delete);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

          // Ensure that the whole word was deleted.
          final paragraphNode = testContext.findEditContext().document.first as ParagraphNode;
          expect(paragraphNode.text.toPlainText(), startsWith("Lorem ipsum  sit amet"));
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 12),
              ),
            ),
          );
        }, variant: inputSourceVariant);

        testWidgetsOnApple("option + delete: deletes a word downstream (before a space)", (tester) async {
          final testContext = await tester
              .createDocument() //
              .withSingleParagraph()
              .withInputSource(inputSourceVariant.currentValue!)
              .pump();

          // Lorem ipsum| dolor sit amet...
          await tester.placeCaretInParagraph("1", 11);

          // Press option + delete
          await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.delete);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

          // Ensure that the whole word was deleted.
          final paragraphNode = testContext.findEditContext().document.first as ParagraphNode;
          expect(paragraphNode.text.toPlainText().startsWith("Lorem ipsum sit amet"), isTrue);
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 11),
              ),
            ),
          );
        }, variant: inputSourceVariant);

        testWidgetsOnApple("control + backspace: deletes a single upstream character", (tester) async {
          final testContext = await tester
              .createDocument() //
              .withSingleParagraph()
              .withInputSource(inputSourceVariant.currentValue!)
              .pump();

          // Lorem ipsum| dolor sit amet...
          await tester.placeCaretInParagraph("1", 11);

          // Press control + backspace
          await tester.pressCtlBackspace();

          // Ensure that a character was deleted.
          final paragraphNode = testContext.findEditContext().document.first as ParagraphNode;
          expect(paragraphNode.text.toPlainText(), startsWith("Lorem ipsu dolor sit amet"));
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 10),
              ),
            ),
          );
        }, variant: inputSourceVariant);

        testWidgetsOnApple("control + delete: deletes a single downstream character", (tester) async {
          final testContext = await tester
              .createDocument() //
              .withSingleParagraph()
              .withInputSource(inputSourceVariant.currentValue!)
              .pump();

          // Lorem ipsum| dolor sit amet...
          await tester.placeCaretInParagraph("1", 11);

          // Press control + delete
          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.delete);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

          // Ensure that a character was deleted.
          final paragraphNode = testContext.findEditContext().document.first as ParagraphNode;
          expect(paragraphNode.text.toPlainText().startsWith("Lorem ipsumdolor sit amet"), isTrue);
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 11),
              ),
            ),
          );
        }, variant: inputSourceVariant);

        testWidgetsOnMacDesktopAndWeb('with CMD + LEFT ARROW at the beginning of a paragraph', (tester) async {
          await tester //
              .createDocument()
              .withLongTextContent()
              .pump();

          // Place caret at the beginning of the second paragraph.
          await tester.placeCaretInParagraph('2', 0);

          // Press the key combo to move to the beginning of the line.
          await tester.pressCmdLeftArrow();

          // Ensure that the caret didn't move, since we are already at the beginning.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            selectionEquivalentTo(
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: "2",
                  nodePosition: TextNodePosition(offset: 0),
                ),
              ),
            ),
          );
        });

        testWidgetsOnMacDesktopAndWeb('with CMD + RIGHT ARROW at the end of a paragraph', (tester) async {
          await tester //
              .createDocument()
              .withLongTextContent()
              .pump();

          // Place caret at the end of the first paragraph.
          await tester.placeCaretInParagraph('1', 439);

          // Press the key combo to move to the end of the line.
          await tester.pressCmdRightArrow();

          // Ensure that the caret didn't move, since we are already at the end.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            selectionEquivalentTo(
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 439),
                ),
              ),
            ),
          );
        });

        testWidgetsOnMacDesktopAndWeb(
            'SHIFT + OPTION + LEFT ARROW: deselects word at end of line after selecting the whole line from start to end',
            (tester) async {
          await tester //
              .createDocument()
              .withCustomContent(
                MutableDocument(
                  nodes: [
                    ParagraphNode(
                      id: '1',
                      text: AttributedText('This is a paragraph'),
                    ),
                  ],
                ),
              )
              .pump();

          // Place caret at the beginning of the paragraph.
          await tester.placeCaretInParagraph('1', 0);

          // Press CMD + SHIFT + RIGHT ARROW to expand the selection to the end of the line.
          await tester.pressShiftCmdRightArrow();

          // Ensure that the whole line is selected.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            selectionEquivalentTo(
              const DocumentSelection(
                base: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 0),
                ),
                extent: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 19),
                ),
              ),
            ),
          );

          // Press SHIFT + OPTION + LEFT ARROW to remove the last word from the selection.
          await tester.pressShiftAltLeftArrow();

          // Ensure that the last word was removed from the selection.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            selectionEquivalentTo(
              const DocumentSelection(
                base: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 0),
                ),
                extent: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 10),
                ),
              ),
            ),
          );
        });

        testWidgetsOnMacDesktopAndWeb(
            'SHIFT + OPTION + RIGHT ARROW: deselects word at start of line after selecting the whole line from end to start',
            (tester) async {
          await tester //
              .createDocument()
              .withCustomContent(
                MutableDocument(
                  nodes: [
                    ParagraphNode(
                      id: '1',
                      text: AttributedText('This is a paragraph'),
                    ),
                  ],
                ),
              )
              .pump();

          // Place caret at the end of the paragraph.
          await tester.placeCaretInParagraph('1', 19);

          // Press CMD + SHIFT + LEFT ARROW to expand the selection to the beginning of the line.
          await tester.pressShiftCmdLeftArrow();

          // Ensure that the whole line is selected.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            selectionEquivalentTo(
              const DocumentSelection(
                base: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 19),
                ),
                extent: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 0),
                ),
              ),
            ),
          );

          // Press SHIFT + OPTION + RIGHT ARROW to remove the first word from the selection.
          await tester.pressShiftAltRightArrow();

          // Ensure that the first word was removed from the selection.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            selectionEquivalentTo(
              const DocumentSelection(
                base: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 19),
                ),
                extent: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 4),
                ),
              ),
            ),
          );
        });
      });

      group("Windows and Linux >", () {
        group("jumps to", () {
          testWidgetsOnWindowsAndLinux('beginning of line with HOME in an auto-wrapping paragraph', (tester) async {
            await _pumpAutoWrappingTestSetup(tester);

            // Place caret at the second line at "adipiscing |elit"
            // We avoid placing the caret in the first line to make sure HOME doesn't move caret
            // all the way to the beginning of the text
            await tester.placeCaretInParagraph('1', 51);

            await tester.pressHome();

            // Ensure that the caret moved to the beginning of the wrapped line at "|adipiscing elit"
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 40),
                ),
              ),
            );
          });

          testWidgetsOnWindowsAndLinux('beginning of line with HOME in a paragraph with explicit new lines',
              (tester) async {
            await _pumpExplicitLineBreakTestSetup(tester);

            // Place caret at the second line at "consectetur adipiscing |elit"
            // We avoid placing the caret in the first line to make sure HOME doesn't move caret
            // all the way to the beginning of the text
            await tester.placeCaretInParagraph('1', 51);

            await tester.pressHome();

            // Ensure that the caret moved to the beginning of the second line at "|consectetur adipiscing elit"
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 27),
                ),
              ),
            );
          });

          testWidgetsOnWindowsAndLinux('end of line with END in an auto-wrapping paragraph', (tester) async {
            await _pumpAutoWrappingTestSetup(tester);

            // Place caret at the start of the first line
            // We avoid placing the caret in the last line to make sure END doesn't move caret
            // all the way to the end of the text
            await tester.placeCaretInParagraph('1', 0);

            await tester.pressEnd();

            // Ensure that the caret moved to the end of the line. This value
            // is very fragile. If the text size or layout width changes, this value
            // will also need to change.
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 17),
                ),
              ),
            );
          });

          testWidgetsOnWindowsAndLinux('end of line with END in a paragraph with explicit new lines', (tester) async {
            // Configure the screen to a size big enough so there's no auto line-wrapping
            await _pumpExplicitLineBreakTestSetup(tester, size: const Size(1024, 400));

            // Place caret at the first line at "Lorem |ipsum"
            // Avoid placing caret in the last line to make sure END doesn't move caret
            // all the way to the end of the text
            await tester.placeCaretInParagraph('1', 6);

            await tester.pressEnd();

            // Ensure that the caret moved the end of the first line
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 26, affinity: TextAffinity.upstream),
                ),
              ),
            );
          });

          testWidgetsOnWindowsAndLinux('beginning of word with CTRL + LEFT ARROW', (tester) async {
            // Start the user's selection somewhere in the middle of a word.
            await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

            await tester.pressCtlLeftArrow();

            // Ensure that the caret moved to the beginning of the word.
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 6),
                ),
              ),
            );
          });

          testWidgetsOnWindowsAndLinux('end of word with CTRL + RIGHT ARROW', (tester) async {
            // Start the user's selection somewhere in the middle of a word.
            await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

            await tester.pressCtlRightArrow();

            // Ensure that the caret moved to the beginning of the word.
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 11),
                ),
              ),
            );
          });
        });

        testWidgetsOnWindowsAndLinux("control + backspace: deletes a word upstream", (tester) async {
          final testContext = await tester
              .createDocument() //
              .withSingleParagraph()
              .withInputSource(inputSourceVariant.currentValue!)
              .pump();

          // Lorem ipsum| dolor sit amet...
          await tester.placeCaretInParagraph("1", 11);

          // Press control + backspace
          await tester.pressCtlBackspace();

          // Ensure that the whole word was deleted.
          final paragraphNode = testContext.findEditContext().document.first as ParagraphNode;
          expect(paragraphNode.text.toPlainText().startsWith("Lorem  dolor sit amet"), isTrue);
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 6),
              ),
            ),
          );
        }, variant: inputSourceVariant);

        testWidgetsOnWindowsAndLinux("control + backspace: deletes a word upstream (after a space)", (tester) async {
          final testContext = await tester
              .createDocument() //
              .withSingleParagraph()
              .withInputSource(inputSourceVariant.currentValue!)
              .pump();

          // Lorem ipsum |dolor sit amet...
          await tester.placeCaretInParagraph("1", 12);

          // Press control + backspace
          await tester.pressCtlBackspace();

          // Ensure that the whole word was deleted.
          final paragraphNode = testContext.findEditContext().document.first as ParagraphNode;
          expect(paragraphNode.text.toPlainText().startsWith("Lorem dolor sit amet"), isTrue);
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 6),
              ),
            ),
          );
        }, variant: inputSourceVariant);

        testWidgetsOnWindowsAndLinux("control + delete: deletes a word downstream", (tester) async {
          final testContext = await tester
              .createDocument() //
              .withSingleParagraph()
              .withInputSource(inputSourceVariant.currentValue!)
              .pump();

          // Lorem ipsum |dolor sit amet...
          await tester.placeCaretInParagraph("1", 12);

          // Press control + delete
          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.delete);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

          // Ensure that the whole word was deleted.
          final paragraphNode = testContext.findEditContext().document.first as ParagraphNode;
          expect(paragraphNode.text.toPlainText(), startsWith("Lorem ipsum  sit amet"));
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 12),
              ),
            ),
          );
        }, variant: inputSourceVariant);

        testWidgetsOnWindowsAndLinux("control + backspace: deletes a word downstream (before a space)", (tester) async {
          final testContext = await tester
              .createDocument() //
              .withSingleParagraph()
              .withInputSource(inputSourceVariant.currentValue!)
              .pump();

          // Lorem ipsum| dolor sit amet...
          await tester.placeCaretInParagraph("1", 11);

          // Press control + delete
          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.delete);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

          // Ensure that the whole word was deleted.
          final paragraphNode = testContext.findEditContext().document.first as ParagraphNode;
          expect(paragraphNode.text.toPlainText().startsWith("Lorem ipsum sit amet"), isTrue);
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 11),
              ),
            ),
          );
        }, variant: inputSourceVariant);

        testWidgetsOnWindowsAndLinux("alt + backspace: deletes upstream character", (tester) async {
          final testContext = await tester
              .createDocument() //
              .withSingleParagraph()
              .withInputSource(inputSourceVariant.currentValue!)
              .pump();

          // Lorem ipsum| dolor sit amet...
          await tester.placeCaretInParagraph("1", 11);

          // Press alt + backspace
          await tester.pressAltBackspace();

          // Ensure that nothing changed.
          final paragraphNode = testContext.findEditContext().document.first as ParagraphNode;
          expect(paragraphNode.text.toPlainText(), startsWith("Lorem ipsu dolor sit amet"));
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 10),
              ),
            ),
          );
        }, variant: inputSourceVariant);

        testWidgetsOnWindowsAndLinux("alt + delete: deletes downstream character", (tester) async {
          final testContext = await tester
              .createDocument() //
              .withSingleParagraph()
              .withInputSource(inputSourceVariant.currentValue!)
              .pump();

          // Lorem ipsum| dolor sit amet...
          await tester.placeCaretInParagraph("1", 11);

          // Press alt + delete
          await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.delete);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

          // Ensure that nothing changed.
          final paragraphNode = testContext.findEditContext().document.first as ParagraphNode;
          expect(paragraphNode.text.toPlainText(), startsWith("Lorem ipsumdolor sit amet"));
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 11),
              ),
            ),
          );
        }, variant: inputSourceVariant);
      });

      testWidgetsOnDesktop(
        "Backspace deletes upstream character and keeps paragraph metadata",
        (tester) async {
          final testContext = await tester
              .createDocument() //
              .fromMarkdown('# A header')
              .withInputSource(inputSourceVariant.currentValue!)
              .pump();

          final document = testContext.document;

          // Place caret at "A| header"
          await tester.placeCaretInParagraph(document.first.id, 1);

          // Delete "A".
          await tester.pressBackspace();

          // Ensure the first character was deleted.
          expect(document.first.asTextNode.text.toPlainText(), ' header');

          // Ensure the node is still a header.
          expect(document.first.getMetadataValue("blockType"), header1Attribution);
        },
        variant: inputSourceVariant,
      );

      testWidgetsOnDesktop(
        "Backspace clears metadata at start of a paragraph",
        (tester) async {
          final testContext = await tester
              .createDocument() //
              .fromMarkdown('# A header')
              .withInputSource(inputSourceVariant.currentValue!)
              .pump();

          final document = testContext.document;

          // Place caret at the start of the header.
          await tester.placeCaretInParagraph(document.first.id, 0);

          // Press backspace to clear the metadata.
          await tester.pressBackspace();

          // Ensure the text remains the same.
          expect(document.first.asTextNode.text.toPlainText(), 'A header');

          // Ensure the header was converted to a paragraph.
          expect(document.first.getMetadataValue("blockType"), paragraphAttribution);
        },
        variant: inputSourceVariant,
      );

      group("jumps to downstream node preserving approximate x-position with DOWN ARROW", () {
        testWidgetsOnDesktop('from paragraph to paragraph', (tester) async {
          final context = await tester //
              .createDocument()
              .fromMarkdown('''
First paragraph

Second paragraph''') //
              .pump();

          // Place caret at "First para|graph".
          await tester.placeCaretInParagraph(context.document.first.id, 10);

          // Press DOWN arrow to move the caret to the downstream paragraph.
          await tester.pressDownArrow();

          // Ensure the selection moved to "Second par|agraph".
          expect(
            SuperEditorInspector.findDocumentSelection(),
            selectionEquivalentTo(
              DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: context.document.last.id,
                  nodePosition: const TextNodePosition(offset: 10),
                ),
              ),
            ),
          );
        });

        testWidgetsOnDesktop('from paragraph to task', (tester) async {
          await _pumpEditorWithTaskComponent(
            tester,
            document: MutableDocument(
              nodes: [
                ParagraphNode(id: '1', text: AttributedText('This is a paragraph')),
                TaskNode(id: '2', text: AttributedText('This is a task'), isComplete: false),
              ],
            ),
          );

          // Place the caret at "This is a |paragraph".
          await tester.placeCaretInParagraph('1', 10);

          // Press down arrow to move the caret to the downstream node.
          //
          // The text layout of this document is approximately:
          //
          // This is a paragraph
          // [ ]This is a task
          //
          // So, pressing DOWN should move the caret from "This is a |paragraph"
          // to "This is| a task".
          await tester.pressDownArrow();

          // Ensure the caret moved to "This is| a task".
          expect(
            SuperEditorInspector.findDocumentSelection(),
            selectionEquivalentTo(
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: '2',
                  nodePosition: TextNodePosition(offset: 7),
                ),
              ),
            ),
          );
        });

        testWidgetsOnDesktop('from paragraph to list item', (tester) async {
          final context = await tester //
              .createDocument()
              .fromMarkdown('''
This is a paragraph

* This is a list item''') //
              .pump();

          // Place the caret at "This is a |paragraph".
          await tester.placeCaretInParagraph(context.document.first.id, 10);

          // Press DOWN arrow to move the caret to the downstream node.
          //
          // The text layout of this document is approximately:
          //
          // This is a paragraph
          // * This is a list item
          //
          // So, pressing DOWN should move the caret from "This is a |paragraph"
          // to "This is |a list item".
          await tester.pressDownArrow();

          // Ensure the selection moved to "This is |a list item".
          expect(
            SuperEditorInspector.findDocumentSelection(),
            selectionEquivalentTo(
              DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: context.document.last.id,
                  nodePosition: const TextNodePosition(offset: 8),
                ),
              ),
            ),
          );
        });

        testWidgetsOnDesktop('from task to paragraph', (tester) async {
          await _pumpEditorWithTaskComponent(
            tester,
            document: MutableDocument(
              nodes: [
                TaskNode(id: '1', text: AttributedText('This is a task'), isComplete: false),
                ParagraphNode(id: '2', text: AttributedText('This is a paragraph')),
              ],
            ),
          );

          // Place the caret at "This| is a task".
          await tester.placeCaretInParagraph('1', 4);

          // Press down arrow to move the caret to the downstream node.
          //
          // The text layout of this document is approximately:
          //
          // [ ]This is a task
          // This is a paragraph
          //
          // So, pressing DOWN should move the caret from "This| is a task"
          // to "This is| a paragraph".
          await tester.pressDownArrow();

          // Ensure the caret moved to "This is| a paragraph."
          expect(
            SuperEditorInspector.findDocumentSelection(),
            selectionEquivalentTo(
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: '2',
                  nodePosition: TextNodePosition(offset: 7),
                ),
              ),
            ),
          );
        });

        testWidgetsOnDesktop('from task to task', (tester) async {
          await _pumpEditorWithTaskComponent(
            tester,
            document: MutableDocument(
              nodes: [
                TaskNode(id: '1', text: AttributedText('This is another task'), isComplete: false),
                TaskNode(id: '2', text: AttributedText('This is a task'), isComplete: false),
              ],
            ),
          );

          // Place the caret at "This is a|nother task".
          await tester.placeCaretInParagraph('1', 9);

          // Press down arrow to move the caret to the downstream node.
          //
          // The text layout of this document is approximately:
          //
          //   [ ]  This is another task
          //   [ ]  This is a task
          //
          // So, pressing DOWN should move the caret from "This is a|nother task"
          // to "This is a| task".
          await tester.pressDownArrow();

          // Ensure the caret moved to "This is a| task".
          expect(
            SuperEditorInspector.findDocumentSelection(),
            selectionEquivalentTo(
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: '2',
                  nodePosition: TextNodePosition(offset: 9),
                ),
              ),
            ),
          );
        });

        testWidgetsOnDesktop('from task to list item', (tester) async {
          await _pumpEditorWithTaskComponent(
            tester,
            document: MutableDocument(
              nodes: [
                TaskNode(id: '1', text: AttributedText('This is a task'), isComplete: false),
                ListItemNode.unordered(id: '2', text: AttributedText('This is a list item')),
              ],
            ),
          );

          // Place the caret at "This| is a task".
          await tester.placeCaretInParagraph('1', 4);

          // Press down arrow to move the caret to the downstream node.
          //
          // The text layout of this document is approximately:
          //
          // [ ]This is a task
          //  * This is a list item
          //
          // So, pressing DOWN should move the caret from "This| is a task"
          // to "This| is a list item".
          await tester.pressDownArrow();

          // Ensure the caret moved to "This| is a list item".
          expect(
            SuperEditorInspector.findDocumentSelection(),
            selectionEquivalentTo(
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: '2',
                  nodePosition: TextNodePosition(offset: 4),
                ),
              ),
            ),
          );
        });

        testWidgetsOnDesktop('from list item to paragraph', (tester) async {
          final context = await tester //
              .createDocument()
              .fromMarkdown('''
* This is a list item

This is a paragraph''') //
              .pump();

          // Place caret at "This is |a list item".
          await tester.placeCaretInParagraph(context.document.first.id, 8);

          // Press DOWN arrow to move the caret to the downstream node.
          //
          // The text layout of this document is approximately:
          //
          // * This is a list item
          // This is a paragraph
          //
          // So, pressing DOWN should move the caret from "This is |a list item"
          // to "This is a |paragraph".
          await tester.pressDownArrow();

          // Ensure the selection moved to "This is a |paragraph".
          expect(
            SuperEditorInspector.findDocumentSelection(),
            selectionEquivalentTo(
              DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: context.document.last.id,
                  nodePosition: const TextNodePosition(offset: 10),
                ),
              ),
            ),
          );
        });

        testWidgetsOnDesktop('from list item to task', (tester) async {
          await _pumpEditorWithTaskComponent(
            tester,
            document: MutableDocument(
              nodes: [
                ListItemNode.unordered(id: '1', text: AttributedText('This is a list item')),
                TaskNode(id: '2', text: AttributedText('This is a task'), isComplete: false),
              ],
            ),
          );

          // Place the caret at "This| is a list item".
          await tester.placeCaretInParagraph('1', 4);

          // Press down arrow to move the caret to the downstream node.
          //
          // The text layout of this document is approximately:
          //
          //  * This is a list item
          // [ ]This is a task
          //
          // So, pressing DOWN should move the caret from "This| is a list item"
          // to "This| is a task".
          await tester.pressDownArrow();

          // Ensure the caret moved to "This| is a task".
          expect(
            SuperEditorInspector.findDocumentSelection(),
            selectionEquivalentTo(
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: '2',
                  nodePosition: TextNodePosition(offset: 4),
                ),
              ),
            ),
          );
        });

        testWidgetsOnDesktop('from list item to list item', (tester) async {
          final context = await tester //
              .createDocument()
              .fromMarkdown('''
* This is another list item

* This is a list item''') //
              .pump();

          // Place the caret at "This is a|nother list item".
          await tester.placeCaretInParagraph(context.document.first.id, 9);

          // Press down arrow to move the caret to the downstream node.
          //
          // The text layout of this document is approximately:
          //
          //  *  This is another list item
          //  *  This is a list item
          //
          // So, pressing DOWN should move the caret from "This is a|nother list item"
          // to "This is a| list item".
          await tester.pressDownArrow();

          // Ensure the caret moved to "This is a| task".
          expect(
            SuperEditorInspector.findDocumentSelection(),
            selectionEquivalentTo(
              DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: context.document.last.id,
                  nodePosition: const TextNodePosition(offset: 9),
                ),
              ),
            ),
          );
        });
      });

      group("jumps to upstream node preserving approximate x-position with UP ARROW", () {
        testWidgetsOnDesktop('from paragraph to paragraph', (tester) async {
          final context = await tester //
              .createDocument()
              .fromMarkdown(''''
First paragraph

Second paragraph''') //
              .pump();

          // Place caret at "Second p|aragraph".
          await tester.placeCaretInParagraph(context.document.last.id, 8);

          // Press UP arrow to move the caret to the upstream paragraph.
          await tester.pressUpArrow();

          // Ensure the selection moved to "First para|graph".
          expect(
            SuperEditorInspector.findDocumentSelection(),
            selectionEquivalentTo(
              DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: context.document.first.id,
                  nodePosition: const TextNodePosition(offset: 10),
                ),
              ),
            ),
          );
        });

        testWidgetsOnDesktop('from paragraph to task', (tester) async {
          await _pumpEditorWithTaskComponent(
            tester,
            document: MutableDocument(
              nodes: [
                TaskNode(id: '1', text: AttributedText('This is a task'), isComplete: false),
                ParagraphNode(id: '2', text: AttributedText('This is a paragraph')),
              ],
            ),
          );

          // Place the caret at "This is a |paragraph".
          await tester.placeCaretInParagraph('2', 10);

          // Press up arrow to move the caret to the upstream node.
          //
          // The text layout of this document is approximately:
          //
          // [ ]This is a task
          // This is a paragraph
          //
          // So, pressing UP should move the caret from "This is a |paragraph"
          // to "Th|is is a task".
          await tester.pressUpArrow();

          // Ensure the caret moved to "This is| a task".
          expect(
            SuperEditorInspector.findDocumentSelection(),
            selectionEquivalentTo(
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 7),
                ),
              ),
            ),
          );
        });

        testWidgetsOnDesktop('from paragraph to list item', (tester) async {
          final context = await tester //
              .createDocument()
              .fromMarkdown('''
* This is a list item

This is a paragraph''') //
              .pump();

          // Place the caret at "This is a |paragraph".
          await tester.placeCaretInParagraph(context.document.last.id, 10);

          // Press UP arrow to move the caret to the upstream node.
          //
          // The text layout of this document is approximately:
          //
          // * This is a list item
          // This is a paragraph
          //
          // So, pressing UP should move the caret from "This is a |paragraph"
          // to "This is |a list item".
          await tester.pressUpArrow();

          // Ensure the selection moved to "This is |a list item".
          expect(
            SuperEditorInspector.findDocumentSelection(),
            selectionEquivalentTo(
              DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: context.document.first.id,
                  nodePosition: const TextNodePosition(offset: 8),
                ),
              ),
            ),
          );
        });

        testWidgetsOnDesktop('from task to paragraph', (tester) async {
          await _pumpEditorWithTaskComponent(
            tester,
            document: MutableDocument(
              nodes: [
                ParagraphNode(id: '1', text: AttributedText('This is a paragraph')),
                TaskNode(id: '2', text: AttributedText('This is a task'), isComplete: false),
              ],
            ),
          );

          // Place the caret at "This| is a task".
          await tester.placeCaretInParagraph('2', 4);

          // Press up arrow to move the caret to the upstream node.
          //
          // The text layout of this document is approximately:
          //
          // This is a paragraph
          // [ ]This is a task
          //
          // So, pressing UP should move the caret from "This| is a task"
          // to "This is| a paragraph".
          await tester.pressUpArrow();

          // Ensure the caret moved to "This is| a paragraph."
          expect(
            SuperEditorInspector.findDocumentSelection(),
            selectionEquivalentTo(
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 7),
                ),
              ),
            ),
          );
        });

        testWidgetsOnDesktop('from task to task', (tester) async {
          await _pumpEditorWithTaskComponent(
            tester,
            document: MutableDocument(
              nodes: [
                TaskNode(id: '1', text: AttributedText('This is a task'), isComplete: false),
                TaskNode(id: '2', text: AttributedText('This is another task'), isComplete: false),
              ],
            ),
          );

          // Place the caret at "This is a|nother task".
          await tester.placeCaretInParagraph('2', 9);

          // Press up arrow to move the caret to the upstream node.
          //
          // The text layout of this document is approximately:
          //
          //   [ ]  This is a task
          //   [ ]  This is another task
          //
          // So, pressing UP should move the caret from "This is a|nother task"
          // to "This is a| task".
          await tester.pressUpArrow();

          // Ensure the caret moved to "This is a| task".
          expect(
            SuperEditorInspector.findDocumentSelection(),
            selectionEquivalentTo(
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 9),
                ),
              ),
            ),
          );
        });

        testWidgetsOnDesktop('from task to list item', (tester) async {
          await _pumpEditorWithTaskComponent(
            tester,
            document: MutableDocument(
              nodes: [
                ListItemNode.unordered(id: '1', text: AttributedText('This is a list item')),
                TaskNode(id: '2', text: AttributedText('This is a task'), isComplete: false),
              ],
            ),
          );

          // Place the caret at "This| is a task".
          await tester.placeCaretInParagraph('2', 4);

          // Press UP arrow to move the caret to the upstream node.
          //
          // The text layout of this document is approximately:
          //
          //  * This is a list item
          // [ ]This is a task
          //
          // So, pressing UP should move the caret from "This| is a task"
          // to "This| is a list item".
          await tester.pressUpArrow();

          // Ensure the caret moved to "This| is a list item".
          expect(
            SuperEditorInspector.findDocumentSelection(),
            selectionEquivalentTo(
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 4),
                ),
              ),
            ),
          );
        });

        testWidgetsOnDesktop('from list item to paragraph', (tester) async {
          final context = await tester //
              .createDocument()
              .fromMarkdown('''
This is a paragraph

* This is a list item''') //
              .pump();

          // Place caret at "This is |a list item".
          await tester.placeCaretInParagraph(context.document.last.id, 8);

          // Press UP arrow to move the caret to the upstream node.
          //
          // The text layout of this document is approximately:
          //
          // This is a paragraph
          // * This is a list item
          //
          // So, pressing UP should move the caret from "This is |a list item"
          // to "This is a |paragraph".
          await tester.pressUpArrow();

          // Ensure the selection moved to "This is a |paragraph".
          expect(
            SuperEditorInspector.findDocumentSelection(),
            selectionEquivalentTo(
              DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: context.document.first.id,
                  nodePosition: const TextNodePosition(offset: 10),
                ),
              ),
            ),
          );
        });

        testWidgetsOnDesktop('from list item to task', (tester) async {
          await _pumpEditorWithTaskComponent(
            tester,
            document: MutableDocument(
              nodes: [
                TaskNode(id: '1', text: AttributedText('This is a task'), isComplete: false),
                ListItemNode.unordered(id: '2', text: AttributedText('This is a list item')),
              ],
            ),
          );

          // Place the caret at "This| is a list item".
          await tester.placeCaretInParagraph('2', 4);

          // Press UP arrow to move the caret to the upstream node.
          //
          // The text layout of this document is approximately:
          //
          // [ ]This is a task
          //  * This is a list item
          //
          // So, pressing UP should move the caret from "This| is a list item"
          // to "This| is a task".
          await tester.pressUpArrow();

          // Ensure the caret moved to "This| is a task".
          expect(
            SuperEditorInspector.findDocumentSelection(),
            selectionEquivalentTo(
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 4),
                ),
              ),
            ),
          );
        });

        testWidgetsOnDesktop('from list item to list item', (tester) async {
          final context = await tester //
              .createDocument()
              .fromMarkdown('''
* This is a list item

* This is another list item''') //
              .pump();

          // Place the caret at "This is a|nother list item".
          await tester.placeCaretInParagraph(context.document.last.id, 9);

          // Press UP arrow to move the caret to the upstream node.
          //
          // The text layout of this document is approximately:
          //
          //  *  This is a list item
          //  *  This is another list item
          //
          // So, pressing UP should move the caret from "This is a|nother list item"
          // to "This is a| list item".
          await tester.pressUpArrow();

          // Ensure the caret moved to "This is a| task".
          expect(
            SuperEditorInspector.findDocumentSelection(),
            selectionEquivalentTo(
              DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: context.document.first.id,
                  nodePosition: const TextNodePosition(offset: 9),
                ),
              ),
            ),
          );
        });
      });
    });

    group("Linux >", () {
      group('jumps to', () {
        testWidgetsOnLinux('preceding character with ALT + LEFT ARROW', (tester) async {
          // Start the user's selection somewhere in the middle of a word.
          await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

          await tester.pressAltLeftArrow();

          // Ensure that the caret moved one character to the left.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 7),
              ),
            ),
          );
        });

        testWidgetsOnLinux('next character with ALT + RIGHT ARROW', (tester) async {
          // Start the user's selection somewhere in the middle of a word.
          await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

          await tester.pressAltRightArrow();

          // Ensure that the caret moved one character to the right
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 9),
              ),
            ),
          );
        });
      });
    });

    group("does nothing", () {
      testWidgetsOnWindows("with ALT + LEFT ARROW", (tester) async {
        // Start the user's selection somewhere in the middle of a word.
        await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

        await tester.pressAltLeftArrow();

        // Ensure that the caret didn't move
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 8),
            ),
          ),
        );
      });

      testWidgetsOnWindows("with ALT + RIGHT ARROW", (tester) async {
        // Start the user's selection somewhere in the middle of a word.
        await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

        await tester.pressAltRightArrow();

        // Ensure that the caret didn't move
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 8),
            ),
          ),
        );
      });

      testWidgetsOnWindowsAndLinux('with ALT + UP ARROW', (tester) async {
        await _pumpExplicitLineBreakTestSetup(tester);

        // Place caret at the second line at "consectetur adipiscing |elit"
        await tester.placeCaretInParagraph('1', 51);

        await tester.pressAltUpArrow();

        // Ensure that the caret didn't move
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 51),
            ),
          ),
        );
      });

      testWidgetsOnWindowsAndLinux('with ALT + DOWN ARROW', (tester) async {
        await _pumpExplicitLineBreakTestSetup(tester);

        // Place caret at the first line at "Lorem |ipsum"
        await tester.placeCaretInParagraph('1', 6);

        await tester.pressAltDownArrow();

        // Ensure that the caret didn't move
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 6),
            ),
          ),
        );
      });
    });

    group("shortcuts for Windows and Linux do nothing on mac", () {
      testWidgetsOnMac('HOME', (tester) async {
        // Start the user's selection somewhere after the beginning of the first
        // line in the first node.
        await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

        await tester.pressHome();

        // Ensure that the caret didn't move
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 8),
            ),
          ),
        );
      });

      testWidgetsOnMac('END', (tester) async {
        // Start the user's selection somewhere after the beginning of the first
        // line in the first node.
        await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 2);

        await tester.pressEnd();

        // Ensure that the caret didn't move
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 2),
            ),
          ),
        );
      });

      testWidgetsOnMac('CTRL + LEFT ARROW', (tester) async {
        // Start the user's selection somewhere in the middle of a word.
        await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

        await tester.pressCtlLeftArrow();

        // Ensure that the caret moved only one character to the left
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 7),
            ),
          ),
        );
      });

      testWidgetsOnMac('CTRL + RIGHT ARROW', (tester) async {
        // Start the user's selection somewhere in the middle of a word.
        await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

        await tester.pressCtlRightArrow();

        // Ensure that the caret moved only one character to the right
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 9),
            ),
          ),
        );
      });
    });

    group("shortcuts for Mac do nothing on Windows and Linux", () {
      testWidgetsOnWindowsAndLinux('CMD + LEFT ARROW', (tester) async {
        // Start the user's selection somewhere after the beginning of the first
        // line in the first node.
        await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

        await tester.pressCmdLeftArrow();

        // Ensure that the caret didn't move to the beginning of the line.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 7),
            ),
          ),
        );
      });

      testWidgetsOnWindowsAndLinux('CMD + RIGHT ARROW', (tester) async {
        // Start the user's selection somewhere before the end of the first line
        // in the first node.
        await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 2);

        await tester.pressCmdRightArrow();

        // Ensure that the caret didn't move to the end of the line.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 3),
            ),
          ),
        );
      });
    });

    group('CMD + A to select all', () {
      testWidgetsOnApple('does nothing when CMD key is pressed but A-key is not pressed', (tester) async {
        await tester //
            .createDocument()
            .withSingleParagraph()
            .pump();

        await tester.placeCaretInParagraph("1", 0);

        // Press CMD key.
        await tester.sendKeyEvent(LogicalKeyboardKey.metaLeft);

        // Ensure we didn't select all content.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 0),
            ),
          ),
        );
      });

      testWidgetsOnApple('does nothing when A-key is pressed but meta key is not pressed', (tester) async {
        await tester //
            .createDocument()
            .withSingleParagraph()
            .pump();

        await tester.placeCaretInParagraph("1", 0);

        // Press CMD key.
        await tester.sendKeyEvent(LogicalKeyboardKey.keyA);

        // Ensure we didn't select all content.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 1),
            ),
          ),
        );
      });

      testWidgetsOnApple('does nothing when CMD+A is pressed but the document is empty', (tester) async {
        await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .pump();

        await tester.placeCaretInParagraph("1", 0);

        await tester.pressCmdA();

        // We don't expect that our selection changed at all.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 0),
            ),
          ),
        );
      });

      testWidgetsOnApple('selects all when CMD+A is pressed with a single-node document', (tester) async {
        await tester //
            .createDocument()
            .withCustomContent(MutableDocument(
              nodes: [
                ParagraphNode(
                  id: '1',
                  text: AttributedText('This is some text'),
                ),
              ],
            ))
            .pump();

        await tester.placeCaretInParagraph("1", 0);

        await tester.pressCmdA();

        // Ensure everything is selected.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection(
            base: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 0),
            ),
            extent: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 17),
            ),
          ),
        );
      });

      testWidgetsOnApple('selects all when CMD+A is pressed with a two-node document', (tester) async {
        await tester //
            .createDocument()
            .withCustomContent(
              MutableDocument(
                nodes: [
                  ParagraphNode(
                    id: '1',
                    text: AttributedText('This is some text'),
                  ),
                  ParagraphNode(
                    id: '2',
                    text: AttributedText('This is some text'),
                  ),
                ],
              ),
            )
            .pump();

        await tester.placeCaretInParagraph("1", 0);

        await tester.pressCmdA();

        // Ensure everything is selected.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection(
            base: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 0),
            ),
            extent: DocumentPosition(
              nodeId: '2',
              nodePosition: TextNodePosition(offset: 17),
            ),
          ),
        );
      });

      testWidgetsOnApple('selects all when CMD+A is pressed with a three-node document', (tester) async {
        await tester //
            .createDocument()
            .withCustomContent(
              MutableDocument(
                nodes: [
                  ImageNode(
                    id: '1',
                    imageUrl: 'https://fake.com/image/url.png',
                  ),
                  ParagraphNode(
                    id: '2',
                    text: AttributedText('This is some text'),
                  ),
                  ImageNode(
                    id: '3',
                    imageUrl: 'https://fake.com/image/url.png',
                  ),
                ],
              ),
            )
            .withAddedComponents([const FakeImageComponentBuilder(size: Size(800, 400))]) //
            .pump();

        await tester.placeCaretInParagraph("2", 0);

        await tester.pressCmdA();

        // Ensure everything is selected.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection(
            base: DocumentPosition(
              nodeId: '1',
              nodePosition: UpstreamDownstreamNodePosition.upstream(),
            ),
            extent: DocumentPosition(
              nodeId: '3',
              nodePosition: UpstreamDownstreamNodePosition.downstream(),
            ),
          ),
        );
      });
    });

    group('key pressed with selection', () {
      testWidgetsOnApple('deletes selection if backspace is pressed', (tester) async {
        await tester //
            .createDocument()
            .withCustomContent(
              MutableDocument(
                nodes: [
                  ParagraphNode(
                    id: '1',
                    text: AttributedText('Text with [DELETEME] selection'),
                  ),
                ],
              ),
            )
            .pump();

        // Select "DELETEME" by doube-tapping.
        await tester.doubleTapInParagraph("1", 14);

        // Ensure that we selected the word.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection(
            base: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 11),
            ),
            extent: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 19),
            ),
          ),
        );

        await tester.pressBackspace();

        // Ensure the selected content was deleted.
        expect(SuperEditorInspector.findTextInComponent("1").toPlainText(), "Text with [] selection");
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 11),
            ),
          ),
        );
      });

      testWidgetsOnApple('deletes selection if delete is pressed', (tester) async {
        await tester //
            .createDocument()
            .withCustomContent(
              MutableDocument(
                nodes: [
                  ParagraphNode(
                    id: '1',
                    text: AttributedText('Text with [DELETEME] selection'),
                  ),
                ],
              ),
            )
            .pump();

        // Select "DELETEME" by doube-tapping.
        await tester.doubleTapInParagraph("1", 14);

        // Ensure that we selected the word.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection(
            base: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 11),
            ),
            extent: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 19),
            ),
          ),
        );

        await tester.pressDelete();

        // Ensure the selected content was deleted.
        expect(SuperEditorInspector.findTextInComponent("1").toPlainText(), "Text with [] selection");
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 11),
            ),
          ),
        );
      });

      testWidgetsOnApple('replaces selected content with character when character key is pressed', (tester) async {
        await tester //
            .createDocument()
            .withCustomContent(
              MutableDocument(
                nodes: [
                  ParagraphNode(
                    id: '1',
                    text: AttributedText('Text with [DELETEME] selection'),
                  ),
                ],
              ),
            )
            .withInputSource(TextInputSource.keyboard)
            .pump();

        // Select "DELETEME" by doube-tapping.
        await tester.doubleTapInParagraph("1", 14);

        // Ensure that we selected the word.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection(
            base: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 11),
            ),
            extent: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 19),
            ),
          ),
        );

        await tester.typeKeyboardText("a");

        // Ensure the selected content was deleted.
        expect(SuperEditorInspector.findTextInComponent("1").toPlainText(), "Text with [a] selection");
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 12),
            ),
          ),
        );
      });

      testWidgetsOnApple('collapses selection if escape is pressed', (tester) async {
        await tester //
            .createDocument()
            .withCustomContent(
              MutableDocument(
                nodes: [
                  ParagraphNode(
                    id: '1',
                    text: AttributedText('Text with [SELECTME] selection'),
                  ),
                ],
              ),
            )
            .pump();

        // Select "SELECTME" by double-tapping.
        await tester.doubleTapInParagraph("1", 14);

        // Ensure that we selected the word.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection(
            base: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 11),
            ),
            extent: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 19),
            ),
          ),
        );

        await tester.pressEscape();

        // Ensure the selected content was deleted.
        expect(SuperEditorInspector.findTextInComponent("1").toPlainText(), "Text with [SELECTME] selection");
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 19),
            ),
          ),
        );
      });
    });

    testWidgetsOnApple('does nothing when escape is pressed if the selection is collapsed', (tester) async {
      await tester //
          .createDocument()
          .withCustomContent(
            MutableDocument(
              nodes: [
                ParagraphNode(
                  id: '1',
                  text: AttributedText('This is some text'),
                ),
              ],
            ),
          )
          .pump();

      // Select "SELECTME" by double-tapping.
      await tester.placeCaretInParagraph("1", 8);

      await tester.pressEscape();

      // Ensure that nothing changed.
      expect(SuperEditorInspector.findTextInComponent("1").toPlainText(), "This is some text");
      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: '1',
            nodePosition: TextNodePosition(offset: 8),
          ),
        ),
      );
    });

    group("page scrolling", () {
      testWidgetsOnAllPlatforms(
        'PAGE DOWN scrolls down by the viewport height',
        (tester) async {
          await _scrollingVariant.currentValue!.pumpEditor(
            tester,
            _scrollingVariant.currentValue!.textInputSource,
          );

          await tester.placeCaretInParagraph('1', 0);

          final scrollState = tester.state<ScrollableState>(find.byType(Scrollable));

          await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);

          // Let the scrolling system auto-scroll, as desired.
          await tester.pumpAndSettle();

          // Ensure we scrolled down by the viewport height.
          expect(
            scrollState.position.pixels,
            equals(scrollState.position.viewportDimension),
          );
        },
        variant: _scrollingVariant,
      );

      testWidgetsOnAllPlatforms(
        'PAGE DOWN does not scroll past bottom of the viewport',
        (tester) async {
          await _scrollingVariant.currentValue!.pumpEditor(
            tester,
            _scrollingVariant.currentValue!.textInputSource,
          );

          await tester.placeCaretInParagraph('1', 0);

          final scrollState = tester.state<ScrollableState>(find.byType(Scrollable));

          // Scroll very close to the bottom but not all the way to avoid explicit
          // checks comparing scroll offset directly against `maxScrollExtent`
          // and test scrolling behaviour in more realistic manner.
          scrollState.position.jumpTo(scrollState.position.maxScrollExtent - 10);

          await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);

          // Let the scrolling system auto-scroll, as desired.
          await tester.pumpAndSettle();

          // Ensure we didn't scroll past the bottom of the viewport.
          expect(scrollState.position.pixels, equals(scrollState.position.maxScrollExtent));
        },
        variant: _scrollingVariant,
      );

      testWidgetsOnAllPlatforms(
        'PAGE UP scrolls up by the viewport height',
        (tester) async {
          await _scrollingVariant.currentValue!.pumpEditor(
            tester,
            _scrollingVariant.currentValue!.textInputSource,
          );

          await tester.placeCaretInParagraph('1', 0);

          final scrollState = tester.state<ScrollableState>(find.byType(Scrollable));

          // Scroll to the bottom of the viewport.
          scrollState.position.jumpTo(scrollState.position.maxScrollExtent);

          await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);

          // Let the scrolling system auto-scroll, as desired.
          await tester.pumpAndSettle();

          // Ensure we scrolled up by the viewport height.
          expect(
            scrollState.position.pixels,
            equals(scrollState.position.maxScrollExtent - scrollState.position.viewportDimension),
          );
        },
        variant: _scrollingVariant,
      );

      testWidgetsOnAllPlatforms(
        'PAGE UP does not scroll past top of the viewport',
        (tester) async {
          await _scrollingVariant.currentValue!.pumpEditor(
            tester,
            _scrollingVariant.currentValue!.textInputSource,
          );

          await tester.placeCaretInParagraph('1', 0);

          final scrollState = tester.state<ScrollableState>(find.byType(Scrollable));

          // Scroll very close to the top but not all the way to avoid explicit
          // checks comparing scroll offset directly against `minScrollExtent`
          // and test scrolling behaviour in more realistic manner.
          scrollState.position.jumpTo(scrollState.position.minScrollExtent + 10);

          await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);

          // Let the scrolling system auto-scroll, as desired.
          await tester.pumpAndSettle();

          // Ensure we didn't scroll past the top of the viewport.
          expect(scrollState.position.pixels, equals(scrollState.position.minScrollExtent));
        },
        variant: _scrollingVariant,
      );

      testWidgetsOnAllPlatforms(
        'CMD + HOME on mac/ios and CTRL + HOME on other platforms scrolls to top of viewport',
        (tester) async {
          await _scrollingVariant.currentValue!.pumpEditor(
            tester,
            _scrollingVariant.currentValue!.textInputSource,
          );

          await tester.placeCaretInParagraph('1', 0);

          final scrollState = tester.state<ScrollableState>(find.byType(Scrollable));

          // Scroll to the bottom of the viewport.
          scrollState.position.jumpTo(scrollState.position.maxScrollExtent);

          if (defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS) {
            await tester.pressCmdHome(tester);
          } else {
            await tester.pressCtrlHome(tester);
          }

          // Ensure we scrolled to the top of the viewport.
          expect(
            scrollState.position.pixels,
            equals(scrollState.position.minScrollExtent),
          );
        },
        variant: _scrollingVariant,
      );

      testWidgetsOnAllPlatforms(
        "CMD + HOME on mac/ios and CTRL + HOME on other platforms does not scroll past top of the viewport",
        (tester) async {
          await _scrollingVariant.currentValue!.pumpEditor(
            tester,
            _scrollingVariant.currentValue!.textInputSource,
          );

          await tester.placeCaretInParagraph('1', 0);

          final scrollState = tester.state<ScrollableState>(find.byType(Scrollable));

          // Scroll very close to the top but not all the way to avoid explicit
          // checks comparing scroll offset directly against `minScrollExtent`
          // and test scrolling behaviour in more realistic manner.
          scrollState.position.jumpTo(scrollState.position.minScrollExtent + 10);

          if (defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS) {
            await tester.pressCmdHome(tester);
          } else {
            await tester.pressCtrlHome(tester);
          }

          // Ensure we didn't scroll past the top of the viewport.
          expect(scrollState.position.pixels, equals(scrollState.position.minScrollExtent));
        },
        variant: _scrollingVariant,
      );

      testWidgetsOnAllPlatforms(
        "CMD + END on mac/ios and CTRL + END on other platforms scrolls to bottom of viewport",
        (tester) async {
          await _scrollingVariant.currentValue!.pumpEditor(
            tester,
            _scrollingVariant.currentValue!.textInputSource,
          );

          await tester.placeCaretInParagraph('1', 0);

          final scrollState = tester.state<ScrollableState>(find.byType(Scrollable));

          if (defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS) {
            await tester.pressCmdEnd(tester);
          } else {
            await tester.pressCtrlEnd(tester);
          }

          // Ensure we scrolled to the bottom of the viewport.
          expect(scrollState.position.pixels, equals(scrollState.position.maxScrollExtent));
        },
        variant: _scrollingVariant,
      );

      testWidgetsOnAllPlatforms(
        "CMD + END on mac/ios and CTRL + END on other platforms does not scroll past bottom of the viewport",
        (tester) async {
          await _scrollingVariant.currentValue!.pumpEditor(
            tester,
            _scrollingVariant.currentValue!.textInputSource,
          );

          await tester.placeCaretInParagraph('1', 0);

          final scrollState = tester.state<ScrollableState>(find.byType(Scrollable));

          // Scroll very close to the bottom but not all the way to avoid explicit
          // checks comparing scroll offset directly against `maxScrollExtent`
          // and test scrolling behaviour in more realistic manner.
          scrollState.position.jumpTo(scrollState.position.maxScrollExtent - 10);

          if (defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS) {
            await tester.pressCmdEnd(tester);
          } else {
            await tester.pressCtrlEnd(tester);
          }

          // Ensure we didn't scroll past the bottom of the viewport.
          expect(scrollState.position.pixels, equals(scrollState.position.maxScrollExtent));
        },
        variant: _scrollingVariant,
      );
    });
  });
}

/// Pumps a [SuperEditor] with a single-paragraph document, with focus, and returns
/// the associated [SuperEditorContext] for further inspection and control.
///
/// This particular setup is intended for caret movement testing within a single
/// paragraph node.
Future<TestDocumentContext> _pumpCaretMovementTestSetup(
  WidgetTester tester, {
  required int textOffsetInFirstNode,
}) async {
  final focusNode = FocusNode()..requestFocus();
  final context = await tester //
      .createDocument()
      .withSingleParagraph()
      .withFocusNode(focusNode)
      .pump();

  await tester.placeCaretInParagraph("1", textOffsetInFirstNode);

  return context;
}

Future<TestDocumentContext> _pumpAutoWrappingTestSetup(WidgetTester tester) async {
  return await tester //
      .createDocument()
      .withSingleParagraph()
      .forDesktop()
      .withEditorSize(const Size(400, 400))
      .pump();
}

Future<TestDocumentContext> _pumpExplicitLineBreakTestSetup(
  WidgetTester tester, {
  Size? size,
}) async {
  return await tester
      .createDocument()
      .withCustomContent(MutableDocument(
        nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText(
              'Lorem ipsum dolor sit amet\nconsectetur adipiscing elit',
            ),
          ),
        ],
      ))
      .forDesktop()
      .withEditorSize(size)
      .pump();
}

/// Pumps a [SuperEditor] with a document with two multi-line paragraphs.
Future<TestDocumentContext> _pumpTwoParagraphsTestApp(
  WidgetTester tester, {
  required TextInputSource inputSource,
}) async {
  final context = await tester //
      .createDocument()
      .withCustomContent(MutableDocument(
        nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText(
              'First paragraph\nwith multiple lines',
            ),
          ),
          ParagraphNode(
            id: '2',
            text: AttributedText(
              'Second paragraph\nwith multiple lines',
            ),
          ),
        ],
      ))
      .withInputSource(inputSource)
      .pump();

  return context;
}

/// Variant for an editor experience with an internal scrollable and
/// an ancestor scrollable.
final _scrollingVariant = ValueVariant<_PageScrollSetup>({
  const _PageScrollSetup(
    description: "inner viewport",
    pumpEditor: _pumpPageScrollTestSetup,
    textInputSource: TextInputSource.ime,
  ),
  const _PageScrollSetup(
    description: "inner viewport",
    pumpEditor: _pumpPageScrollTestSetup,
    textInputSource: TextInputSource.keyboard,
  ),
  const _PageScrollSetup(
    description: "ancestor viewport",
    pumpEditor: _pumpPageScrollSliverTestSetup,
    textInputSource: TextInputSource.ime,
  ),
  const _PageScrollSetup(
    description: "ancestor viewport",
    pumpEditor: _pumpPageScrollSliverTestSetup,
    textInputSource: TextInputSource.keyboard,
  ),
});

/// Pumps a [SuperEditor] experience with the default [Scrollable].
Future<TestDocumentContext> _pumpPageScrollTestSetup(
  WidgetTester tester,
  TextInputSource textInputSource,
) async {
  return await tester //
      .createDocument()
      .withLongDoc()
      .withInputSource(textInputSource)
      .pump();
}

/// Pumps a [SuperEditor] within a ancestor [Scrollable], including additional
/// content above the [SuperEditor] and additional content on top of [Scrollable].
///
/// By including content above the [SuperEditor], it doesn't have the same origin as
/// the ancestor [Scrollable].
///
/// By including content on top of [Scrollable], it doesn't have the origin
/// at [Offset.zero].
///
/// This setup is intended for testing page scrolling actions behaviour in presense
/// of an ancestor [Scrollable].
Future<TestDocumentContext> _pumpPageScrollSliverTestSetup(
  WidgetTester tester,
  TextInputSource textInputSource,
) async {
  return tester //
      .createDocument()
      .withLongDoc()
      .withInputSource(textInputSource)
      .withCustomWidgetTreeBuilder((superEditor) {
    return MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.only(top: 300),
          child: CustomScrollView(
            slivers: [
              const SliverAppBar(
                title: Text(
                  'Rich Text Editor Sliver Example',
                ),
                expandedHeight: 200.0,
              ),
              superEditor,
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                    return ListTile(title: Text('$index'));
                  },
                  childCount: 100,
                ),
              ),
            ],
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }).pump();
}

/// Pumps a [SuperEditor] configured with the [TaskComponentBuilder].
Future<void> _pumpEditorWithTaskComponent(
  WidgetTester tester, {
  required MutableDocument document,
}) async {
  final composer = MutableDocumentComposer();
  final editor = createDefaultDocumentEditor(document: document, composer: composer);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SuperEditor(
          editor: editor,
          componentBuilders: [
            TaskComponentBuilder(editor),
            ...defaultComponentBuilders,
          ],
        ),
      ),
    ),
  );
}

Future<void> _pressShiftAltUpArrow(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shift, platform: 'macos');
  await tester.sendKeyDownEvent(LogicalKeyboardKey.alt, platform: 'macos');
  await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp, platform: 'macos');
  await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp, platform: 'macos');
  await tester.sendKeyUpEvent(LogicalKeyboardKey.alt, platform: 'macos');
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shift, platform: 'macos');
  await tester.pumpAndSettle();
}

Future<void> _pressShiftAltDownArrow(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shift, platform: 'macos');
  await tester.sendKeyDownEvent(LogicalKeyboardKey.alt, platform: 'macos');
  await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown, platform: 'macos');
  await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown, platform: 'macos');
  await tester.sendKeyUpEvent(LogicalKeyboardKey.alt, platform: 'macos');
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shift, platform: 'macos');
  await tester.pumpAndSettle();
}

/// Holds the setup for a page scroll test.
class _PageScrollSetup {
  const _PageScrollSetup({
    required this.description,
    required this.pumpEditor,
    required this.textInputSource,
  });
  final String description;
  final _PumpEditorWidget pumpEditor;
  final TextInputSource textInputSource;

  @override
  String toString() {
    return "PageScrollSetup: $description, ${textInputSource.toString()}";
  }
}

typedef _PumpEditorWidget = Future<TestDocumentContext> Function(
  WidgetTester tester,
  TextInputSource textInputSource,
);
