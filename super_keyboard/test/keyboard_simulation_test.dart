import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_keyboard/super_keyboard.dart';
import 'package:super_keyboard/super_keyboard_test.dart';

void main() {
  group("Super Keyboard Test Tools > keyboard simulation >", () {
    testWidgets("opens and closes", (tester) async {
      final screenKey = GlobalKey();
      final contentKey = GlobalKey();
      await _pumpScaffold(
        tester,
        screenKey: screenKey,
        contentKey: contentKey,
      );

      // Ensure the keyboard is closed, initially.
      expect(SuperKeyboard.instance.mobileGeometry.value.keyboardState, KeyboardState.closed);
      expect(_calculateKeyboardHeight(screenKey, contentKey), 0.0);

      // Focus the text field to open the keyboard.
      await tester.tap(find.byType(TextField));

      // Pump a couple frames and ensure the keyboard is opening.
      // Note: If we don't explicitly pass a duration, the animation doesn't
      //       move forward. I don't know why.
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(SuperKeyboard.instance.mobileGeometry.value.keyboardState, KeyboardState.opening);
      expect(_calculateKeyboardHeight(screenKey, contentKey), lessThan(_keyboardHeight));
      expect(_calculateKeyboardHeight(screenKey, contentKey), greaterThan(0));

      // Let the keyboard finish opening.
      await tester.pumpAndSettle();

      // Ensure that the keyboard is fully open.
      expect(SuperKeyboard.instance.mobileGeometry.value.keyboardState, KeyboardState.open);
      expect(_calculateKeyboardHeight(screenKey, contentKey), _keyboardHeight);

      // Tap outside the text field to unfocus it.
      await tester.tapAt(const Offset(200, 100));

      // Pump a couple frames and ensure the keyboard is closing.
      // Note: If we don't explicitly pass a duration, the animation doesn't
      //       move forward. I don't know why.
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(SuperKeyboard.instance.mobileGeometry.value.keyboardState, KeyboardState.closing);
      expect(_calculateKeyboardHeight(screenKey, contentKey), lessThan(_keyboardHeight));
      expect(_calculateKeyboardHeight(screenKey, contentKey), greaterThan(0));

      // Let the keyboard finish closing.
      await tester.pumpAndSettle();

      // Ensure that the keyboard is fully closed.
      expect(SuperKeyboard.instance.mobileGeometry.value.keyboardState, KeyboardState.closed);
      expect(_calculateKeyboardHeight(screenKey, contentKey), 0.0);
    });

    testWidgetsOnMobile("enabled by default on mobile", (tester) async {
      final screenKey = GlobalKey();
      final contentKey = GlobalKey();
      await _pumpScaffold(
        tester,
        screenKey: screenKey,
        contentKey: contentKey,
      );

      // Ensure the keyboard is closed, initially.
      expect(_calculateKeyboardHeight(screenKey, contentKey), 0.0);

      // Focus the text field to open the keyboard.
      await tester.tap(find.byType(TextField));

      // Let the keyboard animate up.
      await tester.pumpAndSettle();

      // Ensure the keyboard is open.
      expect(_calculateKeyboardHeight(screenKey, contentKey), _keyboardHeight);
    });

    testWidgetsOnDesktop("disabled by default on desktop", (tester) async {
      final screenKey = GlobalKey();
      final contentKey = GlobalKey();
      await _pumpScaffold(
        tester,
        screenKey: screenKey,
        contentKey: contentKey,
      );

      // Ensure the keyboard is closed, initially.
      expect(_calculateKeyboardHeight(screenKey, contentKey), 0.0);

      // Focus the text field to open the keyboard.
      await tester.tap(find.byType(TextField));

      // Give the keyboard a chance to animate up (it shouldn't).
      await tester.pumpAndSettle();

      // Ensure the keyboard is still closed.
      expect(_calculateKeyboardHeight(screenKey, contentKey), 0.0);
    });
  });
}

Future<void> _pumpScaffold(
  WidgetTester tester, {
  GlobalKey? screenKey,
  GlobalKey? contentKey,
}) async {
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.android:
      tester.view.physicalSize = const Size(1170, 2532); // iPhone 13 Pro
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
    // Use default test window size for desktop.
  }

  await tester.pumpWidget(
    SizedBox(
      key: screenKey,
      child: SoftwareKeyboardHeightSimulator(
        keyboardHeight: _keyboardHeight,
        animateKeyboard: true,
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              key: contentKey,
              child: TextField(
                onTapOutside: (event) {
                  // Remove focus on tap outside.
                  FocusManager.instance.primaryFocus?.unfocus();
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

double _calculateKeyboardHeight(GlobalKey screenKey, GlobalKey contentKey) {
  final screenBox = screenKey.currentContext!.findRenderObject() as RenderBox;
  final contentBox = contentKey.currentContext!.findRenderObject() as RenderBox;

  return screenBox.size.height - contentBox.size.height;
}

const _keyboardHeight = 300.0;
