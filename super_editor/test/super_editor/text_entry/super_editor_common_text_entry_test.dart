import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

void main() {
  group("SuperEditor common text entry >", () {
    testWidgetsOnDesktop("control keys don't impact content", (tester) async {
      await _pumpApp(tester, _desktopInputSourceAndControlKeyVariant.currentValue!.inputSource);

      final initialParagraphText = SuperEditorInspector.findTextInComponent("1");

      // Select some content -> "Lorem |ipsum| dolor sit..."
      await tester.doubleTapInParagraph("1", 8);
      const expectedSelection = DocumentSelection(
        base: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 6)),
        extent: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 11)),
      );
      expect(SuperEditorInspector.findDocumentSelection(), expectedSelection);

      // Press a control key.
      await tester.sendKeyEvent(
        _desktopInputSourceAndControlKeyVariant.currentValue!.controlKey,
        platform: _platformNames[defaultTargetPlatform]!,
      );

      // Make sure the content and selection remains the same.
      expect(SuperEditorInspector.findTextInComponent("1"), initialParagraphText);
      expect(SuperEditorInspector.findDocumentSelection(), expectedSelection);
    }, variant: _desktopInputSourceAndControlKeyVariant);

    testWidgetsOnMobile("control keys don't impact content", (tester) async {
      await _pumpApp(tester, _mobileInputSourceAndControlKeyVariant.currentValue!.inputSource);

      final initialParagraphText = SuperEditorInspector.findTextInComponent("1");

      // Select some content -> "Lorem |ipsum| dolor sit..."
      await tester.doubleTapInParagraph("1", 8);
      const expectedSelection = DocumentSelection(
        base: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 6)),
        extent: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 11)),
      );
      expect(SuperEditorInspector.findDocumentSelection(), expectedSelection);

      // Press a control key.
      await tester.sendKeyEvent(
        _mobileInputSourceAndControlKeyVariant.currentValue!.controlKey,
        platform: _platformNames[defaultTargetPlatform]!,
      );

      // Make sure the content and selection remains the same.
      expect(SuperEditorInspector.findTextInComponent("1"), initialParagraphText);
      expect(SuperEditorInspector.findDocumentSelection(), expectedSelection);
    }, variant: _mobileInputSourceAndControlKeyVariant);
  });
}

Future<void> _pumpApp(WidgetTester tester, TextInputSource inputSource) async {
  await tester //
      .createDocument()
      .withSingleParagraph()
      .withInputSource(inputSource)
      .withCustomWidgetTreeBuilder((superEditor) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            // Add focusable widgets before and after SuperEditor so that we
            // catch any keys that try to move focus forward or backward.
            const Focus(child: SizedBox(width: double.infinity, height: 54)),
            Expanded(
              child: superEditor,
            ),
            const Focus(child: SizedBox(width: double.infinity, height: 54)),
          ],
        ),
      ),
    );
  }).pump();
}

final _mobileInputSourceAndControlKeyVariant = ValueVariant({
  for (final inputSource in TextInputSource.values)
    for (final controlKey in _allPlatformControlKeys) //
      _InputSourceAndControlKey(inputSource, controlKey),
});

final _desktopInputSourceAndControlKeyVariant = ValueVariant({
  for (final inputSource in TextInputSource.values)
    for (final controlKey in _desktopControlKeys) //
      _InputSourceAndControlKey(inputSource, controlKey),
});

// TODO: Replace raw strings with constants when Flutter offers them (https://github.com/flutter/flutter/issues/133295)
final _platformNames = {
  TargetPlatform.android: "android",
  TargetPlatform.iOS: "ios",
  TargetPlatform.macOS: "macos",
  TargetPlatform.windows: "windows",
  TargetPlatform.linux: "linux",
};

class _InputSourceAndControlKey {
  _InputSourceAndControlKey(
    this.inputSource,
    this.controlKey,
  );

  final TextInputSource inputSource;
  final LogicalKeyboardKey controlKey;

  @override
  String toString() => "$inputSource, ${controlKey.keyLabel}";
}

final _allPlatformControlKeys = {
  LogicalKeyboardKey.capsLock,
  LogicalKeyboardKey.shift,
  LogicalKeyboardKey.control,
  LogicalKeyboardKey.controlLeft,
  LogicalKeyboardKey.controlRight,
  LogicalKeyboardKey.meta,
  LogicalKeyboardKey.metaLeft,
  LogicalKeyboardKey.metaRight,
  LogicalKeyboardKey.alt,
  LogicalKeyboardKey.altLeft,
  LogicalKeyboardKey.altRight,
  LogicalKeyboardKey.f1,
  LogicalKeyboardKey.f2,
  LogicalKeyboardKey.f3,
  LogicalKeyboardKey.f4,
  LogicalKeyboardKey.f5,
  LogicalKeyboardKey.f6,
  LogicalKeyboardKey.f7,
  LogicalKeyboardKey.f8,
  LogicalKeyboardKey.f9,
  LogicalKeyboardKey.f10,
  LogicalKeyboardKey.f11,
  LogicalKeyboardKey.f12,
};

// Apparently Flutter blows up if you simulate certain keys on mobile. Those
// keys are separated here as desktop-only control keys.
final _desktopControlKeys = {
  ..._allPlatformControlKeys,
  LogicalKeyboardKey.f13,
  LogicalKeyboardKey.f14,
  LogicalKeyboardKey.f15,
  LogicalKeyboardKey.f16,
  LogicalKeyboardKey.f17,
  LogicalKeyboardKey.f18,
  LogicalKeyboardKey.f19,
  LogicalKeyboardKey.f20,
  // The following keys don't appear to be supported on desktop as of Aug 24, 2023.
  // LogicalKeyboardKey.f21,
  // LogicalKeyboardKey.f22,
  // LogicalKeyboardKey.f23,
  // LogicalKeyboardKey.f24,
};
