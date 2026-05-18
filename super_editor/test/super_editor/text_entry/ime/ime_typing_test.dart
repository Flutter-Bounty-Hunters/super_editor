import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../../../test_runners.dart';

void main() {
  group('IME input > typing >', () {
    group('types characters >', () {
      testWidgetsOnAllPlatforms('at the beginning of existing text', (tester) async {
        final document = MutableDocument(
          nodes: [
            ParagraphNode(id: "1", text: AttributedText("<- text here")),
          ],
        );

        await tester //
            .createDocument()
            .withCustomContent(document)
            .withInputSource(TextInputSource.ime)
            .pump();

        // Place caret at the beginning of the paragraph content.
        await tester.placeCaretInParagraph("1", 0);

        // Type some text.
        await tester.typeImeText("Hello");

        // Ensure the text was typed.
        expect((document.first as ParagraphNode).text.toPlainText(), "Hello<- text here");
      });

      testWidgetsOnAllPlatforms('in the middle of existing text', (tester) async {
        final document = MutableDocument(
          nodes: [
            ParagraphNode(id: "1", text: AttributedText("text here -><---")),
          ],
        );

        await tester //
            .createDocument()
            .withCustomContent(document)
            .withInputSource(TextInputSource.ime)
            .pump();

        // Place caret at the beginning of the paragraph content.
        await tester.placeCaretInParagraph("1", 12);

        // Type some text.
        await tester.typeImeText("Hello");

        // Ensure the text was typed.
        expect((document.first as ParagraphNode).text.toPlainText(), "text here ->Hello<---");
      });

      testWidgetsOnAllPlatforms('at the end of existing text', (tester) async {
        final document = MutableDocument(
          nodes: [
            ParagraphNode(id: "1", text: AttributedText("text here ->")),
          ],
        );

        await tester //
            .createDocument()
            .withCustomContent(document)
            .withInputSource(TextInputSource.ime)
            .pump();

        // Place caret at the beginning of the paragraph content.
        await tester.placeCaretInParagraph("1", 12);

        // Type some text.
        await tester.typeImeText("Hello");

        // Ensure the text was typed.
        expect((document.first as ParagraphNode).text.toPlainText(), "text here ->Hello");
      });

      test('can handle an auto-inserted period', () {
        // On iOS, adding 2 spaces causes the two spaces to be replaced by a
        // period and a space. This test applies the same type and order of deltas
        // that were observed on iOS.
        //
        // Previously, we had a bug where the period was appearing after the
        // 2nd space, instead of between the two spaces. This test prevents
        // that regression.
        final document = MutableDocument(nodes: [
          ParagraphNode(
            id: "1",
            text: AttributedText("This is a sentence"),
          ),
        ]);
        final composer = MutableDocumentComposer(
          initialSelection: const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 18),
            ),
          ),
        );
        final editor = createDefaultDocumentEditor(document: document, composer: composer);
        final commonOps = CommonEditorOperations(
          editor: editor,
          document: document,
          composer: composer,
          documentLayoutResolver: () => FakeDocumentLayout(),
        );
        final softwareKeyboardHandler = TextDeltasDocumentEditor(
          editor: editor,
          document: document,
          documentLayoutResolver: () => FakeDocumentLayout(),
          selection: composer.selectionNotifier,
          composerPreferences: composer.preferences,
          composingRegion: composer.composingRegion,
          commonOps: commonOps,
          onPerformAction: (_) {},
        );

        softwareKeyboardHandler.applyDeltas([
          const TextEditingDeltaInsertion(
            textInserted: ' ',
            insertionOffset: 20,
            selection: TextSelection.collapsed(offset: 21),
            composing: TextRange(start: -1, end: -1),
            oldText: '. This is a sentence',
          ),
        ]);
        softwareKeyboardHandler.applyDeltas([
          const TextEditingDeltaReplacement(
            oldText: '. This is a sentence ',
            replacementText: '.',
            replacedRange: TextRange(start: 20, end: 21),
            selection: TextSelection.collapsed(offset: 21),
            composing: TextRange(start: -1, end: -1),
          ),
        ]);
        softwareKeyboardHandler.applyDeltas([
          const TextEditingDeltaInsertion(
            textInserted: ' ',
            insertionOffset: 21,
            selection: TextSelection.collapsed(offset: 22),
            composing: TextRange(start: -1, end: -1),
            oldText: '. This is a sentence.',
          ),
        ]);

        expect((document.first as ParagraphNode).text.toPlainText(), "This is a sentence. ");
      });

      testWidgets('can type compound character in an empty paragraph', (tester) async {
        final editContext = await tester //
            .createDocument()
            .withTwoEmptyParagraphs()
            .withInputSource(TextInputSource.ime)
            .withGestureMode(DocumentGestureMode.mouse)
            .autoFocus(true)
            .pump();

        // Start the caret in the 2nd paragraph so that we send a
        // hidden placeholder to the IME to report backspaces.
        await tester.placeCaretInParagraph("2", 0);

        // Send the deltas that should produce a ü.
        //
        // We have to use implementation details to send the simulated IME deltas
        // because Flutter doesn't have any testing tools for IME deltas.
        final imeInteractor = find.byType(SuperEditorImeInteractor).evaluate().first;
        final deltaClient = ((imeInteractor as StatefulElement).state as ImeInputOwner).imeClient;

        // Ensure that the delta client starts with the expected invisible placeholder
        // characters.
        expect(deltaClient.currentTextEditingValue!.text, ". ");
        expect(deltaClient.currentTextEditingValue!.selection, const TextSelection.collapsed(offset: 2));
        expect(deltaClient.currentTextEditingValue!.composing, const TextRange(start: -1, end: -1));

        // Insert the "opt+u" character.
        deltaClient.updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: ". ",
            textInserted: "¨",
            insertionOffset: 2,
            selection: TextSelection.collapsed(offset: 3),
            composing: TextRange(start: 2, end: 3),
          ),
        ]);
        await tester.pumpAndSettle();

        // Ensure that the empty paragraph now reads "¨".
        expect((editContext.document.getNodeAt(1)! as ParagraphNode).text.toPlainText(), "¨");

        // Ensure that the IME still has the invisible characters.
        expect(deltaClient.currentTextEditingValue!.text, ". ¨");
        expect(deltaClient.currentTextEditingValue!.composing, const TextRange(start: 2, end: 3));

        // Insert the "u" character to create the compound character.
        deltaClient.updateEditingValueWithDeltas([
          const TextEditingDeltaReplacement(
            oldText: ". ¨",
            replacementText: "ü",
            replacedRange: TextRange(start: 2, end: 3),
            selection: TextSelection.collapsed(offset: 3),
            composing: TextRange(start: -1, end: -1),
          ),
        ]);

        // We need a final pump and settle to propagate selection changes while we still
        // have access to the document layout. Otherwise, the selection change callback
        // will execute after the end of this test, and the layout isn't available any
        // more.
        // TODO: trace the selection change call stack and adjust it so that we don't need this pump
        await tester.pumpAndSettle();

        // Ensure that the empty paragraph now reads "ü".
        expect((editContext.document.getNodeAt(1)! as ParagraphNode).text.toPlainText(), "ü");
      });
    });

    group('deletion >', () {
      testWidgetsOnWebDesktop('merges paragraphs backspace at the beginning of a paragraph', (tester) async {
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

        // Simulates the user pressing BACKSPACE, which generates a deletion delta.
        // This deletion will cause the two paragraphs to be merged.
        await tester.ime.sendDeltas(
          const [
            TextEditingDeltaNonTextUpdate(
              oldText: '. Paragraph two',
              selection: TextSelection.collapsed(offset: 2),
              composing: TextRange(start: -1, end: -1),
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
      });
    });
  });
}
