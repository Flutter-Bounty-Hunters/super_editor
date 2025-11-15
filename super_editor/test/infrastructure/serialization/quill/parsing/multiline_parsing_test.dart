import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group("Delta document parsing > test > multiline >", () {
    test("parses inline newline characters into multiple document nodes", () {
      final document = parseQuillDeltaDocument(
        {
          "ops": [
            {"insert": "\nLine one\nLine two\nLine three\nLine four\n\n"}
          ],
        },
      );

      expect((document.getNodeAt(0)! as TextNode).text.toPlainText(), "");
      expect((document.getNodeAt(1)! as TextNode).text.toPlainText(), "Line one");
      expect((document.getNodeAt(2)! as TextNode).text.toPlainText(), "Line two");
      expect((document.getNodeAt(3)! as TextNode).text.toPlainText(), "Line three");
      expect((document.getNodeAt(4)! as TextNode).text.toPlainText(), "Line four");
      expect((document.getNodeAt(5)! as TextNode).text.toPlainText(), "");
      expect((document.getNodeAt(6)! as TextNode).text.toPlainText(), "");

      // A note on the length of the document. If this document is placed in a
      // Quill editor, there will only be 6 lines the user can edit. This seems
      // like it's probably a part of Quill specified behavior. I think that
      // because every Quill document must always end with a newline, the final
      // newline of a document is ignored by a Quill editor. But in our case
      // we parse every newline, including the trailing newline, so the length
      // of this document is 7. If that's a problem, we can make the parser
      // more intelligent about this later.
      expect(document.nodeCount, 7);
    });

    group("block merging >", () {
      group("default merging >", () {
        test("merges consecutive blockquote", () {
          final document = parseQuillDeltaDocument(
            {
              "ops": [
                {"insert": "This is a blockquote"},
                {
                  "attributes": {
                    "blockquote": {"blockquote": true}
                  },
                  "insert": "\n"
                },
                {"insert": "This is line two"},
                {
                  "attributes": {
                    "blockquote": {"blockquote": true}
                  },
                  "insert": "\n"
                },
              ],
            },
          );

          expect(
            (document.getNodeAt(0)! as ParagraphNode).text.toPlainText(),
            "This is a blockquote\nThis is line two",
          );
          expect((document.getNodeAt(0)! as ParagraphNode).getMetadataValue("blockType"), blockquoteAttribution);
          expect((document.getNodeAt(1)! as ParagraphNode).text.toPlainText(), "");
          expect(document.nodeCount, 2);
        });

        test("does not merge blockquotes separated by an unstyled insert", () {
          final document = parseQuillDeltaDocument(
            {
              "ops": [
                {"insert": "This is a blockquote"},
                {
                  "attributes": {
                    "blockquote": {"blockquote": true}
                  },
                  "insert": "\n"
                },
                {"insert": "\n"},
                {"insert": "This is line two"},
                {
                  "attributes": {
                    "blockquote": {"blockquote": true}
                  },
                  "insert": "\n"
                },
              ],
            },
          );

          expect(
            (document.getNodeAt(0)! as ParagraphNode).text.toPlainText(),
            "This is a blockquote",
          );
          expect(
            (document.getNodeAt(1)! as ParagraphNode).text.toPlainText(),
            "",
          );
          expect(
            (document.getNodeAt(2)! as ParagraphNode).text.toPlainText(),
            "This is line two",
          );
          expect((document.getNodeAt(0)! as ParagraphNode).getMetadataValue("blockType"), blockquoteAttribution);
          expect((document.getNodeAt(1)! as ParagraphNode).text.toPlainText(), "");
          expect((document.getNodeAt(2)! as ParagraphNode).getMetadataValue("blockType"), blockquoteAttribution);
          expect(document.nodeCount, 4);
        });

        test("merges consecutive code blocks", () {
          // Notice that Delta encodes each line of a code block as a separate attributed
          // delta. But when a Quill editor renders the code block, it's rendered as one
          // block. This test ensures that Super Editor accumulates back-to-back code
          // lines into a single code node.
          final document = parseQuillDeltaDocument(
            {
              "ops": [
                {"insert": "This is a code block"},
                {
                  "attributes": {"code-block": "plain"},
                  "insert": "\n"
                },
                {"insert": "This is line two"},
                {
                  "attributes": {"code-block": "plain"},
                  "insert": "\n"
                },
                {"insert": "This is line three"},
                {
                  "attributes": {"code-block": "plain"},
                  "insert": "\n"
                },
              ],
            },
          );

          expect(
            (document.getNodeAt(0)! as ParagraphNode).text.toPlainText(),
            "This is a code block\nThis is line two\nThis is line three",
          );
          expect((document.getNodeAt(0)! as ParagraphNode).getMetadataValue("blockType"), codeAttribution);
          expect((document.getNodeAt(1)! as ParagraphNode).text.toPlainText(), "");
          expect(document.nodeCount, 2);
        });

        test("does not merge code blocks separated by an unstyled insert", () {
          final document = parseQuillDeltaDocument(
            {
              "ops": [
                {"insert": "This is a code block"},
                {
                  "attributes": {"code-block": "plain"},
                  "insert": "\n"
                },
                {"insert": "\n"},
                {"insert": "This is line two"},
                {
                  "attributes": {"code-block": "plain"},
                  "insert": "\n"
                },
              ],
            },
          );

          expect(
            (document.getNodeAt(0)! as ParagraphNode).text.toPlainText(),
            "This is a code block",
          );
          expect(
            (document.getNodeAt(1)! as ParagraphNode).text.toPlainText(),
            "",
          );
          expect(
            (document.getNodeAt(2)! as ParagraphNode).text.toPlainText(),
            "This is line two",
          );
          expect((document.getNodeAt(0)! as ParagraphNode).getMetadataValue("blockType"), codeAttribution);
          expect((document.getNodeAt(1)! as ParagraphNode).text.toPlainText(), "");
          expect((document.getNodeAt(2)! as ParagraphNode).getMetadataValue("blockType"), codeAttribution);
          expect(document.nodeCount, 4);
        });
      });
    });
  });
}
