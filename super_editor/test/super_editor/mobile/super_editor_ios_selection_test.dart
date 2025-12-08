import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/selection_handles.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../../test_tools.dart';

void main() {
  group("SuperEditor mobile selection >", () {
    group("iOS >", () {
      group("on tap >", () {
        testWidgetsOnIos("when beyond first character > places caret at end of word", (tester) async {
          // Note: We pump the following text.
          // "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod...",
          await _pumpAppWithLongText(tester);

          // Tap near the end of a word "consectet|ur".
          await tester.tapInParagraph("1", 37);
          await tester.pumpAndSettle();

          // Ensure that the caret is at the end of the world "consectetur|".
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 39),
              ),
            ),
          );

          // Tap near the middle of a word "adipi|scing".
          await tester.tapInParagraph("1", 45);
          await tester.pumpAndSettle();

          // Ensure that the caret is at the end of the world "adipiscing|".
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 50),
              ),
            ),
          );

          // Tap near the beginning of a word "co|nsectetur".
          await tester.tapInParagraph("1", 30);
          await tester.pumpAndSettle();

          // Ensure that the caret is at the end of the word "consectetur|".
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 39),
              ),
            ),
          );
        });

        testWidgetsOnIos("when near first character > places caret at start of word", (tester) async {
          // Note: We pump the following text.
          // "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod...",
          await _pumpAppWithLongText(tester);

          // Tap just before first character of word " |consectetur".
          await tester.tapInParagraph("1", 28);
          await tester.pumpAndSettle();

          // Ensure that the caret is at the start of the world "|consectetur".
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 28),
              ),
            ),
          );

          // Tap just after the start of the word " a|dipiscing".
          await tester.tapInParagraph("1", 41);
          await tester.pumpAndSettle();

          // Ensure that the caret is at the start of the word " |adipiscing".
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 40),
              ),
            ),
          );
        });
      });

      group("long press >", () {
        testWidgetsOnIos("selects word under finger", (tester) async {
          await _pumpAppWithLongText(tester);

          // Ensure that no overlay controls are visible.
          _expectNoControlsAreVisible();

          // Long press on the middle of "conse|ctetur".
          await tester.longPressInParagraph("1", 33);
          await tester.pumpAndSettle();

          // Ensure the word was selected.
          expect(SuperEditorInspector.findDocumentSelection(), isNotNull);
          expect(SuperEditorInspector.findDocumentSelection(), _wordConsecteturSelection);

          // Ensure the drag handles and toolbar are visible, but the magnifier isn't.
          _expectHandlesAndToolbar();
        });

        testWidgetsOnIos("does nothing with hack global property", (tester) async {
          disableLongPressSelectionForSuperlist = true;
          addTearDown(() => disableLongPressSelectionForSuperlist = false);

          await _pumpAppWithLongText(tester);

          // Long press down on the middle of "conse|ctetur".
          final gesture = await tester.longPressDownInParagraph("1", 33);
          await tester.pump();

          // Ensure that there's no selection.
          expect(SuperEditorInspector.findDocumentSelection(), isNull);

          // Release the long-press.
          await gesture.up();
          await tester.pump();

          // Ensure that only the caret was placed, rather than an expanded selection due
          // to a long press.
          expect(SuperEditorInspector.findDocumentSelection()!.isCollapsed, isTrue);
        });

        testWidgetsOnIos("over handle does nothing", (tester) async {
          await _pumpAppWithLongText(tester);

          // Long press on the middle of "do|lor".
          await tester.longPressInParagraph("1", 14);
          await tester.pumpAndSettle();

          // Ensure the word was selected.
          expect(SuperEditorInspector.findDocumentSelection(), isNotNull);
          expect(SuperEditorInspector.findDocumentSelection(), _wordDolorSelection);

          // Long-press near the upstream handle, but just before the selected word.
          await tester.longPressInParagraph("1", 11);
          await tester.pumpAndSettle();

          // Ensure that the selection didn't change.
          expect(SuperEditorInspector.findDocumentSelection(), _wordDolorSelection);

          // Long-press near the downstream handle, but just after the selected word.
          await tester.longPressInParagraph("1", 18);
          await tester.pumpAndSettle();

          // Ensure that the selection didn't change.
          expect(SuperEditorInspector.findDocumentSelection(), _wordDolorSelection);
        });

        testWidgetsOnIos("selects by word when dragging upstream and then back downstream", (tester) async {
          await _pumpAppWithLongText(tester);

          // Long press on the middle of "do|lor".
          final gesture = await tester.longPressDownInParagraph("1", 14);
          await tester.pumpAndSettle();

          // Ensure the word was selected.
          expect(SuperEditorInspector.findDocumentSelection(), _wordDolorSelection);

          // Ensure the drag handles and magnifier are visible, but the toolbar isn't.
          _expectHandlesAndMagnifier();

          // Drag upstream to the end of the previous word.
          // "Lorem ipsu|m dolor sit amet"
          //            ^ position 10
          //
          // We do this with manual distances because the attempt to look up character
          // offsets was producing unpredictable results.
          const dragIncrementCount = 10;
          const upstreamDragDistance = -130 / dragIncrementCount;
          for (int i = 0; i < dragIncrementCount; i += 1) {
            await gesture.moveBy(const Offset(upstreamDragDistance, 0));
            await tester.pump();
          }

          // Ensure the original word and upstream word are both selected.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection(
              base: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 6),
              ),
              extent: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 17),
              ),
            ),
          );

          // Drag back towards the original long-press offset.
          //
          // We do this with manual distances because the attempt to look up character
          // offsets was producing unpredictable results.
          const downstreamDragDistance = 80 / dragIncrementCount;
          for (int i = 0; i < dragIncrementCount; i += 1) {
            await gesture.moveBy(const Offset(downstreamDragDistance, 0));
            await tester.pump();
          }

          // Ensure that only the original word is selected.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection(
              base: DocumentPosition(
                nodeId: "1",
                // Note: when we move the selection back the other way, the word calculation
                // decided to include the leading space, which is why we pass a different
                // selection here.
                nodePosition: TextNodePosition(offset: 11),
              ),
              extent: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 17),
              ),
            ),
          );

          // Release the gesture so the test system doesn't complain.
          await gesture.up();
        });

        testWidgetsOnIos("selects by word when dragging downstream and then back upstream", (tester) async {
          await _pumpAppWithLongText(tester);

          // Long press on the middle of "do|lor".
          final gesture = await tester.longPressDownInParagraph("1", 14);
          await tester.pumpAndSettle();

          // Ensure the word was selected.
          expect(SuperEditorInspector.findDocumentSelection(), _wordDolorSelection);

          // Ensure the drag handles and magnifier are visible, but the toolbar isn't.
          _expectHandlesAndMagnifier();

          // Drag downstream to the beginning of the next word.
          // "Lorem ipsum dolor s|it amet"
          //                     ^ position 19
          //
          // We do this with manual distances because the attempt to look up character
          // offsets was producing unpredictable results.
          const dragIncrementCount = 10;
          const downstreamDragDistance = 80 / dragIncrementCount;
          for (int i = 0; i < dragIncrementCount; i += 1) {
            await gesture.moveBy(const Offset(downstreamDragDistance, 0));
            await tester.pump();
          }

          // Ensure the original word and downstream word are both selected.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection(
              base: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 12),
              ),
              extent: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 21),
              ),
            ),
          );

          // Drag back towards the original long-press offset.
          //
          // We do this with manual distances because the attempt to look up character
          // offsets was producing unpredictable results.
          const upstreamDragDistance = -40 / dragIncrementCount;
          for (int i = 0; i < dragIncrementCount; i += 1) {
            await gesture.moveBy(const Offset(upstreamDragDistance, 0));
            await tester.pump();
          }

          // Ensure that only the original word is selected.
          expect(SuperEditorInspector.findDocumentSelection(), _wordDolorSelection);

          // Release the gesture so the test system doesn't complain.
          await gesture.up();
        });

        testWidgetsOnIos("selects an image and then by word when jumping down", (tester) async {
          await tester
              .createDocument()
              .withCustomContent(
                MutableDocument(
                  nodes: [
                    ImageNode(id: '1', imageUrl: ''),
                    ParagraphNode(
                      id: '2',
                      text: AttributedText('Lorem ipsum dolor'),
                    )
                  ],
                ),
              )
              .withAddedComponents(
            [
              const FakeImageComponentBuilder(
                size: Size(100, 100),
              ),
            ],
          ).pump();

          // Long press near the top of the image.
          final tapDownOffset = tester.getTopLeft(find.byType(ImageComponent)) + const Offset(0, 10);
          final gesture = await tester.startGesture(tapDownOffset);
          await tester.pump(kLongPressTimeout + kPressTimeout);

          // Ensure the image was selected.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection(
              base: DocumentPosition(nodeId: '1', nodePosition: UpstreamDownstreamNodePosition.upstream()),
              extent: DocumentPosition(nodeId: '1', nodePosition: UpstreamDownstreamNodePosition.downstream()),
            ),
          );

          // Drag down from the image to the begining of the paragraph.
          const dragIncrementCount = 10;
          final verticalDragDistance =
              Offset(0, (tester.getTopLeft(find.byType(TextComponent)).dy - tapDownOffset.dy) / dragIncrementCount);
          for (int i = 0; i < dragIncrementCount; i += 1) {
            await gesture.moveBy(verticalDragDistance);
            await tester.pump();
          }

          // Ensure the selection begins at the image and goes to the end of "Lorem".
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection(
              base: DocumentPosition(nodeId: '1', nodePosition: UpstreamDownstreamNodePosition.upstream()),
              extent: DocumentPosition(
                nodeId: "2",
                nodePosition: TextNodePosition(offset: 5),
              ),
            ),
          );

          // Release the gesture so the test system doesn't complain.
          await gesture.up();
          await tester.pump();
        });

        testWidgetsOnIos("selects an image and then by word when jumping up", (tester) async {
          await tester
              .createDocument()
              .withCustomContent(
                MutableDocument(
                  nodes: [
                    ParagraphNode(
                      id: '1',
                      text: AttributedText('Lorem ipsum dolor'),
                    ),
                    ImageNode(id: '2', imageUrl: ''),
                  ],
                ),
              )
              .withAddedComponents(
            [
              const FakeImageComponentBuilder(
                size: Size(100, 100),
              ),
            ],
          ).pump();

          // Long press near the top of the image.
          final tapDownOffset = tester.getTopLeft(find.byType(ImageComponent)) + const Offset(0, 10);
          final gesture = await tester.startGesture(tapDownOffset);
          await tester.pump(kLongPressTimeout + kPressTimeout);

          // Ensure the image was selected.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection(
              base: DocumentPosition(nodeId: '2', nodePosition: UpstreamDownstreamNodePosition.upstream()),
              extent: DocumentPosition(nodeId: '2', nodePosition: UpstreamDownstreamNodePosition.downstream()),
            ),
          );

          // Drag up from the image to the begining of the paragraph.
          const dragIncrementCount = 10;
          final verticalDragDistance =
              Offset(0, (tester.getTopLeft(find.byType(TextComponent)).dy - tapDownOffset.dy) / dragIncrementCount);
          for (int i = 0; i < dragIncrementCount; i += 1) {
            await gesture.moveBy(verticalDragDistance);
            await tester.pump();
          }

          // Ensure the selection starts at the beginning of the paragraph and goes to the end of the image.
          //
          // On iOS, the selection ends up normalized, where the position the appears first in the document
          // is considered to be the selection base. Therefore, even though we are dragging upstream,
          // the paragraph is the base of the selection.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection(
              base: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 0),
              ),
              extent: DocumentPosition(nodeId: '2', nodePosition: UpstreamDownstreamNodePosition.downstream()),
            ),
          );

          // Release the gesture so the test system doesn't complain.
          await gesture.up();
          await tester.pump();
        });
      });

      group("horizontal drag", () {
        testWidgetsOnIos("does not cause editor to scroll", (tester) async {
          final scrollController = ScrollController();

          await tester //
              .createDocument()
              .withLongDoc()
              .withScrollController(scrollController)
              .pump();

          // Start dragging horizontally.
          final gesture = await tester.startGesture(
            tester.getCenter(find.byType(SuperEditor)),
          );

          // Drag horizontally.
          for (int i = 1; i < 10; i += 1) {
            await gesture.moveBy(const Offset(20, 0));
            await tester.pump();
          }

          // Ensure that dragging doesn't cause the editor to scroll.
          expect(scrollController.offset, 0);

          // Release the gesture so the test system doesn't complain.
          await gesture.up();
          await tester.pumpAndSettle();
        });
      });

      group("vertical drag", () {
        testWidgetsOnIos("scrolls the editor after a horizontal drag", (tester) async {
          final scrollController = ScrollController();

          await tester //
              .createDocument()
              .withLongDoc()
              .withScrollController(scrollController)
              .pump();

          // Start dragging horizontally.
          final gesture = await tester.startGesture(
            tester.getCenter(find.byType(SuperEditor)),
          );

          // Drag horizontally.
          for (int i = 1; i < 10; i += 1) {
            await gesture.moveBy(const Offset(20, 0));
            await tester.pump();
          }

          // Ensure that dragging doesn't cause the editor to scroll.
          expect(scrollController.offset, 0);

          // Drag vertically.
          for (int i = 1; i < 10; i += 1) {
            await gesture.moveBy(const Offset(0, -10));
            await tester.pump();
          }

          // Ensure that the editor scrolled up.
          expect(scrollController.offset, greaterThan(0.0));

          // Release the gesture so the test system doesn't complain.
          await gesture.up();
          await tester.pumpAndSettle();
        });
      });

      testWidgetsOnIos("converts entire paragraph selection to entire document selection", (tester) async {
        // This test locks the behavior of a workaround for https://github.com/superlistapp/super_editor/issues/2579.
        //
        // When using the native text selection toolbar to select all text in a document, the IME sends a delta
        // that selects only the text of the currently selected nodes. This is because we only send the text of the
        // currently selected nodes to the IME. This test ensures that we select the entire document when we
        // receive a delta that selects an entire node.

        await tester //
            .createDocument()
            .withCustomContent(MutableDocument(
              nodes: [
                ParagraphNode(
                  id: '1',
                  text: AttributedText('First paragraph'),
                ),
                ParagraphNode(
                  id: '2',
                  text: AttributedText('Second paragraph'),
                ),
              ],
            ))
            .pump();

        // Place the caret at the beginning of the document.
        await tester.placeCaretInParagraph('1', 0);

        // Simulate the user pressing "Select all" on the native text selection toolbar.
        // Since we send only the text of the currently selected nodes to the IME, this results in a delta
        // that selects only the first paragraph.
        await tester.ime.sendDeltas(const [
          TextEditingDeltaNonTextUpdate(
            oldText: '. First paragraph',
            selection: TextSelection(baseOffset: 0, extentOffset: 17),
            composing: TextRange(start: -1, end: -1),
          ),
        ], getter: imeClientGetter);

        // Ensure that we selected the entire document.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection(
            base: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 0),
            ),
            extent: DocumentPosition(
              nodeId: '2',
              nodePosition: TextNodePosition(offset: 16),
            ),
          ),
        );
      });
    });

    group('within ancestor scrollable', () {
      testWidgetsOnIos("expands selection when dragging horizontally", (tester) async {
        final testContext = await tester
            .createDocument()
            .fromMarkdown(
              '''
SuperEditor containing a
paragraph that spans 
multiple lines.''',
            )
            .insideCustomScrollView()
            .pump();

        final paragraphNode = testContext.document.first as ParagraphNode;

        // Double tap to select "SuperEditor".
        await tester.doubleTapInParagraph(paragraphNode.id, 0);

        // Drag from "SuperEdito|r" a distance long enough to go through the entire first line.
        await tester.dragSelectDocumentFromPositionByOffset(
          from: DocumentPosition(
            nodeId: paragraphNode.id,
            nodePosition: const TextNodePosition(offset: 10),
          ),
          delta: const Offset(300, 0),
        );

        // Ensure the first line is selected.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          selectionEquivalentTo(
            DocumentSelection(
              base: DocumentPosition(
                nodeId: paragraphNode.id,
                nodePosition: const TextNodePosition(offset: 0),
              ),
              extent: DocumentPosition(
                nodeId: paragraphNode.id,
                nodePosition: const TextNodePosition(offset: 24),
              ),
            ),
          ),
        );
      });

      testWidgetsOnIos("expands selection when dragging vertically", (tester) async {
        final testContext = await tester
            .createDocument()
            .fromMarkdown(
              '''
SuperEditor containing a
paragraph that spans 
multiple lines.''',
            )
            .insideCustomScrollView()
            .pump();

        final paragraphNode = testContext.document.first as ParagraphNode;

        // Double tap to select "SuperEditor".
        await tester.doubleTapInParagraph(paragraphNode.id, 0);

        // Drag from "SuperEdito|r" a distance long enough to go to the last line.
        await tester.dragSelectDocumentFromPositionByOffset(
          from: DocumentPosition(
            nodeId: paragraphNode.id,
            nodePosition: const TextNodePosition(offset: 10),
          ),
          delta: const Offset(0, 40),
        );

        // Ensure the selection starts at the beginning and end at "multiple l|ines".
        expect(
          SuperEditorInspector.findDocumentSelection(),
          selectionEquivalentTo(
            DocumentSelection(
              base: DocumentPosition(
                nodeId: paragraphNode.id,
                nodePosition: const TextNodePosition(offset: 0),
              ),
              extent: DocumentPosition(
                nodeId: paragraphNode.id,
                nodePosition: const TextNodePosition(offset: 57),
              ),
            ),
          ),
        );
      });
    });
  });
}

// The test suite was originally laid out and calculated with:
//  - physical size: 2400x1800
//  - device pixel ratio: 3.0

Future<void> _pumpAppWithLongText(WidgetTester tester) async {
  await tester
      .createDocument()
      // "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod...",
      .withSingleParagraph()
      .useIosSelectionHeuristics(true)
      .withiOSToolbarBuilder((context, mobileToolbarKey, focalPoint) =>
          IOSTextEditingFloatingToolbar(key: mobileToolbarKey, focalPoint: focalPoint))
      .pump();
}

const _wordConsecteturSelection = DocumentSelection(
  base: DocumentPosition(
    nodeId: "1",
    nodePosition: TextNodePosition(offset: 28),
  ),
  extent: DocumentPosition(
    nodeId: "1",
    nodePosition: TextNodePosition(offset: 39),
  ),
);

const _wordDolorSelection = DocumentSelection(
  base: DocumentPosition(
    nodeId: "1",
    nodePosition: TextNodePosition(offset: 12),
  ),
  extent: DocumentPosition(
    nodeId: "1",
    nodePosition: TextNodePosition(offset: 17),
  ),
);

void _expectNoControlsAreVisible() {
  expect(find.byType(IOSSelectionHandle), findsNothing);
  expect(find.byType(IOSTextEditingFloatingToolbar), findsNothing);
  expect(find.byType(IOSRoundedRectangleMagnifyingGlass), findsNothing);
}

void _expectHandlesAndMagnifier() {
  expect(find.byType(IOSSelectionHandle), findsExactly(2));
  expect(find.byType(IOSRoundedRectangleMagnifyingGlass), findsOne);
  expect(find.byType(IOSTextEditingFloatingToolbar), findsNothing);
}

void _expectHandlesAndToolbar() {
  expect(find.byType(IOSSelectionHandle), findsExactly(2));
  expect(find.byType(IOSTextEditingFloatingToolbar), findsOne);
  expect(find.byType(IOSRoundedRectangleMagnifyingGlass), findsNothing);
}
