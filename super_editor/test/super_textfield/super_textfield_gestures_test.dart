import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_text_field_test.dart';

void main() {
  group('SuperTextField gestures', () {
    group('tapping in empty space places the caret at the end of the text', () {
      testWidgetsOnMobile("when the field does not have focus", (tester) async {
        await _pumpTestApp(tester);

        // Tap in a place without text
        await tester.tapAt(tester.getBottomRight(find.byType(SuperTextField)) - const Offset(10, 10));
        await tester.pumpAndSettle();

        // Ensure selection is at the end of the text
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 3),
        );
      });

      testWidgetsOnMobile("when the field already has focus", (tester) async {
        await _pumpTestApp(tester);

        // Tap in a place containing text
        await tester.tapAt(tester.getTopLeft(find.byType(SuperTextField)));
        // Without this 'delay' onTapDown is not called the second time
        await tester.pumpAndSettle(const Duration(milliseconds: 200));

        // Tap in a place without text
        await tester.tapAt(tester.getBottomRight(find.byType(SuperTextField)) - const Offset(10, 10));
        await tester.pumpAndSettle();

        // Ensure selection is at the end of the text
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 3),
        );
      });
    });

    group('tapping on padding places caret', () {
      testWidgetsOnAllPlatforms('on the left side', (tester) async {
        await _pumpTestApp(
          tester,
          padding: const EdgeInsets.only(left: 20),
        );

        final finder = find.byType(SuperTextField);
        // Tap at the left side of the text field, at the vertical center.
        await tester.tapAt(tester.getTopLeft(finder) + Offset(1, tester.getSize(finder).height / 2));
        await tester.pumpAndSettle();

        // Ensure caret was placed.
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 0),
        );
      });

      testWidgetsOnAllPlatforms('on the top', (tester) async {
        /// Pump a center-aligned text field so we can tap at the middle of the text.
        await _pumpTestApp(
          tester,
          padding: const EdgeInsets.only(top: 20),
          textAlign: TextAlign.center,
        );

        final finder = find.byType(SuperTextField);
        // Tap at the top of the text field, at the horizontal center.
        // On linux, tapping exactly at middle is placing caret at offset 1.
        await tester.tapAt(tester.getTopLeft(finder) + Offset((tester.getSize(finder).width / 2) + 1, 1));
        await tester.pumpAndSettle();

        // Ensure caret was placed.
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 2),
        );
      });

      testWidgetsOnAllPlatforms('on the bottom', (tester) async {
        /// Pump a center-aligned text field so we can tap at the middle of the text.
        await _pumpTestApp(
          tester,
          padding: const EdgeInsets.only(bottom: 20),
          textAlign: TextAlign.center,
        );

        final finder = find.byType(SuperTextField);
        // Tap at the bottom of the text field, at the horizontal center.
        // On linux, tapping exactly at middle is placing caret at offset 1.
        await tester.tapAt(tester.getBottomRight(finder) - Offset((tester.getSize(finder).width / 2) - 1, 1));
        await tester.pumpAndSettle();

        // Ensure caret was placed.
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 2),
        );
      });

      testWidgetsOnAllPlatforms('on the right side', (tester) async {
        await _pumpTestApp(
          tester,
          padding: const EdgeInsets.only(right: 20),
        );

        final finder = find.byType(SuperTextField);
        // Tap at the right side of the text field, at the vertical center.
        await tester.tapAt(tester.getBottomRight(finder) - Offset(1, tester.getSize(finder).height / 2));
        await tester.pumpAndSettle();

        // Ensure caret was placed.
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 3),
        );
      });
    });

    group('tapping in an area containing text places the caret at tap position', () {
      testWidgetsOnMobile("when the field does not have focus", (tester) async {
        await _pumpTestApp(tester);

        // Tap in a place containing text
        await tester.tapAt(tester.getTopLeft(find.byType(SuperTextField)));
        await tester.pumpAndSettle();

        // Ensure selection is at the beginning of the text
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 0),
        );
      });

      testWidgetsOnMobile("when the field already has focus", (tester) async {
        await _pumpTestApp(tester);

        // Tap in a place without text
        await tester.tapAt(tester.getBottomRight(find.byType(SuperTextField)) - const Offset(10, 10));
        // Without this 'delay' onTapDown is not called the second time
        await tester.pumpAndSettle(const Duration(milliseconds: 200));

        // Tap in a place containing text
        await tester.tapAt(tester.getTopLeft(find.byType(SuperTextField)));
        await tester.pumpAndSettle();

        // Ensure selection is at the beginning of the text
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 0),
        );
      });

      testWidgetsOnAllPlatforms("when a single-line text field contains scrollable text", (tester) async {
        // The purpose of this test is to ensure that when placing the caret in a scrollable
        // single-line text field (a text field with more text than can fit), the text field
        // doesn't erratically move the caret somewhere else due to buggy scroll calculations.
        await _pumpSingleLineTextField(
          tester,
          controller: AttributedTextEditingController(
            // Display enough text to ensure the text field is scrollable.
            text: AttributedText(
              "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus sed sagittis urna.",
            ),
          ),
        );

        // Ensure we begin with no scroll offset.
        expect(SuperTextFieldInspector.isScrolledToBeginning(), isTrue);

        // Place the caret at an arbitrary offset other than zero (so that we can
        // catch any bug where the caret ends up being placed too far upstream after
        // the tap).
        await tester.placeCaretInSuperTextField(10);

        // Ensure the caret was placed at the desired text position.
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 10),
        );

        // Ensure that placing the caret didn't cause the scroll view to jump anywhere.
        expect(SuperTextFieldInspector.isScrolledToBeginning(), isTrue);
      });
    });

    group("on desktop", () {
      testWidgetsOnDesktop("tap down focuses the field", (tester) async {
        await _pumpTestApp(tester);

        // Tap down, but don't release.
        final gesture = await tester.startGesture(tester.getTopLeft(find.byType(SuperTextField)));
        await tester.pumpAndSettle();

        // Ensure the field has a selection
        expect(SuperTextFieldInspector.findSelection()!.isValid, true);

        // Normally, `gesture.removePointer()` would be placed in a teardown
        // because we don't really care about removing the pointer. However,
        // in this case, when the pointer is removed, it triggers the field's
        // "pan cancel", which throws a null-pointer exception because the
        // widget tree is being torn down and a `GlobalKey` is used. The only
        // way I found to fix this issue was to run both an `up()` and
        // `removePointer()` here.
        await gesture.up();
        await gesture.removePointer();
      });

      testWidgetsOnDesktop("scrolls the content when dragging with trackpad down", (tester) async {
        final controller = AttributedTextEditingController(
          text: AttributedText('''
SuperTextField with a
content that spans
multiple lines
of text to test
scrolling with 
a trackpad
'''),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 300),
                child: SuperTextField(
                  textController: controller,
                  maxLines: 2,
                ),
              ),
            ),
          ),
        );

        // Double tap to select "SuperTextField".
        await tester.doubleTapAtSuperTextField(0);
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection(baseOffset: 0, extentOffset: 14),
        );

        // Find text field scrollable.
        final scrollState = tester.state<ScrollableState>(find.descendant(
          of: find.byType(SuperTextField),
          matching: find.byType(Scrollable),
        ));

        // Ensure the textfield didn't start scrolled.
        expect(scrollState.position.pixels, 0.0);

        // Simulate the user starting a gesture with two fingers
        // somewhere close to the beginning of the text.
        final gesture = await tester.startGesture(
          tester.getTopLeft(find.byType(SuperTextField)) + const Offset(10, 10),
          kind: PointerDeviceKind.trackpad,
        );
        await tester.pump();

        // Move a distance big enough to ensure a pan gesture.
        await gesture.moveBy(const Offset(0, kPanSlop));
        await tester.pump();

        // Drag up.
        await gesture.moveBy(const Offset(0, -300));
        await tester.pump();

        // Ensure the content scrolled to the end of the content.
        expect(scrollState.position.pixels, moreOrLessEquals(80.0));

        // Ensure that the selection didn't change.
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection(baseOffset: 0, extentOffset: 14),
        );
      });

      testWidgetsOnDesktop("scrolls the content when dragging with trackpad up", (tester) async {
        final controller = AttributedTextEditingController(
          text: AttributedText('''
SuperTextField with a
content that spans
multiple lines
of text to test
scrolling with
a trackpad
'''),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 300),
                child: SuperTextField(
                  textController: controller,
                  maxLines: 2,
                ),
              ),
            ),
          ),
        );

        // Double tap to select "SuperTextField".
        await tester.doubleTapAtSuperTextField(0);
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection(baseOffset: 0, extentOffset: 14),
        );

        // Find text field scrollable.
        final scrollState = tester.state<ScrollableState>(find.descendant(
          of: find.byType(SuperTextField),
          matching: find.byType(Scrollable),
        ));

        // Jump to the end of the textfield.
        scrollState.position.jumpTo(scrollState.position.maxScrollExtent);
        await tester.pump();

        // Simulate the user starting a gesture with two fingers
        // somewhere close to the end of the text.
        final gesture = await tester.startGesture(
          tester.getBottomLeft(find.byType(SuperTextField)) + const Offset(10, -1),
          kind: PointerDeviceKind.trackpad,
        );
        await tester.pump();

        // Move a distance big enough to ensure a pan gesture.
        await gesture.moveBy(const Offset(0, kPanSlop));
        await tester.pump();

        // Drag down.
        await gesture.moveBy(const Offset(0, 300));
        await tester.pump();

        // Ensure the content scrolled to the beginning of the content.
        expect(scrollState.position.pixels, 0.0);

        // Ensure that the selection didn't change.
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection(baseOffset: 0, extentOffset: 14),
        );
      });

      testWidgetsOnDesktop("scrolls the content when dragging the scrollbar down", (tester) async {
        final controller = AttributedTextEditingController(
          text: AttributedText('''
SuperTextField with a
content that spans
multiple lines
of text to test
scrolling with 
a scrollbar
'''),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 300),
                child: SuperTextField(
                  textController: controller,
                  maxLines: 4,
                ),
              ),
            ),
          ),
        );

        // Double tap to select "SuperTextField".
        await tester.doubleTapAtSuperTextField(0);
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection(baseOffset: 0, extentOffset: 14),
        );

        // Find text field scrollable.
        final scrollState = tester.state<ScrollableState>(find.descendant(
          of: find.byType(SuperTextField),
          matching: find.byType(Scrollable),
        ));

        // Ensure the textfield didn't start scrolled.
        expect(scrollState.position.pixels, 0.0);

        // Find the approximate position of the scrollbar thumb.
        final thumbLocation = tester.getTopRight(find.byType(SuperTextField)) + const Offset(-10, 10);

        // Hover to make the thumb visible with a duration long enough to run the fade in animation.
        final testPointer = TestPointer(1, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(testPointer.hover(thumbLocation, timeStamp: const Duration(seconds: 1)));
        await tester.pumpAndSettle();

        // Press the thumb.
        await tester.sendEventToBinding(testPointer.down(thumbLocation));
        await tester.pump(kTapMinTime);

        // Move the thumb down a distance equals to the max scroll extent.
        await tester.sendEventToBinding(testPointer.move(thumbLocation + const Offset(0, 48)));
        await tester.pump();

        // Release the pointer.
        await tester.sendEventToBinding(testPointer.up());
        await tester.pump();

        // Ensure the content scrolled to the end of the content.
        expect(scrollState.position.pixels, moreOrLessEquals(scrollState.position.maxScrollExtent));

        // Ensure that the selection didn't change.
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection(baseOffset: 0, extentOffset: 14),
        );
      });

      testWidgetsOnDesktop("scrolls the content when dragging the scrollbar up", (tester) async {
        final controller = AttributedTextEditingController(
          text: AttributedText('''
SuperTextField with a
content that spans
multiple lines
of text to test
scrolling with 
a scrollbar
'''),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 300),
                child: SuperTextField(
                  textController: controller,
                  maxLines: 4,
                ),
              ),
            ),
          ),
        );

        // Double tap to select "SuperTextField".
        await tester.doubleTapAtSuperTextField(0);
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection(baseOffset: 0, extentOffset: 14),
        );

        // Find text field scrollable.
        final scrollState = tester.state<ScrollableState>(find.descendant(
          of: find.byType(SuperTextField),
          matching: find.byType(Scrollable),
        ));

        // Jump to the end of the textfield.
        scrollState.position.jumpTo(scrollState.position.maxScrollExtent);
        await tester.pump();

        // Find the approximate position of the scrollbar thumb.
        final thumbLocation = tester.getBottomRight(find.byType(SuperTextField)) - const Offset(10, 10);

        // Hover to make the thumb visible with a duration long enough to run the fade in animation.
        final testPointer = TestPointer(1, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(testPointer.hover(thumbLocation, timeStamp: const Duration(seconds: 1)));
        await tester.pumpAndSettle();

        // Press the thumb.
        await tester.sendEventToBinding(testPointer.down(thumbLocation));
        await tester.pump(kTapMinTime);

        // Move the thumb up a distance equals to the max scroll extent.
        await tester.sendEventToBinding(testPointer.move(thumbLocation - const Offset(0, 48)));
        await tester.pump();

        // Release the pointer.
        await tester.sendEventToBinding(testPointer.up());
        await tester.pump();

        // Ensure the content scrolled to the beginning of the content.
        expect(scrollState.position.pixels, 0.0);

        // Ensure that the selection didn't change.
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection(baseOffset: 0, extentOffset: 14),
        );
      });
    });

    group("on mobile", () {
      testWidgetsOnMobile("tap down does NOT focus the field", (tester) async {
        await _pumpTestApp(tester);

        // Tap down, but don't release.
        final gesture = await tester.startGesture(tester.getTopLeft(find.byType(SuperTextField)));
        addTearDown(() => gesture.removePointer());
        await tester.pumpAndSettle();

        // Ensure the field has no selection
        expect(SuperTextFieldInspector.findSelection()!.isValid, false);
      });

      testWidgetsOnMobile("tap down and drag does NOT focus the field", (tester) async {
        await _pumpTestApp(tester);

        // Tap down, start a pan, then drag up.
        final gesture = await tester.startGesture(tester.getTopLeft(find.byType(SuperTextField)));
        addTearDown(() => gesture.removePointer());
        await tester.pumpAndSettle();
        await gesture.moveBy(const Offset(2, 2));
        await tester.pumpAndSettle();
        await gesture.moveBy(const Offset(0, -300));
        await tester.pumpAndSettle();

        // Ensure the field has no selection
        expect(SuperTextFieldInspector.findSelection()!.isValid, false);
      });

      testWidgetsOnMobile("tap up focuses the field", (tester) async {
        await _pumpTestApp(tester);

        // Tap down and up.
        await tester.tapAt(tester.getTopLeft(find.byType(SuperTextField)));
        await tester.pumpAndSettle();

        // Ensure the field now has a selection.
        expect(SuperTextFieldInspector.findSelection()!.isValid, true);
      });

      testWidgetsOnMobile("tap down in focused field does nothing", (tester) async {
        await _pumpTestApp(tester);

        // Tap in empty space to place the caret at the end of the text.
        await tester.tapAt(tester.getBottomRight(find.byType(SuperTextField)) - const Offset(10, 10));
        // Without this 'delay' onTapDown is not called the second time
        await tester.pumpAndSettle(const Duration(milliseconds: 200));
        expect(SuperTextFieldInspector.findSelection()!.extent.offset, greaterThan(0));

        // Tap DOWN at beginning of text to move the caret.
        final gesture = await tester.startGesture(tester.getTopLeft(find.byType(SuperTextField)));
        addTearDown(() => gesture.removePointer());
        await tester.pumpAndSettle();

        // Ensure the caret didn't move.
        expect(SuperTextFieldInspector.findSelection()!.extent.offset, 3);
      });

      testWidgetsOnMobile("tap up in focused field moves the caret", (tester) async {
        await _pumpTestApp(tester);

        // Tap in empty space to place the caret at the end of the text.
        await tester.tapAt(tester.getBottomRight(find.byType(SuperTextField)) - const Offset(10, 10));
        // Without this 'delay' onTapDown is not called the second time.
        await tester.pumpAndSettle(const Duration(milliseconds: 200));
        expect(SuperTextFieldInspector.findSelection()!.extent.offset, greaterThan(0));

        // Tap DOWN at beginning of text to move the caret.
        final gesture = await tester.startGesture(tester.getTopLeft(find.byType(SuperTextField)));
        await tester.pump();
        await gesture.up();
        await tester.pump(kTapTimeout);

        // Ensure the caret moved to the beginning of the text.
        expect(SuperTextFieldInspector.findSelection()!.extent.offset, 0);
      });

      // mobile only because precise input (mouse) doesn't use touch slop
      testWidgetsOnMobile("MediaQuery gesture settings are respected", (tester) async {
        bool horizontalDragStartCalled = false;
        final controller = AttributedTextEditingController(
          text: AttributedText('a b c'),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GestureDetector(
                onHorizontalDragStart: (d) {
                  horizontalDragStartCalled = true;
                },
                child: Builder(builder: (context) {
                  // Custom gesture settings that ensure same value for touchSlop
                  // and panSlop
                  final data = MediaQuery.of(context).copyWith(
                    gestureSettings: const _GestureSettings(
                      panSlop: 18,
                      touchSlop: 18,
                    ),
                  );
                  return MediaQuery(
                    data: data,
                    child: SuperTextField(
                      textController: controller,
                    ),
                  );
                }),
              ),
            ),
          ),
        );

        // Tap down and up so the field is focused.
        await tester.placeCaretInSuperTextField(0);

        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 0),
        );

        // The following gesture should trigger the selection PanGestureRecognizer instead
        // of the HorizontalDragGestureRecognizer, thereby moving the caret.
        final gesture = await tester.startGesture(tester.getTopLeft(find.byType(SuperTextField)));
        addTearDown(() => gesture.removePointer());
        // This first move is just enough to surpass the touch slop, which then
        // triggers _onPanStart, but doesn't impact the text selection.
        await gesture.moveBy(const Offset(19, 0));
        // This second move runs _onPanUpdate, which does change the text selection.
        await gesture.moveBy(const Offset(1, 0));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(horizontalDragStartCalled, isFalse);
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 1),
        );

        // Pump an update with a larger pan slop.
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GestureDetector(
                onHorizontalDragStart: (d) {
                  horizontalDragStartCalled = true;
                },
                child: Builder(builder: (context) {
                  // Gesture settings that mimic flutter default where
                  // panSlop = 2x touchSlop
                  final data = MediaQuery.of(context).copyWith(
                    gestureSettings: const _GestureSettings(
                      touchSlop: 18,
                      panSlop: 36,
                    ),
                  );
                  return MediaQuery(
                    data: data,
                    child: SuperTextField(
                      textController: controller,
                    ),
                  );
                }),
              ),
            ),
          ),
        );

        // The following gesture, which moves as much as the previous gesture, should
        // have no effect on the selection because the pan slop was increased.
        final gesture2 = await tester.startGesture(tester.getTopLeft(find.byType(SuperTextField)));
        addTearDown(() => gesture2.removePointer());
        await gesture2.moveBy(const Offset(19, 0));
        await gesture2.up();
        await tester.pumpAndSettle();

        // Ensure that the selection didn't change because the larger pan slop prevented
        // the selection pan from winning in the gesture arena. Also, ensure that because
        // the selection pan didn't take the gesture, the horizontal drag detector won
        // out, instead.
        expect(horizontalDragStartCalled, isTrue);
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 1),
        );
      });

      testWidgetsOnMobile("tap up shows the keyboard if the field already has focus", (tester) async {
        await _pumpTestApp(tester);

        bool isShowKeyboardCalled = false;

        // Tap down and up so the field is focused.
        await tester.tapAt(tester.getTopLeft(find.byType(SuperTextField)));
        await tester.pumpAndSettle();

        // Intercept messages sent to the platform.
        tester.binding.defaultBinaryMessenger.setMockMessageHandler(SystemChannels.textInput.name, (message) async {
          final methodCall = const JSONMethodCodec().decodeMethodCall(message);
          if (methodCall.method == "TextInput.show") {
            isShowKeyboardCalled = true;
          }
          return null;
        });

        // Avoid a double tap.
        await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 1));

        // Tap down and up again.
        await tester.tapAt(tester.getTopLeft(find.byType(SuperTextField)));
        await tester.pumpAndSettle();

        // Ensure we requested the keyboard to the platform
        expect(isShowKeyboardCalled, true);
      });

      testWidgetsOnIos("tap up attaches to IME if the field already has focus", (tester) async {
        final controller = ImeAttributedTextEditingController();

        await _pumpTestApp(tester, controller: controller);

        // Tap down and up so the field is focused.
        await tester.tap(find.byType(SuperTextField));
        await tester.pumpAndSettle();
        // Avoid a double tap.
        await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 1));

        // Ensure we are connected.
        expect(controller.isAttachedToIme, true);

        // Disconnect from IME.
        // In a real app this could happen when the user taps outside the field
        // or clicks on the OK button of the software keyboard.
        controller.detachFromIme();
        await tester.pumpAndSettle();

        // Ensure we are not connected.
        expect(controller.isAttachedToIme, false);

        // Tap down and up again.
        await tester.tap(find.byType(SuperTextField));
        await tester.pumpAndSettle();

        // Ensure we are connected again.
        expect(controller.isAttachedToIme, true);
      });

      testWidgetsOnMobile("tap up does not shows the toolbar if the field does not have focus", (tester) async {
        await _pumpTestAppWithFakeToolbar(tester);

        // Tap down and up so the field is focused.
        await tester.tapAt(tester.getTopLeft(find.byKey(_textFieldKey)));
        await tester.pumpAndSettle();

        // Ensure the toolbar isn't visible.
        expect(find.byKey(_popoverToolbarKey), findsNothing);
      });

      testWidgetsOnIos("tap up shows the toolbar if the field already has focus", (tester) async {
        await _pumpTestAppWithFakeToolbar(tester);

        // Tap down and up so the field is focused.
        await tester.tapAt(tester.getTopLeft(find.byKey(_textFieldKey)));
        await tester.pumpAndSettle();

        // Ensure the toolbar isn't visible.
        expect(find.byKey(_popoverToolbarKey), findsNothing);

        // Avoid a double tap.
        await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 1));

        // Tap down and up again.
        await tester.tapAt(tester.getTopLeft(find.byKey(_textFieldKey)));
        await tester.pumpAndSettle();

        // Ensure the toolbar is visible.
        expect(find.byKey(_popoverToolbarKey), findsOneWidget);
      });

      testWidgetsOnAndroid("tap up does not shows the toolbar if the field already has focus", (tester) async {
        await _pumpTestAppWithFakeToolbar(tester);

        // Tap down and up so the field is focused.
        await tester.tapAt(tester.getTopLeft(find.byKey(_textFieldKey)));
        await tester.pumpAndSettle();

        // Ensure the toolbar isn't visible.
        expect(find.byKey(_popoverToolbarKey), findsNothing);

        // Avoid a double tap.
        await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 1));

        // Tap down and up again.
        await tester.tapAt(tester.getTopLeft(find.byKey(_textFieldKey)));
        await tester.pumpAndSettle();

        // Ensure the toolbar is visible.
        expect(find.byKey(_popoverToolbarKey), findsNothing);
      });
    });

    testWidgetsOnAllPlatforms("loses focus when user taps outside in a TapRegion", (tester) async {
      // Note: the our test scaffold in this suite includes a TapRegion
      // that removes focus from the field when tapping outside. This test
      // depends upon that TapRegion.
      await _pumpTestApp(tester);
      await tester.pumpAndSettle();

      // Give the text field focus.
      await tester.tapAt(tester.getCenter(find.byType(SuperTextField)));
      await tester.pump(kTapMinTime);

      // Ensure that we start with focus.
      expect(
        SuperTextFieldInspector.findSelection()!.extentOffset,
        greaterThan(-1),
      );

      // Tap outside the text field.
      await tester.tapAt(tester.getCenter(find.byType(Scaffold)));
      await tester.pump(kTapMinTime);
      await tester.pumpAndSettle();

      // Ensure that focus is gone.
      expect(
        SuperTextFieldInspector.findSelection(),
        const TextSelection.collapsed(offset: -1),
      );
    });
  });
}

Future<void> _pumpTestApp(
  WidgetTester tester, {
  AttributedTextEditingController? controller,
  EdgeInsets? padding,
  TextAlign? textAlign,
}) async {
  final textFieldFocusNode = FocusNode();
  const tapRegionGroupdId = "test_super_text_field";

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ColoredBox(
          color: Colors.green,
          child: TapRegion(
            groupId: tapRegionGroupdId,
            onTapOutside: (_) {
              // Unfocus on tap outside so that we're sure that all gesture tests
              // pass when using TapRegion's for focus, because apps should be able
              // to do that.
              textFieldFocusNode.unfocus();
            },
            child: SizedBox.expand(
              child: Align(
                alignment: Alignment.topCenter,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black),
                  ),
                  child: SuperTextField(
                    focusNode: textFieldFocusNode,
                    tapRegionGroupId: tapRegionGroupdId,
                    padding: padding,
                    textAlign: textAlign ?? TextAlign.left,
                    textController: controller ??
                        AttributedTextEditingController(
                          text: AttributedText('abc'),
                        ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _pumpSingleLineTextField(
  WidgetTester tester, {
  AttributedTextEditingController? controller,
  double? width,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width ?? 400,
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border.all(color: Colors.red)),
              child: SuperTextField(
                textController: controller,
                // We use significant padding to catch bugs related to projecting offsets
                // between the text layout and the scrolling viewport.
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 48),
                minLines: 1,
                maxLines: 1,
                inputSource: TextInputSource.ime,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Pump a test app with either a [SuperAndroidTextField] or a [SuperIOSTextField] with a fake toolbar.
///
/// The textfield is bound to [_textFieldKey] and the toolbar is bound to [_popoverToolbarKey].
///
/// This is used because we cannot configure the toolbar with [SuperTextField]'s public API.
Future<void> _pumpTestAppWithFakeToolbar(
  WidgetTester tester, {
  ImeAttributedTextEditingController? controller,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border.all(color: Colors.red)),
              child: defaultTargetPlatform == TargetPlatform.android
                  ? SuperAndroidTextField(
                      key: _textFieldKey,
                      caretStyle: const CaretStyle(),
                      textController: controller,
                      selectionColor: Colors.blue,
                      handlesColor: Colors.blue,
                      popoverToolbarBuilder: (context, controller, config) => SizedBox(key: _popoverToolbarKey),
                    )
                  : SuperIOSTextField(
                      key: _textFieldKey,
                      caretStyle: const CaretStyle(),
                      selectionColor: Colors.blue,
                      handlesColor: Colors.blue,
                      popoverToolbarBuilder: (context, controller) => SizedBox(key: _popoverToolbarKey),
                    ),
            ),
          ),
        ),
      ),
    ),
  );
}

// Custom gesture settings that ensure panSlop equal to touchSlop
class _GestureSettings extends DeviceGestureSettings {
  const _GestureSettings({
    required double touchSlop,
    required this.panSlop,
  }) : super(touchSlop: touchSlop);

  @override
  final double panSlop;
}

final _popoverToolbarKey = GlobalKey();
final _textFieldKey = GlobalKey();
