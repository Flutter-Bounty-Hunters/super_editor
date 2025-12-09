import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_text_field_test.dart';
import 'package:super_text_layout/super_text_layout.dart';

void main() {
  group("SuperTextField", () {
    group("configures for", () {
      group("desktop", () {
        testWidgets("automatically", (tester) async {
          debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

          await tester.pumpWidget(
            _buildScaffold(
              child: const SuperTextField(),
            ),
          );

          expect(find.byType(SuperDesktopTextField), findsOneWidget);

          debugDefaultTargetPlatformOverride = null;
        });

        testWidgets("when requested", (tester) async {
          await tester.pumpWidget(
            _buildScaffold(
              child: const SuperTextField(
                configuration: SuperTextFieldPlatformConfiguration.desktop,
              ),
            ),
          );

          expect(find.byType(SuperDesktopTextField), findsOneWidget);
        });
      });

      group("android", () {
        testWidgets("automatically", (tester) async {
          debugDefaultTargetPlatformOverride = TargetPlatform.android;

          await tester.pumpWidget(
            _buildScaffold(
              child: const SuperTextField(),
            ),
          );

          expect(find.byType(SuperAndroidTextField), findsOneWidget);

          debugDefaultTargetPlatformOverride = null;
        });

        testWidgets("when requested", (tester) async {
          await tester.pumpWidget(
            _buildScaffold(
              child: const SuperTextField(
                configuration: SuperTextFieldPlatformConfiguration.android,
              ),
            ),
          );

          expect(find.byType(SuperAndroidTextField), findsOneWidget);
        });
      });

      group("iOS", () {
        testWidgets("automatically", (tester) async {
          debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

          await tester.pumpWidget(
            _buildScaffold(
              child: const SuperTextField(),
            ),
          );

          expect(find.byType(SuperIOSTextField), findsOneWidget);

          debugDefaultTargetPlatformOverride = null;
        });

        testWidgets("when requested", (tester) async {
          await tester.pumpWidget(
            _buildScaffold(
              child: const SuperTextField(
                configuration: SuperTextFieldPlatformConfiguration.iOS,
              ),
            ),
          );

          expect(find.byType(SuperIOSTextField), findsOneWidget);
        });
      });
    });

    group("on mobile", () {
      testWidgetsOnAndroid("configures inner textfield textInputAction for newline when it's multiline",
          (tester) async {
        await tester.pumpWidget(
          _buildScaffold(
            child: const SuperTextField(
              minLines: 10,
              maxLines: 10,
            ),
          ),
        );

        final innerTextField = tester.widget<SuperAndroidTextField>(find.byType(SuperAndroidTextField).first);

        // Ensure inner textfield action is configured to newline
        // so we are able to receive new lines
        expect(innerTextField.textInputAction, TextInputAction.newline);
      });

      testWidgetsOnIos("configures inner textfield textInputAction for newline when it's multiline", (tester) async {
        await tester.pumpWidget(
          _buildScaffold(
            child: const SuperTextField(
              minLines: 10,
              maxLines: 10,
            ),
          ),
        );

        final innerTextField = tester.widget<SuperIOSTextField>(find.byType(SuperIOSTextField).first);

        // Ensure inner textfield action is configured to newline
        // so we are able to receive new lines
        expect(innerTextField.textInputAction, TextInputAction.newline);
      });

      testWidgetsOnAndroid("configures inner textfield textInputAction for done when it's singleline", (tester) async {
        await tester.pumpWidget(
          _buildScaffold(
            child: const SuperTextField(
              minLines: 1,
              maxLines: 1,
            ),
          ),
        );

        final innerTextField = tester.widget<SuperAndroidTextField>(find.byType(SuperAndroidTextField).first);

        // Ensure inner textfield action is configured to done
        // because we should NOT receive new lines
        expect(innerTextField.textInputAction, TextInputAction.done);
      });

      testWidgetsOnIos("configures inner textfield textInputAction for done when it's singleline", (tester) async {
        await tester.pumpWidget(
          _buildScaffold(
            child: const SuperTextField(
              minLines: 1,
              maxLines: 1,
            ),
          ),
        );

        final innerTextField = tester.widget<SuperIOSTextField>(find.byType(SuperIOSTextField).first);

        // Ensure inner textfield action is configured to done
        // because we should NOT receive new lines
        expect(innerTextField.textInputAction, TextInputAction.done);
      });

      testWidgetsOnIos('applies keyboard appearance', (tester) async {
        await tester.pumpWidget(
          _buildScaffold(
            child: SuperTextField(
              textController: ImeAttributedTextEditingController(
                keyboardAppearance: Brightness.dark,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Holds the keyboard appearance sent to the platform.
        String? keyboardAppearance;

        // Intercept messages sent to the platform.
        tester.binding.defaultBinaryMessenger.setMockMessageHandler(SystemChannels.textInput.name, (message) async {
          final methodCall = const JSONMethodCodec().decodeMethodCall(message);
          if (methodCall.method == 'TextInput.setClient') {
            final params = methodCall.arguments[1] as Map;
            keyboardAppearance = params['keyboardAppearance'];
          }
          return null;
        });

        // Tap the text field to show the software keyboard.
        await tester.placeCaretInSuperTextField(0);

        // Ensure the given keyboardAppearance was applied.
        expect(keyboardAppearance, 'Brightness.dark');
      });

      testWidgetsOnIos('updates keyboard appearance', (tester) async {
        final controller = ImeAttributedTextEditingController(
          keyboardAppearance: Brightness.light,
        );

        await tester.pumpWidget(
          _buildScaffold(
            child: SuperTextField(
              textController: controller,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Holds the keyboard appearance sent to the platform.
        String? keyboardAppearance;

        // Intercept the setClient message sent to the platform.
        tester
            .interceptChannel(SystemChannels.textInput.name) //
            .interceptMethod(
          'TextInput.setClient',
          (methodCall) {
            final params = methodCall.arguments[1] as Map;
            keyboardAppearance = params['keyboardAppearance'];
            return null;
          },
        );

        // Tap the text field to show the software keyboard with the light appearance.
        await tester.placeCaretInSuperTextField(0);

        // Ensure the initial keyboardAppearance was applied.
        expect(keyboardAppearance, 'Brightness.light');

        // Change the keyboard appearance from light to dark.
        controller.updateTextInputConfiguration(
          viewId: 0,
          keyboardAppearance: Brightness.dark,
        );
        await tester.pump();

        // Ensure the given keyboardAppearance was applied.
        expect(keyboardAppearance, 'Brightness.dark');
      });

      testWidgetsOnIos('updates keyboard appearance when not attached to IME', (tester) async {
        final controller = ImeAttributedTextEditingController(
          keyboardAppearance: Brightness.light,
        );

        await tester.pumpWidget(
          _buildScaffold(
            child: SuperTextField(
              textController: controller,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Holds the keyboard appearance sent to the platform.
        String? keyboardAppearance;

        // Intercept the setClient message sent to the platform.
        tester
            .interceptChannel(SystemChannels.textInput.name) //
            .interceptMethod(
          'TextInput.setClient',
          (methodCall) {
            final params = methodCall.arguments[1] as Map;
            keyboardAppearance = params['keyboardAppearance'];
            return null;
          },
        );

        // Change the keyboard appearance from light to dark while detached from IME.
        controller.updateTextInputConfiguration(
          viewId: 0,
          keyboardAppearance: Brightness.dark,
        );

        // Tap the text field to show the software keyboard.
        await tester.placeCaretInSuperTextField(0);

        // Ensure the initial keyboardAppearance was dark.
        expect(keyboardAppearance, 'Brightness.dark');
      });
    });

    group("selection", () {
      testWidgetsOnAllPlatforms("is inserted automatically when the field is initialized with focus", (tester) async {
        await tester.pumpWidget(
          _buildScaffold(
            child: SuperTextField(
              focusNode: FocusNode()..requestFocus(),
            ),
          ),
        );
        await tester.pump();

        expect(_isCaretPresent(tester), isTrue);
      });

      testWidgetsOnAllPlatforms("is inserted automatically when the field is given focus", (tester) async {
        final focusNode = FocusNode();
        await tester.pumpWidget(
          _buildScaffold(
            child: SuperTextField(
              focusNode: focusNode,
            ),
          ),
        );
        await tester.pump();

        expect(_isCaretPresent(tester), isFalse);

        focusNode.requestFocus();
        await tester.pumpAndSettle();

        expect(_isCaretPresent(tester), isTrue);
      });

      testWidgetsOnAllPlatforms(
          "is inserted automatically when the field is initialized with a focused node used by another widget",
          (tester) async {
        final node = FocusNode()..requestFocus();

        await tester.pumpWidget(
          _buildScaffold(
            child: Focus(
              focusNode: node,
              child: const SizedBox.shrink(),
            ),
          ),
        );

        // Pumps a second widget tree, to simulate switching the FocusNode
        // from one widget to another.
        await tester.pumpWidget(
          _buildScaffold(
            child: SuperTextField(
              focusNode: node,
            ),
          ),
        );
        await tester.pump();

        expect(_isCaretPresent(tester), isTrue);
      });
    });

    group('padding', () {
      testWidgetsOnAllPlatforms('is applied when configured', (tester) async {
        await tester.pumpWidget(
          _buildScaffold(
            child: const SuperTextField(
              padding: EdgeInsets.fromLTRB(5, 10, 15, 20),
              minLines: 1,
              maxLines: 2,
            ),
          ),
        );

        await tester.pumpAndSettle();

        final textFieldRect = tester.getRect(find.byType(SuperTextField));
        final contentRect = tester.getRect(find.byType(SuperText));

        // Ensure padding was applied.
        expect(contentRect.left - textFieldRect.left, 5);
        expect(contentRect.top - textFieldRect.top, 10);
        expect(textFieldRect.right - contentRect.right, 15);
        expect(textFieldRect.bottom - contentRect.bottom, 20);
      });
    });

    testWidgetsOnAllPlatforms('recalculates its viewport height when text changes for text smaller than maxLines',
        (tester) async {
      final controller = AttributedTextEditingController();

      await tester.pumpWidget(
        _buildScaffold(
          child: SuperTextField(
            minLines: 1,
            maxLines: 10,
            textController: controller,
          ),
        ),
      );

      // Change the text so the content height is greater
      // than the initial content height.
      controller.text = AttributedText(
        """
This is
a
multi-line
SuperTextField
""",
      );
      await tester.pumpAndSettle();

      final textSize = tester.getSize(find.byType(SuperText));
      final textFieldSize = tester.getSize(find.byType(SuperTextField));

      // Ensure the text field height is big enough to display the whole content.
      expect(textFieldSize.height, greaterThanOrEqualTo(textSize.height));
    });

    testWidgetsOnAllPlatforms('recalculates its viewport height when text changes for text bigger than maxLines',
        (tester) async {
      final controller = AttributedTextEditingController();

      await tester.pumpWidget(
        _buildScaffold(
          child: SuperTextField(
            minLines: 1,
            maxLines: 2,
            textController: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFieldSizeBefore = tester.getSize(find.byType(SuperTextField));

      // Change the text, so the content height is greater
      // than the initial content height.
      controller.text = AttributedText(
        """
This is
a
multi-line
SuperTextField
""",
      );
      await tester.pumpAndSettle();

      // Ensure the text field height has increased.
      expect(tester.getSize(find.byType(SuperTextField)).height, greaterThan(textFieldSizeBefore.height));
    });
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

bool _isCaretPresent(WidgetTester tester) {
  final caretMatches = find.byType(TextLayoutCaret).evaluate();
  if (caretMatches.isEmpty) {
    return false;
  }
  final caretState = (caretMatches.single as StatefulElement).state as TextLayoutCaretState;
  return caretState.isCaretPresent;
}
