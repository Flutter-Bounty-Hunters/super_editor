import 'package:flutter/material.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';
import 'package:super_editor/src/default_editor/tables/table_block.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/serialization/html/html_inline_text_styles.dart';

/// Serializes a [TableBlockNode] to HTML.
///
/// Table rows that contain only header cells (i.e., cells with the [tableHeaderAttribution]
/// metadata) and appear at the beginning of the table are serialized inside a `<thead>` element.
///
/// All other rows are serialized inside a `<tbody>` element.
///
/// Each cell with the [tableHeaderAttribution] metadata is serialized as a `<th>` element.
///
/// If the [selection] is non-`null`, it must be an [UpstreamDownstreamNodeSelection]. Returns
/// an empty string if the selection is collapsed.
String? defaultTableToHtmlSerializer(
  Document document,
  DocumentNode node,
  NodeSelection? selection,
  InlineHtmlSerializerChain inlineSerializers,
) {
  if (node is! TableBlockNode) {
    return null;
  }
  if (selection != null) {
    if (selection is! UpstreamDownstreamNodeSelection) {
      // We don't know how to handle this selection type.
      return null;
    }
    if (selection.isCollapsed) {
      // This selection doesn't include the table - it's a collapsed selection
      // either on the upstream or downstream edge. Return an empty string to
      // signal we handled the serialization, but there's no content to include.
      return '';
    }
  }

  return node.toHtml(document, inlineSerializers);
}

extension TableBlockNodeToHtml on TableBlockNode {
  String toHtml(Document document, InlineHtmlSerializerChain inlineSerializers) {
    final htmlBuffer = StringBuffer();
    htmlBuffer.write('<table>');

    final headers = <List<TextNode>>[];
    final dataRows = <List<TextNode>>[];

    for (int i = 0; i < rowCount; i++) {
      final row = getRow(i);

      if (dataRows.isNotEmpty) {
        // We already have data rows. Each row after the first data row is also
        // a data row.
        dataRows.add(row);
        continue;
      }

      bool doesRowContainOnlyHeaders = true;
      for (final cell in row) {
        if (cell.getMetadataValue(NodeMetadata.blockType) != tableHeaderAttribution) {
          doesRowContainOnlyHeaders = false;
          break;
        }
      }

      if (doesRowContainOnlyHeaders) {
        headers.add(row);
      } else {
        dataRows.add(row);
      }
    }

    if (headers.isNotEmpty) {
      htmlBuffer.write('<thead>');
      for (final headerRow in headers) {
        htmlBuffer.write('<tr>');
        for (final cell in headerRow) {
          final cellContent = cell.text.toHtml(
            serializers: inlineSerializers,
          );
          htmlBuffer.write('<th${_getTextAlignStyle(cell)}>$cellContent</th>');
        }
        htmlBuffer.write('</tr>');
      }
      htmlBuffer.write('</thead>');
    }

    if (dataRows.isNotEmpty) {
      htmlBuffer.write('<tbody>');
      for (final row in dataRows) {
        htmlBuffer.write('<tr>');
        for (final cell in row) {
          final cellContent = cell.text.toHtml(
            serializers: inlineSerializers,
          );
          final tag = cell.getMetadataValue(NodeMetadata.blockType) == tableHeaderAttribution ? 'th' : 'td';
          htmlBuffer.write('<$tag${_getTextAlignStyle(cell)}>$cellContent</$tag>');
        }
        htmlBuffer.write('</tr>');
      }
      htmlBuffer.write('</tbody>');
    }

    htmlBuffer.write('</table>');
    return htmlBuffer.toString();
  }

  String _getTextAlignStyle(TextNode cell) {
    final textAlign = cell.getMetadataValue('textAlign');
    if (textAlign == TextAlign.left) {
      // Default alignment is left, so we don't need to specify it.
      return '';
    }
    final textAlignString = switch (textAlign) {
      TextAlign.center => 'center',
      TextAlign.right => 'right',
      _ => 'left',
    };
    return textAlign != null ? ' style="text-align:$textAlignString"' : '';
  }
}
