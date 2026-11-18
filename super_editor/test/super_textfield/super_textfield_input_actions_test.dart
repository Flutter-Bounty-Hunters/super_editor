import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group("SuperTextField input actions", () {
    testWidgetsOnMobile("unfocus on DONE", (tester) async {
      FocusNode focusNode = FocusNode();

      await _pumpSingleFieldTestApp(tester, focusNode: focusNode);

      // Focus SuperTextField. This should show the software keyboard
      focusNode.requestFocus();
      await tester.pump();

      // Ensure we have focus
      expect(focusNode.hasFocus, true);

      // Simulate a tap at the action button
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Ensure focus was removed
      expect(focusNode.hasFocus, false);
    });

    testWidgetsOnMobile("moves focus to next focusable item on NEXT", (tester) async {
      FocusNode focusNodeFirstField = FocusNode();
      FocusNode focusNodeSecondField = FocusNode();

      // We use a widget tree with three textfields because TextInputAction.previous
      // moves focus to the last focusable item in the scope when the first item is focused
      await _pumpTripleFieldTestApp(
        tester,
        focusNodeFirstField: focusNodeFirstField,
        focusNodeSecondField: focusNodeSecondField,
      );

      // Focus first field
      focusNodeFirstField.requestFocus();
      await tester.pump();

      // Ensure we have focus
      expect(focusNodeFirstField.hasFocus, true);

      // Simulate a tap at the action button
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();

      // Ensure focus has moved to next field
      expect(focusNodeSecondField.hasFocus, true);
    });

    testWidgetsOnMobile("moves focus to previous focusable item on PREVIOUS", (tester) async {
      FocusNode focusNodeFirstField = FocusNode();
      FocusNode focusNodeSecondField = FocusNode();

      // We use a widget tree with three textfields because TextInputAction.next
      // moves focus to the first focusable item in the scope when the last item is focused
      await _pumpTripleFieldTestApp(
        tester,
        focusNodeFirstField: focusNodeFirstField,
        focusNodeSecondField: focusNodeSecondField,
      );

      // Focus second field
      focusNodeSecondField.requestFocus();
      await tester.pump();

      // Ensure we have focus
      expect(focusNodeSecondField.hasFocus, true);

      // Simulate a tap at the action button
      await tester.testTextInput.receiveAction(TextInputAction.previous);
      await tester.pump();

      // Ensure focus has moved to next field
      expect(focusNodeFirstField.hasFocus, true);
    });

    testWidgetsOnMobile("unfocus on DONE when the controller was used by a removed field", (tester) async {
      final textController = ImeAttributedTextEditingController();

      // Show a text field, and then remove it, but keep its controller.
      await _pumpSingleFieldTestApp(tester, focusNode: FocusNode(), textController: textController);
      await tester.pumpWidget(const SizedBox());

      // Show a new text field with the same controller.
      final focusNode = FocusNode();
      await _pumpSingleFieldTestApp(tester, focusNode: focusNode, textController: textController);

      // Focus the new text field.
      focusNode.requestFocus();
      await tester.pump();

      // Ensure we have focus
      expect(focusNode.hasFocus, true);

      // Simulate a tap at the action button
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Ensure focus was removed
      expect(
        focusNode.hasFocus,
        false,
        reason: 'The DONE action should be handled by the new text field, not by the removed one',
      );
    });

    group('with custom onPerformActionPressed callback', () {
      testWidgetsOnMobile("does nothing on DONE", (tester) async {
        FocusNode focusNode = FocusNode();
        bool callbackCalled = false;

        ImeAttributedTextEditingController textController = ImeAttributedTextEditingController()
          ..onPerformActionPressed = (action) {
            callbackCalled = true;
          };

        await _pumpSingleFieldTestApp(
          tester,
          focusNode: focusNode,
          textController: textController,
        );

        // Focus SuperTextField.
        focusNode.requestFocus();
        await tester.pump();

        // Ensure we have focus
        expect(focusNode.hasFocus, true);

        // Simulate a tap at the action button
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();

        // Ensure our callback was called
        expect(callbackCalled, true);

        // Ensure we still have focus
        expect(focusNode.hasFocus, true);
      });

      testWidgetsOnMobile("does nothing on NEXT", (tester) async {
        FocusNode focusNode = FocusNode();
        bool callbackCalled = false;

        ImeAttributedTextEditingController textController = ImeAttributedTextEditingController()
          ..onPerformActionPressed = (action) {
            callbackCalled = true;
          };

        await _pumpTripleFieldTestApp(
          tester,
          focusNodeFirstField: focusNode,
          textControllerFirstField: textController,
        );

        // Focus first field.
        focusNode.requestFocus();
        await tester.pump();

        // Ensure we have focus
        expect(focusNode.hasFocus, true);

        // Simulate a tap at the action button
        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pump();

        // Ensure our callback was called
        expect(callbackCalled, true);

        // Ensure focus is still on first field
        expect(focusNode.hasFocus, true);
      });

      testWidgetsOnMobile("does nothing on PREVIOUS", (tester) async {
        FocusNode focusNode = FocusNode();
        bool callbackCalled = false;

        ImeAttributedTextEditingController textController = ImeAttributedTextEditingController()
          ..onPerformActionPressed = (action) {
            callbackCalled = true;
          };

        await _pumpTripleFieldTestApp(
          tester,
          focusNodeSecondField: focusNode,
          textControllerSecondField: textController,
        );

        // Focus second field
        focusNode.requestFocus();
        await tester.pump();

        // Ensure we have focus
        expect(focusNode.hasFocus, true);

        // Simulate a tap at the action button
        await tester.testTextInput.receiveAction(TextInputAction.previous);
        await tester.pump();

        // Ensure our callback was called
        expect(callbackCalled, true);

        // Ensure focus is still on second field
        expect(focusNode.hasFocus, true);
      });
    });
  });
}

Future<void> _pumpSingleFieldTestApp(
  WidgetTester tester, {
  required FocusNode focusNode,
  ImeAttributedTextEditingController? textController,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          child: SuperTextField(
            focusNode: focusNode,
            textController: textController,
            lineHeight: 16,
          ),
        ),
      ),
    ),
  );
}

Future<void> _pumpTripleFieldTestApp(
  WidgetTester tester, {
  FocusNode? focusNodeFirstField,
  FocusNode? focusNodeSecondField,
  FocusNode? focusNodeThirdField,
  ImeAttributedTextEditingController? textControllerFirstField,
  ImeAttributedTextEditingController? textControllerSecondField,
  ImeAttributedTextEditingController? textControllerThirdField,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            SizedBox(
              width: 300,
              child: SuperTextField(
                focusNode: focusNodeFirstField,
                textController: textControllerFirstField,
                lineHeight: 16,
              ),
            ),
            SizedBox(
              width: 300,
              child: SuperTextField(
                focusNode: focusNodeSecondField,
                textController: textControllerSecondField,
                lineHeight: 16,
              ),
            ),
            SizedBox(
              width: 300,
              child: SuperTextField(
                focusNode: focusNodeThirdField,
                textController: textControllerThirdField,
                lineHeight: 16,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
