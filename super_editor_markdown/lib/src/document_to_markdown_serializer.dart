import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:super_editor/super_editor.dart';

import 'super_editor_syntax.dart';

/// Serializes the given [doc] to Markdown text.
///
/// When [selection] is provided, only the selected range of the document is serialized.
///
/// The given [syntax] controls how the [doc] is serialized, e.g., [MarkdownSyntax.normal]
/// for standard Markdown syntax, or [MarkdownSyntax.superEditor] to use Super Editor's
/// extended syntax.
///
/// To serialize [DocumentNode]s that aren't part of Super Editor's standard serialization,
/// provide [customNodeSerializers] to serialize those custom nodes.
String serializeDocumentToMarkdown(
  Document doc, {
  DocumentSelection? selection,
  MarkdownSyntax syntax = MarkdownSyntax.superEditor,
  List<DocumentNodeMarkdownSerializer> customNodeSerializers = const [],
}) {
  final nodeSerializers = [
    // Custom serializers first, in case the custom serializers handle
    // specialized cases of traditional nodes, such as serializing a
    // `ParagraphNode` with a special `"blockType"`.
    ...customNodeSerializers,
    ImageNodeSerializer(useSizeNotation: syntax == MarkdownSyntax.superEditor),
    const HorizontalRuleNodeSerializer(),
    const ListItemNodeSerializer(),
    const TaskNodeSerializer(),
    HeaderNodeSerializer(syntax),
    ParagraphNodeSerializer(syntax),
    const TableBlockNodeSerializer(),
  ];

  StringBuffer buffer = StringBuffer();

  late final DocumentRange? selectedRange;
  late final List<DocumentNode> selectedNodes;
  if (selection != null) {
    selectedRange = selection.normalize(doc);
    selectedNodes = doc.getNodesInside(
      selectedRange.start,
      selectedRange.end,
    );
  } else {
    selectedRange = null;
    selectedNodes = doc.toList(growable: false);
  }

  for (int i = 0; i < selectedNodes.length; ++i) {
    final node = selectedNodes[i];
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
      // The node is fully selected, so we don't need to specify a selection.
      nodeSelection = null;
    }

    for (final serializer in nodeSerializers) {
      final serialization = serializer.serialize(doc, node, selection: nodeSelection);
      if (serialization != null) {
        if (i > 0) {
          // Add a new line before every node, except the first node.
          buffer.writeln("");
        }

        buffer.write(serialization);
        break;
      }
    }
  }

  return buffer.toString();
}

/// Serializes a given [DocumentNode] to a Markdown `String`.
abstract class DocumentNodeMarkdownSerializer {
  /// Serializes the given [node] to a Markdown `String`.
  ///
  /// When [selection] is `null`, the entire node is converted to markdown. When
  /// [selection] is non-`null`, only the selected range is converted to markdown.
  ///
  /// Returns `null` if the [node] is not supported by this serializer.
  String? serialize(
    Document document,
    DocumentNode node, {
    NodeSelection? selection,
  });
}

/// A [DocumentNodeMarkdownSerializer] that automatically rejects any
/// [DocumentNode] that doesn't match the given [NodeType].
///
/// Use this base class to avoid repeating type checks across various
/// serializers.
abstract class NodeTypedDocumentNodeMarkdownSerializer<NodeType> implements DocumentNodeMarkdownSerializer {
  const NodeTypedDocumentNodeMarkdownSerializer();

  @override
  String? serialize(
    Document document,
    DocumentNode node, {
    NodeSelection? selection,
  }) {
    if (node is! NodeType) {
      return null;
    }

    return doSerialization(document, node as NodeType, selection: selection);
  }

  @protected
  String doSerialization(
    Document document,
    NodeType node, {
    NodeSelection? selection,
  });
}

/// [DocumentNodeMarkdownSerializer] for serializing [ImageNode]s as standard Markdown
/// images.
class ImageNodeSerializer extends NodeTypedDocumentNodeMarkdownSerializer<ImageNode> {
  const ImageNodeSerializer({
    this.useSizeNotation = false,
  });

  final bool useSizeNotation;

  @override
  String doSerialization(
    Document document,
    ImageNode node, {
    NodeSelection? selection,
  }) {
    if (selection != null) {
      if (selection is! UpstreamDownstreamNodeSelection) {
        // We don't know how to handle this selection type.
        return '';
      }
      if (selection.isCollapsed) {
        // This selection doesn't include the image - it's a collapsed selection
        // either on the upstream or downstream edge.
        return '';
      }
    }

    if (!useSizeNotation || (node.expectedBitmapSize?.width == null && node.expectedBitmapSize?.height == null)) {
      // We don't want to use size notation or the image doesn't have
      // size information. Use the regular syntax.
      return '![${node.altText}](${node.imageUrl})';
    }

    StringBuffer sizeNotation = StringBuffer();
    sizeNotation.write(' =');

    if (node.expectedBitmapSize?.width != null) {
      sizeNotation.write(node.expectedBitmapSize!.width!.toInt());
    }

    sizeNotation.write('x');

    if (node.expectedBitmapSize?.height != null) {
      sizeNotation.write(node.expectedBitmapSize!.height!.toInt());
    }

    return '![${node.altText}](${node.imageUrl}${sizeNotation.toString()})';
  }
}

/// [DocumentNodeMarkdownSerializer] for serializing [HorizontalRuleNode]s as standard
/// Markdown horizontal rules.
class HorizontalRuleNodeSerializer extends NodeTypedDocumentNodeMarkdownSerializer<HorizontalRuleNode> {
  const HorizontalRuleNodeSerializer();

  @override
  String doSerialization(
    Document document,
    HorizontalRuleNode node, {
    NodeSelection? selection,
  }) {
    if (selection != null) {
      if (selection is! UpstreamDownstreamNodeSelection) {
        // We don't know how to handle this selection type.
        return '';
      }
      if (selection.isCollapsed) {
        // This selection doesn't include the horizontal rule - it's a collapsed selection
        // either on the upstream or downstream edge.
        return '';
      }
    }

    return '---';
  }
}

/// [DocumentNodeMarkdownSerializer] for serializing [ListItemNode]s as standard Markdown
/// list items.
///
/// Includes support for ordered and unordered list items.
class ListItemNodeSerializer extends NodeTypedDocumentNodeMarkdownSerializer<ListItemNode> {
  const ListItemNodeSerializer();

  @override
  String doSerialization(
    Document document,
    ListItemNode node, {
    NodeSelection? selection,
  }) {
    if (selection != null && selection is! TextNodeSelection) {
      // We don't know how to handle this selection type.
      return '';
    }
    final textSelection = selection as TextNodeSelection?;
    if (textSelection != null && textSelection.isCollapsed) {
      // Selection is collapsed. Nothing is selected for copy.
      return '';
    }
    final textToConvert = textSelection != null //
        ? node.text.copyText(textSelection.start, textSelection.end)
        : node.text;

    final buffer = StringBuffer();

    final indent = List.generate(node.indent + 1, (index) => '  ').join('');
    final symbol = node.type == ListItemType.unordered ? '*' : '1.';

    buffer.write('$indent$symbol ${textToConvert.toMarkdown()}');

    final nodeIndex = document.getNodeIndexById(node.id);
    final nodeBelow = nodeIndex < document.nodeCount - 1 ? document.getNodeAt(nodeIndex + 1) : null;
    if (nodeBelow != null && (nodeBelow is! ListItemNode || nodeBelow.type != node.type)) {
      // This list item is the last item in the list. Add an extra
      // blank line after it.
      buffer.writeln('');
    }

    return buffer.toString();
  }
}

/// [DocumentNodeMarkdownSerializer] for serializing [ParagraphNode]s as standard Markdown
/// paragraphs.
///
/// Includes support for headers, blockquotes, and code blocks.
class ParagraphNodeSerializer extends NodeTypedDocumentNodeMarkdownSerializer<ParagraphNode> {
  const ParagraphNodeSerializer(this.markdownSyntax);

  final MarkdownSyntax markdownSyntax;

  @override
  String doSerialization(
    Document document,
    ParagraphNode node, {
    NodeSelection? selection,
  }) {
    if (selection != null && selection is! TextNodeSelection) {
      // We don't know how to handle this selection type.
      return '';
    }
    final textSelection = selection as TextNodeSelection?;
    if (textSelection != null && textSelection.isCollapsed) {
      // Selection is collapsed. Nothing is selected for copy.
      return '';
    }

    final buffer = StringBuffer();

    final Attribution? blockType = node.getMetadataValue('blockType');

    final inlineMarkdown = (textSelection != null //
            ? node.text.copyText(textSelection.start, textSelection.end)
            : node.text)
        .toMarkdown();

    if (blockType == header1Attribution) {
      buffer.write('# $inlineMarkdown');
    } else if (blockType == header2Attribution) {
      buffer.write('## $inlineMarkdown');
    } else if (blockType == header3Attribution) {
      buffer.write('### $inlineMarkdown');
    } else if (blockType == header4Attribution) {
      buffer.write('#### $inlineMarkdown');
    } else if (blockType == header5Attribution) {
      buffer.write('##### $inlineMarkdown');
    } else if (blockType == header6Attribution) {
      buffer.write('###### $inlineMarkdown');
    } else if (blockType == blockquoteAttribution) {
      // TODO: handle multiline
      buffer.write('> $inlineMarkdown');
    } else if (blockType == codeAttribution) {
      buffer //
        ..writeln('```') //
        ..writeln(inlineMarkdown) //
        ..write('```');
    } else {
      final String? textAlign = node.getMetadataValue('textAlign');
      // Left alignment is the default, so there is no need to add the alignment token.
      if (markdownSyntax == MarkdownSyntax.superEditor && textAlign != null && textAlign != 'left') {
        final alignmentToken = _convertAlignmentToMarkdown(textAlign);
        if (alignmentToken != null) {
          buffer.writeln(alignmentToken);
        }
      }
      buffer.write(inlineMarkdown);
    }

    // We're not at the end of the document yet. Add a blank line after the
    // paragraph so that we can tell the difference between separate
    // paragraphs vs. newlines within a single paragraph.
    final nodeIndex = document.getNodeIndexById(node.id);
    if (nodeIndex != document.nodeCount - 1) {
      buffer.writeln();
    }

    return buffer.toString();
  }
}

/// [DocumentNodeMarkdownSerializer] for serializing [TaskNode]s using Github's style syntax.
///
/// A completed task is serialized as `- [x] This is a completed task`
/// An incomplete task is serialized as `- [ ] This is an incomplete task`
class TaskNodeSerializer extends NodeTypedDocumentNodeMarkdownSerializer<TaskNode> {
  const TaskNodeSerializer();

  @override
  String doSerialization(
    Document document,
    TaskNode node, {
    NodeSelection? selection,
  }) {
    if (selection != null && selection is! TextNodeSelection) {
      // We don't know how to handle this selection type.
      return '';
    }
    final textSelection = selection as TextNodeSelection?;
    if (textSelection != null && textSelection.isCollapsed) {
      // Selection is collapsed. Nothing is selected for copy.
      return '';
    }
    final textToConvert = textSelection != null //
        ? node.text.copyText(textSelection.start, textSelection.end)
        : node.text;

    return '- [${node.isComplete ? 'x' : ' '}] ${textToConvert.toMarkdown()}';
  }
}

String? _convertAlignmentToMarkdown(String alignment) {
  switch (alignment) {
    case 'left':
      return ':---';
    case 'center':
      return ':---:';
    case 'right':
      return '---:';
    case 'justify':
      return '-::-';
    default:
      return null;
  }
}

/// Extension on [AttributedText] to serialize the [AttributedText] to a Markdown `String`.
extension Markdown on AttributedText {
  String toMarkdown() {
    final serializer = AttributedTextMarkdownSerializer();
    return serializer.serialize(this);
  }
}

/// Serializes an [AttributedText] into markdown format
class AttributedTextMarkdownSerializer extends AttributionVisitor {
  late String _fullText;
  late StringBuffer _buffer;
  late int _bufferCursor;

  String serialize(AttributedText attributedText) {
    _fullText = attributedText.toPlainText();
    _buffer = StringBuffer();
    _bufferCursor = 0;
    if (attributedText.toPlainText().isNotEmpty) {
      attributedText.visitAttributions(this);
    }
    return _buffer.toString();
  }

  @override
  void visitAttributions(
    AttributedText fullText,
    int index,
    Set<Attribution> startingAttributions,
    Set<Attribution> endingAttributions,
  ) {
    // Write out the text between the end of the last markers, and these new markers.
    _writeTextToBuffer(
      fullText.toPlainText().substring(_bufferCursor, index),
    );

    // Add start markers.
    if (startingAttributions.isNotEmpty) {
      final markdownStyles = _sortAndSerializeAttributions(startingAttributions, AttributionVisitEvent.start);
      // Links are different from the plain styles since they are both not NamedAttributions (and therefore
      // can't be checked using equality comparison) and asymmetrical in markdown.
      final linkMarker = _encodeLinkMarker(startingAttributions, AttributionVisitEvent.start);

      _buffer
        ..write(linkMarker)
        ..write(markdownStyles);
    }

    // Write out the character at this index.
    _writeTextToBuffer(_fullText[index]);
    _bufferCursor = index + 1;

    // Add end markers.
    if (endingAttributions.isNotEmpty) {
      final markdownStyles = _sortAndSerializeAttributions(endingAttributions, AttributionVisitEvent.end);
      // Links are different from the plain styles since they are both not NamedAttributions (and therefore
      // can't be checked using equality comparison) and asymmetrical in markdown.
      final linkMarker = _encodeLinkMarker(endingAttributions, AttributionVisitEvent.end);

      _buffer
        ..write(markdownStyles)
        ..write(linkMarker);
    }
  }

  @override
  void onVisitEnd() {
    // When the last span has no attributions, we still have text that wasn't added to the buffer yet.
    if (_bufferCursor <= _fullText.length - 1) {
      _writeTextToBuffer(_fullText.substring(_bufferCursor));
    }
  }

  /// Writes the given [text] to [_buffer].
  ///
  /// Separates multiple lines in a single paragraph using two spaces before each line break.
  ///
  /// A line ending with two or more spaces represents a hard line break,
  /// as defined in the Markdown spec.
  void _writeTextToBuffer(String text) {
    final lines = text.split('\n');
    for (int i = 0; i < lines.length; i++) {
      if (i > 0) {
        // Adds two spaces before line breaks.
        // The Markdown spec defines that a line ending with two or more spaces
        // represents a hard line break, which causes the next line to be part of
        // the previous paragraph during deserialization.
        _buffer.write('  ');
        _buffer.write('\n');
      }

      _buffer.write(lines[i]);
    }
  }

  /// Serializes style attributions into markdown syntax in a repeatable
  /// order such that opening and closing styles match each other on
  /// the opening and closing ends of a span.
  static String _sortAndSerializeAttributions(Set<Attribution> attributions, AttributionVisitEvent event) {
    const startOrder = [
      codeAttribution,
      boldAttribution,
      italicsAttribution,
      strikethroughAttribution,
      underlineAttribution,
    ];

    final buffer = StringBuffer();
    final encodingOrder = event == AttributionVisitEvent.start ? startOrder : startOrder.reversed;

    for (final markdownStyleAttribution in encodingOrder) {
      if (attributions.contains(markdownStyleAttribution)) {
        buffer.write(_encodeMarkdownStyle(markdownStyleAttribution));
      }
    }

    return buffer.toString();
  }

  static String _encodeMarkdownStyle(Attribution attribution) {
    if (attribution == codeAttribution) {
      return '`';
    } else if (attribution == boldAttribution) {
      return '**';
    } else if (attribution == italicsAttribution) {
      return '*';
    } else if (attribution == strikethroughAttribution) {
      return '~';
    } else if (attribution == underlineAttribution) {
      return '¬';
    } else {
      return '';
    }
  }

  /// Checks for the presence of a link in the attributions and returns the characters necessary to represent it
  /// at the open or closing boundary of the attribution, depending on the event.
  static String _encodeLinkMarker(Set<Attribution> attributions, AttributionVisitEvent event) {
    final linkAttributions = attributions.whereType<LinkAttribution?>();
    if (linkAttributions.isNotEmpty) {
      final linkAttribution = linkAttributions.first as LinkAttribution;

      if (event == AttributionVisitEvent.start) {
        return '[';
      } else {
        return '](${linkAttribution.plainTextUri})';
      }
    }
    return "";
  }
}

/// [DocumentNodeMarkdownSerializer], which serializes Markdown headers to
/// [ParagraphNode]s with an appropriate header block type, and (optionally) a
/// block alignment.
///
/// Headers are represented by `ParagraphNode`s and therefore this serializer must
/// run before a [ParagraphNodeSerializer], so that this serializer can process
/// header-specific details, such as header alignment.
class HeaderNodeSerializer extends NodeTypedDocumentNodeMarkdownSerializer<ParagraphNode> {
  const HeaderNodeSerializer(this.markdownSyntax);

  final MarkdownSyntax markdownSyntax;

  @override
  String? serialize(
    Document document,
    DocumentNode node, {
    NodeSelection? selection,
  }) {
    if (node is! ParagraphNode) {
      return null;
    }

    // Only serialize this node when this is a header node.
    final Attribution? blockType = node.getMetadataValue('blockType');
    final isHeaderNode = blockType == header1Attribution ||
        blockType == header2Attribution ||
        blockType == header3Attribution ||
        blockType == header4Attribution ||
        blockType == header5Attribution ||
        blockType == header6Attribution;

    if (!isHeaderNode) {
      return null;
    }

    return doSerialization(document, node);
  }

  @override
  String doSerialization(
    Document document,
    ParagraphNode node, {
    NodeSelection? selection,
  }) {
    if (selection != null && selection is! TextNodeSelection) {
      // We don't know how to handle this selection type.
      return '';
    }
    final textSelection = selection as TextNodeSelection?;
    if (textSelection != null && textSelection.isCollapsed) {
      // Selection is collapsed. Nothing is selected for copy.
      return '';
    }
    final textToConvert = textSelection != null //
        ? node.text.copyText(textSelection.start, textSelection.end)
        : node.text;

    final buffer = StringBuffer();

    final Attribution? blockType = node.getMetadataValue('blockType');
    final String? textAlign = node.getMetadataValue('textAlign');

    // Add the alignment token, we exclude the left alignment because it's the default.
    if (markdownSyntax == MarkdownSyntax.superEditor && textAlign != null && textAlign != 'left') {
      final alignmentToken = _convertAlignmentToMarkdown(textAlign);
      if (alignmentToken != null) {
        buffer.writeln(alignmentToken);
      }
    }

    if (blockType == header1Attribution) {
      buffer.write('# ${textToConvert.toMarkdown()}');
    } else if (blockType == header2Attribution) {
      buffer.write('## ${textToConvert.toMarkdown()}');
    } else if (blockType == header3Attribution) {
      buffer.write('### ${textToConvert.toMarkdown()}');
    } else if (blockType == header4Attribution) {
      buffer.write('#### ${textToConvert.toMarkdown()}');
    } else if (blockType == header5Attribution) {
      buffer.write('##### ${textToConvert.toMarkdown()}');
    } else if (blockType == header6Attribution) {
      buffer.write('###### ${textToConvert.toMarkdown()}');
    }

    // We're not at the end of the document yet. Add a blank line after the
    // paragraph so that we can tell the difference between separate
    // paragraphs vs. newlines within a single paragraph.
    final nodeIndex = document.getNodeIndexById(node.id);
    if (nodeIndex != document.nodeCount - 1) {
      buffer.writeln();
    }

    return buffer.toString();
  }
}

/// [DocumentNodeMarkdownSerializer] for serializing [TableBlockNode]s as the extended Markdown
/// syntax for tables.
///
/// See https://www.markdownguide.org/extended-syntax/#tables for the specification.
class TableBlockNodeSerializer extends NodeTypedDocumentNodeMarkdownSerializer<TableBlockNode> {
  const TableBlockNodeSerializer();

  @override
  String doSerialization(
    Document document,
    TableBlockNode node, {
    NodeSelection? selection,
  }) {
    if (selection != null) {
      if (selection is! UpstreamDownstreamNodeSelection) {
        // We don't know how to handle this selection type.
        return '';
      }
      if (selection.isCollapsed) {
        // This selection doesn't include the table - it's a collapsed selection
        // either on the upstream or downstream edge.
        return '';
      }
    }

    if (node.rowCount == 0) {
      // The table must have at least one row (the header row) to be serialized.
      return '';
    }

    final buffer = StringBuffer();

    final headerRow = node.getRow(0);

    // Serialize the header values.
    buffer.write('|');
    for (final cell in headerRow) {
      buffer.write(' ');
      buffer.write(cell.text.toMarkdown());
      buffer.write(' |');
    }

    // Serialize the header separator row.
    buffer.writeln();
    buffer.write('|');
    for (int i = 0; i < headerRow.length; i++) {
      buffer.write(' ');

      final firstDataCell = node.rowCount > 1 //
          ? node.getCell(rowIndex: 1, columnIndex: i)
          : null;

      buffer.write(_getHeaderSeparatorColumnContent(firstDataCell));
      buffer.write(' |');
    }

    // Serialize the data rows.
    if (node.rowCount > 1) {
      for (int i = 1; i < node.rowCount; i++) {
        buffer.writeln();
        final row = node.getRow(i);

        buffer.write('|');
        for (final cell in row) {
          buffer.write(' ');
          buffer.write(cell.text.toMarkdown());
          buffer.write(' |');
        }
      }
    }

    return buffer.toString();
  }

  String _getHeaderSeparatorColumnContent(TextNode? firstDataCell) {
    if (firstDataCell == null) {
      return '---';
    }

    final textAlign = firstDataCell.getMetadataValue('textAlign');
    return switch (textAlign) {
      TextAlign.center => ':--:',
      TextAlign.right => '--:',
      _ => '---',
    };
  }
}
