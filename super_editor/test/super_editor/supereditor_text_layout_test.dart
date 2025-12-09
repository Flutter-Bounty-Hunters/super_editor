import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:super_text_layout/super_text_layout.dart';
import 'package:super_text_layout/super_text_layout_inspector.dart';

void main() {
  group('SuperEditor', () {
    testWidgetsOnAllPlatforms('respects the OS text scaling preference', (tester) async {
      // Pump an editor with a custom textScaleFactor.
      await tester
          .createDocument()
          .withSingleParagraph()
          .withCustomWidgetTreeBuilder(
            (superEditor) => MaterialApp(
              home: Scaffold(
                body: MediaQuery(
                  data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
                  child: superEditor,
                ),
              ),
            ),
          )
          .pump();

      // Ensure the configure textScaleFactor was applied.
      expect(SuperTextInspector.findTextScaler().scale(1.0), 1.5);
    });

    testWidgetsOnAllPlatforms('does not rebuild unmodified nodes', (tester) async {
      final document = MutableDocument(
        nodes: [
          ParagraphNode(id: "paragraph-1", text: AttributedText("Paragraph one")),
          ParagraphNode(id: "paragraph-2", text: AttributedText("Paragraph two")),
          ParagraphNode(id: "paragraph-3", text: AttributedText("Paragraph three")),
          ListItemNode.unordered(id: "unordered-1", text: AttributedText("Unordered list item one")),
          ListItemNode.unordered(id: "unordered-2", text: AttributedText("Unordered list item two")),
          ListItemNode.unordered(id: "unordered-3", text: AttributedText("Unordered list item three")),
          ListItemNode.ordered(id: "ordered-1", text: AttributedText("Ordered list item one")),
          ListItemNode.ordered(id: "ordered-2", text: AttributedText("Ordered list item two")),
          ListItemNode.ordered(id: "ordered-3", text: AttributedText("Ordered list item three")),
          TaskNode(id: "task-1", text: AttributedText("Task one"), isComplete: false),
          TaskNode(id: "task-2", text: AttributedText("Task two"), isComplete: false),
          TaskNode(id: "task-3", text: AttributedText("Task three"), isComplete: false),
        ],
      );
      final composer = MutableDocumentComposer();
      final editor = createDefaultDocumentEditor(document: document, composer: composer);

      // Keeps track of the build count for each node.
      Map<String, int> buildCountPerNode = {
        for (final node in document) //
          node.id: 0,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SuperTextAnalytics(
              trackBuilds: true,
              child: SuperEditor(
                editor: editor,
                componentBuilders: [
                  TaskComponentBuilder(editor),
                  ...defaultComponentBuilders,
                ],
              ),
            ),
          ),
        ),
      );

      // Ensure each node was built a single time.
      Map<String, int> newBuildCountPerNode = _findRebuildCountPerNode(document);
      for (final pair in newBuildCountPerNode.entries) {
        expect(pair.value, 1, reason: 'Node with id ${pair.key} was rebuilt more times than expected');
      }

      // Update the current build count to perform the subsequent expectations.
      buildCountPerNode = newBuildCountPerNode;

      // Modify the first paragraph.
      await tester.placeCaretInParagraph('paragraph-1', 0);
      await tester.typeImeText('a');

      // Ensure only that paragraph was rebuilt.
      newBuildCountPerNode = _findRebuildCountPerNode(document);
      _ensureOnlyExpectedNodesRebuilt(
        previousBuildCount: buildCountPerNode,
        currentBuildCount: newBuildCountPerNode,
        expectedRebuiltNodes: {'paragraph-1'},
      );

      // Update the current build count to perform the subsequent expectations.
      buildCountPerNode = newBuildCountPerNode;

      // Modify the first unordered list item.
      await tester.placeCaretInParagraph('unordered-1', 0);
      await tester.typeImeText('a');

      // Ensure only that list item and the previously selected paragraph were rebuilt.
      newBuildCountPerNode = _findRebuildCountPerNode(document);
      _ensureOnlyExpectedNodesRebuilt(
        previousBuildCount: buildCountPerNode,
        currentBuildCount: newBuildCountPerNode,
        expectedRebuiltNodes: {'paragraph-1', 'unordered-1'},
      );

      // Update the current build count to perform the subsequent expectations.
      buildCountPerNode = newBuildCountPerNode;

      // Modify the first ordered list item.
      await tester.placeCaretInParagraph('ordered-1', 0);
      await tester.typeImeText('a');

      // Ensure only that unoreded list item and the previously selected list item were rebuilt.
      newBuildCountPerNode = _findRebuildCountPerNode(document);
      _ensureOnlyExpectedNodesRebuilt(
        previousBuildCount: buildCountPerNode,
        currentBuildCount: newBuildCountPerNode,
        expectedRebuiltNodes: {'unordered-1', 'ordered-1'},
      );

      // Update the current build count to perform the subsequent expectations.
      buildCountPerNode = newBuildCountPerNode;

      // Modify the first task.
      await tester.placeCaretInParagraph('task-1', 0);
      await tester.typeImeText('a');

      // Ensure only that task and the previously selected list item were rebuilt.
      newBuildCountPerNode = _findRebuildCountPerNode(document);
      _ensureOnlyExpectedNodesRebuilt(
        previousBuildCount: buildCountPerNode,
        currentBuildCount: newBuildCountPerNode,
        expectedRebuiltNodes: {'ordered-1', 'task-1'},
      );
    });
  });
}

/// Returns a map with an entry for each document's node, where the key is the node id
/// and the value is the number of times this node was rebuilt since the widget tree was pumped.
///
/// Only works for nodes that include a `SuperText` in its tree.
Map<String, int> _findRebuildCountPerNode(Document document) {
  final rebuildCountPerNode = <String, int>{};
  for (final node in document) {
    final widget = SuperEditorInspector.findWidgetForComponent<Widget>(node.id);

    final superTextState = (find
            .descendant(of: find.byWidget(widget), matching: find.byType(SuperText))
            .evaluate()
            .first as StatefulElement)
        .state as SuperTextState;

    rebuildCountPerNode[node.id] = superTextState.textBuildCount;
  }

  return rebuildCountPerNode;
}

/// Ensures that only the nodes present in [expectedRebuiltNodes] have increased the build count.
void _ensureOnlyExpectedNodesRebuilt({
  required Map<String, int> previousBuildCount,
  required Map<String, int> currentBuildCount,
  required Set<String> expectedRebuiltNodes,
}) {
  for (final pair in previousBuildCount.entries) {
    if (expectedRebuiltNodes.contains(pair.key)) {
      // Ensure that this node was rebuilt.
      expect(currentBuildCount[pair.key], greaterThan(pair.value),
          reason: 'Node with id ${pair.key} wasn\'t rebuilt when it should');
    } else {
      // Ensure that this node wasn't rebuilt.
      expect(currentBuildCount[pair.key], equals(pair.value),
          reason: 'Node with id ${pair.key} was rebuilt when it shouldn\'t');
    }
  }
}
