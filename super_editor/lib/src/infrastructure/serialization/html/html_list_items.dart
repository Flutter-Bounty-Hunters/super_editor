import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/default_editor/list_items.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/serialization/html/html_inline_text_styles.dart';

String? defaultListItemToHtmlSerializer(
  Document document,
  DocumentNode node,
  NodeSelection? selection,
  InlineHtmlSerializerChain inlineSerializers,
) {
  if (node is! ListItemNode) {
    return null;
  }
  if (selection != null && selection is! TextNodeSelection) {
    // We don't know how to handle this selection type.
    return null;
  }
  final textSelection = selection as TextNodeSelection?;

  return node.toHtml(document, inlineSerializers, start: textSelection?.start, end: textSelection?.end);
}

extension ListItemNodeToHtml on ListItemNode {
  String toHtml(Document document, InlineHtmlSerializerChain inlineSerializers, {int? start, int? end}) {
    if (start != null && start == end) {
      // Selection is collapsed. Nothing is selected for copy.
      return "";
    }

    final content = text.toHtml(serializers: inlineSerializers, start: start, end: end);

    final nodeBefore = document.getNodeBeforeById(id);
    final isListStart = nodeBefore == null || nodeBefore is! ListItemNode || nodeBefore.type != type;

    final nodeAfter = document.getNodeAfterById(id);
    final isListEnd = nodeAfter == null || nodeAfter is! ListItemNode || nodeAfter.type != type;

    final htmlBuffer = StringBuffer();

    if (isListStart) {
      switch (type) {
        case ListItemType.ordered:
          htmlBuffer.write('<ol>');
        case ListItemType.unordered:
          htmlBuffer.write('<ul>');
      }
    }

    htmlBuffer.write('<li>$content</li>');

    if (isListEnd) {
      switch (type) {
        case ListItemType.ordered:
          htmlBuffer.write('</ol>');
        case ListItemType.unordered:
          htmlBuffer.write('</ul>');
      }
    }

    return htmlBuffer.toString();
  }
}
