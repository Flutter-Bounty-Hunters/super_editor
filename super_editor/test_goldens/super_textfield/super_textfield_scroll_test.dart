import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_test.dart';

void main() {
  group('SuperTextField', () {
    testGoldensOnAndroid("multi-line accounts for padding when jumping scroll position down", (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText("First line\nSecond Line\nThird Line\nFourth Line"),
      );

      const description =
          'A SuperTextField scrolled to the end should have the last line fully visible with space below it';

      // Use a Row as a wrapper to fill the available width.
      final builder = GoldenBuilder.column(
        wrap: (child) => Row(
          children: [child],
        ),
      )
        ..addScenario(
          '$description (on Android)',
          _buildTextField(
            textController: controller,
            minLines: 1,
            maxLines: 2,
            maxHeight: 50,
            maxWidth: 200,
            padding: const EdgeInsets.all(10.0),
            configuration: SuperTextFieldPlatformConfiguration.android,
          ),
        )
        ..addScenario(
          '$description (on iOS)',
          _buildTextField(
            textController: controller,
            minLines: 1,
            maxLines: 2,
            maxHeight: 50,
            maxWidth: 200,
            padding: const EdgeInsets.all(10.0),
            configuration: SuperTextFieldPlatformConfiguration.iOS,
          ),
        )
        ..addScenario(
          '$description  (on Desktop)',
          _buildTextField(
            textController: controller,
            minLines: 1,
            maxLines: 2,
            maxHeight: 50,
            maxWidth: 200,
            padding: const EdgeInsets.all(10.0),
            configuration: SuperTextFieldPlatformConfiguration.desktop,
          ),
        );
      await tester.pumpWidgetBuilder(builder.build());

      // Move selection to the end of the text.
      // This will scroll the text field to the end.
      controller.selection = const TextSelection.collapsed(offset: 45);
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, 'super_textfield_scrolled_down');
    });

    testGoldensOnAndroid("multi-line accounts for padding when jumping scroll position up", (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText("First line\nSecond Line\nThird Line\nFourth Line"),
      );

      const description =
          'A SuperTextField scrolled to the beginning should have the first line fully visible with space above it';

      // Use a Row as a wrapper to fill the available width.
      final builder = GoldenBuilder.column(
        wrap: (child) => Row(
          children: [child],
        ),
      )
        ..addScenario(
          '$description (on Android)',
          _buildTextField(
            textController: controller,
            minLines: 1,
            maxLines: 2,
            maxHeight: 50,
            maxWidth: 200,
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 24),
            configuration: SuperTextFieldPlatformConfiguration.android,
          ),
        )
        ..addScenario(
          '$description (on iOS)',
          _buildTextField(
            textController: controller,
            minLines: 1,
            maxLines: 2,
            maxHeight: 50,
            maxWidth: 200,
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 24),
            configuration: SuperTextFieldPlatformConfiguration.iOS,
          ),
        )
        ..addScenario(
          '$description (on Desktop)',
          _buildTextField(
            textController: controller,
            minLines: 1,
            maxLines: 2,
            maxHeight: 50,
            maxWidth: 200,
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 24),
            configuration: SuperTextFieldPlatformConfiguration.desktop,
          ),
        );
      await tester.pumpWidgetBuilder(builder.build());

      // Move selection to the end of the text.
      // This will scroll the text field to the end.
      controller.selection = const TextSelection.collapsed(offset: 45);
      await tester.pumpAndSettle();

      // Place the caret at the beginning of the text.
      controller.selection = const TextSelection.collapsed(offset: 0);
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, 'super_textfield_scrolled_up');
    });
  });
}

Widget _buildTextField({
  required AttributedTextEditingController textController,
  required int minLines,
  required int maxLines,
  double? maxWidth,
  double? maxHeight,
  EdgeInsets? padding,
  SuperTextFieldPlatformConfiguration? configuration,
}) {
  return ConstrainedBox(
    constraints: BoxConstraints(
      maxWidth: maxWidth ?? double.infinity,
      maxHeight: maxHeight ?? double.infinity,
    ),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.yellow,
        border: Border.all(),
      ),
      child: SuperTextField(
        textController: textController,
        lineHeight: 20,
        textStyleBuilder: (_) => const TextStyle(fontSize: 20, color: Colors.black, fontFamily: 'Roboto'),
        minLines: minLines,
        maxLines: maxLines,
        padding: padding,
        configuration: configuration,
      ),
    ),
  );
}
