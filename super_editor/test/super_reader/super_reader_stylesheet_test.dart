import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:golden_bricks/golden_bricks.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart';

import 'reader_test_tools.dart';
import 'test_documents.dart';

void main() {
  group("SuperReader stylesheets", () {
    group("style text", () {
      testWidgetsOnArbitraryDesktop("with left alignment", (tester) async {
        await _pumpReader(tester, stylesheet: _stylesheetWithTextAlignment(TextAlign.left));

        expect(_findTextWithAlignment(TextAlign.left), findsOneWidget);
      });

      testWidgetsOnArbitraryDesktop("with center alignment", (tester) async {
        await _pumpReader(tester, stylesheet: _stylesheetWithTextAlignment(TextAlign.center));

        expect(_findTextWithAlignment(TextAlign.center), findsOneWidget);
      });

      testWidgetsOnArbitraryDesktop("with right alignment", (tester) async {
        await _pumpReader(tester, stylesheet: _stylesheetWithTextAlignment(TextAlign.right));

        expect(_findTextWithAlignment(TextAlign.right), findsOneWidget);
      });

      testWidgetsOnArbitraryDesktop("with justify alignment", (tester) async {
        await _pumpReader(tester, stylesheet: _stylesheetWithTextAlignment(TextAlign.justify));

        expect(_findTextWithAlignment(TextAlign.justify), findsOneWidget);
      });
    });

    testWidgetsOnArbitraryDesktop('does not inherit the enclosing default text style by default', (tester) async {
      await tester
          .createDocument() //
          .withSingleParagraph()
          .withCustomWidgetTreeBuilder(
            (superReader) => MaterialApp(
              home: Scaffold(
                body: DefaultTextStyle(
                  style: const TextStyle(fontFamily: goldenBricks),
                  child: superReader,
                ),
              ),
            ),
          )
          .pump();

      // Ensure we didn't inherit the font family from the enclosing text style.
      expect(
        _findSpanAtOffset(tester, offset: 0).style!.fontFamily,
        isNull,
      );
    });

    testWidgetsOnArbitraryDesktop('inherits the enclosing default text style if requested', (tester) async {
      await tester
          .createDocument() //
          .withSingleParagraph()
          // Use an empty stylesheet to ensure the default text style is inherited when
          // there is no style rule for a node.
          .useStylesheet(
            const Stylesheet(
              inheritDefaultTextStyle: true,
              rules: [],
              inlineTextStyler: defaultInlineTextStyler,
              inlineWidgetBuilders: defaultInlineWidgetBuilderChain,
            ),
          )
          .withCustomWidgetTreeBuilder(
            (superReader) => MaterialApp(
              home: Scaffold(
                body: DefaultTextStyle(
                  style: const TextStyle(fontFamily: goldenBricks),
                  child: superReader,
                ),
              ),
            ),
          )
          .pump();

      // Ensure the font family from the default text style was applied.
      expect(
        _findSpanAtOffset(tester, offset: 0).style!.fontFamily,
        goldenBricks,
      );
    });

    testWidgetsOnArbitraryDesktop('merges style with the enclosing default text style if requested', (tester) async {
      await tester
          .createDocument() //
          .withSingleParagraph()
          .useStylesheet(
            Stylesheet(
              inheritDefaultTextStyle: true,
              rules: [
                StyleRule(
                  BlockSelector.all,
                  (doc, docNode) {
                    return {
                      Styles.textStyle: const TextStyle(fontSize: 24),
                    };
                  },
                ),
              ],
              inlineTextStyler: defaultInlineTextStyler,
              inlineWidgetBuilders: defaultInlineWidgetBuilderChain,
            ),
          )
          .withCustomWidgetTreeBuilder(
            (superReader) => MaterialApp(
              home: Scaffold(
                body: DefaultTextStyle(
                  style: const TextStyle(fontFamily: goldenBricks),
                  child: superReader,
                ),
              ),
            ),
          )
          .pump();

      final spanStyle = _findSpanAtOffset(tester, offset: 0).style!;

      // Ensure the font family from the default text style was applied.
      expect(
        spanStyle.fontFamily,
        goldenBricks,
      );

      // Ensure the font size from the style rule was applied.
      expect(spanStyle.fontSize, 24);
    });

    testWidgetsOnArbitraryDesktop('changes visual text when the enclosing default text style changes', (tester) async {
      final styleNotifier = ValueNotifier<TextStyle>(
        const TextStyle(fontFamily: goldenBricks),
      );

      await tester
          .createDocument() //
          .withSingleParagraph()
          // Use an empty stylesheet to ensure the default text style is inherited when
          // there is no style rule for a node.
          .useStylesheet(
            const Stylesheet(
              inheritDefaultTextStyle: true,
              rules: [],
              inlineTextStyler: defaultInlineTextStyler,
              inlineWidgetBuilders: defaultInlineWidgetBuilderChain,
            ),
          )
          .withCustomWidgetTreeBuilder(
            (superReader) => MaterialApp(
              home: Scaffold(
                body: ValueListenableBuilder(
                  valueListenable: styleNotifier,
                  builder: (context, style, child) {
                    return DefaultTextStyle(
                      style: style,
                      child: superReader,
                    );
                  },
                ),
              ),
            ),
          )
          .pump();

      // Ensure the font family from the default text style was applied.
      expect(
        _findSpanAtOffset(tester, offset: 0).style!.fontFamily,
        goldenBricks,
      );

      // Change the default text style.
      styleNotifier.value = const TextStyle(
        fontFamily: 'Roboto',
      );
      await tester.pump();

      // Ensure the font family from the new default text style was applied.
      expect(
        _findSpanAtOffset(tester, offset: 0).style!.fontFamily,
        'Roboto',
      );
    });
  });
}

Finder _findTextWithAlignment(TextAlign textAlign) =>
    find.byWidgetPredicate((widget) => (widget is SuperText) && widget.textAlign == textAlign);

Future<void> _pumpReader(
  WidgetTester tester, {
  required Stylesheet stylesheet,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SuperReader(
          editor: createDefaultDocumentEditor(
            document: singleParagraphDoc(),
            composer: MutableDocumentComposer(),
          ),
          stylesheet: stylesheet,
        ),
      ),
    ),
  );
}

Stylesheet _stylesheetWithTextAlignment(TextAlign textAlign) {
  return Stylesheet(
    inlineTextStyler: defaultInlineTextStyler,
    rules: [
      StyleRule(
        BlockSelector.all,
        (doc, docNode) {
          return {
            "textAlign": textAlign,
          };
        },
      ),
    ],
  );
}

InlineSpan _findSpanAtOffset(
  WidgetTester tester, {
  required int offset,
}) {
  final superText = tester.widget<SuperText>(find.byType(SuperText));
  return superText.richText.getSpanForPosition(TextPosition(offset: offset))!;
}
