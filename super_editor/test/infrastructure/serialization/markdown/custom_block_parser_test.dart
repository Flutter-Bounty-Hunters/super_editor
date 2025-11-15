import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

import 'custom_parsers/callout_block.dart';
import 'custom_parsers/upsell_block.dart';

void main() {
  group("Markdown deserialization", () {
    test("handles custom placeholder block syntax", () {
      final document = deserializeMarkdownToDocument(
        '''# Header 1
This is a normal paragraph.

@@@ upsell
  
This is another normal paragraph.''',
        customBlockSyntax: [const UpsellBlockSyntax()],
        customElementToNodeConverters: [UpsellElementToNodeConverter()],
      );

      expect(document.nodeCount, 4);
      expect(
        document.getNodeAt(0)!,
        isA<ParagraphNode>(),
      );
      expect(
        document.getNodeAt(1)!,
        isA<ParagraphNode>(),
      );
      expect(
        document.getNodeAt(2)!,
        isA<UpsellNode>(),
      );
      expect(
        document.getNodeAt(3)!,
        isA<ParagraphNode>(),
      );
    });

    test("handles custom text block syntax", () {
      final document = deserializeMarkdownToDocument(
        '''# Header 1
This is a normal paragraph.

@@@ callout
This is a **callout**!
@@@
  
This is another normal paragraph.''',
        customBlockSyntax: [const CalloutBlockSyntax()],
        customElementToNodeConverters: [CalloutElementToNodeConverter()],
      );

      expect(document.nodeCount, 4);
      expect(
        document.getNodeAt(0)!,
        isA<ParagraphNode>(),
      );
      expect(
        document.getNodeAt(1)!,
        isA<ParagraphNode>(),
      );
      expect(
        document.getNodeAt(2)!,
        isA<ParagraphNode>(),
      );
      expect(
        (document.getNodeAt(2)! as ParagraphNode).metadata["blockType"],
        const NamedAttribution("callout"),
      );
      expect(
        document.getNodeAt(3)!,
        isA<ParagraphNode>(),
      );
    });
  });
}
