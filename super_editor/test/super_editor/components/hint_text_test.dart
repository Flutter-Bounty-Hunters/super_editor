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
            const HintComponentBuilder("Hello", _hintStyler),
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
  });
}

TextStyle _hintStyler(BuildContext _) => TextStyle();

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
