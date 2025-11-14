import 'package:markdown/markdown.dart' as md;
import 'package:super_editor/src/default_editor/image.dart';

/// Matches all images.
///
/// For example: `![My Image](https://my-image.com)` and `![My Image](https://my-image.com =500x200)`
///
/// To define a size, use the notation `=widthxheight`. The size notation is optional and
/// it can be providade partially. For example:
///
/// - ![alternate text](url =500x200)
/// - ![alternate text](url =500x)
/// - ![alternate text](url =x200)
///
/// This class was modified from a copy of [md.LinkSyntax].
class SuperEditorImageSyntax extends md.LinkSyntax {
  static final _entirelyWhitespacePattern = RegExp(r'^\s*$.');

  SuperEditorImageSyntax({md.Resolver? linkResolver})
      : super(
          linkResolver: linkResolver,
          pattern: r'!\[',
          startCharacter: AsciiTable.exclamation,
        );

  @override
  Iterable<md.Node>? close(
    md.InlineParser parser,
    covariant md.SimpleDelimiter opener,
    md.Delimiter? closer, {
    String? tag,
    required List<md.Node> Function() getChildren,
  }) {
    var text = parser.source.substring(opener.endPos, parser.pos);
    // The current character is the `]` that closed the link text. Examine the
    // next character, to determine what type of link we might have (a '('
    // means a possible inline link; otherwise a possible reference link).
    if (parser.pos + 1 >= parser.source.length) {
      // The `]` is at the end of the document, but this may still be a valid
      // shortcut reference link.
      return _tryCreateReferenceLink(parser, text, getChildren: getChildren);
    }

    // Peek at the next character; don't advance, so as to avoid later stepping
    // backward.
    var char = parser.charAt(parser.pos + 1);

    if (char == AsciiTable.leftParen) {
      // Maybe an inline link, like `[text](destination)`.
      parser.advanceBy(1);
      var leftParenIndex = parser.pos;
      var inlineLink = _parseInlineLink(parser);
      if (inlineLink != null) {
        return [_tryCreateInlineLink(parser, inlineLink, getChildren: getChildren)];
      }
      // At this point, we've matched `[...](`, but that `(` did not pan out to
      // be an inline link. We must now check if `[...]` is simply a shortcut
      // reference link.

      // Reset the parser position.
      parser.pos = leftParenIndex;
      parser.advanceBy(-1);
      return _tryCreateReferenceLink(parser, text, getChildren: getChildren);
    }

    if (char == AsciiTable.leftBracket) {
      parser.advanceBy(1);
      // At this point, we've matched `[...][`. Maybe a *full* reference link,
      // like `[foo][bar]` or a *collapsed* reference link, like `[foo][]`.
      if (parser.pos + 1 < parser.source.length && parser.charAt(parser.pos + 1) == AsciiTable.rightBracket) {
        // That opening `[` is not actually part of the link. Maybe a
        // *shortcut* reference link (followed by a `[`).
        parser.advanceBy(1);
        return _tryCreateReferenceLink(parser, text, getChildren: getChildren);
      }
      var label = _parseReferenceLinkLabel(parser);
      if (label != null) {
        return _tryCreateReferenceLink(parser, label, getChildren: getChildren);
      }
      return null;
    }

    // The link text (inside `[...]`) was not followed with a opening `(` nor
    // an opening `[`. Perhaps just a simple shortcut reference link (`[...]`).
    return _tryCreateReferenceLink(parser, text, getChildren: getChildren);
  }

  /// Parses a size using the notation `=widthxheight`.
  ///
  /// Returns `null` if the size notation isn't provided.
  ExpectedSize? _tryParseImageSize(md.InlineParser parser) {
    if (parser.charAt(parser.pos) != AsciiTable.equal) {
      // The image size should start with a "=" but the input doesn't. Fizzle.
      return null;
    }

    // Consume the "=".
    parser.advanceBy(1);

    // Parse an optional width.
    final width = _tryParseNumber(parser);

    final downstreamCharacter = parser.source.substring(parser.pos, parser.pos + 1);
    if (downstreamCharacter.toLowerCase() != 'x') {
      // The image size must have a "x" between the width and height, but the input doesn't.  Fizzle.
      return null;
    }

    // Consume the "x".
    parser.advanceBy(1);

    // Parse an optional height.
    final height = _tryParseNumber(parser);

    return ExpectedSize(width, height);
  }

  /// Tries to parse an integer number.
  ///
  /// Returns `null` if it can't find an integer number.
  int? _tryParseNumber(md.InlineParser parser) {
    StringBuffer numberCharacters = StringBuffer();

    while (!parser.isDone && //
        parser.charAt(parser.pos) >= AsciiTable.numberZero &&
        parser.charAt(parser.pos) <= AsciiTable.numberNine) {
      // The current char is between 0-9.
      numberCharacters.writeCharCode(parser.charAt(parser.pos));
      parser.advanceBy(1);
    }

    if (numberCharacters.isEmpty) {
      // We didn't find any digits. Fizzle.
      return null;
    }

    return int.parse(numberCharacters.toString());
  }

  /// Tries to create a reference link node.
  ///
  /// Returns the link if it was successfully created, `null` otherwise.
  List<md.Node>? _tryCreateReferenceLink(md.InlineParser parser, String label,
      {required List<md.Node> Function() getChildren}) {
    return _resolveReferenceLink(label, parser.document.linkReferences, getChildren: getChildren);
  }

  // Tries to create an inline link node.
  //
  /// Returns the link if it was successfully created, `null` otherwise.
  md.Node _tryCreateInlineLink(md.InlineParser parser, MarkdownImage link,
      {required List<md.Node> Function() getChildren}) {
    return createNode(link.destination, link.title, size: link.size, getChildren: getChildren);
  }

  /// Parse an inline [MarkdownImage] at the current position.
  ///
  /// At this point, we have parsed a link's (or image's) opening `[`, and then
  /// a matching closing `]`, and [parser.pos] is pointing at an opening `(`.
  /// This method will then attempt to parse a link destination wrapped in `<>`,
  /// such as `(<http://url>)`, or a bare link destination, such as
  /// `(http://url)`, or a link destination with a title, such as
  /// `(http://url "title")`.
  ///
  /// Returns the [MarkdownImage] if one was parsed, or `null` if not.
  MarkdownImage? _parseInlineLink(md.InlineParser parser) {
    // Start walking to the character just after the opening `(`.
    parser.advanceBy(1);

    _moveThroughWhitespace(parser);
    if (parser.isDone) return null; // EOF. Not a link.

    if (parser.charAt(parser.pos) == AsciiTable.lessThan) {
      // Maybe a `<...>`-enclosed link destination.
      return _parseInlineBracketedLink(parser);
    } else {
      return _parseInlineBareDestinationLink(parser);
    }
  }

  /// Parses a link title in [parser] at it's current position. The parser's
  /// current position should be a whitespace character that followed a link
  /// destination.
  ///
  /// Returns the title if it was successfully parsed, `null` otherwise.
  String? _parseTitle(md.InlineParser parser) {
    _moveThroughWhitespace(parser);
    if (parser.isDone) return null;

    // The whitespace should be followed by a title delimiter.
    final delimiter = parser.charAt(parser.pos);
    if (delimiter != AsciiTable.apostrophe && delimiter != AsciiTable.quote && delimiter != AsciiTable.leftParen) {
      return null;
    }

    final closeDelimiter = delimiter == AsciiTable.leftParen ? AsciiTable.rightParen : delimiter;
    parser.advanceBy(1);

    // Now we look for an un-escaped closing delimiter.
    final buffer = StringBuffer();
    while (true) {
      final char = parser.charAt(parser.pos);
      if (char == AsciiTable.backslash) {
        parser.advanceBy(1);
        final next = parser.charAt(parser.pos);
        if (next != AsciiTable.backslash && next != closeDelimiter) {
          buffer.writeCharCode(char);
        }
        buffer.writeCharCode(next);
      } else if (char == closeDelimiter) {
        break;
      } else {
        buffer.writeCharCode(char);
      }
      parser.advanceBy(1);
      if (parser.isDone) return null;
    }
    final title = buffer.toString();

    // Advance past the closing delimiter.
    parser.advanceBy(1);
    if (parser.isDone) return null;
    _moveThroughWhitespace(parser);
    if (parser.isDone) return null;
    if (parser.charAt(parser.pos) != AsciiTable.rightParen) return null;
    return title;
  }

  /// Resolve a possible reference link.
  ///
  /// Uses [linkReferences], [linkResolver], and [createNode] to try to
  /// resolve [label] into a [Node]. If [label] is defined in
  /// [linkReferences] or can be resolved by [linkResolver], returns a [Node]
  /// that links to the resolved URL.
  ///
  /// Otherwise, returns `null`.
  ///
  /// [label] does not need to be normalized.
  List<md.Node>? _resolveReferenceLink(
    String label,
    Map<String, md.LinkReference> linkReferences, {
    required List<md.Node> Function() getChildren,
  }) {
    final linkReference = linkReferences[_normalizeLinkLabel(label)];
    if (linkReference != null) {
      return [
        createNode(
          linkReference.destination,
          linkReference.title,
          //size: linkReference.size,
          getChildren: getChildren,
        )
      ];
    } else {
      // This link has no reference definition. But we allow users of the
      // library to specify a custom resolver function ([linkResolver]) that
      // may choose to handle this. Otherwise, it's just treated as plain
      // text.

      // Normally, label text does not get parsed as inline Markdown. However,
      // for the benefit of the link resolver, we need to at least escape
      // brackets, so that, e.g. a link resolver can receive `[\[\]]` as `[]`.
      final resolved = linkResolver(label.replaceAll(r'\\', r'\').replaceAll(r'\[', '[').replaceAll(r'\]', ']'));
      if (resolved != null) {
        getChildren();
      }
      return resolved != null ? [resolved] : null;
    }
  }

  /// Parse a reference link label at the current position.
  ///
  /// Specifically, [parser.pos] is expected to be pointing at the `[` which
  /// opens the link label.
  ///
  /// Returns the label if it could be parsed, or `null` if not.
  String? _parseReferenceLinkLabel(md.InlineParser parser) {
    // Walk past the opening `[`.
    parser.advanceBy(1);
    if (parser.isDone) return null;

    var buffer = StringBuffer();
    while (true) {
      var char = parser.charAt(parser.pos);
      if (char == AsciiTable.backslash) {
        parser.advanceBy(1);
        var next = parser.charAt(parser.pos);
        if (next != AsciiTable.backslash && next != AsciiTable.rightBracket) {
          buffer.writeCharCode(char);
        }
        buffer.writeCharCode(next);
      } else if (char == AsciiTable.rightBracket) {
        break;
      } else {
        buffer.writeCharCode(char);
      }
      parser.advanceBy(1);
      if (parser.isDone) return null;
      // TODO(srawlins): only check 999 characters, for performance reasons?
    }

    var label = buffer.toString();

    // A link label must contain at least one non-whitespace character.
    if (_entirelyWhitespacePattern.hasMatch(label)) return null;

    return label;
  }

  /// Parse an inline link with a bracketed destination (a destination wrapped
  /// in `<...>`). The current position of the parser must be the first
  /// character of the destination.
  ///
  /// Returns the link if it was successfully created, `null` otherwise.
  MarkdownImage? _parseInlineBracketedLink(md.InlineParser parser) {
    parser.advanceBy(1);

    ExpectedSize? imageSize;

    var buffer = StringBuffer();
    while (true) {
      var char = parser.charAt(parser.pos);
      if (char == AsciiTable.backslash) {
        parser.advanceBy(1);
        var next = parser.charAt(parser.pos);
        // TODO: Follow the backslash spec better here.
        // http://spec.commonmark.org/0.29/#backslash-escapes
        if (next != AsciiTable.backslash && next != AsciiTable.greaterThan) {
          buffer.writeCharCode(char);
        }
        buffer.writeCharCode(next);
      } else if (char == AsciiTable.lineFeed || char == AsciiTable.carriageReturn || char == AsciiTable.formFeed) {
        // Not a link (no line breaks allowed within `<...>`).
        return null;
      } else if (char == AsciiTable.space) {
        buffer.write('%20');
      } else if (char == AsciiTable.greaterThan) {
        break;
      } else {
        buffer.writeCharCode(char);
      }
      parser.advanceBy(1);
      if (parser.isDone) return null;
    }
    var destination = buffer.toString();

    parser.advanceBy(1);
    var char = parser.charAt(parser.pos);
    if (char == AsciiTable.space ||
        char == AsciiTable.lineFeed ||
        char == AsciiTable.carriageReturn ||
        char == AsciiTable.formFeed) {
      if (char == AsciiTable.space) {
        // We found a space, we might have a title or a size definition after it.
        if (parser.isDone) {
          // We are already at the end. Fizzle.
          return null;
        }

        if (parser.charAt(parser.pos + 1) == AsciiTable.equal) {
          // We found the start of a size definition. Try to parse it.
          parser.advanceBy(1);
          imageSize = _tryParseImageSize(parser);

          if (imageSize != null) {
            // We parsed the image size. Continue to parse the remainder of the input.
          }
        }
      }

      var title = _parseTitle(parser);
      if (title == null && parser.charAt(parser.pos) != AsciiTable.rightParen) {
        // This looked like an inline link, until we found this AsciiTable.$space
        // followed by mystery characters; no longer a link.
        return null;
      }
      return MarkdownImage(destination, title: title, size: imageSize);
    } else if (char == AsciiTable.rightParen) {
      return MarkdownImage(destination, size: imageSize);
    } else {
      // We parsed something like `[foo](<url>X`. Not a link.
      return null;
    }
  }

  /// Parse an inline link with a "bare" destination (a destination _not_
  /// wrapped in `<...>`). The current position of the parser must be the first
  /// character of the destination.
  ///
  /// Returns the link if it was successfully created, `null` otherwise.
  MarkdownImage? _parseInlineBareDestinationLink(md.InlineParser parser) {
    // According to
    // [CommonMark](http://spec.commonmark.org/0.28/#link-destination):
    //
    // > A link destination consists of [...] a nonempty sequence of
    // > characters [...], and includes parentheses only if (a) they are
    // > backslash-escaped or (b) they are part of a balanced pair of
    // > unescaped parentheses.
    //
    // We need to count the open parens. We start with 1 for the paren that
    // opened the destination.
    var parenCount = 1;
    final buffer = StringBuffer();

    ExpectedSize? imageSize;

    while (true) {
      final char = parser.charAt(parser.pos);
      switch (char) {
        case AsciiTable.backslash:
          parser.advanceBy(1);
          if (parser.isDone) return null; // EOF. Not a link.
          final next = parser.charAt(parser.pos);
          // Parentheses may be escaped.
          //
          // http://spec.commonmark.org/0.28/#example-467
          if (next != AsciiTable.backslash && next != AsciiTable.leftParen && next != AsciiTable.rightParen) {
            buffer.writeCharCode(char);
          }
          buffer.writeCharCode(next);
          break;

        case AsciiTable.space:
        case AsciiTable.lineFeed:
        case AsciiTable.carriageReturn:
        case AsciiTable.formFeed:
          final destination = buffer.toString();

          if (char == AsciiTable.space) {
            // We found a space, we might have a title or a size definition after it.
            if (parser.isDone) {
              // We are already at the end. Fizzle.
              return null;
            }

            if (parser.charAt(parser.pos + 1) == AsciiTable.equal) {
              // We found the start of a size definition. Try to parse it.
              parser.advanceBy(1);
              imageSize = _tryParseImageSize(parser);

              if (imageSize != null) {
                // We parsed the image size. Continue to parse the remainder of the input.
                continue;
              }
            }
          }

          final title = _parseTitle(parser);
          if (title == null && (parser.isDone || parser.charAt(parser.pos) != AsciiTable.rightParen)) {
            // This looked like an inline link, until we found this AsciiTable.$space
            // followed by mystery characters; no longer a link.
            return null;
          }
          // [_parseTitle] made sure the title was follwed by a closing `)`
          // (but it's up to the code here to examine the balance of
          // parentheses).
          parenCount--;
          if (parenCount == 0) {
            return MarkdownImage(destination, size: imageSize, title: title);
          }
          break;

        case AsciiTable.leftParen:
          parenCount++;
          buffer.writeCharCode(char);
          break;

        case AsciiTable.rightParen:
          parenCount--;
          if (parenCount == 0) {
            final destination = buffer.toString();
            return MarkdownImage(destination, size: imageSize);
          }
          buffer.writeCharCode(char);
          break;

        default:
          buffer.writeCharCode(char);
      }
      parser.advanceBy(1);
      if (parser.isDone) return null; // EOF. Not a link.
    }
  }

  @override
  md.Element createNode(
    String destination,
    String? title, {
    ExpectedSize? size,
    required List<md.Node> Function() getChildren,
  }) {
    final element = md.Element.empty('img');
    final children = getChildren();
    element.attributes['src'] = destination;
    element.attributes['alt'] = children.map((node) => node.textContent).join();

    if (size?.width != null) {
      element.attributes['width'] = size!.width!.toString();
    }

    if (size?.height != null) {
      element.attributes['height'] = size!.height!.toString();
    }

    if (title != null && title.isNotEmpty) {
      title.replaceAll('&', '&amp;');
      element.attributes['title'] = _escapeAttribute(title.replaceAll('&', '&amp;'));
    }
    return element;
  }

  // Walk the parser forward through any whitespace.
  void _moveThroughWhitespace(md.InlineParser parser) {
    while (!parser.isDone) {
      final char = parser.charAt(parser.pos);
      if (char != AsciiTable.space &&
          char != AsciiTable.tab &&
          char != AsciiTable.lineFeed &&
          char != AsciiTable.vTab &&
          char != AsciiTable.carriageReturn &&
          char != AsciiTable.formFeed) {
        return;
      }
      parser.advanceBy(1);
    }
  }
}

/// One or more whitespace, for compressing.
final _oneOrMoreWhitespacePattern = RegExp('[ \n\r\t]+');

/// "Normalizes" a link label, according to the [CommonMark spec].
///
/// Extracted from the markdown package.
String _normalizeLinkLabel(String label) => label.trim().replaceAll(_oneOrMoreWhitespacePattern, ' ').toLowerCase();

/// Escapes the contents of [value], so that it may be used as an HTML
/// attribute.
///
/// Extracted from the markdown package.
String _escapeAttribute(String value) {
  final result = StringBuffer();
  int ch;
  for (var i = 0; i < value.codeUnits.length; i++) {
    ch = value.codeUnitAt(i);
    if (ch == AsciiTable.backslash) {
      i++;
      if (i == value.codeUnits.length) {
        result.writeCharCode(ch);
        break;
      }
      ch = value.codeUnitAt(i);
      switch (ch) {
        case AsciiTable.quote:
          result.write('&quot;');
          break;
        case AsciiTable.exclamation:
        case AsciiTable.hashSign:
        case AsciiTable.dollar:
        case AsciiTable.percent:
        case AsciiTable.ampersand:
        case AsciiTable.apostrophe:
        case AsciiTable.leftParen:
        case AsciiTable.rightParen:
        case AsciiTable.asterisk:
        case AsciiTable.plus:
        case AsciiTable.comma:
        case AsciiTable.dash:
        case AsciiTable.dot:
        case AsciiTable.slash:
        case AsciiTable.colon:
        case AsciiTable.semicolon:
        case AsciiTable.lessThan:
        case AsciiTable.equal:
        case AsciiTable.greaterThan:
        case AsciiTable.questionMark:
        case AsciiTable.at:
        case AsciiTable.leftBracket:
        case AsciiTable.backslash:
        case AsciiTable.rightBracket:
        case AsciiTable.caret:
        case AsciiTable.underscore:
        case AsciiTable.backquote:
        case AsciiTable.leftBrace:
        case AsciiTable.pipe:
        case AsciiTable.rightBrace:
        case AsciiTable.tilde:
          result.writeCharCode(ch);
          break;
        default:
          result.write('%5C');
          result.writeCharCode(ch);
      }
    } else if (ch == AsciiTable.quote) {
      result.write('%22');
    } else {
      result.writeCharCode(ch);
    }
  }
  return result.toString();
}

/// Codes for a set of characters in the ascii table.
class AsciiTable {
  /// "Horizontal Tab" character.
  static const int tab = 0x09;

  /// "Line feed" control character.
  static const int lineFeed = 0x0A;

  /// "Vertical Tab" control character.
  static const int vTab = 0x0B;

  /// "Form feed" control character.
  static const int formFeed = 0x0C;

  /// "Carriage return" control character.
  static const int carriageReturn = 0x0D;

  /// Space character.
  static const int space = 0x20;

  /// Character `!`.
  static const int exclamation = 0x21;

  /// Character `"`.
  static const int quote = 0x22;

  /// Character `"`.
  static const int doubleQuote = 0x22; // ignore: constant_identifier_names

  /// Character `#`.
  static const int hashSign = 0x23;

  /// Character `$`.
  static const int dollar = 0x24;

  /// Character `%`.
  static const int percent = 0x25;

  /// Character `&`.
  static const int ampersand = 0x26;

  /// Character `'`.
  static const int apostrophe = 0x27;

  /// Character `(`.
  static const int leftParen = 0x28;

  /// Character `)`.
  static const int rightParen = 0x29;

  /// Character `*`.
  static const int asterisk = 0x2A;

  /// Character `+`.
  static const int plus = 0x2B;

  /// Character `,`.
  static const int comma = 0x2C;

  /// Character `-`.
  static const int dash = 0x2D;

  /// Character `.`.
  static const int dot = 0x2E;

  /// Character `/`.
  static const int slash = 0x2F;

  /// Character `0`.
  static const int numberZero = 0x30;

  /// Character `9`.
  static const int numberNine = 0x39;

  /// Character `:`.
  static const int colon = 0x3A;

  /// Character `;`.
  static const int semicolon = 0x3B;

  /// Character `<`.
  static const int lessThan = 0x3C;

  /// Character `=`.
  static const int equal = 0x3D;

  /// Character `>`.
  static const int greaterThan = 0x3E;

  /// Character `?`.
  static const int questionMark = 0x3F;

  /// Character `@`.
  static const int at = 0x40;

  /// Character `[`.
  static const int leftBracket = 0x5B;

  /// Character `\`.
  static const int backslash = 0x5C;

  /// Character `]`.
  static const int rightBracket = 0x5D;

  /// Character `^`.
  static const int caret = 0x5E;

  /// Character `_`.
  static const int underscore = 0x5F;

  /// Character `` ` ``.
  static const int backquote = 0x60;

  /// Character `{`.
  static const int leftBrace = 0x7B;

  /// Character `|`.
  static const int pipe = 0x7C;

  /// Character `}`.
  static const int rightBrace = 0x7D;

  /// Character `~`.
  static const int tilde = 0x7E;
}

/// A parsed image notation.
class MarkdownImage {
  const MarkdownImage(
    this.destination, {
    this.title,
    this.size,
  });

  final String destination;
  final String? title;
  final ExpectedSize? size;
}
