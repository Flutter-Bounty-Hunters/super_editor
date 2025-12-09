import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor_test.dart';

void main() {
  group('SuperReader > phone rotation >', () {
    const screenSizePortrait = Size(400.0, 1000.0);
    const screenSizeLandscape = Size(1000.0, 400);

    testWidgetsOnMobile('does not crash the app when there is no selection', (tester) async {
      // Start the test in portrait mode.
      tester.view
        ..devicePixelRatio = 1.0
        ..platformDispatcher.textScaleFactorTestValue = 1.0
        ..physicalSize = screenSizePortrait;

      addTearDown(() => tester.platformDispatcher.clearAllTestValues());

      await tester //
          .createDocument()
          .withSingleParagraph()
          .pump();

      // Simulate a phone rotation.
      tester.view.physicalSize = screenSizeLandscape;
      await tester.pumpAndSettle();

      // Reaching this point means the reader didn't crash.
    });

    testWidgetsOnMobile('does not crash the app when the selection is collapsed', (tester) async {
      // Start the test in portrait mode.
      tester.view
        ..devicePixelRatio = 1.0
        ..platformDispatcher.textScaleFactorTestValue = 1.0
        ..physicalSize = screenSizePortrait;
      addTearDown(() => tester.platformDispatcher.clearAllTestValues());

      await tester //
          .createDocument()
          .withSingleParagraph()
          .pump();

      // Place the caret at the beginning of the document.
      await tester.placeCaretInParagraph('1', 0);

      // Simulate a phone rotation.
      tester.view.physicalSize = screenSizeLandscape;
      await tester.pumpAndSettle();

      // Reaching this point means the reader didn't crash.
    });

    testWidgetsOnMobile('does not crash the app when the selection is expanded', (tester) async {
      // Start the test in portrait mode.
      tester.view
        ..devicePixelRatio = 1.0
        ..platformDispatcher.textScaleFactorTestValue = 1.0
        ..physicalSize = screenSizePortrait;
      addTearDown(() => tester.platformDispatcher.clearAllTestValues());

      await tester //
          .createDocument()
          .withSingleParagraph()
          .pump();

      // Double tap to select the first word.
      await tester.doubleTapInParagraph('1', 0);

      // Simulate a phone rotation.
      tester.view.physicalSize = screenSizeLandscape;
      await tester.pumpAndSettle();

      // Reaching this point means the reader didn't crash.
    });
  });
}
