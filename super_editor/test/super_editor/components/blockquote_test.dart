import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:super_text_layout/super_text_layout.dart';

void main() {
  group('Super Editor > Blockquote >', () {
    testWidgets("applies the textStyle from SuperEditor's styleSheet", (WidgetTester tester) async {
      await tester
          .createDocument() //
          .withCustomContent(_singleBlockquoteDoc())
          .useStylesheet(_styleSheet)
          .pump();

      // Ensure that the textStyle from the styleSheet was applied
      expect(find.byType(LayoutAwareRichText), findsOneWidget);
      final richText = (find.byType(LayoutAwareRichText).evaluate().first.widget) as LayoutAwareRichText;
      expect(richText.text.style!.color, Colors.blue);
      expect(richText.text.style!.fontSize, 16);
    });

    group("insert newlines >", () {
      testWidgetsOnAllPlatforms("inserts newline in middle and splits blockquote into two blockquotes",
          (WidgetTester tester) async {
        await tester
            .createDocument() //
            .withCustomContent(_singleBlockquoteDoc())
            .pump();

        // Place caret in the middle of the blockquote:
        // "This is |a blockquote."
        await tester.placeCaretInParagraph("1", 8);

        // Insert a newline.
        switch (debugDefaultTargetPlatformOverride) {
          case TargetPlatform.android:
          case TargetPlatform.iOS:
            // FIXME: pressEnterWithIme should work, but it seems to think there are no
            //        connected IME clients, so it fizzles. For now, we use the implementation
            //        directly.
            // await tester.pressEnterWithIme();
            await tester.testTextInput.receiveAction(TextInputAction.newline);
          case TargetPlatform.macOS:
          case TargetPlatform.windows:
          case TargetPlatform.linux:
          case TargetPlatform.fuchsia:
          case null:
            await tester.pressEnter();
        }

        // Ensure we have two blockquotes, each with part of the original text.
        final document = SuperEditorInspector.findDocument()!;
        expect(document.nodeCount, 2);

        expect(document.first.metadata["blockType"], blockquoteAttribution);
        expect(document.first.asTextNode.text.toPlainText(), "This is ");

        expect(document.last.metadata["blockType"], blockquoteAttribution);
        expect(document.last.asTextNode.text.toPlainText(), "a blockquote.");
      });

      testWidgetsOnAllPlatforms("inserts newline at end of blockquote to create a new empty paragraph",
          (WidgetTester tester) async {
        await tester
            .createDocument() //
            .withCustomContent(_singleBlockquoteDoc())
            .pump();

        // Place caret at the end of the blockquote.
        await tester.placeCaretInParagraph("1", 21);

        // Insert a newline.
        switch (debugDefaultTargetPlatformOverride) {
          case TargetPlatform.android:
          case TargetPlatform.iOS:
            // FIXME: pressEnterWithIme should work, but it seems to think there are no
            //        connected IME clients, so it fizzles. For now, we use the implementation
            //        directly.
            // await tester.pressEnterWithIme();
            await tester.testTextInput.receiveAction(TextInputAction.newline);
          case TargetPlatform.macOS:
          case TargetPlatform.windows:
          case TargetPlatform.linux:
          case TargetPlatform.fuchsia:
          case null:
            await tester.pressEnter();
        }

        // Ensure a new, empty paragraph was inserted after the blockquote.
        final document = SuperEditorInspector.findDocument()!;
        expect(document.nodeCount, 2);

        expect(document.first.metadata["blockType"], blockquoteAttribution);
        expect(document.first.asTextNode.text.toPlainText(), "This is a blockquote.");

        expect(document.last.metadata["blockType"], paragraphAttribution);
        expect(document.last.asTextNode.text.toPlainText(), "");
      });
    });
  });
}

MutableDocument _singleBlockquoteDoc() => MutableDocument(
      nodes: [
        ParagraphNode(
          id: '1',
          text: AttributedText("This is a blockquote."),
          metadata: const {'blockType': blockquoteAttribution},
        )
      ],
    );

final _styleSheet = Stylesheet(
  inlineTextStyler: _inlineTextStyler,
  rules: [
    StyleRule(
      const BlockSelector("blockquote"),
      (doc, docNode) {
        return {
          Styles.textStyle: const TextStyle(color: Colors.blue, fontSize: 16),
        };
      },
    ),
  ],
);

TextStyle _inlineTextStyler(Set<Attribution> attributions, TextStyle base) => base;
