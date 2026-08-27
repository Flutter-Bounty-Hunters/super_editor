import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:super_editor_spellcheck/super_editor_spellcheck.dart';

/// Regression coverage for a "stuck editor" bug: after tapping a spell-check
/// suggestion, every backspace threw and the field became dead to input.
///
/// The cause is entirely inside this plugin:
///
///   * [SpellingErrorSuggestions] caches each misspelled word's range and does
///     NOT reconcile it when the document changes ([SpellingErrorSuggestions.
///     onTransactionEnd] is a no-op). Only the underline styler is shifted on
///     edits, not the suggestion cache the tap handler reads.
///   * So an edit that shortens the text between the spell check completing and
///     the user tapping the word leaves a cached range whose `end` now sits
///     past the end of the text.
///   * The Android tap handler turns that cached range straight into a
///     [DocumentSelection] and commits it (after its 300ms delay) with no
///     validation against the current text. super_editor stores the selection
///     verbatim, so the composer ends up holding an out-of-range selection, and
///     the next character-boundary operation (a backspace) throws.
///
/// These are written in regression form: each asserts the *correct* behavior,
/// so they FAIL against the current (buggy) code and will PASS once the plugin
/// reconciles its suggestion cache on edits (and/or clamps the range it turns
/// into a selection).
void main() {
  group('SuperEditor spellcheck > stale suggestion selection >', () {
    testWidgetsOnAndroid(
      'a suggestion cached before an edit is reconciled, so its range never outlives the text',
      (tester) async {
        // "I love pizzza" -> length 13; the misspelled word is [7, 13), i.e. it
        // touches the end of the text (as in the field report).
        const originalText = 'I love pizzza';
        const misspelledRange = TextRange(start: 7, end: 13);

        final testClock = SpellcheckClock.forTesting(tester);
        final (editor, _) = await _pumpSpellingEditor(
          tester,
          clock: testClock,
          spellChecker: _StaleWordSpellChecker(
            textToFlag: originalText,
            flaggedRange: misspelledRange,
            suggestions: const ['pizza'],
          ),
          // A real, non-zero debounce: the re-check triggered by the edit is
          // still pending when the user taps, so the cache can go stale.
          spellCheckDelay: const Duration(seconds: 10),
        );

        final suggestions = editor.context.find<SpellingErrorSuggestions>(
          SpellingAndGrammarPlugin.spellingErrorSuggestionsKey,
        );

        await tester.placeCaretInParagraph('1', 0);
        testClock.pauseAutomaticFramePumping();
        await tester.typeImeText(originalText);

        // Run the single debounced check for the full sentence and let its async
        // result reach the shared suggestion cache.
        await tester.pump(const Duration(seconds: 10));
        await tester.pump();
        await tester.pump();

        // While the text is unchanged, the cached range validly ends at 13.
        expect(suggestions.getSuggestionsAtTextOffset('1', 9)?.range.end, 13);
        expect(_textLength(editor), 13);

        // The user deletes the trailing character. This is a real edit, so the
        // spell-check reaction runs — but it only shifts the underline styler,
        // not the suggestion cache. We never advance the clock by 10s again, so
        // the debounced re-check that would refresh the cache does not run.
        editor.execute([const DeleteUpstreamCharacterRequest()]);
        await tester.pump();
        expect(_textLength(editor), 12);

        // CONTRACT: after an edit the suggestion cache must be reconciled — no
        // cached range may extend past the end of the current text. A correct
        // fix either drops the suggestion or clamps its range.
        //
        // Fails today: onTransactionEnd is a no-op, so the range still ends at
        // 13 on 12-char text.
        final cached = suggestions.getSuggestionsAtTextOffset('1', 9);
        expect(
          cached == null || cached.range.end <= _textLength(editor),
          isTrue,
          reason: 'stale suggestion range (end=${cached?.range.end}) outlives '
              'the ${_textLength(editor)}-char text',
        );
      },
    );

    testWidgetsOnAndroid(
      'tapping a stale suggestion keeps the selection in range and leaves backspace working',
      (tester) async {
        const originalText = 'I love pizzza';
        const misspelledRange = TextRange(start: 7, end: 13);

        final testClock = SpellcheckClock.forTesting(tester);
        final (editor, plugin) = await _pumpSpellingEditor(
          tester,
          clock: testClock,
          spellChecker: _StaleWordSpellChecker(
            textToFlag: originalText,
            flaggedRange: misspelledRange,
            suggestions: const ['pizza'],
          ),
          spellCheckDelay: const Duration(seconds: 10),
        );

        // Type, spell check, then delete the trailing character to leave the
        // suggestion cache stale (see the first test for the assertions on this).
        await tester.placeCaretInParagraph('1', 0);
        testClock.pauseAutomaticFramePumping();
        await tester.typeImeText(originalText);
        await tester.pump(const Duration(seconds: 10));
        await tester.pump();
        await tester.pump();
        editor.execute([const DeleteUpstreamCharacterRequest()]);
        await tester.pump();
        expect(_textLength(editor), 12);

        // The user taps the still-underlined misspelled word. Drive the real
        // Android spell-checker tap handler exactly as a tap would.
        final handler = plugin.contentTapHandlers.first as SuperEditorAndroidSpellCheckerTapHandler;
        final layout = SuperEditorInspector.findDocumentLayout();
        const tapPosition = DocumentPosition(
          nodeId: '1',
          nodePosition: TextNodePosition(offset: 9),
        );
        final layoutOffset = layout.getRectForPosition(tapPosition)!.center;
        handler.onTap(
          DocumentTapDetails(
            documentLayout: layout,
            layoutOffset: layoutOffset,
            globalOffset: layout.getAncestorOffsetFromDocumentOffset(layoutOffset),
          ),
        );

        // The handler places the caret immediately and expands to the whole word
        // after 300ms. Advance time to fire that real timer. In the buggy state,
        // laying out the popover around an out-of-range word can also throw; we
        // capture that and assert on it below rather than let it mask the primary
        // contract.
        await tester.pump(const Duration(milliseconds: 300));
        final popoverException = tester.takeException();

        // CONTRACT 1: the selection the spell-checker commits must stay within
        // the current text. Fails today: it commits extent offset 13 on 12-char
        // text.
        final committed = SuperEditorInspector.findDocumentSelection()!;
        final extentOffset = (committed.extent.nodePosition as TextNodePosition).offset;
        expect(
          extentOffset,
          lessThanOrEqualTo(_textLength(editor)),
          reason: 'spell-checker committed an out-of-range selection '
              '(extent $extentOffset > ${_textLength(editor)})',
        );

        // CONTRACT 2: the editor stays usable — collapsing the caret to that
        // position and pressing backspace deletes a character instead of dead-
        // ending in getCharacterStartBounds.
        editor.execute([
          ChangeSelectionRequest(
            DocumentSelection.collapsed(position: committed.extent),
            SelectionChangeType.placeCaret,
            SelectionReason.userInteraction,
          ),
        ]);
        final lengthBeforeBackspace = _textLength(editor);
        Object? backspaceError;
        try {
          editor.execute([const DeleteUpstreamCharacterRequest()]);
        } catch (error) {
          backspaceError = error;
        }
        expect(backspaceError, isNull, reason: 'backspace must not throw');
        expect(
          _textLength(editor),
          lengthBeforeBackspace - 1,
          reason: 'backspace must delete exactly one character',
        );

        // CONTRACT 3: showing the suggestions popover must not throw.
        expect(
          popoverException,
          isNull,
          reason: 'laying out the suggestions popover threw: $popoverException',
        );
      },
    );
  });
}

int _textLength(Editor editor) =>
    (editor.context.document.getNodeById('1')! as TextNode).text.length;

Future<(Editor, SpellingAndGrammarPlugin)> _pumpSpellingEditor(
  WidgetTester tester, {
  required SpellcheckClock clock,
  required SpellCheckService spellChecker,
  required Duration spellCheckDelay,
}) async {
  final editor = createDefaultDocumentEditor(
    document: MutableDocument(
      nodes: [
        ParagraphNode(id: '1', text: AttributedText('')),
      ],
    ),
    composer: MutableDocumentComposer(),
  );

  final plugin = SpellingAndGrammarPlugin(
    // Grammar has no service on Android and only adds noise here.
    isGrammarCheckEnabled: false,
    spellCheckService: spellChecker,
    spellCheckDelayAfterEdit: spellCheckDelay,
    androidControlsController: SuperEditorAndroidControlsController(),
    clock: clock,
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SuperEditor(
          editor: editor,
          plugins: {plugin},
        ),
      ),
    ),
  );

  return (editor, plugin);
}

/// A [SpellCheckService] that flags one word in one specific text, and returns
/// nothing for any other text — so a re-check after an edit would clear the
/// suggestion, which is exactly why these tests never let that re-check run.
class _StaleWordSpellChecker extends SpellCheckService {
  _StaleWordSpellChecker({
    required this.textToFlag,
    required this.flaggedRange,
    required this.suggestions,
  });

  final String textToFlag;
  final TextRange flaggedRange;
  final List<String> suggestions;

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(Locale locale, String text) async {
    if (text == textToFlag) {
      return [SuggestionSpan(flaggedRange, suggestions)];
    }
    return const [];
  }
}
