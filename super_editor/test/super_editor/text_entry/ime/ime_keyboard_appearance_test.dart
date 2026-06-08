import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

void main() {
  group('IME input >', () {
    group('applies keyboard appearance', () {
      testWidgetsOnIos('dark from theme', (tester) async {
        await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .useAppTheme(ThemeData.dark())
            .pump();

        // Holds the keyboard appearance sent to the platform.
        String? keyboardAppearance;

        _interceptKeyboardAppearanceSentToPlatform(
          tester,
          (appearance) => keyboardAppearance = appearance,
        );

        // Place the caret at the empty paragraph to trigger the software keyboard.
        await tester.placeCaretInParagraph('1', 0);

        // Ensure the given keyboardAppearance was applied.
        expect(keyboardAppearance, 'Brightness.dark');
      });

      testWidgetsOnIos('light from theme', (tester) async {
        await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .useAppTheme(ThemeData.light())
            .pump();

        // Holds the keyboard appearance sent to the platform.
        String? keyboardAppearance;

        _interceptKeyboardAppearanceSentToPlatform(
          tester,
          (appearance) => keyboardAppearance = appearance,
        );

        // Place the caret at the empty paragraph to trigger the software keyboard.
        await tester.placeCaretInParagraph('1', 0);

        // Ensure the given keyboardAppearance was applied.
        expect(keyboardAppearance, 'Brightness.light');
      });

      testWidgetsOnIos('from the given configuration', (tester) async {
        // Pump an editor with a light theme to ensure we are a configuration
        // with different brightness.
        await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .useAppTheme(ThemeData.light())
            .withImeConfiguration(
              const SuperEditorImeConfiguration(
                keyboardBrightness: Brightness.dark,
              ),
            )
            .pump();

        // Holds the keyboard appearance sent to the platform.
        String? keyboardAppearance;

        _interceptKeyboardAppearanceSentToPlatform(
          tester,
          (appearance) => keyboardAppearance = appearance,
        );

        // Place the caret at the empty paragraph to trigger the software keyboard.
        await tester.placeCaretInParagraph('1', 0);

        // Ensure the given keyboardAppearance was applied.
        expect(keyboardAppearance, 'Brightness.dark');
      });
    });
  });
}

/// Intercepts `TextInput.setClient` calls and invokes [onSetKeyboard]
/// with the configured keyboard keyboardAppearance.
void _interceptKeyboardAppearanceSentToPlatform(
    WidgetTester tester, void Function(String keyboardAppearance) onSetKeyboard) {
  tester
      .interceptChannel(SystemChannels.textInput.name) //
      .interceptMethod(
    'TextInput.setClient',
    (methodCall) {
      final params = methodCall.arguments[1] as Map;
      onSetKeyboard(params['keyboardAppearance']);
      return null;
    },
  );
}
