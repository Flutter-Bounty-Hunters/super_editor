import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_editor/super_text_field.dart';

void main() {
  group("SuperTextField > empty >", () {
    // This desktop test is run on Android because it seems that the golden toolkit
    // only renders real fonts on Android. To account for this, we explicitly configure
    // the SuperTextField to present as a desktop textfield.
    testGoldensOnAndroid("displays hint text with padding", (tester) async {
      // Use a Row as a wrapper to fill the available width.
      final builder = GoldenBuilder.grid(
        columns: 2,
        widthToHeightRatio: 3,
      )
        ..addScenario(
          'Desktop - No Padding',
          _buildEmptySingleLineTextField(
            padding: EdgeInsets.zero,
            platform: SuperTextFieldPlatformConfiguration.desktop,
          ),
        )
        ..addScenario(
          'Desktop - Small Padding',
          _buildEmptySingleLineTextField(
            padding: const EdgeInsets.all(10.0),
            platform: SuperTextFieldPlatformConfiguration.desktop,
          ),
        )
        ..addScenario(
          'Desktop - Large Padding',
          _buildEmptySingleLineTextField(
            padding: const EdgeInsets.all(25.0),
            platform: SuperTextFieldPlatformConfiguration.desktop,
          ),
        )
        ..addScenario(
          'iOS - No Padding',
          _buildEmptySingleLineTextField(
            padding: EdgeInsets.zero,
            platform: SuperTextFieldPlatformConfiguration.iOS,
          ),
        )
        ..addScenario(
          'iOS - Small Padding',
          _buildEmptySingleLineTextField(
            padding: const EdgeInsets.all(10.0),
            platform: SuperTextFieldPlatformConfiguration.iOS,
          ),
        )
        ..addScenario(
          'iOS - Large Padding',
          _buildEmptySingleLineTextField(
            padding: const EdgeInsets.all(25.0),
            platform: SuperTextFieldPlatformConfiguration.iOS,
          ),
        )
        ..addScenario(
          'Android - No Padding',
          _buildEmptySingleLineTextField(
            padding: EdgeInsets.zero,
            platform: SuperTextFieldPlatformConfiguration.android,
          ),
        )
        ..addScenario(
          'Android - Small Padding',
          _buildEmptySingleLineTextField(
            padding: const EdgeInsets.all(10.0),
            platform: SuperTextFieldPlatformConfiguration.android,
          ),
        )
        ..addScenario(
          'Android - Large Padding',
          _buildEmptySingleLineTextField(
            padding: const EdgeInsets.all(25.0),
            platform: SuperTextFieldPlatformConfiguration.android,
          ),
        );

      await tester.pumpWidgetBuilder(builder.build());

      await screenMatchesGolden(tester, 'super_textfield_empty_hint_padding');
    });
  });
}

Widget _buildEmptySingleLineTextField({
  EdgeInsets? padding,
  required SuperTextFieldPlatformConfiguration platform,
}) {
  return ConstrainedBox(
    constraints: const BoxConstraints(
      maxWidth: 250,
    ),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.yellow,
        border: Border.all(),
      ),
      child: SuperTextField(
        textController: AttributedTextEditingController(),
        textStyleBuilder: (_) => const TextStyle(fontSize: 20, color: Colors.black, fontFamily: 'Roboto'),
        hintBuilder: (_) => Text(
          "Hint text...",
          style: defaultHintStyleBuilder({}),
        ),
        maxLines: 1,
        padding: padding,
        lineHeight: 20,
        configuration: platform,
      ),
    ),
  );
}
