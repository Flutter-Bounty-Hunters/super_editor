import 'package:attributed_text/attributed_text.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/default_editor/paragraph.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/serialization/html/html_inline_text_styles.dart';

String? defaultHeaderToHtmlSerializer(
  Document document,
  DocumentNode node,
  NodeSelection? selection,
  InlineHtmlSerializerChain inlineSerializers,
) {
  if (node is! ParagraphNode) {
    return null;
  }

  final headerType = node.getMetadataValue(NodeMetadata.blockType);
  if (!const [
    header1Attribution,
    header2Attribution,
    header3Attribution,
    header4Attribution,
    header5Attribution,
    header6Attribution,
  ].contains(headerType)) {
    // Not a header.
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

  final openTag = _openTag(headerType);
  final closeTag = _closeTag(headerType);
  final content = node.text.toHtml(
    serializers: inlineSerializers,
    start: textSelection?.start,
    end: textSelection?.end,
  );
  return '$openTag$content$closeTag';
}

String _openTag(Attribution headerType) {
  return _tag(headerType, isOpening: true);
}

String _closeTag(Attribution headerType) {
  return _tag(headerType, isOpening: false);
}

String _tag(Attribution headerType, {required bool isOpening}) {
  return switch (headerType) {
    header1Attribution => isOpening ? "<h1>" : "</h1>",
    header2Attribution => isOpening ? "<h2>" : "</h2>",
    header3Attribution => isOpening ? "<h3>" : "</h3>",
    header4Attribution => isOpening ? "<h4>" : "</h4>",
    header5Attribution => isOpening ? "<h5>" : "</h5>",
    header6Attribution => isOpening ? "<h6>" : "</h6>",
    _ => throw Exception(
        "Tried to create HTML tag for a header block, but we don't recognize this block type: $headerType"),
  };
}
