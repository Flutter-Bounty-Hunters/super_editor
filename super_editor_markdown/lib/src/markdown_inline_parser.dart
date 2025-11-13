import 'package:markdown/markdown.dart' as md;
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_markdown/src/image_syntax.dart';
import 'package:super_editor_markdown/super_editor_markdown.dart';

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
  SingleStrikethroughSyntax(), // this needs to be before md.StrikethroughSyntax to be recognized
  md.StrikethroughSyntax(),
  UnderlineSyntax(),
  SuperEditorImageSyntax(),
];

final defaultNonSuperEditorInlineSyntaxes = [
  SingleStrikethroughSyntax(), // this needs to be before md.StrikethroughSyntax to be recognized
  md.StrikethroughSyntax(),
  UnderlineSyntax(),
];

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
