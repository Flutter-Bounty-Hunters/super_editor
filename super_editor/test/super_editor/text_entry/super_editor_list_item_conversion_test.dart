import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/src/test/super_editor_test/supereditor_inspector.dart';
import 'package:super_editor/src/test/super_editor_test/supereditor_robot.dart';
import 'package:super_editor/src/test/super_editor_test/supereditor_test_tools.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group("Super Editor > list items > auto-conversion >", () {
    group("unordered list items >", () {
      testWidgetsOnAllPlatforms("converts with prefix in empty paragraph", (tester) async {
        await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .pump();

        await tester.placeCaretInParagraph("1", 0);

        // Type the prefix for an unordered list item.
        await tester.typeImeText(_unorderedListItemPrefixes.currentValue!);

        // Ensure that we converted the paragraph to a list item.
        expect(
          SuperEditorInspector.findDocument(),
          documentEquivalentTo(MutableDocument(
            nodes: [
              ListItemNode(id: "1", itemType: ListItemType.unordered, text: AttributedText()),
            ],
          )),
        );
      }, variant: _unorderedListItemPrefixes);

      testWidgetsOnAllPlatforms("converts with prefix in non-empty paragraph", (tester) async {
        await tester //
            .createDocument()
            .withSingleShortParagraph()
            .pump();

        await tester.placeCaretInParagraph("1", 0);

        // Type the prefix for an unordered list item.
        await tester.typeImeText(_unorderedListItemPrefixes.currentValue!);
        final startingText = SuperEditorInspector.findTextInComponent("1");

        // Ensure that we converted the paragraph to a list item.
        expect(
          SuperEditorInspector.findDocument(),
          documentEquivalentTo(MutableDocument(
            nodes: [
              ListItemNode(id: "1", itemType: ListItemType.unordered, text: startingText),
            ],
          )),
        );
      }, variant: _unorderedListItemPrefixes);
    });

    group("ordered list items >", () {
      testWidgetsOnAllPlatforms("converts with '1' prefix in empty paragraph", (tester) async {
        await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .pump();

        await tester.placeCaretInParagraph("1", 0);

        // Type the prefix for an ordered list item.
        await tester.typeImeText(_orderedListItemPrefixes.currentValue!);

        // Ensure that we converted the paragraph to a list item.
        expect(
          SuperEditorInspector.findDocument(),
          documentEquivalentTo(MutableDocument(
            nodes: [
              ListItemNode(id: "1", itemType: ListItemType.ordered, text: AttributedText()),
            ],
          )),
        );
      }, variant: _orderedListItemPrefixes);

      testWidgetsOnAllPlatforms("converts with '1' prefix in non-empty paragraph", (tester) async {
        await tester //
            .createDocument()
            .withSingleShortParagraph()
            .pump();

        await tester.placeCaretInParagraph("1", 0);

        // Type the prefix for an ordered list item.
        await tester.typeImeText(_orderedListItemPrefixes.currentValue!);
        final startingText = SuperEditorInspector.findTextInComponent("1");

        // Ensure that we converted the paragraph to a list item.
        expect(
          SuperEditorInspector.findDocument(),
          documentEquivalentTo(MutableDocument(
            nodes: [
              ListItemNode(id: "1", itemType: ListItemType.ordered, text: startingText),
            ],
          )),
        );
      }, variant: _orderedListItemPrefixes);

      testWidgetsOnAllPlatforms("converts with '2' prefix in empty paragraph", (tester) async {
        await tester //
            .createDocument()
            .withOrderedListItemFollowedByEmptyParagraph()
            .pump();

        await tester.placeCaretInParagraph("2", 0);

        // Type the prefix for the 2nd ordered list item.
        await tester.typeImeText(_secondOrderedListItemPrefixes.currentValue!);

        // Ensure that we converted the paragraph to a list item.
        expect(
          SuperEditorInspector.findDocument(),
          documentEquivalentTo(MutableDocument(
            nodes: [
              ListItemNode(
                id: "1",
                itemType: ListItemType.ordered,
                text: SuperEditorInspector.findTextInComponent("1"),
              ),
              ListItemNode(id: "2", itemType: ListItemType.ordered, text: AttributedText()),
            ],
          )),
        );
      }, variant: _secondOrderedListItemPrefixes);

      testWidgetsOnAllPlatforms("converts with '2' prefix in non-empty paragraph", (tester) async {
        await tester //
            .createDocument()
            .withOrderedListItemFollowedByEmptyParagraph()
            .pump();

        await tester.placeCaretInParagraph("2", 0);

        // Type the prefix for an unordered list item.
        await tester.typeImeText(_orderedListItemPrefixes.currentValue!);
        final startingText = SuperEditorInspector.findTextInComponent("2");

        // Ensure that we converted the paragraph to a list item.
        expect(
          SuperEditorInspector.findDocument(),
          documentEquivalentTo(MutableDocument(
            nodes: [
              ListItemNode(
                id: "1",
                itemType: ListItemType.ordered,
                text: SuperEditorInspector.findTextInComponent("1"),
              ),
              ListItemNode(id: "2", itemType: ListItemType.ordered, text: startingText),
            ],
          )),
        );
      }, variant: _secondOrderedListItemPrefixes);
    });
  });
}

final _unorderedListItemPrefixes = ValueVariant({
  "- ",
  " - ",
  " • ",
});

final _orderedListItemPrefixes = ValueVariant({
  "1. ",
  " 1. ",
});

final _secondOrderedListItemPrefixes = ValueVariant({
  "2. ",
  " 2. ",
});
