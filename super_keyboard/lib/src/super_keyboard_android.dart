import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:super_keyboard/super_keyboard.dart';

class SuperKeyboardAndroidBuilder extends StatefulWidget {
  const SuperKeyboardAndroidBuilder({
    super.key,
    required this.builder,
  });

  final Widget Function(BuildContext, MobileWindowGeometry) builder;

  @override
  State<SuperKeyboardAndroidBuilder> createState() => _SuperKeyboardAndroidBuilderState();
}

class _SuperKeyboardAndroidBuilderState extends State<SuperKeyboardAndroidBuilder>
    implements SuperKeyboardAndroidListener {
  @override
  void initState() {
    super.initState();
    SuperKeyboardAndroid.instance.addListener(this);
  }

  @override
  void dispose() {
    SuperKeyboardAndroid.instance.removeListener(this);
    super.dispose();
  }

  @override
  void onKeyboardOpen() {
    setState(() {});
  }

  @override
  void onKeyboardOpening() {
    setState(() {});
  }

  @override
  void onKeyboardClosing() {
    setState(() {});
  }

  @override
  void onKeyboardClosed() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      SuperKeyboardAndroid.instance.geometry.value,
    );
  }
}

class SuperKeyboardAndroid {
  static SuperKeyboardAndroid? _instance;
  static SuperKeyboardAndroid get instance {
    _instance ??= SuperKeyboardAndroid._();
    return _instance!;
  }

  SuperKeyboardAndroid._() {
    assert(
      defaultTargetPlatform == TargetPlatform.android,
      "You shouldn't initialize SuperKeyboardAndroid when not on an Android platform. Current: $defaultTargetPlatform",
    );
    _methodChannel.setMethodCallHandler(_onPlatformMessage);
  }

  final _methodChannel = const MethodChannel('super_keyboard_android');

  /// Enable platform-side logging, e.g., Android logs.
  ///
  /// Optionally, log messages on the platform side can be forwarded to Dart
  /// so that they can be printed by the current [SKLog]. To do this, pass
  /// `true` for [sendPlatformLogsToDart]. Defaults to `false`.
  Future<void> enablePlatformLogging({bool sendPlatformLogsToDart = false}) async {
    await _methodChannel.invokeMethod("startLogging", {"sendPlatformLogsToDart": sendPlatformLogsToDart});
  }

  /// Disable platform-side logging, e.g., Android logs.
  Future<void> disablePlatformLogging() async {
    await _methodChannel.invokeMethod("stopLogging");
  }

  ValueListenable<MobileWindowGeometry> get geometry => _geometry;
  final _geometry = ValueNotifier<MobileWindowGeometry>(const MobileWindowGeometry());

  final _listeners = <SuperKeyboardAndroidListener>{};
  void addListener(SuperKeyboardAndroidListener listener) => _listeners.add(listener);
  void removeListener(SuperKeyboardAndroidListener listener) => _listeners.remove(listener);

  Future<void> _onPlatformMessage(MethodCall message) async {
    switch (message.method) {
      case "keyboardOpening":
        _geometry.value = _geometry.value.updateWith(
          MobileWindowGeometry(
            keyboardState: KeyboardState.opening,
            keyboardHeight: (message.arguments["keyboardHeight"] as num?)?.toDouble(),
            bottomPadding: (message.arguments["bottomPadding"] as num?)?.toDouble(),
          ),
        );

        for (final listener in _listeners) {
          listener.onKeyboardOpening();
        }
        break;
      case "keyboardOpened":
        _geometry.value = _geometry.value.updateWith(
          MobileWindowGeometry(
            keyboardState: KeyboardState.open,
            keyboardHeight: (message.arguments["keyboardHeight"] as num?)?.toDouble(),
            bottomPadding: (message.arguments["bottomPadding"] as num?)?.toDouble(),
          ),
        );

        for (final listener in _listeners) {
          listener.onKeyboardOpen();
        }
        break;
      case "keyboardClosing":
        _geometry.value = _geometry.value.updateWith(
          MobileWindowGeometry(
            keyboardState: KeyboardState.closing,
            keyboardHeight: (message.arguments["keyboardHeight"] as num?)?.toDouble(),
            bottomPadding: (message.arguments["bottomPadding"] as num?)?.toDouble(),
          ),
        );

        for (final listener in _listeners) {
          listener.onKeyboardClosing();
        }
        break;
      case "keyboardClosed":
        _geometry.value = _geometry.value.updateWith(
          MobileWindowGeometry(
            keyboardState: KeyboardState.closed,
            // Just in case the height got out of sync, perhaps due to Activity
            // lifecycle changes, explicitly set the keyboard height to zero.
            keyboardHeight: 0,
            bottomPadding: (message.arguments["bottomPadding"] as num?)?.toDouble(),
          ),
        );

        for (final listener in _listeners) {
          listener.onKeyboardClosed();
        }
        break;
      case "onProgress":
        _geometry.value = _geometry.value.updateWith(
          MobileWindowGeometry(
            keyboardHeight: (message.arguments["keyboardHeight"] as num?)?.toDouble(),
            bottomPadding: (message.arguments["bottomPadding"] as num?)?.toDouble(),
          ),
        );
        break;
      case "metricsUpdate":
        _geometry.value = _geometry.value.updateWith(
          MobileWindowGeometry(
            keyboardHeight: (message.arguments["keyboardHeight"] as num?)?.toDouble(),
            bottomPadding: (message.arguments["bottomPadding"] as num?)?.toDouble(),
          ),
        );
        break;
      case "log":
        _printAndroidLog(message);
        break;
      default:
        SKLog.android.warning("Unknown Android plugin platform message: $message");
    }
  }

  void _printAndroidLog(MethodCall channelMessage) {
    final level = channelMessage.arguments["level"] as String?;
    final logMessage = "SK Android: ${channelMessage.arguments["message"] ?? "EMPTY MESSAGE"}";
    switch (level) {
      case "v":
        SKLog.android.finer(logMessage);
      case "d":
        SKLog.android.fine(logMessage);
      case "i":
        SKLog.android.info(logMessage);
      case "w":
        SKLog.android.warning(logMessage);
      case "e":
        SKLog.android.shout(logMessage);
    }
  }
}

abstract interface class SuperKeyboardAndroidListener {
  void onKeyboardOpening();
  void onKeyboardOpen();
  void onKeyboardClosing();
  void onKeyboardClosed();
}
