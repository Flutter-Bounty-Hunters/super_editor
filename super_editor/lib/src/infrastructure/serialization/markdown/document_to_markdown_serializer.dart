import 'dart:ui';

import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/foundation.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/default_editor/horizontal_rule.dart';
import 'package:super_editor/src/default_editor/image.dart';
import 'package:super_editor/src/default_editor/list_items.dart';
import 'package:super_editor/src/default_editor/paragraph.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';
import 'package:super_editor/src/default_editor/tables/table_block.dart';
import 'package:super_editor/src/default_editor/tasks.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/serialization/markdown/markdown_inline_parser.dart';
import 'package:super_editor/src/infrastructure/serialization/markdown/super_editor_syntax.dart';

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
///
/// ## Whitespace policy
///
/// This serializer and [deserializeMarkdownToDocument] are exact inverses for
/// every structure the parser produces. Newlines are owned entirely by this
/// function — node serializers emit their block's text with NO trailing
/// newline, and the separator written between two nodes is:
///
///  * `"\n\n"` between two non-empty blocks — the standard markdown blank-line
///    block separator;
///  * `"\n"` between two consecutive list-family nodes ([ListItemNode],
///    [TaskNode]), which markdown requires on adjacent lines to form one list;
///  * `"\n"` after a heading whose `tight` metadata is `true` (parsed from
///    `# Title\nBody` with no blank line — both the tight and the
///    blank-line-separated form round-trip byte-identically);
///  * around empty paragraphs: an empty paragraph serializes as an empty
///    string, and every empty paragraph contributes exactly one `"\n"` to the
///    document. Concretely: `"\n"` before an empty paragraph, `"\n"` between
///    two empty paragraphs, and — closing a run — `"\n\n"` before the next
///    non-empty block (or `"\n"` when no non-empty block precedes the run,
///    i.e. at the start of the document).
///
/// The result, in raw-newline terms, with `[A]`/`[B]` non-empty blocks and
/// `[e]` an empty paragraph:
///
///  * `[A][B]` → `A\n\nB`; `[A][e][B]` → `A\n\n\nB`; `[A][e][e][B]` → `A\n\n\n\nB`
///  * `[e][A]` → `\nA`; `[A][e]` → `A\n` — a document ends with a newline iff
///    it ends with empty paragraphs;
///  * an all-empty document with n empty paragraphs → n-1 newlines (`[e]` → `""`).
///
/// The parser's inverse rules: k blank lines between two blocks → k-1 empty
/// paragraphs (one blank line is just the separator); k blank lines at the
/// document start → k empty paragraphs; m trailing newlines → m empty
/// paragraphs; a document of nothing but m newlines → m+1 empty paragraphs.
///
/// Single `"\n"` characters inside a paragraph's text (soft wraps) serialize
/// verbatim — no two-space hard-break markers are appended (they compounded on
/// every save; see upstream issue #3006). Text that would be re-interpreted as
/// block syntax at a line start is backslash-escaped instead.
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

  // The last node that produced a serialization, and whether any node so far
  // serialized as a non-empty block — the inputs to the separator written
  // between blocks (see the whitespace policy above).
  DocumentNode? previousNode;
  bool hasNonEmptyBlockBefore = false;

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
        if (previousNode != null) {
          buffer.write(_nodeSeparator(previousNode, node, hasNonEmptyBlockBefore: hasNonEmptyBlockBefore));
        }

        buffer.write(serialization);
        previousNode = node;
        hasNonEmptyBlockBefore = hasNonEmptyBlockBefore || !_isEmptyParagraph(node);
        break;
      }
    }
  }

  return buffer.toString();
}

/// The newlines to write between [previous] and [current], per the whitespace
/// policy documented on [serializeDocumentToMarkdown].
///
/// [hasNonEmptyBlockBefore] reports whether any node before [current] —
/// [previous] included — serialized as a non-empty block. It distinguishes an
/// empty-paragraph run at the start of the document (each empty paragraph is
/// one newline, nothing more) from a run between two blocks (where the
/// surrounding blocks also need their blank-line separator).
String _nodeSeparator(DocumentNode previous, DocumentNode current, {required bool hasNonEmptyBlockBefore}) {
  if (_isEmptyParagraph(previous)) {
    return _isEmptyParagraph(current) || !hasNonEmptyBlockBefore ? '\n' : '\n\n';
  }
  if (_isEmptyParagraph(current)) {
    return '\n';
  }
  if (_isListItemLike(previous) && _isListItemLike(current)) {
    // Adjacent lines, so the items form a single markdown list.
    return '\n';
  }
  if (_isTightHeading(previous)) {
    return '\n';
  }
  return '\n\n';
}

/// Whether [node] is an empty paragraph with no special block type — a node
/// that serializes to an empty string and stands for one newline.
bool _isEmptyParagraph(DocumentNode node) {
  if (node is! ParagraphNode || node.text.isNotEmpty) {
    return false;
  }
  final blockType = node.getMetadataValue('blockType');
  return blockType == null || blockType == paragraphAttribution;
}

/// Whether [node] serializes as a markdown list item (`- `, `1. `, `- [ ] `).
bool _isListItemLike(DocumentNode node) => node is ListItemNode || node is TaskNode;

/// Whether [node] is a heading that was parsed with no blank line between it
/// and the following block, and should be written back the same way.
bool _isTightHeading(DocumentNode node) {
  if (node is! ParagraphNode || node.getMetadataValue('tight') != true) {
    return false;
  }
  final blockType = node.getMetadataValue('blockType');
  return blockType == header1Attribution ||
      blockType == header2Attribution ||
      blockType == header3Attribution ||
      blockType == header4Attribution ||
      blockType == header5Attribution ||
      blockType == header6Attribution;
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

    final indent = _indentPrefix(document, node);
    final symbol = node.type == ListItemType.unordered ? '-' : '${_ordinal(document, node)}.';

    buffer.write('$indent$symbol ${textToConvert.toMarkdown()}');

    return buffer.toString();
  }

  /// The leading spaces for [node], computed from the marker widths of its
  /// ancestor list items so that a nested item sits at the content column of
  /// its parent — the column markdown requires for a nested list.
  ///
  /// A top-level item has no leading spaces. An item nested under `- ` is
  /// indented 2 spaces, under `1. ` 3 spaces, under `10. ` 4 spaces, etc. A
  /// fixed 2-space indent wouldn't be enough under an ordered parent, and the
  /// nesting would silently flatten on the next parse.
  String _indentPrefix(Document document, ListItemNode node) {
    if (node.indent == 0) {
      return '';
    }

    // Walk the contiguous run of list items above this node, recording the
    // marker width of the most recent item at each indent level — those are
    // this node's ancestors.
    final nodeIndex = document.getNodeIndexById(node.id);
    var runStart = nodeIndex;
    while (runStart > 0 && document.getNodeAt(runStart - 1) is ListItemNode) {
      runStart -= 1;
    }

    final markerWidthByLevel = <int, int>{};
    for (var i = runStart; i < nodeIndex; i += 1) {
      final item = document.getNodeAt(i) as ListItemNode;
      markerWidthByLevel[item.indent] = _markerWidth(document, item);
    }

    var width = 0;
    for (var level = 0; level < node.indent; level += 1) {
      // A level with no preceding item can only come from malformed indentation.
      // Fall back to the unordered marker width.
      width += markerWidthByLevel[level] ?? 2;
    }
    return ' ' * width;
  }

  /// The width of the marker [node] serializes with, including the trailing
  /// space: `- ` is 2, `1. ` is 3, `10. ` is 4.
  int _markerWidth(Document document, ListItemNode node) {
    if (node.type == ListItemType.unordered) {
      return 2;
    }
    return '${_ordinal(document, node)}. '.length;
  }

  /// The ordinal for an ordered list item — its 1-based position among the
  /// consecutive ordered siblings at the same indent level.
  int _ordinal(Document document, ListItemNode node) {
    var ordinal = 1;
    var index = document.getNodeIndexById(node.id) - 1;
    while (index >= 0) {
      final previous = document.getNodeAt(index);
      if (previous is! ListItemNode || previous.indent < node.indent) {
        // We've reached the start of the list, or left this item's nesting scope.
        break;
      }
      if (previous.indent == node.indent) {
        if (previous.type != ListItemType.ordered) {
          // An unordered sibling at the same level means this item started a
          // new ordered list.
          break;
        }
        ordinal += 1;
      }
      // Items with a deeper indent belong to an earlier sibling; keep scanning.
      index -= 1;
    }
    return ordinal;
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

    final textToConvert = textSelection != null //
        ? node.text.copyText(textSelection.start, textSelection.end)
        : node.text;
    final inlineMarkdown = textToConvert.toMarkdown();

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
      buffer.write(_serializeBlockquote(inlineMarkdown));
    } else if (blockType == codeAttribution) {
      final language = node.getMetadataValue('codeLanguage') as String? ?? '';
      // A code fence holds literal text: serialize the plain text, not the
      // inline markdown, so code isn't backslash-escaped or given hard-break
      // trailing spaces.
      final code = textToConvert.toPlainText();
      // The markdown parser stores fenced code with a trailing newline; strip a
      // single one so the fence doesn't grow a blank line on every round trip.
      final trimmedCode = code.endsWith('\n') ? code.substring(0, code.length - 1) : code;
      buffer //
        ..writeln('```$language') //
        ..writeln(trimmedCode) //
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
      // A plain paragraph has no block-level syntax of its own, so a line starting
      // with "#", "- ", "1. ", etc., would change block type on the next parse.
      // Serialize with those trigger characters escaped.
      buffer.write(textToConvert.toMarkdown(escapeLineStartTriggers: true));
    }

    return buffer.toString();
  }

  /// Serializes blockquote text, prefixing every line with `> ` (a bare `>`
  /// for empty lines) so multi-line quotes keep their marker on every line.
  /// Without the marker, the second line loses the quote on the next parse and
  /// splits into a separate paragraph. Hard-break trailing spaces are dropped —
  /// the `>` markers alone keep the lines in one quote.
  static String _serializeBlockquote(String inlineMarkdown) {
    return inlineMarkdown
        .split('\n')
        .map((line) => line.trimRight())
        .map((line) => line.isEmpty ? '>' : '> $line')
        .join('\n');
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
  /// Serializes this [AttributedText] to Markdown.
  ///
  /// When [escapeLineStartTriggers] is `true`, a character at the start of a line
  /// that would be re-interpreted as block-level syntax on the next parse (e.g., a
  /// leading "#", ">", "- ", or "1. ") is backslash-escaped. Enable this when the
  /// text is serialized as a plain paragraph. Leave it disabled when the surrounding
  /// serializer supplies its own block-level syntax (headers, list items, tasks,
  /// table cells, etc.), where a leading "#" can't change the block type.
  String toMarkdown({bool escapeLineStartTriggers = false}) {
    final serializer = AttributedTextMarkdownSerializer();
    return serializer.serialize(this, escapeLineStartTriggers: escapeLineStartTriggers);
  }
}

/// Serializes an [AttributedText] into markdown format.
///
/// The serializer guarantees, as best markdown allows, that its output re-parses
/// back to the same styled text:
///
///  * Whitespace at the edges of bold/italic/strikethrough/code spans is moved
///    outside the style markers, because CommonMark doesn't recognize a closing
///    marker that follows whitespace — "**bold **" re-parses as plain text and
///    the styling would silently vanish. The edge whitespace itself loses the
///    styling, which is invisible anyway.
///  * Overlapping (non-nested) spans are serialized by closing and re-opening
///    styles, producing properly nested markers that CommonMark can re-parse.
///  * Characters carrying [markdownEscapeAttribution] (characters that were
///    backslash-escaped in the original markdown) are re-escaped on the way out.
///  * As a safety net, the output is re-parsed and compared against the input.
///    If the styles don't survive the round trip, markdown-significant characters
///    are backslash-escaped and the escaped serialization is used instead. This
///    prevents unstyled text like "3*4 and 5*6" from gaining emphasis on the
///    next parse.
class AttributedTextMarkdownSerializer {
  /// Inline styles whose markers can't sit against whitespace in CommonMark.
  ///
  /// Spans of these attributions are trimmed to their non-whitespace core before
  /// serialization. Underline is excluded because it serializes to HTML tags, and
  /// links are excluded because link text may legitimately start or end with spaces.
  static const _trimmableAttributions = [
    codeAttribution,
    boldAttribution,
    italicsAttribution,
    strikethroughAttribution,
  ];

  /// All ASCII punctuation, i.e., every character that supports backslash-escaping
  /// in markdown. Characters carrying [markdownEscapeAttribution] are re-escaped
  /// only if they appear in this set.
  static final _asciiPunctuation = r'''!"#$%&'()*+,-./:;<=>?@[\]^_`{|}~'''.codeUnits.toSet();

  /// The characters that can begin inline markdown syntax. These are escaped in
  /// non-code text when the serialization fails to round-trip without escaping.
  static final _markdownSignificantCharacters = '*_`~[]<\\'.codeUnits.toSet();

  /// Inline HTML syntaxes used when re-parsing a candidate serialization, to compare
  /// it against the original. Extends the default set with a handler that maps hard
  /// line breaks back to the newline characters they were serialized from.
  static final _reparseInlineHtmlSyntaxes = [
    ...defaultInlineHtmlSyntaxes,
    _lineBreakHtmlSyntax,
  ];

  String serialize(AttributedText attributedText, {bool escapeLineStartTriggers = false}) {
    final fullText = attributedText.toPlainText();
    if (fullText.isEmpty) {
      return '';
    }

    final trimmed = _withTrimmedStyleSpans(attributedText, fullText);

    final candidate = _serializeSpans(
      trimmed,
      fullText,
      escapeSignificantCharacters: false,
      escapeLineStartTriggers: escapeLineStartTriggers,
    );
    if (_reparsesToSameStyles(candidate, trimmed, fullText)) {
      return candidate;
    }

    // The un-escaped serialization doesn't survive a round trip, e.g., plain text
    // like "3*4 and 5*6" would gain emphasis on the next parse. Escape the
    // markdown-significant characters, and use that version if it round-trips.
    final escaped = _serializeSpans(
      trimmed,
      fullText,
      escapeSignificantCharacters: true,
      escapeLineStartTriggers: escapeLineStartTriggers,
    );
    return _reparsesToSameStyles(escaped, trimmed, fullText) ? escaped : candidate;
  }

  /// Returns a copy of [text] whose [_trimmableAttributions] spans are shrunk to
  /// exclude leading/trailing whitespace. Spans that contain only whitespace are
  /// dropped entirely — markdown has no way to style bare whitespace.
  AttributedText _withTrimmedStyleSpans(AttributedText text, String fullText) {
    // Coalesce abutting spans of the same attribution before trimming, so that
    // trimming sees maximal runs. Editing can leave a bold run stored as two
    // spans meeting at a space (e.g., after toggling bold off and back on over
    // part of the run) — trimming each span separately would silently un-style
    // the space at their internal boundary.
    final spans = text.getAttributionSpansByFilter((_) => true).toList()
      ..sort((a, b) => a.start != b.start ? a.start.compareTo(b.start) : a.end.compareTo(b.end));
    final coalesced = <({Attribution attribution, int start, int end})>[];
    for (final span in spans) {
      final previousIndex = coalesced.lastIndexWhere(
        (candidate) => candidate.attribution == span.attribution && candidate.end + 1 >= span.start,
      );
      if (previousIndex >= 0) {
        final previous = coalesced[previousIndex];
        coalesced[previousIndex] = (
          attribution: previous.attribution,
          start: previous.start,
          end: span.end > previous.end ? span.end : previous.end,
        );
      } else {
        coalesced.add((attribution: span.attribution, start: span.start, end: span.end));
      }
    }

    var changed = false;
    final rebuiltSpans = AttributedSpans();
    for (final span in coalesced) {
      var start = span.start;
      var end = span.end.clamp(0, fullText.length - 1);
      if (_trimmableAttributions.contains(span.attribution)) {
        while (start <= end && _isWhitespace(fullText.codeUnitAt(start))) {
          start += 1;
        }
        while (end >= start && _isWhitespace(fullText.codeUnitAt(end))) {
          end -= 1;
        }
      }
      if (start > end) {
        changed = true;
        continue;
      }
      changed = changed || start != span.start || end != span.end;
      rebuiltSpans.addAttribution(
        newAttribution: span.attribution,
        start: start,
        end: end,
        autoMerge: true,
      );
    }
    return changed ? text.replaceAttributions(rebuiltSpans) : text;
  }

  String _serializeSpans(
    AttributedText text,
    String fullText, {
    required bool escapeSignificantCharacters,
    required bool escapeLineStartTriggers,
  }) {
    final writer = _MarkdownTextWriter(escapeLineStartTriggers: escapeLineStartTriggers);

    final spans = text.computeAttributionSpans().toList();

    // Attributions that are currently open, in the order they were opened. Styles
    // are closed innermost-first, and when an outer style has to close while an
    // inner one continues, the inner style is closed and re-opened, keeping the
    // markers properly nested.
    final openAttributions = <Attribution>[];

    for (var spanIndex = 0; spanIndex < spans.length; spanIndex += 1) {
      final span = spans[spanIndex];
      final styles = span.attributions.where(_isSerializedInline).toSet();
      final isEscaped = span.attributions.contains(markdownEscapeAttribution);
      var spanText = fullText.substring(span.start, span.end + 1);

      // Close styles that end at this boundary, along with any styles that were
      // opened after them (those are re-opened below).
      var keepCount = 0;
      while (keepCount < openAttributions.length && styles.contains(openAttributions[keepCount])) {
        keepCount += 1;
      }
      for (var i = openAttributions.length - 1; i >= keepCount; i -= 1) {
        writer.writeMarker(_closeMarker(openAttributions[i]));
        openAttributions.removeAt(i);
      }

      // Open styles that start (or re-open) at this boundary. The style that
      // extends furthest opens first so that shorter spans nest inside longer
      // ones, e.g., bold and italics both starting at "is" in
      // "This *is a **bold** word*" open as "*is a **bold**", not "**\*is a...".
      final stylesToOpen = styles.where((attribution) => !openAttributions.contains(attribution)).toList()
        ..sort((a, b) {
          final endComparison = _attributionEnd(b, spans, spanIndex).compareTo(_attributionEnd(a, spans, spanIndex));
          if (endComparison != 0) {
            return endComparison;
          }
          return _stylePriority(a).compareTo(_stylePriority(b));
        });
      if (stylesToOpen.any(_trimmableAttributions.contains)) {
        // Emphasis-like markers can't sit against whitespace. Write any leading
        // whitespace before the opening markers. Trimming already guarantees this
        // for span starts; this only happens when an overlapping span forced a
        // style closed and it re-opens mid-span, e.g., at " e" in "**ab *cd***_ e_".
        final whitespaceCount = _leadingWhitespaceCount(spanText);
        if (whitespaceCount > 0) {
          writer.writeText(spanText.substring(0, whitespaceCount));
          spanText = spanText.substring(whitespaceCount);
        }
      }
      for (final attribution in stylesToOpen) {
        writer.writeMarker(_openMarker(attribution));
        openAttributions.add(attribution);
      }

      if (spanText.isEmpty) {
        continue;
      }
      if (isEscaped) {
        // These characters were backslash-escaped in the original markdown.
        writer.writeText(spanText, escapeCharacters: _asciiPunctuation);
      } else if (escapeSignificantCharacters && !styles.contains(codeAttribution)) {
        writer.writeText(spanText, escapeCharacters: _markdownSignificantCharacters);
      } else {
        writer.writeText(spanText);
      }
    }

    for (var i = openAttributions.length - 1; i >= 0; i -= 1) {
      writer.writeMarker(_closeMarker(openAttributions[i]));
    }

    return writer.toString();
  }

  /// Whether serializing [markdown] and parsing it again produces the styles in
  /// [expected] — the bar every serialization must meet for styling and text to
  /// survive a save/load round trip.
  bool _reparsesToSameStyles(String markdown, AttributedText expected, String expectedText) {
    AttributedText reparsed;
    try {
      reparsed = parseInlineMarkdown(
        markdown,
        inlineHtmlSyntaxes: _reparseInlineHtmlSyntaxes,
      );
    } catch (_) {
      return false;
    }

    if (reparsed.toPlainText() != expectedText) {
      return false;
    }

    for (var i = 0; i < expectedText.length; i += 1) {
      final expectedStyles = expected.getAllAttributionsAt(i).where(_isSerializedInline).toSet();
      final reparsedStyles = reparsed.getAllAttributionsAt(i).where(_isSerializedInline).toSet();
      if (!setEquals(expectedStyles, reparsedStyles)) {
        return false;
      }
    }
    return true;
  }

  /// Maps hard line breaks in a re-parsed candidate serialization back to the
  /// newline they were serialized from, so the comparison in
  /// [_reparsesToSameStyles] sees the same plain text.
  static AttributedText? _lineBreakHtmlSyntax(md.Element element, AttributedText text) {
    if (element.tag != 'br') {
      return null;
    }
    return AttributedText('\n');
  }

  static bool _isSerializedInline(Attribution attribution) =>
      attribution == codeAttribution ||
      attribution == boldAttribution ||
      attribution == italicsAttribution ||
      attribution == strikethroughAttribution ||
      attribution == underlineAttribution ||
      attribution is LinkAttribution;

  /// The last text offset covered by [attribution], scanning contiguously
  /// forward from the span at [fromIndex].
  static int _attributionEnd(Attribution attribution, List<MultiAttributionSpan> spans, int fromIndex) {
    var end = spans[fromIndex].end;
    for (var i = fromIndex + 1; i < spans.length; i += 1) {
      if (!spans[i].attributions.contains(attribution)) {
        break;
      }
      end = spans[i].end;
    }
    return end;
  }

  /// Nesting priority when multiple styles open at the same offset — lower values
  /// sit outside higher ones.
  static int _stylePriority(Attribution attribution) {
    if (attribution is LinkAttribution) {
      return 0;
    } else if (attribution == codeAttribution) {
      return 1;
    } else if (attribution == boldAttribution) {
      return 2;
    } else if (attribution == italicsAttribution) {
      return 3;
    } else if (attribution == strikethroughAttribution) {
      return 4;
    } else {
      return 5;
    }
  }

  static String _openMarker(Attribution attribution) {
    if (attribution is LinkAttribution) {
      return '[';
    } else if (attribution == codeAttribution) {
      return '`';
    } else if (attribution == boldAttribution) {
      return '**';
    } else if (attribution == italicsAttribution) {
      return '*';
    } else if (attribution == strikethroughAttribution) {
      return '~~';
    } else if (attribution == underlineAttribution) {
      return '<u>';
    } else {
      return '';
    }
  }

  static String _closeMarker(Attribution attribution) {
    if (attribution is LinkAttribution) {
      return '](${attribution.plainTextUri})';
    } else if (attribution == underlineAttribution) {
      return '</u>';
    } else {
      return _openMarker(attribution);
    }
  }

  static int _leadingWhitespaceCount(String text) {
    var count = 0;
    while (count < text.length && _isWhitespace(text.codeUnitAt(count))) {
      count += 1;
    }
    return count;
  }

  static bool _isWhitespace(int codeUnit) =>
      codeUnit == 0x20 || codeUnit == 0x09 || codeUnit == 0x0A || codeUnit == 0x0D;
}

/// Accumulates serialized markdown text, handling hard line breaks, backslash
/// escaping, and escaping of block-level syntax at line starts.
class _MarkdownTextWriter {
  _MarkdownTextWriter({required this.escapeLineStartTriggers});

  /// Whether to backslash-escape characters at the start of a line that would be
  /// re-interpreted as block-level syntax (headings, list bullets, blockquotes,
  /// thematic breaks, fences) when the markdown is parsed again.
  final bool escapeLineStartTriggers;

  final _buffer = StringBuffer();
  bool _isAtLineStart = true;

  /// Ordered list markers are neutralized by escaping the delimiter after the
  /// digits ("1\. "), because a backslash before a digit is not an escape.
  static final _orderedListPattern = RegExp(r'^ {0,3}\d{1,9}[.)][ \t]');

  /// Block-level syntax that a plain paragraph line must not start with. For all
  /// of these, escaping the first non-space character neutralizes the syntax.
  static final _blockTriggerPatterns = <RegExp>[
    RegExp(r'^ {0,3}#{1,6}(?:[ \t]|$)'), // ATX heading
    RegExp(r'^ {0,3}>'), // blockquote
    RegExp(r'^ {0,3}[-*+][ \t]'), // bullet list item
    RegExp(r'^ {0,3}(?:-[ \t]*){3,}$'), // thematic break, e.g. "---"
    RegExp(r'^ {0,3}(?:\*[ \t]*){3,}$'), // thematic break, e.g. "***"
    RegExp(r'^ {0,3}(?:_[ \t]*){3,}$'), // thematic break, e.g. "___"
    RegExp(r'^ {0,3}=+[ \t]*$'), // setext heading underline
    RegExp(r'^ {0,3}`{3,}'), // code fence
    RegExp(r'^ {0,3}~{3,}'), // code fence
  ];

  void writeMarker(String marker) {
    _buffer.write(marker);
    if (marker.isNotEmpty) {
      _isAtLineStart = false;
    }
  }

  /// Writes the given [text], escaping any characters whose code units appear in
  /// [escapeCharacters] with a leading backslash.
  ///
  /// A "\n" within [text] is written verbatim: consecutive non-blank lines
  /// re-parse into the same paragraph, so a soft wrap needs no hard-break
  /// marker. Two-space hard breaks are never emitted — they accumulated one
  /// invisible "  " per line per save (upstream issue #3006).
  void writeText(String text, {Set<int>? escapeCharacters}) {
    final lines = text.split('\n');
    for (int i = 0; i < lines.length; i++) {
      if (i > 0) {
        _buffer.write('\n');
        _isAtLineStart = true;
      }
      _writeLine(lines[i], escapeCharacters);
    }
  }

  void _writeLine(String line, Set<int>? escapeCharacters) {
    if (line.isEmpty) {
      return;
    }

    var escapeAtIndex = -1;
    if (_isAtLineStart && escapeLineStartTriggers) {
      escapeAtIndex = _findBlockTriggerIndex(line);
    }

    if (escapeCharacters == null && escapeAtIndex < 0) {
      _buffer.write(line);
    } else {
      for (var i = 0; i < line.length; i += 1) {
        final codeUnit = line.codeUnitAt(i);
        if (i == escapeAtIndex || (escapeCharacters?.contains(codeUnit) ?? false)) {
          _buffer.write(r'\');
        }
        _buffer.writeCharCode(codeUnit);
      }
    }
    _isAtLineStart = false;
  }

  static int _findBlockTriggerIndex(String line) {
    final orderedListMatch = _orderedListPattern.firstMatch(line);
    if (orderedListMatch != null) {
      // Escape the "." or ")" that follows the digits.
      return orderedListMatch.end - 2;
    }
    for (final pattern in _blockTriggerPatterns) {
      if (pattern.hasMatch(line)) {
        // Escape the first non-space character.
        var index = 0;
        while (index < line.length && line.codeUnitAt(index) == 0x20) {
          index += 1;
        }
        return index;
      }
    }
    return -1;
  }

  @override
  String toString() => _buffer.toString();
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
