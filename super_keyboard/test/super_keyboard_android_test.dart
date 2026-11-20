import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_keyboard/src/super_keyboard_android.dart';

void main() {
  group("SuperKeyboardAndroid > getActiveKeyboardId >", () {
    const channel = MethodChannel('super_keyboard_android');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    testWidgets("returns the active IME ID reported by the platform", (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == "getActiveKeyboardId") {
          return "com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME";
        }
        return null;
      });

      final imeId = await SuperKeyboardAndroid.instance.getActiveKeyboardId();

      expect(imeId, "com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME");

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets("returns null when the platform can't determine the active IME", (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == "getActiveKeyboardId") {
          return null;
        }
        return null;
      });

      final imeId = await SuperKeyboardAndroid.instance.getActiveKeyboardId();

      expect(imeId, isNull);

      debugDefaultTargetPlatformOverride = null;
    });
  });
}
