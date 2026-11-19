import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_text_layout/super_text_layout.dart';

import 'test_tools.dart';

const primaryCaretStyle = CaretStyle(color: Colors.black);

void main() {
  group("Caret layer", () {
    group("with a single caret", () {
      testWidgets("can switch out the BlinkController", (tester) async {
        // Start with built-in BlinkController
        final blinkControllerHolder = ValueNotifier<BlinkController?>(null);
        await tester.pumpWidget(
          buildTestScaffold(
            child: SuperText(
              richText: threeLineTextSpan,
              layerAboveBuilder: (context, TextLayout textLayout) {
                return Stack(
                  children: [
                    // We switch the BlinkController using a builder so that we don't
                    // risk replacing the entire widget tree across pumps. We need to
                    // retain the same State object for the TextLayoutCaret, so that
                    // we can test the didUpdateWidget() behavior.
                    ValueListenableBuilder(
                      valueListenable: blinkControllerHolder,
                      builder: (context, value, child) {
                        return TextLayoutCaret(
                          textLayout: textLayout,
                          blinkController: blinkControllerHolder.value,
                          style: primaryCaretStyle,
                          position: const TextPosition(offset: 35),
                          blinkCaret: false,
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        );

        // Switch to an external BlinkController
        blinkControllerHolder.value = BlinkController(tickerProvider: tester);

        // Give the Flutter pipeline time to rebuild after the ValueNotifier change.
        await tester.pump();

        // Switch back to an internal BlinkController
        blinkControllerHolder.value = null;

        // Give the Flutter pipeline time to rebuild after the ValueNotifier change.
        await tester.pump();

        // As long as this test completes without an error, it should be the
        // case that the BlinkController was successfully switched from an internal
        // controller to an external controller, and then back.
      });
    });
  });
}
