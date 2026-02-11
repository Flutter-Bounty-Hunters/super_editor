import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

import 'custom_parsers/callout_block.dart';
import 'custom_parsers/upsell_block.dart';

void main() {
  group("Markdown serialization", () {
    test("handles custom placeholder block node", () {
      final markdown = serializeDocumentToMarkdown(
        MutableDocument(
          nodes: [
            ParagraphNode(id: Editor.createNodeId(), text: AttributedText("Paragraph 1")),
            UpsellNode(Editor.createNodeId()),
            ParagraphNode(id: Editor.createNodeId(), text: AttributedText("Paragraph 2")),
          ],
        ),
        customNodeSerializers: [UpsellSerializer()],
      );

      expect(
        markdown,
        '''Paragraph 1

@@@ upsell

Paragraph 2''',
      );
    });

    test("handles custom text node", () {
      final markdown = serializeDocumentToMarkdown(
        MutableDocument(
          nodes: [
            ParagraphNode(
              id: Editor.createNodeId(),
              text: AttributedText("Paragraph 1"),
            ),
            ParagraphNode(
              id: Editor.createNodeId(),
              text: attributedTextFromMarkdown("This is a **callout!**"),
              metadata: const {
                "blockType": NamedAttribution("callout"),
              },
            ),
            ParagraphNode(id: Editor.createNodeId(), text: AttributedText("Paragraph 2")),
          ],
        ),
        customNodeSerializers: [CalloutSerializer()],
      );

      expect(
        markdown,
        '''Paragraph 1

@@@ callout
This is a **callout!**
@@@

Paragraph 2''',
      );
    });
  });
}
