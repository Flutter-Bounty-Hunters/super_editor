import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../test_runners.dart';

void main() {
  group('SuperEditor copy and paste > ', () {
    testWidgetsOnApple('pastes within a paragraph', (tester) async {
      await tester //
          .createDocument()
          .withSingleEmptyParagraph()
          .withInputSource(TextInputSource.ime)
          .pump();

      final doc = SuperEditorInspector.findDocument()!;

      // Place the caret at the beginning of the empty document and
      // add some text to give us a non-empty paragraph.
      await tester.placeCaretInParagraph(doc.first.id, 0);
      await tester.typeImeText("Pasted text: ");

      // Paste text into the paragraph.
      tester
        ..simulateClipboard()
        ..setSimulatedClipboardContent("This was pasted here");
      await tester.pressCmdV();

      // Ensure that the text was pasted into the paragraph.
      final nodeId = doc.first.id;
      expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), "Pasted text: This was pasted here");
    });

    testWidgetsOnApple('pastes within a list item', (tester) async {
      await tester //
          .createDocument()
          .fromMarkdown(" * Pasted text:")
          .withInputSource(TextInputSource.ime)
          .pump();

      final doc = SuperEditorInspector.findDocument()!;

      // Place the caret at the end of the list item.
      await tester.placeCaretInParagraph(doc.first.id, 12);
      await tester.typeImeText(" "); // <- manually add a space because Markdown strips it

      // Paste text into the paragraph.
      tester
        ..simulateClipboard()
        ..setSimulatedClipboardContent("This was pasted here");
      await tester.pressCmdV();

      // Ensure that the text was pasted into the paragraph.
      final nodeId = doc.first.id;
      expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), "Pasted text: This was pasted here");
    });

    testAllInputsOnDesktop('pastes multiple paragraphs', (
      tester, {
      required TextInputSource inputSource,
    }) async {
      final testContext = await tester //
          .createDocument()
          .withSingleEmptyParagraph()
          .withInputSource(inputSource)
          .pump();

      // Place the caret at the empty paragraph.
      await tester.placeCaretInParagraph('1', 0);

      // Simulate pasting multiple lines.
      tester
        ..simulateClipboard()
        ..setSimulatedClipboardContent('''This is a paragraph
This is a second paragraph
This is the third paragraph''');
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        await tester.pressCmdV();
      } else {
        await tester.pressCtlV();
      }

      // Ensure three paragraphs were created.
      final doc = testContext.document;
      expect(doc.nodeCount, 3);
      expect((doc.getNodeAt(0)! as ParagraphNode).text.toPlainText(), 'This is a paragraph');
      expect((doc.getNodeAt(1)! as ParagraphNode).text.toPlainText(), 'This is a second paragraph');
      expect((doc.getNodeAt(2)! as ParagraphNode).text.toPlainText(), 'This is the third paragraph');
    });

    testAllInputsOnAllPlatforms("paste retains node IDs when replayed during undo", (
      tester, {
      required TextInputSource inputSource,
    }) async {
      final testContext = await tester //
          .createDocument()
          .withSingleEmptyParagraph()
          .withInputSource(inputSource)
          .pump();

      // Place the caret at the empty paragraph.
      await tester.placeCaretInParagraph('1', 0);

      // Simulate pasting multiple lines.
      tester
        ..simulateClipboard()
        ..setSimulatedClipboardContent('''This is a paragraph
This is a second paragraph
This is the third paragraph''');
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        await tester.pressCmdV();
      } else {
        await tester.pressCtlV();
      }

      // Gather the current node IDs in the document.
      final originalNodeIds = testContext.document.toList().map((node) => node.id).toList();

      // Pump enough time to separate the next text entry from the paste action.
      await tester.pump(const Duration(seconds: 2));

      // Type some text.
      switch (inputSource) {
        case TextInputSource.keyboard:
          await tester.pressKey(LogicalKeyboardKey.keyA);
        case TextInputSource.ime:
          await tester.typeImeText("a");
      }

      // Undo the text insertion (this causes the paste command re-run).
      testContext.editor.undo();

      // Ensure that the node IDs in the document didn't change after re-running
      // the paste command.
      final newNodeIds = testContext.document.toList().map((node) => node.id).toList();
      expect(newNodeIds, originalNodeIds);
    });

    testWidgetsOnMac("paste command content does not mutate when document changes", (tester) async {
      final testContext = await tester //
          .createDocument()
          .withSingleEmptyParagraph()
          .enableHistory(true)
          .pump();

      // Place the caret at the empty paragraph.
      await tester.placeCaretInParagraph('1', 0);

      // Simulate pasting multiple lines.
      tester
        ..simulateClipboard()
        ..setSimulatedClipboardContent('''This is a paragraph
This is a second paragraph
This is the third paragraph''');
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        await tester.pressCmdV();
      } else {
        await tester.pressCtlV();
      }

      // Pump enough time to separate the next text entry from the paste action.
      await tester.pump(const Duration(seconds: 2));
      await tester.typeImeText("a");

      // Ensure that the "a" was inserted at the end of the final pasted paragraph.
      expect(
        (testContext.document.last as TextNode).text.toPlainText(),
        "This is the third paragrapha",
      );

      // Run undo.
      testContext.editor.undo();

      // After undo, ensure that we no longer have the inserted "a".
      //
      // The undo operation works by replaying earlier commands, such as the paste command.
      // The paste command internally stores the content that it inserted. This test ensures
      // that the paste command's internal content wasn't mutated when we inserted the "a"
      // into the document. Such mutation was part of bug https://github.com/superlistapp/super_editor/issues/2173
      expect(
        (testContext.document.last as TextNode).text.toPlainText(),
        "This is the third paragraph",
      );
    });
  });
}
