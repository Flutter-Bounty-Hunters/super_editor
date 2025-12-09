import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_text_field_test.dart';

import '../../lib/src/test/flutter_extensions/test_tools_user_input.dart';

void main() {
  group('ImeAttributedTextEditingController', () {
    test('types hello **world** into empty field', () {
      final controller = ImeAttributedTextEditingController(
        controller: AttributedTextEditingController(
          selection: const TextSelection.collapsed(offset: 0),
        ),
      )
        ..updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: '',
            textInserted: 'H',
            insertionOffset: 0,
            selection: TextSelection.collapsed(offset: 1),
            composing: TextRange.empty,
          )
        ])
        ..updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: 'H',
            textInserted: 'e',
            insertionOffset: 1,
            selection: TextSelection.collapsed(offset: 2),
            composing: TextRange.empty,
          )
        ])
        ..updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: 'He',
            textInserted: 'l',
            insertionOffset: 2,
            selection: TextSelection.collapsed(offset: 3),
            composing: TextRange.empty,
          )
        ])
        ..updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: 'Hel',
            textInserted: 'l',
            insertionOffset: 3,
            selection: TextSelection.collapsed(offset: 4),
            composing: TextRange.empty,
          )
        ])
        ..updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: 'Hell',
            textInserted: 'o',
            insertionOffset: 4,
            selection: TextSelection.collapsed(offset: 5),
            composing: TextRange.empty,
          )
        ])
        ..updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: 'Hello',
            textInserted: ' ',
            insertionOffset: 5,
            selection: TextSelection.collapsed(offset: 6),
            composing: TextRange.empty,
          )
        ])
        ..addComposingAttributions({boldAttribution})
        ..updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: 'Hello ',
            textInserted: 'W',
            insertionOffset: 6,
            selection: TextSelection.collapsed(offset: 7),
            composing: TextRange.empty,
          )
        ])
        ..updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: 'Hello W',
            textInserted: 'o',
            insertionOffset: 7,
            selection: TextSelection.collapsed(offset: 8),
            composing: TextRange.empty,
          )
        ])
        ..updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: 'Hello Wo',
            textInserted: 'r',
            insertionOffset: 8,
            selection: TextSelection.collapsed(offset: 9),
            composing: TextRange.empty,
          )
        ])
        ..updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: 'Hello Wor',
            textInserted: 'l',
            insertionOffset: 9,
            selection: TextSelection.collapsed(offset: 10),
            composing: TextRange.empty,
          )
        ])
        ..updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: 'Hello Worl',
            textInserted: 'd',
            insertionOffset: 10,
            selection: TextSelection.collapsed(offset: 11),
            composing: TextRange.empty,
          )
        ]);

      expect(controller.text.toPlainText(), equals('Hello World'));
      ExpectedSpans([
        '______bbbbb',
      ]).expectSpans(controller.text.spans);
    });

    testWidgetsOnAllPlatforms('doesn\'t send existing IME value back to IME', (tester) async {
      // We test this condition because, on at least some platforms, whenever
      // we send a value to the IME, the IME sends it right back to us. Therefore,
      // if we keep reporting unchanged IME values, we'll get stuck in an infinite
      // loop of IME updates.

      int listenerNotificationCount = 0;
      late ImeConnectionWithUpdateCount imeConnection;
      final controller = ImeAttributedTextEditingController(
          controller: AttributedTextEditingController(
            text: AttributedText(
              'Some text',
            ),
          ),
          // Decorate the TextInputConnection to track the number of IME updates.
          inputConnectionFactory: (client, config) {
            final realConnection = TextInput.attach(client, config);
            imeConnection = ImeConnectionWithUpdateCount(realConnection);
            return imeConnection;
          })
        ..addListener(() {
          // Track the number of times the controller notifies listeners
          // of changes, because we don't want to receive notifications for
          // deltas that don't change anything.
          listenerNotificationCount += 1;
        });

      // Display a SuperTextField.
      await _pumpSuperTextField(tester, controller, inputSource: TextInputSource.ime);

      // Place the caret in the text field to introduce a selection.
      await tester.placeCaretInSuperTextField(4);

      // Ensure the controller was updated with the selection.
      expect(controller.selection, const TextSelection.collapsed(offset: 4));
      expect(controller.composingRegion, TextRange.empty);
      expect(listenerNotificationCount, 1);
      expect(imeConnection.contentUpdateCount, 1);

      // Send a delta that shouldn't change the text field's content.
      controller.updateEditingValueWithDeltas([
        const TextEditingDeltaNonTextUpdate(
          oldText: "Some text",
          selection: TextSelection.collapsed(offset: 4),
          composing: TextRange.empty,
        ),
      ]);
      await tester.pumpAndSettle();

      // Ensure listeners aren't notified, because no change occurred.
      expect(listenerNotificationCount, 1);

      // Ensure that we didn't send another update to the IME. This is the most
      // critical condition in this test.
      expect(imeConnection.contentUpdateCount, 1);
    });

    test('types new text in the middle of styled text', () {
      final controller = ImeAttributedTextEditingController(
          controller: AttributedTextEditingController(
        text: AttributedText(
          'before [] after',
          AttributedSpans(
            attributions: [
              const SpanMarker(attribution: boldAttribution, offset: 7, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: boldAttribution, offset: 8, markerType: SpanMarkerType.end),
            ],
          ),
        ),
      ))
        ..selection = const TextSelection.collapsed(offset: 8)
        ..updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: 'before [] after',
            textInserted: 'b',
            insertionOffset: 8,
            selection: TextSelection.collapsed(offset: 9),
            composing: TextRange.empty,
          )
        ]);

      expect(controller.text.toPlainText(), equals('before [b] after'));
      expect(controller.selection, equals(const TextSelection.collapsed(offset: 9)));
      ExpectedSpans([
        '_______bbb______',
      ]).expectSpans(controller.text.spans);
    });

    test('types batch of new text in the middle of styled text', () {
      final controller = ImeAttributedTextEditingController(
        controller: AttributedTextEditingController(
          text: AttributedText(
            'before [] after',
            AttributedSpans(
              attributions: [
                const SpanMarker(attribution: boldAttribution, offset: 7, markerType: SpanMarkerType.start),
                const SpanMarker(attribution: boldAttribution, offset: 8, markerType: SpanMarkerType.end),
              ],
            ),
          ),
        ),
      )
        ..selection = const TextSelection.collapsed(offset: 8)
        ..updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: 'before [] after',
            textInserted: 'hello',
            insertionOffset: 8,
            selection: TextSelection.collapsed(offset: 13),
            composing: TextRange.empty,
          )
        ]);

      expect(controller.text.toPlainText(), equals('before [hello] after'));
      expect(controller.selection, equals(const TextSelection.collapsed(offset: 13)));
      ExpectedSpans([
        '_______bbbbbbb______',
      ]).expectSpans(controller.text.spans);
    });

    test('types unstyled text in the middle of styled text', () {
      final controller = ImeAttributedTextEditingController(
        controller: AttributedTextEditingController(
          text: AttributedText(
            'before [] after',
            AttributedSpans(
              attributions: [
                const SpanMarker(attribution: boldAttribution, offset: 7, markerType: SpanMarkerType.start),
                const SpanMarker(attribution: boldAttribution, offset: 8, markerType: SpanMarkerType.end),
              ],
            ),
          ),
        ),
      )
        ..selection = const TextSelection.collapsed(offset: 8)
        ..clearComposingAttributions()
        ..updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: 'before [] after',
            textInserted: 'b',
            insertionOffset: 8,
            selection: TextSelection.collapsed(offset: 9),
            composing: TextRange.empty,
          )
        ]);

      expect(controller.text.toPlainText(), equals('before [b] after'));
      ExpectedSpans([
        '_______b_b______',
      ]).expectSpans(controller.text.spans);
    });

    test('clears composing attributions by deleting individual styled characters', () {
      final controller = ImeAttributedTextEditingController(
        controller: AttributedTextEditingController(
          text: AttributedText(
            'before [] after',
            AttributedSpans(
              attributions: [
                const SpanMarker(attribution: boldAttribution, offset: 7, markerType: SpanMarkerType.start),
                const SpanMarker(attribution: boldAttribution, offset: 8, markerType: SpanMarkerType.end),
              ],
            ),
          ),
        ),
      )..selection = const TextSelection.collapsed(offset: 9);
      expect(controller.composingAttributions, equals({boldAttribution}));

      controller.updateEditingValueWithDeltas([
        const TextEditingDeltaDeletion(
          oldText: 'before [] after',
          deletedRange: TextRange(start: 8, end: 9),
          selection: TextSelection.collapsed(offset: 8),
          composing: TextRange.empty,
        )
      ]);
      expect(controller.composingAttributions, equals({boldAttribution}));

      controller.updateEditingValueWithDeltas([
        const TextEditingDeltaDeletion(
          oldText: 'before [ after',
          deletedRange: TextRange(start: 7, end: 8),
          selection: TextSelection.collapsed(offset: 7),
          composing: TextRange.empty,
        )
      ]);
      expect(controller.composingAttributions.isEmpty, isTrue);
    });

    test('replaces selected text with new character', () {
      final controller = ImeAttributedTextEditingController(
        controller: AttributedTextEditingController(
          text: AttributedText(
            '[replaceme]',
          ),
        ),
      )
        ..selection = const TextSelection(baseOffset: 1, extentOffset: 10)
        ..updateEditingValueWithDeltas([
          const TextEditingDeltaReplacement(
            oldText: '[replaceme]',
            replacementText: 'b',
            replacedRange: TextRange(start: 1, end: 10),
            selection: TextSelection.collapsed(offset: 2),
            composing: TextRange.empty,
          ),
        ]);

      expect(controller.text.toPlainText(), equals('[b]'));
      expect(controller.selection, equals(const TextSelection.collapsed(offset: 2)));
    });

    test('replaces selected text with batch of new text', () {
      final controller = ImeAttributedTextEditingController(
        controller: AttributedTextEditingController(
          text: AttributedText(
            '[replaceme]',
          ),
        ),
      )
        ..selection = const TextSelection(baseOffset: 1, extentOffset: 10)
        ..updateEditingValueWithDeltas([
          const TextEditingDeltaReplacement(
            oldText: '[replaceme]',
            replacementText: 'new',
            replacedRange: TextRange(start: 1, end: 10),
            selection: TextSelection.collapsed(offset: 4),
            composing: TextRange.empty,
          ),
        ]);

      expect(controller.text.toPlainText(), equals('[new]'));
      expect(controller.selection, equals(const TextSelection.collapsed(offset: 4)));
    });

    test('deletes first character in text with backspace key', () {
      final controller = ImeAttributedTextEditingController(
        controller: AttributedTextEditingController(
          text: AttributedText(
            'some text',
          ),
        ),
      )
        ..selection = const TextSelection.collapsed(offset: 1)
        ..updateEditingValueWithDeltas([
          const TextEditingDeltaDeletion(
            oldText: 'some text',
            deletedRange: TextRange(start: 0, end: 1),
            selection: TextSelection.collapsed(offset: 0),
            composing: TextRange.empty,
          )
        ]);

      expect(controller.text.toPlainText(), equals('ome text'));
      expect(controller.selection, equals(const TextSelection.collapsed(offset: 0)));
    });

    test('deletes last character in text with delete key', () {
      final controller = ImeAttributedTextEditingController(
        controller: AttributedTextEditingController(
          text: AttributedText(
            'some text',
          ),
        ),
      )
        ..selection = const TextSelection.collapsed(offset: 8)
        ..updateEditingValueWithDeltas([
          const TextEditingDeltaDeletion(
            oldText: 'some text',
            deletedRange: TextRange(start: 8, end: 9),
            selection: TextSelection.collapsed(offset: 8),
            composing: TextRange.empty,
          )
        ]);

      expect(controller.text.toPlainText(), equals('some tex'));
      expect(controller.selection, equals(const TextSelection.collapsed(offset: 8)));
    });
  });

  testWidgets('isn\'t notified by inner controller after disposal', (tester) async {
    final innerController = AttributedTextEditingController(
      text: AttributedText(
        'some text',
      ),
    );

    // Create an IME controller wrapping the inner controller.
    //
    // The IME controller is notified whenever the inner controller changes.
    ImeAttributedTextEditingController imeController = ImeAttributedTextEditingController(
      controller: innerController,
      disposeClientController: false,
    );

    // Dispose the IME controller.
    //
    // After this point, the IME controller crashes if it's notified.
    imeController.dispose();

    // Attach the inner controller into a new IME controller.
    imeController = ImeAttributedTextEditingController(
      controller: innerController,
      disposeClientController: false,
    );

    // Change the text of the inner controller to notify the listeners.
    innerController.text = AttributedText('Another text');

    // Reaching this point means that disposing the old controller didn't cause a crash.
  });
}

Future<void> _pumpSuperTextField(
  WidgetTester tester,
  AttributedTextEditingController controller, {
  TextInputSource? inputSource,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 300,
          child: SuperTextField(
            textController: controller,
            inputSource: inputSource,
          ),
        ),
      ),
    ),
  ));
}
