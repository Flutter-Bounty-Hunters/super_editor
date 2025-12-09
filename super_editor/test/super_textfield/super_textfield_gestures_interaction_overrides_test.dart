import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/src/infrastructure/document_gestures_interaction_overrides.dart';
import 'package:super_editor/super_text_field.dart';
import 'package:super_editor/super_text_field_test.dart';

void main() {
  group('SuperTextField gesture interaction overrides > ', () {
    group('single tap >', () {
      group('single handler >', () {
        testWidgetsOnAllPlatforms('can be customized', (tester) async {
          final handler = _SuperTextFieldTestTapHandler();

          await _pumpSingleFieldTestApp(tester, tapHandlers: [handler]);

          // Tap on the text field.
          await tester.placeCaretInSuperTextField(0);

          // Ensure the custom tap handler was called.
          expect(handler.wasTapDownHandled, isTrue);
          expect(handler.wasTapUpHandled, isTrue);
          expect(handler.wasDoubleTapDownHandled, isFalse);
          expect(handler.wasTripleTapDownHandled, isFalse);

          // Ensure the default behavior of placing the caret was not called.
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection.collapsed(offset: -1),
          );
        });
      });

      group('multiple handlers >', () {
        testWidgetsOnAllPlatforms('run seach handler until the gesture is handled', (tester) async {
          final noOpHandler = _NoOpTextFieldTapHandler();
          final handler = _SuperTextFieldTestTapHandler();

          await _pumpSingleFieldTestApp(tester, tapHandlers: [noOpHandler, handler]);

          // Tap on the text field.
          await tester.placeCaretInSuperTextField(0);

          // Ensure the custom tap handler was called.
          expect(handler.wasTapDownHandled, isTrue);
          expect(handler.wasTapUpHandled, isTrue);
          expect(handler.wasDoubleTapDownHandled, isFalse);
          expect(handler.wasTripleTapDownHandled, isFalse);

          // Ensure the default behavior of placing the caret was not called.
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection.collapsed(offset: -1),
          );
        });

        testWidgetsOnAllPlatforms('stops when a handler handles the gesture', (tester) async {
          final handler1 = _SuperTextFieldTestTapHandler();
          final handler2 = _SuperTextFieldTestTapHandler();

          await _pumpSingleFieldTestApp(tester, tapHandlers: [handler1, handler2]);

          // Tap on the text field.
          await tester.placeCaretInSuperTextField(0);

          // Ensure the first tap handler was called.
          expect(handler1.wasTapDownHandled, isTrue);
          expect(handler1.wasTapUpHandled, isTrue);
          expect(handler1.wasDoubleTapDownHandled, isFalse);
          expect(handler1.wasTripleTapDownHandled, isFalse);

          // Ensure the second tap handler was not called.
          expect(handler2.wasTapDownHandled, isFalse);
          expect(handler2.wasTapUpHandled, isFalse);
          expect(handler2.wasDoubleTapDownHandled, isFalse);
          expect(handler2.wasTripleTapDownHandled, isFalse);

          // Ensure the default behavior of placing the caret was not called.
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection.collapsed(offset: -1),
          );
        });
      });
    });

    group('double tap >', () {
      group('single handler >', () {
        testWidgetsOnAllPlatforms('can be customized', (tester) async {
          final handler = _SuperTextFieldTestTapHandler();

          await _pumpSingleFieldTestApp(tester, tapHandlers: [handler]);

          await tester.doubleTapAtSuperTextField(0);

          // Ensure the custom tap handler was called.
          expect(handler.wasDoubleTapDownHandled, isTrue);
          expect(handler.wasDoubleTapUpHandled, isTrue);
          expect(handler.wasTripleTapDownHandled, isFalse);

          // Ensure the default behavior of placing the caret was not called.
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection.collapsed(offset: -1),
          );
        });
      });

      group('multiple handlers > ', () {
        testWidgetsOnAllPlatforms('run each handler until the gesture is handled', (tester) async {
          final noOpHandler = _NoOpTextFieldTapHandler();
          final handler = _SuperTextFieldTestTapHandler();

          await _pumpSingleFieldTestApp(tester, tapHandlers: [noOpHandler, handler]);

          await tester.doubleTapAtSuperTextField(0);

          // Ensure the custom tap handler was called.
          expect(handler.wasDoubleTapDownHandled, isTrue);
          expect(handler.wasDoubleTapUpHandled, isTrue);
          expect(handler.wasTripleTapDownHandled, isFalse);

          // Ensure the default behavior of placing an expanded selection
          // was not called.
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection.collapsed(offset: -1),
          );
        });

        testWidgetsOnAllPlatforms('stops when a handler handles the gesture', (tester) async {
          final handler1 = _SuperTextFieldTestTapHandler();
          final handler2 = _SuperTextFieldTestTapHandler();

          await _pumpSingleFieldTestApp(tester, tapHandlers: [handler1, handler2]);

          await tester.doubleTapAtSuperTextField(0);

          // Ensure the first tap handler was called.
          expect(handler1.wasDoubleTapDownHandled, isTrue);
          expect(handler1.wasDoubleTapUpHandled, isTrue);
          expect(handler1.wasTripleTapDownHandled, isFalse);

          // Ensure the second tap handler was not called.
          expect(handler2.wasDoubleTapDownHandled, isFalse);
          expect(handler2.wasDoubleTapUpHandled, isFalse);
          expect(handler2.wasTripleTapDownHandled, isFalse);

          // Ensure the default behavior of placing an expanded selection
          // was not called.
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection.collapsed(offset: -1),
          );
        });
      });
    });

    group('triple tap', () {
      group('single handler > ', () {
        testWidgetsOnAllPlatforms('can be customized', (tester) async {
          final handler = _SuperTextFieldTestTapHandler();

          await _pumpSingleFieldTestApp(tester, tapHandlers: [handler]);

          // Triple tap on the text field.
          await tester.tripleTapAtSuperTextField(0);

          // Ensure the custom tap handler was called.
          expect(handler.wasTripleTapDownHandled, isTrue);
          expect(handler.wasTripleTapUpHandled, isTrue);

          // Ensure the default behavior of placing an expanded selection
          // was not called.
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection.collapsed(offset: -1),
          );
        });
      });

      group('multiple handlers > ', () {
        testWidgetsOnAllPlatforms('run each handler until the gesture is handled', (tester) async {
          final noOpHandler = _NoOpTextFieldTapHandler();
          final handler = _SuperTextFieldTestTapHandler();

          await _pumpSingleFieldTestApp(tester, tapHandlers: [noOpHandler, handler]);

          await tester.tripleTapAtSuperTextField(0);

          // Ensure the custom tap handler was called.
          expect(handler.wasTripleTapDownHandled, isTrue);
          expect(handler.wasTripleTapUpHandled, isTrue);

          // Ensure the default behavior of placing an expanded selection
          // was not called.
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection.collapsed(offset: -1),
          );
        });

        testWidgetsOnAllPlatforms('stops when a handler handles the gesture', (tester) async {
          final handler1 = _SuperTextFieldTestTapHandler();
          final handler2 = _SuperTextFieldTestTapHandler();

          await _pumpSingleFieldTestApp(tester, tapHandlers: [handler1, handler2]);

          await tester.tripleTapAtSuperTextField(0);

          // Ensure the first tap handler was called.
          expect(handler1.wasTripleTapDownHandled, isTrue);
          expect(handler1.wasTripleTapUpHandled, isTrue);

          // Ensure the second tap handler was not called.
          expect(handler2.wasTripleTapDownHandled, isFalse);
          expect(handler2.wasTripleTapUpHandled, isFalse);

          // Ensure the default behavior of placing an expanded selection
          // was not called.
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection.collapsed(offset: -1),
          );
        });
      });
    });

    group('secondary tap >', () {
      group('single handler >', () {
        testWidgetsOnDesktop('can be customized', (tester) async {
          final handler = _SuperTextFieldTestTapHandler();

          await _pumpSingleFieldTestApp(tester, tapHandlers: [handler]);

          // Tap on the text field.
          await tester.tapAtSuperTextField(0, buttons: kSecondaryMouseButton);

          // Ensure the custom tap handler was called.
          expect(handler.wasSecondaryTapDownHandled, isTrue);
          expect(handler.wasSecondaryTapUpHandled, isTrue);
          expect(handler.wasTapUpHandled, isFalse);
          expect(handler.wasDoubleTapDownHandled, isFalse);
          expect(handler.wasTripleTapDownHandled, isFalse);
        });
      });

      group('multiple handlers >', () {
        testWidgetsOnDesktop('run seach handler until the gesture is handled', (tester) async {
          final noOpHandler = _NoOpTextFieldTapHandler();
          final handler = _SuperTextFieldTestTapHandler();

          await _pumpSingleFieldTestApp(tester, tapHandlers: [noOpHandler, handler]);

          // Tap on the text field.
          await tester.tapAtSuperTextField(0, buttons: kSecondaryMouseButton);

          // Ensure the custom tap handler was called.
          expect(handler.wasSecondaryTapDownHandled, isTrue);
          expect(handler.wasSecondaryTapUpHandled, isTrue);
          expect(handler.wasTapUpHandled, isFalse);
          expect(handler.wasDoubleTapDownHandled, isFalse);
          expect(handler.wasTripleTapDownHandled, isFalse);
        });

        testWidgetsOnDesktop('stops when a handler handles the gesture', (tester) async {
          final handler1 = _SuperTextFieldTestTapHandler();
          final handler2 = _SuperTextFieldTestTapHandler();

          await _pumpSingleFieldTestApp(tester, tapHandlers: [handler1, handler2]);

          // Tap on the text field.
          await tester.tapAtSuperTextField(0, buttons: kSecondaryMouseButton);

          // Ensure the first tap handler was called.
          expect(handler1.wasSecondaryTapDownHandled, isTrue);
          expect(handler1.wasSecondaryTapUpHandled, isTrue);
          expect(handler1.wasTapUpHandled, isFalse);
          expect(handler1.wasDoubleTapDownHandled, isFalse);
          expect(handler1.wasTripleTapDownHandled, isFalse);

          // Ensure the second tap handler was not called.
          expect(handler2.wasSecondaryTapDownHandled, isFalse);
          expect(handler2.wasSecondaryTapUpHandled, isFalse);
          expect(handler2.wasTapUpHandled, isFalse);
          expect(handler2.wasDoubleTapDownHandled, isFalse);
          expect(handler2.wasTripleTapDownHandled, isFalse);
        });
      });
    });

    testWidgetsOnDesktop('allows customizing mouse cursor', (tester) async {
      final handler = _SuperTextFieldTestTapHandler();

      await _pumpSingleFieldTestApp(tester, tapHandlers: [handler]);

      // Start a gesture outside SuperTextField bounds.
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();

      // Ensure the cursor type is 'basic' when not hovering SuperTextField.
      expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.basic);

      // Hover over the text field.
      await gesture.moveTo(tester.getCenter(find.byType(SuperTextField)));
      await tester.pump();

      // Ensure the cursor type was configured by the custom handler.
      expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.move);
    });
  });
}

/// Pump a test app with a single [SuperTextField] that has the given [tapHandlers].
Future<void> _pumpSingleFieldTestApp(
  WidgetTester tester, {
  required List<SuperTextFieldTapHandler> tapHandlers,
}) async {
  final textController = AttributedTextEditingController(
    text: AttributedText('This is a text field'),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SizedBox(
            width: 300,
            child: SuperTextField(
              textController: textController,
              lineHeight: 16,
              tapHandlers: tapHandlers,
            ),
          ),
        ),
      ),
    ),
  );
}

/// A [SuperTextFieldTapHandler] that records whether each tap was handled and
/// always specifies [SystemMouseCursors.move] as the mouse cursor.
///
/// This handler prevents any other handlers from running, because it always
/// returns [TapHandlingInstruction.halt].
class _SuperTextFieldTestTapHandler extends SuperTextFieldTapHandler {
  bool get wasTapDownHandled => _wasTapDownHandled;
  bool _wasTapDownHandled = false;

  bool get wasTapUpHandled => _wasTapUpHandled;
  bool _wasTapUpHandled = false;

  bool get wasDoubleTapDownHandled => _wasDoubleTapDownHandled;
  bool _wasDoubleTapDownHandled = false;

  bool get wasDoubleTapUpHandled => _wasDoubleTapUpHandled;
  bool _wasDoubleTapUpHandled = false;

  bool get wasTripleTapDownHandled => _wasTripleTapDownHandled;
  bool _wasTripleTapDownHandled = false;

  bool get wasTripleTapUpHandled => _wasTripleTapUpHandled;
  bool _wasTripleTapUpHandled = false;

  bool get wasSecondaryTapDownHandled => _wasSecondaryTapDownHandled;
  bool _wasSecondaryTapDownHandled = false;

  bool get wasSecondaryTapUpHandled => _wasSecondaryTapUpHandled;
  bool _wasSecondaryTapUpHandled = false;

  @override
  MouseCursor? mouseCursorForContentHover(SuperTextFieldGestureDetails details) {
    return SystemMouseCursors.move;
  }

  @override
  TapHandlingInstruction onTapDown(SuperTextFieldGestureDetails details) {
    _wasTapDownHandled = true;
    return TapHandlingInstruction.halt;
  }

  @override
  TapHandlingInstruction onTapUp(SuperTextFieldGestureDetails details) {
    _wasTapUpHandled = true;
    return TapHandlingInstruction.halt;
  }

  @override
  TapHandlingInstruction onDoubleTapDown(SuperTextFieldGestureDetails details) {
    _wasDoubleTapDownHandled = true;
    return TapHandlingInstruction.halt;
  }

  @override
  TapHandlingInstruction onDoubleTapUp(SuperTextFieldGestureDetails details) {
    _wasDoubleTapUpHandled = true;
    return TapHandlingInstruction.halt;
  }

  @override
  TapHandlingInstruction onTripleTapDown(SuperTextFieldGestureDetails details) {
    _wasTripleTapDownHandled = true;
    return TapHandlingInstruction.halt;
  }

  @override
  TapHandlingInstruction onTripleTapUp(SuperTextFieldGestureDetails details) {
    _wasTripleTapUpHandled = true;
    return TapHandlingInstruction.halt;
  }

  @override
  TapHandlingInstruction onSecondaryTapDown(SuperTextFieldGestureDetails details) {
    _wasSecondaryTapDownHandled = true;
    return TapHandlingInstruction.halt;
  }

  @override
  TapHandlingInstruction onSecondaryTapUp(SuperTextFieldGestureDetails details) {
    _wasSecondaryTapUpHandled = true;
    return TapHandlingInstruction.halt;
  }
}

/// A [SuperTextFieldTapHandler] that does nothing.
class _NoOpTextFieldTapHandler extends SuperTextFieldTapHandler {}
