import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/infrastructure/serialization/html/html_blockquotes.dart';
import 'package:super_editor/src/infrastructure/serialization/html/html_code.dart';
import 'package:super_editor/src/infrastructure/serialization/html/html_headers.dart';
import 'package:super_editor/src/infrastructure/serialization/html/html_horizontal_rules.dart';
import 'package:super_editor/src/infrastructure/serialization/html/html_images.dart';
import 'package:super_editor/src/infrastructure/serialization/html/html_inline_text_styles.dart';
import 'package:super_editor/src/infrastructure/serialization/html/html_list_items.dart';
import 'package:super_editor/src/infrastructure/serialization/html/html_paragraphs.dart';
import 'package:super_editor/src/infrastructure/serialization/html/html_table.dart';

extension HtmlSerialization on Document {
  /// Converts this [Document] to an HTML representation.
  ///
  /// When [selection] is `null`, the entire document is converted to HTML. When
  /// [selection] is non-`null`, only the selected content is converted to HTML.
  ///
  /// When [skipUnknownNodes] is `true`, nodes that don't have an HTML serializer
  /// will be ignored. When it's `false`, an exception will be thrown.
  String toHtml({
    DocumentSelection? selection,
    NodeHtmlSerializerChain nodeSerializers = defaultNodeHtmlSerializerChain,
    InlineHtmlSerializerChain inlineSerializers = defaultInlineHtmlSerializers,
    bool skipUnknownNodes = true,
  }) {
    final htmlBuffer = StringBuffer();

    if (selection != null && selection.isCollapsed) {
      // The selection is collapsed to a single position, which by definition can't
      // contain any content.
      return "";
    }

    late final DocumentRange? selectedRange;
    late final List<DocumentNode> selectedNodes;
    if (selection != null) {
      selectedRange = selection.normalize(this);
      selectedNodes = getNodesInside(
        selectedRange.start,
        selectedRange.end,
      );
    } else {
      selectedRange = null;
      selectedNodes = toList(growable: false);
    }

    for (final node in selectedNodes) {
      late final NodeSelection? nodeSelection;
      if (selectedRange != null && node.id == selectedRange.start.nodeId && node.id == selectedRange.end.nodeId) {
        // The entire copy selection is within this node.
        nodeSelection = node.computeSelection(
          base: selectedRange.start.nodePosition,
          extent: selectedRange.end.nodePosition,
        );
      } else if (selectedRange != null && node.id == selectedRange.start.nodeId) {
        // The selection starts somewhere in this node and goes to the end of the node.
        nodeSelection = node.computeSelection(
          base: selectedRange.start.nodePosition,
          extent: node.endPosition,
        );
      } else if (selectedRange != null && node.id == selectedRange.end.nodeId) {
        // The selection starts at the beginning of this node and ends somewhere within this node.
        nodeSelection = node.computeSelection(
          base: node.beginningPosition,
          extent: selectedRange.end.nodePosition,
        );
      } else {
        nodeSelection = null;
      }

      bool didSerializeNode = false;
      for (final serializer in nodeSerializers) {
        final html = serializer(this, node, nodeSelection, inlineSerializers);
        if (html != null) {
          htmlBuffer.write(html);
          didSerializeNode = true;
          break;
        }
      }
      if (!didSerializeNode && !skipUnknownNodes) {
        throw Exception("Tried to serialize node ($node) but couldn't find a compatible HTML serializer.");
      }
    }

    return htmlBuffer.toString();
  }
}

/// The standard HTML serializers for every type of [DocumentNode] in a [Document].
///
/// To customize how [Document]s are serialized to HTML, create a custom list of serializers
/// as needed, and pass that chain into the HTML serializer.
const NodeHtmlSerializerChain defaultNodeHtmlSerializerChain = [
  defaultImageToHtmlSerializer,
  defaultHorizontalRuleToHtmlSerializer,
  defaultListItemToHtmlSerializer,
  defaultHeaderToHtmlSerializer,
  defaultBlockquoteToHtmlSerializer,
  defaultCodeBlockToHtmlSerializer,
  defaultParagraphToHtmlSerializer,
  defaultTableToHtmlSerializer,
];

/// A priority-order list of [NodeHtmlSerializer]s, which can be used to serialize
/// an entire [Document] of nodes.
typedef NodeHtmlSerializerChain = List<NodeHtmlSerializer>;

/// A function that (maybe) serializes the given [node] to HTML.
typedef NodeHtmlSerializer = String? Function(
  Document document,
  DocumentNode node,
  NodeSelection? selection,
  InlineHtmlSerializerChain inlineSerializers,
);
