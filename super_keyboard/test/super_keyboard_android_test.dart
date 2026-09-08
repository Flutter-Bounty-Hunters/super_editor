import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_keyboard/super_keyboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("SuperKeyboard Android >", () {
    const channel = MethodChannel('super_keyboard_android');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    });

    test("getActiveIme returns active IME ID from Android platform", () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (MethodCall methodCall) async {
            if (methodCall.method == 'getActiveIme') {
              return 'com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME';
            }
            return null;
          },
        );

        final ime = await SuperKeyboardAndroid.instance.getActiveIme();
        expect(ime, 'com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME');

        final unifiedIme = await SuperKeyboard.instance.getActiveIme();
        expect(unifiedIme, 'com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test("getActiveIme returns null on non-Android platform in unified API", () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final unifiedIme = await SuperKeyboard.instance.getActiveIme();
        expect(unifiedIme, isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
