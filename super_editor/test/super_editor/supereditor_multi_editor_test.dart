import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import 'supereditor_test_tools.dart';

void main() {
  group("SuperEditor > multiple editors >", () {
    testWidgetsOnAllPlatforms("can select both editors", (tester) async {
      final editor1Key = GlobalKey();
      final editor2Key = GlobalKey();

      await _buildTextScaleScaffold(
        tester,
        editor1: _buildSuperEditor(tester, "super-editor-1", key: editor1Key),
        editor2: _buildSuperEditor(tester, "super-editor-2", key: editor2Key),
      );

      // Select different text in each editor.
      // Text starts with: "Lorem ipsum dolor sit amet, consectetur adipiscing...."
      await tester.placeCaretInParagraph("1", 6, superEditorFinder: find.byKey(editor1Key));
      await tester.placeCaretInParagraph("1", 12, superEditorFinder: find.byKey(editor2Key));

      // Ensure that both editors have the expected selections.
      expect(
        SuperEditorInspector.findDocumentSelection(find.byKey(editor1Key)),
        const DocumentSelection.collapsed(
          position: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 6)),
        ),
      );
      expect(
        SuperEditorInspector.findDocumentSelection(find.byKey(editor2Key)),
        const DocumentSelection.collapsed(
          position: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 12)),
        ),
      );
    });
  });

  group("SuperEditor > editor switching >", () {
    testWidgetsOnAllPlatforms("can switch between editors", (tester) async {
      await tester.pumpWidget(const _SwitchEditorsDemo());

      // Ensure that the first editor content is visible.
      expect(SuperEditorInspector.findWidgetForComponent<ParagraphComponent>("Editor1_Header"), isNotNull);
      expect(SuperEditorInspector.findWidgetForComponent<ParagraphComponent>("Editor1_Para"), isNotNull);

      // Switch to the second editor.
      await tester.tap(find.byKey(const ValueKey("Editor2")));
      await tester.pump();

      // Ensure that the second editor content is visible.
      expect(SuperEditorInspector.findWidgetForComponent<ParagraphComponent>("Editor2_Header"), isNotNull);
      expect(SuperEditorInspector.findWidgetForComponent<ParagraphComponent>("Editor2_Para"), isNotNull);
    });

    testWidgetsOnAllPlatforms("restores selection when switching back to a previously selected editor", (tester) async {
      const docSelection1 = DocumentSelection(
        base: DocumentPosition(
          nodeId: "Editor1_Header",
          nodePosition: TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: "Editor1_Para",
          nodePosition: TextNodePosition(offset: 10),
        ),
      );
      final composer1 = MutableDocumentComposer(
        initialSelection: docSelection1,
      );

      const docSelection2 = DocumentSelection(
        base: DocumentPosition(
          nodeId: "Editor2_Header",
          nodePosition: TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: "Editor2_Para",
          nodePosition: TextNodePosition(offset: 5),
        ),
      );
      final composer2 = MutableDocumentComposer(
        initialSelection: docSelection2,
      );

      await tester.pumpWidget(_SwitchEditorsDemo(
        composer1: composer1,
        composer2: composer2,
      ));

      // Switch to the second editor.
      await tester.tap(find.byKey(const ValueKey("Editor2")));
      await tester.pump();

      // Ensure that the original selection is maintained for the second editor.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        docSelection2,
      );

      await tester.tap(find.byKey(const ValueKey("Editor1")));
      await tester.pump();

      // Ensure that the original selection is maintained for the first editor.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        docSelection1,
      );
    });

    testWidgetsOnDesktop("the user can select content after switching to a different editor", (tester) async {
      await tester.pumpWidget(const _SwitchEditorsDemo());

      // Switch to the second editor.
      await tester.tap(find.byKey(const ValueKey("Editor2")));
      await tester.pump();

      final document = SuperEditorInspector.findDocument()!;
      final header = document.getNodeById("Editor2_Header") as ParagraphNode;
      final paragraph = document.getNodeById("Editor2_Para") as ParagraphNode;

      // Change the selection on the second editor.
      await tester.dragSelectDocumentFromPositionByOffset(
        from: DocumentPosition(
          nodeId: header.id,
          nodePosition: header.beginningPosition,
        ),
        delta: const Offset(0, 400),
      );

      // Ensure that the selection was changed.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        DocumentSelection(
          base: DocumentPosition(
            nodeId: header.id,
            nodePosition: header.beginningPosition,
          ),
          extent: DocumentPosition(
            nodeId: paragraph.id,
            nodePosition: paragraph.endPosition,
          ),
        ),
      );
    });

    testWidgetsOnDesktop("the user can edit content after switching to a different editor", (tester) async {
      await tester.pumpWidget(
        _SwitchEditorsDemo(
          composer2: MutableDocumentComposer(
            initialSelection: const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "Editor2_Header",
                nodePosition: TextNodePosition(offset: "Document #2".length),
              ),
            ),
          ),
        ),
      );

      // Enable the SuperEditor.
      await tester.placeCaretInParagraph("Editor1_Header", 0);

      // Switch to the second editor.
      await tester.tap(find.byKey(const ValueKey("Editor2")));
      await tester.pump();

      await tester.pressBackspace();

      // Ensure that the text was edited upon pressing backspace.
      expect(
        SuperEditorInspector.findTextInComponent("Editor2_Header").toPlainText(),
        "Document #",
      );

      await tester.typeImeText("Edit");

      // Ensure that the text was inserted into the paragraph.
      expect(
        SuperEditorInspector.findTextInComponent("Editor2_Header").toPlainText(),
        "Document #Edit",
      );
    });
  });
}

Widget _buildSuperEditor(
  WidgetTester tester,
  String inputRole, {
  Key? key,
}) {
  return tester //
      .createDocument()
      .withSingleParagraph()
      .withKey(key)
      .withInputRole(inputRole)
      // Testing concurrent selections across multiple editors requires
      // that each editor leave their selection alone when losing focus
      // or closing the IME.
      .withSelectionPolicies(
        const SuperEditorSelectionPolicies(
          clearSelectionWhenEditorLosesFocus: false,
          clearSelectionWhenImeConnectionCloses: false,
        ),
      )
      .build()
      .widget;
}

/// Pumps a widget tree containing two editors side by side.
Future<void> _buildTextScaleScaffold(
  WidgetTester tester, {
  required Widget editor1,
  required Widget editor2,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            Expanded(
              child: editor1,
            ),
            Expanded(
              child: editor2,
            ),
          ],
        ),
      ),
    ),
  );
}

/// Demo of an [SuperEditor] widget where the [Editor] changes.
///
/// This demo ensures that [SuperEditor] state resets where appropriate
/// when its content is replaced.
class _SwitchEditorsDemo extends StatefulWidget {
  const _SwitchEditorsDemo({
    Key? key,
    this.composer1,
    this.composer2,
  }) : super(key: key);

  final MutableDocumentComposer? composer1;
  final MutableDocumentComposer? composer2;

  @override
  State<_SwitchEditorsDemo> createState() => _SwitchEditorsDemoState();
}

class _SwitchEditorsDemoState extends State<_SwitchEditorsDemo> {
  late MutableDocument _doc1;
  late MutableDocumentComposer _composer1;
  late Editor _docEditor1;

  late MutableDocument _doc2;
  late MutableDocumentComposer _composer2;
  late Editor _docEditor2;

  late Editor _activeDocumentEditor;

  @override
  void initState() {
    super.initState();
    _doc1 = _createDocument1();
    _composer1 = widget.composer1 ?? MutableDocumentComposer();
    _docEditor1 = createDefaultDocumentEditor(document: _doc1, composer: _composer1);

    _doc2 = _createDocument2();
    _composer2 = widget.composer2 ?? MutableDocumentComposer();
    _docEditor2 = createDefaultDocumentEditor(document: _doc2, composer: _composer2);

    _activeDocumentEditor = _docEditor1;
  }

  @override
  void dispose() {
    _docEditor1.dispose();
    _docEditor2.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            _buildDocSelector(),
            Expanded(
              child: SuperEditor(
                // Note: We give this `SuperEditor` the "global" input role because even though
                //       we're switching its backing `Editor`, we aren't switching between visibly
                //       different `SuperEditor`s.
                editor: _activeDocumentEditor,
                stylesheet: defaultStylesheet.copyWith(
                  documentPadding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          key: const ValueKey("Editor1"),
          onPressed: () {
            setState(() {
              _activeDocumentEditor = _docEditor1;
            });
          },
          child: const Text('Document 1'),
        ),
        const SizedBox(width: 24),
        TextButton(
          key: const ValueKey("Editor2"),
          onPressed: () {
            setState(() {
              _activeDocumentEditor = _docEditor2;
            });
          },
          child: const Text('Document 2'),
        ),
      ],
    );
  }
}

MutableDocument _createDocument1() {
  return MutableDocument(
    nodes: [
      ParagraphNode(
        id: "Editor1_Header",
        text: AttributedText('Document #1'),
        metadata: {
          'blockType': header1Attribution,
        },
      ),
      ParagraphNode(
        id: "Editor1_Para",
        text: AttributedText(
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus sed sagittis urna. Aenean mattis ante justo, quis sollicitudin metus interdum id. Aenean ornare urna ac enim consequat mollis. In aliquet convallis efficitur. Phasellus convallis purus in fringilla scelerisque. Ut ac orci a turpis egestas lobortis. Morbi aliquam dapibus sem, vitae sodales arcu ultrices eu. Duis vulputate mauris quam, eleifend pulvinar quam blandit eget.',
        ),
      ),
    ],
  );
}

MutableDocument _createDocument2() {
  return MutableDocument(
    nodes: [
      ParagraphNode(
        id: "Editor2_Header",
        text: AttributedText('Document #2'),
        metadata: {
          'blockType': header1Attribution,
        },
      ),
      ParagraphNode(
        id: "Editor2_Para",
        text: AttributedText(
          'Cras vitae sodales nisi. Vivamus dignissim vel purus vel aliquet. Sed viverra diam vel nisi rhoncus pharetra. Donec gravida ut ligula euismod pharetra. Etiam sed urna scelerisque, efficitur mauris vel, semper arcu. Nullam sed vehicula sapien. Donec id tellus volutpat, eleifend nulla eget, rutrum mauris.',
        ),
      ),
    ],
  );
}
