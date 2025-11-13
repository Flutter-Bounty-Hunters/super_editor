import 'dart:ui';

import 'package:markdown/markdown.dart' as md;
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_markdown/src/markdown_inline_parser.dart';

extension ElementTableExtension on md.Element {
  /// Converts this element to a [TableBlockNode].
  ///
  /// The element must have a `table` tag.
  ///
  /// Throws an exception if the element is not a valid table structure.
  TableBlockNode asTable({
    Iterable<md.InlineSyntax>? inlineMarkdownSyntaxes,
    Iterable<InlineHtmlSyntax>? inlineHtmlSyntaxes,
  }) {
    if (tag != 'table') {
      throw Exception('Cannot parse a table from an element with tag "$tag"');
    }

    if (children == null || children!.isEmpty) {
      throw Exception('A table must have at least one child element');
    }

    final cells = <List<TextNode>>[];

    final headerElement = children![0];
    if (headerElement is! md.Element || headerElement.tag != 'thead') {
      throw Exception('Table header must be a <thead> element');
    }
    if (headerElement.children == null || headerElement.children!.isEmpty) {
      throw Exception('Table header must have a row');
    }

    final headerRow = headerElement.children![0];
    if (headerRow is! md.Element || headerRow.tag != 'tr') {
      throw Exception('Table header row must be a <tr> element');
    }

    final headerNodes = <TextNode>[];
    for (final headerCell in headerRow.children!) {
      if (headerCell is! md.Element || headerCell.tag != 'th') {
        throw Exception('Table header cells must be <th> elements');
      }
      headerNodes.add(
        TextNode(
          id: Editor.createNodeId(),
          text: parseInlineMarkdown(
            headerCell.textContent,
            inlineMarkdownSyntaxes: inlineMarkdownSyntaxes,
            inlineHtmlSyntaxes: inlineHtmlSyntaxes,
          ),
          metadata: const {
            NodeMetadata.blockType: tableHeaderAttribution,
            TextNodeMetadata.textAlign: TextAlign.center,
          },
        ),
      );
    }
    cells.add(headerNodes);

    if (children!.length >= 2) {
      // The table contains the table body element.
      final bodyElement = children![1];
      if (bodyElement is! md.Element || bodyElement.tag != 'tbody') {
        throw Exception('Table body must be a <tbody> element');
      }

      for (final rowElement in bodyElement.children!) {
        if (rowElement is! md.Element || rowElement.tag != 'tr') {
          throw Exception('Table body rows must be <tr> elements');
        }

        final row = <TextNode>[];
        for (int i = 0; i < rowElement.children!.length; i++) {
          final cellElement = rowElement.children![i];
          if (cellElement is! md.Element || cellElement.tag != 'td') {
            throw Exception('Table body cells must be <td> elements');
          }
          final textAlign = switch ((headerRow.children![i] as md.Element).attributes['align']) {
            'left' => TextAlign.left,
            'center' => TextAlign.center,
            'right' => TextAlign.right,
            _ => TextAlign.left,
          };

          row.add(TextNode(
            id: Editor.createNodeId(),
            text: parseInlineMarkdown(cellElement.textContent),
            metadata: {
              if (textAlign != TextAlign.left) TextNodeMetadata.textAlign: textAlign,
            },
          ));
        }
        cells.add(row);
      }
    }

    return TableBlockNode(
      id: Editor.createNodeId(),
      cells: cells,
    );
  }
}
