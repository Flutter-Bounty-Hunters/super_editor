import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/src/super_textfield/android/android_textfield.dart';
import 'package:super_editor/src/super_textfield/infrastructure/attributed_text_editing_controller.dart';
import 'package:super_editor/src/super_textfield/input_method_engine/_ime_text_editing_controller.dart';
import 'package:super_editor/src/super_textfield/ios/ios_textfield.dart';
import 'package:super_editor/super_text_field_test.dart';
import 'package:super_text_layout/super_text_layout.dart';

void main() {
  group('SuperTextField', () {
    testWidgetsOnIos('applies app theme to the popover toolbar', (tester) async {
      final controller = ImeAttributedTextEditingController(
        controller: AttributedTextEditingController(
          text: AttributedText('A single line textfield'),
        ),
      );

      // Used to switch between dark/light mode.
      ValueNotifier<ThemeData> themeData = ValueNotifier(ThemeData.dark());

      // Holds the popover theme's brightness.
      Brightness? popoverBrightness;

      await _pumpTestAppScaffold(
        tester,
        theme: themeData,
        child: SuperIOSTextField(
          textController: controller,
          caretStyle: const CaretStyle(),
          selectionColor: Colors.blue,
          handlesColor: Colors.blue,
          popoverToolbarBuilder: (context, overlayController) {
            popoverBrightness = Theme.of(context).brightness;
            return const SizedBox();
          },
        ),
      );

      // Double tap to show the toolbar.
      await tester.doubleTapAtSuperTextField(0, find.byType(SuperIOSTextField));

      // Ensure the toolbar has a dark theme.
      expect(popoverBrightness, Brightness.dark);

      // Switch the theme to light.
      themeData.value = ThemeData.light();
      await tester.pump();

      // Ensure the toolbar also switched to a light theme.
      expect(popoverBrightness, Brightness.light);
    });

    testWidgetsOnAndroid('applies app theme to the popover toolbar', (tester) async {
      final controller = ImeAttributedTextEditingController(
        controller: AttributedTextEditingController(
          text: AttributedText('A single line textfield'),
        ),
      );

      // Used to switch between dark/light mode.
      ValueNotifier<ThemeData> themeData = ValueNotifier(ThemeData.dark());

      // Holds the popover theme's brightness.
      Brightness? popoverBrightness;

      await _pumpTestAppScaffold(
        tester,
        theme: themeData,
        child: SuperAndroidTextField(
          textController: controller,
          caretStyle: const CaretStyle(),
          selectionColor: Colors.blue,
          handlesColor: Colors.blue,
          popoverToolbarBuilder: (context, overlayController, config) {
            popoverBrightness = Theme.of(context).brightness;
            return const SizedBox();
          },
        ),
      );

      // Double tap to show the toolbar.
      await tester.doubleTapAtSuperTextField(0, find.byType(SuperAndroidTextField));

      // Ensure the toolbar has a dark theme.
      expect(popoverBrightness, Brightness.dark);

      // Switch the theme to light.
      themeData.value = ThemeData.light();
      await tester.pump();

      // Ensure the toolbar also switched to a light theme.
      expect(popoverBrightness, Brightness.light);
    });
  });
}

/// Pumps a [Scaffold] which applies the given [theme]'s value to its body.
///
/// The body rebuilds itself whenever the [theme]'s value changes.
Future<void> _pumpTestAppScaffold(
  WidgetTester tester, {
  required ValueListenable<ThemeData> theme,
  required Widget child,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder(
          valueListenable: theme,
          builder: (context, _, __) {
            // The theme must be placed below the MaterialApp
            // so it isn't applied to the app's Overlay.
            return Theme(
              data: theme.value,
              child: SizedBox(
                width: 300,
                child: child,
              ),
            );
          },
        ),
      ),
    ),
  );
}
