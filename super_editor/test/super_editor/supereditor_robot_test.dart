import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

void main() {
  group("SuperEditor robot", () {
    testWidgetsOnAllPlatforms("taps to place caret in empty paragraph", (tester) async {
      // Configure and render a document.
      await tester //
          .createDocument()
          .withSingleEmptyParagraph()
          .forDesktop()
          .pump();

      // Ensure that the document doesn't have a selection.
      expect(SuperEditorInspector.findDocumentSelection(), null);

      // Tap to place the caret at the beginning of the first paragraph.
      await tester.placeCaretInParagraph("1", 0);

      // Ensure that the document has the expected text caret selection.
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

    testWidgetsOnAllPlatforms("taps to place caret before first character", (tester) async {
      // Configure and render a document.
      await tester //
          .createDocument()
          .withSingleParagraph()
          .forDesktop()
          .pump();

      // Ensure that the document doesn't have a selection.
      expect(SuperEditorInspector.findDocumentSelection(), null);

      // Tap to place the caret at the beginning of the first paragraph.
      await tester.placeCaretInParagraph("1", 0);

      // Ensure that the document has the expected text caret selection.
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

    testWidgetsOnAllPlatforms("taps to place caret in middle of paragraph", (tester) async {
      // Configure and render a document.
      await tester //
          .createDocument()
          .withSingleParagraph()
          .forDesktop()
          .pump();

      // Ensure that the document doesn't have a selection.
      expect(SuperEditorInspector.findDocumentSelection(), null);

      // Tap to place the caret in the first paragraph.
      await tester.placeCaretInParagraph("1", 10);

      // Ensure that the document has the expected text caret selection.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "1",
            nodePosition: TextNodePosition(offset: 10),
          ),
        ),
      );
    });

    testWidgetsOnAllPlatforms("taps to place caret at a non-linebreak offset with different affinities",
        (tester) async {
      // Configure and render a document.
      await tester //
          .createDocument()
          .withSingleParagraph()
          .pump();

      // Ensure that the document doesn't have a selection.
      expect(SuperEditorInspector.findDocumentSelection(), null);

      // Tap to place the caret in the first paragraph with a downstream affinity. This assumes that the paragraph
      // does not wrap at the second character of the paragraph, which should be true for any reasonable display size.
      await tester.placeCaretInParagraph("1", 1, affinity: TextAffinity.downstream);
      // Ensure the document has the correct selection, including affinity;
      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: '1',
            nodePosition: TextNodePosition(
              offset: 1,
              affinity: TextAffinity.downstream,
            ),
          ),
        ),
      );

      // Tap on another character, because tapping on the same character shows the toolbar
      // instead of changing the selection.
      await tester.placeCaretInParagraph("1", 5);

      // Place the caret at the same offset as before but with an upstream affinity.
      await tester.placeCaretInParagraph("1", 1, affinity: TextAffinity.upstream);
      // Ensure the document has the correct selection, including affinity;
      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: '1',
            nodePosition: TextNodePosition(
              offset: 1,
              affinity: TextAffinity.upstream,
            ),
          ),
        ),
      );
    });

    testWidgetsOnAllPlatforms("taps to place caret after last character", (tester) async {
      // Configure and render a document.
      await tester //
          .createDocument()
          .withSingleParagraph()
          .forDesktop()
          .pump();

      // Ensure that the document doesn't have a selection.
      expect(SuperEditorInspector.findDocumentSelection(), null);

      // Tap to place the caret at the end of the first paragraph.
      const paragraphLength = 445;
      await tester.placeCaretInParagraph("1", paragraphLength);

      // Ensure that the document has the expected text caret selection.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "1",
            nodePosition: TextNodePosition(offset: paragraphLength, affinity: TextAffinity.upstream),
          ),
        ),
      );
    });

    testWidgetsOnDesktop("enters text with hardware keyboard", (tester) async {
      // Configure and render a document.
      await tester //
          .createDocument()
          .withSingleEmptyParagraph()
          .forDesktop()
          .withInputSource(TextInputSource.keyboard)
          .autoFocus(true)
          .pump();

      // Tap to place the caret in the first paragraph.
      await tester.placeCaretInParagraph("1", 0);

      // Type some text by simulating hardware keyboard key presses.
      await tester.typeKeyboardText("Hello, world!");

      // Verify that SuperEditor displays the text we typed.
      expect(SuperEditorInspector.findTextInComponent("1").toPlainText(), "Hello, world!");
    });

    testWidgetsOnDesktop("enters text with hardware keyboard with multiple taps", (tester) async {
      await tester //
          .createDocument()
          .withSingleEmptyParagraph()
          .withInputSource(TextInputSource.keyboard)
          .pump();

      // Tap to place the caret in the first paragraph.
      await tester.placeCaretInParagraph("1", 0);

      // Type some text by simulating hardware keyboard key presses.
      await tester.typeKeyboardText("Hello, world!");

      // Place the caret at the end of the paragraph.
      await tester.placeCaretInParagraph("1", 13);

      // Type another text.
      await tester.typeKeyboardText("ABC");

      // Ensure that the text is inserted.
      expect(SuperEditorInspector.findTextInComponent("1").toPlainText(), "Hello, world!ABC");
    });

    testWidgetsOnDesktop("enters text with IME keyboard", (tester) async {
      // Configure and render a document.
      await tester //
          .createDocument()
          .withSingleEmptyParagraph()
          .forDesktop()
          .withInputSource(TextInputSource.ime)
          .autoFocus(true)
          .pump();

      // Tap to place the caret in the first paragraph.
      await tester.placeCaretInParagraph("1", 0);

      // Type some text by simulating hardware keyboard key presses.
      await tester.typeImeText("Hello, world!");

      // Verify that SuperEditor displays the text we typed.
      expect(SuperEditorInspector.findTextInComponent("1").toPlainText(), "Hello, world!");
    });

    testWidgetsOnDesktop("enters text with IME keyboard with multiple taps", (tester) async {
      await tester //
          .createDocument()
          .withSingleEmptyParagraph()
          .withInputSource(TextInputSource.ime)
          .pump();

      // Tap to place the caret in the first paragraph.
      await tester.placeCaretInParagraph("1", 0);

      // Type some text by simulating IME keyboard key presses.
      await tester.typeImeText("Hello, world!");

      // Place the caret at the end of the paragraph.
      await tester.placeCaretInParagraph("1", 13);

      // Type another text.
      await tester.typeImeText("ABC");

      // Ensure that the text is inserted.
      expect(SuperEditorInspector.findTextInComponent("1").toPlainText(), "Hello, world!ABC");
    });

    testWidgetsOnAllPlatforms("performs back to back taps with hardware keyboard", (tester) async {
      final testContext = await tester //
          .createDocument()
          .fromMarkdown('Hello, world!')
          .withInputSource(TextInputSource.keyboard)
          .pump();

      final nodeId = testContext.document.first.id;

      // Tap to place the caret in the first paragraph.
      await tester.placeCaretInParagraph(nodeId, 0);

      // Place the caret at 'Hello, |world!'.
      await tester.placeCaretInParagraph(nodeId, 7);

      // Type another text.
      await tester.typeKeyboardText("new ");

      // Ensure that the text is inserted.
      expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), "Hello, new world!");
    });

    testWidgetsOnAllPlatforms("performs back to back taps with software keyboard", (tester) async {
      final testContext = await tester //
          .createDocument()
          .fromMarkdown('Hello, world!')
          .withInputSource(TextInputSource.ime)
          .pump();

      final nodeId = testContext.document.first.id;

      // Tap to place the caret in the first paragraph.
      await tester.placeCaretInParagraph(nodeId, 0);

      // Place the caret at 'Hello, |world!'.
      await tester.placeCaretInParagraph(nodeId, 7);

      // Type another text.
      await tester.typeImeText("new ");

      // Ensure that the text is inserted.
      expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), "Hello, new world!");
    });
  });
}
