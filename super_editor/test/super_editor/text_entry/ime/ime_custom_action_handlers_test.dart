import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:super_editor/super_test.dart';

void main() {
  group('IME input >', () {
    testWidgetsOnAllPlatforms('allows apps to handle performAction in their own way', (tester) async {
      final document = singleParagraphEmptyDoc();

      int performActionCount = 0;
      TextInputAction? performedAction;
      final imeOverrides = _TestImeOverrides(
        (action) {
          performActionCount += 1;
          performedAction = action;
        },
      );

      await tester //
          .createDocument()
          .withCustomContent(document)
          .withInputSource(TextInputSource.ime)
          .withImeOverrides(imeOverrides)
          .pump();

      // Place the caret in the document so that we open an IME connection.
      await tester.placeCaretInParagraph("1", 0);

      // Simulate a "Newline" action from the platform.
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        SystemChannels.textInput.name,
        SystemChannels.textInput.codec.encodeMethodCall(
          const MethodCall(
            "TextInputClient.performAction",
            [-1, "TextInputAction.newline"],
          ),
        ),
        null,
      );

      // Ensure that our override got the performAction call.
      expect(performActionCount, 1);
      expect(performedAction, TextInputAction.newline);

      // Ensure that the editor didn't receive the performAction call, and didn't
      // insert a new node.
      expect(document.nodeCount, 1);
    });

    testWidgetsOnAndroid('allows app to handle newline action', (tester) async {
      // On Android, when the user presses an action button configured as TextInputAction.newline,
      // instead of dispatching the action, the OS sends an insertion delta of '\n'.
      //
      // Then, the IME code that handles deltas translates this insertion into a performAction call.
      // This test ensures that this performAction call honors the IME overrides.

      final document = singleParagraphEmptyDoc();

      int performActionCount = 0;
      TextInputAction? performedAction;
      final imeOverrides = _TestImeOverrides(
        (action) {
          performActionCount += 1;
          performedAction = action;
        },
      );

      await tester //
          .createDocument()
          .withCustomContent(document)
          .withInputSource(TextInputSource.ime)
          .withImeOverrides(imeOverrides)
          .pump();

      // Place the caret in the document so that we open an IME connection.
      await tester.placeCaretInParagraph("1", 0);

      // Simulate the user pressing an action button that generates an insertion of a new line.
      await tester.typeImeText('\n');

      // Ensure that our override got the performAction call.
      expect(performActionCount, 1);
      expect(performedAction, TextInputAction.newline);

      // Ensure that the editor didn't receive the performAction call, and didn't
      // insert a new node.
      expect(document.nodeCount, 1);
    });

    testWidgetsOnMac('allows apps to handle selectors in their own way', (tester) async {
      bool customHandlerCalled = false;

      await tester //
          .createDocument()
          .withCustomContent(
            MutableDocument(
              nodes: [ParagraphNode(id: '1', text: AttributedText('First paragraph'))],
            ),
          )
          .withInputSource(TextInputSource.ime)
          .withSelectorHandlers({
        MacOsSelectors.moveRight: (context) {
          customHandlerCalled = true;
        },
      }).pump();

      // Place the caret at the beginning of the document.
      await tester.placeCaretInParagraph("1", 0);

      // Press right arrow key to trigger the MacOsSelectors.moveRight selector.
      await tester.pressRightArrow();

      // Ensure the custom handler was called.
      expect(customHandlerCalled, isTrue);

      // Ensure that the editor didn't execute the default handler for the MacOsSelectors.moveRight selector.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: '1',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
    });

    testWidgetsOnAllPlatforms('applies list of deltas the way some IMEs report them', (tester) async {
      // This test simulates an auto-correction scenario,
      // where the IME sends multiple insertion deltas at once.

      await tester //
          .createDocument()
          .withSingleEmptyParagraph()
          .withInputSource(TextInputSource.ime)
          .pump();

      // Place caret at the start of the document.
      await tester.placeCaretInParagraph('1', 0);

      // Send initial delta, insertion of 'Goi'.
      await tester.ime.sendDeltas(
        const [
          TextEditingDeltaNonTextUpdate(
            oldText: '. ',
            selection: TextSelection.collapsed(offset: 2),
            composing: TextRange(start: -1, end: -1),
          ),
          TextEditingDeltaInsertion(
            oldText: '. ',
            textInserted: 'Goi',
            insertionOffset: 2,
            selection: TextSelection.collapsed(offset: 5),
            composing: TextRange(start: 2, end: 5),
          )
        ],
        getter: imeClientGetter,
      );

      // Simulate the auto-correction kicking in during the insertion of a '.'.
      await tester.ime.sendDeltas(
        const [
          // This delta represents the '.' typed by the user.
          TextEditingDeltaInsertion(
            oldText: '. Goi',
            textInserted: '.',
            insertionOffset: 3,
            selection: TextSelection.collapsed(offset: 6),
            composing: TextRange(start: -1, end: -1),
          ),
          // Deltas generated by the auto-correction.
          // First, delete everything.
          TextEditingDeltaDeletion(
            oldText: '. Goi.',
            deletedRange: TextRange(start: 2, end: 6),
            selection: TextSelection.collapsed(offset: 2),
            composing: TextRange(start: -1, end: -1),
          ),
          // Insert the auto-corrected word.
          TextEditingDeltaInsertion(
            oldText: '. ',
            textInserted: 'Going',
            insertionOffset: 2,
            selection: TextSelection.collapsed(offset: 7),
            composing: TextRange(start: -1, end: -1),
          ),
          // Insert the '.' typed.
          TextEditingDeltaInsertion(
            oldText: '. Going',
            textInserted: '.',
            insertionOffset: 7,
            selection: TextSelection.collapsed(offset: 8),
            composing: TextRange(start: -1, end: -1),
          ),
        ],
        getter: imeClientGetter,
      );

      // Ensure the text was inserted.
      expect(
        SuperEditorInspector.findTextInComponent('1').toPlainText(),
        'Going.',
      );
    });
  });
}

class _TestImeOverrides extends DeltaTextInputClientDecorator {
  _TestImeOverrides(this.performActionCallback);

  final void Function(TextInputAction) performActionCallback;

  @override
  void performAction(TextInputAction action) {
    performActionCallback(action);
  }
}
