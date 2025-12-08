import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../../test_runners.dart';

void main() {
  group("SuperEditor content conversion >", () {
    group("paragraph to headers >", () {
      testWidgetsOnAllPlatforms(
        "with '#'",
        (tester) async {
          final headerVariant = _headerVariant.currentValue!;

          final context = await tester //
              .createDocument()
              .withSingleEmptyParagraph()
              .withInputSource(TextInputSource.ime)
              .autoFocus(true)
              .pump();

          // Type the token that should cause an auto-conversion.
          await tester.typeImeText(headerVariant.$1);

          // Ensure that the paragraph is now a header, and it's content is empty.
          final document = context.findEditContext().document;
          final paragraph = document.first as ParagraphNode;

          expect(paragraph.metadata['blockType'], headerVariant.$2);
          expect(paragraph.text.toPlainText().isEmpty, isTrue);
        },
        variant: _headerVariant,
      );

      testWidgetsOnAllPlatforms("does not convert with 7 or more #", (tester) async {
        final context = await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .withInputSource(TextInputSource.ime)
            .autoFocus(true)
            .pump();

        // Type a header token that's longer than the smallest supported header
        await tester.typeImeText("####### ");

        // Ensure that the paragraph hasn't changed.
        final document = context.findEditContext().document;
        final paragraph = document.first as ParagraphNode;

        expect(paragraph.metadata['blockType'], paragraphAttribution);
        expect(paragraph.text.toPlainText(), "####### ");
      });
    });

    group("paragraph to unordered list >", () {
      testWidgetsOnAllPlatforms('with', (tester) async {
        final context = await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .withInputSource(TextInputSource.ime)
            .autoFocus(true)
            .pump();

        final unorderedListItemPattern = _unorderedListVariant.currentValue!;
        await tester.typeImeText(unorderedListItemPattern);

        final listItemNode = context.findEditContext().document.first;
        expect(listItemNode, isA<ListItemNode>());
        expect((listItemNode as ListItemNode).type, ListItemType.unordered);
        expect(listItemNode.text.toPlainText().isEmpty, isTrue);
      }, variant: _unorderedListVariant);

      testWidgetsOnAllPlatforms('does not convert "1 "', (tester) async {
        final context = await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .withInputSource(TextInputSource.ime)
            .autoFocus(true)
            .pump();

        await tester.typeImeText("1 ");

        final paragraphNode = context.findEditContext().document.first;
        expect(paragraphNode, isA<ParagraphNode>());
        expect((paragraphNode as ParagraphNode).text.toPlainText(), "1 ");
      });

      testWidgetsOnAllPlatforms('does not convert " 1 "', (tester) async {
        final context = await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .withInputSource(TextInputSource.ime)
            .autoFocus(true)
            .pump();

        await tester.typeImeText(" 1 ");

        final paragraphNode = context.findEditContext().document.first;
        expect(paragraphNode, isA<ParagraphNode>());
        expect((paragraphNode as ParagraphNode).text.toPlainText(), " 1 ");
      });
    });

    group("paragraph to ordered list >", () {
      testWidgetsOnAllPlatforms('with', (tester) async {
        final context = await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .withInputSource(TextInputSource.ime)
            .autoFocus(true)
            .pump();

        final orderedListItemPattern = _orderedListVariant.currentValue!;
        await tester.typeImeText(orderedListItemPattern);

        final listItemNode = context.findEditContext().document.first;
        expect(listItemNode, isA<ListItemNode>());
        expect((listItemNode as ListItemNode).type, ListItemType.ordered);
        expect(listItemNode.text.toPlainText().isEmpty, isTrue);
      }, variant: _orderedListVariant);

      testWidgetsOnAllPlatforms('with a number that continues the sequence', (tester) async {
        final context = await tester //
            .createDocument()
            .fromMarkdown('''
1. First item
2. Second item
3. Third item


''')
            .withInputSource(TextInputSource.ime)
            .autoFocus(true)
            .pump();

        final document = context.document;
        await tester.placeCaretInParagraph(document.getNodeAt(3)!.id, 0);

        // Type a list pattern with the number 4.
        await tester.typeImeText(_orderedListNumberVariant.currentValue!.replaceAll('n', '4'));

        // Ensure the paragraph was converted.
        final listItemNode = context.findEditContext().document.getNodeAt(3)!;
        expect(listItemNode, isA<ListItemNode>());
        expect((listItemNode as ListItemNode).type, ListItemType.ordered);
        expect(listItemNode.text.toPlainText().isEmpty, isTrue);
      }, variant: _orderedListNumberVariant);

      testWidgetsOnAllPlatforms('does not convert with a number that does not continues the sequence', (tester) async {
        final context = await tester //
            .createDocument()
            .fromMarkdown('''
1. First item
2. Second item
3. Third item


''')
            .withInputSource(TextInputSource.ime)
            .autoFocus(true)
            .pump();

        final document = context.document;
        await tester.placeCaretInParagraph(document.getNodeAt(3)!.id, 0);

        // Type a list pattern with the number 5.
        final orderedListItemPattern = _orderedListNumberVariant.currentValue!.replaceAll('n', '5');
        await tester.typeImeText(orderedListItemPattern);

        // Ensure the paragraph was not converted and the typed text was kept.
        final editingNode = context.findEditContext().document.getNodeAt(3)!;
        expect(editingNode, isA<ParagraphNode>());
        expect((editingNode as ParagraphNode).text.toPlainText(), orderedListItemPattern);
      }, variant: _orderedListNumberVariant);

      testWidgetsOnAllPlatforms('does not start a list with a number bigger than one', (tester) async {
        final context = await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .withInputSource(TextInputSource.ime)
            .autoFocus(true)
            .pump();

        final document = context.document;
        await tester.placeCaretInParagraph('1', 0);

        // Type a list pattern with the number 2.
        final orderedListItemPattern = _orderedListNumberVariant.currentValue!.replaceAll('n', '2');
        await tester.typeImeText(orderedListItemPattern);

        // Ensure the paragraph was not converted and the typed text was kept.
        final editingNode = document.first;
        expect(editingNode, isA<ParagraphNode>());
        expect((editingNode as ParagraphNode).text.toPlainText(), orderedListItemPattern);
      }, variant: _orderedListNumberVariant);

      testWidgetsOnAllPlatforms('does not convert "1 "', (tester) async {
        final context = await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .withInputSource(TextInputSource.ime)
            .autoFocus(true)
            .pump();

        await tester.typeImeText("1 ");

        final paragraphNode = context.findEditContext().document.first;
        expect(paragraphNode, isA<ParagraphNode>());
        expect((paragraphNode as ParagraphNode).text.toPlainText(), "1 ");
      });

      testWidgetsOnAllPlatforms('does not convert " 1 "', (tester) async {
        final context = await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .withInputSource(TextInputSource.ime)
            .autoFocus(true)
            .pump();

        await tester.typeImeText(" 1 ");

        final paragraphNode = context.findEditContext().document.first;
        expect(paragraphNode, isA<ParagraphNode>());
        expect((paragraphNode as ParagraphNode).text.toPlainText(), " 1 ");
      });
    });

    group("paragraph to horizontal rule >", () {
      testAllInputsOnAllPlatforms("with --- at the beginning of an empty paragraph", (
        tester, {
        required TextInputSource inputSource,
      }) async {
        final context = await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .withInputSource(inputSource)
            .autoFocus(true)
            .pump();

        await tester.typeTextAdaptive("--- ");

        // Ensure that we now have two nodes, and the first one is an HR.
        final document = context.findEditContext().document;
        expect(document.nodeCount, 2);

        expect(document.first, isA<HorizontalRuleNode>());
        expect(document.last, isA<ParagraphNode>());
        expect((document.last as ParagraphNode).text.toPlainText().isEmpty, isTrue);
      });

      testAllInputsOnAllPlatforms('with --- at the beginning of an non-empty paragraph', (
        tester, {
        required TextInputSource inputSource,
      }) async {
        final context = await tester //
            .createDocument()
            .fromMarkdown('Existing paragraph')
            .withInputSource(inputSource)
            .pump();

        // Place the caret at the beginning of the document.
        await tester.placeCaretInParagraph(context.document.first.id, 0);

        // Type the first dash.
        await tester.typeTextAdaptive('-');

        // Ensure no conversion was performed.
        expect((context.document.first as ParagraphNode).text.toPlainText(), '-Existing paragraph');

        // Type the second dash.
        await tester.typeTextAdaptive('-');

        // Ensure the two dashes were converted to an em-dash.
        expect((context.document.first as ParagraphNode).text.toPlainText(), '—Existing paragraph');

        // Type the third dash.
        await tester.typeTextAdaptive('- ');

        // Ensure a horizontal rule was inserted before the existing paragraph.
        expect(context.document.nodeCount, 2);
        expect(context.document.first, isA<HorizontalRuleNode>());
        expect(context.document.last, isA<ParagraphNode>());
        expect((context.document.last as ParagraphNode).text.toPlainText(), 'Existing paragraph');
      });

      testWidgetsOnAllPlatforms('does not convert non-HR dashes', (tester) async {
        final context = await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .withInputSource(TextInputSource.ime)
            .autoFocus(true)
            .pump();

        final nonHrInputAndResult = _nonHrVariant.currentValue!;
        final input = nonHrInputAndResult.input;
        final expectedResult = nonHrInputAndResult.expectedResult;

        await tester.typeImeText(input);

        final paragraphNode = context.findEditContext().document.first;
        expect(paragraphNode, isA<ParagraphNode>());
        expect((paragraphNode as ParagraphNode).text.toPlainText(), expectedResult);
      }, variant: _nonHrVariant);
    });

    group("paragraph to blockquote >", () {
      testWidgetsOnAllPlatforms("with '> '", (tester) async {
        final context = await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .withInputSource(TextInputSource.ime)
            .autoFocus(true)
            .pump();

        await tester.typeImeText("> ");

        // Ensure that the paragraph is now a blockquote, and it's content is empty.
        final document = context.findEditContext().document;
        final paragraph = document.first as ParagraphNode;

        expect(paragraph.metadata['blockType'], blockquoteAttribution);
        expect(paragraph.text.toPlainText().isEmpty, isTrue);
      });
    });

    group("converts to paragraph when backspace is pressed >", () {
      testWidgetsOnAllPlatforms("headers", (tester) async {
        final context = await tester //
            .createDocument()
            .fromMarkdown("# My Header")
            .withInputSource(TextInputSource.ime)
            .pump();
        final document = context.document;

        await tester.placeCaretInParagraph(document.first.id, 0);

        // Ensure that we're starting with a header.
        expect(document.first.metadata["blockType"], header1Attribution);

        // Simulate a backspace deletion delta.
        await tester.ime.sendDeltas(
          [
            const TextEditingDeltaNonTextUpdate(
              oldText: ". My Header",
              selection: TextSelection(baseOffset: 1, extentOffset: 2),
              composing: TextRange.empty,
            ),
            const TextEditingDeltaDeletion(
              oldText: ". My Header",
              selection: TextSelection.collapsed(offset: 1),
              deletedRange: TextRange(start: 1, end: 2),
              composing: TextRange.empty,
            ),
          ],
          getter: imeClientGetter,
        );

        // Ensure that the header became a paragraph.
        expect(document.first.metadata["blockType"], paragraphAttribution);
        expect(SuperEditorInspector.findTextInComponent(document.first.id).toPlainText(), "My Header");
      });

      testWidgetsOnAllPlatforms("blockquotes", (tester) async {
        final context = await tester //
            .createDocument()
            .fromMarkdown("> My Blockquote")
            .withInputSource(TextInputSource.ime)
            .pump();
        final document = context.document;

        await tester.placeCaretInParagraph(document.first.id, 0);

        // Ensure that we're starting with a blockquote.
        expect(document.first.metadata["blockType"], blockquoteAttribution);

        // Simulate a backspace deletion delta.
        await tester.ime.sendDeltas(
          [
            const TextEditingDeltaNonTextUpdate(
              oldText: ". My Blockquote",
              selection: TextSelection(baseOffset: 1, extentOffset: 2),
              composing: TextRange.empty,
            ),
            const TextEditingDeltaDeletion(
              oldText: ". My Blockquote",
              selection: TextSelection.collapsed(offset: 1),
              deletedRange: TextRange(start: 1, end: 2),
              composing: TextRange.empty,
            ),
          ],
          getter: imeClientGetter,
        );

        // Ensure that the blockquote became a paragraph.
        expect(document.first.metadata["blockType"], paragraphAttribution);
        expect(SuperEditorInspector.findTextInComponent(document.first.id).toPlainText(), "My Blockquote");
      });

      testWidgetsOnAllPlatforms("ordered list items", (tester) async {
        final context = await tester //
            .createDocument()
            .fromMarkdown("1. My list item")
            .withInputSource(TextInputSource.ime)
            .pump();
        final document = context.document;

        await tester.placeCaretInParagraph(document.first.id, 0);

        // Ensure that we're starting with list item.
        expect(document.first, isA<ListItemNode>());

        // Simulate a backspace deletion delta.
        await tester.ime.sendDeltas(
          [
            const TextEditingDeltaNonTextUpdate(
              oldText: ". My list item",
              selection: TextSelection(baseOffset: 1, extentOffset: 2),
              composing: TextRange.empty,
            ),
            const TextEditingDeltaDeletion(
              oldText: ". My list item",
              selection: TextSelection.collapsed(offset: 1),
              deletedRange: TextRange(start: 1, end: 2),
              composing: TextRange.empty,
            ),
          ],
          getter: imeClientGetter,
        );

        // Ensure that the list item became a paragraph.
        final newNode = document.first;
        expect(newNode, isA<ParagraphNode>());
        expect(newNode.metadata["blockType"], paragraphAttribution);
        expect(SuperEditorInspector.findTextInComponent(document.first.id).toPlainText(), "My list item");
      });
    });
  });
}

final _headerVariant = ValueVariant({
  ("# ", header1Attribution),
  ("## ", header2Attribution),
  ("### ", header3Attribution),
  ("#### ", header4Attribution),
  ("##### ", header5Attribution),
  ("###### ", header6Attribution),
});

final _unorderedListVariant = ValueVariant({
  "* ",
  " * ",
  "- ",
  " - ",
});

final _orderedListVariant = ValueVariant({
  "1. ",
  " 1. ",
  "1) ",
  " 1) ",
});

final _orderedListNumberVariant = ValueVariant({
  "n. ",
  " n. ",
  "n) ",
  " n) ",
});

/// Holds sequence of character that shouldn't produce a horizontal rule
/// and the expected resulting text after running the editor reactions.
final _nonHrVariant = ValueVariant(const {
  // We ignore " - " because that is a conversion for unordered list items
  _TestInput(input: "-- ", expectedResult: "— "),
  _TestInput(input: "---- ", expectedResult: "—— "),
  _TestInput(input: " --- ", expectedResult: " —- "),
});

/// A test text input and the expected resulting text after running
/// the editor reactions.
class _TestInput {
  const _TestInput({
    required this.input,
    required this.expectedResult,
  });

  final String input;
  final String expectedResult;

  @override
  String toString() {
    return "[input: $input, expectedResult: $expectedResult]";
  }
}
