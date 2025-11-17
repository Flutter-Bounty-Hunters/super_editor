import 'package:attributed_text/attributed_text.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/default_editor/multi_node_editing.dart';
import 'package:super_editor/src/default_editor/super_editor.dart';
import 'package:super_editor/src/default_editor/text.dart';

/// A [SuperEditorPlugin] that finds inline Markdown syntax immediately upstream from the
/// caret and converts it into attributions.
///
/// See [MarkdownInlineUpstreamSyntaxReaction] to learn more about how Markdown is located
/// and applied by this plugin.
///
/// To add this plugin to a [SuperEditor] widget, provide a [MarkdownInlineUpstreamSyntaxPlugin] in
/// the `plugins` property.
///
///   SuperEditor(
///     //...
///     plugins: {
///       markdownInlineUpstreamSyntaxPlugin,
///     },
///   );
///
/// To add this plugin directly to an [Editor], without involving a [SuperEditor]
/// widget, call [attach] with the given [Editor]. When that [Editor] is no longer needed,
/// call [detach] to clean up all plugin references.
///
///   markdownInlineUpstreamSyntaxPlugin.attach(editor);
///
///
class MarkdownInlineUpstreamSyntaxPlugin extends SuperEditorPlugin {
  MarkdownInlineUpstreamSyntaxPlugin({
    List<UpstreamMarkdownInlineSyntax> parsers = defaultUpstreamInlineMarkdownParsers,
  }) {
    _markdownInlineUpstreamSyntaxReaction = MarkdownInlineUpstreamSyntaxReaction(parsers);
  }

  /// An [EditReaction] that finds and converts Markdown styling into attributed
  /// styles.
  late final EditReaction _markdownInlineUpstreamSyntaxReaction;

  @override
  void attach(Editor editor) {
    editor.reactionPipeline.insert(0, _markdownInlineUpstreamSyntaxReaction);
  }

  @override
  void detach(Editor editor) {
    editor.reactionPipeline.remove(_markdownInlineUpstreamSyntaxReaction);
  }
}

const defaultUpstreamInlineMarkdownParsers = [
  StyleUpstreamMarkdownSyntaxParser(),
];

/// An [EditReaction] that finds inline Markdown syntax immediately upstream from the
/// caret and converts it into attributions.
///
/// Inline Markdown syntax includes things like `**token**` for bold, `*token*` for
/// italics, `~token~` for strikethrough, and `[name](url)` for links.
///
/// When this reaction finds inline Markdown syntax, that syntax is removed when the corresponding
/// attribution is applied. For example, "**bold**" becomes "bold" with a bold attribution
/// applied to it.
///
/// This reaction only identifies spans of Markdown styles within individual [TextNode]s, which
/// immediately precedes the caret. For example, "Hello **bold**|" will apply the bold style,
/// but "Hello **bold** wo|" won't apply bold.
///
/// Parsing of links is handled differently than all other upstream syntax. Links use a fairly
/// complicated syntax, so they're identified with a regular expression. All other upstream
/// inline syntaxes are parsed character by character, moving upstream from the caret position.
class MarkdownInlineUpstreamSyntaxReaction extends EditReaction {
  const MarkdownInlineUpstreamSyntaxReaction(this._parsers);

  final List<UpstreamMarkdownInlineSyntax> _parsers;

  @override
  void react(EditContext editContext, RequestDispatcher requestDispatcher, List<EditEvent> changeList) {
    if (changeList.whereType<DocumentEdit>().isEmpty) {
      // No edits means no Markdown insertions. Nothing for this plugin to do.
      return;
    }
    if (changeList.where((edit) => edit is DocumentEdit && edit.change is TextInsertionEvent).isEmpty) {
      // No text insertions. Nothing for this reaction to do.
      return;
    }

    final document = editContext.find<MutableDocument>(Editor.documentKey);
    final composer = editContext.find<MutableDocumentComposer>(Editor.composerKey);
    final selection = composer.selection;
    if (selection == null) {
      // No selection, so no caret for us to search upstream.
      return;
    }
    if (!selection.isCollapsed) {
      // It's not clear how the user would insert a Markdown character when the
      // selection is expanded. Fizzle.
      return;
    }
    final extent = selection.extent;

    final editedTextNodeIds = _findEditedTextNodes(document, changeList);
    if (!editedTextNodeIds.contains(extent.nodeId)) {
      // None of the changes happened in the node where the caret sits. Therefore,
      // there's no way the user added Markdown styling near the caret.
      return;
    }

    final editRequests = _applyInlineMarkdownBeforeCaret(document, extent);
    if (editRequests.isEmpty) {
      // No inline Markdown was applied. Fizzle.
      return;
    }

    requestDispatcher.execute(editRequests);
  }

  /// Finds and returns the node IDs for every [TextNode] that was altered during this
  /// transaction.
  Set<String> _findEditedTextNodes(Document document, List<EditEvent> changeList) {
    final editedTextNodes = <String>{};
    for (final change in changeList) {
      if (change is! DocumentEdit || change.change is! NodeDocumentChange) {
        continue;
      }

      final nodeId = (change.change as NodeDocumentChange).nodeId;
      if (editedTextNodes.contains(nodeId)) {
        continue;
      }

      if (document.getNodeById(nodeId) is! TextNode) {
        continue;
      }

      editedTextNodes.add(nodeId);
    }

    return editedTextNodes;
  }

  List<EditRequest> _applyInlineMarkdownBeforeCaret(
    Document document,
    DocumentPosition caretPosition,
  ) {
    final editedNode = document.getNodeById(caretPosition.nodeId) as TextNode;
    final caretOffset = (caretPosition.nodePosition as TextNodePosition).offset;
    final inlineParser = _UpstreamInlineMarkdownParser(
      _parsers,
      editedNode.text,
      caretOffset: caretOffset,
    );

    final markdownRun = inlineParser.findMarkdown();
    if (markdownRun == null) {
      return const [];
    }

    final newCaretPosition = DocumentPosition(
      nodeId: editedNode.id,
      nodePosition: TextNodePosition(offset: markdownRun.start + markdownRun.replacementText.length),
    );
    return [
      // Delete the whole run of Markdown text, e.g., "**my bold**".
      DeleteContentRequest(
        documentRange: DocumentRange(
          start: DocumentPosition(
            nodeId: editedNode.id,
            nodePosition: TextNodePosition(offset: markdownRun.start),
          ),
          end: DocumentPosition(
            nodeId: editedNode.id,
            nodePosition: TextNodePosition(offset: markdownRun.end),
          ),
        ),
      ),
      // Insert the non-Markdown content with styles, e.g., "bold" with a bold attribution.
      InsertAttributedTextRequest(
        DocumentPosition(
          nodeId: editedNode.id,
          nodePosition: TextNodePosition(offset: markdownRun.start),
        ),
        markdownRun.replacementText,
      ),
      // Adjust the caret position to reflect any Markdown syntax characters that
      // were removed.
      ChangeSelectionRequest(
        DocumentSelection.collapsed(
          position: newCaretPosition,
        ),
        SelectionChangeType.alteredContent,
        SelectionReason.contentChange,
      ),
      ChangeComposingRegionRequest(
        DocumentRange(
          start: newCaretPosition,
          end: newCaretPosition,
        ),
      ),
    ];
  }
}

/// A specialized Markdown parser that starts a given caret offset and then works its
/// way upstream to find inline Markdown tokens.
///
/// The parser finds and returns a single [_InlineMarkdownRun], if one exists.
///
/// The parser moves character by character upstream from the caret. Each time the
/// parser encounters a character that might be part of the end of an inline syntax,
/// that possible token is added to a set of candidates. When the upstream parser
/// locates a corresponding upstream inline syntax token, the completed syntax is
/// added to a set of completed syntaxes.
///
/// The reason that multiple completed syntaxes are tracked is because the Markdown
/// syntax allows for ambiguities.
///
/// For example, the parser finds
///
///   "*word**|"
///
/// Notice that "*word*" is a completed token, but it' very likely that if
/// the parser moves one more character upstream, it will find...
///
///   "**word**|"
///
/// In this case, the parser wants to apply bold, not italics. Therefore,
/// the heuristic that makes sense is to keep parsing upstream until there
/// aren't any possible matches left, and then apply whichever syntax was
/// completed last.
class _UpstreamInlineMarkdownParser {
  _UpstreamInlineMarkdownParser(
    this.parsers,
    this.attributedText, {
    required this.caretOffset,
  });

  final List<UpstreamMarkdownInlineSyntax> parsers;
  final AttributedText attributedText;
  final int caretOffset;

  final _possibleSyntaxes = <UpstreamMarkdownToken>[];

  _InlineMarkdownRun? findMarkdown() {
    if (caretOffset == 0) {
      // Can't possibly have an upstream Markdown syntax when the caret is
      // at the beginning of the text.
      return null;
    }

    // Run the special case of parsing a link. This is a special case because the syntax
    // is complicated enough that we don't want to try to accumulate characters as the
    // user types.
    final linkRun = _tryCreateLinkRun();
    if (linkRun != null) {
      return linkRun;
    }

    int offset = caretOffset - 1;

    // Start visiting upstream characters by visiting the first character
    // and checking for possible syntaxes.
    for (final parser in parsers) {
      final markdownToken = parser.startWith(attributedText[offset] as String, offset);
      if (markdownToken != null) {
        _possibleSyntaxes.add(markdownToken);
      }
    }

    final successfulParsers = <UpstreamMarkdownToken>[];
    while (offset > 0 && _possibleSyntaxes.isNotEmpty) {
      offset -= 1;

      // Update all existing possible syntaxes and remove any possible syntaxes
      // that are now invalid due to the new character.
      _updatePossibleSyntaxes(attributedText[offset] as String, offset);

      // Store any successful parsers on a stack. We keep searching after successful
      // parsing because some parsers are essentially supersets of others, e.g., "*"
      // will succeed when we really want to keep parsing and find "**".
      successfulParsers.addAll(_possibleSyntaxes.where((parser) => parser.isComplete && parser.isValid));
      _possibleSyntaxes.removeWhere((parser) => parser.isComplete);

      if (offset > 0) {
        // There's still at least one character upstream from this one. Make sure
        // that all of our successful parsers are allowed to appear after that
        // upstream character.
        //
        // An example where this check is needed is the following:
        //
        //   We found "*word*"
        //
        //   Actual text is "**word*"
        //
        // Finding a completed syntax isn't enough. We need to ensure that the
        // immediate upstream character before the syntax doesn't invalidate it.
        final upstreamCharacter = attributedText[offset - 1] as String;
        successfulParsers.removeWhere((parser) => !parser.canFollowCharacter(upstreamCharacter));
      }
    }

    if (successfulParsers.isEmpty) {
      return null;
    }

    // Select the completed syntax that we found last.
    final successfulParser = successfulParsers.last;

    return _InlineMarkdownRun(
      successfulParser.calculateFinalText(attributedText),
      offset,
      // Note: end offset is exclusive.
      caretOffset,
    );
  }

  _InlineMarkdownRun? _tryCreateLinkRun() {
    if (caretOffset < 2) {
      // There's not enough text before the caret to possibly hold a link. Fizzle.
      return null;
    }

    final characterAtCaret = attributedText[caretOffset - 1] as String; // -1 because caret sits after character
    if (characterAtCaret != " ") {
      // Don't linkify unless the user just inserted a space after the token.
      return null;
    }

    final endOfTokenOffset = caretOffset - 2;
    if (attributedText[endOfTokenOffset] != ")") {
      // All links end with a ")", therefore we know the upstream token
      // isn't a link. Short-circuit return.
      return null;
    }

    final markdownLinkRegex = RegExp(r'\[([\w\s\d]+)]\(((?:|https?://)[\w\d./?=#]+)\)');
    final matches = markdownLinkRegex.allMatches(attributedText.toPlainText());
    if (matches.isEmpty) {
      // Didn't find any links.
      return null;
    }

    // Found some links. See if any of them are immediately upstream.
    for (final match in matches) {
      if (match.end - 1 == endOfTokenOffset) {
        // We found a Markdown link immediately upstream. Return it.
        final linkName = match.group(1)!;
        final linkUrl = match.group(2)!;
        final linkAttribution = LinkAttribution(linkUrl);

        return _InlineMarkdownRun(
          AttributedText(
            "$linkName ", // Explicitly add the trailing space so the caret stays after the space.
            AttributedSpans(attributions: [
              SpanMarker(
                attribution: linkAttribution,
                offset: 0,
                markerType: SpanMarkerType.start,
              ),
              SpanMarker(
                attribution: linkAttribution,
                offset: linkName.length - 1,
                markerType: SpanMarkerType.end,
              ),
            ]),
          ),
          match.start,
          match.end + 1, // +1 to include the space after the link so the caret stays in same place.
        );
      }
    }

    // We found links, but none of them are immediately upstream.
    return null;
  }

  void _updatePossibleSyntaxes(String character, int characterIndex) {
    // Update all existing possible syntaxes.
    for (int i = _possibleSyntaxes.length - 1; i >= 0; i -= 1) {
      // Add the latest character to the existing syntax parser.
      _possibleSyntaxes[i].prependCharacter(character);

      if (!_possibleSyntaxes[i].isValid) {
        // This syntax is no longer valid. Remove it.
        _possibleSyntaxes.removeAt(i);
      }
    }
  }
}

/// A parser for a specific set of inline Markdown syntaxes, based on
/// the offset of a caret.
///
/// The syntax that's parsed is determined by the implementer.
abstract interface class UpstreamMarkdownInlineSyntax {
  /// Checks the given [character], and if that [character] might represent
  /// the trailing end of an inline token, that token is returned, otherwise
  /// `null` is returned.
  ///
  /// The given [atTextIndex] is the index of the [character] within the
  /// larger text blob.
  ///
  /// For example, given a starting [character] of "*", a token might be
  /// returned which is capable of identifying italics "*" and bold "**".
  /// But if the [character] is "#", then `null` is returned because no
  /// Markdown syntax ends with a "#".
  UpstreamMarkdownToken? startWith(String character, int atTextIndex);
}

/// A Markdown token that's assembled by a specific [UpstreamMarkdownInlineSyntax].
///
/// An [UpstreamMarkdownToken] grows one character at a time until it either completes
/// a valid Markdown token, or reaches a point where it's an invalid Markdown token.
abstract interface class UpstreamMarkdownToken {
  /// Whether this parser still contains a valid syntax.
  ///
  /// Upstream parsers are told to consume one character after another with
  /// [prependCharacter]. A syntax that begins valid, such as "*" might then become
  /// invalid when adding another character, such as "~*". When adding a character
  /// invalidates the syntax, this property switches from `true` to `false`.
  bool get isValid;

  /// Whether the current text within this parser represents a complete Markdown
  /// syntax.
  ///
  /// The parser is considered complete when it finds both opening and closing
  /// syntaxes of the same form, e.g., "*italics*" or "**bold**".
  bool get isComplete;

  /// Prepends the given upstream [character] to this syntax and then re-evaluates
  /// the validity of this syntax.
  ///
  /// The following are some examples of a syntax that prepends a character and remains
  /// valid:
  ///
  ///   - "*" -> "**"
  ///   - "**" -> "***"
  ///   - "_" -> "_"
  ///   - "__" -> "___"
  ///
  /// The following are some example of a syntax that prepends a character and becomes
  /// invalid:
  ///
  ///   - "***" -> "****"
  ///   - "___" -> "____"
  ///   - "~" -> "*~"
  ///
  /// After prepending a character, clients should check [isValid] to ensure that this
  /// syntax is still a valid Markdown syntax.
  void prependCharacter(String character);

  /// Returns `true` if this completed syntax is allowed to immediately follow the given
  /// [character], or `false` if following the [character] would invalidate this syntax.
  ///
  /// For example, it's legal to apply italics in strings like " *italics*" and "h*italics*"
  /// but it's not appropriate to apply italics when there are more "*" such as "**italics*".
  bool canFollowCharacter(String character);

  /// Calculates the [AttributedText] that should replace the [existingText] based on the
  /// parsed Markdown.
  ///
  /// This should only be called when [isComplete] is `true`.
  ///
  /// The final text is calculated based on a given [existingText], rather than returned
  /// in isolation, because the final attributions might be based on existing attributions.
  /// For example, applying bold shouldn't remove existing italics, and vis-a-versa.
  /// But this decision about which attributions to retain needs to be a per-parser
  /// responsibility. For example, it might not make sense to retain bold or italics if
  /// the user applies an inline code style.
  AttributedText calculateFinalText(AttributedText existingText);
}

/// An [UpstreamMarkdownInlineSyntax] that parses standard Markdown styles, e.g.,
/// bold, italics, code, strikethrough.
class StyleUpstreamMarkdownSyntaxParser implements UpstreamMarkdownInlineSyntax {
  const StyleUpstreamMarkdownSyntaxParser();

  @override
  UpstreamMarkdownToken? startWith(String character, int atTextIndex) {
    if (!StyleUpstreamMarkdownToken.possibleStartCharacters.contains(character)) {
      return null;
    }

    switch (character) {
      case "*":
      case "_":
        return StyleUpstreamMarkdownToken(character, 3, atTextIndex);
      case "~":
      case "`":
        return StyleUpstreamMarkdownToken(character, 1, atTextIndex);
      default:
        throw Exception("Unrecognized Markdown style trigger: '$character'");
    }
  }
}

/// An [UpstreamMarkdownToken] that applies standard inline Markdown styles,
/// e.g., bold, italics, strikethrough, and code.
class StyleUpstreamMarkdownToken implements UpstreamMarkdownToken {
  static const possibleStartCharacters = {"*", "_", "~", "`"};

  static const _lookingForCloseSyntax = 1;
  static const _lookingForOpenSyntax = 2;
  static const _done = 3;

  StyleUpstreamMarkdownToken(this._triggerCharacter, this._maxSyntaxLength, this._triggerIndex)
      : assert(_triggerCharacter.length == 1),
        assert(possibleStartCharacters.contains(_triggerCharacter)),
        _closingSyntax = _triggerCharacter {
    if (_maxSyntaxLength == 1) {
      // Only one closing character is allowed, so we start off already looking
      // for the opening syntax upstream.
      _phase = _lookingForOpenSyntax;
    } else {
      // The closing syntax might be 1+ character, so we start off by looking for
      // more closing syntax characters.
      _phase = _lookingForCloseSyntax;
    }

    _allParsedText = _triggerCharacter;
    _currentIndex = _triggerIndex;
  }

  final String _triggerCharacter;
  final int _triggerIndex;
  final int _maxSyntaxLength;
  String _allParsedText = "";
  late int _currentIndex;

  String _closingSyntax;
  String _openingSyntax = "";
  late int _phase = _lookingForCloseSyntax;

  @override
  bool get isValid => _isValid;
  bool _isValid = true;

  @override
  bool get isComplete => _isComplete;
  bool _isComplete = false;

  @override
  void prependCharacter(String character) {
    _allParsedText = "$character$_allParsedText";
    _currentIndex -= 1;

    switch (_phase) {
      case _lookingForCloseSyntax:
        if (character == _triggerCharacter) {
          // We found another character that belongs to our style syntax, e.g.,
          // from "*" to "**", from "_" to "__".
          _closingSyntax = "$character$_closingSyntax";
        } else {
          // We've moved from the closing syntax into the styled content.
          _phase = _lookingForOpenSyntax;
        }
      case _lookingForOpenSyntax:
        if (character == _triggerCharacter) {
          // Prepend the current character to what might end up being the starting
          // syntax.
          _openingSyntax = "$character$_openingSyntax";
        } else {
          _openingSyntax = "";
        }

        if (_openingSyntax == _closingSyntax) {
          if (_allParsedText.length == _openingSyntax.length * 2) {
            // We just found an opening syntax that matches our closing syntax,
            // but there is no text between the opening and closing syntax.
            // Therefore, this is an invalid Markdown style.
            _isValid = false;
          } else {
            // We just found an opening syntax that matches our closing syntax.
            // Therefore, we have found a complete Markdown run.
            _isComplete = true;
            _phase = _done;
          }
        }
      case _done:
        // More characters were added after already finding a complete Markdown
        // style. This changes the syntax from valid to invalid because its now
        // more than just a style.
        _isValid = false;
    }
  }

  @override
  bool canFollowCharacter(String character) {
    return character == " ";
  }

  @override
  AttributedText calculateFinalText(AttributedText existingText) {
    if (!_isComplete) {
      throw Exception(
        "Can't calculate inline Markdown text for a parser whose content is incomplete: '${_allParsedText.toString()}'.",
      );
    }
    if (!_isValid) {
      throw Exception(
          "Can't calculate inline Markdown text for a parser whose content is invalid: '${_allParsedText.toString()}'.");
    }

    final newStyles = <Attribution>{};
    switch (_openingSyntax) {
      case "***":
      case "___":
        newStyles.addAll([italicsAttribution, boldAttribution]);
      case "**":
      case "__":
        newStyles.add(boldAttribution);
      case "*":
      case "_":
        newStyles.add(italicsAttribution);
      case "~":
        newStyles.add(strikethroughAttribution);
      case "`":
        newStyles.add(codeAttribution);
    }

    // Imagine that we've identified something like "**token**". In that case, we'd
    // want to remove the opening and closing "**" and then apply bold to the rest of
    // the text. We want to leave any other existing attributions alone.
    final syntaxLength = _closingSyntax.length;
    final appliedText = existingText.copyText(
      _currentIndex + syntaxLength,
      _triggerIndex - syntaxLength + 1,
    );
    for (final attribution in newStyles) {
      appliedText.addAttribution(attribution, SpanRange(0, appliedText.length - 1));
    }

    return appliedText;
  }
}

/// The span of text where a Markdown snippet resides, e.g., "**bold**",
/// and the [AttributedText] that should replace it, e.g., "bold" with
/// a bold attribution.
class _InlineMarkdownRun {
  const _InlineMarkdownRun(this.replacementText, this.start, this.end);

  /// A snippet of text with some kind of Markdown syntax applied to it.
  ///
  /// The Markdown syntax is included in this value, e.g., "**word**.
  final AttributedText replacementText;

  /// The index of the first character of a Markdown snippet within a larger
  /// piece of text.
  final int start;

  /// The index immediately after the last character of a Markdown snippet
  /// within a larger piece of text.
  final int end;
}
