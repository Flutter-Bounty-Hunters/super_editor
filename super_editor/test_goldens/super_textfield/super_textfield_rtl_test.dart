import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_reader_test.dart';
import 'package:super_editor/super_test.dart';
import 'package:super_editor/super_text_field_test.dart';

void main() {
  group('SuperTextfield > RTL mode >', () {
    testGoldensOnAllPlatforms(
      'inserts text and paints caret on the left side for downstream position',
      (tester) async {
        await _pumpTestApp(tester);

        // Place the caret at the beginning of the text field.
        await tester.placeCaretInSuperTextField(0);

        // Type the text "Example".
        await tester.ime.typeText(
          'مثال',
          getter: imeClientGetter,
        );
        await tester.pumpAndSettle();

        await screenMatchesGolden(
            tester, 'super-text-field_rtl-caret-at-leftmost-character-${defaultTargetPlatform.name}');
      },
      windowSize: const Size(600, 600),
    );
  });
}

/// Pump a widget tree with a centered multiline textfield with
/// a yellow background, so we can clearly see the bounds of the textfield.
Future<void> _pumpTestApp(WidgetTester tester) async {
  final controller = ImeAttributedTextEditingController();

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            child: ColoredBox(
              color: Colors.yellow,
              child: SuperTextField(
                textController: controller,
                maxLines: 10,
                lineHeight: 16,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
