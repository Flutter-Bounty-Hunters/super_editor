import 'package:flutter/material.dart' hide SelectableText;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:super_editor/super_text_field_test.dart';

void main() {
  group('SuperTextField', () {
    group('with IME input source', () {
      group('inserts character', () {
        testWidgetsOnAllPlatforms('in empty text', (tester) async {
          await _pumpEmptySuperTextField(tester);
          await tester.placeCaretInSuperTextField(0);

          await tester.ime.typeText("f", getter: imeClientGetter);

          expect(SuperTextFieldInspector.findText().toPlainText(), "f");
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 1));
        });

        testWidgetsOnAllPlatforms('in middle of text', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('--><--'),
            ),
          );
          await tester.placeCaretInSuperTextField(3);

          await tester.ime.typeText("f", getter: imeClientGetter);

          expect(SuperTextFieldInspector.findText().toPlainText(), "-->f<--");
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 4));
        });

        testWidgetsOnAllPlatforms('at end of text', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('-->'),
            ),
          );
          await tester.placeCaretInSuperTextField(3);

          await tester.ime.typeText("f", getter: imeClientGetter);

          expect(SuperTextFieldInspector.findText().toPlainText(), "-->f");
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 4));
        });

        testWidgetsOnAllPlatforms('and replaces selected text', (tester) async {
          // TODO: We create the controller outside the pump so that we can explicitly set its selection
          //  because we don't support gesture selection on mobile, yet.
          final controller = AttributedTextEditingController(
            text: AttributedText('-->REPLACE<--'),
          );
          await _pumpSuperTextField(
            tester,
            controller,
          );

          // TODO: switch this to gesture selection when we support that on mobile
          controller.selection = const TextSelection(baseOffset: 3, extentOffset: 10);

          await tester.ime.typeText("f", getter: imeClientGetter);

          expect(SuperTextFieldInspector.findText().toPlainText(), "-->f<--");
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 4));
        });

        testWidgetsOnAllPlatforms('and clears composing region after text changes', (tester) async {
          final controller = ImeAttributedTextEditingController();
          await _pumpSuperTextField(tester, controller);

          await tester.placeCaretInSuperTextField(0);

          bool sentToPlatform = false;
          int? composingBase;
          int? composingExtent;

          // Intercept the setEditingState message sent to the platform.
          tester
              .interceptChannel(SystemChannels.textInput.name) //
              .interceptMethod(
            'TextInput.setEditingState',
            (methodCall) {
              if (methodCall.method == 'TextInput.setEditingState') {
                sentToPlatform = true;
                composingBase = methodCall.arguments["composingBase"];
                composingExtent = methodCall.arguments["composingExtent"];
              }
              return null;
            },
          );

          // Type "a".
          await tester.ime.typeText('a', getter: imeClientGetter);

          // Manually set the value to "b" to send the value to the IME.
          controller.text = AttributedText('b');

          // Ensure we send the value back to the IME.
          expect(sentToPlatform, true);

          // Ensure we cleared the composing region.
          expect(composingBase, -1);
          expect(composingExtent, -1);
        });

        testWidgetsOnAllPlatforms('and don\'t send editing value back to IME if matches the expected value',
            (tester) async {
          await _pumpEmptySuperTextField(tester);
          await tester.placeCaretInSuperTextField(0);

          bool sentToPlatform = false;

          // Intercept the setEditingState message sent to the platform.
          tester
              .interceptChannel(SystemChannels.textInput.name) //
              .interceptMethod(
            'TextInput.setEditingState',
            (methodCall) {
              if (methodCall.method == 'TextInput.setEditingState') {
                sentToPlatform = true;
              }
              return null;
            },
          );

          // Type "a".
          // The IME now sees "a" as the editing value.
          await tester.ime.typeText('a', getter: imeClientGetter);

          // Ensure that after the insertion our value is also "a".
          expect(SuperTextFieldInspector.findText().toPlainText(), 'a');

          // Ensure we don't send the value back to the OS.
          //
          // As both us and the IME agree on what's the current editing value, we don't need to send it back.
          expect(sentToPlatform, false);
        });

        testWidgetsOnAllPlatforms('and send editing value back to IME if it doesn\'t match the expected value',
            (tester) async {
          final controller = ImeAttributedTextEditingController(
            controller: _ObscuringTextController(),
          );
          await _pumpSuperTextField(tester, controller);

          await tester.placeCaretInSuperTextField(0);

          bool sentToPlatform = false;

          // Intercept the setEditingState message sent to the platform.
          tester
              .interceptChannel(SystemChannels.textInput.name) //
              .interceptMethod(
            'TextInput.setEditingState',
            (methodCall) {
              if (methodCall.method == 'TextInput.setEditingState') {
                sentToPlatform = true;
              }
              return null;
            },
          );

          // Type "ab". Our controller will change the text to "*b" when the second delta is processed.
          await tester.ime.typeText("ab", getter: imeClientGetter);

          // We are using a custom controller which changes every character but the last one to "*".
          // After typing "b" the IME thinks the text is "ab". However, for us the text is "*b".
          // As our value is different from what the IME thinks it is, we need to send our current value
          // back to the IME.

          // Ensure we sent the value back to the IME.
          expect(sentToPlatform, true);
        });

        testWidgetsOnAllPlatforms(
            'and don\'t send editing value back to the IME on replacements if matches the expected value',
            (tester) async {
          final controller = ImeAttributedTextEditingController(
            controller: AttributedTextEditingController(
              text: AttributedText('-->REPLACE'),
            ),
          );

          await _pumpSuperTextField(tester, controller);

          // Select the word REPLACE.
          await tester.doubleTapAtSuperTextField(3);

          bool sentToPlatform = false;

          // Intercept the setEditingState message sent to the platform to check if we sent the value
          // back to the IME.
          tester
              .interceptChannel(SystemChannels.textInput.name) //
              .interceptMethod(
            'TextInput.setEditingState',
            (methodCall) {
              if (methodCall.method == 'TextInput.setEditingState') {
                sentToPlatform = true;
              }
              return null;
            },
          );

          // Simulate the IME sending a replacement with a non-empty composing region.
          await tester.ime.sendDeltas([
            const TextEditingDeltaReplacement(
              oldText: '-->REPLACE',
              replacementText: 'a',
              replacedRange: TextRange(start: 3, end: 10),
              selection: TextSelection.collapsed(offset: 4),
              composing: TextRange(start: 3, end: 4),
            ),
          ], getter: imeClientGetter);

          // Ensure we send the value back to the IME.
          //
          // As both us and the IME agree on what's the current editing value, we don't need to send it back.
          expect(sentToPlatform, false);
        });
      });

      group('inserts line', () {
        testWidgetsOnDesktop('when ENTER is pressed in middle of text', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('this is some text'),
            ),
          );
          await tester.placeCaretInSuperTextField(8);

          await tester.pressEnterAdaptive(getter: imeClientGetter);

          expect(SuperTextFieldInspector.findText().toPlainText(), "this is \nsome text");
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 9));
        });

        testWidgetsOnDesktop('when ENTER is pressed at beginning of text', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('this is some text'),
            ),
          );
          await tester.placeCaretInSuperTextField(0);

          await tester.pressEnterAdaptive(getter: imeClientGetter);

          expect(SuperTextFieldInspector.findText().toPlainText(), "\nthis is some text");
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 1));
        });

        testWidgetsOnDesktop('when ENTER is pressed at end of text', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('this is some text'),
            ),
          );
          await tester.placeCaretInSuperTextField(17);

          await tester.pressEnterAdaptive(getter: imeClientGetter);

          expect(SuperTextFieldInspector.findText().toPlainText(), "this is some text\n");
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 18));
        });

        // TODO: Merge this with the testWidgetsOnMac below when Flutter supports numpad enter on windows
        testWidgetsOnLinux('when NUMPAD ENTER is pressed in middle of text', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('this is some text'),
            ),
          );
          await tester.placeCaretInSuperTextField(8);

          await tester.pressNumpadEnterAdaptive(getter: imeClientGetter);

          expect(SuperTextFieldInspector.findText().toPlainText(), "this is \nsome text");
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 9));
        });

        testWidgetsOnMac('when NUMPAD ENTER is pressed in middle of tex', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('this is some text'),
            ),
          );
          await tester.placeCaretInSuperTextField(8);

          await tester.pressNumpadEnterAdaptive(getter: imeClientGetter);

          expect(SuperTextFieldInspector.findText().toPlainText(), "this is \nsome text");
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 9));
        });

        // TODO: Merge this with the testWidgetsOnMac below when Flutter supports numpad enter on windows
        testWidgetsOnLinux('when NUMPAD ENTER is pressed at beginning of text', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('this is some text'),
            ),
          );
          await tester.placeCaretInSuperTextField(0);

          await tester.pressNumpadEnterAdaptive(getter: imeClientGetter);

          expect(SuperTextFieldInspector.findText().toPlainText(), "\nthis is some text");
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 1));
        });

        testWidgetsOnMac('when NUMPAD ENTER is pressed at beginning of text', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('this is some text'),
            ),
          );
          await tester.placeCaretInSuperTextField(0);

          await tester.pressNumpadEnterAdaptive(getter: imeClientGetter);

          expect(SuperTextFieldInspector.findText().toPlainText(), "\nthis is some text");
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 1));
        });

        // TODO: Merge this with the testWidgetsOnMac below when Flutter supports numpad enter on windows
        testWidgetsOnLinux('when NUMPAD ENTER is pressed at end of text', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('this is some text'),
            ),
          );
          await tester.placeCaretInSuperTextField(17);

          await tester.pressNumpadEnterAdaptive(getter: imeClientGetter);

          expect(SuperTextFieldInspector.findText().toPlainText(), "this is some text\n");
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 18));
        });

        testWidgetsOnMac('when NUMPAD ENTER is pressed at end of text', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText('this is some text'),
            ),
          );
          await tester.placeCaretInSuperTextField(17);

          await tester.pressNumpadEnterAdaptive(getter: imeClientGetter);

          expect(SuperTextFieldInspector.findText().toPlainText(), "this is some text\n");
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 18));
        });
      });

      group('delete text', () {
        testWidgetsOnAllPlatforms('BACKSPACE does nothing when text is empty', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText(""),
            ),
          );
          await tester.placeCaretInSuperTextField(0);

          await tester.ime.backspace(getter: imeClientGetter);

          expect(SuperTextFieldInspector.findText().toPlainText(), "");
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 0));
        });

        testWidgetsOnAllPlatforms('BACKSPACE deletes the previous character', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText("this is some text"),
            ),
          );
          await tester.placeCaretInSuperTextField(2);

          await tester.ime.backspace(getter: imeClientGetter);

          expect(SuperTextFieldInspector.findText().toPlainText(), "tis is some text");
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 1));
        });

        testWidgetsOnAllPlatforms('BACKSPACE deletes selection when selection is expanded', (tester) async {
          // TODO: We create the controller outside the pump so that we can explicitly set its selection
          //  because we don't support gesture selection on mobile, yet.
          final controller = AttributedTextEditingController(
            text: AttributedText(_multilineLayoutText),
          );
          await _pumpSuperTextField(
            tester,
            controller,
          );

          // TODO: switch this to gesture selection when we support that on mobile
          controller.selection = const TextSelection(baseOffset: 0, extentOffset: 10);

          await tester.ime.backspace(getter: imeClientGetter);

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 0));
          expect(SuperTextFieldInspector.findText().toPlainText(),
              "is long enough to be multiline in the available space");
        });
      });

      testWidgetsOnAllPlatforms('clears composing region after selection changes', (tester) async {
        final controller = ImeAttributedTextEditingController();
        await _pumpSuperTextField(tester, controller);

        // Place the caret at the beginning of the textfield.
        await tester.placeCaretInSuperTextField(0);

        // Type something to have some text to tap on.
        await tester.typeImeText('Composing: ');

        // Ensure we don't have a composing region.
        expect(controller.composingRegion, TextRange.empty);

        // Simulate an insertion containing a composing region.
        await tester.ime.sendDeltas(
          [
            const TextEditingDeltaInsertion(
              oldText: 'Composing: ',
              textInserted: "あs",
              insertionOffset: 11,
              selection: TextSelection.collapsed(offset: 13),
              composing: TextRange(start: 11, end: 13),
            ),
          ],
          getter: imeClientGetter,
        );

        // Ensure the textfield applied the composing region.
        expect(controller.composingRegion, const TextRange(start: 11, end: 13));

        int? composingBase;
        int? composingExtent;

        // Intercept the setEditingState message sent to the platform to check if we
        // cleared the IME composing region when changing the selection.
        tester
            .interceptChannel(SystemChannels.textInput.name) //
            .interceptMethod(
          'TextInput.setEditingState',
          (methodCall) {
            composingBase = methodCall.arguments["composingBase"];
            composingExtent = methodCall.arguments["composingExtent"];
            return null;
          },
        );

        // Place the caret at the beginning of the textfield.
        await tester.placeCaretInSuperTextField(0);

        // Ensure we cleared the composing region.
        expect(composingBase, -1);
        expect(composingExtent, -1);

        // Ensure the textfield composing region was cleared.
        expect(controller.composingRegion, TextRange.empty);
      });

      testWidgetsOnAllPlatforms('clears composing region after losing focus', (tester) async {
        final controller = ImeAttributedTextEditingController();
        final focusNode = FocusNode();

        await _pumpSuperTextField(
          tester,
          controller,
          focusNode: focusNode,
        );

        // Place the caret at the beginning of the textfield.
        await tester.placeCaretInSuperTextField(0);

        // Type something to have some text to tap on.
        await tester.typeImeText('Composing: ');

        // Ensure we don't have a composing region.
        expect(controller.composingRegion, TextRange.empty);

        // Simulate an insertion containing a composing region.
        await tester.ime.sendDeltas(
          [
            const TextEditingDeltaInsertion(
              oldText: 'Composing: ',
              textInserted: "あs",
              insertionOffset: 11,
              selection: TextSelection.collapsed(offset: 13),
              composing: TextRange(start: 11, end: 13),
            ),
          ],
          getter: imeClientGetter,
        );

        // Ensure the textfield applied the composing region.
        expect(controller.composingRegion, const TextRange(start: 11, end: 13));

        // Remove focus from the textfield.
        focusNode.unfocus();
        await tester.pump();

        // Ensure the composing region was cleared.
        expect(controller.composingRegion, TextRange.empty);
      });
    });

    testWidgetsOnMobile('configures the software keyboard action button', (tester) async {
      await tester.pumpWidget(
        _buildScaffold(
          child: const SuperTextField(
            textInputAction: TextInputAction.next,
          ),
        ),
      );

      // Holds the keyboard input action sent to the platform.
      String? inputAction;

      // Intercept messages sent to the platform.
      tester.binding.defaultBinaryMessenger.setMockMessageHandler(SystemChannels.textInput.name, (message) async {
        final methodCall = const JSONMethodCodec().decodeMethodCall(message);
        if (methodCall.method == 'TextInput.setClient') {
          final params = methodCall.arguments[1] as Map;
          inputAction = params['inputAction'];
        }
        return null;
      });

      // Tap the text field to show the software keyboard.
      await tester.placeCaretInSuperTextField(0);

      // Ensure the given TextInputAction was applied.
      expect(inputAction, 'TextInputAction.next');
    });

    testWidgetsOnAllPlatforms('disconnects from IME when disposed', (tester) async {
      final controller = ImeAttributedTextEditingController();
      await _pumpSuperTextField(tester, controller);

      // Place the caret to open an IME connection.
      await tester.placeCaretInSuperTextField(0);

      // Ensure the IME connection is open.
      expect(controller.isAttachedToIme, isTrue);

      // Pump a different tree to cause the text field to dispose.
      await tester.pumpWidget(const MaterialApp());

      // Ensure the IME connection is closed.
      expect(controller.isAttachedToIme, isFalse);
    });

    testWidgetsOnAllPlatforms('applies custom IME configuration', (tester) async {
      // Pump a SuperTextField with an IME configuration with values
      // that differ from the defaults.
      await tester.pumpWidget(
        _buildScaffold(
          child: const SuperTextField(
            inputSource: TextInputSource.ime,
            imeConfiguration: TextInputConfiguration(
              enableSuggestions: false,
              autocorrect: false,
              inputAction: TextInputAction.search,
              keyboardAppearance: Brightness.dark,
              inputType: TextInputType.number,
              enableDeltaModel: false,
            ),
          ),
        ),
      );

      // Holds the IME configuration values passed to the platform.
      String? inputAction;
      String? inputType;
      bool? autocorrect;
      bool? enableSuggestions;
      String? keyboardAppearance;
      bool? enableDeltaModel;

      // Intercept the setClient message sent to the platform to check the configuration.
      tester
          .interceptChannel(SystemChannels.textInput.name) //
          .interceptMethod(
        'TextInput.setClient',
        (methodCall) {
          final params = methodCall.arguments[1] as Map;
          inputAction = params['inputAction'];
          autocorrect = params['autocorrect'];
          enableSuggestions = params['enableSuggestions'];
          keyboardAppearance = params['keyboardAppearance'];
          enableDeltaModel = params['enableDeltaModel'];

          final inputTypeConfig = params['inputType'] as Map;
          inputType = inputTypeConfig['name'];

          return null;
        },
      );

      // Tap to focus the text field and attach to the IME.
      await tester.placeCaretInSuperTextField(0);

      // Ensure we use the values from the configuration.
      expect(inputAction, 'TextInputAction.search');
      expect(inputType, 'TextInputType.number');
      expect(autocorrect, false);
      expect(enableSuggestions, false);
      expect(enableDeltaModel, true);
      expect(keyboardAppearance, 'Brightness.dark');
    });

    testWidgetsOnAllPlatforms('applies viewId when attaching to the IME', (tester) async {
      await _pumpEmptySuperTextField(tester);

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

      // Place the caret to attach to the IME.
      await tester.placeCaretInSuperTextField(0);

      // Ensure we provided a viewId when attaching to the IME.
      expect(viewId, isNotNull);
    });

    group('on iPhone 15 (iOS 17.5)', () {
      testWidgetsOnIos('ignores keyboard autocorrections when pressing the action button', (tester) async {
        await _pumpEmptySuperTextField(tester);

        // Place the caret at the start of the text field.
        await tester.placeCaretInSuperTextField(0);

        // Type some text.
        await tester.typeImeText('run tom');

        // Press the "Done" button.
        await tester.testTextInput.receiveAction(TextInputAction.done);

        // Simulate the IME sending a delta replacing "tom" with "Tom".
        await tester.ime.sendDeltas([
          const TextEditingDeltaReplacement(
            oldText: '. run tom',
            replacementText: 'Tom',
            replacedRange: TextRange(start: 6, end: 9),
            selection: TextSelection.collapsed(offset: 9),
            composing: TextRange(start: -1, end: -1),
          ),
        ], getter: imeClientGetter);
        await tester.pump();

        // Ensure the correction was ignored.
        expect(SuperTextFieldInspector.findText().toPlainText(), 'run tom');
      });
    });
  });

  testWidgetsOnAllPlatforms('updates IME configuration when it changes', (tester) async {
    final brightnessNotifier = ValueNotifier(Brightness.dark);

    // Pump a SuperTextField with an IME configuration with values
    // that differ from the defaults.
    await tester.pumpWidget(
      _buildScaffold(
        child: ValueListenableBuilder(
          valueListenable: brightnessNotifier,
          builder: (context, brightness, child) {
            return SuperTextField(
              inputSource: TextInputSource.ime,
              imeConfiguration: TextInputConfiguration(
                enableSuggestions: false,
                autocorrect: false,
                inputAction: TextInputAction.search,
                keyboardAppearance: brightness,
                inputType: TextInputType.number,
                enableDeltaModel: false,
                textCapitalization: TextCapitalization.characters,
              ),
            );
          },
        ),
      ),
    );

    // Holds the IME configuration values passed to the platform.
    String? inputAction;
    String? inputType;
    bool? autocorrect;
    bool? enableSuggestions;
    String? keyboardAppearance;
    bool? enableDeltaModel;
    String? textCapitalization;

    // Intercept the setClient message sent to the platform to check the configuration.
    tester
        .interceptChannel(SystemChannels.textInput.name) //
        .interceptMethod(
      'TextInput.setClient',
      (methodCall) {
        final params = methodCall.arguments[1] as Map;
        inputAction = params['inputAction'];
        autocorrect = params['autocorrect'];
        enableSuggestions = params['enableSuggestions'];
        keyboardAppearance = params['keyboardAppearance'];
        enableDeltaModel = params['enableDeltaModel'];
        textCapitalization = params['textCapitalization'];

        final inputTypeConfig = params['inputType'] as Map;
        inputType = inputTypeConfig['name'];

        return null;
      },
    );

    // Tap to focus the text field and attach to the IME.
    await tester.placeCaretInSuperTextField(0);

    // Ensure we use the values from the configuration.
    expect(inputAction, 'TextInputAction.search');
    expect(inputType, 'TextInputType.number');
    expect(autocorrect, false);
    expect(enableSuggestions, false);
    expect(enableDeltaModel, true);
    expect(textCapitalization, 'TextCapitalization.characters');
    expect(keyboardAppearance, 'Brightness.dark');

    // Change the brightness to rebuild the widget
    // and re-attach to the IME.
    brightnessNotifier.value = Brightness.light;
    await tester.pump();

    // Ensure we use the values from the configuration,
    // updating only the keyboard appearance.
    expect(inputAction, 'TextInputAction.search');
    expect(inputType, 'TextInputType.number');
    expect(autocorrect, false);
    expect(enableSuggestions, false);
    expect(enableDeltaModel, true);
    expect(textCapitalization, 'TextCapitalization.characters');
    expect(keyboardAppearance, 'Brightness.light');
  });

  testWidgetsOnAllPlatforms('doesn\'t re-attach to IME if the configuration doesn\'t change', (tester) async {
    // Keeps track of how many times TextInput.setClient was called.
    int imeConnectionCount = 0;

    // Explicitly avoid using const to ensure that we have two
    // TextInputConfiguration instances with the same values.
    //
    // ignore: prefer_const_constructors
    final configuration1 = TextInputConfiguration(
      enableSuggestions: false,
      autocorrect: false,
      inputAction: TextInputAction.search,
      keyboardAppearance: Brightness.dark,
      inputType: TextInputType.number,
      enableDeltaModel: false,
    );
    // ignore: prefer_const_constructors
    final configuration2 = TextInputConfiguration(
      enableSuggestions: false,
      autocorrect: false,
      inputAction: TextInputAction.search,
      keyboardAppearance: Brightness.dark,
      inputType: TextInputType.number,
      enableDeltaModel: false,
    );

    final inputConfigurationNotifier = ValueNotifier(configuration1);

    // Pump a SuperTextField with an IME configuration with values
    // that differ from the defaults.
    await tester.pumpWidget(
      _buildScaffold(
        child: ValueListenableBuilder(
          valueListenable: inputConfigurationNotifier,
          builder: (context, inputConfiguration, child) {
            return SuperTextField(
              inputSource: TextInputSource.ime,
              imeConfiguration: inputConfiguration,
            );
          },
        ),
      ),
    );

    // Intercept the setClient message sent to the platform.
    tester
        .interceptChannel(SystemChannels.textInput.name) //
        .interceptMethod(
      'TextInput.setClient',
      (methodCall) {
        imeConnectionCount += 1;
        return null;
      },
    );

    // Tap to focus the text field and attach to the IME.
    await tester.placeCaretInSuperTextField(0);

    // Change the configuration instance to trigger a rebuild.
    inputConfigurationNotifier.value = configuration2;
    await tester.pump();

    // Ensure the connection was performed only once.
    expect(imeConnectionCount, 1);
  });

  group('SuperTextField on some bad Android software keyboards', () {
    testWidgetsOnAndroid('handles BACKSPACE key event instead of deletion for a collapsed selection', (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText('This is a text'),
      );
      await _pumpScaffoldForBuggyKeyboards(tester, controller: controller);

      // Focus the text field
      // TODO: change to use the robot when mobile is supported
      await tester.tapAt(tester.getCenter(find.byType(SuperTextField)));
      await tester.pump();

      // Place caret at This|. We don't put caret at the end of the text
      // to ensure we are not deleting always the last character
      controller.selection = const TextSelection.collapsed(offset: 4);
      await tester.pump();

      await tester.pressBackspace();

      // Ensure text is deleted
      expect(controller.text.toPlainText(), 'Thi is a text');
    });

    testWidgetsOnAndroid('handles BACKSPACE key event instead of deletion for a expanded selection', (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText('This is a text'),
      );
      await _pumpScaffoldForBuggyKeyboards(tester, controller: controller);

      // Focus the text field
      // TODO: change to use the robot when mobile is supported
      await tester.tapAt(tester.getCenter(find.byType(SuperTextField)));
      await tester.pump();

      // Selects ' text'
      controller.selection = const TextSelection(
        baseOffset: 9,
        extentOffset: 14,
      );
      await tester.pump();

      await tester.pressBackspace();

      // Ensure text is deleted
      expect(controller.text.toPlainText(), 'This is a');
    });
  });
}

// Based on experiments, the text is laid out as follows (at 320px wide):
//
//  (0)this text is long (18 - upstream)
// (18)enough to be (31 - upstream)
// (31)multiline in the (48 - upstream)
// (48)available space(63)
const _multilineLayoutText = 'this text is long enough to be multiline in the available space';

Future<void> _pumpEmptySuperTextField(WidgetTester tester) async {
  await _pumpSuperTextField(
    tester,
    AttributedTextEditingController(text: AttributedText('')),
  );
}

Future<void> _pumpSuperTextField(
  WidgetTester tester,
  AttributedTextEditingController controller, {
  FocusNode? focusNode,
  int? minLines,
  int? maxLines,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      // The Center allows the content to be smaller than the display
      home: Center(
        // This SizedBox, combined with the font size in the TextStyle,
        // determines the text line wrapping, which is critical for the
        // tests in this suite.
        child: SizedBox(
          width: 320,
          child: SuperTextField(
            focusNode: focusNode,
            textController: controller,
            inputSource: TextInputSource.ime,
            minLines: minLines,
            maxLines: maxLines,
            lineHeight: 18,
            textStyleBuilder: (_) {
              return const TextStyle(
                // This font size, combined with the layout width below, are
                // critical to determining the text line wrapping.
                fontSize: 18,
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // The following code prints the bounding box for every
  // character of text in the layout. You can use that info
  // to figure out where line breaks occur.
  // final textLayout = SuperTextFieldInspector.findProseTextLayout();
  // for (int i = 0; i < _multilineLayoutText.length; ++i) {
  //   print('$i: ${textLayout.getCharacterBox(TextPosition(offset: i))}');
  // }
}

Future<void> _pumpScaffoldForBuggyKeyboards(
  WidgetTester tester, {
  required AttributedTextEditingController controller,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 300),
          child: SuperTextField(
            textController: controller,
          ),
        ),
      ),
    ),
  );
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

/// An [AttributedTextEditingController] that uppon insertion replaces every character
/// but the last one with a "*".
///
/// Used to modify the text when we receive deltas from the IME, causing us to send the editing value
/// back to the IME.
class _ObscuringTextController extends AttributedTextEditingController {
  _ObscuringTextController({
    AttributedText? text,
  }) : super(text: text);

  @override
  void insertAtCaret({
    required String text,
    TextRange? newComposingRegion,
  }) {
    final attributedText = super.text;

    final textAfterInsertion = attributedText.insertString(
      textToInsert: text,
      startOffset: selection.extentOffset,
      applyAttributions: Set.from(composingAttributions),
    );

    // Replace everything but the last char with *.
    final updatedText = (''.padLeft(textAfterInsertion.length - 1, '*')) +
        textAfterInsertion.toPlainText().substring(textAfterInsertion.length - 1);

    final updatedSelection = _moveSelectionForInsertion(
      selection: selection,
      insertIndex: selection.extentOffset,
      newTextLength: text.length,
    );

    update(
      text: AttributedText(
        updatedText,
        textAfterInsertion.spans,
      ),
      selection: updatedSelection,
      composingRegion: newComposingRegion,
    );
  }

  // Copied from AttributedTextEditingController.
  TextSelection _moveSelectionForInsertion({
    required TextSelection selection,
    required int insertIndex,
    required int newTextLength,
  }) {
    int newBaseOffset = selection.baseOffset;
    if ((selection.baseOffset == insertIndex && selection.isCollapsed) || (selection.baseOffset > insertIndex)) {
      newBaseOffset = selection.baseOffset + newTextLength;
    }

    final newExtentOffset =
        selection.extentOffset >= insertIndex ? selection.extentOffset + newTextLength : selection.extentOffset;

    return TextSelection(
      baseOffset: newBaseOffset,
      extentOffset: newExtentOffset,
    );
  }
}
