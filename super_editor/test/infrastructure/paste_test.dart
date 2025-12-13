import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/test/super_editor_test/supereditor_test_tools.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group("Paste >", () {
    group("multi-node content >", () {
      test("paste single paragraph into empty paragraph", () {
        final editor = createDefaultDocumentEditor(
          document: MutableDocument(
            nodes: [ParagraphNode(id: "1", text: AttributedText())],
          ),
        );

        editor.execute([
          PasteStructuredContentEditorRequest(
            content: MutableDocument(
              nodes: [
                ParagraphNode(id: "2", text: AttributedText("Hello, World!")),
              ],
            ),
            pastePosition: const DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 0)),
          ),
        ]);

        expect(
          editor.document,
          documentEquivalentTo(
            MutableDocument(
              nodes: [
                ParagraphNode(id: "1", text: AttributedText("Hello, World!")),
              ],
            ),
          ),
        );
        expect(
          editor.composer.selection,
          const DocumentSelection.collapsed(
            position: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 13)),
          ),
        );
      });

      test("paste single paragraph into middle of paragraph", () {
        final editor = createDefaultDocumentEditor(
          document: MutableDocument(
            nodes: [ParagraphNode(id: "1", text: AttributedText("abcdefghi"))],
          ),
        );

        editor.execute([
          PasteStructuredContentEditorRequest(
            content: MutableDocument(
              nodes: [
                ParagraphNode(id: "2", text: AttributedText("Hello, World!")),
              ],
            ),
            pastePosition: const DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 4)),
          ),
        ]);

        expect(
          editor.document,
          documentEquivalentTo(
            MutableDocument(
              nodes: [
                ParagraphNode(id: "1", text: AttributedText("abcdHello, World!efghi")),
              ],
            ),
          ),
        );
        expect(
          editor.composer.selection,
          const DocumentSelection.collapsed(
            position: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 17)),
          ),
        );
      });

      test("paste table in empty paragraph", () {
        final editor = createDefaultDocumentEditor(
          document: MutableDocument(
            nodes: [ParagraphNode(id: "1", text: AttributedText())],
          ),
        );

        // Place the caret so we know where to paste.
        editor.execute([
          const ChangeSelectionRequest(
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 0),
              ),
            ),
            SelectionChangeType.placeCaret,
            SelectionReason.userInteraction,
          ),
        ]);

        // Paste a table.
        editor.execute([
          PasteStructuredContentEditorRequest(
            content: MutableDocument(nodes: [
              _table,
            ]),
            pastePosition: const DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 0),
            ),
          ),
        ]);

        // Ensure the HTML was turned into the expected document, with the
        // expected selection.
        expect(
          editor.document,
          documentEquivalentTo(
            MutableDocument(
              nodes: [
                _table,
                ParagraphNode(id: editor.document.last.id, text: AttributedText()),
              ],
            ),
          ),
        );
        expect(
          editor.composer.selection,
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: editor.document.last.id,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
        );
      });

      test("paste table in middle of paragraph", () {
        final editor = createDefaultDocumentEditor(
          document: MutableDocument(
            nodes: [ParagraphNode(id: "1", text: AttributedText("abcdefgh"))],
          ),
        );

        // Place the caret so we know where to paste.
        editor.execute([
          const ChangeSelectionRequest(
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 4),
              ),
            ),
            SelectionChangeType.placeCaret,
            SelectionReason.userInteraction,
          ),
        ]);

        // Paste a table.
        editor.execute([
          PasteStructuredContentEditorRequest(
            content: MutableDocument(nodes: [
              _table,
            ]),
            pastePosition: const DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 4),
            ),
          ),
        ]);

        // Ensure the HTML was turned into the expected document, with the
        // expected selection.
        expect(
          editor.document,
          documentEquivalentTo(
            MutableDocument(
              nodes: [
                ParagraphNode(id: "1", text: AttributedText("abcd")),
                _table,
                ParagraphNode(id: editor.document.last.id, text: AttributedText("efgh")),
              ],
            ),
          ),
        );
        expect(
          editor.composer.selection,
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: editor.document.last.id,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
        );
      });

      test("paste multiple nodes into empty paragraph", () {
        final editor = createDefaultDocumentEditor(
          document: MutableDocument(
            nodes: [ParagraphNode(id: "1", text: AttributedText())],
          ),
        );

        editor.execute([
          PasteStructuredContentEditorRequest(
            content: MutableDocument(
              nodes: [
                ParagraphNode(id: "2", text: AttributedText("One")),
                ParagraphNode(id: "3", text: AttributedText("Two")),
                ParagraphNode(id: "4", text: AttributedText("Three")),
              ],
            ),
            pastePosition: const DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 0)),
          ),
        ]);

        expect(
          editor.document,
          documentEquivalentTo(
            MutableDocument(
              nodes: [
                ParagraphNode(id: "1", text: AttributedText("One")),
                ParagraphNode(id: "3", text: AttributedText("Two")),
                ParagraphNode(id: "4", text: AttributedText("Three")),
              ],
            ),
          ),
        );
        expect(
          editor.composer.selection,
          const DocumentSelection.collapsed(
            position: DocumentPosition(nodeId: "4", nodePosition: TextNodePosition(offset: 5)),
          ),
        );
      });

      test("paste multiple nodes into middle of paragraph", () {
        final editor = createDefaultDocumentEditor(
          document: MutableDocument(
            nodes: [ParagraphNode(id: "1", text: AttributedText("abcdefghi"))],
          ),
        );

        editor.execute([
          PasteStructuredContentEditorRequest(
            content: MutableDocument(
              nodes: [
                ParagraphNode(id: "2", text: AttributedText("One")),
                ParagraphNode(id: "3", text: AttributedText("Two")),
                ParagraphNode(id: "4", text: AttributedText("Three")),
              ],
            ),
            pastePosition: const DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 4)),
          ),
        ]);

        expect(
          editor.document,
          documentEquivalentTo(
            MutableDocument(
              nodes: [
                ParagraphNode(id: "1", text: AttributedText("abcdOne")),
                ParagraphNode(id: "3", text: AttributedText("Two")),
                ParagraphNode(id: "4", text: AttributedText("Threeefghi")),
              ],
            ),
          ),
        );

        expect(
          editor.composer.selection,
          DocumentSelection.collapsed(
            position:
                DocumentPosition(nodeId: editor.document.last.id, nodePosition: const TextNodePosition(offset: 5)),
          ),
        );
      });
    });
  });
}

final _table = TableBlockNode(id: "table", cells: [
  [
    TextNode(
      id: "1.1",
      text: AttributedText("BMI Category"),
      metadata: const {
        NodeMetadata.blockType: tableHeaderAttribution,
      },
    ),
    TextNode(
      id: "1.2",
      text: AttributedText("BMI Range (kg/m²)"),
      metadata: const {
        NodeMetadata.blockType: tableHeaderAttribution,
      },
    ),
  ],
  [
    TextNode(
      id: "2.1",
      text: AttributedText("Underweight"),
    ),
    TextNode(
      id: "2.2",
      text: AttributedText("< 18.5"),
    ),
  ],
  [
    TextNode(
      id: "3.1",
      text: AttributedText("Normal weight"),
    ),
    TextNode(
      id: "3.2",
      text: AttributedText("18.5 – 24.9"),
    ),
  ],
  [
    TextNode(
      id: "4.1",
      text: AttributedText("Overweight"),
    ),
    TextNode(
      id: "4.2",
      text: AttributedText("25.0 - 29.9"),
    ),
  ],
  [
    TextNode(
      id: "5.1",
      text: AttributedText("Obesity (Class I)"),
    ),
    TextNode(
      id: "5.2",
      text: AttributedText("30.0 - 34.9"),
    ),
  ],
  [
    TextNode(
      id: "6.1",
      text: AttributedText("Obesity (Class II)"),
    ),
    TextNode(
      id: "6.2",
      text: AttributedText("35.0 - 39.9"),
    ),
  ],
  [
    TextNode(
      id: "7.1",
      text: AttributedText("Obesity (Class III)"),
    ),
    TextNode(
      id: "7.2",
      text: AttributedText("≥ 40.0"),
    ),
  ],
]);
