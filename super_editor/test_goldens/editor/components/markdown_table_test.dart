import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_editor/super_editor.dart';

import '../../../test/super_editor/supereditor_test_tools.dart';
import '../../test_tools_goldens.dart';

void main() {
  group('SuperEditor > Markdown Table >', () {
    group('layout >', () {
      testGoldensOnMac('expands to fill width', (tester) async {
        await tester //
            .createDocument()
            .fromMarkdown('''
| Header 1 |
|---|
| Cell 1 |
| Cell 2 |
| Cell 3 |''')
            .withAddedComponents([const MarkdownTableComponentBuilder()])
            .useStylesheet(markdownTableStylesheet)
            .pump();

        await screenMatchesGolden(tester, 'super_editor_markdown_table_fills_width');
      }, windowSize: goldenSizeMedium);

      testGoldensOnMac('shrinks to fit width', (tester) async {
        await tester //
            .createDocument()
            .fromMarkdown('''
| Header 1 | Header 2 | Header 3 | Header 4 | Header 5 | 
|---|---|---|---|---|
| Cell 1 | Cell 2 | Cell 3 | Cell 4 | Cell 5 |
| Cell 1 | Cell 2 | Cell 3 | Cell 4 | Cell 5 |''')
            .withAddedComponents([const MarkdownTableComponentBuilder()])
            .useStylesheet(markdownTableStylesheet)
            .pump();

        await screenMatchesGolden(tester, 'super_editor_markdown_table_shrinks_to_fit_width');
      }, windowSize: goldenSizeMedium);

      testGoldensOnMac('without data rows', (tester) async {
        await tester //
            .createDocument()
            .fromMarkdown('''
| Header 1 | Header 2 |
|---|---|''')
            .withAddedComponents([const MarkdownTableComponentBuilder()])
            .useStylesheet(markdownTableStylesheet)
            .pump();

        await screenMatchesGolden(tester, 'super_editor_markdown_table_without_data_rows');
      }, windowSize: goldenSizeMedium);

      testGoldensOnMac('missing columns', (tester) async {
        await tester //
            .createDocument()
            .fromMarkdown('''
| Header 1 | Header 2 | Header 3 |
|---|---|---|
| Cell 1 | Cell 2 |
| Cell 3 |
''')
            .withAddedComponents([const MarkdownTableComponentBuilder()])
            .useStylesheet(markdownTableStylesheet)
            .pump();

        await screenMatchesGolden(tester, 'super_editor_markdown_table_missing_columns');
      }, windowSize: goldenSizeMedium);

      testGoldensOnMac('single header cell', (tester) async {
        await tester //
            .createDocument()
            .fromMarkdown('''
| Header 1 |
|---|''')
            .withAddedComponents([const MarkdownTableComponentBuilder()])
            .useStylesheet(markdownTableStylesheet)
            .pump();

        await screenMatchesGolden(tester, 'super_editor_markdown_table_single_header_cell');
      }, windowSize: goldenSizeMedium);

      testGoldensOnMac('different alignments', (tester) async {
        await tester //
            .createDocument()
            .fromMarkdown('''
| Column 1 | Column 2 | Column 3 |
|---|:---:|---:|
| Cell 1 | Cell 2 | Cell 3 |
| Cell 1 | Cell 2 | Cell 3 |
| Cell 1 | Cell 2 | Cell 3 |
| Cell 1 | Cell 2 | Cell 3 |
''')
            .withAddedComponents([const MarkdownTableComponentBuilder()])
            .useStylesheet(markdownTableStylesheet)
            .pump();

        await screenMatchesGolden(tester, 'super_editor_markdown_table_different_alignments');
      }, windowSize: goldenSizeMedium);

      testGoldensOnMac('different alignments', (tester) async {
        await tester //
            .createDocument()
            .fromMarkdown('''
| Column 1 | Column 2 | Column 3 |
|---|:---:|---:|
| Cell 1 | Cell 2 | Cell 3 |
| Cell 1 | Cell 2 | Cell 3 |
| Cell 1 | Cell 2 | Cell 3 |
| Cell 1 | Cell 2 | Cell 3 |
''')
            .withAddedComponents([const MarkdownTableComponentBuilder()])
            .useStylesheet(markdownTableStylesheet)
            .pump();

        await screenMatchesGolden(tester, 'super_editor_markdown_table_different_alignments');
      }, windowSize: goldenSizeMedium);

      testGoldensOnMac('inline styles', (tester) async {
        await tester //
            .createDocument()
            .fromMarkdown('''
| Column 1 | ~Column 2~ | ¬Column 3¬ |
|---|---|---|
| **Cell 1** | Cell 2 | Cell 3 |
| Cell 1 | *Cell 2* | Cell 3 |
| Cell 1 | Cell 2 | *Cell 3* |
''')
            .withAddedComponents([const MarkdownTableComponentBuilder()])
            .useStylesheet(markdownTableStylesheet.copyWith(
              addRulesAfter: [
                StyleRule(
                  BlockSelector.all,
                  (document, node) {
                    return {
                      Styles.textStyle: const TextStyle(
                        fontFamily: 'Roboto',
                      ),
                    };
                  },
                ),
              ],
            ))
            .pump();

        await screenMatchesGolden(tester, 'super_editor_markdown_table_inline_styles');
      }, windowSize: goldenSizeMedium);
    });

    group('customization >', () {
      testGoldensOnMac('text style', (tester) async {
        await _pumpCustomizationTestApp(
          tester,
          stylesheet: markdownTableStylesheet.copyWith(
            addRulesAfter: [
              StyleRule(
                BlockSelector(tableBlockAttribution.name),
                (document, node) {
                  return {
                    Styles.textStyle: const TextStyle(
                      color: Colors.red,
                    ),
                  };
                },
              ),
            ],
          ),
        );

        await screenMatchesGolden(tester, 'super_editor_markdown_table_customization_text_style');
      }, windowSize: goldenSizeMedium);

      testGoldensOnMac('header text style', (tester) async {
        await _pumpCustomizationTestApp(
          tester,
          stylesheet: markdownTableStylesheet.copyWith(
            addRulesAfter: [
              StyleRule(
                BlockSelector(tableBlockAttribution.name),
                (document, node) {
                  return {
                    TableStyles.headerTextStyle: const TextStyle(
                      color: Colors.red,
                    ),
                  };
                },
              ),
            ],
          ),
        );

        await screenMatchesGolden(tester, 'super_editor_markdown_table_customization_header_text_style');
      }, windowSize: goldenSizeMedium);

      testGoldensOnMac('border', (tester) async {
        await _pumpCustomizationTestApp(
          tester,
          stylesheet: markdownTableStylesheet.copyWith(
            addRulesAfter: [
              StyleRule(
                BlockSelector(tableBlockAttribution.name),
                (document, node) {
                  return {
                    TableStyles.border: const TableBorder(),
                  };
                },
              ),
            ],
          ),
        );

        await screenMatchesGolden(tester, 'super_editor_markdown_table_customization_border');
      }, windowSize: goldenSizeMedium);

      testGoldensOnMac('cell padding', (tester) async {
        await _pumpCustomizationTestApp(
          tester,
          stylesheet: markdownTableStylesheet.copyWith(
            addRulesAfter: [
              StyleRule(
                BlockSelector(tableBlockAttribution.name),
                (document, node) {
                  return {
                    TableStyles.cellPadding: const CascadingPadding.all(20.0),
                  };
                },
              ),
            ],
          ),
        );

        await screenMatchesGolden(tester, 'super_editor_markdown_table_customization_cell_padding');
      }, windowSize: goldenSizeMedium);

      testGoldensOnMac('header row decoration', (tester) async {
        await _pumpCustomizationTestApp(
          tester,
          stylesheet: markdownTableStylesheet.copyWith(
            addRulesAfter: [
              StyleRule(
                BlockSelector(tableBlockAttribution.name),
                (document, node) {
                  return {
                    TableStyles.cellDecorator: ({
                      required int rowIndex,
                      required int columnIndex,
                      required AttributedText cellText,
                      required Map<String, dynamic> cellMetadata,
                    }) {
                      if (rowIndex == 0) {
                        // Header row.
                        return const BoxDecoration(color: Colors.blue);
                      }

                      return null;
                    },
                  };
                },
              ),
            ],
          ),
        );

        await screenMatchesGolden(tester, 'super_editor_markdown_table_customization_header_decoration');
      }, windowSize: goldenSizeMedium);

      testGoldensOnMac('data row decoration', (tester) async {
        await _pumpCustomizationTestApp(
          tester,
          stylesheet: markdownTableStylesheet.copyWith(
            addRulesAfter: [
              StyleRule(
                BlockSelector(tableBlockAttribution.name),
                (document, node) {
                  return {
                    TableStyles.cellDecorator: ({
                      required int rowIndex,
                      required int columnIndex,
                      required AttributedText cellText,
                      required Map<String, dynamic> cellMetadata,
                    }) {
                      if (rowIndex > 0 && rowIndex % 2 == 0) {
                        // Even data row.
                        return const BoxDecoration(
                          color: Colors.green,
                        );
                      }

                      return null;
                    },
                  };
                },
              ),
            ],
          ),
        );

        await screenMatchesGolden(tester, 'super_editor_markdown_table_customization_row_decoration');
      }, windowSize: goldenSizeMedium);

      testGoldensOnMac('cell decoration', (tester) async {
        await _pumpCustomizationTestApp(
          tester,
          stylesheet: markdownTableStylesheet.copyWith(
            addRulesAfter: [
              StyleRule(
                BlockSelector(tableBlockAttribution.name),
                (document, node) {
                  return {
                    TableStyles.cellDecorator: ({
                      required int rowIndex,
                      required int columnIndex,
                      required AttributedText cellText,
                      required Map<String, dynamic> cellMetadata,
                    }) {
                      if (columnIndex == 1) {
                        return const BoxDecoration(color: Colors.red);
                      }

                      return null;
                    },
                  };
                },
              ),
            ],
          ),
        );

        await screenMatchesGolden(tester, 'super_editor_markdown_table_customization_cell_decoration');
      }, windowSize: goldenSizeMedium);
    });
  });
}

Future<void> _pumpCustomizationTestApp(
  WidgetTester tester, {
  required Stylesheet stylesheet,
}) async {
  await tester //
      .createDocument()
      .fromMarkdown('''
| Header 1 | Header 2 | Header 3 |
|---|---|---|
| Cell 1 | Cell 2 | Cell 3 |
| Cell 1 | Cell 2 |
| Cell 1 | Cell 2 |
| Cell 1 | Cell 2 |
| Cell 1 | Cell 2 |
''')
      .withAddedComponents([const MarkdownTableComponentBuilder()])
      .useStylesheet(stylesheet)
      .pump();
}

/// Applies the markdown table styles to the default stylesheet.
final markdownTableStylesheet = defaultStylesheet.copyWith(
  addRulesAfter: [
    markdownTableStyles,
  ],
);
