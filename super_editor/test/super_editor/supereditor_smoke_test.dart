import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

void main() {
  group("SuperEditor smoke test", () {
    testWidgets("writes a document with multiple types of content", (tester) async {
      // Configure and render an empty document.
      final testDocContext = await tester //
          .createDocument()
          .withSingleEmptyParagraph()
          .forDesktop()
          .withInputSource(TextInputSource.keyboard)
          .pump();

      await tester.placeCaretInParagraph("1", 0);

      // Type the first paragraph.
      await tester.typeKeyboardText("This is the first paragraph of the document.");
      await tester.pressEnter();

      // Type a blockquote.
      await tester.typeKeyboardText("> This is a blockquote.");
      await tester.pressEnter();

      // Type an ordered list.
      await tester.typeKeyboardText("This is an ordered list.");
      await tester.pressEnter();
      await tester.typeKeyboardText("1. item 1");
      await tester.pressEnter();
      await tester.typeKeyboardText("item 2");
      await tester.pressEnter();
      await tester.typeKeyboardText("item 3");

      // Stop ordered list from continuing.
      await tester.pressEnter();
      await tester.pressBackspace();

      // Type an unordered list.
      await tester.typeKeyboardText("This is an unordered list.");
      await tester.pressEnter();
      await tester.typeKeyboardText("* item 1");
      await tester.pressEnter();
      await tester.typeKeyboardText("item 2");
      await tester.pressEnter();
      await tester.typeKeyboardText("item 3");

      // Stop unordered list from continuing.
      await tester.pressEnter();
      await tester.pressBackspace();

      // Generate a horizontal rule.
      await tester.typeKeyboardText("--- ");
      // Note: a blank paragraph is automatically inserted after the HR.

      // Ensure that we've created the document that we think we have.
      expect(
        testDocContext.findEditContext().document,
        documentEquivalentTo(_expectedDocument),
      );
    });
  });
}

final _expectedDocument = MutableDocument(
  nodes: [
    ParagraphNode(id: "1", text: AttributedText("This is the first paragraph of the document.")),
    ParagraphNode(
        id: "2", text: AttributedText("This is a blockquote."), metadata: {'blockType': blockquoteAttribution}),
    ParagraphNode(id: "3", text: AttributedText("This is an ordered list.")),
    ListItemNode.ordered(id: "4", text: AttributedText("item 1")),
    ListItemNode.ordered(id: "5", text: AttributedText("item 2")),
    ListItemNode.ordered(id: "6", text: AttributedText("item 3")),
    ParagraphNode(id: "7", text: AttributedText("This is an unordered list.")),
    ListItemNode.unordered(id: "8", text: AttributedText("item 1")),
    ListItemNode.unordered(id: "9", text: AttributedText("item 2")),
    ListItemNode.unordered(id: "10", text: AttributedText("item 3")),
    HorizontalRuleNode(id: "11"),
    ParagraphNode(id: "12", text: AttributedText("")),
  ],
);
