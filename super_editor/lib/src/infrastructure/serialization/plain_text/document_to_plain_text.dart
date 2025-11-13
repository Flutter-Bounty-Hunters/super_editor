import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/text.dart';

extension ToPlainText on Document {
  /// Serializes this [Document] to a plain-text representation by writing the text
  /// from every [TextNode] to a `String`.
  ///
  /// Non-[TextNode]s are skipped. All attributions within [TextNode]s are ignored.
  /// Inline text placeholders are stripped out.
  String toPlainText({DocumentSelection? selection}) {
    final plainTextBuffer = StringBuffer();

    selection = selection ??
        DocumentSelection(
          base: DocumentPosition(nodeId: first.id, nodePosition: first.beginningPosition),
          extent: DocumentPosition(nodeId: last.id, nodePosition: last.endPosition),
        );
    final selectedRange = selection.normalize(this);
    final selectedNodes = getNodesInside(
      selectedRange.start,
      selectedRange.end,
    );

    for (final node in selectedNodes) {
      switch (node) {
        case TextNode():
          final textStart =
              node.id == selectedRange.start.nodeId ? (selectedRange.start.nodePosition as TextNodePosition).offset : 0;
          final textEnd = node.id == selectedRange.end.nodeId
              ? (selectedRange.end.nodePosition as TextNodePosition).offset
              : node.text.length;

          plainTextBuffer.write(
            "${node.text.copyText(textStart, textEnd).toPlainText(includePlaceholders: false)}\n",
          );
        default: // We don't know how to encode non-text nodes as plain text. Ignore.
      }
    }

    return plainTextBuffer.toString();
  }
}
