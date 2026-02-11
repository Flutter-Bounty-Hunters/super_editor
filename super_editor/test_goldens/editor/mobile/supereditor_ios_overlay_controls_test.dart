import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:super_editor/super_test.dart';

void main() {
  group("SuperEditor > iOS > overlay controls >", () {
    testGoldensOniOS("confines magnifier within screen bounds", (tester) async {
      tester.view
        ..devicePixelRatio = 1.0
        ..platformDispatcher.textScaleFactorTestValue = 1.0
        ..physicalSize = const Size(400.0, 500.0);

      addTearDown(() => tester.platformDispatcher.clearAllTestValues());

      await tester //
          .createDocument()
          .withSingleParagraph()
          .useStylesheet(Stylesheet(
            rules: defaultStylesheet.rules,
            inlineTextStyler: (attributions, style) => _textStyleBuilder(attributions),
          ))
          .pump();

      // Place the caret at "Duis aute|" (line 6).
      await tester.tapInParagraph("1", 241);

      // Press and drag the caret to the beginning of the line.
      final gesture = await tester.tapDownInParagraph("1", 241);
      for (int i = 1; i < 7; i++) {
        await gesture.moveBy(const Offset(-12, 0));
        await tester.pump();
      }

      await screenMatchesGolden(tester, 'supereditor_ios_magnifier_screen_edges');

      // Resolve the gesture so that we don't have pending gesture timers.
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}

TextStyle _textStyleBuilder(Set<Attribution> attributions) {
  return const TextStyle(
    color: Colors.black,
    fontFamily: 'Roboto',
    fontSize: 16,
    height: 1.4,
  );
}
