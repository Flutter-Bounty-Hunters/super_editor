import 'package:attributed_text/attributed_text.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/infrastructure/serialization/markdown/image_syntax.dart';
import 'package:super_editor/src/infrastructure/serialization/markdown/markdown_to_document_parsing.dart';

/// Parses inline markdown content.
///
/// {@macro markdown_two_phase}
///
/// {@macro inline_markdown_syntaxes}
///
/// If [encodeHtml] is `true`, it escapes HTML symbols like &, <, and >. For example,
/// `&` becomes `&amp;`, `<` becomes `&lt;`, and `>` becomes `&gt;`.
AttributedText parseInlineMarkdown(
  String text, {
  Iterable<md.InlineSyntax>? inlineMarkdownSyntaxes,
  Iterable<InlineHtmlSyntax>? inlineHtmlSyntaxes,
  bool encodeHtml = false,
}) {
  final inlineParser = md.InlineParser(
    text,
    md.Document(
      inlineSyntaxes: inlineMarkdownSyntaxes ?? defaultSuperEditorInlineSyntaxes,
      encodeHtml: encodeHtml,
    ),
  );
  final inlineVisitor = _InlineMarkdownToDocument(
    inlineHtmlSyntaxes: inlineHtmlSyntaxes ?? defaultInlineHtmlSyntaxes,
  );
  final inlineNodes = inlineParser.parse();
  for (final inlineNode in inlineNodes) {
    inlineNode.accept(inlineVisitor);
  }
  return inlineVisitor.attributedText;
}

final defaultSuperEditorInlineSyntaxes = [
  PreservedEscapeSyntax(), // must run before the markdown package's EscapeSyntax, which discards the backslash
  SingleStrikethroughSyntax(), // this needs to be before md.StrikethroughSyntax to be recognized
  md.StrikethroughSyntax(),
  UnderlineSyntax(),
  HtmlUnderlineSyntax(),
  SuperEditorImageSyntax(),
];

final defaultNonSuperEditorInlineSyntaxes = [
  PreservedEscapeSyntax(), // must run before the markdown package's EscapeSyntax, which discards the backslash
  SingleStrikethroughSyntax(), // this needs to be before md.StrikethroughSyntax to be recognized
  md.StrikethroughSyntax(),
  UnderlineSyntax(),
  HtmlUnderlineSyntax(),
];

/// Attribution applied to characters that were backslash-escaped in the Markdown
/// source, e.g., the `*` in "3\*4".
///
/// The parser strips the backslash so the user sees the bare character, and the
/// serializer re-emits the backslash for any character carrying this attribution.
/// Without it, "3\*4" would save as "3*4" and the markers could be re-interpreted
/// as emphasis on the next parse.
const markdownEscapeAttribution = NamedAttribution('markdownEscape');

/// Matches a backslash-escaped ASCII punctuation character, like the markdown
/// package's own `EscapeSyntax`, but wraps the escaped character in an element
/// so that the escape survives the round trip as [markdownEscapeAttribution].
class PreservedEscapeSyntax extends md.InlineSyntax {
  PreservedEscapeSyntax()
      : super(
          r'''\\([!"#$%&'()*+,\-./:;<=>?@\[\\\]^_`{|}~])''',
          startCharacter: 0x5C, // backslash
        );

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('mdEscape', match[1]!));
    return true;
  }
}

/// Matches underline spans written as inline HTML, e.g., "this is <u>underline</u> text".
///
/// `<u>text</u>` is the only widely supported way to express underlines in Markdown,
/// and it's what Super Editor serializes underlines to. The legacy `¬` marker
/// ([UnderlineSyntax]) is still parsed for backwards compatibility.
class HtmlUnderlineSyntax extends md.InlineSyntax {
  HtmlUnderlineSyntax()
      : super(
          r'<u>([\s\S]*?)</u>',
          startCharacter: 0x3C, // '<'
        );

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    // Parse the inner content so that styles nested within the underline,
    // e.g., "<u>**bold**</u>", are preserved.
    final children = md.InlineParser(match[1]!, parser.document).parse();
    parser.addNode(md.Element('u', children));
    return true;
  }
}

/// Parses inline markdown content.
///
/// Apply [_InlineMarkdownToDocument] to a text [md.Element] to
/// obtain an [AttributedText] that represents the inline
/// styles within the given text.
///
/// [_InlineMarkdownToDocument] does not support parsing text
/// that contains image tags. If any non-image text is found,
/// the content is treated as styled text.
class _InlineMarkdownToDocument implements md.NodeVisitor {
  _InlineMarkdownToDocument({
    required this.inlineHtmlSyntaxes,
  });

  final Iterable<InlineHtmlSyntax> inlineHtmlSyntaxes;

  AttributedText get attributedText => _textStack.first;

  final List<AttributedText> _textStack = [AttributedText()];

  @override
  bool visitElementBefore(md.Element element) {
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
    var styledText = _textStack.removeLast();

    for (final inlineHtmlSyntax in inlineHtmlSyntaxes) {
      final finalText = inlineHtmlSyntax(element, styledText);
      if (finalText != null) {
        styledText = finalText;
        break;
      }
    }

    if (_textStack.isNotEmpty) {
      final surroundingText = _textStack.removeLast();
      _textStack.add(surroundingText.copyAndAppend(styledText));
    } else {
      _textStack.add(styledText);
    }
  }
}

const defaultInlineHtmlSyntaxes = [
  boldHtmlSyntax,
  italicHtmlSyntax,
  underlineHtmlSyntax,
  strikethroughHtmlSyntax,
  anchorHtmlSyntax,
  codeInlineHtmlSyntax,
  escapedCharacterHtmlSyntax,
];

typedef InlineHtmlSyntax = AttributedText? Function(md.Element element, AttributedText text);

AttributedText? boldHtmlSyntax(md.Element element, AttributedText text) {
  if (element.tag != 'strong') {
    return null;
  }

  return text
    ..addAttribution(
      boldAttribution,
      SpanRange(0, text.length - 1),
    );
}

AttributedText? italicHtmlSyntax(md.Element element, AttributedText text) {
  if (element.tag != 'em') {
    return null;
  }

  return text
    ..addAttribution(
      italicsAttribution,
      SpanRange(0, text.length - 1),
    );
}

AttributedText? underlineHtmlSyntax(md.Element element, AttributedText text) {
  if (element.tag != 'u') {
    return null;
  }

  return text
    ..addAttribution(
      underlineAttribution,
      SpanRange(0, text.length - 1),
    );
}

AttributedText? strikethroughHtmlSyntax(md.Element element, AttributedText text) {
  if (element.tag != 'del') {
    return null;
  }

  return text
    ..addAttribution(
      strikethroughAttribution,
      SpanRange(0, text.length - 1),
    );
}

AttributedText? anchorHtmlSyntax(md.Element element, AttributedText text) {
  if (element.tag != 'a') {
    return null;
  }

  return text
    ..addAttribution(
      LinkAttribution.fromUri(Uri.parse(element.attributes['href']!)),
      SpanRange(0, text.length - 1),
    );
}

AttributedText? codeInlineHtmlSyntax(md.Element element, AttributedText text) {
  if (element.tag != 'code') {
    return null;
  }

  return text
    ..addAttribution(
      codeAttribution,
      SpanRange(0, text.length - 1),
    );
}

AttributedText? escapedCharacterHtmlSyntax(md.Element element, AttributedText text) {
  if (element.tag != 'mdEscape') {
    return null;
  }

  return text
    ..addAttribution(
      markdownEscapeAttribution,
      SpanRange(0, text.length - 1),
    );
}
