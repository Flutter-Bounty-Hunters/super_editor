import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_text_field_test.dart';

void main() {
  group("SuperTextField > Mac > Selectors > ", () {
    testWidgetsOnMac('allows apps to handle selectors in their own way', (tester) async {
      bool customHandlerCalled = false;

      final controller = AttributedTextEditingController(
        text: AttributedText('Selectors test'),
      );

      await tester.pumpWidget(
        _buildScaffold(
          child: SuperTextField(
            textController: controller,
            inputSource: TextInputSource.ime,
            selectorHandlers: {
              MacOsSelectors.moveRight: ({
                required SuperTextFieldContext textFieldContext,
              }) {
                customHandlerCalled = true;
              }
            },
          ),
        ),
      );

      // Place the caret at the beginning of the text field.
      await tester.placeCaretInSuperTextField(0);

      // Press right arrow key to trigger the MacOsSelectors.moveRight selector.
      await tester.pressRightArrow();

      // Ensure the custom handler was called.
      expect(customHandlerCalled, isTrue);

      // Ensure that the textfield didn't execute the default handler for the MacOsSelectors.moveRight selector.
      expect(
        SuperTextFieldInspector.findSelection(),
        const TextSelection.collapsed(offset: 0),
      );
    });
  });

  testWidgetsOnMac('prevents surrounding widgets from consuming control keys that trigger OS selectors',
      (tester) async {
    // Explanation: Mac OS selectors are only generated for a given key event, if that key event
    // isn't handled by anything within Flutter code. Some key events are almost always tied to
    // Shortcuts higher up in the tree, e.g., ESC to generate a DismissIntent. Therefore, SuperTextField
    // needs to explicitly tell Flutter to stop propagating any key event that's expected to generate a
    // selector on the OS side.
    bool receivedOsSelector = false;

    await tester.pumpWidget(
      _buildScaffold(
        child: Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
          },
          child: Actions(
            actions: {
              DismissIntent: CallbackAction<DismissIntent>(onInvoke: (DismissIntent intent) {
                fail("Received a DismissIntent from Shortcuts but that shortcut should never have been activated.");
              }),
            },
            child: SuperTextField(
              inputSource: TextInputSource.ime,
              selectorHandlers: {
                MacOsSelectors.cancelOperation: ({
                  required SuperTextFieldContext textFieldContext,
                }) {
                  receivedOsSelector = true;
                }
              },
            ),
          ),
        ),
      ),
    );

    // Give focus to the text field so that it handles key presses.
    await tester.placeCaretInSuperTextField(0);

    // Press ESC, which we expect to make it all the way to the OS.
    await tester.pressEscape();

    // Ensure that the key event skipped the Flutter tree Shortcuts and Actions and
    // made it back to us as an OS selector.
    expect(receivedOsSelector, isTrue);
  });
}

Widget _buildScaffold({
  required Widget child,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 300,
        child: child,
      ),
    ),
  );
}
