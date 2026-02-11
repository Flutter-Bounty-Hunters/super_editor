import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:super_editor/super_test.dart';

void main() {
  group('SuperEditor', () {
    group('autofocus', () {
      testWidgets('does not claim focus when autofocus is false', (tester) async {
        // Configure and render a document.
        await tester //
            .createDocument()
            .withSingleParagraph()
            .withInputSource(inputAndGestureVariants.currentValue!.inputSource)
            .withGestureMode(inputAndGestureVariants.currentValue!.gestureMode)
            .autoFocus(false)
            .pump();

        expect(SuperEditorInspector.hasFocus(), false);
      }, variant: inputAndGestureVariants);

      testWidgets('claims focus when autofocus is true', (tester) async {
        // Configure and render a document.
        await tester //
            .createDocument()
            .withSingleParagraph()
            .withInputSource(inputAndGestureVariants.currentValue!.inputSource)
            .withGestureMode(inputAndGestureVariants.currentValue!.gestureMode)
            .autoFocus(true)
            .pump();

        expect(SuperEditorInspector.hasFocus(), true);
      }, variant: inputAndGestureVariants);

      testWidgets('claims focus by gesture when autofocus is false', (tester) async {
        // Configure and render a document.
        await tester //
            .createDocument()
            .withSingleParagraph()
            .withInputSource(inputAndGestureVariants.currentValue!.inputSource)
            .withGestureMode(inputAndGestureVariants.currentValue!.gestureMode)
            .autoFocus(false)
            .pump();

        await tester.placeCaretInParagraph("1", 0);

        expect(SuperEditorInspector.hasFocus(), true);
      }, variant: inputAndGestureVariants);
    });

    group("restores selection after re-focus", () {
      testWidgetsOnAllPlatforms("when selection is collapsed", (tester) async {
        final focusNode = FocusNode();
        await _pumpFocusChangeLayoutWithSingleParagraph(tester, editorFocusNode: focusNode);

        // Place caret in the middle of a word.
        await tester.placeCaretInParagraph('1', 8);
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 8),
            ),
          ),
        );

        // Focus the textfield.
        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();

        // Ensure selection was cleared.
        expect(SuperEditorInspector.findDocumentSelection(), isNull);

        // Focus the editor.
        focusNode.requestFocus();
        await tester.pumpAndSettle();

        // Ensure selection was restored.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 8),
            ),
          ),
        );
      });

      testWidgetsOnAllPlatforms("when selection is expanded", (tester) async {
        final editorFocusNode = FocusNode();
        final testContext = await _pumpFocusChangeLayoutWithSingleParagraph(tester, editorFocusNode: editorFocusNode);

        // Tap on editor to give it focus.
        await tester.placeCaretInParagraph('1', 0);

        // Select some text.
        testContext.editor.execute([
          const ChangeSelectionRequest(
            DocumentSelection(
              base: DocumentPosition(
                nodeId: '1',
                nodePosition: TextNodePosition(offset: 0),
              ),
              extent: DocumentPosition(
                nodeId: '1',
                nodePosition: TextNodePosition(offset: 8),
              ),
            ),
            SelectionChangeType.expandSelection,
            SelectionReason.userInteraction,
          ),
        ]);
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection(
            base: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 0),
            ),
            extent: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 8),
            ),
          ),
        );

        // Focus the textfield.
        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();

        // Ensure selection was cleared.
        expect(SuperEditorInspector.findDocumentSelection(), isNull);

        // Focus the editor.
        editorFocusNode.requestFocus();
        await tester.pumpAndSettle();

        // Ensure selection was restored.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection(
            base: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 0),
            ),
            extent: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 8),
            ),
          ),
        );
      });
    });

    group("throws away stale selection after re-focus", () {
      group("with caret", () {
        testWidgetsOnAllPlatforms("when content type changes", (tester) async {
          final focusNode = FocusNode();
          final testContext = await _pumpFocusChangeLayoutWithSingleParagraph(tester, editorFocusNode: focusNode);

          // Place caret in the middle of a word.
          await tester.placeCaretInParagraph('1', 8);
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: '1',
                nodePosition: TextNodePosition(offset: 8),
              ),
            ),
          );

          // Focus the textfield.
          await tester.tap(find.byType(TextField));
          await tester.pumpAndSettle();

          // Ensure selection was cleared.
          expect(SuperEditorInspector.findDocumentSelection(), isNull);

          // Replace the paragraph with a horizontal rule.
          testContext.editor.execute([
            ReplaceNodeRequest(
              existingNodeId: '1',
              newNode: HorizontalRuleNode(id: '1'),
            ),
          ]);

          // Focus the editor.
          focusNode.requestFocus();
          await tester.pumpAndSettle();

          // Ensure selection is cleared.
          expect(SuperEditorInspector.findDocumentSelection(), isNull);
        });

        testWidgetsOnAllPlatforms("when it no longer fits in text", (tester) async {
          final focusNode = FocusNode();
          final testContext = await _pumpFocusChangeLayoutWithSingleParagraph(tester, editorFocusNode: focusNode);

          // Place caret in the middle of a word.
          await tester.placeCaretInParagraph('1', 8);
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: '1',
                nodePosition: TextNodePosition(offset: 8),
              ),
            ),
          );

          // Focus the textfield.
          await tester.tap(find.byType(TextField));
          await tester.pumpAndSettle();

          // Ensure selection was cleared.
          expect(SuperEditorInspector.findDocumentSelection(), isNull);

          // Delete text to make selection invalid.
          final textNode = testContext.document.first as TextNode;
          testContext.editor.execute([
            DeleteContentRequest(
              documentRange: DocumentRange(
                start: DocumentPosition(nodeId: textNode.id, nodePosition: textNode.beginningPosition),
                end: DocumentPosition(nodeId: textNode.id, nodePosition: textNode.endPosition),
              ),
            ),
          ]);

          // Focus the editor.
          focusNode.requestFocus();
          await tester.pumpAndSettle();

          // Ensure selection is cleared.
          expect(SuperEditorInspector.findDocumentSelection(), isNull);
        });
      });

      group("with expanded selection within a node", () {
        testWidgetsOnAllPlatforms("when downstream no longer fits", (tester) async {
          final editorFocusNode = FocusNode();
          final testContext = await _pumpFocusChangeLayoutWithSingleParagraph(tester, editorFocusNode: editorFocusNode);

          // Tap on editor to give it focus.
          await tester.placeCaretInParagraph('1', 0);

          // Select some text.
          testContext.editor.execute([
            const ChangeSelectionRequest(
              DocumentSelection(
                base: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 0),
                ),
                extent: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 8),
                ),
              ),
              SelectionChangeType.expandSelection,
              SelectionReason.userInteraction,
            ),
          ]);
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection(
              base: DocumentPosition(
                nodeId: '1',
                nodePosition: TextNodePosition(offset: 0),
              ),
              extent: DocumentPosition(
                nodeId: '1',
                nodePosition: TextNodePosition(offset: 8),
              ),
            ),
          );

          // Focus the textfield.
          await tester.tap(find.byType(TextField));
          await tester.pumpAndSettle();

          // Ensure selection was cleared.
          expect(SuperEditorInspector.findDocumentSelection(), isNull);

          // Delete the text so that the selection extent is no longer valid.
          final textNode = testContext.document.first as TextNode;
          testContext.editor.execute([
            DeleteContentRequest(
              documentRange: DocumentRange(
                start: DocumentPosition(nodeId: textNode.id, nodePosition: textNode.beginningPosition),
                end: DocumentPosition(nodeId: textNode.id, nodePosition: textNode.endPosition),
              ),
            ),
          ]);

          // Focus the editor.
          editorFocusNode.requestFocus();
          await tester.pumpAndSettle();

          // Ensure selection is cleared.
          expect(SuperEditorInspector.findDocumentSelection(), isNull);
        });

        testWidgetsOnAllPlatforms("when content type changes", (tester) async {
          final focusNode = FocusNode();
          final testContext = await _pumpFocusChangeLayoutWithSingleParagraph(tester, editorFocusNode: focusNode);

          // Tap on editor to give it focus.
          await tester.placeCaretInParagraph('1', 0);

          // Select some text.
          testContext.editor.execute([
            const ChangeSelectionRequest(
              DocumentSelection(
                base: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 0),
                ),
                extent: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 8),
                ),
              ),
              SelectionChangeType.expandSelection,
              SelectionReason.userInteraction,
            ),
          ]);
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection(
              base: DocumentPosition(
                nodeId: '1',
                nodePosition: TextNodePosition(offset: 0),
              ),
              extent: DocumentPosition(
                nodeId: '1',
                nodePosition: TextNodePosition(offset: 8),
              ),
            ),
          );

          // Focus the textfield.
          await tester.tap(find.byType(TextField));
          await tester.pumpAndSettle();

          // Ensure selection was cleared.
          expect(SuperEditorInspector.findDocumentSelection(), isNull);

          // Replace the paragraph with a horizontal rule.
          testContext.editor.execute([
            ReplaceNodeRequest(
              existingNodeId: '1',
              newNode: HorizontalRuleNode(id: '1'),
            ),
          ]);

          // Focus the editor.
          focusNode.requestFocus();
          await tester.pumpAndSettle();

          // Ensure selection is cleared.
          expect(SuperEditorInspector.findDocumentSelection(), isNull);
        });
      });

      group("with expanded selection across nodes", () {
        testWidgetsOnAllPlatforms("when the base and extent content type changes", (tester) async {
          final focusNode = FocusNode();
          final testContext = await _pumpFocusChangeLayoutWithTwoParagraphs(tester, editorFocusNode: focusNode);

          // Tap on editor to give it focus.
          await tester.placeCaretInParagraph('1', 0);

          // Select some text.
          testContext.editor.execute([
            const ChangeSelectionRequest(
              DocumentSelection(
                base: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 0),
                ),
                extent: DocumentPosition(
                  nodeId: '2',
                  nodePosition: TextNodePosition(offset: 8),
                ),
              ),
              SelectionChangeType.placeCaret,
              SelectionReason.userInteraction,
            ),
          ]);
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection(
              base: DocumentPosition(
                nodeId: '1',
                nodePosition: TextNodePosition(offset: 0),
              ),
              extent: DocumentPosition(
                nodeId: '2',
                nodePosition: TextNodePosition(offset: 8),
              ),
            ),
          );

          // Focus the textfield.
          await tester.tap(find.byType(TextField));
          await tester.pumpAndSettle();

          // Ensure selection was cleared.
          expect(SuperEditorInspector.findDocumentSelection(), isNull);

          // Replace the paragraphs with horizontal rules.
          testContext.editor.execute([
            ReplaceNodeRequest(
              existingNodeId: '1',
              newNode: HorizontalRuleNode(id: '1'),
            ),
            ReplaceNodeRequest(
              existingNodeId: '2',
              newNode: HorizontalRuleNode(id: '2'),
            ),
          ]);

          // Focus the editor.
          focusNode.requestFocus();
          await tester.pumpAndSettle();

          // Ensure selection is cleared.
          expect(SuperEditorInspector.findDocumentSelection(), isNull);
        });

        testWidgetsOnAllPlatforms("when the base content type changes", (tester) async {
          final focusNode = FocusNode();
          final testContext = await _pumpFocusChangeLayoutWithTwoParagraphs(tester, editorFocusNode: focusNode);

          // Tap on editor to give it focus.
          await tester.placeCaretInParagraph('1', 0);

          // Select some text.
          testContext.editor.execute([
            const ChangeSelectionRequest(
              DocumentSelection(
                base: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 0),
                ),
                extent: DocumentPosition(
                  nodeId: '2',
                  nodePosition: TextNodePosition(offset: 8),
                ),
              ),
              SelectionChangeType.placeCaret,
              SelectionReason.userInteraction,
            ),
          ]);
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection(
              base: DocumentPosition(
                nodeId: '1',
                nodePosition: TextNodePosition(offset: 0),
              ),
              extent: DocumentPosition(
                nodeId: '2',
                nodePosition: TextNodePosition(offset: 8),
              ),
            ),
          );

          // Focus the textfield.
          await tester.tap(find.byType(TextField));
          await tester.pumpAndSettle();

          // Ensure selection was cleared.
          expect(SuperEditorInspector.findDocumentSelection(), isNull);

          // Replace the base paragraph with a horizontal rule.
          testContext.editor.execute([
            ReplaceNodeRequest(
              existingNodeId: '1',
              newNode: HorizontalRuleNode(id: '1'),
            ),
          ]);

          // Focus the editor.
          focusNode.requestFocus();
          await tester.pumpAndSettle();

          // Ensure selection is cleared.
          expect(SuperEditorInspector.findDocumentSelection(), isNull);
        });

        testWidgetsOnAllPlatforms("when the extent content type changes", (tester) async {
          final focusNode = FocusNode();
          final testContext = await _pumpFocusChangeLayoutWithTwoParagraphs(tester, editorFocusNode: focusNode);

          // Tap on editor to give it focus.
          await tester.placeCaretInParagraph('1', 0);

          // Select some text.
          testContext.editor.execute([
            const ChangeSelectionRequest(
              DocumentSelection(
                base: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 0),
                ),
                extent: DocumentPosition(
                  nodeId: '2',
                  nodePosition: TextNodePosition(offset: 8),
                ),
              ),
              SelectionChangeType.placeCaret,
              SelectionReason.userInteraction,
            ),
          ]);
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection(
              base: DocumentPosition(
                nodeId: '1',
                nodePosition: TextNodePosition(offset: 0),
              ),
              extent: DocumentPosition(
                nodeId: '2',
                nodePosition: TextNodePosition(offset: 8),
              ),
            ),
          );

          // Focus the textfield.
          await tester.tap(find.byType(TextField));
          await tester.pumpAndSettle();

          // Ensure selection was cleared.
          expect(SuperEditorInspector.findDocumentSelection(), isNull);

          // Replace the extent paragraph with a horizontal rule.
          testContext.editor.execute([
            ReplaceNodeRequest(
              existingNodeId: '2',
              newNode: HorizontalRuleNode(id: '2'),
            ),
          ]);

          // Focus the editor.
          focusNode.requestFocus();
          await tester.pumpAndSettle();

          // Ensure selection is cleared.
          expect(SuperEditorInspector.findDocumentSelection(), isNull);
        });

        testWidgetsOnAllPlatforms("when the upstream no longer fits", (tester) async {
          final focusNode = FocusNode();
          final testContext = await _pumpFocusChangeLayoutWithTwoParagraphs(tester, editorFocusNode: focusNode);

          // Tap on editor to give it focus.
          await tester.placeCaretInParagraph('1', 0);

          // Select some text.
          testContext.editor.execute([
            const ChangeSelectionRequest(
              DocumentSelection(
                base: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 1),
                ),
                extent: DocumentPosition(
                  nodeId: '2',
                  nodePosition: TextNodePosition(offset: 8),
                ),
              ),
              SelectionChangeType.placeCaret,
              SelectionReason.userInteraction,
            ),
          ]);
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection(
              base: DocumentPosition(
                nodeId: '1',
                nodePosition: TextNodePosition(offset: 1),
              ),
              extent: DocumentPosition(
                nodeId: '2',
                nodePosition: TextNodePosition(offset: 8),
              ),
            ),
          );

          // Focus the textfield.
          await tester.tap(find.byType(TextField));
          await tester.pumpAndSettle();

          // Ensure selection was cleared.
          expect(SuperEditorInspector.findDocumentSelection(), isNull);

          // Delete the text in the upstream node.
          final textNode = testContext.editor.context.document.first as TextNode;
          testContext.editor.execute([
            DeleteContentRequest(
              documentRange: DocumentRange(
                start: DocumentPosition(nodeId: textNode.id, nodePosition: textNode.beginningPosition),
                end: DocumentPosition(nodeId: textNode.id, nodePosition: textNode.endPosition),
              ),
            ),
          ]);

          // Focus the editor.
          focusNode.requestFocus();
          await tester.pumpAndSettle();

          // Ensure selection is cleared.
          expect(SuperEditorInspector.findDocumentSelection(), isNull);
        });

        testWidgetsOnAllPlatforms("when the downstream no longer fits", (tester) async {
          final focusNode = FocusNode();
          final testContext = await _pumpFocusChangeLayoutWithTwoParagraphs(tester, editorFocusNode: focusNode);

          // Tap on editor to give it focus.
          await tester.placeCaretInParagraph('1', 0);

          // Select some text.
          testContext.editor.execute([
            const ChangeSelectionRequest(
              DocumentSelection(
                base: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 0),
                ),
                extent: DocumentPosition(
                  nodeId: '2',
                  nodePosition: TextNodePosition(offset: 8),
                ),
              ),
              SelectionChangeType.placeCaret,
              SelectionReason.userInteraction,
            ),
          ]);
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection(
              base: DocumentPosition(
                nodeId: '1',
                nodePosition: TextNodePosition(offset: 0),
              ),
              extent: DocumentPosition(
                nodeId: '2',
                nodePosition: TextNodePosition(offset: 8),
              ),
            ),
          );

          // Focus the textfield.
          await tester.tap(find.byType(TextField));
          await tester.pumpAndSettle();

          // Ensure selection was cleared.
          expect(SuperEditorInspector.findDocumentSelection(), isNull);

          // Delete the text in the downstream node.
          final textNode = testContext.editor.context.document.last as TextNode;
          testContext.editor.execute([
            DeleteContentRequest(
              documentRange: DocumentRange(
                start: DocumentPosition(nodeId: textNode.id, nodePosition: textNode.beginningPosition),
                end: DocumentPosition(nodeId: textNode.id, nodePosition: textNode.endPosition),
              ),
            ),
          ]);

          // Focus the editor.
          focusNode.requestFocus();
          await tester.pumpAndSettle();

          // Ensure selection is cleared.
          expect(SuperEditorInspector.findDocumentSelection(), isNull);
        });
      });
    });
  });
}

Future<TestDocumentContext> _pumpFocusChangeLayoutWithSingleParagraph(
  WidgetTester tester, {
  required FocusNode editorFocusNode,
  FocusNode? textFieldFocusNode,
}) async {
  return await tester
      .createDocument()
      .withSingleParagraph()
      .withInputSource(TextInputSource.ime)
      .withFocusNode(editorFocusNode)
      // We include StableTagPlugin because its reaction checks the selection change type,
      // and at one point (#2792) Super Editor was reporting "place caret" when restoring
      // an expanded selection. This broke the plugin. So while we don't actually care about
      // this plugin for this test suite, we want to ensure that it doesn't throw any exceptions.
      .withPlugin(StableTagPlugin())
      .withCustomWidgetTreeBuilder(
        (superEditor) => MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                // Add a textfield as a place to temporarily move focus.
                TextField(
                  focusNode: textFieldFocusNode,
                ),
                Expanded(child: superEditor),
              ],
            ),
          ),
        ),
      )
      .pump();
}

Future<TestDocumentContext> _pumpFocusChangeLayoutWithTwoParagraphs(
  WidgetTester tester, {
  required FocusNode editorFocusNode,
  FocusNode? textFieldFocusNode,
}) async {
  return await tester
      .createDocument()
      .withCustomContent(MutableDocument(nodes: [
        ParagraphNode(id: "1", text: AttributedText("Hello, world - 1")),
        ParagraphNode(id: "2", text: AttributedText("Hello, world - 2")),
      ]))
      .withInputSource(TextInputSource.ime)
      .withFocusNode(editorFocusNode)
      .withCustomWidgetTreeBuilder(
        (superEditor) => MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                // Add a textfield as a place to temporarily move focus.
                TextField(
                  focusNode: textFieldFocusNode,
                ),
                Expanded(child: superEditor),
              ],
            ),
          ),
        ),
      )
      .pump();
}
