import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Controls the visibility of something that blinks.
///
/// A [BlinkController] maintains a timer that alters [opacity] based
/// on a [flashPeriod]. The blinking can be enabled or disabled, and
/// the opacity can be immediately reset to opaque with [jumpToOpaque()].
class BlinkController with ChangeNotifier {
  // Controls whether or not all BlinkControllers animate. This is intended
  // to be used by tests to disable animations so that pumpAndSettle() doesn't
  // time out.
  @visibleForTesting
  static bool indeterminateAnimationsEnabled = true;

  BlinkController({
    required TickerProvider tickerProvider,
    Duration flashPeriod = const Duration(milliseconds: 500),
  }) : _flashPeriod = flashPeriod {
    _ticker = tickerProvider.createTicker(_onTick);
  }

  BlinkController.withTimer({
    Duration flashPeriod = const Duration(milliseconds: 500),
  }) : _flashPeriod = flashPeriod;

  @override
  void dispose() {
    _ticker?.dispose();
    _timer?.cancel();

    super.dispose();
  }

  Ticker? _ticker;
  Duration _lastBlinkTime = Duration.zero;

  @visibleForTesting
  bool get isTicking => _ticker?.isTicking ?? false;

  Timer? _timer;

  @visibleForTesting
  bool get isTimerRunning => _timer?.isActive ?? false;

  final Duration _flashPeriod;

  /// Duration to switch between visible and invisible.
  Duration get flashPeriod => _flashPeriod;

  /// Returns `true` if this controller is currently animating a blinking
  /// signal, or `false` if it's not.
  bool get isBlinking =>
      (_ticker != null || _timer != null) && (_ticker != null ? _ticker!.isTicking : _timer?.isActive ?? false);

  bool _isBlinkingEnabled = true;
  set isBlinkingEnabled(bool newValue) {
    if (newValue == _isBlinkingEnabled) {
      return;
    }

    _isBlinkingEnabled = newValue;
    if (!_isBlinkingEnabled) {
      stopBlinking();
    }
    notifyListeners();
  }

  bool _isVisible = true;
  double get opacity => _isVisible ? 1.0 : 0.0;

  void startBlinking() {
    if (!indeterminateAnimationsEnabled) {
      // Never animate a blink when the app/test wants to avoid
      // indeterminate animations.
      return;
    }

    if (_ticker != null) {
      // We're using a Ticker to blink. Restart it.
      _ticker!
        ..stop()
        ..start();
    } else {
      // We're using a Timer to blink. Restart it.
      _timer?.cancel();
      _timer = Timer(_flashPeriod, _blink);
    }

    _lastBlinkTime = Duration.zero;
    notifyListeners();
  }

  void stopBlinking() {
    _isVisible = true; // If we're not blinking then we need to be visible

    if (_ticker != null) {
      // We're using a Ticker to blink. Stop it.
      _ticker?.stop();
    } else {
      // We're using a Timer to blink. Stop it.
      _timer?.cancel();
      _timer = null;
    }

    notifyListeners();
  }

  /// Make the object completely opaque, and restart the blink timer.
  void jumpToOpaque() {
    final wasBlinking = isBlinking;
    stopBlinking();

    if (!_isBlinkingEnabled) {
      return;
    }

    if (wasBlinking) {
      startBlinking();
    }
  }

  void _onTick(Duration elapsedTime) {
    if (elapsedTime - _lastBlinkTime >= _flashPeriod) {
      _blink();
      _lastBlinkTime = elapsedTime;
    }
  }

  void _blink() {
    _isVisible = !_isVisible;
    notifyListeners();

    if (_timer != null && _isBlinkingEnabled) {
      _timer = Timer(_flashPeriod, _blink);
    }
  }
}

/// The way a blinking caret tracks time.
///
/// Ideally, all time in Flutter widgets is tracked by `Ticker`s because they hook into
/// Flutter's internal time reporting. This is critical for tests.
///
/// Unfortunately, at the time of this writing, running `Ticker`s forces Flutter into
/// full FPS rendering, even when nothing needs to be rebuilt or painted. For that reason,
/// [BlinkController] lets users request the use of Dart `Timer`s, which only fire
/// when needed. `Timer`s are not expected to work in widget tests.
enum BlinkTimingMode {
  ticker,
  timer,
}
