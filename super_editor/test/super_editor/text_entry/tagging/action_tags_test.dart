import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../../supereditor_test_tools.dart';
import '../../test_documents.dart';

void main() {
  group("SuperEditor action tags >", () {
    group("composing >", () {
      testWidgetsOnAllPlatforms("can start at the beginning of a paragraph", (tester) async {
        await _pumpTestEditor(
          tester,
          singleParagraphEmptyDoc(),
        );
        await tester.placeCaretInParagraph("1", 0);

        // Compose an action tag.
        await tester.typeImeText("/header");

        // Ensure that the tag has a composing attribution.
        final text = SuperEditorInspector.findTextInComponent("1");
        expect(text.toPlainText(), "/header");
        expect(
          text.getAttributedRange({actionTagComposingAttribution}, 0),
          const SpanRange(0, 6),
        );
      });

      testWidgetsOnAllPlatforms("can start between words", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText("before  after"),
              ),
            ],
          ),
        );

        // Place the caret at "before |"
        await tester.placeCaretInParagraph("1", 7);

        // Compose an action tag.
        await tester.typeImeText("/header");

        // Ensure that the tag has a composing attribution.
        final text = SuperEditorInspector.findTextInComponent("1");
        expect(text.toPlainText(), "before /header after");
        expect(
          text.getAttributedRange({actionTagComposingAttribution}, 7),
          const SpanRange(7, 13),
        );
      });

      testWidgetsOnAllPlatforms("can start at the beginning of a word", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText("before after"),
              ),
            ],
          ),
        );

        // Place the caret at "before |after"
        await tester.placeCaretInParagraph("1", 7);

        // Compose an action tag, typing at "|after".
        await tester.typeImeText("/header");

        // Ensure that "/header" was attributed but "after" was left unnattributed.
        final spans = SuperEditorInspector.findTextInComponent("1").getAttributionSpansInRange(
          attributionFilter: (attribution) => attribution == actionTagComposingAttribution,
          range: const SpanRange(0, 19),
        );
        expect(spans.length, 1);
        expect(
          spans.first,
          const AttributionSpan(
            attribution: actionTagComposingAttribution,
            start: 7,
            end: 13,
          ),
        );
      });

      testWidgetsOnAllPlatforms("by default does not continue after a space", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText("before "),
              ),
            ],
          ),
        );

        // Place the caret at "before |"
        await tester.placeCaretInParagraph("1", 7);

        // Compose an action tag and more content after a space.
        await tester.typeImeText("/header after");

        // Ensure that there's no more composing attribution because the tag
        // should have been submitted.
        final text = SuperEditorInspector.findTextInComponent("1");
        expect(text.toPlainText(), "before /header after");
        expect(
          text.getAttributionSpansInRange(
            attributionFilter: (attribution) => attribution == actionTagComposingAttribution,
            range: const SpanRange(0, 18),
          ),
          isEmpty,
        );
        expect(
          text.getAttributedRange({actionTagCancelledAttribution}, 7),
          const SpanRange(7, 7),
        );
      });

      testWidgetsOnAllPlatforms("can be configured to continue after a space", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText("before "),
              ),
            ],
          ),
          tagRule: const TagRule(trigger: "/"),
        );

        // Place the caret at "before |"
        await tester.placeCaretInParagraph("1", 7);

        // Compose an action tag.
        await tester.typeImeText("/header");

        // Ensure that we started a composing tag before adding a space.
        var text = SuperEditorInspector.findTextInComponent("1");
        expect(text.toPlainText(), "before /header");
        expect(
          text.getAttributedRange({actionTagComposingAttribution}, 7),
          const SpanRange(7, 13),
        );

        await tester.typeImeText(" after");

        // Ensure that the composing attribution continues after the space.
        text = SuperEditorInspector.findTextInComponent("1");
        expect(text.toPlainText(), "before /header after");
        expect(
          text.getAttributedRange({actionTagComposingAttribution}, 7),
          const SpanRange(7, 19),
        );
      });

      testWidgetsOnAllPlatforms("can be configured to use a different trigger", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText("before "),
              ),
            ],
          ),
          tagRule: const TagRule(trigger: "@", excludedCharacters: {" "}),
        );

        // Place the caret at "before |"
        await tester.placeCaretInParagraph("1", 7);

        // Compose an action tag.
        await tester.typeImeText("@john");

        // Ensure that we're composing an action tag.
        var text = SuperEditorInspector.findTextInComponent("1");
        expect(text.toPlainText(), "before @john");
        expect(
          text.getAttributedRange({actionTagComposingAttribution}, 7),
          const SpanRange(7, 11),
        );
      });

      testWidgetsOnAllPlatforms("does not continue when user expands the selection upstream", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText("before "),
              ),
              ParagraphNode(
                id: "2",
                text: AttributedText(""),
              ),
            ],
          ),
        );

        // Place the caret at "before |"
        await tester.placeCaretInParagraph("1", 7);

        // Compose an action tag.
        await tester.typeImeText("/header");

        // Ensure we're composing a tag.
        AttributedText text = SuperEditorInspector.findTextInComponent("1");
        expect(
          text.getAttributedRange({actionTagComposingAttribution}, 7),
          const SpanRange(7, 13),
        );

        // Expand the selection to "before /heade|r|"
        await tester.pressShiftLeftArrow();
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection(
            base: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 14),
            ),
            extent: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 13),
            ),
          ),
        );

        // Ensure we're not composing anymore.
        text = SuperEditorInspector.findTextInComponent("1");
        expect(
          text.getAttributionSpansInRange(
            attributionFilter: (attribution) => attribution == actionTagComposingAttribution,
            range: const SpanRange(7, 13),
          ),
          isEmpty,
        );

        // Expand the selection to "before |/header|"
        await tester.pressShiftLeftArrow();
        await tester.pressShiftLeftArrow();
        await tester.pressShiftLeftArrow();
        await tester.pressShiftLeftArrow();
        await tester.pressShiftLeftArrow();
        await tester.pressShiftLeftArrow();

        // Ensure we're still not composing.
        text = SuperEditorInspector.findTextInComponent("1");
        expect(
          text.getAttributionSpansInRange(
            attributionFilter: (attribution) => attribution == actionTagComposingAttribution,
            range: const SpanRange(7, 13),
          ),
          isEmpty,
        );

        // Expand the selection to "befor|e /header|"
        await tester.pressShiftLeftArrow();
        await tester.pressShiftLeftArrow();

        // Ensure we're still not composing.
        text = SuperEditorInspector.findTextInComponent("1");
        expect(
          text.getAttributionSpansInRange(
            attributionFilter: (attribution) => attribution == actionTagComposingAttribution,
            range: const SpanRange(7, 13),
          ),
          isEmpty,
        );
      });

      testWidgetsOnAllPlatforms("does not continue when user expands the selection downstream", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText("before  after"),
              ),
              ParagraphNode(
                id: "2",
                text: AttributedText(),
              ),
            ],
          ),
        );

        // Place the caret at "before | after"
        await tester.placeCaretInParagraph("1", 7);

        // Compose an action tag.
        await tester.typeImeText("/header");

        // Ensure we're composing a tag.
        AttributedText text = SuperEditorInspector.findTextInComponent("1");
        expect(
          text.getAttributedRange({actionTagComposingAttribution}, 7),
          const SpanRange(7, 13),
        );

        // Move the caret to "before /|header".
        await tester.pressLeftArrow();
        await tester.pressLeftArrow();
        await tester.pressLeftArrow();
        await tester.pressLeftArrow();
        await tester.pressLeftArrow();
        await tester.pressLeftArrow();

        // Expand the selection to "before /|header a|fter"
        await tester.pressShiftRightArrow();
        await tester.pressShiftRightArrow();
        await tester.pressShiftRightArrow();
        await tester.pressShiftRightArrow();
        await tester.pressShiftRightArrow();
        await tester.pressShiftRightArrow();
        await tester.pressShiftRightArrow();
        await tester.pressShiftRightArrow();
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection(
            base: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 8),
            ),
            extent: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 16),
            ),
          ),
        );

        // Ensure we're not composing anymore.
        text = SuperEditorInspector.findTextInComponent("1");
        expect(
          text.getAttributionSpansInRange(
            attributionFilter: (attribution) => attribution == actionTagComposingAttribution,
            range: const SpanRange(7, 13),
          ),
          isEmpty,
        );
      });

      testWidgetsOnAllPlatforms("cancels when the user moves the caret", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText("before "),
              ),
              ParagraphNode(
                id: "2",
                text: AttributedText(),
              ),
            ],
          ),
        );

        // Place the caret at "before |"
        await tester.placeCaretInParagraph("1", 7);

        // Compose an action tag.
        await tester.typeImeText("/header");

        // Move the selection somewhere else.
        await tester.placeCaretInParagraph("2", 0);
        expect(
          SuperEditorInspector.findDocumentSelection()!.extent,
          const DocumentPosition(
            nodeId: "2",
            nodePosition: TextNodePosition(offset: 0),
          ),
        );

        // Ensure that the tag was submitted.
        final text = SuperEditorInspector.findTextInComponent("1");
        expect(text.toPlainText(), "before /header");
        expect(
          text.getAttributedRange({actionTagCancelledAttribution}, 7),
          const SpanRange(7, 7),
        );
      });

      testWidgetsOnAllPlatforms("cancels when upstream selection collapses outside of tag", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText("before "),
              ),
              ParagraphNode(
                id: "2",
                text: AttributedText(),
              ),
            ],
          ),
        );

        // Place the caret at "before |"
        await tester.placeCaretInParagraph("1", 7);

        // Compose an action tag
        await tester.typeImeText("/header");

        // Expand the selection to "befor|e /header|"
        await tester.pressShiftLeftArrow();
        await tester.pressShiftLeftArrow();
        await tester.pressShiftLeftArrow();
        await tester.pressShiftLeftArrow();
        await tester.pressShiftLeftArrow();
        await tester.pressShiftLeftArrow();
        await tester.pressShiftLeftArrow();
        await tester.pressShiftLeftArrow();
        await tester.pressShiftLeftArrow();

        // Collapse the selection to the upstream position.
        await tester.pressLeftArrow();

        // Ensure that the action tag was cancelled.
        final text = SuperEditorInspector.findTextInComponent("1");
        expect(text.toPlainText(), "before /header");
        expect(
          text.getAttributedRange({actionTagCancelledAttribution}, 7),
          const SpanRange(7, 7),
        );
      });

      testWidgetsOnAllPlatforms("cancels when downstream selection collapses outside of tag", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText("before  after"),
              ),
              ParagraphNode(
                id: "2",
                text: AttributedText(),
              ),
            ],
          ),
        );

        // Place the caret at "before | after"
        await tester.placeCaretInParagraph("1", 7);

        // Compose an action tag.
        await tester.typeImeText("/header");

        // Move caret to "before /|header after"
        await tester.pressLeftArrow();
        await tester.pressLeftArrow();
        await tester.pressLeftArrow();
        await tester.pressLeftArrow();
        await tester.pressLeftArrow();
        await tester.pressLeftArrow();

        // Expand the selection to "before @|header a|fter"
        await tester.pressShiftRightArrow();
        await tester.pressShiftRightArrow();
        await tester.pressShiftRightArrow();
        await tester.pressShiftRightArrow();
        await tester.pressShiftRightArrow();
        await tester.pressShiftRightArrow();
        await tester.pressShiftRightArrow();
        await tester.pressShiftRightArrow();

        // Collapse the selection to the downstream position.
        await tester.pressRightArrow();

        // Ensure that the action tag was cancelled.
        final text = SuperEditorInspector.findTextInComponent("1");
        expect(text.toPlainText(), "before /header after");
        expect(
          text.getAttributedRange({actionTagCancelledAttribution}, 7),
          const SpanRange(7, 7),
        );
      });

      testWidgetsOnAllPlatforms("cancels composing when the user presses ESC", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText("before "),
              ),
            ],
          ),
        );

        // Place the caret at "before |"
        await tester.placeCaretInParagraph("1", 7);

        // Start composing a tag.
        await tester.typeImeText("/stuff");

        // Ensure that we're composing.
        var text = SuperEditorInspector.findTextInComponent("1");
        expect(
          text.getAttributedRange({actionTagComposingAttribution}, 7),
          const SpanRange(7, 12),
        );

        // Cancel composing.
        await tester.pressEscape();

        // Ensure that the composing was cancelled.
        text = SuperEditorInspector.findTextInComponent("1");
        expect(
          text.getAttributionSpansInRange(
            attributionFilter: (attribution) => attribution == actionTagComposingAttribution,
            range: const SpanRange(0, 12),
          ),
          isEmpty,
        );
        expect(
          text.getAttributedRange({actionTagCancelledAttribution}, 7),
          const SpanRange(7, 7),
        );

        // Start typing again.
        await tester.typeImeText(" ");

        // Ensure that we didn't start composing again.
        text = SuperEditorInspector.findTextInComponent("1");
        expect(text.toPlainText(), "before /stuff ");
        expect(
          text.getAttributionSpansInRange(
            attributionFilter: (attribution) => attribution == actionTagComposingAttribution,
            range: const SpanRange(0, 13),
          ),
          isEmpty,
        );
        expect(
          text.getAttributedRange({actionTagCancelledAttribution}, 7),
          const SpanRange(7, 7),
        );
      });

      testWidgetsOnDesktop("cancels composing when deleting the trigger character", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText("before after"),
              ),
            ],
          ),
        );

        // Place the caret at "before |after"
        await tester.placeCaretInParagraph("1", 7);

        // Start composing a tag.
        await tester.typeImeText("/");

        // Press backspace to delete the tag.
        await tester.pressBackspace();

        // Ensure nothing is attributed, because we didn't type any characters
        // after the initial "/".
        expect(
          SuperEditorInspector.findTextInComponent("1").getAttributionSpansInRange(
            attributionFilter: (candidate) => candidate == actionTagComposingAttribution,
            range: const SpanRange(0, 13),
          ),
          isEmpty,
        );

        // Start composing the tag again.
        await tester.typeImeText("/header");

        // Ensure that "/header" is attributed.
        final spans = SuperEditorInspector.findTextInComponent("1").getAttributionSpansInRange(
          attributionFilter: (attribution) => attribution == actionTagComposingAttribution,
          range: const SpanRange(0, 19),
        );
        expect(spans.length, 1);
        expect(
          spans.first,
          const AttributionSpan(
            attribution: actionTagComposingAttribution,
            start: 7,
            end: 13,
          ),
        );
      });

      testWidgetsOnMobile("cancels composing when deleting the trigger character with software keyboard",
          (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText("before after"),
              ),
            ],
          ),
        );

        // Place the caret at "before |after"
        await tester.placeCaretInParagraph("1", 7);

        // Start composing a tag.
        await tester.typeImeText("/");

        // Simulate the user pressing backspace on the software keyboard.
        await tester.ime.sendDeltas([
          const TextEditingDeltaNonTextUpdate(
            oldText: '. before /after',
            selection: TextSelection(baseOffset: 9, extentOffset: 9),
            composing: TextRange.empty,
          ),
          const TextEditingDeltaDeletion(
            oldText: '. before /after',
            deletedRange: TextSelection(baseOffset: 9, extentOffset: 10),
            selection: TextSelection(baseOffset: 9, extentOffset: 9),
            composing: TextRange.empty,
          ),
        ], getter: imeClientGetter);

        // Ensure nothing is attributed, because we didn't type any characters
        // after the initial "/".
        expect(
          SuperEditorInspector.findTextInComponent("1").getAttributionSpansInRange(
            attributionFilter: (candidate) => candidate == actionTagComposingAttribution,
            range: const SpanRange(0, 13),
          ),
          isEmpty,
        );

        // Start composing the tag again.
        await tester.typeImeText("/header");

        // Ensure that "/header" is attributed.
        final spans = SuperEditorInspector.findTextInComponent("1").getAttributionSpansInRange(
          attributionFilter: (attribution) => attribution == actionTagComposingAttribution,
          range: const SpanRange(0, 19),
        );
        expect(spans.length, 1);
        expect(
          spans.first,
          const AttributionSpan(
            attribution: actionTagComposingAttribution,
            start: 7,
            end: 13,
          ),
        );
      });

      testWidgetsOnAllPlatforms("does not re-apply a canceled tag", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText("before  after"),
              ),
            ],
          ),
        );

        // Place the caret at "before | after"
        await tester.placeCaretInParagraph("1", 7);

        // Start composing a tag.
        await tester.typeImeText("/");

        // Ensure that we're composing.
        var text = SuperEditorInspector.findTextInComponent("1");
        expect(
          text.getAttributedRange({actionTagComposingAttribution}, 7),
          const SpanRange(7, 7),
        );

        // Move the caret to "before |/ after"
        await tester.pressLeftArrow();

        // Ensure we are not composing anymore.
        expect(
          SuperEditorInspector.findTextInComponent("1").getAttributionSpansInRange(
            attributionFilter: (candidate) => candidate == actionTagComposingAttribution,
            range: const SpanRange(0, 14),
          ),
          isEmpty,
        );

        // Move the caret to "before /| after"
        await tester.pressRightArrow();

        // Ensure we are still not composing.
        expect(
          SuperEditorInspector.findTextInComponent("1").getAttributionSpansInRange(
            attributionFilter: (candidate) => candidate == actionTagComposingAttribution,
            range: const SpanRange(0, 14),
          ),
          isEmpty,
        );
      });

      testWidgetsOnAllPlatforms("only notifies tag index listeners when tags change", (tester) async {
        final actionTagPlugin = ActionTagsPlugin();

        await _pumpTestEditor(
          tester,
          singleParagraphEmptyDoc(),
          plugin: actionTagPlugin,
        );
        await tester.placeCaretInParagraph("1", 0);

        // Listen for tag notifications.
        int tagNotificationCount = 0;
        actionTagPlugin.composingActionTag.addListener(() {
          tagNotificationCount += 1;
        });

        // Type some non tag text.
        await tester.typeImeText("hello ");

        // Ensure that no tag notifications were sent, because the typed text
        // has no tag artifacts.
        expect(tagNotificationCount, 0);

        // Start a tag.
        await tester.typeImeText("/");

        // Ensure that we received one notification when the tag started.
        expect(tagNotificationCount, 1);

        // Create and update a tag.
        await tester.typeImeText("world");

        // Ensure that we received a notification for every character we typed.
        expect(tagNotificationCount, 6);

        // Cancel the tag.
        await tester.pressEscape();

        // Ensure that we received a notification when the tag was cancelled.
        expect(tagNotificationCount, 7);
      });

      testWidgetsOnAllPlatforms("does not start composing when placing the caret at an existing tag pattern",
          (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText("This is origin/main branch"),
              ),
            ],
          ),
        );

        // Place the caret at "mai|n".
        await tester.placeCaretInParagraph("1", 18);

        // Ensure that we are not composing a tag.
        final text = SuperEditorInspector.findTextInComponent("1");
        expect(
          text.getAttributionSpansInRange(
            attributionFilter: (attribution) => attribution == actionTagComposingAttribution,
            range: const SpanRange(0, 26),
          ),
          isEmpty,
        );
      });

      testWidgetsOnAllPlatforms("updates composing when moving the caret within an existing composing tag",
          (tester) async {
        await _pumpTestEditor(
          tester,
          singleParagraphEmptyDoc(),
        );
        await tester.placeCaretInParagraph("1", 0);

        // Compose an action tag.
        await tester.typeImeText("/header");

        // Ensure that the tag has a composing attribution.
        final textBefore = SuperEditorInspector.findTextInComponent("1");
        expect(
          textBefore.getAttributedRange({actionTagComposingAttribution}, 0),
          const SpanRange(0, 6),
        );

        // Press the left arrow to move the caret within the tag.
        await tester.pressLeftArrow();

        // Ensure that the tag was updated.
        final textAfter = SuperEditorInspector.findTextInComponent("1");
        expect(
          textAfter.getAttributedRange({actionTagComposingAttribution}, 0),
          const SpanRange(0, 5),
        );
      });
    });

    group("submissions >", () {
      testWidgetsOnAllPlatforms("at the beginning of a paragraph", (tester) async {
        await _pumpTestEditor(
          tester,
          singleParagraphEmptyDoc(),
        );

        // Place the caret in the empty paragraph.
        await tester.placeCaretInParagraph("1", 0);

        // Compose an action tag.
        await tester.typeImeText("/header");

        // Submit the tag.
        await tester.pressEnter();

        // Ensure that the action tag was removed after submission.
        final text = SuperEditorInspector.findTextInComponent("1");
        expect(text.toPlainText(), "");
      });

      testWidgetsOnAllPlatforms("after existing text", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText("before "),
              ),
            ],
          ),
        );

        // Place the caret at "before |"
        await tester.placeCaretInParagraph("1", 7);

        // Compose an action tag
        await tester.typeImeText("/header");

        // Submit the tag.
        await tester.pressEnter();

        // Ensure that the action tag was removed.
        final text = SuperEditorInspector.findTextInComponent("1");
        expect(text.toPlainText(), "before ");
        expect(
          text.getAttributionSpansInRange(
            attributionFilter: (attribution) => attribution == actionTagComposingAttribution,
            range: const SpanRange(0, 6),
          ),
          isEmpty,
        );
      });

      testWidgetsOnAllPlatforms("in the middle of text", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText("before  after"),
              ),
            ],
          ),
        );

        // Place the caret at "before | after"
        await tester.placeCaretInParagraph("1", 7);

        // Compose an action tag
        await tester.typeImeText("/header");

        // Submit the tag.
        await tester.pressEnter();

        // Ensure that the action tag was removed.
        final text = SuperEditorInspector.findTextInComponent("1");
        expect(text.toPlainText(), "before  after");
        expect(
          text.getAttributionSpansInRange(
            attributionFilter: (attribution) => attribution == actionTagComposingAttribution,
            range: const SpanRange(0, 12),
          ),
          isEmpty,
        );
      });

      testWidgetsOnAllPlatforms("at the beginning of a word", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText("before after"),
              ),
            ],
          ),
        );

        // Place the caret at "before |after".
        await tester.placeCaretInParagraph("1", 7);

        // Compose an action tag.
        await tester.typeImeText("/header");

        // Ensure only "/header" is attributed.
        AttributedText? text = SuperEditorInspector.findTextInComponent("1");
        final spans = text.getAttributionSpansInRange(
          attributionFilter: (attribution) => attribution == actionTagComposingAttribution,
          range: const SpanRange(0, 19),
        );
        expect(spans.length, 1);
        expect(
          spans.first,
          const AttributionSpan(
            attribution: actionTagComposingAttribution,
            start: 7,
            end: 13,
          ),
        );

        // Submit the tag.
        await tester.pressEnter();

        // Ensure that the action tag was removed.
        text = SuperEditorInspector.findTextInComponent("1");
        expect(text.toPlainText(), "before after");
        expect(
          text.getAttributionSpansInRange(
            attributionFilter: (attribution) => attribution == actionTagComposingAttribution,
            range: const SpanRange(0, 12),
          ),
          isEmpty,
        );
      });
    });
  });

  group("selections >", () {
    testWidgetsOnArbitraryDesktop('does not extract a tag when the selection is expanded', (tester) async {
      await _pumpTestEditor(
        tester,
        MutableDocument(nodes: [
          ParagraphNode(id: '1', text: AttributedText('A paragraph')),
          // It's important that the second paragraph is longer than the first to ensure
          // that we don't try to access a character in the first paragraph using an index
          // from the second paragraph.
          ParagraphNode(id: '2', text: AttributedText('Another paragraph with longer text')),
        ]),
      );

      // Place the caret at the end of the second paragraph.
      await tester.placeCaretInParagraph('2', 34);

      // Press CMD + SHIFT + ARROW UP to expand the selection to the beginning of
      // the document.
      await tester.pressShiftCmdUpArrow();

      // Ensure nothing in the first paragraph is attributed.
      final firstParagraphText = SuperEditorInspector.findTextInComponent("1");
      expect(
        firstParagraphText.getAttributionSpansInRange(
          attributionFilter: (attribution) => attribution == actionTagComposingAttribution,
          range: SpanRange(0, firstParagraphText.length),
        ),
        isEmpty,
      );

      // Ensure nothing in the second paragraph is attributed.
      final secondParagraphText = SuperEditorInspector.findTextInComponent("1");
      expect(
        secondParagraphText.getAttributionSpansInRange(
          attributionFilter: (attribution) => attribution == actionTagComposingAttribution,
          range: SpanRange(0, secondParagraphText.length),
        ),
        isEmpty,
      );
    });

    testWidgetsOnAllPlatforms("does not extract a tag when expanding the selection from a non-text node",
        (tester) async {
      await _pumpTestEditor(
        tester,
        paragraphThenHrDoc(),
      );

      // Create cancelled action tag
      await tester.placeCaretInParagraph("1", 0);
      await tester.typeImeText("/header ");

      // Place cursor at the end of the horizontal rule/block node
      await tester.pressDownArrow();
      await tester.pressRightArrow();

      // Expand the selection to the first paragraph.
      await tester.pressShiftLeftArrow();
      await tester.pressShiftUpArrow();

      // Ensure nothing in the paragraph is attributed.
      final text = SuperEditorInspector.findTextInComponent("1");
      expect(
        text.getAttributionSpansInRange(
          attributionFilter: (attribution) => attribution == actionTagComposingAttribution,
          range: SpanRange(0, text.length),
        ),
        isEmpty,
      );
    });
  });
}

Future<TestDocumentContext> _pumpTestEditor(
  WidgetTester tester,
  MutableDocument document, {
  TagRule? tagRule,
  ActionTagsPlugin? plugin,
}) async {
  assert(tagRule == null || plugin == null,
      "You can provide a custom tagRule, or a custom ActionsTagPlugin, but not both");

  final actionTagPlugin = plugin ?? ActionTagsPlugin(tagRule: tagRule ?? defaultActionTagRule);

  return await tester //
      .createDocument()
      .withCustomContent(document)
      .withAddedKeyboardActions(prepend: [
        // In real apps, the app needs to decide when to submit an action tag.
        // For the purpose of tests, we'll arbitrarily choose to submit on enter.
        _submitOnEnter,
      ])
      .withPlugin(actionTagPlugin)
      .pump();
}

ExecutionInstruction _submitOnEnter({
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
}) {
  if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) {
    return ExecutionInstruction.continueExecution;
  }
  if (keyEvent.logicalKey != LogicalKeyboardKey.enter) {
    return ExecutionInstruction.continueExecution;
  }

  editContext.editor.execute([
    const SubmitComposingActionTagRequest(),
  ]);

  return ExecutionInstruction.haltExecution;
}
