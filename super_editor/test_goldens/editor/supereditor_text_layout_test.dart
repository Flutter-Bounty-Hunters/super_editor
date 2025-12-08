import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:super_editor/super_test.dart';

void main() {
  group('SuperEditor', () {
    group('applies textScaleFactor', () {
      testGoldensOnAndroid('for paragraph', (tester) async {
        await _buildTextScaleScaffold(
          tester,
          regularEditor: _buildSuperEditorFromMarkdown(
            tester,
            inputRole: 'regular-editor',
            markdown: 'This is a paragraph',
          ),
          scaledEditor: _buildSuperEditorFromMarkdown(
            tester,
            inputRole: 'scaled-editor',
            markdown: 'This is a paragraph',
          ),
        );

        await screenMatchesGolden(tester, 'text-scaling-paragraph');
      });

      testGoldensOnLinux('for paragraph with collapsed selection', (tester) async {
        final regularEditorKey = GlobalKey();
        final scaledEditorKey = GlobalKey();

        await _buildTextScaleScaffold(
          tester,
          regularEditor: _buildSuperEditorFromMarkdown(
            tester,
            inputRole: 'regular-editor',
            markdown: 'This is a paragraph',
            key: regularEditorKey,
          ),
          scaledEditor: _buildSuperEditorFromMarkdown(
            tester,
            inputRole: 'scaled-editor',
            markdown: 'This is a paragraph',
            key: scaledEditorKey,
          ),
        );

        // Place caret at "This is| a paragraph" in the regular edditor.
        await _placeCaretAtFirstNode(
          tester,
          offset: 7,
          editorKey: regularEditorKey,
        );

        // Place caret at "This is| a paragraph" in the regular edditor.
        await _placeCaretAtFirstNode(
          tester,
          offset: 7,
          editorKey: scaledEditorKey,
        );

        await screenMatchesGolden(tester, 'text-scaling-paragraph-collapsed-selection');
      });

      testGoldensOnLinux('for paragraph with expanded selection', (tester) async {
        final regularEditorKey = GlobalKey();
        final scaledEditorKey = GlobalKey();

        await _buildTextScaleScaffold(
          tester,
          regularEditor: _buildSuperEditorFromMarkdown(
            tester,
            inputRole: 'regular-editor',
            markdown: 'This is a paragraph',
            key: regularEditorKey,
          ),
          scaledEditor: _buildSuperEditorFromMarkdown(
            tester,
            inputRole: 'scaled-editor',
            markdown: 'This is a paragraph',
            key: scaledEditorKey,
          ),
        );

        // Double tap at "This is a p|aragraph" to select the word "paragraph" in the regular editor.
        await _doubleTapAtFirstNode(
          tester,
          offset: 11,
          editorKey: regularEditorKey,
        );

        // Double tap at "This is a p|aragraph" to select the word "paragraph" in the scaled editor.
        await _doubleTapAtFirstNode(
          tester,
          offset: 11,
          editorKey: scaledEditorKey,
        );

        await expectLater(
          find.byType(MaterialApp).first,
          matchesGoldenFileWithPixelAllowance(
            'goldens/text-scaling-paragraph-expanded-selection.png',
            21,
          ),
        );
      });

      testGoldensOnAndroid('for unordered list item', (tester) async {
        await _buildTextScaleScaffold(
          tester,
          regularEditor: _buildSuperEditorFromMarkdown(
            tester,
            inputRole: 'regular-editor',
            markdown: '- List item 1\n- List item 2',
          ),
          scaledEditor: _buildSuperEditorFromMarkdown(
            tester,
            inputRole: 'scaled-editor',
            markdown: '- List item 1\n- List item 2',
          ),
        );

        await screenMatchesGolden(tester, 'text-scaling-unordered-list');
      });

      testGoldensOnAndroid('for ordered list item', (tester) async {
        await _buildTextScaleScaffold(
          tester,
          regularEditor: _buildSuperEditorFromMarkdown(
            tester,
            inputRole: 'regular-editor',
            markdown: '1. List item 1\n2. List item 2',
          ),
          scaledEditor: _buildSuperEditorFromMarkdown(
            tester,
            inputRole: 'scaled-editor',
            markdown: '1. List item 1\n2. List item 2',
          ),
        );

        await screenMatchesGolden(tester, 'text-scaling-ordered-list');
      });

      testGoldensOnAndroid('for header', (tester) async {
        await _buildTextScaleScaffold(
          tester,
          regularEditor: _buildSuperEditorFromMarkdown(
            tester,
            inputRole: 'regular-editor',
            markdown: '# This is a header',
          ),
          scaledEditor: _buildSuperEditorFromMarkdown(
            tester,
            inputRole: 'scaled-editor',
            markdown: '# This is a header',
          ),
        );

        await expectLater(
          find.byType(MaterialApp).first,
          matchesGoldenFileWithPixelAllowance("goldens/text-scaling-header.png", 125),
        );
      });

      testGoldensOnAndroid('for blockquote', (tester) async {
        await _buildTextScaleScaffold(
          tester,
          regularEditor: _buildSuperEditorFromMarkdown(
            tester,
            inputRole: 'regular-editor',
            markdown: '> This is a blockquote',
          ),
          scaledEditor: _buildSuperEditorFromMarkdown(
            tester,
            inputRole: 'scaled-editor',
            markdown: '> This is a blockquote',
          ),
        );

        await expectLater(
          find.byType(MaterialApp).first,
          matchesGoldenFileWithPixelAllowance("goldens/text-scaling-blockquote.png", 40),
        );
      });
    });
  });
}

/// Places the caret at [offset] in the editor with the given [editorKey].
Future<void> _placeCaretAtFirstNode(
  WidgetTester tester, {
  required int offset,
  required Key editorKey,
}) async {
  final regularEditorFinder = find.byKey(editorKey);
  final regularDoc = SuperEditorInspector.findDocument(regularEditorFinder)!;
  await tester.placeCaretInParagraph(
    regularDoc.first.id,
    offset,
    superEditorFinder: regularEditorFinder,
  );
}

/// Double taps at [offset] in the editor with the given [editorKey].
Future<void> _doubleTapAtFirstNode(
  WidgetTester tester, {
  required int offset,
  required Key editorKey,
}) async {
  final regularEditorFinder = find.byKey(editorKey);
  final regularDoc = SuperEditorInspector.findDocument(regularEditorFinder)!;
  await tester.doubleTapInParagraph(
    regularDoc.first.id,
    offset,
    superEditorFinder: regularEditorFinder,
  );
}

/// Builds a [SuperEditor] for desktop from the given [markdown].
///
/// This editor uses [_stylesheet] and doesn't clear selection when loses focus.
Widget _buildSuperEditorFromMarkdown(
  WidgetTester tester, {
  required String inputRole,
  required String markdown,
  Key? key,
}) {
  return tester //
      .createDocument()
      .fromMarkdown(markdown)
      .forDesktop()
      .withKey(key)
      .withInputRole(inputRole)
      .withSelectionPolicies(
        const SuperEditorSelectionPolicies(
          clearSelectionWhenEditorLosesFocus: false,
          clearSelectionWhenImeConnectionCloses: false,
        ),
      )
      .useStylesheet(_stylesheet)
      .build()
      .widget;
}

/// A [StyleSheet] which applies the Roboto font for all nodes.
///
/// This is needed to use real font glyphs in the golden tests.
final _stylesheet = defaultStylesheet.copyWith(
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

TextStyle inlineTextStyler(Set<Attribution> attributions, TextStyle base) {
  return base;
}

/// Pumps a widget tree containing two editors side by side.
///
/// The left editor has the default `textScaleFactor`.
///
/// The right editor has `textScaleFactor` set to `2.0`.
Future<void> _buildTextScaleScaffold(
  WidgetTester tester, {
  required Widget regularEditor,
  required Widget scaledEditor,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            Expanded(
              child: regularEditor,
            ),
            Expanded(
              child: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
                child: scaledEditor,
              ),
            ),
          ],
        ),
      ),
      debugShowCheckedModeBanner: false,
    ),
  );
}
