import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

void main() {
  group("Chat > SuperChatEditor > styles >", () {
    testWidgetsOnArbitraryDesktop("uses the default selection styles", (tester) async {
      await _pumpScaffold(tester);
      await _selectAWord(tester);

      expect(_selectionColor(tester), defaultSelectionStyle.selectionColor);
    });

    testWidgetsOnArbitraryDesktop("applies the given selection styles", (tester) async {
      const selectionColor = Color(0xFFFF0000);
      await _pumpScaffold(tester, selectionStyle: const SelectionStyles(selectionColor: selectionColor));
      await _selectAWord(tester);

      expect(_selectionColor(tester), selectionColor);
    });

    testWidgetsOnArbitraryDesktop("applies new selection styles when they change", (tester) async {
      final editor = _createEditor();
      final pageController = MessagePageController();
      await _pumpScaffold(tester, editor: editor, pageController: pageController);
      await _selectAWord(tester);

      const newSelectionColor = Color(0xFFFF0000);
      await _pumpScaffold(
        tester,
        editor: editor,
        pageController: pageController,
        selectionStyle: const SelectionStyles(selectionColor: newSelectionColor),
      );

      expect(_selectionColor(tester), newSelectionColor);
    });
  });
}

Future<void> _selectAWord(WidgetTester tester) async {
  await tester.doubleTapInParagraph("1", 5);
  await tester.pump();
}

Color _selectionColor(WidgetTester tester) => tester.widget<TextComponent>(find.byType(TextComponent)).selectionColor;

Editor _createEditor() => createDefaultDocumentEditor(
      document: MutableDocument(
        nodes: [
          ParagraphNode(id: "1", text: AttributedText("This is a chat message.")),
        ],
      ),
    );

Future<void> _pumpScaffold(
  WidgetTester tester, {
  Editor? editor,
  MessagePageController? pageController,
  SelectionStyles? selectionStyle,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SuperChatEditor(
          editor: editor ?? _createEditor(),
          pageController: pageController ?? MessagePageController(),
          selectionStyle: selectionStyle,
        ),
      ),
    ),
  );
}
