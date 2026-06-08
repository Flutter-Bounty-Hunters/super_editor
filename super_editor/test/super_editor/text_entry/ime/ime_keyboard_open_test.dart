import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

void main() {
  group('IME input >', () {
    testWidgetsOnMobile('opens software keyboard when tapping on caret', (tester) async {
      await tester
          .createDocument() //
          .withSingleParagraph()
          .withInputSource(TextInputSource.ime)
          .pump();

      // Place the caret at "Lorem| ipsum".
      await tester.placeCaretInParagraph('1', 5);

      // Hide the software keyboard using the system button.
      tester.testTextInput.hide();

      bool wasKeyboardShown = false;

      // Intercept the messages sent to the platform to check if
      // we showed the software keyboard.
      tester
          .interceptChannel(SystemChannels.textInput.name) //
          .interceptMethod(
        'TextInput.show',
        (methodCall) {
          wasKeyboardShown = true;

          return null;
        },
      );

      // Tap again on the same selected position.
      await tester.placeCaretInParagraph('1', 5);

      // Ensure the keyboard was shown.
      expect(wasKeyboardShown, isTrue);
    });

    testWidgetsOnIos('opens software keyboard when tapping on an expanded selection', (tester) async {
      await tester
          .createDocument() //
          .withSingleParagraph()
          .withInputSource(TextInputSource.ime)
          .pump();

      // Double tap to select "|Lorem| ipsum".
      await tester.doubleTapInParagraph('1', 1);

      // Hide the software keyboard using the system button.
      tester.testTextInput.hide();

      bool wasKeyboardShown = false;

      // Intercept the messages sent to the platform to check if
      // we showed the software keyboard.
      tester
          .interceptChannel(SystemChannels.textInput.name) //
          .interceptMethod(
        'TextInput.show',
        (methodCall) {
          wasKeyboardShown = true;

          return null;
        },
      );

      // Tap somewhere on the existing selection.
      await tester.tapInParagraph('1', 3);

      // Ensure the keyboard was shown.
      expect(wasKeyboardShown, isTrue);
    });

    testWidgetsOnAllPlatforms('applies viewId when attaching to the IME', (tester) async {
      await tester
          .createDocument() //
          .withSingleEmptyParagraph()
          .withInputSource(TextInputSource.ime)
          .pump();

      // Intercept the messages sent to the platform to check if
      // we provided the viewId when attaching to the IME.
      int? viewId;
      tester
          .interceptChannel(SystemChannels.textInput.name) //
          .interceptMethod(
        'TextInput.setClient',
        (methodCall) {
          final textInputConfig = (methodCall.arguments as List<dynamic>)[1] as Map;
          viewId = textInputConfig['viewId'];
          return null;
        },
      );

      // Place the caret at the beginning of the paragraph to attach to the IME.
      await tester.placeCaretInParagraph('1', 0);

      // Ensure we provided a viewId when attaching to the IME.
      expect(viewId, isNotNull);
    });
  });
}
