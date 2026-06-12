import 'package:flutter_test/flutter_test.dart';
import 'package:super_text_layout/src/infrastructure/blink_controller.dart';

void main() {
  group("BlinkController", () {
    testWidgets("notifies listeners when it stops blinking", (tester) async {
      bool hasNotifiedItsListener = false;

      final blinkController = BlinkController(tickerProvider: tester);
      blinkController.addListener(() {
        hasNotifiedItsListener = true;
      });

      blinkController.stopBlinking();

      // Ensure that the callback was called
      expect(hasNotifiedItsListener, true);
    });

    testWidgets("notifies listeners when it starts blinking", (tester) async {
      // Configure BlinkController to animate, otherwise it won't blink
      BlinkController.indeterminateAnimationsEnabled = true;

      bool hasNotifiedItsListeners = false;

      final blinkController = BlinkController(tickerProvider: tester);
      blinkController.stopBlinking();

      blinkController.addListener(() {
        hasNotifiedItsListeners = true;
      });

      blinkController.startBlinking();

      // Ensure that the callback was called
      expect(hasNotifiedItsListeners, true);

      // Release the ticker
      blinkController.stopBlinking();
      BlinkController.indeterminateAnimationsEnabled = false;
    });

    testWidgets("notifies listeners every time it blinks", (tester) async {
      // Configure BlinkController to animate, otherwise it won't blink
      BlinkController.indeterminateAnimationsEnabled = true;
      // duration to switch between visible and invisible
      const flashPeriod = Duration(milliseconds: 500);

      int notificationCount = 0;

      final blinkController = BlinkController(tickerProvider: tester, flashPeriod: flashPeriod);
      blinkController.addListener(() {
        notificationCount++;
      });

      blinkController.startBlinking();

      // Ensure that the callback was called before the first blink
      expect(notificationCount, 1);

      // Trigger the first frame, otherwise we get a zero elapsedTime in the _onTick method
      await tester.pump();
      // Trigger a frame with an ellapsed time greater than the flashPeriod,
      // so the controller should change its visible state and notify its listeners
      await tester.pump(flashPeriod + const Duration(milliseconds: 1));

      // Ensure that the callback was called a second time
      expect(notificationCount, 2);

      // Release the ticker
      blinkController.stopBlinking();
      BlinkController.indeterminateAnimationsEnabled = false;
    });

    testWidgets("can stop and then restart ticker", (tester) async {
      // Configure BlinkController to animate, otherwise it won't blink
      BlinkController.indeterminateAnimationsEnabled = true;

      int notificationCount = 0;

      final blinkController = BlinkController(tickerProvider: tester);
      blinkController.addListener(() {
        notificationCount += 1;
      });

      blinkController.startBlinking();
      expect(notificationCount, 1);

      // Ensure the ticker is ticking.
      expect(blinkController.isTicking, isTrue);

      // Stop the blinking, which should stop the ticker, but should retain the ticker.
      blinkController.stopBlinking();
      expect(notificationCount, 2);

      // Ensure that the ticker is no longer ticking.
      expect(blinkController.isTicking, isFalse);
      expect(blinkController.isTimerRunning, isFalse);

      blinkController.startBlinking();
      expect(notificationCount, 3);

      // Ensure that the ticker is running again, and that we're not using a timer.
      expect(blinkController.isTicking, isTrue);
      expect(blinkController.isTimerRunning, isFalse);

      // Dispose the controller so that we don't leak the ticker and cause a test error.
      blinkController.dispose();
    });
  });
}
