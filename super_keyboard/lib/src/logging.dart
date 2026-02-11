import 'dart:async';

import 'package:logging/logging.dart';

/// Loggers for Super Keyboard, which can be activated by log level and by focal
/// area, and can also print to a given [LogPrinter].
abstract class SKLog {
  static final superKeyboard = Logger("super_keyboard");
  static final unified = Logger("super_keyboard.unified");
  static final ios = Logger("super_keyboard.ios");
  static final android = Logger("super_keyboard.android");

  static StreamSubscription<LogRecord>? _logRecordSubscription;

  static void startLogging([Level level = Level.ALL, LogPrinter? printer]) {
    if (_logRecordSubscription != null) {
      _logRecordSubscription!.cancel();
      _logRecordSubscription = null;
    }

    hierarchicalLoggingEnabled = true;
    superKeyboard.level = level;
    _logRecordSubscription = superKeyboard.onRecord.listen(printer ?? defaultLogPrinter);
  }

  static void stopLogging() {
    superKeyboard.level = Level.OFF;

    if (_logRecordSubscription != null) {
      _logRecordSubscription!.cancel();
      _logRecordSubscription = null;
    }
  }
}

void defaultLogPrinter(LogRecord record) {
  // ignore: avoid_print
  print('${record.level.name}: ${record.time.toLogTime()}: ${record.message}');
}

typedef LogPrinter = void Function(LogRecord);

extension on DateTime {
  String toLogTime() {
    String h = _twoDigits(hour);
    String min = _twoDigits(minute);
    String sec = _twoDigits(second);
    String ms = _threeDigits(millisecond);
    if (isUtc) {
      return "$h:$min:$sec.$ms";
    } else {
      return "$h:$min:$sec.$ms";
    }
  }

  String _threeDigits(int n) {
    if (n >= 100) return "$n";
    if (n >= 10) return "0$n";
    return "00$n";
  }

  String _twoDigits(int n) {
    if (n >= 10) return "$n";
    return "0$n";
  }
}
