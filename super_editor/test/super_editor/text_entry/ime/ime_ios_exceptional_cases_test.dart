import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../../../test_tools.dart';

void main() {
  group('IME input >', () {
    group('iPhone >', () {
      testWidgetsOnIos('can backspace an empty paragraph with deletion delta', (tester) async {
        await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .pump();

        // Place the caret in the first paragraph.
        await tester.placeCaretInParagraph('1', 0);

        // Create a second empty paragraph.
        await tester.pressEnterWithIme(getter: imeClientGetter);
        expect(SuperEditorInspector.findDocument()!.length, 2);

        // Backspace to delete the 2nd empty paragraph. We run this deletion
        // as its reported on iOS, to make sure that the iOS delta deletion
        // approach doesn't conflict with our logic to ignore GBoard trailing
        // space removal.
        await tester.ime.sendDeltas(const [
          TextEditingDeltaNonTextUpdate(
            oldText: '. ',
            selection: TextSelection(baseOffset: 1, extentOffset: 2),
            composing: TextRange(start: -1, end: -1),
          ),
          TextEditingDeltaDeletion(
            oldText: '. ',
            deletedRange: TextRange(start: 1, end: 2),
            selection: TextSelection.collapsed(
              offset: 1,
              affinity: TextAffinity.downstream,
            ),
            composing: TextRange(start: -1, end: -1),
          ),
        ], getter: imeClientGetter);

        // Ensure that we deleted the 2nd paragraph and moved back up to the first.
        final document = SuperEditorInspector.findDocument()!;
        expect(document.length, 1);
        expect(document.first.id, "1");
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 0)),
          ),
        );
      });

      group('on iPhone 11 (iOS 13.7) with chinese keyboard', () {
        testWidgetsOnIos('applies keyboard suggestions', (tester) async {
          // Holds the composing region that we sent to the IME.
          TextRange? composingRegion;

          await tester //
              .createDocument()
              .withSingleEmptyParagraph()
              .withInputSource(TextInputSource.ime)
              .pump();

          // Place the caret at the start of the paragraph.
          await tester.placeCaretInParagraph('1', 0);

          // Simulate the user typing "a a a".
          await tester.ime.sendDeltas(const [
            TextEditingDeltaNonTextUpdate(
              oldText: '. ',
              selection: TextSelection.collapsed(offset: 2),
              composing: TextRange(start: -1, end: -1),
            ),
            TextEditingDeltaInsertion(
              oldText: '. ',
              textInserted: 'a',
              insertionOffset: 2,
              selection: TextSelection.collapsed(
                offset: 3,
                affinity: TextAffinity.upstream,
              ),
              composing: TextRange(start: 2, end: 3),
            ),
          ], getter: imeClientGetter);
          await tester.ime.sendDeltas(const [
            TextEditingDeltaInsertion(
              oldText: '. a',
              textInserted: ' a',
              insertionOffset: 3,
              selection: TextSelection.collapsed(
                offset: 5,
                affinity: TextAffinity.upstream,
              ),
              composing: TextRange(start: 2, end: 5),
            ),
          ], getter: imeClientGetter);
          await tester.ime.sendDeltas(const [
            TextEditingDeltaInsertion(
              oldText: '. a a',
              textInserted: ' a',
              insertionOffset: 5,
              selection: TextSelection.collapsed(
                offset: 7,
                affinity: TextAffinity.upstream,
              ),
              composing: TextRange(start: 2, end: 7),
            ),
          ], getter: imeClientGetter);

          // Simulate the user accepting the suggestion from the keyboard.
          //
          // The IME sends the replacement and changes the composing region in the same frame,
          // in separate delta batches.
          final imeClient = imeClientGetter();
          imeClient.updateEditingValueWithDeltas(const [
            TextEditingDeltaReplacement(
              oldText: '. a a a',
              replacementText: '呵呵呵',
              replacedRange: TextRange(start: 2, end: 7),
              selection: TextSelection.collapsed(
                offset: 5,
                affinity: TextAffinity.upstream,
              ),
              composing: TextRange(start: 2, end: 5),
            ),
          ]);

          // Intercept the setEditingState message sent to the platform so we can check
          // which composing region was sent.
          tester
              .interceptChannel(SystemChannels.textInput.name) //
              .interceptMethod(
            'TextInput.setEditingState',
                (methodCall) {
              final params = methodCall.arguments as Map;
              composingRegion = TextRange(
                start: params['composingBase'],
                end: params['composingExtent'],
              );
              return null;
            },
          );

          imeClient.updateEditingValueWithDeltas(const [
            TextEditingDeltaNonTextUpdate(
              oldText: '. 呵呵呵',
              selection: TextSelection.collapsed(
                offset: 5,
                affinity: TextAffinity.upstream,
              ),
              composing: TextRange.empty,
            ),
          ]);
          await tester.pump();

          // Between the two updateEditingValueWithDeltas calls, the IME interactor
          // sends [0, 3) as the new composing region (the composing region of the first delta) to the IME.
          //
          // If the user types with that composing region, all the existing text is replaced.
          //
          // Ensure we cleared the composing region on the IME so the previous entered text is preserved.
          expect(composingRegion, TextRange.empty);
        });

        testWidgetsOnIos('applies keyboard suggestions and keeps styles', (tester) async {
          // Pump an editor with a bold text.
          final testContext = await tester //
              .createDocument()
              .fromMarkdown('**Fix**')
              .withInputSource(TextInputSource.ime)
              .pump();

          // Place the caret at the end of the paragraph.
          await tester.placeCaretInParagraph(testContext.document.first.id, 3);

          // Type a letter simulating a typo. The current text results in "Fixs".
          await tester.typeImeText('s');

          // Simulate the user accepting a suggestion.
          // The IME replaces the word and inserts a space after it.
          await tester.ime.sendDeltas([
            const TextEditingDeltaReplacement(
              oldText: '. Fixs',
              replacementText: 'Fixed',
              replacedRange: TextRange(start: 2, end: 6),
              selection: TextSelection.collapsed(offset: 7),
              composing: TextRange(start: -1, end: -1),
            ),
          ], getter: imeClientGetter);
          await tester.ime.sendDeltas([
            const TextEditingDeltaInsertion(
              oldText: '. Fixed',
              textInserted: ' ',
              insertionOffset: 7,
              selection: TextSelection.collapsed(offset: 8),
              composing: TextRange(start: -1, end: -1),
            )
          ], getter: imeClientGetter);

          // Ensure the text was replaced and the style was preserved.
          expect(testContext.document, equalsMarkdown('**Fixed **'));
        });
      });

      group('on iPhone 13 (iOS 17.2) with korean keyboard', () {
        testWidgetsOnIos('applies keyboard suggestions', (tester) async {
          await tester //
              .createDocument()
              .withSingleEmptyParagraph()
              .withInputSource(TextInputSource.ime)
              .pump();

          // Place the caret at the start of the paragraph.
          await tester.placeCaretInParagraph('1', 0);

          // Simulate the user typing "ㅅ".
          await tester.ime.sendDeltas(const [
            TextEditingDeltaNonTextUpdate(
              oldText: '. ',
              selection: TextSelection.collapsed(offset: 2),
              composing: TextRange(start: -1, end: -1),
            ),
            TextEditingDeltaInsertion(
              oldText: '. ',
              textInserted: 'ㅅ',
              insertionOffset: 2,
              selection: TextSelection.collapsed(offset: 3, affinity: TextAffinity.downstream),
              composing: TextRange(start: -1, end: -1),
            ),
          ], getter: imeClientGetter);

          // Simulate the user typing "ㅛ" and the IME converting the "ㅅㅛ" to "쇼".
          await tester.ime.sendDeltas(const [
            TextEditingDeltaNonTextUpdate(
              oldText: '. ㅅ',
              selection: TextSelection(baseOffset: 1, extentOffset: 3, isDirectional: false),
              composing: TextRange(start: -1, end: -1),
            ),
            TextEditingDeltaDeletion(
              oldText: '. ㅅ',
              deletedRange: TextRange(start: 1, end: 3),
              selection: TextSelection.collapsed(
                offset: 1,
                affinity: TextAffinity.downstream,
              ),
              composing: TextRange(start: -1, end: -1),
            ),
            TextEditingDeltaInsertion(
              oldText: '.',
              textInserted: ' ',
              insertionOffset: 1,
              selection: TextSelection.collapsed(
                offset: 2,
                affinity: TextAffinity.downstream,
              ),
              composing: TextRange(start: -1, end: -1),
            ),
            TextEditingDeltaInsertion(
              oldText: '. ',
              textInserted: '쇼',
              insertionOffset: 2,
              selection: TextSelection.collapsed(
                offset: 3,
                affinity: TextAffinity.downstream,
              ),
              composing: TextRange(start: -1, end: -1),
            )
          ], getter: imeClientGetter);

          // Ensure text and selection were updated.
          expect(SuperEditorInspector.findTextInComponent('1').toPlainText(), '쇼');
          expect(
            SuperEditorInspector.findDocumentSelection(),
            selectionEquivalentTo(
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 1),
                ),
              ),
            ),
          );
        });
      });

      group('on iPhone 15 (iOS 17.5)', () {
        testWidgetsOnIos('ignores keyboard suggestions when pressing the newline button', (tester) async {
          final testContext = await tester //
              .createDocument()
              .withSingleEmptyParagraph()
              .withInputSource(TextInputSource.ime)
              .pump();

          // Place the caret at the start of the paragraph.
          await tester.placeCaretInParagraph('1', 0);

          // Type some text.
          await tester.typeImeText('run tom');

          // Press the new line button.
          await tester.testTextInput.receiveAction(TextInputAction.newline);

          // Simulate the IME sending a delta replacing "tom" with "Tom".
          // At this point, we already added a new paragraph to the document,
          // so these text ranges are invalid for us.
          await tester.ime.sendDeltas([
            const TextEditingDeltaReplacement(
              oldText: '. Run tom',
              replacementText: 'Tom',
              replacedRange: TextRange(start: 6, end: 9),
              selection: TextSelection.collapsed(offset: 9),
              composing: TextRange(start: -1, end: -1),
            ),
          ], getter: imeClientGetter);

          await tester.ime.sendDeltas([
            const TextEditingDeltaInsertion(
              oldText: '. Run Tom',
              textInserted: '\n',
              insertionOffset: 9,
              selection: TextSelection.collapsed(
                offset: 10,
                affinity: TextAffinity.downstream,
              ),
              composing: TextRange(start: -1, end: -1),
            ),
          ], getter: imeClientGetter);
          await tester.pump();

          final document = testContext.document;

          // Ensure the replacement was ignored and a new empty node was added.
          expect(document.nodeCount, 2);
          expect((document.getNodeAt(0)! as TextNode).text.toPlainText(), 'run tom');
          expect((document.getNodeAt(1)! as TextNode).text.toPlainText(), '');
        });
      });
    });
  });
}