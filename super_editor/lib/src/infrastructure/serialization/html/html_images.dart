import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/default_editor/image.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';
import 'package:super_editor/src/infrastructure/serialization/html/html_inline_text_styles.dart';

String? defaultImageToHtmlSerializer(
  Document document,
  DocumentNode node,
  NodeSelection? selection,
  InlineHtmlSerializerChain inlineSerializers,
) {
  if (node is! ImageNode) {
    return null;
  }
  if (selection != null) {
    if (selection is! UpstreamDownstreamNodeSelection) {
      // We don't know how to handle this selection type.
      return null;
    }
    if (selection.isCollapsed) {
      // This selection doesn't include the image - it's a collapsed selection
      // either on the upstream or downstream edge.
      return null;
    }
  }

  return '<img src="${node.imageUrl}">';
}
