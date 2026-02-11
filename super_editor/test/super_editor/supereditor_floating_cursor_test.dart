import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/blinking_caret.dart';
import 'package:super_editor/super_editor_test.dart';

void main() {
  group('SuperEditor', () {
    group('floating cursor', () {
      testWidgetsOnIos('hides caret when over text', (tester) async {
        // Pump a SuperEditor which displays the content in a single line.
        await tester //
            .createDocument()
            .fromMarkdown('This is a paragraph')
            .withEditorSize(const Size(500, 500))
            .pump();

        // Place caret at "|This is a paragraph".
        await tester.placeCaretInParagraph(SuperEditorInspector.findDocument()!.first.id, 0);

        // Ensure the caret is displayed.
        expect(_caretFinder(), findsOneWidget);

        // Show the floating cursor.
        await tester.startFloatingCursorGesture();
        await tester.pump();

        // Move the floating cursor to the right.
        // The floating cursor will be over the text.
        await tester.updateFloatingCursorGesture(const Offset(50, 0));
        await tester.pump();

        // Ensure the caret isn't displayed.
        expect(_caretFinder(), findsNothing);

        // Move the floating cursor to the right.
        // The floating cursor will be over the text.
        await tester.updateFloatingCursorGesture(const Offset(100, 0));
        await tester.pump();

        // Ensure the caret isn't displayed.
        expect(_caretFinder(), findsNothing);

        // Move the floating cursor to the right.
        // The floating cursor will be over the text.
        await tester.updateFloatingCursorGesture(const Offset(175, 0));
        await tester.pump();

        // Ensure the caret isn't displayed.
        expect(_caretFinder(), findsNothing);

        // Release the floating cursor.
        await tester.stopFloatingCursorGesture();
        await tester.pump();

        // Ensure the caret is displayed.
        expect(_caretFinder(), findsOneWidget);
      });

      testWidgetsOnIos('hides caret when near text', (tester) async {
        // Pump a SuperEditor which displays the content in a single line.
        await tester //
            .createDocument()
            .fromMarkdown('This is a paragraph')
            .withEditorSize(const Size(500, 500))
            .pump();

        // Place caret at the end of the text.
        await tester.placeCaretInParagraph(SuperEditorInspector.findDocument()!.first.id, 19);

        // Ensure the caret is displayed.
        expect(_caretFinder(), findsOneWidget);

        // Show the floating cursor.
        await tester.startFloatingCursorGesture();
        await tester.pump();

        // Moves the floating cursor to the maximum distance before the grey caret is displayed.
        await tester.updateFloatingCursorGesture(const Offset(30, 0));
        await tester.pump();

        // Ensure the caret isn't displayed.
        expect(_caretFinder(), findsNothing);

        // Release the floating cursor.
        await tester.stopFloatingCursorGesture();
        await tester.pump();

        // Ensure the caret is displayed.
        expect(_caretFinder(), findsOneWidget);
      });

      testWidgetsOnIos('shows grey caret when far from text', (tester) async {
        // Pump a SuperEditor which displays the content in a single line.
        await tester //
            .createDocument()
            .fromMarkdown('This is a paragraph')
            .withEditorSize(const Size(500, 500))
            .pump();

        // Place caret at the end of the text.
        await tester.placeCaretInParagraph(SuperEditorInspector.findDocument()!.first.id, 19);

        // Show the floating cursor.
        await tester.startFloatingCursorGesture();
        await tester.pump();

        // Moves the floating cursor to the first pixel where the grey caret should be displayed.
        await tester.updateFloatingCursorGesture(const Offset(31, 0));
        await tester.pump();

        // Ensure the caret is displayed.
        expect(_caretFinder(), findsOneWidget);

        // Ensure the caret is grey.
        BlinkingCaret caret = tester.widget<BlinkingCaret>(_caretFinder());
        expect(caret.color, Colors.grey);

        // Release the floating cursor.
        await tester.stopFloatingCursorGesture();
        await tester.pump();

        // Ensure the caret is displayed.
        expect(_caretFinder(), findsOneWidget);

        // Ensure the caret has the default color.
        caret = tester.widget<BlinkingCaret>(_caretFinder());
        // The default caret color is the theme's primary color. Currently
        // this test will succeed for both Material2 and Material3.
        // TODO(hansmuller) when the default for ThemeData.useMaterial3 is
        // changed to true, change this test to check for the default
        // M3 theme's primary color's value, Color(0xff6750a4).
        expect(caret.color, Theme.of(tester.firstElement(_caretFinder())).primaryColor);
      });

      testWidgetsOnIos('collapses an expanded selection', (tester) async {
        final testContext = await tester //
            .createDocument()
            .fromMarkdown('This is a paragraph')
            .pump();

        final nodeId = testContext.document.first.id;

        // Double tap to select the word "This"
        await tester.doubleTapInParagraph(nodeId, 0);

        // Ensure the word is selected.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection(
            base: DocumentPosition(
              nodeId: nodeId,
              nodePosition: const TextNodePosition(offset: 0),
            ),
            extent: DocumentPosition(
              nodeId: nodeId,
              nodePosition: const TextNodePosition(offset: 4),
            ),
          ),
        );

        // Show the floating cursor.
        await tester.startFloatingCursorGesture();
        await tester.pump();

        // Ensure the selection collapsed.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: nodeId,
              nodePosition: const TextNodePosition(offset: 4),
            ),
          ),
        );
      });

      testWidgetsOnIos('moves selection between paragraphs', (tester) async {
        final testContext = await tester //
            .createDocument()
            .fromMarkdown('''
This is the first paragraph

Second paragraph''') //
            .pump();

        // Place the caret at the end of the first paragraph.
        await tester.placeCaretInParagraph(testContext.document.first.id, 27);

        // Show the floating cursor.
        await tester.startFloatingCursorGesture();
        await tester.pump();

        // Move the floating cursor down to the next paragraph.
        await tester.updateFloatingCursorGesture(const Offset(0, 30));
        await tester.pump();

        // Simulate iOS IME generating deltas as a result of moving the floating cursor.
        // At this point, the selection already changed to the second paragraph, which is
        // smaller than the selection offset reported in the delta.
        await tester.ime.sendDeltas([
          const TextEditingDeltaNonTextUpdate(
            oldText: 'This is the first paragraph',
            selection: TextSelection.collapsed(offset: 27),
            composing: TextRange.empty,
          )
        ], getter: imeClientGetter);
        await tester.pump();

        // Ensure the selection changed to the end of the second paragraph.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: testContext.document.last.id,
              nodePosition: const TextNodePosition(offset: 16, affinity: TextAffinity.upstream),
            ),
          ),
        );
      });
    });
  });
}

Finder _caretFinder() {
  return find.byType(BlinkingCaret);
}
