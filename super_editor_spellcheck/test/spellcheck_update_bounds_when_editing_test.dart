import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:super_editor_spellcheck/super_editor_spellcheck.dart';

void main() {
  group('SuperEditor spellcheck > error span bounds >', () {
    testWidgetsOnMobile(
      'shifts to stay aligned after an insertion upstream of the word',
      (tester) async {
        final testClock = SpellcheckClock.forTesting(tester);
        // "x hllo" -> "hllo" is misspelled at [2, 6).
        final (editor, plugin) = await _pumpSpellingEditor(
          tester,
          testClock,
          text: 'x hllo',
          flaggedRange: const TextRange(start: 2, end: 6),
        );
        expect(_errorRanges(plugin), {const TextRange(start: 2, end: 6)});

        // Insert "yy" at the start of the paragraph, upstream of the word.
        await tester.placeCaretInParagraph('1', 0);
        await tester.typeImeText('yy');
        await tester.pump();

        // The range follows the word, shifted right by the two inserted chars.
        expect(_errorRanges(plugin), {const TextRange(start: 4, end: 8)});
      },
    );

    testWidgetsOnMobile(
      'is dropped when its word is deleted',
      (tester) async {
        final testClock = SpellcheckClock.forTesting(tester);
        // "x hllo" -> "hllo" is misspelled at [2, 6) and touches the end.
        final (editor, plugin) = await _pumpSpellingEditor(
          tester,
          testClock,
          text: 'x hllo',
          flaggedRange: const TextRange(start: 2, end: 6),
        );
        expect(_errorRanges(plugin), {const TextRange(start: 2, end: 6)});

        // Delete the trailing character of the misspelled word (the caret is at
        // the end of the text after typing).
        editor.execute([const DeleteUpstreamCharacterRequest()]);
        await tester.pump();

        // The word changed, so the stale range is dropped rather than left
        // pointing past the end of the text.
        expect(_errorRanges(plugin), isEmpty);
      },
    );

    testWidgetsOnMobile(
      'shifts up after a deletion upstream of the word',
      (tester) async {
        final testClock = SpellcheckClock.forTesting(tester);
        // "yx hllo" -> "hllo" is misspelled at [3, 7).
        final (editor, plugin) = await _pumpSpellingEditor(
          tester,
          testClock,
          text: 'yx hllo',
          flaggedRange: const TextRange(start: 3, end: 7),
        );
        expect(_errorRanges(plugin), {const TextRange(start: 3, end: 7)});

        // Delete the leading "y", upstream of the word. Place the caret with a
        // request rather than a tap, which on iOS is subject to selection
        // heuristics that would snap it to the word boundary.
        editor.execute([
          const ChangeSelectionRequest(
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: '1',
                nodePosition: TextNodePosition(offset: 1),
              ),
            ),
            SelectionChangeType.placeCaret,
            SelectionReason.userInteraction,
          ),
          const DeleteUpstreamCharacterRequest(),
        ]);
        await tester.pump();

        // The range follows the word, shifted left by the one deleted char.
        expect(_errorRanges(plugin), {const TextRange(start: 2, end: 6)});
      },
    );
  });

  group('SuperEditor spellcheck > suggestion bounds >', () {
    testWidgetsOnMobile(
      'shifts to stay aligned after an insertion upstream of the word',
      (tester) async {
        final testClock = SpellcheckClock.forTesting(tester);
        // "x hllo" -> "hllo" is misspelled at [2, 6).
        final (editor, _) = await _pumpSpellingEditor(
          tester,
          testClock,
          text: 'x hllo',
          flaggedRange: const TextRange(start: 2, end: 6),
        );
        expect(_suggestionRanges(editor), {const TextRange(start: 2, end: 6)});

        // Insert "yy" at the start of the paragraph, upstream of the word.
        await tester.placeCaretInParagraph('1', 0);
        await tester.typeImeText('yy');
        await tester.pump();

        // The range follows the word, shifted right by the two inserted chars.
        expect(_suggestionRanges(editor), {const TextRange(start: 4, end: 8)});
      },
    );

    testWidgetsOnMobile(
      'is dropped when its word is deleted',
      (tester) async {
        final testClock = SpellcheckClock.forTesting(tester);
        // "x hllo" -> "hllo" is misspelled at [2, 6) and touches the end.
        final (editor, _) = await _pumpSpellingEditor(
          tester,
          testClock,
          text: 'x hllo',
          flaggedRange: const TextRange(start: 2, end: 6),
        );
        expect(_suggestionRanges(editor), {const TextRange(start: 2, end: 6)});

        // Delete the trailing character of the misspelled word (the caret is at
        // the end of the text after typing).
        editor.execute([const DeleteUpstreamCharacterRequest()]);
        await tester.pump();

        // The word changed, so the stale range is dropped rather than left
        // pointing past the end of the text — which is what previously produced
        // an out-of-range selection and the "stuck editor".
        expect(_suggestionRanges(editor), isEmpty);
      },
    );

    testWidgetsOnMobile(
      'shifts up after a deletion upstream of the word',
      (tester) async {
        final testClock = SpellcheckClock.forTesting(tester);
        // "yx hllo" -> "hllo" is misspelled at [3, 7).
        final (editor, _) = await _pumpSpellingEditor(
          tester,
          testClock,
          text: 'yx hllo',
          flaggedRange: const TextRange(start: 3, end: 7),
        );
        expect(_suggestionRanges(editor), {const TextRange(start: 3, end: 7)});

        // Delete the leading "y", upstream of the word. Place the caret with a
        // request rather than a tap, which on iOS is subject to selection
        // heuristics that would snap it to the word boundary.
        editor.execute([
          const ChangeSelectionRequest(
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: '1',
                nodePosition: TextNodePosition(offset: 1),
              ),
            ),
            SelectionChangeType.placeCaret,
            SelectionReason.userInteraction,
          ),
          const DeleteUpstreamCharacterRequest(),
        ]);
        await tester.pump();

        // The range follows the word, shifted left by the one deleted char.
        expect(_suggestionRanges(editor), {const TextRange(start: 2, end: 6)});
      },
    );
  });

  group('SuperEditor spellcheck > stale suggestion selection >', () {
    testWidgetsOnMobile(
      'tapping a suggestion after an edit keeps the selection in range and leaves backspace working',
      (tester) async {
        final testClock = SpellcheckClock.forTesting(tester);
        // "I love pizzza" -> the misspelled word [7, 13) touches the end of the
        // text, as in the field report.
        final (editor, plugin) = await _pumpSpellingEditor(
          tester,
          testClock,
          text: 'I love pizzza',
          flaggedRange: const TextRange(start: 7, end: 13),
        );

        // Delete the trailing character. The word changes underneath the cached
        // suggestion; before the fix its range was left pointing at offset 13.
        editor.execute([const DeleteUpstreamCharacterRequest()]);
        await tester.pump();
        expect(_textLength(editor), 12);

        // Tap the word via the real spell-checker tap handler for this platform.
        final handler = plugin.contentTapHandlers.first;
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

        // Android expands the selection to the whole word after a 300ms delay;
        // iOS does it synchronously. Pump past the Android delay so either path
        // has committed by the time we assert.
        await tester.pump(const Duration(milliseconds: 300));
        final popoverException = tester.takeException();

        // CONTRACT 1: the selection the spell-checker commits stays within the
        // current text. Before the fix it committed extent offset 13 on 12-char
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

/// The current set of underline error ranges stored for node `'1'`.
Set<TextRange> _errorRanges(SpellingAndGrammarPlugin plugin) =>
    plugin.styler.getErrorsForNode('1').map((error) => error.range).toSet();

/// The current set of correction-suggestion ranges stored for node `'1'`.
Set<TextRange> _suggestionRanges(Editor editor) => editor.context
    .find<SpellingErrorSuggestions>(SpellingAndGrammarPlugin.spellingErrorSuggestionsKey)
    .getSuggestionsForNode('1')
    .keys
    .toSet();

int _textLength(Editor editor) => (editor.context.document.getNodeById('1')! as TextNode).text.length;

/// Pumps an editor with the spell-check plugin, types [text], and runs a single
/// spell check that flags [flaggedRange] — populating both the underline styler
/// and the suggestion cache with that range.
///
/// Uses a long debounce and never advances the clock past it again, so a later
/// edit reconciles the existing bounds without a fresh check overwriting them.
Future<(Editor, SpellingAndGrammarPlugin)> _pumpSpellingEditor(
  WidgetTester tester,
  WidgetTestSpellcheckClock testClock, {
  required String text,
  required TextRange flaggedRange,
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
    spellCheckService: _StaleWordSpellChecker(
      textToFlag: text,
      flaggedRange: flaggedRange,
      suggestions: const ['correction'],
    ),
    spellCheckDelayAfterEdit: const Duration(seconds: 10),
    // The plugin requires the controls controller for whichever mobile platform
    // the test runs on; provide both so the setup works on Android and iOS.
    androidControlsController: SuperEditorAndroidControlsController(),
    iosControlsController: SuperEditorIosControlsController(),
    clock: testClock,
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

  await tester.placeCaretInParagraph('1', 0);
  testClock.pauseAutomaticFramePumping();
  await tester.typeImeText(text);

  await tester.pump(const Duration(seconds: 10));
  await tester.pump();
  await tester.pump();

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
