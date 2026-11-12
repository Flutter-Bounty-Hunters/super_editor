import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group('SuperTextField', () {
    setUpAll(() async {
      // We need to load the app fonts, because using Ahem the estimated line height
      // is always equal to the true line height.
      //
      // Fonts are loaded before the test, rather than within it, because loading fonts
      // causes a "fontsChange" system message to arrive asynchronously, which schedules
      // a frame callback. If that happens within the test, the callback can still be
      // pending when the test ends, which fails the test.
      await loadAppFonts();
    });

    testWidgetsOnArbitraryDesktop('computes line height for empty field', (tester) async {
      // Pump an empty SuperTextField containing a hint text.
      final controller = AttributedTextEditingController();
      await _pumpScaffold(tester, controller: controller);
      await tester.pumpAndSettle();

      // When the text field is displaying only the hint, the line height is estimated.
      final heightWithHintText = tester.getSize(find.byType(SuperTextField)).height;

      // Change the text, this should recompute viewport height.
      controller.text = AttributedText('Leave a message');
      await tester.pumpAndSettle();

      // When the text field has content the line height should be the true line height.
      final heightWithText = tester.getSize(find.byType(SuperTextField)).height;

      // Ensure the text field has ~ the same height when it's empty and when it has content
      expect((heightWithHintText - heightWithText).abs(), lessThanOrEqualTo(3e-1));
    });
  });
}

Future<void> _pumpScaffold(WidgetTester tester, {required AttributedTextEditingController controller}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SuperTextField(
          textController: controller,
          hintBuilder: (context) {
            return const Text(
              'Leave a message',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
                fontFamily: 'Roboto',
              ),
            );
          },
          hintBehavior: HintBehavior.displayHintUntilTextEntered,
          minLines: 1,
          maxLines: null,
          textStyleBuilder: (_) => const TextStyle(
            fontSize: 16,
            fontFamily: 'Roboto',
          ),
        ),
      ),
    ),
  );
}
