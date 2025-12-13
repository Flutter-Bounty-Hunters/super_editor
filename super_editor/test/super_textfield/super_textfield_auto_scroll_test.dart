import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:meta/meta.dart';
import 'package:super_editor/src/super_textfield/metrics.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_text_field_test.dart';

const screenSizeWithoutKeyboard = Size(400, 800);
const screenSizeWithKeyboard = Size(400, 300);

void main() {
  group('SuperTextField', () {
    group('on mobile with an ancestor Scrollable', () {
      _testWidgetsOnMobileWithKeyboard('auto scrolls when focused in single-line', (tester, keyboardToggle) async {
        await _pumpTestApp(
          tester,
          text: 'Single line SuperTextField',
          lineCount: 1,
        );

        // Tap to focus the text field
        await tester.tapAt(tester.getCenter(find.byType(SuperTextField)));
        await tester.pumpAndSettle();

        // Simulate a keyboard opening, which reduces available screen height.
        await keyboardToggle.open();

        // Find the global offset where the selection is
        final selectionOffset = _findGlobalCaretOffset(tester);

        // Ensure selection is visible in the viewport
        expect(selectionOffset.dy.floor(), lessThanOrEqualTo(screenSizeWithKeyboard.height));

        // Ensure we scroll only the necessary to reveal the selection, plus a small gap
        expect(
            screenSizeWithKeyboard.height - selectionOffset.dy.floor(), lessThanOrEqualTo(gapBetweenCaretAndKeyboard));

        // Ensure selection doesn't scroll beyond the top
        expect(selectionOffset.dy.floor(), greaterThanOrEqualTo(0));
      });

      _testWidgetsOnMobileWithKeyboard('auto scrolls when focused in single-line', (tester, keyboardToggle) async {
        await _pumpTestApp(
          tester,
          text: 'Single line SuperTextField',
          lineCount: 1,
        );

        // Tap to focus the text field
        await tester.tapAt(tester.getCenter(find.byType(SuperTextField)));
        await tester.pumpAndSettle();

        // Simulate a keyboard opening, which reduces available screen height.
        await keyboardToggle.open();

        // Find the global offset where the selection is
        final selectionOffset = _findGlobalCaretOffset(tester);

        // Ensure selection is visible in the viewport
        expect(selectionOffset.dy.floor(), lessThanOrEqualTo(screenSizeWithKeyboard.height));

        // Ensure we scroll only the necessary to reveal the selection, plus a small gap
        expect(
            screenSizeWithKeyboard.height - selectionOffset.dy.floor(), lessThanOrEqualTo(gapBetweenCaretAndKeyboard));

        // Ensure selection doesn't scroll beyond the top
        expect(selectionOffset.dy.floor(), greaterThanOrEqualTo(0));
      });

      _testWidgetsOnMobileWithKeyboard('auto scrolls when focused in multi-line', (tester, keyboardToggle) async {
        await _pumpTestApp(
          tester,
          text: 'This is\na multiline\nSuperTextField',
          lineCount: 3,
        );

        // Tap to focus to the text field
        await tester.tapAt(tester.getCenter(find.byType(SuperTextField)));
        await tester.pumpAndSettle();

        // Simulate a keyboard opening, which reduces available screen height.
        await keyboardToggle.open();

        // Find the offset of the selected line
        final selectionOffset = _findGlobalCaretOffset(tester);

        // Ensure selected line is visible on viewport
        expect(selectionOffset.dy.floor(), lessThanOrEqualTo(screenSizeWithKeyboard.height));

        // Ensure we scroll only the necessary to reveal the selection, plus a small gap
        expect(
            screenSizeWithKeyboard.height - selectionOffset.dy.floor(), lessThanOrEqualTo(gapBetweenCaretAndKeyboard));

        // Ensure selection doesn't scroll beyond the top
        expect(selectionOffset.dy.floor(), greaterThanOrEqualTo(0));
      });

      _testWidgetsOnMobileWithKeyboard('doest not auto scroll when not focused', (tester, keyboardToggle) async {
        await _pumpTestApp(
          tester,
          text: 'Single line SuperTextField',
          lineCount: 1,
        );

        // Position of the text field before resizing
        final initialTopLeft = tester.getTopLeft(find.byType(SuperTextField));

        // Simulate a keyboard opening, which reduces available screen height.
        await keyboardToggle.open();

        // Position of the text field after resizing
        final finalTopLeft = tester.getTopLeft(find.byType(SuperTextField, skipOffstage: false));

        // Ensure the text field does not cause autoscroll
        expect(finalTopLeft, initialTopLeft);
      });
    });

    testWidgetsOnAllPlatforms('auto scroll doesn\'t crash when text is empty', (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText('Text before'),
      );

      await _pumpScaffold(
        tester,
        SuperTextField(
          textController: controller,
        ),
      );

      // Place caret at the end of the text field.
      await tester.placeCaretInSuperTextField(11);

      // Clear the text and changes the selection to the beginning of the text.
      controller.updateTextAndSelection(
        text: AttributedText(),
        selection: const TextSelection.collapsed(offset: 0),
      );
      await tester.pump();

      /// When text or selection changes, we auto scroll to ensure that the selecion is visible.
      /// To do so, we need to get the bounds of the character at the selection extent.
      ///
      /// If we attempt to auto scroll when the text is empty, a crash happens because there isn't a
      /// character at the selection extent.
      ///
      /// Reaching this point means we didn't attempt to auto scroll after clearing the text.
    });
  });
}

Future<void> _pumpTestApp(
  WidgetTester tester, {
  required String text,
  required int lineCount,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            ...List.generate(8, (index) => const ListTile(title: Text("BEFORE"))),
            SuperTextField(
              minLines: lineCount,
              maxLines: lineCount,
              lineHeight: 24,
              textController: AttributedTextEditingController(
                text: AttributedText(text),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // A SuperTextField configured with maxLines can't render in the first frame.
  // Ask another frame, so the text field can be found by the finder.
  await tester.pump();
}

/// Pumps a scaffold with a centered [child].
Future<void> _pumpScaffold(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            child: child,
          ),
        ),
      ),
    ),
  );
}

@isTestGroup
void _testWidgetsOnMobileWithKeyboard(
  String description,
  Future<void> Function(WidgetTester tester, _KeyboardToggle keyboardToggle) test,
) {
  testWidgetsOnMobile(description, (tester) async {
    tester.view
      ..physicalSize = screenSizeWithoutKeyboard
      ..platformDispatcher.textScaleFactorTestValue = 1.0
      ..devicePixelRatio = 1.0;
    addTearDown(() => tester.platformDispatcher.clearAllTestValues());

    final keyboardToggle = _KeyboardToggle(
      tester: tester,
      sizeWithoutKeyboard: screenSizeWithoutKeyboard,
      sizeWithKeyboard: screenSizeWithKeyboard,
    );

    await test(tester, keyboardToggle);
  });
}

class _KeyboardToggle {
  _KeyboardToggle({
    required this.tester,
    required this.sizeWithoutKeyboard,
    required this.sizeWithKeyboard,
    // TODO(srawlins): `unused_element`, when reporting a parameter, is being
    // renamed to `unused_element_parameter`. For now, ignore each; when the SDK
    // constraint is >= 3.6.0, just ignore `unused_element_parameter`.
    // ignore: unused_element, unused_element_parameter
    this.frameCount = 60,
  });

  final WidgetTester tester;
  final Size sizeWithoutKeyboard;
  final Size sizeWithKeyboard;
  final int frameCount;

  Future<void> open() async {
    double resizedWidth = 0.0;
    double resizedHeight = 0.0;
    double totalWidthResize = sizeWithoutKeyboard.width - sizeWithKeyboard.width;
    double totalHeightResize = sizeWithoutKeyboard.height - sizeWithKeyboard.height;
    double widthShrinkPerFrame = totalWidthResize / frameCount;
    double heightShrinkPerFrame = totalHeightResize / frameCount;
    for (var i = 0; i < frameCount; i++) {
      resizedWidth += widthShrinkPerFrame;
      resizedHeight += heightShrinkPerFrame;
      final currentScreenSize = (sizeWithoutKeyboard - Offset(resizedWidth, resizedHeight)) as Size;
      tester.view.physicalSize = currentScreenSize;
      await tester.pumpAndSettle();
    }
  }
}

Offset _findGlobalCaretOffset(WidgetTester tester) {
  final customPaint = find.byWidgetPredicate((widget) => widget is CustomPaint && widget.painter is CaretPainter);
  final caretPainter = tester.widget<CustomPaint>(customPaint.last).painter as CaretPainter;
  return tester.getTopLeft(customPaint) + caretPainter.offset!;
}
