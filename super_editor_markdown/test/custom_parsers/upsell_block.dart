import 'package:markdown/markdown.dart' as md;
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_markdown/super_editor_markdown.dart';

/// A [DocumentNode] that represents a placeholder for an "upsell message".
///
/// Consider a blog post. The author might like to display an advertisement,
/// or an upsell message after the first paragraph. A developer could include
/// an [UpsellNode] in the [Document] after the first paragraph, and then the
/// corresponding [SuperReader] could render the desired upsell message. Perhaps
/// the upsell widget is chosen by the server, so that the upsell message can
/// change on all blog posts over time. As a result, this node, and its component
/// in the [SuperReader] are just placeholders for content that will be chosen
/// when rendered.
class UpsellNode extends BlockNode {
  UpsellNode(this.id);

  @override
  final String id;

  @override
  UpsellNode copyAndReplaceMetadata(Map<String, dynamic> newMetadata) {
    return UpsellNode(id);
  }

  @override
  UpsellNode copyWithAddedMetadata(Map<String, dynamic> newProperties) {
    return UpsellNode(id);
  }

  @override
  String? copyContent(NodeSelection selection) {
    return null;
  }

  DocumentNode copy() {
    return UpsellNode(id);
  }
}

/// Markdown block-parser for upsell messages.
///
/// This [BlockSyntax] produces an [md.Element] with the name "upsell".
class UpsellBlockSyntax extends md.BlockSyntax {
  @override
  RegExp get pattern => RegExp(r'^@@@\s*upsell\s*$');

  const UpsellBlockSyntax();

  @override
  md.Node parse(md.BlockParser parser) {
    parser.advance();
    return md.Element('upsell', []);
  }
}

/// An [ElementToNodeConverter] that converts an "upsell" Markdown [md.Element]
/// to an [UpsellNode].
class UpsellElementToNodeConverter implements ElementToNodeConverter {
  @override
  DocumentNode? handleElement(md.Element element) {
    if (element.tag != "upsell") {
      return null;
    }

    return UpsellNode(Editor.createNodeId());
  }
}

class UpsellSerializer extends NodeTypedDocumentNodeMarkdownSerializer<UpsellNode> {
  @override
  String doSerialization(Document document, UpsellNode node, {NodeSelection? selection}) {
    return "@@@ upsell\n";
  }
}
