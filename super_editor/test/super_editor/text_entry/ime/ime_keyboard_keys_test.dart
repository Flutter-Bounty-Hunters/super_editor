import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:super_editor/super_test.dart';

import '../../../test_runners.dart';

void main() {
  group('IME input > hardware keys >', () {
    group('moves caret', () {
      testWidgetsOnDesktopAndWeb('to end of previous node when LEFT_ARROW is pressed at the beginning of a paragraph',
          (tester) async {
        await tester
            .createDocument() //
            .withLongDoc()
            .withInputSource(inputSourceVariant.currentValue!)
            .pump();

        // Place the caret at the beginning of the second paragraph.
        await tester.placeCaretInParagraph('2', 0);

        // Press left arrow to move to the previous node.
        await tester.pressLeftArrow();

        // Ensure the caret sits at the end of the first paragraph.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 439),
            ),
          ),
        );
      }, variant: inputSourceVariant);

      testWidgetsOnDesktopAndWeb('to the beginning of next node when RIGHT_ARROW is pressed at the end of a paragraph',
          (tester) async {
        await tester
            .createDocument() //
            .withLongDoc()
            .withInputSource(inputSourceVariant.currentValue!)
            .pump();

        // Place the caret at the end of the first paragraph.
        await tester.placeCaretInParagraph('1', 439);

        // Press right arrow to move to the next node.
        await tester.pressRightArrow();

        // Ensure the caret sits at the beginning of the second paragraph.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: '2',
              nodePosition: TextNodePosition(offset: 0),
            ),
          ),
        );
      }, variant: inputSourceVariant);
    });

    testWidgetsOnWebDesktop('inside a CustomScrollView > inserts space instead of scrolling with SPACEBAR',
        (tester) async {
      final testContext = await tester //
          .createDocument()
          .withSingleEmptyParagraph()
          .insideCustomScrollView()
          .withInputSource(TextInputSource.ime)
          .pump();

      final nodeId = testContext.document.first.id;

      // Place the caret at the beginning of the paragraph.
      await tester.placeCaretInParagraph(nodeId, 0);

      // Press space to insert a space character.
      await _typeSpaceAdaptive(tester);

      // Ensure the space character was inserted.
      expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), ' ');
    });

    testWidgetsOnWebDesktop('deletes a character with backspace', (tester) async {
      final testContext = await tester //
          .createDocument()
          .fromMarkdown('This is a paragraph')
          .withInputSource(TextInputSource.ime)
          .pump();

      final nodeId = testContext.document.first.id;

      // Place the caret at the end of the paragraph.
      await tester.placeCaretInParagraph(nodeId, 19);

      // Simulate the user pressing backspace.
      //
      // On web, this generates both a key event and a deletion delta.
      await tester.pressBackspace();
      await tester.ime.sendDeltas(
        [
          const TextEditingDeltaDeletion(
            oldText: '. This is a paragraph',
            deletedRange: TextRange(start: 20, end: 21),
            selection: TextSelection.collapsed(offset: 20),
            composing: TextRange.empty,
          ),
        ],
        getter: imeClientGetter,
      );

      // Ensure the last character was deleted.
      expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), 'This is a paragrap');
    });
  });
}

/// Simulates pressing the SPACE key.
///
/// First, this method simulates pressing the SPACE key on a physical keyboard. If that key event goes unhandled
/// then this method generates an insertion delta of " ".
///
// TODO: extract this to the flutter_test_robots package.
Future<void> _typeSpaceAdaptive(WidgetTester tester) async {
  final handled = await tester.sendKeyEvent(LogicalKeyboardKey.space);

  if (handled) {
    await tester.pumpAndSettle();
    return;
  }

  await tester.typeImeText(' ');
}
