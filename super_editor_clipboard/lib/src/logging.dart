import 'dart:async';

import 'package:logging/logging.dart';

/// Loggers for Super Editor Clipboard, which can be activated by log level and by focal
/// area, and can also print to a given [SECLogPrinter].
abstract class SECLog {
  static final superEditorClipboard = Logger("super_editor_clipboard");
  static final paste = Logger("super_editor_clipboard.paste");
  static final pasteIOS = Logger("super_editor_clipboard.paste.ios");
  static final pasteAndroid = Logger("super_editor_clipboard.paste.android");

  static StreamSubscription<LogRecord>? _logRecordSubscription;

  static void startLogging([Level level = Level.ALL, SECLogPrinter? printer]) {
    if (_logRecordSubscription != null) {
      _logRecordSubscription!.cancel();
      _logRecordSubscription = null;
    }

    hierarchicalLoggingEnabled = true;
    superEditorClipboard.level = level;
    _logRecordSubscription = superEditorClipboard.onRecord.listen(printer ?? defaultLogPrinter);
  }

  static void stopLogging() {
    superEditorClipboard.level = Level.OFF;

    if (_logRecordSubscription != null) {
      _logRecordSubscription!.cancel();
      _logRecordSubscription = null;
    }
  }

  static void defaultLogPrinter(LogRecord record) {
    // ignore: avoid_print
    print('${record.level.name}: ${record.time.toLogTime()}: ${record.message}');
  }
}

typedef SECLogPrinter = void Function(LogRecord);

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
