import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

void main() {
  group('IME input >', () {
    group('Android >', () {
      // Note: Some Android devices report ENTER and BACKSPACE as hardware keys. Other Android
      //       devices report "\n" insertion and deletion IME deltas, instead.
      group('on Xiaomi Redmi tablet (Android 12 SP1A)', () {
        testWidgetsOnAndroid('applies list of deltas when inserting new lines', (tester) async {
          // This test simulates inserting a line break in the middle of the text,
          // followed by a non-text delta placing the selection/composing region on the new line.
          //
          // This test runs only on Android, because we only map a \n insertion to a new line on Android.

          await tester //
              .createDocument()
              .withSingleEmptyParagraph()
              .withInputSource(TextInputSource.ime)
              .pump();

          // Place caret at the start of the document.
          await tester.placeCaretInParagraph('1', 0);

          // Send initial delta.
          await tester.ime.sendDeltas(
            const [
              TextEditingDeltaInsertion(
                oldText: '. ',
                textInserted: 'Before the line break new line',
                insertionOffset: 2,
                selection: TextSelection.collapsed(offset: 32),
                composing: TextRange(start: 2, end: 32),
              )
            ],
            getter: imeClientGetter,
          );

          // Place the caret at "Before the line break |new line".
          await tester.placeCaretInParagraph('1', 22);

          // Add a line break and simulate the OS sending a non-text delta to change the composing region.
          //
          // The OS thinks the editing text is "Before the line break \nnew line".
          //
          // With the insertion of the line break, the paragraph will be split into two and
          // our current editing text will be "new line".
          //
          // The OS selection is invalid to us, as our editing text changed.
          await tester.ime.sendDeltas(
            const [
              TextEditingDeltaInsertion(
                oldText: 'Before the line break new line',
                textInserted: '\n',
                insertionOffset: 22,
                selection: TextSelection.collapsed(offset: 23),
                composing: TextRange(start: -1, end: -1),
              ),
              TextEditingDeltaNonTextUpdate(
                oldText: 'Before the line break \nnew line',
                selection: TextSelection.collapsed(offset: 23),
                composing: TextRange(start: -1, end: -1),
              ),
              TextEditingDeltaNonTextUpdate(
                oldText: 'Before the line break \nnew line',
                selection: TextSelection.collapsed(offset: 23),
                composing: TextRange(start: 23, end: 26),
              ),
            ],
            getter: imeClientGetter,
          );

          final doc = SuperEditorInspector.findDocument()!;

          // Ensure the paragraph was split.
          expect(
            (doc.getNodeAt(0)! as ParagraphNode).text.toPlainText(),
            'Before the line break ',
          );

          // Ensure the paragraph was split.
          expect(
            (doc.getNodeAt(1)! as ParagraphNode).text.toPlainText(),
            'new line',
          );

          // Ensure the selection is at the beginning of the second node.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: doc.getNodeAt(1)!.id,
                nodePosition: const TextNodePosition(offset: 0),
              ),
            ),
          );
        });

        testWidgetsOnAndroid('maintains correct selection after merging paragraphs', (tester) async {
          await tester //
              .createDocument()
              .fromMarkdown('''
Paragraph one

Paragraph two
''')
              .withInputSource(TextInputSource.ime)
              .pump();

          final doc = SuperEditorInspector.findDocument()!;

          // Place caret at the start of the second paragraph.
          await tester.placeCaretInParagraph(doc.getNodeAt(1)!.id, 0);

          // Sends the deletion delta followed by non-text deltas.
          //
          // This deletion will cause the two paragraphs to be merged.
          await tester.ime.sendDeltas(
            const [
              TextEditingDeltaNonTextUpdate(
                oldText: '. Paragraph two',
                selection: TextSelection.collapsed(offset: 2),
                composing: TextRange(start: -1, end: -1),
              ),
              TextEditingDeltaNonTextUpdate(
                oldText: 'Paragraph two',
                selection: TextSelection.collapsed(offset: 0),
                composing: TextRange(start: 2, end: 11),
              ),
              TextEditingDeltaDeletion(
                oldText: '. Paragraph two',
                deletedRange: TextRange(start: 1, end: 2),
                selection: TextSelection.collapsed(offset: 1),
                composing: TextRange(start: -1, end: -1),
              ),
            ],
            getter: imeClientGetter,
          );

          // Ensure the paragraph was merged.
          expect(
            (doc.getNodeAt(0)! as ParagraphNode).text.toPlainText(),
            'Paragraph oneParagraph two',
          );

          // Ensure the selection is at "Paragraph one|Paragraph two".
          expect(
            SuperEditorInspector.findDocumentSelection(),
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: doc.getNodeAt(0)!.id,
                nodePosition: const TextNodePosition(offset: 13),
              ),
            ),
          );
        });
      });

      group('on Samsung M51 (Android 12 SP1A)', () {
        testWidgetsOnAndroid('applies keyboard suggestions', (tester) async {
          await tester //
              .createDocument()
              .withSingleEmptyParagraph()
              .withInputSource(TextInputSource.ime)
              .pump();

          // Place the caret at the start of the paragraph.
          await tester.placeCaretInParagraph('1', 0);

          // Start typing the word "Anonymous" with typos.
          await tester.typeImeText('Anonimoi');

          // Simulate the user accepting a suggestion.
          // The IME replaces the word and inserts a space after it.
          await tester.ime.sendDeltas(const [
            TextEditingDeltaNonTextUpdate(
              oldText: '. Anonimoi',
              selection: TextSelection.collapsed(
                offset: 10,
                affinity: TextAffinity.downstream,
              ),
              composing: TextRange(start: 2, end: 10),
            ),
            TextEditingDeltaReplacement(
              oldText: '. Anonimoi',
              replacementText: 'Anonymous',
              replacedRange: TextRange(start: 2, end: 10),
              selection: TextSelection.collapsed(offset: 11, affinity: TextAffinity.downstream),
              composing: TextRange(start: -1, end: -1),
            ),
            TextEditingDeltaInsertion(
              oldText: '. Anonymous',
              textInserted: ' ',
              insertionOffset: 11,
              selection: TextSelection.collapsed(
                offset: 12,
                affinity: TextAffinity.downstream,
              ),
              composing: TextRange(start: -1, end: -1),
            )
          ], getter: imeClientGetter);

          expect(
            SuperEditorInspector.findTextInComponent('1').toPlainText(),
            'Anonymous ',
          );
        });
      });

      group('on Samsung M51 (Android 12 SP1A) with GBoard', () {
        testWidgetsOnAndroid('applies keyboard suggestions', (tester) async {
          await tester //
              .createDocument()
              .withSingleEmptyParagraph()
              .withInputSource(TextInputSource.ime)
              .pump();

          // Place the caret at the start of the paragraph.
          await tester.placeCaretInParagraph('1', 0);

          // Start typing the word "Anonymous" with typos.
          await tester.typeImeText('Anonimoi');

          // Simulate the user accepting a suggestion.
          // The IME deletes the substring "imoi" and inserts "ymous ".
          await tester.ime.sendDeltas(const [
            TextEditingDeltaDeletion(
              oldText: '. Anonimoi',
              deletedRange: TextRange(start: 6, end: 10),
              selection: TextSelection.collapsed(
                offset: 4,
                affinity: TextAffinity.downstream,
              ),
              composing: TextRange(start: -1, end: -1),
            ),
            TextEditingDeltaInsertion(
              oldText: '. Anon',
              textInserted: 'ymous ',
              insertionOffset: 6,
              selection: TextSelection.collapsed(
                offset: 12,
                affinity: TextAffinity.downstream,
              ),
              composing: TextRange(start: -1, end: -1),
            ),
          ], getter: imeClientGetter);

          expect(
            SuperEditorInspector.findTextInComponent('1').toPlainText(),
            'Anonymous ',
          );
        });
      });

      group('on Samsung', () {
        testWidgetsOnAndroid('handles out of order newline followed by delta suggestion application', (tester) async {
          await tester //
              .createDocument()
              .withSingleEmptyParagraph()
              .withInputSource(TextInputSource.ime)
              .pump();

          // Place the caret at the start of the paragraph.
          await tester.placeCaretInParagraph('1', 0);

          // Start typing the word "Anonymous" with typos.
          await tester.typeImeText('Anonimoi');

          // Simulate the user pressing "newline", which on Samsung results in reporting
          // the ENTER hardware key, followed by the suggestion deltas. Notice that these
          // two events are in the wrong order!
          await tester.pressEnter();

          await tester.ime.sendDeltas(const [
            TextEditingDeltaNonTextUpdate(
              oldText: '. Anonimoi',
              selection: TextSelection.collapsed(
                offset: 10,
                affinity: TextAffinity.downstream,
              ),
              composing: TextRange(start: 2, end: 10),
            ),
            TextEditingDeltaNonTextUpdate(
              oldText: '. Anonimoi',
              selection: TextSelection.collapsed(
                offset: 10,
                affinity: TextAffinity.downstream,
              ),
              composing: TextRange(start: 2, end: 10),
            ),
            TextEditingDeltaReplacement(
              oldText: '. Anonimoi',
              replacementText: 'Anonymous',
              replacedRange: TextRange(start: 2, end: 10),
              selection: TextSelection.collapsed(offset: 11, affinity: TextAffinity.downstream),
              composing: TextRange(start: -1, end: -1),
            ),
          ], getter: imeClientGetter);

          final document = SuperEditorInspector.findDocument()!;
          expect(document.length, 2);
          // Note: We expect the mis-spelled word to remain because we couldn't apply
          //       the suggestion due to receiving events in the wrong order.
          expect((document.first as TextNode).text.toPlainText(), 'Anonimoi');
          expect((document.last as TextNode).text.toPlainText(), '');
        });
      });

      group('GBoard >', () {
        testWidgetsOnAndroid('can insert newline into empty paragraph', (tester) async {
          // Verifies fix for GBoard empty paragraph newline bug:
          // https://github.com/Flutter-Bounty-Hunters/super_editor/issues/2981

          await tester //
              .createDocument()
              .withSingleEmptyParagraph()
              .withInputSource(TextInputSource.ime)
              .pump();

          // Place the caret at the start of the paragraph.
          await tester.placeCaretInParagraph('1', 0);

          // Simulate press of the newline button.
          //
          // On GBoard this is reported as the ENTER key, followed by corrective dangling
          // space removal deltas. Technically those deltas are sent out of order. This is
          // because the empty paragraph is encoded as ". ".
          await tester.pressEnter();

          await tester.ime.sendDeltas(const [
            // GBoard seems to send a bunch of identical non-text updates.
            TextEditingDeltaNonTextUpdate(
              oldText: '. ',
              selection: TextSelection.collapsed(offset: 2),
              composing: TextRange.empty,
            ),
            TextEditingDeltaNonTextUpdate(
              oldText: '. ',
              selection: TextSelection.collapsed(offset: 2),
              composing: TextRange.empty,
            ),
            TextEditingDeltaNonTextUpdate(
              oldText: '. ',
              selection: TextSelection.collapsed(offset: 2),
              composing: TextRange.empty,
            ),
            TextEditingDeltaNonTextUpdate(
              oldText: '. ',
              selection: TextSelection.collapsed(offset: 2),
              composing: TextRange.empty,
            ),
            // After the non-text updates, there's a deletion delta that tries to remove the space.
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

          final document = SuperEditorInspector.findDocument();
          expect(document, isNotNull);
          expect(document!.length, 2);

          expect(document.first, isA<ParagraphNode>());
          expect((document.first as TextNode).text.toPlainText(), "");

          expect(document.last, isA<ParagraphNode>());
          expect((document.last as TextNode).text.toPlainText(), "");
        });
      });
    });
  });
}
