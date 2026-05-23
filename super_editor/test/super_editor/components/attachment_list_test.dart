import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

void main() {
  group("Super Editor > Components > attachment list >", () {
    group("caret and selection movement >", () {
      testWidgetsOnAllPlatforms("places caret on tap", (tester) async {
        await _pumpWithList(tester);

        await tester.placeCaretInComponent("2", const AttachmentListNodePosition(0, TextAffinity.upstream));
        expect(
          SuperEditorInspector.findDocumentSelection(),
          _caretAt("2", 0, TextAffinity.upstream),
        );

        await tester.placeCaretInComponent("2", const AttachmentListNodePosition(1, TextAffinity.upstream));
        expect(
          SuperEditorInspector.findDocumentSelection(),
          _caretAt("2", 1, TextAffinity.upstream),
        );

        await tester.placeCaretInComponent("2", const AttachmentListNodePosition(2, TextAffinity.upstream));
        expect(
          SuperEditorInspector.findDocumentSelection(),
          _caretAt("2", 2, TextAffinity.upstream),
        );

        await tester.placeCaretInComponent("2", const AttachmentListNodePosition(3, TextAffinity.upstream));
        expect(
          SuperEditorInspector.findDocumentSelection(),
          _caretAt("2", 3, TextAffinity.upstream),
        );

        await tester.placeCaretInComponent("2", const AttachmentListNodePosition(3, TextAffinity.downstream));
        expect(
          SuperEditorInspector.findDocumentSelection(),
          _caretAt("2", 3, TextAffinity.downstream),
        );
      });

      testWidgetsOnAllPlatforms("moves caret left/right with arrow keys", (tester) async {
        await _pumpWithList(tester);

        await tester.placeCaretInComponent("2", const AttachmentListNodePosition(0, TextAffinity.upstream));
        expect(
          SuperEditorInspector.findDocumentSelection(),
          _caretAt("2", 0, TextAffinity.upstream),
        );

        // Move caret, attachment by attachment, all the way to the right.
        for (int i = 1; i <= 4; i += 1) {
          await tester.pressRightArrow();

          expect(
            SuperEditorInspector.findDocumentSelection(),
            _caretAt("2", i, TextAffinity.upstream),
          );
        }

        // Move caret, attachment by attachment, all the way back to the left.
        for (int i = 3; i >= 0; i -= 1) {
          await tester.pressLeftArrow();

          expect(
            SuperEditorInspector.findDocumentSelection(),
            _caretAt("2", i, TextAffinity.upstream),
          );
        }
      });
    });

    group("editing >", () {
      testWidgetsOnAllPlatforms("can backspace to delete all attachments", (tester) async {
        await _pumpWithList(tester);

        await tester.placeCaretInComponent("2", const AttachmentListNodePosition(4, TextAffinity.downstream));
        expect(
          SuperEditorInspector.findDocumentSelection(),
          _caretAt("2", 4, TextAffinity.downstream),
        );

        // Delete each attachment with backspace.
        await tester.pressBackspace();
        expect(_findAttachments(), const [
          _FakeAttachment("1.png"),
          _FakeAttachment("2.png"),
          _FakeAttachment("3.png"),
          _FakeAttachment("4.png"),
        ]);
        expect(
          SuperEditorInspector.findDocumentSelection(),
          _caretAt("2", 3, TextAffinity.downstream),
        );

        await tester.pressBackspace();
        expect(_findAttachments(), const [
          _FakeAttachment("1.png"),
          _FakeAttachment("2.png"),
          _FakeAttachment("3.png"),
        ]);
        expect(
          SuperEditorInspector.findDocumentSelection(),
          _caretAt("2", 2, TextAffinity.downstream),
        );

        await tester.pressBackspace();
        expect(_findAttachments(), const [
          _FakeAttachment("1.png"),
          _FakeAttachment("2.png"),
        ]);
        expect(
          SuperEditorInspector.findDocumentSelection(),
          _caretAt("2", 1, TextAffinity.downstream),
        );

        await tester.pressBackspace();
        expect(_findAttachments(), const [
          _FakeAttachment("1.png"),
        ]);
        expect(
          SuperEditorInspector.findDocumentSelection(),
          _caretAt("2", 0, TextAffinity.downstream),
        );

        // Backspace to delete final attachment, which should convert
        // node into a paragraph.
        await tester.pressBackspace();
        expect(SuperEditorInspector.findDocument()!.getNodeById("2"), isA<ParagraphNode>());
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(nodeId: "2", nodePosition: TextNodePosition(offset: 0)),
          ),
        );
      });
    });
  });
}

List<Object> _findAttachments() {
  final node =
      SuperEditorInspector.findDocument()!.firstWhere((node) => node is AttachmentListNode) as AttachmentListNode;
  return List.from(node.attachments);
}

DocumentSelection _caretAt(String nodeId, int offset, TextAffinity affinity) {
  return DocumentSelection.collapsed(
    position: DocumentPosition(
      nodeId: nodeId,
      nodePosition: AttachmentListNodePosition(offset, affinity),
    ),
  );
}

Future<void> _pumpWithList(WidgetTester tester) async {
  await tester
      .createDocument() //
      .withCustomContent(_mediumList)
      .withAddedComponents(
    [
      const AttachmentListComponentBuilder(_buildFakeAttachmentThumbnail),
    ],
  ).pump();
}

Widget _buildFakeAttachmentThumbnail(BuildContext context, Object attachment) {
  return const SizedBox(
    width: 50,
    height: 50,
    child: Placeholder(),
  );
}

MutableDocument get _mediumList => MutableDocument(
      nodes: [
        ParagraphNode(id: "1", text: AttributedText()),
        AttachmentListNode(
          id: "2",
          attachments: const [
            _FakeAttachment("1.png"),
            _FakeAttachment("2.png"),
            _FakeAttachment("3.png"),
            _FakeAttachment("4.png"),
            _FakeAttachment("5.png"),
          ],
        ),
        ParagraphNode(id: "3", text: AttributedText()),
      ],
    );

class _FakeAttachment {
  const _FakeAttachment(this.id);

  final String id;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is _FakeAttachment && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
