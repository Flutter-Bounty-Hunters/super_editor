import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

import '../test_documents.dart';

// Useful links:
//  - create a Delta document in the browser: https://quilljs.com/playground/snow
//  - list of supported formats (bold, italics, header, etc): https://quilljs.com/docs/formats

void main() {
  group("Delta document parsing >", () {
    group("text >", () {
      test("plain text followed by block format", () {
        final document = parseQuillDeltaDocument(
          {
            "ops": [
              {"insert": "This is regular text\nThis is a code block"},
              {
                "attributes": {"code-block": "plain"},
                "insert": "\n"
              },
            ],
          },
        );

        expect(
          (document.getNodeAt(0)! as ParagraphNode).text.toPlainText(),
          "This is regular text",
        );
        expect((document.getNodeAt(0)! as ParagraphNode).getMetadataValue("blockType"), paragraphAttribution);
        expect(
          (document.getNodeAt(1)! as ParagraphNode).text.toPlainText(),
          "This is a code block",
        );
        expect((document.getNodeAt(1)! as ParagraphNode).getMetadataValue("blockType"), codeAttribution);
        expect((document.getNodeAt(2)! as ParagraphNode).text.toPlainText(), "");
        expect(document.nodeCount, 3);
      });

      test("all text blocks and styles", () {
        final document = parseQuillDeltaOps(allTextStylesDeltaDocument);

        final nodes = document.iterator..moveNext();
        DocumentNode? node = nodes.current;

        // Check the header.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.toPlainText(), "All Text Styles");

        nodes.moveNext();
        node = nodes.current;

        // Check the paragraph with various formatting.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.toPlainText(),
            "Samples of styles: bold, italics, underline, strikethrough, text color, background color, font change, link");
        expect(
          node.text.getAttributionSpansByFilter((a) => true),
          {
            const AttributionSpan(attribution: boldAttribution, start: 19, end: 22),
            const AttributionSpan(attribution: italicsAttribution, start: 25, end: 31),
            const AttributionSpan(attribution: underlineAttribution, start: 34, end: 42),
            const AttributionSpan(attribution: strikethroughAttribution, start: 45, end: 57),
            const AttributionSpan(attribution: ColorAttribution(Color(0xFFe60000)), start: 60, end: 69),
            const AttributionSpan(attribution: BackgroundColorAttribution(Color(0xFFe60000)), start: 72, end: 87),
            const AttributionSpan(attribution: FontFamilyAttribution("serif"), start: 90, end: 100),
            const AttributionSpan(attribution: LinkAttribution("google.com"), start: 103, end: 106),
          },
        );

        nodes.moveNext();
        node = nodes.current;

        // Blank line.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.toPlainText(), "");

        nodes.moveNext();
        node = nodes.current;

        // Paragraph - left aligned.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.toPlainText(), "Left aligned");
        expect(node.metadata["textAlign"], isNull);

        nodes.moveNext();
        node = nodes.current;

        // Paragraph - center aligned.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.toPlainText(), "Center aligned");
        expect(node.metadata["textAlign"], "center");

        nodes.moveNext();
        node = nodes.current;

        // Paragraph - right aligned.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.toPlainText(), "Right aligned");
        expect(node.metadata["textAlign"], "right");

        nodes.moveNext();
        node = nodes.current;

        // Paragraph - justified.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.toPlainText(), "Justified");
        expect(node.metadata["textAlign"], "justify");

        nodes.moveNext();
        node = nodes.current;

        // Blank line.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.toPlainText(), "");

        nodes.moveNext();
        node = nodes.current;

        // Ordered list items.
        expect(node, isA<ListItemNode>());
        expect((node as ListItemNode).text.toPlainText(), "Ordered item 1");
        expect(node.type, ListItemType.ordered);
        expect(node.indent, 0);

        nodes.moveNext();
        node = nodes.current;

        expect(node, isA<ListItemNode>());
        expect((node as ListItemNode).text.toPlainText(), "Ordered item 2");
        expect(node.type, ListItemType.ordered);
        expect(node.indent, 0);

        nodes.moveNext();
        node = nodes.current;

        // Blank line.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.toPlainText(), "");

        nodes.moveNext();
        node = nodes.current;

        // Unordered list items.
        expect(node, isA<ListItemNode>());
        expect((node as ListItemNode).text.toPlainText(), "Unordered item 1");
        expect(node.type, ListItemType.unordered);
        expect(node.indent, 0);

        nodes.moveNext();
        node = nodes.current;

        expect(node, isA<ListItemNode>());
        expect((node as ListItemNode).text.toPlainText(), "Unordered item 2");
        expect(node.type, ListItemType.unordered);
        expect(node.indent, 0);

        nodes.moveNext();
        node = nodes.current;

        // Blank line.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.toPlainText(), "");

        nodes.moveNext();
        node = nodes.current;

        // Tasks.
        expect(node, isA<TaskNode>());
        expect((node as TaskNode).text.toPlainText(), "I'm a task that's incomplete");
        expect(node.isComplete, isFalse);

        nodes.moveNext();
        node = nodes.current;

        expect(node, isA<TaskNode>());
        expect((node as TaskNode).text.toPlainText(), "I'm a task that's complete");
        expect(node.isComplete, isTrue);

        nodes.moveNext();
        node = nodes.current;

        // Blank line.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.toPlainText(), "");

        nodes.moveNext();
        node = nodes.current;

        // Indented paragraphs.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.toPlainText(), "I'm an indented paragraph at level 1");
        expect((node as ParagraphNode).indent, 1);

        nodes.moveNext();
        node = nodes.current;

        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.toPlainText(), "I'm a paragraph indented at level 2");
        expect((node as ParagraphNode).indent, 2);

        nodes.moveNext();
        node = nodes.current;

        // Blank line.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.toPlainText(), "");

        nodes.moveNext();
        node = nodes.current;

        // Superscript and subscript.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.toPlainText(), "Some contentThis is a subscript");
        expect(
          node.text.getAttributionSpansByFilter((a) => true),
          {
            const AttributionSpan(attribution: subscriptAttribution, start: 12, end: 30),
          },
        );

        nodes.moveNext();
        node = nodes.current;

        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.toPlainText(), "Some contentThis is a superscript");
        expect(
          node.text.getAttributionSpansByFilter((a) => true),
          {
            const AttributionSpan(attribution: superscriptAttribution, start: 12, end: 32),
          },
        );

        nodes.moveNext();
        node = nodes.current;

        // Blank line.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.toPlainText(), "");

        nodes.moveNext();
        node = nodes.current;

        // Text sizes.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.toPlainText(), "HUGE");
        expect(
          node.text.getAttributionSpansByFilter((a) => true),
          {
            const AttributionSpan(attribution: NamedFontSizeAttribution("huge"), start: 0, end: 3),
          },
        );

        nodes.moveNext();
        node = nodes.current;

        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.toPlainText(), "Large");
        expect(
          node.text.getAttributionSpansByFilter((a) => true),
          {
            const AttributionSpan(attribution: NamedFontSizeAttribution("large"), start: 0, end: 4),
          },
        );

        nodes.moveNext();
        node = nodes.current;

        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.toPlainText(), "small");
        expect(
          node.text.getAttributionSpansByFilter((a) => true),
          {
            const AttributionSpan(attribution: NamedFontSizeAttribution("small"), start: 0, end: 4),
          },
        );

        nodes.moveNext();
        node = nodes.current;

        // Blank line.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.toPlainText(), "");

        nodes.moveNext();
        node = nodes.current;

        // Blockquote.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.toPlainText(), "This is a blockquote");
        expect(node.metadata["blockType"], blockquoteAttribution);

        nodes.moveNext();
        node = nodes.current;

        // Blank line.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.toPlainText(), "");

        nodes.moveNext();
        node = nodes.current;

        // Code block - with multiple lines.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.toPlainText(), "This is a code block\nThat spans two lines.");
        expect(node.metadata["blockType"], codeAttribution);

        nodes.moveNext();
        node = nodes.current;

        // Final newline node.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.toPlainText(), "");

        // No more nodes.
        expect(nodes.moveNext(), isFalse);
      });

      test("overlapping styles", () {
        final document = parseQuillDeltaDocument(
          {
            "ops": [
              {"insert": "This "},
              {
                "attributes": {"bold": true},
                "insert": "paragraph ",
              },
              {
                "attributes": {"italic": true, "bold": true},
                "insert": "has ",
              },
              {
                "attributes": {"underline": true, "italic": true, "bold": true},
                "insert": "some",
              },
              {
                "attributes": {"underline": true, "italic": true},
                "insert": " overlapping",
              },
              {
                "attributes": {"underline": true},
                "insert": " styles",
              },
              {"insert": ".\n"},
            ],
          },
        );

        final paragraph = document.first as ParagraphNode;
        expect(paragraph.text.toPlainText(), "This paragraph has some overlapping styles.");
        expect(
          paragraph.text.getAttributionSpansByFilter((a) => true),
          {
            const AttributionSpan(attribution: boldAttribution, start: 5, end: 22),
            const AttributionSpan(attribution: italicsAttribution, start: 15, end: 34),
            const AttributionSpan(attribution: underlineAttribution, start: 19, end: 41),
          },
        );
      });

      test("gracefully handles unknown inline text format", () {
        final document = parseQuillDeltaOps([
          {"insert": "Paragraph "},
          {
            // A non-existent inline format.
            "attributes": {"unknown": true},
            "insert": "one"
          },
          {"insert": "\nParagraph two\n"},
        ]);

        expect(document.nodeCount, 3);

        expect(document.getNodeAt(0)!, isA<ParagraphNode>());
        expect((document.getNodeAt(0)! as ParagraphNode).text.toPlainText(), "Paragraph one");
        expect(
          (document.getNodeAt(0)! as ParagraphNode).text.getAttributionSpansByFilter((a) => true),
          const <AttributionSpan>{},
        );

        expect(document.getNodeAt(1)!, isA<ParagraphNode>());
        expect((document.getNodeAt(1)! as ParagraphNode).text.toPlainText(), "Paragraph two");

        expect(document.getNodeAt(2)!, isA<ParagraphNode>());
        expect((document.getNodeAt(2)! as ParagraphNode).text.toPlainText(), "");
      });

      test("gracefully handles unknown text block format", () {
        final document = parseQuillDeltaOps([
          {"insert": "Paragraph one"},
          {
            "attributes": {"unknown-name": "unknown-value"},
            "insert": "\n"
          },
          {"insert": "Paragraph two\n"},
        ]);

        expect(document.nodeCount, 3);

        expect(document.getNodeAt(0)!, isA<ParagraphNode>());
        expect((document.getNodeAt(0)! as ParagraphNode).text.toPlainText(), "Paragraph one");
        expect((document.getNodeAt(0)! as ParagraphNode).metadata["blockType"], paragraphAttribution);
        expect(
          (document.getNodeAt(0)! as ParagraphNode).text.getAttributionSpansByFilter((a) => true),
          const <AttributionSpan>{},
        );

        expect(document.getNodeAt(1)!, isA<ParagraphNode>());
        expect((document.getNodeAt(1)! as ParagraphNode).text.toPlainText(), "Paragraph two");

        expect(document.getNodeAt(2)!, isA<ParagraphNode>());
        expect((document.getNodeAt(2)! as ParagraphNode).text.toPlainText(), "");
      });
    });

    group("media >", () {
      test("an image", () {
        final document = parseQuillDeltaOps([
          {"insert": "Paragraph one\n"},
          {
            "insert": {
              "image": "https://quilljs.com/assets/images/icon.png",
            },
          },
          {"insert": "Paragraph two\n"},
        ]);

        final image = document.getNodeAt(1)!;
        expect(image, isA<ImageNode>());
        image as ImageNode;
        expect(image.imageUrl, "https://quilljs.com/assets/images/icon.png");
      });

      // TODO: make it possible to linkify an image (needs added support in SuperEditor).
      test("an image with a link", () {
        final document = parseQuillDeltaOps([
          {"insert": "Paragraph one\n"},
          {
            "insert": {
              "image": "https://quilljs.com/assets/images/icon.png",
            },
            "attributes": {
              "link": "https://quilljs.com",
            },
          },
          {"insert": "Paragraph two\n"},
        ]);

        final image = document.getNodeAt(1)!;
        expect(image, isA<ImageNode>());
        image as ImageNode;
        expect(image.imageUrl, "https://quilljs.com/assets/images/icon.png");
      }, skip: true);

      test("a video", () {
        final document = parseQuillDeltaOps([
          {"insert": "Paragraph one\n"},
          {
            "insert": {
              "video": "https://quilljs.com/assets/media/video.mp4",
            },
          },
          {"insert": "Paragraph two\n"},
        ]);

        final video = document.getNodeAt(1)!;
        expect(video, isA<VideoNode>());
        video as VideoNode;
        expect(video.url, "https://quilljs.com/assets/media/video.mp4");
      });

      test("audio", () {
        final document = parseQuillDeltaOps([
          {"insert": "Paragraph one\n"},
          {
            "insert": {
              "audio": "https://quilljs.com/assets/media/audio.mp3",
            },
          },
          {"insert": "Paragraph two\n"},
        ]);

        final audio = document.getNodeAt(1)!;
        expect(audio, isA<AudioNode>());
        audio as AudioNode;
        expect(audio.url, "https://quilljs.com/assets/media/audio.mp3");
      });

      test("a file", () {
        final document = parseQuillDeltaOps([
          {"insert": "Paragraph one\n"},
          {
            "insert": {
              "file": "https://quilljs.com/assets/media/file.pdf",
            },
          },
          {"insert": "Paragraph two\n"},
        ]);

        final file = document.getNodeAt(1)!;
        expect(file, isA<FileNode>());
        file as FileNode;
        expect(file.url, "https://quilljs.com/assets/media/file.pdf");
      });

      test("gracefully handles unknown media block", () {
        final document = parseQuillDeltaOps([
          {"insert": "Paragraph one\n"},
          {
            "insert": {
              "unknown": "this block type doesn't exist",
            },
          },
          {"insert": "Paragraph two\n"},
        ]);

        expect(document.nodeCount, 3);

        expect(document.getNodeAt(0)!, isA<ParagraphNode>());
        expect((document.getNodeAt(0)! as ParagraphNode).text.toPlainText(), "Paragraph one");

        expect(document.getNodeAt(1)!, isA<ParagraphNode>());
        expect((document.getNodeAt(1)! as ParagraphNode).text.toPlainText(), "Paragraph two");

        expect(document.getNodeAt(2)!, isA<ParagraphNode>());
        expect((document.getNodeAt(2)! as ParagraphNode).text.toPlainText(), "");
      });
    });

    group("custom parsers >", () {
      test("works with ambiguous formats", () {
        // Consider the standard Delta list item format:
        // {
        //   "list": "ordered"
        // }
        //
        // We want to ensure that an ambiguous custom format is respected
        // without issue, e.g.,
        // {
        //   "list": {
        //     "list": "ordered"
        //   }
        // }
        parseQuillDeltaOps([
          {"insert": "Paragraph one"},
          {
            "attributes": {
              "header": {
                "header": 1,
              },
            },
            "insert": "\n"
          },
          {"insert": "Paragraph two"},
          {
            "attributes": {
              "blockquote": {
                "blockquote": true,
              },
            },
            "insert": "\n"
          },
          {"insert": "Paragraph three"},
          {
            "attributes": {
              "code-block": {
                "code-block": "dart",
              },
            },
            "insert": "\n"
          },
          {"insert": "Paragraph four"},
          {
            "attributes": {
              "list": {
                "list": "ordered",
              },
            },
            "insert": "\n"
          },
          {"insert": "Paragraph five"},
          {
            "attributes": {
              "align": {
                "align": "left",
              },
            },
            "insert": "\n"
          },
          {"insert": "Paragraph six\n"},
        ]);

        // If we get here without an exception, the test passes. This means that
        // the standard
      });

      test("defers to higher priority ambiguous format", () {
        // Goal of test: when a custom parser has a format that's ambiguous as compared to
        // a standard format, the custom parser is used instead of the standard parser,
        // when the custom parser is higher in the parser list.
        final document = parseQuillDeltaOps([
          {"insert": "Paragraph one"},
          {
            "attributes": {
              "list": {
                "list": "ordered",
              },
            },
            "insert": "\n"
          },
          {"insert": "Paragraph two\n"},
        ], blockFormats: [
          const _CustomListItemBlockFormat(),
          ...defaultBlockFormats,
        ]);

        expect(document.first, isA<TaskNode>());
      });

      test("can parse inline embeds", () {
        final document = parseQuillDeltaOps([
          {"insert": "Have you heard about inline embeds, "},
          {
            "insert": {
              "tag": {
                "type": "user",
                "userId": "123456",
                "text": "@John Smith",
              },
            },
          },
          {"insert": "?\n"},
        ], inlineEmbedFormats: [
          const _UserTagEmbedParser(),
        ]);

        final text = (document.first as ParagraphNode).text;
        expect(text.toPlainText(), "Have you heard about inline embeds, @John Smith?");
        expect(
          text.spans,
          AttributedSpans(
            attributions: [
              const SpanMarker(
                  attribution: _UserTagAttribution("123456"), offset: 36, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: _UserTagAttribution("123456"), offset: 46, markerType: SpanMarkerType.end),
            ],
          ),
        );
      });

      test("plain text followed by custom block format", () {
        final document = parseQuillDeltaDocument(
          {
            "ops": [
              {"insert": "This is regular text\nThis is a banner"},
              {
                "attributes": {
                  "banner-color": "red",
                },
                "insert": "\n"
              },
            ],
          },
          blockFormats: [
            const _BannerBlockFormat(),
            ...defaultBlockFormats,
          ],
        );

        expect(
          (document.getNodeAt(0)! as ParagraphNode).text.toPlainText(),
          "This is regular text",
        );
        expect((document.getNodeAt(0)! as ParagraphNode).getMetadataValue("blockType"), paragraphAttribution);
        expect(
          (document.getNodeAt(1)! as ParagraphNode).text.toPlainText(),
          "This is a banner",
        );
        expect(
            (document.getNodeAt(1)! as ParagraphNode).getMetadataValue("blockType"), const _BannerAttribution("red"));
        expect(document.nodeCount, 3);
      });
    });
  });
}

class _CustomListItemBlockFormat extends FilterByNameBlockDeltaFormat {
  const _CustomListItemBlockFormat() : super("list");

  @override
  List<EditRequest>? doApplyFormat(Editor editor, Object value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }

    final composer = editor.context.find<MutableDocumentComposer>(Editor.composerKey);
    return [
      ConvertParagraphToTaskRequest(
        nodeId: composer.selection!.extent.nodeId,
      ),
    ];
  }
}

class _BannerBlockFormat extends FilterByNameBlockDeltaFormat {
  const _BannerBlockFormat() : super("banner-color");

  @override
  List<EditRequest>? doApplyFormat(Editor editor, Object value) {
    if (value is! String) {
      return null;
    }

    final composer = editor.context.find<MutableDocumentComposer>(Editor.composerKey);
    return [
      ChangeParagraphBlockTypeRequest(
        nodeId: composer.selection!.extent.nodeId,
        blockType: _BannerAttribution(value),
      ),
    ];
  }
}

class _BannerAttribution implements Attribution {
  const _BannerAttribution(this.color);

  @override
  String get id => "banner-$color";

  final String color;

  @override
  bool canMergeWith(Attribution other) {
    if (other is! _BannerAttribution) {
      return false;
    }

    return color == other.color;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is _BannerAttribution && runtimeType == other.runtimeType && color == other.color;

  @override
  int get hashCode => color.hashCode;
}

class _UserTagEmbedParser implements InlineEmbedFormat {
  const _UserTagEmbedParser();

  @override
  bool insert(Editor editor, DocumentComposer composer, Map<String, dynamic> embed) {
    if (embed
        case {
          "tag": {
            "type": String type,
            "userId": String userId,
            "text": String text,
          },
        }) {
      if (type != "user") {
        // This isn't a user tag. Fizzle.
        return false;
      }

      final selection = composer.selection;
      if (selection == null) {
        // The selection should always be defined during insertions. This
        // shouldn't happen. Fizzle.
        return false;
      }
      if (!selection.isCollapsed) {
        // The selection should always be collapsed during insertions. This
        // shouldn't happen. Fizzle.
        return false;
      }

      final extentPosition = selection.extent;
      if (extentPosition.nodePosition is! TextNodePosition) {
        // Insertions should always happen in text nodes. This shouldn't happen.
        // Fizzle.
        return false;
      }

      editor.execute([
        InsertTextRequest(
          documentPosition: extentPosition,
          textToInsert: text,
          attributions: {
            _UserTagAttribution(userId),
          },
        ),
      ]);

      return true;
    }

    return false;
  }
}

class _UserTagAttribution implements Attribution {
  const _UserTagAttribution(this.userId);

  @override
  String get id => userId;

  final String userId;

  @override
  bool canMergeWith(Attribution other) {
    return other is _UserTagAttribution && userId == other.userId;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _UserTagAttribution && runtimeType == other.runtimeType && userId == other.userId;

  @override
  int get hashCode => userId.hashCode;
}
