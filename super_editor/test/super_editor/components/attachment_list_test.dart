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

        await tester.placeCaretInComponent("2", const AttachmentListNodePosition(0));
        expect(
          SuperEditorInspector.findDocumentSelection(),
          _caretAt("2", 0),
        );

        await tester.placeCaretInComponent("2", const AttachmentListNodePosition(1));
        expect(
          SuperEditorInspector.findDocumentSelection(),
          _caretAt("2", 1),
        );

        await tester.placeCaretInComponent("2", const AttachmentListNodePosition(2));
        expect(
          SuperEditorInspector.findDocumentSelection(),
          _caretAt("2", 2),
        );

        await tester.placeCaretInComponent("2", const AttachmentListNodePosition(3));
        expect(
          SuperEditorInspector.findDocumentSelection(),
          _caretAt("2", 3),
        );

        await tester.placeCaretInComponent("2", const AttachmentListNodePosition(4));
        expect(
          SuperEditorInspector.findDocumentSelection(),
          _caretAt("2", 4),
        );
      });

      testWidgetsOnAllPlatforms("moves caret left/right with arrow keys", (tester) async {
        await _pumpWithList(tester);

        await tester.placeCaretInComponent("2", const AttachmentListNodePosition(0));
        expect(
          SuperEditorInspector.findDocumentSelection(),
          _caretAt("2", 0),
        );

        // Move caret, attachment by attachment, all the way to the right.
        for (int i = 1; i <= 4; i += 1) {
          await tester.pressRightArrow();

          expect(
            SuperEditorInspector.findDocumentSelection(),
            _caretAt("2", i),
          );
        }

        // Move caret, attachment by attachment, all the way back to the left.
        for (int i = 3; i >= 0; i -= 1) {
          await tester.pressLeftArrow();

          expect(
            SuperEditorInspector.findDocumentSelection(),
            _caretAt("2", i),
          );
        }
      });
    });

    group("editing >", () {
      testWidgetsOnAllPlatforms("can backspace to delete all attachments", (tester) async {
        await _pumpWithList(tester);

        await tester.placeCaretInComponent("2", const AttachmentListNodePosition(5));
        expect(
          SuperEditorInspector.findDocumentSelection(),
          _caretAt("2", 5),
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
          _caretAt("2", 4),
        );

        await tester.pressBackspace();
        expect(_findAttachments(), const [
          _FakeAttachment("1.png"),
          _FakeAttachment("2.png"),
          _FakeAttachment("3.png"),
        ]);
        expect(
          SuperEditorInspector.findDocumentSelection(),
          _caretAt("2", 3),
        );

        await tester.pressBackspace();
        expect(_findAttachments(), const [
          _FakeAttachment("1.png"),
          _FakeAttachment("2.png"),
        ]);
        expect(
          SuperEditorInspector.findDocumentSelection(),
          _caretAt("2", 2),
        );

        await tester.pressBackspace();
        expect(_findAttachments(), const [
          _FakeAttachment("1.png"),
        ]);
        expect(
          SuperEditorInspector.findDocumentSelection(),
          _caretAt("2", 1),
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

      testWidgetsOnAllPlatforms("inserts paragraph when pressing ENTER at beginning", (tester) async {
        await _pumpWithList(tester);

        // Place caret at start of list.
        await tester.placeCaretInComponent("2", const AttachmentListNodePosition(0));

        // Press enter to insert paragraph before list.
        await tester.pressEnter();

        // Ensure a paragraph was inserted before the list.
        final document = SuperEditorInspector.findDocument()!;
        final paragraph = document.getNodeAt(1)!;

        expect(document.length, 4);
        expect(paragraph, isA<ParagraphNode>());
        expect(document.getNodeAt(2), isA<AttachmentListNode>());
        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: paragraph.id,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
        );
      });

      testWidgetsOnAllPlatforms("inserts paragraph when pressing ENTER at end", (tester) async {
        await _pumpWithList(tester);

        // Place caret at end of list.
        await tester.placeCaretInComponent("2", const AttachmentListNodePosition(5));

        // Press enter to insert paragraph after list.
        await tester.pressEnter();

        // Ensure a paragraph was inserted after the list.
        final document = SuperEditorInspector.findDocument()!;
        final paragraph = document.getNodeAt(2)!;

        expect(document.length, 4);
        expect(paragraph, isA<ParagraphNode>());
        expect(document.getNodeAt(1), isA<AttachmentListNode>());
        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: paragraph.id,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
        );
      });

      testWidgetsOnAllPlatforms("splits attachments into two when pressing ENTER in the middle", (tester) async {
        await _pumpWithList(tester);

        // Place caret in middle of list.
        await tester.placeCaretInComponent("2", const AttachmentListNodePosition(2));

        // Press enter to split the node into two attachment list nodes.
        await tester.pressEnter();

        // Ensure we split the list into two.
        final document = SuperEditorInspector.findDocument()!;
        final firstList = document.getNodeAt(1)!;
        final secondList = document.getNodeAt(2)!;

        expect(document.length, 4);

        expect(firstList, isA<AttachmentListNode>());
        expect((firstList as AttachmentListNode).attachments.length, 2);

        expect(secondList, isA<AttachmentListNode>());
        expect((secondList as AttachmentListNode).attachments.length, 3);

        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: secondList.id,
              nodePosition: const AttachmentListNodePosition(0),
            ),
          ),
        );
      });

      testWidgetsOnAllPlatforms("combines lists together when pressing BACKSPACE at start of second list",
          (tester) async {
        await _pumpWithList(tester, document: _twoLists);

        // Place caret at beginning of second list.
        await tester.placeCaretInComponent("3", const AttachmentListNodePosition(0));

        // Press backspace to merge the two lists into one.
        await tester.pressBackspace();

        // Ensure the nodes were combined.
        final document = SuperEditorInspector.findDocument()!;
        expect(document.length, 3);

        final combinedList = document.getNodeById("2")!;
        expect(combinedList, isA<AttachmentListNode>());
        expect((combinedList as AttachmentListNode).attachments.length, 5);
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "2",
              nodePosition: AttachmentListNodePosition(2),
            ),
          ),
        );
      });

      testWidgetsOnAllPlatforms("combines lists together when pressing DELETE at end of first list", (tester) async {
        await _pumpWithList(tester, document: _twoLists);

        // Place caret at end of first list.
        await tester.placeCaretInComponent("2", const AttachmentListNodePosition(2));

        // Press delete to merge the two lists into one.
        await tester.pressDelete();

        // Ensure the nodes were combined.
        final document = SuperEditorInspector.findDocument()!;
        expect(document.length, 3);

        final combinedList = document.getNodeById("2")!;
        expect(combinedList, isA<AttachmentListNode>());
        expect((combinedList as AttachmentListNode).attachments.length, 5);
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "2",
              nodePosition: AttachmentListNodePosition(2, TextAffinity.upstream),
            ),
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

DocumentSelection _caretAt(String nodeId, int gapIndex) {
  return DocumentSelection.collapsed(
    position: DocumentPosition(
      nodeId: nodeId,
      nodePosition: AttachmentListNodePosition(gapIndex),
    ),
  );
}

Future<void> _pumpWithList(
  WidgetTester tester, {
  MutableDocument? document,
}) async {
  document ??= _mediumList;

  await tester
      .createDocument() //
      .withCustomContent(document)
      .withAddedComponents(
    [
      const AttachmentListComponentBuilder(_buildFakeAttachmentThumbnail),
    ],
  ).pump();
}

Widget _buildFakeAttachmentThumbnail(BuildContext context, int index, Object attachment) {
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

MutableDocument get _twoLists => MutableDocument(
      nodes: [
        ParagraphNode(id: "1", text: AttributedText()),
        AttachmentListNode(
          id: "2",
          attachments: const [
            _FakeAttachment("1.png"),
            _FakeAttachment("2.png"),
          ],
        ),
        AttachmentListNode(
          id: "3",
          attachments: const [
            _FakeAttachment("3.png"),
            _FakeAttachment("4.png"),
            _FakeAttachment("5.png"),
          ],
        ),
        ParagraphNode(id: "4", text: AttributedText()),
      ],
    );

class _FakeAttachment {
  const _FakeAttachment(this.id);

  final String id;

  @override
  String toString() => "_FakeAttachment: $id";

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is _FakeAttachment && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
