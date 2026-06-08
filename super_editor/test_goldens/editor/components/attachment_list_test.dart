import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_goldens/flutter_test_goldens.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:super_editor/super_test.dart';

void main() {
  group('Super Editor > Components > Attachment List >', () {
    testGoldenSceneOnMac('layout', (tester) async {
      tester.view.physicalSize = const Size(350, 300);

      await Gallery(
        'attachment-list_layout',
        fileName: 'attachment-list_layout',
        layout: const RowSceneLayout(),
      )
          .itemFromPumper(
            description: 'Partial Row',
            pumper: (tester, scaffold, description) => _pumpWithList(tester, document: _documentWithPartialLineList),
          )
          .itemFromPumper(
            description: 'Full Row',
            pumper: (tester, scaffold, description) => _pumpWithList(tester, document: _documentWithOneLineList),
          )
          .itemFromPumper(
            description: 'Two and a Half Rows',
            pumper: (tester, scaffold, description) =>
                _pumpWithList(tester, document: _documentWithTwoAndAHalfLineList),
          )
          .itemFromPumper(
            description: 'Three Rows',
            pumper: (tester, scaffold, description) => _pumpWithList(tester, document: _documentWithThreeLineList),
          )
          .run(tester);
    });

    testGoldenSceneOnMac('left/right caret pushing', (tester) async {
      tester.view.physicalSize = const Size(350, 300);

      final timeline = Timeline(
        'attachment-list_caret-push_left-right',
        fileName: 'attachment-list_caret-push_left-right',
        layout: const RowSceneLayout(),
      ) //
          .setup((tester) async => await _pumpWithList(tester, document: _documentWithThreeLineList))
          .takePhoto('No caret')
          .modifyScene(
        (tester, context) async {
          // Place caret at end of first paragraph, so we can test movement into attachment list.
          await tester.placeCaretInComponent("1", SuperEditorInspector.findDocument()!.getNodeById("1")!.endPosition);
        },
      ).takePhoto('Place caret');

      // Push the caret downstream until the end of the list.
      //
      // Note: +2 on the number of pushes because row split gaps place the
      // caret at the upstream side and then the downstream side.
      for (int i = 0; i <= 15 + 2; i += 1) {
        timeline.modifyScene(
          (tester, context) async {
            await tester.pressRightArrow();
          },
        ).takePhoto('Push $i');
      }

      // Push the caret into start of paragraph after the list.
      timeline.modifyScene(
        (tester, context) async {
          await tester.pressRightArrow();
        },
      ).takePhoto('Beyond list');

      // Push the caret upstream until the beginning of the list.
      //
      // Note: +2 on the number of pushes because row split gaps place the
      // caret at the upstream side and then the downstream side.
      for (int i = 15 + 2; i >= 0; i -= 1) {
        timeline.modifyScene(
          (tester, context) async {
            await tester.pressLeftArrow();
          },
        ).takePhoto('Push $i');
      }

      // Push the caret into end of paragraph before the list.
      timeline.modifyScene(
        (tester, context) async {
          await tester.pressLeftArrow();
        },
      ).takePhoto('Before list');

      await timeline.run(tester);
    });

    testGoldenSceneOnMac('up/down caret pushing', (tester) async {
      tester.view.physicalSize = const Size(350, 300);

      final timeline = Timeline(
        'attachment-list_caret-push_up-down',
        fileName: 'attachment-list_caret-push_up-down',
        layout: const RowSceneLayout(),
      ) //
          .setup((tester) async => await _pumpWithList(tester, document: _documentWithThreeLineList))
          .takePhoto('No caret')
          .modifyScene(
        (tester, context) async {
          // Place caret at beginning of first paragraph, so we can test movement into attachment list.
          await tester.placeCaretInParagraph("1", 0);
        },
      ).takePhoto('Place caret');

      // Push the caret down each row on the left side.
      for (int i = 0; i <= 2; i += 1) {
        timeline.modifyScene(
          (tester, context) async {
            await tester.pressDownArrow();
          },
        ).takePhoto('Row $i');
      }

      // Push the caret into start of paragraph after the list.
      timeline.modifyScene(
        (tester, context) async {
          await tester.pressDownArrow();
        },
      ).takePhoto('Beyond list');

      // Push the caret up each row on the left side.
      for (int i = 3; i >= 1; i -= 1) {
        timeline.modifyScene(
          (tester, context) async {
            await tester.pressUpArrow();
          },
        ).takePhoto('Row $i');
      }

      // Push the caret into beginning of paragraph before the list.
      timeline.modifyScene(
        (tester, context) async {
          await tester.pressUpArrow();
        },
      ).takePhoto('Before list');

      // Place caret at end of first paragraph.
      timeline.modifyScene(
        (tester, context) async {
          // Place caret at end of first paragraph.
          await tester.placeCaretInParagraph(
            "1",
            (SuperEditorInspector.findDocument()!.getNodeById("1")!.endPosition as TextNodePosition).offset,
          );
        },
      ).takePhoto('Place caret at end');

      // Push the caret down each row on the right side.
      for (int i = 0; i <= 2; i += 1) {
        timeline.modifyScene(
          (tester, context) async {
            await tester.pressDownArrow();
          },
        ).takePhoto('Row $i');
      }

      // Push the caret into end of paragraph after the list.
      timeline.modifyScene(
        (tester, context) async {
          await tester.pressDownArrow();
        },
      ).takePhoto('Beyond list');

      // Push the caret up each row on the right side.
      for (int i = 3; i >= 1; i -= 1) {
        timeline.modifyScene(
          (tester, context) async {
            await tester.pressUpArrow();
          },
        ).takePhoto('Row $i');
      }

      await timeline.run(tester);
    });

    testGoldenSceneOnMac('expanded selection', (tester) async {
      tester.view.physicalSize = const Size(350, 300);

      final timeline = Timeline(
        'attachment-list_expanded-selection',
        fileName: 'attachment-list_expanded-selection',
        layout: const RowSceneLayout(),
      ) //
          .setup((tester) async => await _pumpWithList(tester, document: _documentWithThreeLineList))
          .modifyScene(
            (tester, context) async {
              // Select a single attachment with double click.
              await tester.doubleTapAtDocumentPosition(
                const DocumentPosition(nodeId: "2", nodePosition: AttachmentListNodePosition(7)),
              );

              // Extra pump to update selection painting.
              await tester.pump();
            },
          )
          .takePhoto('Double Click Selection')
          .modifyScene(
            (tester, context) async {
              // Select all attachments with triple click.
              await tester.tripleTapAtDocumentPosition(
                const DocumentPosition(nodeId: "2", nodePosition: AttachmentListNodePosition(1)),
              );

              // Extra pump to update selection painting.
              await tester.pump();
            },
          )
          .takePhoto('Triple Click Selection')
          .modifyScene(
            (tester, context) async {
              // Drag to select some attachments.
              await tester.dragSelectDocumentFromPositionByOffset(
                from: const DocumentPosition(nodeId: "2", nodePosition: AttachmentListNodePosition(1)),
                delta: const Offset(75, 75),
              );

              // Extra pump to update selection painting.
              await tester.pump();
            },
          )
          .takePhoto('Drag Selection');

      await timeline.run(tester);
    });
  });
}

Future<void> _pumpWithList(
  WidgetTester tester, {
  MutableDocument? document,
}) async {
  document ??= _documentWithOneLineList;

  await tester
      .createDocument() //
      .withCustomContent(document)
      .withAddedComponents(
    [
      const AttachmentListComponentBuilder(_buildFakeAttachmentThumbnail),
    ],
  ).withCustomWidgetTreeBuilder((Widget superEditor) {
    return GoldenImageBounds(
      child: MaterialApp(
        // By default, Flutter chooses the shortcuts based on the platform. For "native" platforms,
        // the defaults already work correctly, because we set `debugDefaultTargetPlatformOverride` to force
        // the desired platform. However, for web Flutter checks for `kIsWeb`, which we can't control.
        //
        // Use our own version of the shortcuts, so we can set `debugIsWebOverride` to `true` to force
        // Flutter to pick the web shortcuts.
        shortcuts: defaultFlutterShortcuts,
        home: Scaffold(
          body: superEditor,
          resizeToAvoidBottomInset: false,
          // ^ Don't automatically resize content to avoid keyboard. We want to be
          //   able to test our keyboard scaffold, which needs full screen height.
          //   If a test ever needs this to be `true` then we should make this configurable.
        ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }).pump();
}

Widget _buildFakeAttachmentThumbnail(BuildContext context, int index, Object attachment) {
  return const SizedBox(
    width: 50,
    height: 50,
    child: Placeholder(),
  );
}

MutableDocument get _documentWithPartialLineList => MutableDocument(
      nodes: [
        ParagraphNode(id: "1", text: AttributedText("Paragraph before")),
        AttachmentListNode(
          id: "2",
          attachments: const [
            _FakeAttachment("1.png"),
            _FakeAttachment("2.png"),
            _FakeAttachment("3.png"),
          ],
        ),
        ParagraphNode(id: "3", text: AttributedText("Paragraph after")),
      ],
    );

MutableDocument get _documentWithOneLineList => MutableDocument(
      nodes: [
        ParagraphNode(id: "1", text: AttributedText("Paragraph before")),
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
        ParagraphNode(id: "3", text: AttributedText("Paragraph after")),
      ],
    );

MutableDocument get _documentWithTwoAndAHalfLineList => MutableDocument(
      nodes: [
        ParagraphNode(id: "1", text: AttributedText("Paragraph before")),
        AttachmentListNode(
          id: "2",
          attachments: [
            for (int i = 0; i < 13; i += 1) _FakeAttachment("$i"),
          ],
        ),
        ParagraphNode(id: "3", text: AttributedText("Paragraph after")),
      ],
    );

MutableDocument get _documentWithThreeLineList => MutableDocument(
      nodes: [
        ParagraphNode(id: "1", text: AttributedText("Paragraph before")),
        AttachmentListNode(
          id: "2",
          attachments: [
            for (int i = 0; i < 15; i += 1) _FakeAttachment("$i"),
          ],
        ),
        ParagraphNode(id: "3", text: AttributedText("Paragraph after")),
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
