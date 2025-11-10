import 'package:flutter/material.dart' show Colors;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/src/test/super_editor_test/supereditor_inspector.dart';
import 'package:super_editor/super_editor.dart';

import '../supereditor_test_tools.dart';

void main() {
  group("Super Editor > components > hint text >", () {
    testWidgetsOnArbitraryDesktop("displays inline widgets", (tester) async {
      await tester
          .createDocument()
          .withCustomContent(MutableDocument(
            nodes: [
              ParagraphNode(
                  id: "1",
                  text: AttributedText("Hello to ", null, {
                    9: "fake_mention",
                  }))
            ],
          ))
          .withComponentBuilders([
            HintComponentBuilder.basic(
              "Hello",
              hintTextStyle: const TextStyle(),
            ),
            ...defaultComponentBuilders,
          ])
          .useStylesheet(defaultStylesheet.copyWith(
            inlineWidgetBuilders: _inlineWidgetBuilders,
          ))
          .pump();

      // Ensure that we really are using the hint text component.
      expect(find.byType(TextWithHintComponent), findsOne);

      final richText = SuperEditorInspector.findRichTextInParagraph("1");
      expect(richText.children, isNotNull);

      // Verify that we show the text in the node.
      expect(richText.children!.first, isA<TextSpan>());
      expect((richText.children!.first as TextSpan).text, "Hello to ");

      // Verify that we built the inline widget for the place holder in the node.
      expect(richText.children!.last, isA<WidgetSpan>());
      expect((richText.children!.last as WidgetSpan).child, isA<_FakeInlineWidget>());
    });

    testWidgetsOnArbitraryDesktop("allows customizing when the hint should be displayed", (tester) async {
      // By default, the hint component shows the hint text only when there is a single node in the document.
      // Here, we customize that behavior to show the hint text even if there are multiple nodes,
      // as long as the first node is empty.
      await tester
          .createDocument()
          .withCustomContent(MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText(""),
              ),
              ParagraphNode(
                id: "2",
                text: AttributedText("A paragraph"),
              ),
            ],
          ))
          .withAddedComponents(
        [
          HintComponentBuilder.basic(
            "This is a hint",
            hintTextStyle: const TextStyle(),
            shouldShowHint: (document, node) => document.getNodeIndexById(node.id) == 0 && node.text.isEmpty,
          ),
        ],
      ).pump();

      // Ensure that the hint text is being displayed for the empty paragraph.
      expect(find.text("This is a hint", findRichText: true), findsOne);
    });

    testWidgetsOnArbitraryDesktop("allows customizing the hint's textStyle", (tester) async {
      await tester //
          .createDocument()
          .withSingleEmptyParagraph()
          .withAddedComponents(
        [
          HintComponentBuilder.basic(
            "This is a hint",
            hintTextStyle: const TextStyle(color: Colors.red),
          ),
        ],
      ).pump();

      // Ensure that the hint text is being displayed for the empty paragraph with a red color.
      final hintFinder = find.text("This is a hint", findRichText: true);
      expect(hintFinder, findsOne);
      final widget = hintFinder.evaluate().first.widget;
      expect(widget, isA<RichText>());
      expect(
          (widget as RichText) //
              .text
              .getSpanForPosition(const TextPosition(offset: 0))
              ?.style
              ?.color,
          Colors.red);
    });

    testWidgetsOnArbitraryDesktop("allows customizing the hint's textStyle with a hintStyleBuilder", (tester) async {
      await tester //
          .createDocument()
          .withSingleEmptyParagraph()
          .withAddedComponents(
        [
          HintComponentBuilder.basic(
            "This is a hint",
            hintStyleBuilder: (context, attributions) => const TextStyle(color: Colors.red),
          ),
        ],
      ).pump();

      // Ensure that the hint text is being displayed for the empty paragraph with a red color.
      final hintFinder = find.text("This is a hint", findRichText: true);
      expect(hintFinder, findsOne);
      final widget = hintFinder.evaluate().first.widget;
      expect(widget, isA<RichText>());
      expect(
          (widget as RichText) //
              .text
              .getSpanForPosition(const TextPosition(offset: 0))
              ?.style
              ?.color,
          Colors.red);
    });

    testWidgetsOnArbitraryDesktop("honors the default text styles", (tester) async {
      await tester //
          .createDocument()
          .withSingleEmptyParagraph()
          .withAddedComponents(
        [
          HintComponentBuilder.attributed(
            AttributedText(
              "This is a hint",
              // The word "hint" has italics.
              AttributedSpans(
                attributions: [
                  const SpanMarker(attribution: italicsAttribution, offset: 10, markerType: SpanMarkerType.start),
                  const SpanMarker(attribution: italicsAttribution, offset: 13, markerType: SpanMarkerType.end),
                ],
              ),
            ),
            hintTextStyle: const TextStyle(),
          ),
        ],
      ).pump();

      // Ensure that the hint text is being displayed for the empty paragraph and only the word
      // "hint" has italics.
      final hintFinder = find.text("This is a hint", findRichText: true);
      expect(hintFinder, findsOne);
      final widget = hintFinder.evaluate().first.widget;
      expect(widget, isA<RichText>());
      expect(
          (widget as RichText) //
              .text
              .getSpanForPosition(const TextPosition(offset: 0))
              ?.style
              ?.fontStyle,
          isNull);
      expect(
          widget.text //
              .getSpanForPosition(const TextPosition(offset: 10))
              ?.style
              ?.fontStyle,
          FontStyle.italic);
    });
  });
}

const _inlineWidgetBuilders = [
  _buildFakeInlineWidget,
];

Widget? _buildFakeInlineWidget(BuildContext context, TextStyle style, Object placeholder) {
  if (placeholder is! String || placeholder != "fake_mention") {
    return null;
  }

  return const _FakeInlineWidget();
}

class _FakeInlineWidget extends StatelessWidget {
  const _FakeInlineWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      color: Colors.red,
    );
  }
}
