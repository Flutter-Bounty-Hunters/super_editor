import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_editor/super_editor.dart';

import '../../test_tools_goldens.dart';

void main() {
  group("SuperEditor > text entry > text errors >", () {
    group("direct styling >", () {
      group("spelling >", () {
        _createDirectStylingTests(_ErrorType.spelling);
      });

      group("grammar >", () {
        _createDirectStylingTests(_ErrorType.grammar);
      });
    });

    group("stylesheet styling >", () {
      group("spelling >", () {
        _createStylesheetStylingTests(_ErrorType.spelling);
      });

      group("grammar >", () {
        _createStylesheetStylingTests(_ErrorType.grammar);
      });
    });
  });
}

void _createDirectStylingTests(_ErrorType type) {
  testGoldensOnMobile(
    "is underlined in paragraph",
    _createWidgetTest(
      contentTypeName: "paragraph",
      testNameQualifier: "no-stylesheet",
      stylesheet: _stylesheetWithNoSpellingErrorStyles,
      content: _paragraphMarkdown,
      errorType: type,
    ),
    windowSize: goldenSizeLongStrip,
  );
  testGoldensOnMobile(
    "is underlined in blockquote",
    _createWidgetTest(
      contentTypeName: "blockquote",
      testNameQualifier: "no-stylesheet",
      stylesheet: _stylesheetWithNoSpellingErrorStyles,
      content: _blockquoteMarkdown,
      errorType: type,
    ),
    windowSize: goldenSizeLongStrip,
  );
  testGoldensOnMobile(
    "is underlined in list item",
    _createWidgetTest(
      contentTypeName: "list-item",
      testNameQualifier: "no-stylesheet",
      stylesheet: _stylesheetWithNoSpellingErrorStyles,
      content: _listItemMarkdown,
      errorType: type,
    ),
    windowSize: goldenSizeLongStrip,
  );
  testGoldensOnMobile(
    "is underlined in task",
    _createWidgetTest(
      contentTypeName: "task",
      testNameQualifier: "no-stylesheet",
      stylesheet: _stylesheetWithNoSpellingErrorStyles,
      content: _taskMarkdown,
      errorType: type,
    ),
    windowSize: goldenSizeLongStrip,
  );

  testGoldensOnMac(
    "is underlined in paragraph",
    _createWidgetTest(
      contentTypeName: "paragraph",
      testNameQualifier: "no-stylesheet",
      stylesheet: _stylesheetWithNoSpellingErrorStyles,
      content: _paragraphMarkdown,
      errorType: type,
    ),
    windowSize: goldenSizeLongStrip,
  );
  testGoldensOnMac(
    "is underlined in blockquote",
    _createWidgetTest(
      contentTypeName: "blockquote",
      testNameQualifier: "no-stylesheet",
      stylesheet: _stylesheetWithNoSpellingErrorStyles,
      content: _blockquoteMarkdown,
      errorType: type,
    ),
    windowSize: goldenSizeLongStrip,
  );
  testGoldensOnMac(
    "is underlined in list item",
    _createWidgetTest(
      contentTypeName: "list-item",
      testNameQualifier: "no-stylesheet",
      stylesheet: _stylesheetWithNoSpellingErrorStyles,
      content: _listItemMarkdown,
      errorType: type,
    ),
    windowSize: goldenSizeLongStrip,
  );
  testGoldensOnMac(
    "is underlined in task",
    _createWidgetTest(
      contentTypeName: "task",
      testNameQualifier: "no-stylesheet",
      stylesheet: _stylesheetWithNoSpellingErrorStyles,
      content: _taskMarkdown,
      errorType: type,
    ),
    windowSize: goldenSizeLongStrip,
  );
}

void _createStylesheetStylingTests(_ErrorType type) {
  testGoldensOnMobile(
    "is underlined in paragraph",
    _createWidgetTest(
      contentTypeName: "paragraph",
      testNameQualifier: "with-stylesheet",
      stylesheet: _stylesheetWithSpellingErrorStyles,
      content: _paragraphMarkdown,
      errorType: type,
    ),
    windowSize: goldenSizeLongStrip,
  );
  testGoldensOnMobile(
    "is underlined in blockquote",
    _createWidgetTest(
      contentTypeName: "blockquote",
      testNameQualifier: "with-stylesheet",
      stylesheet: _stylesheetWithSpellingErrorStyles,
      content: _blockquoteMarkdown,
      errorType: type,
    ),
    windowSize: goldenSizeLongStrip,
  );
  testGoldensOnMobile(
    "is underlined in list item",
    _createWidgetTest(
      contentTypeName: "list-item",
      testNameQualifier: "with-stylesheet",
      stylesheet: _stylesheetWithSpellingErrorStyles,
      content: _listItemMarkdown,
      errorType: type,
    ),
    windowSize: goldenSizeLongStrip,
  );
  testGoldensOnMobile(
    "is underlined in task",
    _createWidgetTest(
      contentTypeName: "task",
      testNameQualifier: "with-stylesheet",
      stylesheet: _stylesheetWithSpellingErrorStyles,
      content: _taskMarkdown,
      errorType: type,
    ),
    windowSize: goldenSizeLongStrip,
  );

  testGoldensOnMac(
    "is underlined in paragraph",
    _createWidgetTest(
      contentTypeName: "paragraph",
      testNameQualifier: "with-stylesheet",
      stylesheet: _stylesheetWithSpellingErrorStyles,
      content: _paragraphMarkdown,
      errorType: type,
    ),
    windowSize: goldenSizeLongStrip,
  );
  testGoldensOnMac(
    "is underlined in blockquote",
    _createWidgetTest(
      contentTypeName: "blockquote",
      testNameQualifier: "with-stylesheet",
      stylesheet: _stylesheetWithSpellingErrorStyles,
      content: _blockquoteMarkdown,
      errorType: type,
    ),
    windowSize: goldenSizeLongStrip,
  );
  testGoldensOnMac(
    "is underlined in list item",
    _createWidgetTest(
      contentTypeName: "list-item",
      testNameQualifier: "with-stylesheet",
      stylesheet: _stylesheetWithSpellingErrorStyles,
      content: _listItemMarkdown,
      errorType: type,
    ),
    windowSize: goldenSizeLongStrip,
  );
  testGoldensOnMac(
    "is underlined in task",
    _createWidgetTest(
      contentTypeName: "task",
      testNameQualifier: "with-stylesheet",
      stylesheet: _stylesheetWithSpellingErrorStyles,
      content: _taskMarkdown,
      errorType: type,
    ),
    windowSize: goldenSizeLongStrip,
  );
}

Future<void> Function(WidgetTester) _createWidgetTest({
  required String contentTypeName,
  required String testNameQualifier,
  required Stylesheet stylesheet,
  required String content,
  required _ErrorType errorType,
}) {
  return (WidgetTester tester) async {
    final document = deserializeMarkdownToDocument(content);

    final (_, _) = await _pumpScaffold(
      tester,
      stylesheet,
      document,
      spellingError: errorType == _ErrorType.spelling
          ? TextError(
              nodeId: document.first.id,
              range: const TextRange(start: 22, end: 23),
              type: TextErrorType.spelling,
              value: "a",
            )
          : null,
      grammarError: errorType == _ErrorType.grammar
          ? TextError(
              nodeId: document.first.id,
              range: const TextRange(start: 7, end: 11),
              type: TextErrorType.grammar,
              value: "with",
            )
          : null,
    );

    late final String goldenName;
    switch (errorType) {
      case _ErrorType.spelling:
        goldenName =
            "super-editor_text-entry_spelling-error-shows-underline_${contentTypeName}_${defaultTargetPlatform.name}_$testNameQualifier";
      case _ErrorType.grammar:
        goldenName =
            "super-editor_text-entry_grammar-error-shows-underline_${contentTypeName}_${defaultTargetPlatform.name}_$testNameQualifier";
    }

    await screenMatchesGolden(tester, goldenName);
  };
}

enum _ErrorType {
  spelling,
  grammar;
}

Future<(Editor, Document)> _pumpScaffold(
  WidgetTester tester,
  Stylesheet stylesheet,
  MutableDocument document, {
  TextError? spellingError,
  TextError? grammarError,
}) async {
  // TODO: Whenever we're able to create a TaskComponentBuilder without passing the Editor, refactor
  //       this setup to look like a normal SuperEditor test.
  final composer = MutableDocumentComposer();
  final editor = createDefaultDocumentEditor(document: document, composer: composer);

  final spellingAndGrammarStyler = SpellingAndGrammarStyler()
    ..addErrors(document.first.id, {
      if (spellingError != null) spellingError,
      if (grammarError != null) grammarError,
    });

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: SuperEditor(
          editor: editor,
          componentBuilders: [
            TaskComponentBuilder(editor),
            ...defaultComponentBuilders,
          ],
          stylesheet: stylesheet,
          customStylePhases: [
            spellingAndGrammarStyler,
          ],
        ),
      ),
    ),
    debugShowCheckedModeBanner: false,
  ));

  return (editor, document);
}

const _paragraphMarkdown = "Typing with composing a";
const _blockquoteMarkdown = "> Typing with composing a";
const _listItemMarkdown = " * Typing with composing a";
const _taskMarkdown = "- [ ] Typing with composing a";

/// A [StyleSheet] which applies the Roboto font for all nodes.
///
/// This is needed to use real font glyphs in the golden tests.
final _stylesheetWithNoSpellingErrorStyles = defaultStylesheet.copyWith(
  addRulesAfter: [
    StyleRule(BlockSelector.all, (doc, node) {
      return {
        Styles.textStyle: const TextStyle(
          fontFamily: 'Roboto',
        ),
      };
    })
  ],
);

/// The same as [_stylesheetWithNoSpellingErrorStyles] but with an explicit style
/// for spelling errors.
final _stylesheetWithSpellingErrorStyles = defaultStylesheet.copyWith(
  addRulesAfter: [
    StyleRule(BlockSelector.all, (doc, node) {
      return {
        Styles.textStyle: const TextStyle(
          fontFamily: 'Roboto',
        ),
        Styles.spellingErrorUnderlineStyle: const SquiggleUnderlineStyle(
          color: Colors.orange,
        ),
        Styles.grammarErrorUnderlineStyle: const SquiggleUnderlineStyle(
          color: Colors.green,
        ),
      };
    })
  ],
);
