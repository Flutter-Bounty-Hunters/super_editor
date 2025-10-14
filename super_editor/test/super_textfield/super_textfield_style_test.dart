import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:golden_bricks/golden_bricks.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart';

void main() {
  group('SuperTextField > DefaultTextStyle >', () {
    testWidgetsOnAllPlatforms('does not inherit the enclosing DefaultTextStyle by default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DefaultTextStyle(
              style: const TextStyle(fontFamily: goldenBricks),
              child: SuperTextField(
                textController: AttributedTextEditingController(
                  text: AttributedText('Hello, world!'),
                ),
              ),
            ),
          ),
        ),
      );

      final textField = find.byType(SuperTextField);
      expect(textField, findsOneWidget);

      // Ensure the font family was not applied from the default text style.
      expect(
        _findSpanAtOffset(tester, offset: 0).style!.fontFamily,
        isNull,
      );
    });

    testWidgetsOnAllPlatforms('inherits the enclosing DefaultTextStyle if requested', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DefaultTextStyle(
              style: const TextStyle(fontFamily: goldenBricks),
              child: SuperTextField(
                inheritDefaultTextStyle: true,
                textController: AttributedTextEditingController(
                  text: AttributedText('Hello, world!'),
                ),
              ),
            ),
          ),
        ),
      );

      final textField = find.byType(SuperTextField);
      expect(textField, findsOneWidget);

      // Ensure the font family from the default text style was applied.
      expect(
        _findSpanAtOffset(tester, offset: 0).style!.fontFamily,
        goldenBricks,
      );
    });

    testWidgetsOnAllPlatforms('merges style with the enclosing default text style if requested', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DefaultTextStyle(
              style: const TextStyle(fontFamily: goldenBricks),
              child: SuperTextField(
                inheritDefaultTextStyle: true,
                textController: AttributedTextEditingController(
                  text: AttributedText('Hello, world!'),
                ),
                textStyleBuilder: (attributions) => const TextStyle(fontSize: 24),
              ),
            ),
          ),
        ),
      );

      final textField = find.byType(SuperTextField);
      expect(textField, findsOneWidget);

      final appliedStyle = _findSpanAtOffset(tester, offset: 0).style!;

      // Ensure the font family from the default text style was applied.
      expect(
        appliedStyle.fontFamily,
        goldenBricks,
      );

      // Ensure the font size from the text style builder was applied.
      expect(
        appliedStyle.fontSize,
        24,
      );
    });

    testWidgetsOnAllPlatforms('changes visual text when the enclosing default text style changes', (tester) async {
      final styleNotifier = ValueNotifier<TextStyle>(
        const TextStyle(fontFamily: goldenBricks),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder(
                valueListenable: styleNotifier,
                builder: (context, style, child) {
                  return DefaultTextStyle(
                    style: style,
                    child: SuperTextField(
                      inheritDefaultTextStyle: true,
                      textController: AttributedTextEditingController(
                        text: AttributedText('Hello, world!'),
                      ),
                    ),
                  );
                }),
          ),
        ),
      );

      final textField = find.byType(SuperTextField);
      expect(textField, findsOneWidget);

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

InlineSpan _findSpanAtOffset(
  WidgetTester tester, {
  required int offset,
}) {
  final superText = tester.widget<SuperText>(find.byType(SuperText));
  return superText.richText.getSpanForPosition(TextPosition(offset: offset))!;
}
