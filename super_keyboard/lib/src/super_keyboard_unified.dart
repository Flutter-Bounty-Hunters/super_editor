import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:super_keyboard/src/keyboard.dart';
import 'package:super_keyboard/src/logging.dart';
import 'package:super_keyboard/src/super_keyboard_android.dart';
import 'package:super_keyboard/src/super_keyboard_ios.dart';

/// A widget that rebuilds whenever the window geometry changes in a way that's
/// relevant to the software keyboard.
class SuperKeyboardBuilder extends StatefulWidget {
  const SuperKeyboardBuilder({
    super.key,
    required this.builder,
  });

  final Widget Function(BuildContext, MobileWindowGeometry) builder;

  @override
  State<SuperKeyboardBuilder> createState() => _SuperKeyboardBuilderState();
}

class _SuperKeyboardBuilderState extends State<SuperKeyboardBuilder> {
  @override
  void initState() {
    super.initState();
    SuperKeyboard.instance.mobileGeometry.addListener(_onKeyboardStateChange);
  }

  @override
  void dispose() {
    SuperKeyboard.instance.mobileGeometry.removeListener(_onKeyboardStateChange);
    super.dispose();
  }

  void _onKeyboardStateChange() {
    setState(() {
      // Re-build.
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      SuperKeyboard.instance.mobileGeometry.value,
    );
  }
}

/// A unified API for tracking the software keyboard status, regardless of platform.
class SuperKeyboard {
  static SuperKeyboard? _instance;
  static SuperKeyboard get instance {
    _instance ??= SuperKeyboard._();
    return _instance!;
  }

  @visibleForTesting
  static set testInstance(SuperKeyboard? testInstance) => _instance = testInstance;

  SuperKeyboard._() {
    _init();
  }

  void _init() {
    SKLog.unified.info("Initializing SuperKeyboard");
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      SKLog.unified.fine("SuperKeyboard - Initializing for iOS");
      SuperKeyboardIOS.instance.geometry.addListener(_onIOSWindowGeometryChange);
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      SKLog.unified.fine("SuperKeyboard - Initializing for Android");
      SuperKeyboardAndroid.instance.geometry.addListener(_onAndroidWindowGeometryChange);
    }
  }

  /// Enable/disable platform-side logging, e.g., Android or iOS logs.
  ///
  /// These logs are distinct from Flutter-side logs, which are controlled
  /// by [startLogging].
  Future<void> enablePlatformLogging(bool isEnabled) async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      SKLog.unified.fine("SuperKeyboard - ${isEnabled ? "Enabling" : "Disabling"} logs for iOS.");
      if (isEnabled) {
        await SuperKeyboardIOS.instance.enablePlatformLogging(sendPlatformLogsToDart: true);
      } else {
        await SuperKeyboardIOS.instance.disablePlatformLogging();
      }
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      SKLog.unified.fine("SuperKeyboard - ${isEnabled ? "Enabling" : "Disabling"} logs for Android.");
      if (isEnabled) {
        await SuperKeyboardAndroid.instance.enablePlatformLogging(sendPlatformLogsToDart: true);
      } else {
        await SuperKeyboardAndroid.instance.disablePlatformLogging();
      }
    }
  }

  ValueListenable<MobileWindowGeometry> get mobileGeometry => _mobileGeometry;
  final _mobileGeometry = ValueNotifier<MobileWindowGeometry>(const MobileWindowGeometry());

  void _onIOSWindowGeometryChange() {
    _mobileGeometry.value = SuperKeyboardIOS.instance.geometry.value;
  }

  void _onAndroidWindowGeometryChange() {
    _mobileGeometry.value = SuperKeyboardAndroid.instance.geometry.value;
  }
}
