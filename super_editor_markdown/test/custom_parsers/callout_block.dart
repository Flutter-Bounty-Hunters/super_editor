import 'package:markdown/markdown.dart' as md;
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_markdown/super_editor_markdown.dart';

/// Markdown block-parser for callouts.
///
/// This [BlockSyntax] produces an [md.Element] with the name "callout".
///
/// Consider a blog post that mentions a detail in passing. The author might
/// like to introduce a standalone block of content that explains that detail
/// for readers who may be interested. That content should be visually separated
/// from the main content in the blog post, so that readers can skip the aside,
/// if desired.
class CalloutBlockSyntax extends md.BlockSyntax {
  static final _endLinePattern = RegExp(r'^@@@\s*$');

  @override
  RegExp get pattern => RegExp(r'^@@@\s*callout\s*$');

  const CalloutBlockSyntax();

  // This method was adapted from the standard Blockquote parser, and
  // the standard code fence block parser.
  @override
  List<md.Line?> parseChildLines(md.BlockParser parser) {
    // Grab all of the lines that form the custom block, stripping off the
    // first line, e.g., "@@@ customBlock", and the last line, e.g., "@@@".
    var childLines = <String>[];

    while (!parser.isDone) {
      final openingLine = pattern.firstMatch(parser.current.content);
      if (openingLine != null) {
        // This is the first line. Ignore it.
        parser.advance();
        continue;
      }
      final closingLine = _endLinePattern.firstMatch(parser.current.content);
      if (closingLine != null) {
        // This is the closing line. Ignore it.
        parser.advance();

        // If we're followed by a blank line, skip it, so that we don't end
        // up with an extra paragraph for that blank line.
        if (parser.current.content.trim().isEmpty) {
          parser.advance();
        }

        // We're done.
        break;
      }

      childLines.add(parser.current.content);
      parser.advance();
    }

    return childLines.map((l) => md.Line(l)).toList();
  }

  // This method was adapted from the standard Blockquote parser, and
  // the standard code fence block parser.
  @override
  md.Node parse(md.BlockParser parser) {
    final childLines = parseChildLines(parser);

    return md.Element('callout', [md.Text(childLines.join("\n"))]);
  }
}

/// An [ElementToNodeConverter] that converts a "callout" Markdown [md.Element]
/// to a [ParagraphNode].
class CalloutElementToNodeConverter implements ElementToNodeConverter {
  @override
  DocumentNode? handleElement(md.Element element) {
    if (element.tag != "callout") {
      return null;
    }

    return ParagraphNode(
      id: Editor.createNodeId(),
      text: _parseInlineText(element),
      metadata: const {
        'blockType': NamedAttribution("callout"),
      },
    );
  }
}

AttributedText _parseInlineText(md.Element element) {
  final inlineVisitor = _parseInline(element);
  return inlineVisitor.attributedText;
}

_InlineMarkdownToDocument _parseInline(md.Element element) {
  final inlineParser = md.InlineParser(
    element.textContent,
    md.Document(
      inlineSyntaxes: [
        SingleStrikethroughSyntax(), // this needs to be before md.StrikethroughSyntax to be recognized
        md.StrikethroughSyntax(),
        UnderlineSyntax(),
      ],
    ),
  );
  final inlineVisitor = _InlineMarkdownToDocument();
  final inlineNodes = inlineParser.parse();
  for (final inlineNode in inlineNodes) {
    inlineNode.accept(inlineVisitor);
  }
  return inlineVisitor;
}

class _InlineMarkdownToDocument implements md.NodeVisitor {
  _InlineMarkdownToDocument();

  // For our purposes, we only support block-level images. Therefore,
  // if we find an image without any text, we're parsing an image.
  // Otherwise, if there is any text, then we're parsing a paragraph
  // and we ignore the image.
  bool get isImage => _imageUrl != null && attributedText.isEmpty;

  String? _imageUrl;
  String? get imageUrl => _imageUrl;

  String? _imageAltText;
  String? get imageAltText => _imageAltText;

  AttributedText get attributedText => _textStack.first;

  final List<AttributedText> _textStack = [AttributedText()];

  @override
  bool visitElementBefore(md.Element element) {
    if (element.tag == 'img') {
      // TODO: handle missing "src" attribute
      _imageUrl = element.attributes['src']!;
      _imageAltText = element.attributes['alt'] ?? '';
      return true;
    }

    _textStack.add(AttributedText());

    return true;
  }

  @override
  void visitText(md.Text text) {
    final attributedText = _textStack.removeLast();
    _textStack.add(attributedText.copyAndAppend(AttributedText(text.text)));
  }

  @override
  void visitElementAfter(md.Element element) {
    // Reset to normal text style because a plain text element does
    // not receive a call to visitElementBefore().
    final styledText = _textStack.removeLast();

    if (element.tag == 'strong') {
      styledText.addAttribution(
        boldAttribution,
        SpanRange(0, styledText.length - 1),
      );
    } else if (element.tag == 'em') {
      styledText.addAttribution(
        italicsAttribution,
        SpanRange(0, styledText.length - 1),
      );
    } else if (element.tag == "del") {
      styledText.addAttribution(
        strikethroughAttribution,
        SpanRange(0, styledText.length - 1),
      );
    } else if (element.tag == "u") {
      styledText.addAttribution(
        underlineAttribution,
        SpanRange(0, styledText.length - 1),
      );
    } else if (element.tag == 'a') {
      styledText.addAttribution(
        LinkAttribution.fromUri(Uri.parse(element.attributes['href']!)),
        SpanRange(0, styledText.length - 1),
      );
    }

    if (_textStack.isNotEmpty) {
      final surroundingText = _textStack.removeLast();
      _textStack.add(surroundingText.copyAndAppend(styledText));
    } else {
      _textStack.add(styledText);
    }
  }
}

class CalloutSerializer implements DocumentNodeMarkdownSerializer {
  @override
  String? serialize(Document document, DocumentNode node, {NodeSelection? selection}) {
    if (node is! ParagraphNode) {
      return null;
    }
    if (node.metadata["blockType"] != const NamedAttribution("callout")) {
      return null;
    }

    final buffer = StringBuffer();
    buffer.writeln("@@@ callout");
    buffer.writeln(node.text.toMarkdown());
    buffer.writeln("@@@");
    return buffer.toString();
  }
}
