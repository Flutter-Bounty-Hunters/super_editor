import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/default_editor/paragraph.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/serialization/html/html_inline_text_styles.dart';

String? defaultParagraphToHtmlSerializer(
  Document document,
  DocumentNode node,
  NodeSelection? selection,
  InlineHtmlSerializerChain inlineSerializers,
) {
  if (node is! ParagraphNode) {
    return null;
  }
  if (node.getMetadataValue(NodeMetadata.blockType) != paragraphAttribution) {
    return null;
  }
  if (selection != null && selection is! TextNodeSelection) {
    // We don't know how to handle this selection type.
    return null;
  }

  final textSelection = selection as TextNodeSelection?;
  if (true == textSelection?.isCollapsed) {
    // Nothing is selected.
    return "";
  }

  final content = node.text.toHtml(
    serializers: inlineSerializers,
    start: textSelection?.start,
    end: textSelection?.end,
  );
  return '<p>$content</p>';
}
