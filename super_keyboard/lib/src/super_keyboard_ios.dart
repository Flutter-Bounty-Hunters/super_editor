import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:super_keyboard/src/keyboard.dart';
import 'package:super_keyboard/src/logging.dart';

class SuperKeyboardIOSBuilder extends StatefulWidget {
  const SuperKeyboardIOSBuilder({
    super.key,
    required this.builder,
  });

  final Widget Function(BuildContext, MobileWindowGeometry) builder;

  @override
  State<SuperKeyboardIOSBuilder> createState() => _SuperKeyboardIOSBuilderState();
}

class _SuperKeyboardIOSBuilderState extends State<SuperKeyboardIOSBuilder> implements SuperKeyboardIOSListener {
  @override
  void initState() {
    super.initState();
    SuperKeyboardIOS.instance.addListener(this);
  }

  @override
  void dispose() {
    SuperKeyboardIOS.instance.removeListener(this);
    super.dispose();
  }

  @override
  void onKeyboardWillShow() {
    setState(() {});
  }

  @override
  void onKeyboardDidShow() {
    setState(() {});
  }

  @override
  void onKeyboardWillHide() {
    setState(() {});
  }

  @override
  void onKeyboardDidHide() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      SuperKeyboardIOS.instance.geometry.value,
    );
  }
}

class SuperKeyboardIOS {
  static SuperKeyboardIOS? _instance;
  static SuperKeyboardIOS get instance {
    _instance ??= SuperKeyboardIOS._();
    return _instance!;
  }

  SuperKeyboardIOS._() {
    SKLog.ios.info("Initializing iOS plugin for super_keyboard");
    assert(
      defaultTargetPlatform == TargetPlatform.iOS,
      "You shouldn't initialize SuperKeyboardIOS when not on an iOS platform. Current: $defaultTargetPlatform",
    );
    _methodChannel.setMethodCallHandler(_onPlatformMessage);
  }

  final _methodChannel = const MethodChannel('super_keyboard_ios');

  /// Enable platform-side logging, e.g., iOS logs.
  ///
  /// Optionally, log messages on the platform side can be forwarded to Dart
  /// so that they can be printed by the current [SKLog]. To do this, pass
  /// `true` for [sendPlatformLogsToDart]. When `false`, platform logs are
  /// printed on the platform side using whatever the standard logger is, e.g.,
  /// `Log` on Android and `print` on iOS. Defaults to `false`.
  Future<void> enablePlatformLogging({bool sendPlatformLogsToDart = false}) async {
    await _methodChannel.invokeMethod("startLogging", {"sendPlatformLogsToDart": sendPlatformLogsToDart});
  }

  /// Disable platform-side logging, e.g., iOS logs.
  Future<void> disablePlatformLogging() async {
    await _methodChannel.invokeMethod("stopLogging");
  }

  ValueListenable<MobileWindowGeometry> get geometry => _geometry;
  final _geometry = ValueNotifier<MobileWindowGeometry>(const MobileWindowGeometry());

  final _listeners = <SuperKeyboardIOSListener>{};
  void addListener(SuperKeyboardIOSListener listener) => _listeners.add(listener);
  void removeListener(SuperKeyboardIOSListener listener) => _listeners.remove(listener);

  Future<void> _onPlatformMessage(MethodCall message) async {
    // assert(() {
    //   SKLog.ios.fine("iOS platform message: '${message.method}', args: ${message.arguments}");
    //   return true;
    // }());

    switch (message.method) {
      case "keyboardWillShow":
        _geometry.value = _geometry.value.updateWith(
          MobileWindowGeometry(
            keyboardState: KeyboardState.opening,
            keyboardHeight: (message.arguments?["keyboardHeight"] as num?)?.toDouble(),
            bottomPadding: (message.arguments?["bottomPadding"] as num?)?.toDouble(),
          ),
        );

        for (final listener in _listeners) {
          listener.onKeyboardWillShow();
        }
        break;
      case "keyboardDidShow":
        _geometry.value = _geometry.value.updateWith(
          MobileWindowGeometry(
            keyboardState: KeyboardState.open,
            keyboardHeight: (message.arguments?["keyboardHeight"] as num?)?.toDouble(),
            bottomPadding: (message.arguments?["bottomPadding"] as num?)?.toDouble(),
          ),
        );

        for (final listener in _listeners) {
          listener.onKeyboardDidShow();
        }
        break;
      case "keyboardWillChangeFrame":
        break;
      case "keyboardWillHide":
        _geometry.value = _geometry.value.updateWith(
          MobileWindowGeometry(
            keyboardState: KeyboardState.closing,
            keyboardHeight: (message.arguments?["keyboardHeight"] as num?)?.toDouble(),
            bottomPadding: (message.arguments?["bottomPadding"] as num?)?.toDouble(),
          ),
        );

        for (final listener in _listeners) {
          listener.onKeyboardWillHide();
        }
        break;
      case "keyboardDidHide":
        _geometry.value = _geometry.value.updateWith(
          MobileWindowGeometry(
            keyboardState: KeyboardState.closed,
            keyboardHeight: (message.arguments?["keyboardHeight"] as num?)?.toDouble(),
            bottomPadding: (message.arguments?["bottomPadding"] as num?)?.toDouble(),
          ),
        );

        for (final listener in _listeners) {
          listener.onKeyboardDidHide();
        }
        break;
      case "log":
        _printIOSLog(message);
        break;
    }
  }

  void _printIOSLog(MethodCall channelMessage) {
    final logMessage = "SK iOS: ${channelMessage.arguments["message"] ?? "EMPTY MESSAGE"}";
    SKLog.ios.info(logMessage);
  }
}

abstract interface class SuperKeyboardIOSListener {
  void onKeyboardWillShow();
  void onKeyboardDidShow();
  void onKeyboardWillHide();
  void onKeyboardDidHide();
}
