import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_test.dart';
import 'package:super_editor/super_text_field_test.dart';

void main() {
  group("SuperTextField > iOS > overlay controls >", () {
    testGoldensOniOS("confines magnifier within screen bounds", (tester) async {
      tester.view
        ..devicePixelRatio = 1.0
        ..platformDispatcher.textScaleFactorTestValue = 1.0
        ..physicalSize = const Size(400.0, 500.0);

      addTearDown(() => tester.platformDispatcher.clearAllTestValues());

      final controller = AttributedTextEditingController(
        text: AttributedText('Lorem ipsum dolor sit amet'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: double.infinity,
                child: SuperTextField(
                  textController: controller,
                  padding: const EdgeInsets.all(20),
                  textStyleBuilder: (_) => const TextStyle(
                    color: Colors.black,
                    // Use Roboto so that goldens show real text
                    fontFamily: 'Roboto',
                  ),
                ),
              ),
            ),
          ),
          debugShowCheckedModeBanner: false,
        ),
      );

      // Place the caret at the end of the textfield.
      await tester.placeCaretInSuperTextField(30);

      // Press and drag the caret to the beginning of the line.
      final gesture = await tester.dragCaretByDistanceInSuperTextField(const Offset(-200, 0));
      await tester.pump();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFileWithPixelAllowance("goldens/super_textfield_ios_magnifier_screen_edges.png", 4),
      );

      // Release the gesture.
      await gesture.up();
    });
  });
}
