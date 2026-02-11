import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_editor/src/super_textfield/desktop/desktop_textfield.dart';
import 'package:super_editor/src/super_textfield/infrastructure/attributed_text_editing_controller.dart';
import 'package:super_editor/super_test.dart';
import 'package:super_editor/super_text_field_test.dart';

void main() {
  group('SuperTextField > single line > with custom font height', () {
    testGoldensOnMac('vertically centers text in viewport', (tester) async {
      final textFieldController = AttributedTextEditingController(
        text: AttributedText('Text with custom font height'),
      );

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: SuperDesktopTextField(
                  textController: textFieldController,
                  decorationBuilder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.blue,
                          width: 1,
                        ),
                      ),
                      child: child,
                    );
                  },
                  textStyleBuilder: (attributions) => const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    leadingDistribution: TextLeadingDistribution.even,
                    height: 6.0,
                  ),
                  minLines: 1,
                  maxLines: 1,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.placeCaretInSuperTextField(0, find.byType(SuperDesktopTextField));
      await screenMatchesGolden(tester, 'super_textfield_font_height');
    });
  });
}
