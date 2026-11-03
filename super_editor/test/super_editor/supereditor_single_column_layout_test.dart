import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

void main() {
  group('SuperEditor > single column layout >', () {
    testWidgetsOnAllPlatforms('updates component width when component styles are changed by the editor',
        (tester) async {
      // Pump an editor with an arbitrary size, so we know
      // the maximum width a component can be.
      final context = await tester
          .createDocument() //
          .withCustomContent(
            MutableDocument(nodes: [
              ParagraphNode(
                id: '1',
                text: AttributedText(),
                metadata: const SingleColumnLayoutComponentStyles(
                  width: 600.0,
                ).toMetadata(),
              ),
            ]),
          )
          .withEditorSize(const Size(1000.0, 5000.0))
          .useStylesheet(
            defaultStylesheet.copyWith(addRulesAfter: [
              StyleRule(
                BlockSelector.all,
                (doc, docNode) => {
                  // Zeroes the padding so the component is exactly
                  // the requested size.
                  Styles.padding: const CascadingPadding.all(0.0),
                },
              )
            ]),
          )
          .pump();

      // Ensure the component initially has the requested size.
      expect(SuperEditorInspector.findComponentSize('1').width, 600.0);

      // Change the width the of the first component in the document layout.
      context.editor.execute(
        const [
          ChangeSingleColumnLayoutComponentStylesRequest(
            nodeId: '1',
            styles: SingleColumnLayoutComponentStyles(
              width: 400.0,
            ),
          ),
        ],
      );
      await tester.pump();

      // Ensure the component width changed to the requested value.
      expect(SuperEditorInspector.findComponentSize('1').width, 400.0);
    });

    group('components >', () {
      testWidgetsOnAllPlatforms('keep their state with their node when a node is inserted above them', (tester) async {
        final context = await _pumpParagraphsWithStatefulComponents(tester);

        // Insert a node at the top of the document.
        context.editor.execute([
          InsertNodeAtIndexRequest(
            nodeIndex: 0,
            newNode: ParagraphNode(id: 'inserted', text: AttributedText('An inserted paragraph')),
          ),
        ]);
        await tester.pump();

        // Ensure that every component kept the state that was created for its node.
        expect(
          _findComponentsWithStateOfAnotherNode(tester),
          isEmpty,
          reason: 'Inserting a node at the top gave components the state of other nodes',
        );
      });

      testWidgetsOnAllPlatforms('keep their state with their node when a node above them is deleted', (tester) async {
        final context = await _pumpParagraphsWithStatefulComponents(tester);

        // Delete the first node of the document.
        context.editor.execute([
          DeleteNodeRequest(nodeId: '1'),
        ]);
        await tester.pump();

        // Ensure that every component kept the state that was created for its node.
        expect(
          _findComponentsWithStateOfAnotherNode(tester),
          isEmpty,
          reason: 'Deleting the first node gave components the state of other nodes',
        );
      });

      testWidgetsOnAllPlatforms('keep their state with their node when a node above them moves below them',
          (tester) async {
        final context = await _pumpParagraphsWithStatefulComponents(tester);

        // Move the first node of the document to the end.
        context.editor.execute([
          const MoveNodeRequest(nodeId: '1', newIndex: 3),
        ]);
        await tester.pump();

        // Ensure that every component kept the state that was created for its node.
        expect(
          _findComponentsWithStateOfAnotherNode(tester),
          isEmpty,
          reason: 'Moving the first node to the end gave components the state of other nodes',
        );
      });

      testWidgetsOnAllPlatforms("keep a list item's state with its node when a node is inserted above it",
          (tester) async {
        final context = await tester
            .createDocument() //
            .withCustomContent(
              MutableDocument(
                nodes: [
                  ParagraphNode(id: '1', text: AttributedText('A paragraph')),
                  ListItemNode.unordered(id: '2', text: AttributedText('The first list item')),
                  ListItemNode.unordered(id: '3', text: AttributedText('The second list item')),
                ],
              ),
            )
            .pump();

        // Remember the state of the second list item's component.
        final listItemState = _findUnorderedListItemState('3');

        // Insert a node at the top of the document.
        context.editor.execute([
          InsertNodeAtIndexRequest(
            nodeIndex: 0,
            newNode: ParagraphNode(id: 'inserted', text: AttributedText('An inserted paragraph')),
          ),
        ]);
        await tester.pump();

        // Ensure that the second list item kept the state of its component.
        expect(
          identical(_findUnorderedListItemState('3'), listItemState),
          isTrue,
          reason: "Inserting a node at the top gave the second list item another component's state",
        );
      });

      testWidgetsOnAllPlatforms('build a document that holds two nodes with the same ID', (tester) async {
        // A document can briefly hold two nodes with the same ID, e.g., while an app applies
        // changes from a server. Keying components by node mustn't give two sibling
        // components the same key, which Flutter doesn't allow.
        await tester
            .createDocument() //
            .withCustomContent(
              MutableDocument(
                nodes: [
                  ParagraphNode(id: '1', text: AttributedText('The first paragraph')),
                  ParagraphNode(id: 'shared', text: AttributedText('The second paragraph')),
                  ParagraphNode(id: '3', text: AttributedText('The third paragraph')),
                  ParagraphNode(id: 'shared', text: AttributedText('A paragraph with the ID of the second')),
                ],
              ),
            )
            .pump();

        // Ensure that the document was built, with both nodes that share an ID.
        expect(tester.takeException(), isNull, reason: 'Building a document with a shared node ID threw');
        expect(find.byType(ParagraphComponent), findsNWidgets(4));
      });
    });
  });

  testWidgetsOnAllPlatforms(
      'updates padding around each component in a document layout, when the overall document layout padding is changed by the editor',
      (tester) async {
    final context = await tester
        .createDocument() //
        .withSingleEmptyParagraph()
        .pump();

    // Ensure the component started with some padding.
    final paddingBefore = tester.widget<Padding>(find
        .ancestor(
          of: find.byWidget(SuperEditorInspector.findWidgetForComponent('1')),
          matching: find.byType(Padding),
        )
        .first);
    expect(paddingBefore.padding.horizontal, greaterThan(0.0));

    // Changes the padding.
    context.editor.execute(
      const [
        ChangeSingleColumnLayoutComponentStylesRequest(
          nodeId: '1',
          styles: SingleColumnLayoutComponentStyles(
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
    await tester.pump();

    // Ensure the padding was removed.
    final paddingAfter = tester.widget<Padding>(find
        .ancestor(
          of: find.byWidget(SuperEditorInspector.findWidgetForComponent('1')),
          matching: find.byType(Padding),
        )
        .first);
    expect(paddingAfter.padding.horizontal, 0.0);
  });
}

/// Pumps a [SuperEditor] with four paragraphs, whose IDs are "1" through "4", and whose
/// components each keep state of their own, above the component, as an app's component
/// might keep, e.g., whether it's collapsed.
Future<TestDocumentContext> _pumpParagraphsWithStatefulComponents(WidgetTester tester) async {
  return await tester
      .createDocument() //
      .withCustomContent(
        MutableDocument(
          nodes: [
            ParagraphNode(id: '1', text: AttributedText('The first paragraph')),
            ParagraphNode(id: '2', text: AttributedText('The second paragraph')),
            ParagraphNode(id: '3', text: AttributedText('The third paragraph')),
            ParagraphNode(id: '4', text: AttributedText('The fourth paragraph')),
          ],
        ),
      )
      .withAddedComponents([const _StatefulParagraphComponentBuilder()]).pump();
}

/// Describes every component whose state was created for a node other than the node that
/// the component now displays, e.g., "node 2 has the state of node 1".
List<String> _findComponentsWithStateOfAnotherNode(WidgetTester tester) {
  return tester
      .stateList<_NodeStateState>(find.byType(_NodeState, skipOffstage: false))
      .where((state) => state.widget.nodeId != state.nodeIdAtCreation)
      .map((state) => 'node ${state.widget.nodeId} has the state of node ${state.nodeIdAtCreation}')
      .toList();
}

/// Returns the state of the [UnorderedListItemComponent] that displays the node with the
/// given [nodeId].
State<UnorderedListItemComponent> _findUnorderedListItemState(String nodeId) {
  final component = SuperEditorInspector.findDocumentLayout().getComponentByNodeId(nodeId)!;
  return component.context.findAncestorStateOfType<State<UnorderedListItemComponent>>()!;
}

/// A [ComponentBuilder] that builds each paragraph's component within a [_NodeState], which
/// keeps state of its own, above the component.
class _StatefulParagraphComponentBuilder implements ComponentBuilder {
  const _StatefulParagraphComponentBuilder();

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) => null;

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! ParagraphComponentViewModel) {
      return null;
    }

    return _NodeState(
      nodeId: componentViewModel.nodeId,
      child: const ParagraphComponentBuilder().createComponent(componentContext, componentViewModel)!,
    );
  }
}

/// A widget whose state remembers the node that it was created for, so that a test can tell
/// when the state ends up with another node.
class _NodeState extends StatefulWidget {
  const _NodeState({
    required this.nodeId,
    required this.child,
  });

  /// The ID of the node that [child] displays.
  final String nodeId;

  final Widget child;

  @override
  State<_NodeState> createState() => _NodeStateState();
}

class _NodeStateState extends State<_NodeState> {
  /// The ID of the node that this state was created for.
  late final String nodeIdAtCreation;

  @override
  void initState() {
    super.initState();
    nodeIdAtCreation = widget.nodeId;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
