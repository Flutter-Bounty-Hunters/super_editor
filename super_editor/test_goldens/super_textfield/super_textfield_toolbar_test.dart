import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_test.dart';
import 'package:super_editor/super_text_field_test.dart';

void main() {
  group('SuperTextField', () {
    testGoldensOnAndroid('displays toolbar pointing down for expanded selection', (tester) async {
      // Pumps a widget tree with a SuperTextField at the bottom of the screen.
      await _pumpSuperTextfieldToolbarTestApp(
        tester,
        child: Positioned(
          bottom: 50,
          child: _buildSuperTextField(
            text: 'Arrow pointing down',
            configuration: SuperTextFieldPlatformConfiguration.iOS,
          ),
        ),
      );

      // Select a word so that the popover toolbar appears.
      await tester.doubleTapAtSuperTextField(6);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFileWithPixelAllowance("goldens/super_textfield_ios_toolbar_pointing_down_expanded.png", 2),
      );
    });

    testGoldensOniOS('displays toolbar pointing down for collapsed selection', (tester) async {
      // Pumps a widget tree with a SuperTextField at the bottom of the screen.
      await _pumpSuperTextfieldToolbarTestApp(
        tester,
        child: Positioned(
          bottom: 50,
          child: _buildSuperTextField(
            text: 'Arrow pointing down',
          ),
        ),
      );

      // Place the caret at "|pointing".
      await tester.placeCaretInSuperTextField(6);

      // Wait to avoid a double tap.
      await tester.pump(kDoubleTapTimeout);

      // Tap again to show the toolbar.
      await tester.placeCaretInSuperTextField(6);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFileWithPixelAllowance("goldens/super_textfield_ios_toolbar_pointing_down_collapsed.png", 1),
      );
    });

    testGoldensOnAndroid('displays toolbar pointing up for expanded selection', (tester) async {
      // Pumps a widget tree with a SuperTextField at the top of the screen.
      await _pumpSuperTextfieldToolbarTestApp(
        tester,
        child: _buildSuperTextField(
          text: 'Arrow pointing up',
          configuration: SuperTextFieldPlatformConfiguration.iOS,
        ),
      );

      // Select a word so that the popover toolbar appears.
      await tester.doubleTapAtSuperTextField(6);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFileWithPixelAllowance("goldens/super_textfield_ios_toolbar_pointing_up_expanded.png", 3),
      );
    });

    testGoldensOniOS('displays toolbar pointing up for collapsed selection', (tester) async {
      // Pumps a widget tree with a SuperTextField at the top of the screen.
      await _pumpSuperTextfieldToolbarTestApp(
        tester,
        child: _buildSuperTextField(
          text: 'Arrow pointing up',
        ),
      );

      // Place the caret at "|pointing".
      await tester.placeCaretInSuperTextField(6);

      // Wait to avoid a double tap.
      await tester.pump(kDoubleTapTimeout);

      // Tap again to show the toolbar.
      await tester.placeCaretInSuperTextField(6);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFileWithPixelAllowance("goldens/super_textfield_ios_toolbar_pointing_up_collapsed.png", 3),
      );
    });
  });
}

/// Pumps a widget tree which displays the [child] inside a [Stack].
Future<void> _pumpSuperTextfieldToolbarTestApp(
  WidgetTester tester, {
  required Widget child,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Stack(
          children: [child],
        ),
      ),
    ),
  );
}

Widget _buildSuperTextField({
  required String text,
  SuperTextFieldPlatformConfiguration? configuration,
}) {
  final controller = AttributedTextEditingController(
    text: AttributedText(text),
  );

  return Container(
    width: 300,
    decoration: BoxDecoration(
      border: Border.all(color: Colors.green),
    ),
    child: SuperTextField(
      configuration: configuration,
      textController: controller,
      maxLines: 1,
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
