import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_reader_test.dart';

import '../test_runners.dart';

void main() {
  group('SuperReader keyboard >', () {
    testWidgetsOnDesktop("copies text regardless of key order", (tester) async {
      final testContext = await tester //
          .createDocument()
          .fromMarkdown("This is some testing text.") // Length is 26
          .autoFocus(true)
          .pump();

      // Select "This".
      final nodeId = testContext.documentContext.document.first.id;
      await tester.doubleTapInParagraph(nodeId, 1);

      // Press the "copy" shortcut in the standard key order.
      tester.simulateClipboard();
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        await tester.pressCmdC();
      } else {
        await tester.pressCtlC();
      }

      // Ensure that "This" was copied.
      expect(tester.getSimulatedClipboardContent(), "This");

      // Select "testing".
      //
      // When I wrote this test, double tapping to select another word wasn't
      // working. Maybe there's some overlay from the earlier word selection.
      // To get rid of whatever it is, we collapse the selection with the arrow
      // key and then double tap after that to select a different word.
      await tester.pressRightArrow();
      await tester.doubleTapInParagraph(nodeId, 16);

      // Press the "copy" shortcut, but release "CMD" before "C", which
      // sometimes happens by accident with human users.
      final keyEventPlatform = switch (defaultTargetPlatform) {
        TargetPlatform.macOS => "macos",
        TargetPlatform.windows => "windows",
        TargetPlatform.linux => "linux",
        TargetPlatform.fuchsia => "linux",
        TargetPlatform.android => throw UnimplementedError(),
        TargetPlatform.iOS => throw UnimplementedError(),
      };

      if (defaultTargetPlatform == TargetPlatform.macOS) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.meta, platform: keyEventPlatform);
      } else {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft, platform: keyEventPlatform);
      }
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyC, platform: keyEventPlatform);
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        await tester.sendKeyUpEvent(LogicalKeyboardKey.meta, platform: keyEventPlatform);
      } else {
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft, platform: keyEventPlatform);
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyC, platform: keyEventPlatform);
      await tester.pumpAndSettle();

      // Ensure that "testing" was copied.
      expect(tester.getSimulatedClipboardContent(), "testing");
    });

    group('moves selection >', () {
      testAllInputsOnDesktop("left by one character and expands when SHIFT + LEFT_ARROW is pressed", (
        tester, {
        required TextInputSource inputSource,
      }) async {
        final nodeId = await _pumpSingleLineAndSelectAWord(tester, offset: 10, inputSource: inputSource);
        expect(SuperReaderInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 8, to: 12));

        await tester.pressShiftLeftArrow();

        expect(SuperReaderInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 8, to: 11));
      });

      testAllInputsOnDesktop("right by one character and expands when SHIFT + RIGHT_ARROW is pressed", (
        tester, {
        required TextInputSource inputSource,
      }) async {
        final nodeId = await _pumpSingleLineAndSelectAWord(tester, offset: 10, inputSource: inputSource);
        expect(SuperReaderInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 8, to: 12));

        await tester.pressShiftRightArrow();

        expect(SuperReaderInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 8, to: 13));
      });

      testAllInputsOnApple("to beginning of word and expands when SHIFT + ALT + LEFT_ARROW is pressed", (
        tester, {
        required TextInputSource inputSource,
      }) async {
        final nodeId = await _pumpSingleLineAndSelectAWord(tester, offset: 10, inputSource: inputSource);
        expect(SuperReaderInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 8, to: 12));

        // Jump upstream by two words. We jump two words instead of one, because our
        // initial selection is pointing downstream. If we only jump upstream by one word
        // then the selection will collapse and disappear. Ideally, we would start with
        // an expanded upstream selection, but we don't currently have tools to drag a
        // text selection on all platforms.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
        await tester.pressAltLeftArrow();
        await tester.pressAltLeftArrow();
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);

        // Ensure that we jumped upstream by two words.
        expect(
          SuperReaderInspector.findDocumentSelection(),
          _selectionInParagraph(nodeId, from: 8, to: 5, toAffinity: TextAffinity.downstream),
        );
      });

      testAllInputsOnApple("to end of word and expands when SHIFT + ALT + RIGHT_ARROW is pressed", (
        tester, {
        required TextInputSource inputSource,
      }) async {
        final nodeId = await _pumpSingleLineAndSelectAWord(tester, offset: 10, inputSource: inputSource);
        expect(SuperReaderInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 8, to: 12));

        await tester.pressShiftAltRightArrow();

        expect(SuperReaderInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 8, to: 20));
      });

      testAllInputsOnApple("to beginning of line and expands when SHIFT + CMD + LEFT_ARROW is pressed", (
        tester, {
        required TextInputSource inputSource,
      }) async {
        final nodeId = await _pumpSingleLineAndSelectAWord(tester, offset: 10, inputSource: inputSource);
        expect(SuperReaderInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 8, to: 12));

        await tester.pressShiftCmdLeftArrow();

        expect(SuperReaderInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 8, to: 0));
      });

      testAllInputsOnApple("to end of line and expands when SHIFT + CMD + RIGHT_ARROW is pressed", (
        tester, {
        required TextInputSource inputSource,
      }) async {
        final nodeId = await _pumpSingleLineAndSelectAWord(tester, offset: 10, inputSource: inputSource);
        expect(SuperReaderInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 8, to: 12));

        await tester.pressShiftCmdRightArrow();

        expect(
          SuperReaderInspector.findDocumentSelection(),
          _selectionInParagraph(nodeId, from: 8, to: 26, toAffinity: TextAffinity.upstream),
        );
      });

      testAllInputsOnWindowsAndLinux("to beginning of word and expands when SHIFT + CTL + LEFT_ARROW is pressed", (
        tester, {
        required TextInputSource inputSource,
      }) async {
        final nodeId = await _pumpSingleLineAndSelectAWord(tester, offset: 10, inputSource: inputSource);
        expect(SuperReaderInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 8, to: 12));

        // Jump upstream by two words. We jump two words instead of one, because our
        // initial selection is pointing downstream. If we only jump upstream by one word
        // then the selection will collapse and disappear. Ideally, we would start with
        // an expanded upstream selection, but we don't currently have tools to drag a
        // text selection on all platforms.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
        await tester.pressCtlLeftArrow();
        await tester.pressCtlLeftArrow();
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);

        // Ensure that we jumped upstream by two words.
        expect(
          SuperReaderInspector.findDocumentSelection(),
          _selectionInParagraph(nodeId, from: 8, to: 5, toAffinity: TextAffinity.downstream),
        );
      });

      testAllInputsOnWindowsAndLinux("to end of word and expands when SHIFT + CTL + RIGHT_ARROW is pressed", (
        tester, {
        required TextInputSource inputSource,
      }) async {
        final nodeId = await _pumpSingleLineAndSelectAWord(tester, offset: 10, inputSource: inputSource);
        expect(SuperReaderInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 8, to: 12));

        await tester.pressShiftCtlRightArrow();

        expect(SuperReaderInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 8, to: 20));
      });

      testAllInputsOnDesktop("up one line and expands when SHIFT + UP_ARROW is pressed", (
        tester, {
        required TextInputSource inputSource,
      }) async {
        final nodeId = await _pumpDoubleLine(tester, offset: 44, inputSource: inputSource);
        expect(SuperReaderInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 41, to: 47));

        await tester.pressShiftUpArrow();

        expect(SuperReaderInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 41, to: 18));
      });

      testAllInputsOnDesktop("down one line and expands when SHIFT + DOWN_ARROW is pressed", (
        tester, {
        required TextInputSource inputSource,
      }) async {
        final nodeId = await _pumpDoubleLine(tester, offset: 12, inputSource: inputSource);
        expect(SuperReaderInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 12, to: 17));

        await tester.pressShiftDownArrow();

        expect(SuperReaderInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 12, to: 46));
      });

      testAllInputsOnDesktop("to beginning of line and expands when SHIFT + UP_ARROW is pressed at top of document", (
        tester, {
        required TextInputSource inputSource,
      }) async {
        final nodeId = await _pumpDoubleLine(tester, offset: 12, inputSource: inputSource);
        expect(SuperReaderInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 12, to: 17));

        await tester.pressShiftUpArrow();

        expect(SuperReaderInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 12, to: 0));
      });

      testAllInputsOnDesktop("end of line and expands when SHIFT + DOWN_ARROW is pressed at end of document", (
        tester, {
        required TextInputSource inputSource,
      }) async {
        final nodeId = await _pumpDoubleLine(tester, offset: 41, inputSource: inputSource);
        expect(SuperReaderInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 41, to: 47));

        await tester.pressShiftDownArrow();

        expect(SuperReaderInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 41, to: 58));
      });
    });

    testAllInputsOnApple("and removes selection when it collapses without holding the SHIFT key", (
      tester, {
      required TextInputSource inputSource,
    }) async {
      final nodeId = await _pumpSingleLineAndSelectAWord(tester, offset: 10, inputSource: inputSource);
      expect(SuperReaderInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 8, to: 12));

      // Hold shift and move the caret to the beginning of the selected word, which
      // collapses the selection. Release the shift key pressed, which should check
      // the selection, see that it's collapsed, and then remove it.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.pressAltLeftArrow();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);

      // Ensure that the selection is gone.
      expect(
        SuperReaderInspector.findDocumentSelection(),
        null,
      );
    });

    testAllInputsOnWindowsAndLinux("and removes selection when it collapses without holding the SHIFT key", (
      tester, {
      required TextInputSource inputSource,
    }) async {
      final nodeId = await _pumpSingleLineAndSelectAWord(tester, offset: 10, inputSource: inputSource);
      expect(SuperReaderInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 8, to: 12));

      // Hold shift and move the caret to the beginning of the selected word, which
      // collapses the selection. Release the shift key pressed, which should check
      // the selection, see that it's collapsed, and then remove it.
      await tester.pressKeyDown(LogicalKeyboardKey.shift);
      await tester.pressCtlLeftArrow();
      await tester.releaseKeyUp(LogicalKeyboardKey.shift);

      // Ensure that the selection is gone.
      expect(
        SuperReaderInspector.findDocumentSelection(),
        null,
      );
    });

    testAllInputsOnApple("and retains the selection when collapsed and the SHIFT key is pressed", (
      tester, {
      required TextInputSource inputSource,
    }) async {
      final nodeId = await _pumpSingleLineAndSelectAWord(tester, offset: 10, inputSource: inputSource);
      expect(SuperReaderInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 8, to: 12));

      // Hold shift and move the caret to the beginning of the selected word, which
      // collapses the selection. Keep the shift key pressed, which should retain
      // the selection while collapsed.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.pressAltLeftArrow();

      // Ensure that the collapsed selection is retained.
      expect(
        SuperReaderInspector.findDocumentSelection(),
        _selectionInParagraph(nodeId, from: 8, to: 8, toAffinity: TextAffinity.downstream),
      );
    });

    testAllInputsOnWindowsAndLinux("and retains the selection when collapsed and the SHIFT key is pressed", (
      tester, {
      required TextInputSource inputSource,
    }) async {
      final nodeId = await _pumpSingleLineAndSelectAWord(tester, offset: 10, inputSource: inputSource);
      expect(SuperReaderInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 8, to: 12));

      // Hold shift and move the caret to the beginning of the selected word, which
      // collapses the selection. Keep the shift key pressed, which should retain
      // the selection while collapsed.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.pressCtlLeftArrow();

      // Ensure that the collapsed selection is retained.
      expect(
        SuperReaderInspector.findDocumentSelection(),
        _selectionInParagraph(nodeId, from: 8, to: 8, toAffinity: TextAffinity.downstream),
      );
    });
  });
}

Future<String> _pumpSingleLineAndSelectAWord(
  WidgetTester tester, {
  required int offset,
  required TextInputSource inputSource,
}) async {
  final testContext = await tester //
      .createDocument()
      .fromMarkdown("This is some testing text.") // Length is 26
      .autoFocus(true)
      .pump();

  final nodeId = testContext.documentContext.document.first.id;

  await tester.doubleTapInParagraph(nodeId, offset);

  return nodeId;
}

Future<String> _pumpDoubleLine(
  WidgetTester tester, {
  required int offset,
  required TextInputSource inputSource,
}) async {
  final testContext = await tester //
      .createDocument()
      // Text indices:
      // - first line: [0, 28] -> "first" word is [12, 17)
      // - newline: 29
      // - second line: [30, 58] -> "second" word is [41, 47)
      .fromMarkdown("This is the first paragraph.\nThis is the second paragraph.")
      .autoFocus(true)
      .pump();

  final nodeId = testContext.documentContext.document.first.id;

  await tester.doubleTapInParagraph(nodeId, offset);

  return nodeId;
}

DocumentSelection _selectionInParagraph(
  String nodeId, {
  required int from,
  TextAffinity fromAffinity = TextAffinity.downstream,
  required int to,
  TextAffinity toAffinity = TextAffinity.downstream,
}) {
  return DocumentSelection(
    base: DocumentPosition(nodeId: nodeId, nodePosition: TextNodePosition(offset: from, affinity: fromAffinity)),
    extent: DocumentPosition(nodeId: nodeId, nodePosition: TextNodePosition(offset: to, affinity: toAffinity)),
  );
}
