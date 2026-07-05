import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/test/super_editor_test/supereditor_test_tools.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group('Markdown', () {
    group('serialization', () {
      test('headers', () {
        final paragraph = ParagraphNode(
          id: '1',
          text: AttributedText('My Header'),
        );

        expect(
          serializeDocumentToMarkdown(
            MutableDocument(
              nodes: [
                paragraph.copyParagraphWith(
                  metadata: const {
                    "blockType": header1Attribution,
                  },
                ),
              ],
            ),
          ),
          '# My Header',
        );

        expect(
          serializeDocumentToMarkdown(
            MutableDocument(
              nodes: [
                paragraph.copyParagraphWith(
                  metadata: const {
                    "blockType": header2Attribution,
                  },
                ),
              ],
            ),
          ),
          '## My Header',
        );

        expect(
          serializeDocumentToMarkdown(
            MutableDocument(
              nodes: [
                paragraph.copyParagraphWith(
                  metadata: const {
                    "blockType": header3Attribution,
                  },
                ),
              ],
            ),
          ),
          '### My Header',
        );

        expect(
          serializeDocumentToMarkdown(
            MutableDocument(
              nodes: [
                paragraph.copyParagraphWith(
                  metadata: const {
                    "blockType": header4Attribution,
                  },
                ),
              ],
            ),
          ),
          '#### My Header',
        );

        expect(
          serializeDocumentToMarkdown(
            MutableDocument(
              nodes: [
                paragraph.copyParagraphWith(
                  metadata: const {
                    "blockType": header5Attribution,
                  },
                ),
              ],
            ),
          ),
          '##### My Header',
        );

        expect(
          serializeDocumentToMarkdown(
            MutableDocument(
              nodes: [
                paragraph.copyParagraphWith(
                  metadata: const {
                    "blockType": header6Attribution,
                  },
                ),
              ],
            ),
          ),
          '###### My Header',
        );
      });

      test('header with left alignment', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText('Header1'),
            metadata: const {
              'textAlign': "left",
              'blockType': header1Attribution,
            },
          ),
        ]);
        // Even when using superEditor markdown syntax, which has support
        // for text alignment, we don't add an alignment token when
        // the paragraph is left-aligned.
        // Paragraphs are left-aligned by default, so it isn't necessary
        // to serialize the alignment token.
        expect(serializeDocumentToMarkdown(doc), '# Header1');
      });

      test('header with center alignment', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText('Header1'),
            metadata: const {
              'textAlign': "center",
              'blockType': header1Attribution,
            },
          ),
        ]);
        expect(serializeDocumentToMarkdown(doc), ':---:\n# Header1');
      });

      test('header with right alignment', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText('Header1'),
            metadata: const {
              'textAlign': "right",
              'blockType': header1Attribution,
            },
          ),
        ]);
        expect(serializeDocumentToMarkdown(doc), '---:\n# Header1');
      });

      test('header with justify alignment', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText('Header1'),
            metadata: const {
              'textAlign': "justify",
              'blockType': header1Attribution,
            },
          ),
        ]);
        expect(serializeDocumentToMarkdown(doc), '-::-\n# Header1');
      });

      test('header with styles', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: attributedTextFromMarkdown("My **Header**"),
            metadata: const {'blockType': header1Attribution},
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), '# My **Header**');
      });

      test('blockquote', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText('This is a blockquote'),
            metadata: const {'blockType': blockquoteAttribution},
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), '> This is a blockquote');
      });

      test('blockquote with styles', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: attributedTextFromMarkdown('This is a **blockquote**'),
            metadata: const {'blockType': blockquoteAttribution},
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), '> This is a **blockquote**');
      });

      test('multi-line blockquote marks every line', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText('First line\nSecond line'),
            metadata: const {'blockType': blockquoteAttribution},
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), '> First line\n> Second line');
      });

      test('blockquote with a blank line emits a bare > marker', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText('First paragraph\n\nSecond paragraph'),
            metadata: const {'blockType': blockquoteAttribution},
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), '> First paragraph\n>\n> Second paragraph');
      });

      test('code', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText('This is some code'),
            metadata: const {'blockType': codeAttribution},
          ),
        ]);

        expect(
          serializeDocumentToMarkdown(doc),
          '''
```
This is some code
```''',
        );
      });

      test('code with language', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText('void main() {}\n'),
            metadata: const {
              'blockType': codeAttribution,
              'codeLanguage': 'dart',
            },
          ),
        ]);

        expect(
          serializeDocumentToMarkdown(doc),
          '''
```dart
void main() {}
```''',
        );
      });

      test('code is serialized literally, without markdown escapes', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText('a *b* c'),
            metadata: const {'blockType': codeAttribution},
          ),
        ]);

        expect(
          serializeDocumentToMarkdown(doc),
          '''
```
a *b* c
```''',
        );
      });

      test('paragraph', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText('This is a paragraph.'),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), 'This is a paragraph.');
      });

      test('paragraph with one inline style', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: attributedTextFromMarkdown('This **is a** paragraph.'),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), 'This **is a** paragraph.');
      });

      test('paragraph with overlapping bold and italics', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: attributedTextFromMarkdown('This ***is a*** paragraph.'),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), 'This ***is a*** paragraph.');
      });

      test('paragraph with non-overlapping bold and italics', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: attributedTextFromMarkdown('**This is** *a paragraph.*'),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), '**This is** *a paragraph.*');
      });

      test('paragraph with intersecting bold and italics', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: attributedTextFromMarkdown('This ***is a** paragraph*.'),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), 'This ***is a** paragraph*.');
      });

      test('paragraph with overlapping code and bold', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            // TODO: get code syntax to work
            // text: attributedTextFromMarkdown('This `**is a**` paragraph.'),
            text: AttributedText(
              'This is a paragraph.',
              AttributedSpans(
                attributions: [
                  const SpanMarker(attribution: boldAttribution, offset: 5, markerType: SpanMarkerType.start),
                  const SpanMarker(attribution: boldAttribution, offset: 8, markerType: SpanMarkerType.end),
                  const SpanMarker(attribution: codeAttribution, offset: 5, markerType: SpanMarkerType.start),
                  const SpanMarker(attribution: codeAttribution, offset: 8, markerType: SpanMarkerType.end),
                ],
              ),
            ),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), 'This `**is a**` paragraph.');
      });

      test('paragraph with link', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: attributedTextFromMarkdown('This is a [paragraph](https://example.org).'),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), 'This is a [paragraph](https://example.org).');
      });

      test('paragraph with link overlapping style', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: attributedTextFromMarkdown('This is a [**paragraph**](https://example.org).'),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), 'This is a [**paragraph**](https://example.org).');
      });

      test('paragraph with link intersecting style', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: attributedTextFromMarkdown('[This **is a** paragraph](https://example.org).'),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), '[This **is a** paragraph](https://example.org).');
      });

      test('paragraph with underline', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: attributedTextFromMarkdown('This is a <u>paragraph</u>.'),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), 'This is a <u>paragraph</u>.');
      });

      test('paragraph with legacy underline marker serializes to <u>', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: attributedTextFromMarkdown('This is a ¬paragraph¬.'),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), 'This is a <u>paragraph</u>.');
      });

      test('paragraph with strikethrough', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: attributedTextFromMarkdown('This is a ~~paragraph~~.'),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), 'This is a ~~paragraph~~.');
      });

      test('paragraph with legacy single-tilde strikethrough serializes to ~~', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: attributedTextFromMarkdown('This is a ~paragraph~.'),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), 'This is a ~~paragraph~~.');
      });

      test('paragraph with consecutive links', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: attributedTextFromMarkdown('[First Link](https://example.org)[Second Link](https://github.com)'),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), '[First Link](https://example.org)[Second Link](https://github.com)');
      });

      test('paragraph with left alignment', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText('Paragraph1'),
            metadata: const {
              'textAlign': "left",
            },
          ),
        ]);

        // Even when using superEditor markdown syntax, which has support
        // for text alignment, we don't add an alignment token when
        // the paragraph is left-aligned.
        // Paragraphs are left-aligned by default, so it isn't necessary
        // to serialize the alignment token.
        expect(serializeDocumentToMarkdown(doc), 'Paragraph1');
      });

      test('paragraph with center alignment', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText('Paragraph1'),
            metadata: const {
              'textAlign': "center",
            },
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), ':---:\nParagraph1');
      });

      test('paragraph with right alignment', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText('Paragraph1'),
            metadata: const {
              'textAlign': "right",
            },
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), '---:\nParagraph1');
      });

      test('paragraph with justify alignment', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText('Paragraph1'),
            metadata: const {
              'textAlign': "justify",
            },
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), '-::-\nParagraph1');
      });

      test("doesn't serialize text alignment when not using supereditor syntax", () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText('Paragraph1'),
            metadata: const {
              'textAlign': "center",
            },
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc, syntax: MarkdownSyntax.normal), 'Paragraph1');
      });

      test('empty paragraph', () {
        final serialized = serializeDocumentToMarkdown(
          MutableDocument(nodes: [
            ParagraphNode(id: '1', text: AttributedText('Paragraph1')),
            ParagraphNode(id: '2', text: AttributedText('')),
            ParagraphNode(id: '3', text: AttributedText('Paragraph3')),
          ]),
        );

        // The empty paragraph contributes exactly one newline on top of the
        // blank-line block separator.
        expect(serialized, """Paragraph1


Paragraph3""");
      });

      test('removes all text attributions when serializing an empty paragraph', () {
        final serialized = serializeDocumentToMarkdown(
          MutableDocument(nodes: [
            ParagraphNode(id: '1', text: AttributedText('Paragraph1')),
            ParagraphNode(
              id: '2',
              text: AttributedText(
                '',
                AttributedSpans(
                  attributions: [
                    const SpanMarker(attribution: boldAttribution, offset: 0, markerType: SpanMarkerType.start),
                    const SpanMarker(attribution: boldAttribution, offset: 0, markerType: SpanMarkerType.end),
                  ],
                ),
              ),
            ),
            ParagraphNode(
              id: '3',
              text: AttributedText(
                '',
                AttributedSpans(
                  attributions: [
                    const SpanMarker(attribution: boldAttribution, offset: 0, markerType: SpanMarkerType.start),
                    const SpanMarker(attribution: boldAttribution, offset: 0, markerType: SpanMarkerType.end),
                  ],
                ),
              ),
            ),
          ]),
        );

        // Ensure the attributions were ignored for the empty paragraphs.
        // Each trailing empty paragraph is one trailing newline.
        expect(serialized, """Paragraph1

""");
      });

      test('separates multiple paragraphs with blank lines', () {
        final serialized = serializeDocumentToMarkdown(
          MutableDocument(nodes: [
            ParagraphNode(id: '1', text: AttributedText('Paragraph1')),
            ParagraphNode(id: '2', text: AttributedText('Paragraph2')),
            ParagraphNode(id: '3', text: AttributedText('Paragraph3')),
          ]),
        );

        expect(serialized, """Paragraph1

Paragraph2

Paragraph3""");
      });

      test('separates paragraph from other blocks with blank lines', () {
        final serialized = serializeDocumentToMarkdown(
          MutableDocument(nodes: [
            ParagraphNode(id: '1', text: AttributedText('First Paragraph')),
            HorizontalRuleNode(id: '2'),
          ]),
        );

        expect(serialized, 'First Paragraph\n\n---');
      });

      test('writes a soft line break without hard-break spaces', () {
        final serialized = serializeDocumentToMarkdown(
          MutableDocument(nodes: [
            ParagraphNode(id: '1', text: AttributedText('Line1\nLine2')),
          ]),
        );

        // No two-space hard-break markers: consecutive non-blank lines
        // re-parse into the same paragraph, and the markers accumulated one
        // "  " per line per save (upstream issue #3006).
        expect(serialized, 'Line1\nLine2');
      });

      test('writes embedded newlines at the end of a paragraph verbatim', () {
        final serialized = serializeDocumentToMarkdown(
          MutableDocument(nodes: [
            ParagraphNode(id: '1', text: AttributedText('Paragraph1\n\n')),
            ParagraphNode(id: '2', text: AttributedText('Paragraph2')),
          ]),
        );

        // Embedded blank lines aren't representable in markdown paragraphs;
        // they re-parse as an empty paragraph (a one-pass, byte-stable
        // normalization under the whitespace policy).
        expect(serialized, 'Paragraph1\n\n\n\nParagraph2');
      });

      test('writes embedded newlines within a paragraph verbatim', () {
        final serialized = serializeDocumentToMarkdown(
          MutableDocument(nodes: [
            ParagraphNode(id: '1', text: AttributedText('Line1\n\nLine2')),
          ]),
        );

        expect(serialized, 'Line1\n\nLine2');
      });

      test('writes embedded newlines at the beginning of a paragraph verbatim', () {
        final serialized = serializeDocumentToMarkdown(
          MutableDocument(nodes: [
            ParagraphNode(id: '1', text: AttributedText('\n\nParagraph1')),
            ParagraphNode(id: '2', text: AttributedText('Paragraph2')),
          ]),
        );

        expect(serialized, '\n\nParagraph1\n\nParagraph2');
      });

      test('image', () {
        final doc = MutableDocument(nodes: [
          ImageNode(
            id: '1',
            imageUrl: 'https://someimage.com/the/image.png',
            altText: 'some alt text',
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), '![some alt text](https://someimage.com/the/image.png)');
      });

      test('image with size', () {
        final doc = MutableDocument(nodes: [
          ImageNode(
            id: '1',
            imageUrl: 'https://someimage.com/the/image.png',
            altText: 'some alt text',
            expectedBitmapSize: const ExpectedSize(500, 400),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), '![some alt text](https://someimage.com/the/image.png =500x400)');
      });

      test('image with width', () {
        final doc = MutableDocument(nodes: [
          ImageNode(
            id: '1',
            imageUrl: 'https://someimage.com/the/image.png',
            altText: 'some alt text',
            expectedBitmapSize: const ExpectedSize(300, null),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), '![some alt text](https://someimage.com/the/image.png =300x)');
      });

      test('image with height', () {
        final doc = MutableDocument(nodes: [
          ImageNode(
            id: '1',
            imageUrl: 'https://someimage.com/the/image.png',
            altText: 'some alt text',
            expectedBitmapSize: const ExpectedSize(null, 200),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), '![some alt text](https://someimage.com/the/image.png =x200)');
      });

      test('horizontal rule', () {
        final doc = MutableDocument(nodes: [
          HorizontalRuleNode(
            id: '1',
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), '---');
      });

      test('horizontal rule is separated from the next block by a blank line', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(id: '1', text: AttributedText('above')),
          HorizontalRuleNode(id: '2'),
          ParagraphNode(id: '3', text: AttributedText('below')),
        ]);

        expect(serializeDocumentToMarkdown(doc), 'above\n\n---\n\nbelow');
      });

      test('unordered list items', () {
        final doc = MutableDocument(nodes: [
          ListItemNode(
            id: '1',
            itemType: ListItemType.unordered,
            text: AttributedText('Unordered 1'),
          ),
          ListItemNode(
            id: '2',
            itemType: ListItemType.unordered,
            text: AttributedText('Unordered 2'),
          ),
          ListItemNode(
            id: '3',
            itemType: ListItemType.unordered,
            indent: 1,
            text: AttributedText('Unordered 2.1'),
          ),
          ListItemNode(
            id: '4',
            itemType: ListItemType.unordered,
            indent: 1,
            text: AttributedText('Unordered 2.2'),
          ),
          ListItemNode(
            id: '5',
            itemType: ListItemType.unordered,
            text: AttributedText('Unordered 3'),
          ),
        ]);

        expect(
          serializeDocumentToMarkdown(doc),
          '''
- Unordered 1
- Unordered 2
  - Unordered 2.1
  - Unordered 2.2
- Unordered 3''',
        );
      });

      test('unordered list item with styles', () {
        final doc = MutableDocument(nodes: [
          ListItemNode(
            id: '1',
            itemType: ListItemType.unordered,
            text: attributedTextFromMarkdown('**Unordered** 1'),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), '- **Unordered** 1');
      });

      test('ordered list items', () {
        final doc = MutableDocument(nodes: [
          ListItemNode(
            id: '1',
            itemType: ListItemType.ordered,
            text: AttributedText('Ordered 1'),
          ),
          ListItemNode(
            id: '2',
            itemType: ListItemType.ordered,
            text: AttributedText('Ordered 2'),
          ),
          ListItemNode(
            id: '3',
            itemType: ListItemType.ordered,
            indent: 1,
            text: AttributedText('Ordered 2.1'),
          ),
          ListItemNode(
            id: '4',
            itemType: ListItemType.ordered,
            indent: 1,
            text: AttributedText('Ordered 2.2'),
          ),
          ListItemNode(
            id: '5',
            itemType: ListItemType.ordered,
            text: AttributedText('Ordered 3'),
          ),
        ]);

        expect(
          serializeDocumentToMarkdown(doc),
          '''
1. Ordered 1
2. Ordered 2
   1. Ordered 2.1
   2. Ordered 2.2
3. Ordered 3''',
        );
      });

      test('ordered list items round-trip with their nesting intact', () {
        final doc = MutableDocument(nodes: [
          ListItemNode(id: '1', itemType: ListItemType.ordered, text: AttributedText('Ordered 1')),
          ListItemNode(id: '2', itemType: ListItemType.ordered, indent: 1, text: AttributedText('Ordered 1.1')),
          ListItemNode(id: '3', itemType: ListItemType.ordered, indent: 1, text: AttributedText('Ordered 1.2')),
          ListItemNode(id: '4', itemType: ListItemType.ordered, text: AttributedText('Ordered 2')),
        ]);

        final markdown = serializeDocumentToMarkdown(doc);
        final reparsed = deserializeMarkdownToDocument(markdown);

        // A 2-space indent would silently flatten the nested items on the next
        // parse; the serializer must indent to the parent marker's width.
        expect(reparsed.nodeCount, 4);
        expect((reparsed.getNodeAt(1)! as ListItemNode).indent, 1);
        expect((reparsed.getNodeAt(2)! as ListItemNode).indent, 1);
        expect((reparsed.getNodeAt(3)! as ListItemNode).indent, 0);
      });

      test('mixed-type nested list items', () {
        final doc = MutableDocument(nodes: [
          ListItemNode(id: '1', itemType: ListItemType.ordered, text: AttributedText('Ordered 1')),
          ListItemNode(id: '2', itemType: ListItemType.unordered, indent: 1, text: AttributedText('Bullet 1.1')),
          ListItemNode(id: '3', itemType: ListItemType.ordered, text: AttributedText('Ordered 2')),
        ]);

        expect(
          serializeDocumentToMarkdown(doc),
          '''
1. Ordered 1
   - Bullet 1.1
2. Ordered 2''',
        );
      });

      test('ordered list item with styles', () {
        final doc = MutableDocument(nodes: [
          ListItemNode(
            id: '1',
            itemType: ListItemType.ordered,
            text: attributedTextFromMarkdown('**Ordered** 1'),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), '1. **Ordered** 1');
      });

      test('tasks', () {
        final doc = MutableDocument(
          nodes: [
            TaskNode(
              id: '1',
              text: AttributedText('Task 1'),
              isComplete: true,
            ),
            TaskNode(
              id: '2',
              text: AttributedText('Task 2\nwith multiple lines'),
              isComplete: false,
            ),
            TaskNode(
              id: '3',
              text: AttributedText('Task 3'),
              isComplete: false,
            ),
            TaskNode(
              id: '4',
              text: AttributedText('Task 4'),
              isComplete: true,
            ),
          ],
        );

        expect(
          serializeDocumentToMarkdown(doc),
          '''
- [x] Task 1
- [ ] Task 2
with multiple lines
- [ ] Task 3
- [x] Task 4''',
        );
      });

      test('task with styles', () {
        final doc = MutableDocument(nodes: [
          TaskNode(
            id: '1',
            text: attributedTextFromMarkdown('**Task** 1'),
            isComplete: false,
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), '- [ ] **Task** 1');
      });

      test('example doc', () {
        final doc = MutableDocument(nodes: [
          ImageNode(
            id: Editor.createNodeId(),
            imageUrl: 'https://someimage.com/the/image.png',
          ),
          ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText('Example Doc'),
            metadata: const {'blockType': header1Attribution},
          ),
          ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText('Example Doc With Left Alignment'),
            metadata: const {'blockType': header1Attribution, 'textAlign': "left"},
          ),
          ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText('Example Doc With Center Alignment'),
            metadata: const {'blockType': header1Attribution, 'textAlign': "center"},
          ),
          ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText('Example Doc With Right Alignment'),
            metadata: const {'blockType': header1Attribution, 'textAlign': "right"},
          ),
          ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText('Example Doc With Justify Alignment'),
            metadata: const {'blockType': header1Attribution, 'textAlign': "justify"},
          ),
          HorizontalRuleNode(id: Editor.createNodeId()),
          ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText('Unordered list:'),
          ),
          ListItemNode(
            id: Editor.createNodeId(),
            itemType: ListItemType.unordered,
            text: AttributedText('Unordered 1'),
          ),
          ListItemNode(
            id: Editor.createNodeId(),
            itemType: ListItemType.unordered,
            text: AttributedText('Unordered 2'),
          ),
          ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText('Ordered list:'),
          ),
          ListItemNode(
            id: Editor.createNodeId(),
            itemType: ListItemType.ordered,
            text: AttributedText('Ordered 1'),
          ),
          ListItemNode(
            id: Editor.createNodeId(),
            itemType: ListItemType.ordered,
            text: AttributedText('Ordered 2'),
          ),
          ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText('A blockquote:'),
          ),
          ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText('This is a blockquote.'),
            metadata: const {'blockType': blockquoteAttribution},
          ),
          ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText('Some code:'),
          ),
          ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText('{\n  // This is some code.\n}'),
            metadata: const {'blockType': codeAttribution},
          ),
          TaskNode(
            id: Editor.createNodeId(),
            text: AttributedText('Task 1'),
            isComplete: true,
          ),
          TaskNode(
            id: Editor.createNodeId(),
            text: AttributedText('Task 2\nwith multiple lines'),
            isComplete: false,
          ),
          ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText('A paragraph between tasks'),
          ),
          TaskNode(
            id: Editor.createNodeId(),
            text: AttributedText('Task 3'),
            isComplete: false,
          ),
          TaskNode(
            id: Editor.createNodeId(),
            text: AttributedText('Task 4\nwith multiple lines'),
            isComplete: true,
          ),
        ]);

        // Ensure that the document serializes. We don't bother with
        // validating the output because other tests should validate
        // the per-node serializations.

        // ignore: unused_local_variable
        final markdown = serializeDocumentToMarkdown(doc);
      });

      test("doesn't add empty lines at the end of the document", () {
        final serialized = serializeDocumentToMarkdown(
          MutableDocument(nodes: [
            ParagraphNode(id: '1', text: AttributedText('Paragraph1')),
          ]),
        );

        expect(serialized, 'Paragraph1');
      });
    });

    group('deserialization', () {
      test('headers', () {
        final header1Doc = deserializeMarkdownToDocument('# Header 1');
        expect((header1Doc.first as ParagraphNode).getMetadataValue('blockType'), header1Attribution);

        final header2Doc = deserializeMarkdownToDocument('## Header 2');
        expect((header2Doc.first as ParagraphNode).getMetadataValue('blockType'), header2Attribution);

        final header3Doc = deserializeMarkdownToDocument('### Header 3');
        expect((header3Doc.first as ParagraphNode).getMetadataValue('blockType'), header3Attribution);

        final header4Doc = deserializeMarkdownToDocument('#### Header 4');
        expect((header4Doc.first as ParagraphNode).getMetadataValue('blockType'), header4Attribution);

        final header5Doc = deserializeMarkdownToDocument('##### Header 5');
        expect((header5Doc.first as ParagraphNode).getMetadataValue('blockType'), header5Attribution);

        final header6Doc = deserializeMarkdownToDocument('###### Header 6');
        expect((header6Doc.first as ParagraphNode).getMetadataValue('blockType'), header6Attribution);
      });

      test('header with left alignment', () {
        final headerLeftAlignment1 = deserializeMarkdownToDocument(':---\n# Header 1');
        final header = headerLeftAlignment1.first as ParagraphNode;
        expect(header.getMetadataValue('blockType'), header1Attribution);
        expect(header.getMetadataValue('textAlign'), "left");
        expect(header.text.toPlainText(), 'Header 1');
      });

      test('header with center alignment', () {
        final headerLeftAlignment1 = deserializeMarkdownToDocument(':---:\n# Header 1');
        final header = headerLeftAlignment1.first as ParagraphNode;
        expect(header.getMetadataValue('blockType'), header1Attribution);
        expect(header.getMetadataValue('textAlign'), "center");
        expect(header.text.toPlainText(), 'Header 1');
      });

      test('header with right alignment', () {
        final headerLeftAlignment1 = deserializeMarkdownToDocument('---:\n# Header 1');
        final header = headerLeftAlignment1.first as ParagraphNode;
        expect(header.getMetadataValue('blockType'), header1Attribution);
        expect(header.getMetadataValue('textAlign'), "right");
        expect(header.text.toPlainText(), 'Header 1');
      });

      test('header with justify alignment', () {
        final headerLeftAlignment1 = deserializeMarkdownToDocument('-::-\n# Header 1');
        final header = headerLeftAlignment1.first as ParagraphNode;
        expect(header.getMetadataValue('blockType'), header1Attribution);
        expect(header.getMetadataValue('textAlign'), "justify");
        expect(header.text.toPlainText(), 'Header 1');
      });

      test('blockquote', () {
        final blockquoteDoc = deserializeMarkdownToDocument('> This is a blockquote');

        final blockquote = blockquoteDoc.first as ParagraphNode;
        expect(blockquote.getMetadataValue('blockType'), blockquoteAttribution);
        expect(blockquote.text.toPlainText(), 'This is a blockquote');
      });

      test('multi-line blockquote parses into a single node', () {
        final blockquoteDoc = deserializeMarkdownToDocument('> First line\n> Second line');

        expect(blockquoteDoc.nodeCount, 1);
        final blockquote = blockquoteDoc.first as ParagraphNode;
        expect(blockquote.getMetadataValue('blockType'), blockquoteAttribution);
        expect(blockquote.text.toPlainText(), 'First line\nSecond line');
      });

      test('blockquote with a > blank line keeps its paragraphs separated', () {
        final blockquoteDoc = deserializeMarkdownToDocument('> First paragraph\n>\n> Second paragraph');

        expect(blockquoteDoc.nodeCount, 1);
        final blockquote = blockquoteDoc.first as ParagraphNode;
        expect(blockquote.getMetadataValue('blockType'), blockquoteAttribution);
        expect(blockquote.text.toPlainText(), 'First paragraph\n\nSecond paragraph');
      });

      test('code block', () {
        final codeBlockDoc = deserializeMarkdownToDocument('''
```
This is some code
```''');

        final code = codeBlockDoc.first as ParagraphNode;
        expect(code.getMetadataValue('blockType'), codeAttribution);
        expect(code.text.toPlainText(), 'This is some code\n');
        expect(code.getMetadataValue('codeLanguage'), isNull);
      });

      test('code block with language', () {
        final codeBlockDoc = deserializeMarkdownToDocument('''
```dart
void main() {}
```''');

        final code = codeBlockDoc.first as ParagraphNode;
        expect(code.getMetadataValue('blockType'), codeAttribution);
        expect(code.text.toPlainText(), 'void main() {}\n');
        expect(code.getMetadataValue('codeLanguage'), 'dart');
      });

      test('image', () {
        final codeBlockDoc = deserializeMarkdownToDocument('![Image alt text](https://images.com/some/image.png)');

        final image = codeBlockDoc.first as ImageNode;
        expect(image.imageUrl, 'https://images.com/some/image.png');
        expect(image.altText, 'Image alt text');
        expect(image.expectedBitmapSize, isNull);
      });

      test('image with size', () {
        final codeBlockDoc =
            deserializeMarkdownToDocument('![Image alt text](https://images.com/some/image.png =500x200)');

        final image = codeBlockDoc.first as ImageNode;
        expect(image.imageUrl, 'https://images.com/some/image.png');
        expect(image.altText, 'Image alt text');
        expect(image.expectedBitmapSize?.width, 500.0);
        expect(image.expectedBitmapSize?.height, 200.0);
      });

      test('image with size and title', () {
        final codeBlockDoc = deserializeMarkdownToDocument(
            '![Image alt text](https://images.com/some/image.png =500x200 "image title")');

        final image = codeBlockDoc.first as ImageNode;
        expect(image.imageUrl, 'https://images.com/some/image.png');
        expect(image.altText, 'Image alt text');
        expect(image.expectedBitmapSize?.width, 500.0);
        expect(image.expectedBitmapSize?.height, 200.0);
      });

      test('image with width', () {
        final codeBlockDoc =
            deserializeMarkdownToDocument('![Image alt text](https://images.com/some/image.png =500x)');

        final image = codeBlockDoc.first as ImageNode;
        expect(image.imageUrl, 'https://images.com/some/image.png');
        expect(image.altText, 'Image alt text');
        expect(image.expectedBitmapSize?.width, 500.0);
        expect(image.expectedBitmapSize?.height, isNull);
      });

      test('image with height', () {
        final codeBlockDoc =
            deserializeMarkdownToDocument('![Image alt text](https://images.com/some/image.png =x200)');

        final image = codeBlockDoc.first as ImageNode;
        expect(image.imageUrl, 'https://images.com/some/image.png');
        expect(image.altText, 'Image alt text');
        expect(image.expectedBitmapSize?.width, isNull);
        expect(image.expectedBitmapSize?.height, 200.0);
      });

      test('image with size notation without width and height', () {
        final codeBlockDoc = deserializeMarkdownToDocument('![Image alt text](https://images.com/some/image.png =x)');

        final image = codeBlockDoc.first as ImageNode;
        expect(image.imageUrl, 'https://images.com/some/image.png');
        expect(image.altText, 'Image alt text');
        expect(image.expectedBitmapSize?.width, isNull);
        expect(image.expectedBitmapSize?.height, isNull);
      });

      test('image with incomplete size notation', () {
        final codeBlockDoc = deserializeMarkdownToDocument('![Image alt text](https://images.com/some/image.png =)');

        final image = codeBlockDoc.first as ImageNode;
        expect(image.imageUrl, 'https://images.com/some/image.png');
        expect(image.altText, 'Image alt text');
        expect(image.expectedBitmapSize?.width, isNull);
        expect(image.expectedBitmapSize?.height, isNull);
      });

      test('image with caption above', () {
        final doc = deserializeMarkdownToDocument(
          '''
Document with image with caption.
        
A caption:
![Image alt text](https://images.com/some/image.png)

Paragraph after the captioned image.''',
        );

        expect(
          doc,
          documentEquivalentTo(
            MutableDocument(nodes: [
              ParagraphNode(id: "1", text: AttributedText("Document with image with caption.")),
              ParagraphNode(id: "2", text: AttributedText("A caption:")),
              ImageNode(id: "3", imageUrl: "https://images.com/some/image.png", altText: "Image alt text"),
              ParagraphNode(id: "4", text: AttributedText("Paragraph after the captioned image.")),
            ]),
          ),
        );
      });

      test('multiple images with captions above', () {
        final doc = deserializeMarkdownToDocument(
          '''
Document with image with caption.
        
A caption:
![Image 1](https://images.com/some/image1.png)

B caption:
![Image 2](https://images.com/some/image2.png)

C caption:
![Image 3](https://images.com/some/image3.png)

Paragraph after the captioned image.''',
        );

        expect(
          doc,
          documentEquivalentTo(
            MutableDocument(nodes: [
              ParagraphNode(id: "1", text: AttributedText("Document with image with caption.")),
              ParagraphNode(id: "2", text: AttributedText("A caption:")),
              ImageNode(id: "3", imageUrl: "https://images.com/some/image1.png", altText: "Image 1"),
              ParagraphNode(id: "4", text: AttributedText("B caption:")),
              ImageNode(id: "5", imageUrl: "https://images.com/some/image2.png", altText: "Image 2"),
              ParagraphNode(id: "6", text: AttributedText("C caption:")),
              ImageNode(id: "7", imageUrl: "https://images.com/some/image3.png", altText: "Image 3"),
              ParagraphNode(id: "8", text: AttributedText("Paragraph after the captioned image.")),
            ]),
          ),
        );
      });

      test('multiple images with captions above without empty lines between', () {
        final doc = deserializeMarkdownToDocument(
          '''
Document with image with caption.
        
A caption:
![Image 1](https://images.com/some/image1.png)
B caption:
![Image 2](https://images.com/some/image2.png)
C caption:
![Image 3](https://images.com/some/image3.png)

Paragraph after the captioned image.''',
        );

        expect(
          doc,
          documentEquivalentTo(
            MutableDocument(nodes: [
              ParagraphNode(id: "1", text: AttributedText("Document with image with caption.")),
              ParagraphNode(id: "2", text: AttributedText("A caption:")),
              ImageNode(id: "3", imageUrl: "https://images.com/some/image1.png", altText: "Image 1"),
              ParagraphNode(id: "4", text: AttributedText("B caption:")),
              ImageNode(id: "5", imageUrl: "https://images.com/some/image2.png", altText: "Image 2"),
              ParagraphNode(id: "6", text: AttributedText("C caption:")),
              ImageNode(id: "7", imageUrl: "https://images.com/some/image3.png", altText: "Image 3"),
              ParagraphNode(id: "8", text: AttributedText("Paragraph after the captioned image.")),
            ]),
          ),
        );
      });

      test('single unstyled paragraph', () {
        const markdown = 'This is some unstyled text to parse as markdown';

        final document = deserializeMarkdownToDocument(markdown);

        expect(document.nodeCount, 1);
        expect(document.first, isA<ParagraphNode>());

        final paragraph = document.first as ParagraphNode;
        expect(paragraph.text.toPlainText(), 'This is some unstyled text to parse as markdown');
      });

      test('single styled paragraph', () {
        const markdown = 'This is **some *styled*** text to parse as [markdown](https://example.org)';

        final document = deserializeMarkdownToDocument(markdown);

        expect(document.nodeCount, 1);
        expect(document.first, isA<ParagraphNode>());

        final paragraph = document.first as ParagraphNode;
        final styledText = paragraph.text;
        expect(styledText.toPlainText(), 'This is some styled text to parse as markdown');

        expect(styledText.getAllAttributionsAt(0).isEmpty, true);
        expect(styledText.getAllAttributionsAt(8).contains(boldAttribution), true);
        expect(styledText.getAllAttributionsAt(13).containsAll([boldAttribution, italicsAttribution]), true);
        expect(styledText.getAllAttributionsAt(19).isEmpty, true);
        expect(styledText.getAllAttributionsAt(40).single, LinkAttribution.fromUri(Uri.https('example.org', '')));
      });

      test('paragraph with special HTML symbols keeps the symbols by default', () {
        const markdown = 'Preserves symbols like &, <, and >, rather than use HTML escape codes.';

        final document = deserializeMarkdownToDocument(markdown);

        expect(document.nodeCount, 1);
        expect(document.first, isA<ParagraphNode>());

        final paragraph = document.first as ParagraphNode;
        final styledText = paragraph.text;
        expect(styledText.toPlainText(), 'Preserves symbols like &, <, and >, rather than use HTML escape codes.');
      });

      test('paragraph with special HTML symbols can escape them', () {
        const markdown = 'Escapes HTML symbols like &, <, and >, when requested.';

        final document = deserializeMarkdownToDocument(markdown, encodeHtml: true);

        expect(document.nodeCount, 1);
        expect(document.first, isA<ParagraphNode>());

        final paragraph = document.first as ParagraphNode;
        final styledText = paragraph.text;
        expect(styledText.toPlainText(), 'Escapes HTML symbols like &amp;, &lt;, and &gt;, when requested.');
      });

      test('link within multiple styles', () {
        const markdown = 'This is **some *styled [link](https://example.org) text***';

        final document = deserializeMarkdownToDocument(markdown);

        expect(document.nodeCount, 1);
        expect(document.first, isA<ParagraphNode>());

        final paragraph = document.first as ParagraphNode;
        final styledText = paragraph.text;
        expect(styledText.toPlainText(), 'This is some styled link text');

        expect(styledText.getAllAttributionsAt(0).isEmpty, true);
        expect(styledText.getAllAttributionsAt(8).contains(boldAttribution), true);
        expect(styledText.getAllAttributionsAt(13).containsAll([boldAttribution, italicsAttribution]), true);
        expect(
            styledText.getAllAttributionsAt(20).containsAll(
                [boldAttribution, italicsAttribution, LinkAttribution.fromUri(Uri.https('example.org', ''))]),
            true);
        expect(styledText.getAllAttributionsAt(25).containsAll([boldAttribution, italicsAttribution]), true);
      });

      test('completely overlapping link and style', () {
        const markdown = 'This is **[a test](https://example.org)**';

        final document = deserializeMarkdownToDocument(markdown);

        expect(document.nodeCount, 1);
        expect(document.first, isA<ParagraphNode>());

        final paragraph = document.first as ParagraphNode;
        final styledText = paragraph.text;
        expect(styledText.toPlainText(), 'This is a test');

        expect(styledText.getAllAttributionsAt(0).isEmpty, true);
        expect(styledText.getAllAttributionsAt(8).contains(boldAttribution), true);
        expect(
            styledText
                .getAllAttributionsAt(13)
                .containsAll([boldAttribution, LinkAttribution.fromUri(Uri.https('example.org', ''))]),
            true);
      });

      test('single style intersecting link', () {
        // This isn't necessarily the behavior that you would expect, but it has been tested against multiple Markdown
        // renderers (such as VS Code) and it matches their behaviour.
        const markdown = 'This **is [a** link](https://example.org) test';
        final document = deserializeMarkdownToDocument(markdown);

        expect(document.nodeCount, 1);
        expect(document.first, isA<ParagraphNode>());

        final paragraph = document.first as ParagraphNode;
        final styledText = paragraph.text;
        expect(styledText.toPlainText(), 'This **is a** link test');

        expect(styledText.getAllAttributionsAt(9).isEmpty, true);
        expect(styledText.getAllAttributionsAt(12).single, LinkAttribution.fromUri(Uri.https('example.org', '')));
      });

      test('empty link', () {
        // This isn't necessarily the behavior that you would expect, but it has been tested against multiple Markdown
        // renderers (such as VS Code) and it matches their behaviour.
        const markdown = 'This is [a link]() test';
        final document = deserializeMarkdownToDocument(markdown);

        expect(document.nodeCount, 1);
        expect(document.first, isA<ParagraphNode>());

        final paragraph = document.first as ParagraphNode;
        final styledText = paragraph.text;
        expect(styledText.toPlainText(), 'This is a link test');

        expect(styledText.getAllAttributionsAt(12).single, LinkAttribution.fromUri(Uri.parse('')));
      });

      test('unordered list', () {
        const markdown = '''
 * list item 1
 * list item 2
   * list item 2.1
   * list item 2.2
 * list item 3''';

        final document = deserializeMarkdownToDocument(markdown);

        expect(document.nodeCount, 5);
        for (final node in document) {
          expect(node, isA<ListItemNode>());
          expect((node as ListItemNode).type, ListItemType.unordered);
        }

        expect((document.getNodeAt(0)! as ListItemNode).indent, 0);
        expect((document.getNodeAt(0)! as ListItemNode).text.toPlainText(), 'list item 1');

        expect((document.getNodeAt(1)! as ListItemNode).indent, 0);
        expect((document.getNodeAt(1)! as ListItemNode).text.toPlainText(), 'list item 2');

        expect((document.getNodeAt(2)! as ListItemNode).indent, 1);
        expect((document.getNodeAt(2)! as ListItemNode).text.toPlainText(), 'list item 2.1');

        expect((document.getNodeAt(3)! as ListItemNode).indent, 1);
        expect((document.getNodeAt(3)! as ListItemNode).text.toPlainText(), 'list item 2.2');

        expect((document.getNodeAt(4)! as ListItemNode).indent, 0);
        expect((document.getNodeAt(4)! as ListItemNode).text.toPlainText(), 'list item 3');
      });

      test('empty unordered list item', () {
        const markdown = '* ';
        final document = deserializeMarkdownToDocument(markdown);

        expect(document.nodeCount, 1);
        expect(document.first, isA<ListItemNode>());
        expect((document.first as ListItemNode).type, ListItemType.unordered);
        expect((document.first as ListItemNode).text.toPlainText(), isEmpty);
      });

      test('unordered list followed by empty list item', () {
        const markdown = """- list item 1
- """;

        final document = deserializeMarkdownToDocument(markdown);

        expect(document.nodeCount, 2);

        expect(document.getNodeAt(0)!, isA<ListItemNode>());
        expect((document.getNodeAt(0)! as ListItemNode).type, ListItemType.unordered);
        expect((document.getNodeAt(0)! as ListItemNode).text.toPlainText(), 'list item 1');
        expect(document.getNodeAt(1)!, isA<ListItemNode>());
        expect((document.getNodeAt(1)! as ListItemNode).type, ListItemType.unordered);
        expect((document.getNodeAt(1)! as ListItemNode).text.toPlainText(), '');
      });

      test('parses mixed unordered and ordered items', () {
        const markdown = """
1. Ordered 1
   - Unordered 1
   - Unordered 2

2. Ordered 2
   - Unordered 1
   - Unordered 2

3. Ordered 3
   - Unordered 1
   - Unordered 2""";

        final document = deserializeMarkdownToDocument(markdown);

        expect(document.nodeCount, 9);
        for (final node in document) {
          expect(node, isA<ListItemNode>());
        }

        expect((document.getNodeAt(0)! as ListItemNode).type, ListItemType.ordered);
        expect((document.getNodeAt(0)! as ListItemNode).text.toPlainText(), 'Ordered 1');

        expect((document.getNodeAt(1)! as ListItemNode).type, ListItemType.unordered);
        expect((document.getNodeAt(1)! as ListItemNode).text.toPlainText(), 'Unordered 1');

        expect((document.getNodeAt(2)! as ListItemNode).type, ListItemType.unordered);
        expect((document.getNodeAt(2)! as ListItemNode).text.toPlainText(), 'Unordered 2');

        expect((document.getNodeAt(3)! as ListItemNode).type, ListItemType.ordered);
        expect((document.getNodeAt(3)! as ListItemNode).text.toPlainText(), 'Ordered 2');

        expect((document.getNodeAt(4)! as ListItemNode).type, ListItemType.unordered);
        expect((document.getNodeAt(4)! as ListItemNode).text.toPlainText(), 'Unordered 1');

        expect((document.getNodeAt(5)! as ListItemNode).type, ListItemType.unordered);
        expect((document.getNodeAt(5)! as ListItemNode).text.toPlainText(), 'Unordered 2');

        expect((document.getNodeAt(6)! as ListItemNode).type, ListItemType.ordered);
        expect((document.getNodeAt(6)! as ListItemNode).text.toPlainText(), 'Ordered 3');

        expect((document.getNodeAt(7)! as ListItemNode).type, ListItemType.unordered);
        expect((document.getNodeAt(7)! as ListItemNode).text.toPlainText(), 'Unordered 1');

        expect((document.getNodeAt(8)! as ListItemNode).type, ListItemType.unordered);
        expect((document.getNodeAt(8)! as ListItemNode).text.toPlainText(), 'Unordered 2');
      });

      test('unordered list with empty lines between items', () {
        const markdown = '''
 * list item 1
 
 * list item 2

 * list item 3''';

        final document = deserializeMarkdownToDocument(markdown);

        expect(document.nodeCount, 3);
        for (final node in document) {
          expect(node, isA<ListItemNode>());
          expect((node as ListItemNode).type, ListItemType.unordered);
        }

        expect((document.getNodeAt(0)! as ListItemNode).text.toPlainText(), 'list item 1');
        expect((document.getNodeAt(1)! as ListItemNode).text.toPlainText(), 'list item 2');
        expect((document.getNodeAt(2)! as ListItemNode).text.toPlainText(), 'list item 3');
      });

      test('unordered list items mixed with task items', () {
        const markdown = '''
- list item node 
- [ ] task node
- [x] completed task node
- second list item node 
- [ ] another task node
- third list item node
- fourth list item node 
''';

        final document = deserializeMarkdownToDocument(markdown);

        // 7 list/task nodes, plus one empty paragraph for the fixture's
        // trailing newline.
        expect(document.nodeCount, 8);
        expect(document.getNodeAt(0)!, isA<ListItemNode>());
        expect(document.getNodeAt(1)!, isA<TaskNode>());
        expect((document.getNodeAt(1) as TaskNode).text.toPlainText(), 'task node');
        expect((document.getNodeAt(1) as TaskNode).isComplete, isFalse);
        expect(document.getNodeAt(2)!, isA<TaskNode>());
        expect((document.getNodeAt(2) as TaskNode).text.toPlainText(), 'completed task node');
        expect((document.getNodeAt(2) as TaskNode).isComplete, isTrue);
        expect(document.getNodeAt(3)!, isA<ListItemNode>());
        expect(document.getNodeAt(4)!, isA<TaskNode>());
        expect((document.getNodeAt(4) as TaskNode).text.toPlainText(), 'another task node');
        expect((document.getNodeAt(4) as TaskNode).isComplete, isFalse);
        expect(document.getNodeAt(5)!, isA<ListItemNode>());
        expect(document.getNodeAt(6)!, isA<ListItemNode>());
      });

      test('ordered list', () {
        const markdown = '''
 1. list item 1
 1. list item 2
    1. list item 2.1
    1. list item 2.2
 1. list item 3''';

        final document = deserializeMarkdownToDocument(markdown);

        expect(document.nodeCount, 5);
        for (final node in document) {
          expect(node, isA<ListItemNode>());
          expect((node as ListItemNode).type, ListItemType.ordered);
        }

        expect((document.getNodeAt(0)! as ListItemNode).indent, 0);
        expect((document.getNodeAt(0)! as ListItemNode).text.toPlainText(), 'list item 1');

        expect((document.getNodeAt(1)! as ListItemNode).indent, 0);
        expect((document.getNodeAt(1)! as ListItemNode).text.toPlainText(), 'list item 2');

        expect((document.getNodeAt(2)! as ListItemNode).indent, 1);
        expect((document.getNodeAt(2)! as ListItemNode).text.toPlainText(), 'list item 2.1');

        expect((document.getNodeAt(3)! as ListItemNode).indent, 1);
        expect((document.getNodeAt(3)! as ListItemNode).text.toPlainText(), 'list item 2.2');

        expect((document.getNodeAt(4)! as ListItemNode).indent, 0);
        expect((document.getNodeAt(4)! as ListItemNode).text.toPlainText(), 'list item 3');
      });

      test('empty ordered list item', () {
        const markdown = '1. ';
        final document = deserializeMarkdownToDocument(markdown);

        expect(document.nodeCount, 1);
        expect(document.first, isA<ListItemNode>());
        expect((document.first as ListItemNode).type, ListItemType.ordered);
        expect((document.first as ListItemNode).text.toPlainText(), isEmpty);
      });

      test('ordered list with empty lines between items', () {
        const markdown = '''
 1. list item 1
 
 2. list item 2

 3. list item 3''';

        final document = deserializeMarkdownToDocument(markdown);

        expect(document.nodeCount, 3);
        for (final node in document) {
          expect(node, isA<ListItemNode>());
          expect((node as ListItemNode).type, ListItemType.ordered);
        }

        expect((document.getNodeAt(0)! as ListItemNode).text.toPlainText(), 'list item 1');
        expect((document.getNodeAt(1)! as ListItemNode).text.toPlainText(), 'list item 2');
        expect((document.getNodeAt(2)! as ListItemNode).text.toPlainText(), 'list item 3');
      });

      test('mixing multiple levels of ordered and unordered lists', () {
        const markdown = '''
- Level 1
   1. Level 2
      1. Level 3
         - Sublevel 1         
         - Sublevel 2
      2. Level 3 again
   2. Level 2 returning
2. Level 1 once more
   - Bullet list
     - Another bullet
- Main bullet list
   - Sub bullet list
      - Subsub bullet list
''';
        final document = deserializeMarkdownToDocument(markdown);

        // 13 list items, plus one empty paragraph for the fixture's trailing
        // newline.
        expect(document.nodeCount, 14);

        expect((document.getNodeAt(0)! as ListItemNode).indent, 0);
        expect((document.getNodeAt(0)! as ListItemNode).type, ListItemType.unordered);
        expect((document.getNodeAt(0)! as ListItemNode).text.toPlainText(), 'Level 1');

        expect((document.getNodeAt(1)! as ListItemNode).indent, 1);
        expect((document.getNodeAt(1)! as ListItemNode).type, ListItemType.ordered);
        expect((document.getNodeAt(1)! as ListItemNode).text.toPlainText(), 'Level 2');

        expect((document.getNodeAt(2)! as ListItemNode).indent, 2);
        expect((document.getNodeAt(2)! as ListItemNode).type, ListItemType.ordered);
        expect((document.getNodeAt(2)! as ListItemNode).text.toPlainText(), 'Level 3');

        expect((document.getNodeAt(3)! as ListItemNode).indent, 3);
        expect((document.getNodeAt(3)! as ListItemNode).type, ListItemType.unordered);
        expect((document.getNodeAt(3)! as ListItemNode).text.toPlainText(), 'Sublevel 1');

        expect((document.getNodeAt(4)! as ListItemNode).indent, 3);
        expect((document.getNodeAt(4)! as ListItemNode).type, ListItemType.unordered);
        expect((document.getNodeAt(4)! as ListItemNode).text.toPlainText(), 'Sublevel 2');

        expect((document.getNodeAt(5)! as ListItemNode).indent, 2);
        expect((document.getNodeAt(5)! as ListItemNode).type, ListItemType.ordered);
        expect((document.getNodeAt(5)! as ListItemNode).text.toPlainText(), 'Level 3 again');

        expect((document.getNodeAt(6)! as ListItemNode).indent, 1);
        expect((document.getNodeAt(6)! as ListItemNode).type, ListItemType.ordered);
        expect((document.getNodeAt(6)! as ListItemNode).text.toPlainText(), 'Level 2 returning');

        expect((document.getNodeAt(7)! as ListItemNode).indent, 0);
        expect((document.getNodeAt(7)! as ListItemNode).type, ListItemType.ordered);
        expect((document.getNodeAt(7)! as ListItemNode).text.toPlainText(), 'Level 1 once more');

        expect((document.getNodeAt(8)! as ListItemNode).indent, 1);
        expect((document.getNodeAt(8)! as ListItemNode).type, ListItemType.unordered);
        expect((document.getNodeAt(8)! as ListItemNode).text.toPlainText(), 'Bullet list');

        expect((document.getNodeAt(9)! as ListItemNode).indent, 2);
        expect((document.getNodeAt(9)! as ListItemNode).type, ListItemType.unordered);
        expect((document.getNodeAt(9)! as ListItemNode).text.toPlainText(), 'Another bullet');

        expect((document.getNodeAt(10)! as ListItemNode).indent, 0);
        expect((document.getNodeAt(10)! as ListItemNode).type, ListItemType.unordered);
        expect((document.getNodeAt(10)! as ListItemNode).text.toPlainText(), 'Main bullet list');

        expect((document.getNodeAt(11)! as ListItemNode).indent, 1);
        expect((document.getNodeAt(11)! as ListItemNode).type, ListItemType.unordered);
        expect((document.getNodeAt(11)! as ListItemNode).text.toPlainText(), 'Sub bullet list');

        expect((document.getNodeAt(12)! as ListItemNode).indent, 2);
        expect((document.getNodeAt(12)! as ListItemNode).type, ListItemType.unordered);
        expect((document.getNodeAt(12)! as ListItemNode).text.toPlainText(), 'Subsub bullet list');
      });

      test('tasks', () {
        const markdown = '''
- [x] Task 1
- [ ] Task 2
- [ ] Task 3  
with multiple lines
- [x] Task 4''';

        final document = deserializeMarkdownToDocument(markdown);

        expect(document.nodeCount, 4);

        expect(document.getNodeAt(0)!, isA<TaskNode>());
        expect(document.getNodeAt(1)!, isA<TaskNode>());
        expect(document.getNodeAt(2)!, isA<TaskNode>());
        expect(document.getNodeAt(3)!, isA<TaskNode>());

        expect((document.getNodeAt(0)! as TaskNode).text.toPlainText(), 'Task 1');
        expect((document.getNodeAt(0)! as TaskNode).isComplete, isTrue);

        expect((document.getNodeAt(1)! as TaskNode).text.toPlainText(), 'Task 2');
        expect((document.getNodeAt(1)! as TaskNode).isComplete, isFalse);

        expect((document.getNodeAt(2)! as TaskNode).text.toPlainText(), 'Task 3\nwith multiple lines');
        expect((document.getNodeAt(2)! as TaskNode).isComplete, isFalse);

        expect((document.getNodeAt(3)! as TaskNode).text.toPlainText(), 'Task 4');
        expect((document.getNodeAt(3)! as TaskNode).isComplete, isTrue);
      });

      test('example doc 1', () {
        final document = deserializeMarkdownToDocument(exampleMarkdownDoc1);

        // 26 content nodes, plus one empty paragraph for the fixture's
        // trailing newline.
        expect(document.nodeCount, 27);

        expect(document.getNodeAt(0)!, isA<ParagraphNode>());
        expect((document.getNodeAt(0)! as ParagraphNode).getMetadataValue('blockType'), header1Attribution);

        expect(document.getNodeAt(1)!, isA<HorizontalRuleNode>());

        expect(document.getNodeAt(2)!, isA<ParagraphNode>());

        expect(document.getNodeAt(3)!, isA<ParagraphNode>());

        for (int i = 4; i < 9; ++i) {
          expect(document.getNodeAt(i)!, isA<ListItemNode>());
        }

        expect(document.getNodeAt(9)!, isA<HorizontalRuleNode>());

        for (int i = 10; i < 15; ++i) {
          expect(document.getNodeAt(i)!, isA<ListItemNode>());
        }

        expect(document.getNodeAt(15)!, isA<HorizontalRuleNode>());

        expect(document.getNodeAt(16)!, isA<ImageNode>());

        expect(document.getNodeAt(17)!, isA<TaskNode>());

        expect(document.getNodeAt(18)!, isA<ParagraphNode>());

        expect(document.getNodeAt(19)!, isA<TaskNode>());

        expect(document.getNodeAt(20)!, isA<HorizontalRuleNode>());

        expect(document.getNodeAt(21)!, isA<ParagraphNode>());
        expect((document.getNodeAt(21)! as ParagraphNode).getMetadataValue('blockType'), header1Attribution);
        expect((document.getNodeAt(21)! as ParagraphNode).getMetadataValue('textAlign'), "left");

        expect(document.getNodeAt(22)!, isA<ParagraphNode>());
        expect((document.getNodeAt(22)! as ParagraphNode).getMetadataValue('blockType'), header1Attribution);
        expect((document.getNodeAt(22)! as ParagraphNode).getMetadataValue('textAlign'), "center");

        expect(document.getNodeAt(23)!, isA<ParagraphNode>());
        expect((document.getNodeAt(23)! as ParagraphNode).getMetadataValue('blockType'), header1Attribution);
        expect((document.getNodeAt(23)! as ParagraphNode).getMetadataValue('textAlign'), "right");

        expect(document.getNodeAt(24)!, isA<ParagraphNode>());
        expect((document.getNodeAt(24)! as ParagraphNode).getMetadataValue('blockType'), header1Attribution);
        expect((document.getNodeAt(24)! as ParagraphNode).getMetadataValue('textAlign'), "justify");

        expect(document.getNodeAt(25)!, isA<ParagraphNode>());

        // The fixture ends with "The end!\n" — the trailing newline is an
        // empty paragraph.
        expect((document.getNodeAt(26)! as ParagraphNode).text.toPlainText(), '');
      });

      test('paragraph with single strikethrough', () {
        final doc = deserializeMarkdownToDocument('~This is~ a paragraph.');
        final styledText = (doc.getNodeAt(0)! as ParagraphNode).text;

        // Ensure text within the range is attributed.
        expect(styledText.getAllAttributionsAt(0).contains(strikethroughAttribution), true);
        expect(styledText.getAllAttributionsAt(6).contains(strikethroughAttribution), true);

        // Ensure text outside the range isn't attributed.
        expect(styledText.getAllAttributionsAt(7).contains(strikethroughAttribution), false);
      });

      test('paragraph with double strikethrough', () {
        final doc = deserializeMarkdownToDocument('~~This is~~ a paragraph.');
        final styledText = (doc.getNodeAt(0)! as ParagraphNode).text;

        // Ensure text within the range is attributed.
        expect(styledText.getAllAttributionsAt(0).contains(strikethroughAttribution), true);
        expect(styledText.getAllAttributionsAt(6).contains(strikethroughAttribution), true);

        // Ensure text outside the range isn't attributed.
        expect(styledText.getAllAttributionsAt(7).contains(strikethroughAttribution), false);
      });

      test('paragraph with underline', () {
        final doc = deserializeMarkdownToDocument('¬This is¬ a paragraph.');
        final styledText = (doc.getNodeAt(0)! as ParagraphNode).text;

        // Ensure text within the range is attributed.
        expect(styledText.getAllAttributionsAt(0).contains(underlineAttribution), true);
        expect(styledText.getAllAttributionsAt(6).contains(underlineAttribution), true);

        // Ensure text outside the range isn't attributed.
        expect(styledText.getAllAttributionsAt(7).contains(underlineAttribution), false);
      });

      test('paragraph with inline code', () {
        final doc = deserializeMarkdownToDocument('`This is` a paragraph.');
        final styledText = (doc.getNodeAt(0)! as ParagraphNode).text;

        // Ensure text within the range is attributed.
        expect(styledText.getAllAttributionsAt(0).contains(codeAttribution), true);
        expect(styledText.getAllAttributionsAt(6).contains(codeAttribution), true);

        // Ensure text outside the range isn't attributed.
        expect(styledText.getAllAttributionsAt(7).contains(codeAttribution), false);
      });

      test('paragraph with left alignment', () {
        final doc = deserializeMarkdownToDocument(':---\nParagraph1');

        final paragraph = doc.first as ParagraphNode;
        expect(paragraph.getMetadataValue('textAlign'), "left");
        expect(paragraph.text.toPlainText(), 'Paragraph1');
      });

      test('paragraph with center alignment', () {
        final doc = deserializeMarkdownToDocument(':---:\nParagraph1');

        final paragraph = doc.first as ParagraphNode;
        expect(paragraph.getMetadataValue('textAlign'), "center");
        expect(paragraph.text.toPlainText(), 'Paragraph1');
      });

      test('paragraph with right alignment', () {
        final doc = deserializeMarkdownToDocument('---:\nParagraph1');

        final paragraph = doc.first as ParagraphNode;
        expect(paragraph.getMetadataValue('textAlign'), "right");
        expect(paragraph.text.toPlainText(), 'Paragraph1');
      });

      test('paragraph with justify alignment', () {
        final doc = deserializeMarkdownToDocument('-::-\nParagraph1');

        final paragraph = doc.first as ParagraphNode;
        expect(paragraph.getMetadataValue('textAlign'), "justify");
        expect(paragraph.text.toPlainText(), 'Paragraph1');
      });

      test('treats alignment token as text at the end of the document', () {
        final doc = deserializeMarkdownToDocument('---:');

        final paragraph = doc.first as ParagraphNode;
        expect(paragraph.getMetadataValue('textAlign'), null);
        expect(paragraph.text.toPlainText(), '---:');
      });

      test('treats alignment token as text when not followed by a paragraph', () {
        final doc = deserializeMarkdownToDocument('---:\n - - -');

        final paragraph = doc.first as ParagraphNode;
        expect(paragraph.getMetadataValue('textAlign'), null);
        expect(paragraph.text.toPlainText(), '---:');

        // Ensure the horizontal rule is parsed.
        expect(doc.getNodeAt(1)!, isA<HorizontalRuleNode>());
      });

      test('treats alignment token as text when not using supereditor syntax', () {
        final doc = deserializeMarkdownToDocument(':---\nParagraph1', syntax: MarkdownSyntax.normal);

        final paragraph = doc.first as ParagraphNode;
        expect(paragraph.getMetadataValue('textAlign'), null);
        expect(paragraph.text.toPlainText(), ':---\nParagraph1');
      });

      test('multiple paragraphs', () {
        const input = """Paragraph1

Paragraph2""";
        final doc = deserializeMarkdownToDocument(input);

        expect(doc.nodeCount, 2);
        expect((doc.getNodeAt(0)! as ParagraphNode).text.toPlainText(), 'Paragraph1');
        expect((doc.getNodeAt(1)! as ParagraphNode).text.toPlainText(), 'Paragraph2');
      });

      test('empty paragraph between paragraphs', () {
        // One blank line separates the blocks; each additional blank line is
        // one empty paragraph.
        const input = """Paragraph1


Paragraph3""";
        final doc = deserializeMarkdownToDocument(input);

        expect(doc.nodeCount, 3);
        expect((doc.getNodeAt(0)! as ParagraphNode).text.toPlainText(), 'Paragraph1');
        expect((doc.getNodeAt(1)! as ParagraphNode).text.toPlainText(), '');
        expect((doc.getNodeAt(2)! as ParagraphNode).text.toPlainText(), 'Paragraph3');
      });

      test('every trailing newline after a list is an empty paragraph', () {
        const input = '''
1. First item
2. Second item
3. Third item


''';
        final doc = deserializeMarkdownToDocument(input);

        // The input ends with "Third item\n\n\n" — three trailing newlines,
        // so three empty paragraphs.
        expect(doc.nodeCount, 6);
        expect((doc.getNodeAt(0)! as ListItemNode).text.toPlainText(), 'First item');
        expect((doc.getNodeAt(1)! as ListItemNode).text.toPlainText(), 'Second item');
        expect((doc.getNodeAt(2)! as ListItemNode).text.toPlainText(), 'Third item');
        expect((doc.getNodeAt(3)! as ParagraphNode).text.toPlainText(), '');
        expect((doc.getNodeAt(4)! as ParagraphNode).text.toPlainText(), '');
        expect((doc.getNodeAt(5)! as ParagraphNode).text.toPlainText(), '');
      });

      test('multiple empty paragraphs between paragraphs', () {
        const input = """Paragraph1



Paragraph4""";
        final doc = deserializeMarkdownToDocument(input);

        expect(doc.nodeCount, 4);
        expect((doc.getNodeAt(0)! as ParagraphNode).text.toPlainText(), 'Paragraph1');
        expect((doc.getNodeAt(1)! as ParagraphNode).text.toPlainText(), '');
        expect((doc.getNodeAt(2)! as ParagraphNode).text.toPlainText(), '');
        expect((doc.getNodeAt(3)! as ParagraphNode).text.toPlainText(), 'Paragraph4');
      });

      test('hard-break spaces do not pull blank lines into a paragraph', () {
        // Previously, the trailing "  " made the blank line part of the
        // first paragraph, embedding a "\n" in its text. Blank lines now
        // always end the paragraph; the extra blank line is an empty
        // paragraph of its own.
        final doc = deserializeMarkdownToDocument('First Paragraph.  \n\n\nSecond Paragraph');
        expect(doc.nodeCount, 3);

        expect(doc.first, isA<ParagraphNode>());
        expect((doc.first as ParagraphNode).text.toPlainText(), 'First Paragraph.');

        expect((doc.getNodeAt(1)! as ParagraphNode).text.toPlainText(), '');

        expect(doc.last, isA<ParagraphNode>());
        expect((doc.last as ParagraphNode).text.toPlainText(), 'Second Paragraph');
      });

      test('whitespace-only lines count as blank lines', () {
        // "First Paragraph.  \n  \n  \n\n\nSecond Paragraph" is a paragraph,
        // four blank lines (two of them whitespace-only), and a paragraph:
        // one separator plus three empty paragraphs.
        final doc = deserializeMarkdownToDocument('First Paragraph.  \n  \n  \n\n\nSecond Paragraph');

        expect(doc.nodeCount, 5);

        expect(doc.first, isA<ParagraphNode>());
        expect((doc.first as ParagraphNode).text.toPlainText(), 'First Paragraph.');

        for (var i = 1; i <= 3; i += 1) {
          expect((doc.getNodeAt(i)! as ParagraphNode).text.toPlainText(), '');
        }

        expect(doc.last, isA<ParagraphNode>());
        expect((doc.last as ParagraphNode).text.toPlainText(), 'Second Paragraph');
      });

      test('blank lines in the middle split the paragraph', () {
        final doc =
            deserializeMarkdownToDocument('First Paragraph.  \n  \n  \nStill First Paragraph\n\nSecond Paragraph');

        expect(doc.nodeCount, 4);

        expect(doc.first, isA<ParagraphNode>());
        expect((doc.first as ParagraphNode).text.toPlainText(), 'First Paragraph.');

        expect((doc.getNodeAt(1)! as ParagraphNode).text.toPlainText(), '');

        expect((doc.getNodeAt(2)! as ParagraphNode).text.toPlainText(), 'Still First Paragraph');

        expect(doc.last, isA<ParagraphNode>());
        expect((doc.last as ParagraphNode).text.toPlainText(), 'Second Paragraph');
      });

      test('blank lines at the document start are empty paragraphs', () {
        final doc = deserializeMarkdownToDocument('  \n  \nFirst Paragraph.\n\nSecond Paragraph');

        expect(doc.nodeCount, 4);

        expect((doc.getNodeAt(0)! as ParagraphNode).text.toPlainText(), '');
        expect((doc.getNodeAt(1)! as ParagraphNode).text.toPlainText(), '');

        expect((doc.getNodeAt(2)! as ParagraphNode).text.toPlainText(), 'First Paragraph.');

        expect(doc.last, isA<ParagraphNode>());
        expect((doc.last as ParagraphNode).text.toPlainText(), 'Second Paragraph');
      });

      test('document ending with empty paragraphs', () {
        // "First Paragraph.\n\n\n" — one empty paragraph per trailing newline.
        final doc = deserializeMarkdownToDocument("""
First Paragraph.


""");

        expect(doc.nodeCount, 4);

        expect(doc.first, isA<ParagraphNode>());
        expect((doc.first as ParagraphNode).text.toPlainText(), 'First Paragraph.');

        for (var i = 1; i <= 3; i += 1) {
          expect((doc.getNodeAt(i)! as ParagraphNode).text.toPlainText(), '');
        }
      });

      test('document ending with a single trailing newline gains one empty paragraph', () {
        final doc = deserializeMarkdownToDocument('First Paragraph.\n');

        expect(doc.nodeCount, 2);
        expect((doc.first as ParagraphNode).text.toPlainText(), 'First Paragraph.');
        expect((doc.last as ParagraphNode).text.toPlainText(), '');
      });

      test('document without a trailing newline gains nothing', () {
        final doc = deserializeMarkdownToDocument('First Paragraph.');

        expect(doc.nodeCount, 1);
        expect((doc.first as ParagraphNode).text.toPlainText(), 'First Paragraph.');
      });

      test('empty markdown produces an empty paragraph', () {
        final doc = deserializeMarkdownToDocument('');

        expect(doc.nodeCount, 1);

        expect(doc.first, isA<ParagraphNode>());
        expect((doc.first as ParagraphNode).text.toPlainText(), '');
      });
    });

    group('whitespace policy', () {
      String roundTrip(String markdown) => serializeDocumentToMarkdown(deserializeMarkdownToDocument(markdown));

      test('external two-blank-line input parses to [paragraph, empty, paragraph]', () {
        final doc = deserializeMarkdownToDocument('A\n\n\nB');

        expect(doc.nodeCount, 3);
        expect((doc.getNodeAt(0)! as ParagraphNode).text.toPlainText(), 'A');
        expect((doc.getNodeAt(1)! as ParagraphNode).text.toPlainText(), '');
        expect((doc.getNodeAt(2)! as ParagraphNode).text.toPlainText(), 'B');
      });

      test('tight heading records tight metadata', () {
        final doc = deserializeMarkdownToDocument('# Title\nBody');

        expect(doc.nodeCount, 2);
        expect((doc.getNodeAt(0)! as ParagraphNode).getMetadataValue('tight'), true);

        final loose = deserializeMarkdownToDocument('# Title\n\nBody');
        expect(loose.nodeCount, 2);
        expect((loose.getNodeAt(0)! as ParagraphNode).getMetadataValue('tight'), isNot(true));
      });

      test('round-trips byte-identically', () {
        const cases = <String>[
          'A\n\nB', // separated paragraphs
          'A\n\n\nB', // one empty paragraph between blocks
          'A\n\n\n\nB', // two empty paragraphs between blocks
          'Line one\nLine two', // soft line break, no hard-break spaces
          '# Title\nBody', // tight heading
          '# Title\n\nBody', // heading with blank line
          'ends with newline\n', // single trailing newline
          'no trailing newline',
          'A\n\n', // trailing empty paragraph
          '\nA', // leading empty paragraph
          '\n\nA', // two leading empty paragraphs
          '', // empty document
          '\n', // newline-only document
          '- a\n- b', // tight list
          '- a\n', // list with trailing newline
          '- [ ] todo\n- [x] done', // task list
        ];

        for (final markdown in cases) {
          expect(roundTrip(markdown), markdown, reason: 'round trip of ${markdown.replaceAll('\n', r'\n')}');
        }
      });

      test('round-trip is idempotent for content the serializer rewrites', () {
        const cases = <String>[
          'First Paragraph.  \nSecond line', // legacy hard-break spaces are dropped
          'A  \n\nB', // legacy hard break before a blank line
          'para\n\n\n\npara', // legacy 2N+2 empty-paragraph encoding
        ];

        for (final markdown in cases) {
          final once = roundTrip(markdown);
          expect(roundTrip(once), once, reason: 'idempotency of ${markdown.replaceAll('\n', r'\n')}');
        }
      });

      test('legacy hard-break soft wrap heals to a plain soft wrap', () {
        // The old serializer wrote soft wraps as "  \n". Those notes
        // heal in one pass, with no text loss.
        expect(roundTrip('Line one  \nLine two'), 'Line one\nLine two');
      });

      test('notes saved under the old empty-paragraph scheme keep their bytes', () {
        // The old scheme wrote one empty paragraph as four newlines. That form
        // now parses as two empty paragraphs and serializes right back to the
        // same four newlines — stable bytes, no content loss.
        const oldForm = 'para\n\n\n\npara';
        final doc = deserializeMarkdownToDocument(oldForm);
        expect(doc.nodeCount, 4);
        expect(roundTrip(oldForm), oldForm);
      });
    });
  });
}

const exampleMarkdownDoc1 = '''
# Example 1
---
This is an example doc that has various types of nodes, like [links](https://example.org).

It includes multiple paragraphs, ordered list items, unordered list items, images, and HRs.

 * unordered item 1
 * unordered item 2
   * unordered item 2.1
   * unordered item 2.2
 * unordered item 3

---

 1. ordered item 1
 2. ordered item 2
   1. ordered item 2.1
   2. ordered item 2.2
 3. ordered item 3

---

![Image alt text](https://images.com/some/image.png)

- [ ] Pending task
with multiple lines

Another paragraph

- [x] Completed task

---

:---
# Example 1 With Left Alignment
:---:
# Example 1 With Center Alignment
---:
# Example 1 With Right Alignment
-::-
# Example 1 With Justify Alignment

The end!
''';
