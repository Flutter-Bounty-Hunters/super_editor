import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_test.dart';

void main() {
  // These golden tests are being skipped on macOS because the text seems to be
  // a bit bigger in this platform, causing the tests to fail.
  group('SuperTextField', () {
    group('single line', () {
      group('displays different alignments', () {
        testGoldensOnAndroid('(on Android)', (tester) async {
          await _pumpScaffold(
            tester,
            children: [
              _buildSuperTextField(
                text: "Left",
                textAlign: TextAlign.left,
                maxLines: 1,
                configuration: SuperTextFieldPlatformConfiguration.android,
              ),
              _buildSuperTextField(
                text: "Center",
                textAlign: TextAlign.center,
                maxLines: 1,
                configuration: SuperTextFieldPlatformConfiguration.android,
              ),
              _buildSuperTextField(
                text: "Right",
                textAlign: TextAlign.right,
                maxLines: 1,
                configuration: SuperTextFieldPlatformConfiguration.android,
              ),
            ],
          );

          await screenMatchesGolden(tester, 'super_textfield_alignments_singleline_android');
        }, skip: Platform.isMacOS);

        testGoldensOnAndroid('(on iOS)', (tester) async {
          await _pumpScaffold(
            tester,
            children: [
              _buildSuperTextField(
                text: "Left",
                textAlign: TextAlign.left,
                maxLines: 1,
                configuration: SuperTextFieldPlatformConfiguration.iOS,
              ),
              _buildSuperTextField(
                text: "Center",
                textAlign: TextAlign.center,
                maxLines: 1,
                configuration: SuperTextFieldPlatformConfiguration.iOS,
              ),
              _buildSuperTextField(
                text: "Right",
                textAlign: TextAlign.right,
                maxLines: 1,
                configuration: SuperTextFieldPlatformConfiguration.iOS,
              ),
            ],
          );

          await screenMatchesGolden(tester, 'super_textfield_alignments_singleline_ios');
        }, skip: Platform.isMacOS);

        testGoldensOnAndroid('(on Desktop)', (tester) async {
          await _pumpScaffold(
            tester,
            children: [
              _buildSuperTextField(
                text: "Left",
                textAlign: TextAlign.left,
                maxLines: 1,
                configuration: SuperTextFieldPlatformConfiguration.desktop,
              ),
              _buildSuperTextField(
                text: "Center",
                textAlign: TextAlign.center,
                maxLines: 1,
                configuration: SuperTextFieldPlatformConfiguration.desktop,
              ),
              _buildSuperTextField(
                text: "Right",
                textAlign: TextAlign.right,
                maxLines: 1,
                configuration: SuperTextFieldPlatformConfiguration.desktop,
              ),
            ],
          );

          await screenMatchesGolden(tester, 'super_textfield_alignments_singleline_desktop');
        }, skip: Platform.isMacOS);
      });
    });

    group('multi line', () {
      const multilineText = 'First Line\nSecond Line\nThird Line\nFourth Line';
      group('displays different alignments', () {
        testGoldensOnAndroid('(on Android)', (tester) async {
          await _pumpScaffold(
            tester,
            children: [
              _buildSuperTextField(
                text: multilineText,
                textAlign: TextAlign.left,
                maxLines: 4,
                configuration: SuperTextFieldPlatformConfiguration.android,
              ),
              _buildSuperTextField(
                text: multilineText,
                textAlign: TextAlign.center,
                maxLines: 4,
                configuration: SuperTextFieldPlatformConfiguration.android,
              ),
              _buildSuperTextField(
                text: multilineText,
                textAlign: TextAlign.right,
                maxLines: 4,
                configuration: SuperTextFieldPlatformConfiguration.android,
              ),
            ],
          );

          await screenMatchesGolden(tester, 'super_textfield_alignments_multiline_android');
        }, skip: Platform.isMacOS);

        testGoldensOnAndroid('(on iOS)', (tester) async {
          await _pumpScaffold(
            tester,
            children: [
              _buildSuperTextField(
                text: multilineText,
                textAlign: TextAlign.left,
                maxLines: 4,
                configuration: SuperTextFieldPlatformConfiguration.iOS,
              ),
              _buildSuperTextField(
                text: multilineText,
                textAlign: TextAlign.center,
                maxLines: 4,
                configuration: SuperTextFieldPlatformConfiguration.iOS,
              ),
              _buildSuperTextField(
                text: multilineText,
                textAlign: TextAlign.right,
                maxLines: 4,
                configuration: SuperTextFieldPlatformConfiguration.iOS,
              ),
            ],
          );

          await screenMatchesGolden(tester, 'super_textfield_alignments_multiline_ios');
        }, skip: Platform.isMacOS);

        testGoldensOnAndroid('(on Desktop)', (tester) async {
          await _pumpScaffold(
            tester,
            children: [
              _buildSuperTextField(
                text: multilineText,
                textAlign: TextAlign.left,
                maxLines: 4,
                configuration: SuperTextFieldPlatformConfiguration.desktop,
              ),
              _buildSuperTextField(
                text: multilineText,
                textAlign: TextAlign.center,
                maxLines: 4,
                configuration: SuperTextFieldPlatformConfiguration.desktop,
              ),
              _buildSuperTextField(
                text: multilineText,
                textAlign: TextAlign.right,
                maxLines: 4,
                configuration: SuperTextFieldPlatformConfiguration.desktop,
              ),
            ],
          );

          await screenMatchesGolden(tester, 'super_textfield_alignments_multiline_desktop');
        });
      }, skip: Platform.isMacOS);

      testWidgetsOnAllPlatforms('makes scrollview fill all the field width', (tester) async {
        await _pumpScaffold(
          tester,
          children: [
            _buildSuperTextField(
              text: multilineText,
              textAlign: TextAlign.center,
              maxLines: 4,
            ),
          ],
        );
        await tester.pump();

        final textfieldWidth = tester.getSize(find.byType(SuperTextField)).width;
        final scrollViewWidth = tester.getSize(find.byType(SingleChildScrollView)).width;

        // Ensure the scrollview occupies all the available width rathen than
        // just width of the text.
        expect(scrollViewWidth, equals(textfieldWidth));
      });
    });
  });
}

Widget _buildSuperTextField({
  required String text,
  required TextAlign textAlign,
  SuperTextFieldPlatformConfiguration? configuration,
  int? maxLines,
}) {
  final controller = AttributedTextEditingController(
    text: AttributedText(text),
  );

  return SizedBox(
    width: double.infinity,
    child: SuperTextField(
      configuration: configuration,
      textController: controller,
      textAlign: textAlign,
      maxLines: maxLines,
      minLines: 1,
      lineHeight: 20,
      textStyleBuilder: (_) {
        return const TextStyle(
          color: Colors.black,
          fontSize: 20,
        );
      },
    ),
  );
}

Future<void> _pumpScaffold(
  WidgetTester tester, {
  required List<Widget> children,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Column(children: children),
      ),
    ),
  );
}
