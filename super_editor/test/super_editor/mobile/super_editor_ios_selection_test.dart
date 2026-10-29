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
        testWidgetsOnIos("places caret under finger and magnifies it", (tester) async {
          await _pumpAppWithLongText(tester);

          // Ensure that no overlay controls are visible.
          _expectNoControlsAreVisible();

          // Long press down on the middle of "conse|ctetur".
          final gesture = await tester.longPressDownInParagraph("1", 33);
          await tester.pump();

          // Ensure that the caret sits exactly where the user pressed, rather than
          // at a word boundary, and that the word wasn't selected.
          expect(SuperEditorInspector.findDocumentSelection(), _caretAt(33));

          // Ensure that the magnifier is visible, but the toolbar isn't.
          expect(SuperEditorInspector.isMobileMagnifierVisible(), isTrue);
          expect(SuperEditorInspector.isMobileToolbarVisible(), isFalse);

          // Release the long-press.
          await gesture.up();
          await tester.pumpAndSettle();

          // Ensure that the caret stayed put and the magnifier went away.
          expect(SuperEditorInspector.findDocumentSelection(), _caretAt(33));
          expect(SuperEditorInspector.isMobileMagnifierVisible(), isFalse);
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

        testWidgetsOnIos("moves an existing caret to the finger", (tester) async {
          await _pumpAppWithLongText(tester);

          // Place the caret at the start of the paragraph.
          await tester.placeCaretInParagraph("1", 0);
          expect(SuperEditorInspector.findDocumentSelection(), _caretAt(0));

          // Long press on the middle of "conse|ctetur".
          await tester.longPressInParagraph("1", 33);
          await tester.pumpAndSettle();

          // Ensure that the caret moved to where the user pressed.
          expect(SuperEditorInspector.findDocumentSelection(), _caretAt(33));
        });

        testWidgetsOnIos("moves the caret when pressing right beside it", (tester) async {
          await _pumpAppWithLongText(tester);

          // Place the caret at the end of "dolor|".
          await tester.placeCaretInParagraph("1", 17);
          expect(SuperEditorInspector.findDocumentSelection(), _caretAt(17));

          // Long press down a couple of characters upstream from the caret, in
          // "dol|or", which is close enough to the caret to also be a caret drag.
          final gesture = await tester.longPressDownInParagraph("1", 15);
          await tester.pump();

          // Ensure that the caret moved to the finger, and that the magnifier shows.
          expect(SuperEditorInspector.findDocumentSelection(), _caretAt(15));
          expect(SuperEditorInspector.isMobileMagnifierVisible(), isTrue);

          await gesture.up();
          await tester.pumpAndSettle();
        });

        testWidgetsOnIos("replaces an expanded selection with the caret", (tester) async {
          await _pumpAppWithLongText(tester);

          // Select the word "dolor".
          await tester.doubleTapInParagraph("1", 14);
          await tester.pumpAndSettle();
          expect(SuperEditorInspector.findDocumentSelection(), _wordDolorSelection);

          // Long press on the middle of "conse|ctetur", away from the selection.
          await tester.longPressInParagraph("1", 33);
          await tester.pumpAndSettle();

          // Ensure that the selection collapsed to a caret where the user pressed.
          expect(SuperEditorInspector.findDocumentSelection(), _caretAt(33));
        });

        testWidgetsOnIos("on an expanded selection's handle does nothing", (tester) async {
          await _pumpAppWithLongText(tester);

          // Select the word "dolor".
          await tester.doubleTapInParagraph("1", 14);
          await tester.pumpAndSettle();
          expect(SuperEditorInspector.findDocumentSelection(), _wordDolorSelection);

          // Long-press on the caret of the upstream handle, within the line.
          final upstreamHandle = tester.getRect(find.byKey(DocumentKeys.upstreamHandle));
          await _longPressAt(tester, Offset(upstreamHandle.center.dx, upstreamHandle.bottom - 8));

          // Ensure that the selection didn't change.
          expect(SuperEditorInspector.findDocumentSelection(), _wordDolorSelection);

          // Long-press on the caret of the downstream handle, within the line.
          final downstreamHandle = tester.getRect(find.byKey(DocumentKeys.downstreamHandle));
          await _longPressAt(tester, Offset(downstreamHandle.center.dx, downstreamHandle.top + 8));

          // Ensure that the selection didn't change.
          expect(SuperEditorInspector.findDocumentSelection(), _wordDolorSelection);
        });

        testWidgetsOnIos("beside an expanded selection's upstream handle places the caret", (tester) async {
          await _pumpAppWithLongText(tester);

          // Select the word "dolor".
          await tester.doubleTapInParagraph("1", 14);
          await tester.pumpAndSettle();
          expect(SuperEditorInspector.findDocumentSelection(), _wordDolorSelection);

          // Long-press on the text just upstream from the upstream handle, close
          // enough that a tap there would still grab the handle.
          final upstreamHandle = tester.getRect(find.byKey(DocumentKeys.upstreamHandle));
          await _longPressAt(tester, Offset(upstreamHandle.center.dx - 14, upstreamHandle.bottom - 8));

          // Ensure that the long-press placed the caret upstream from the word.
          final selection = SuperEditorInspector.findDocumentSelection()!;
          expect(selection.isCollapsed, isTrue);
          expect((selection.extent.nodePosition as TextNodePosition).offset, lessThan(12));
        });

        testWidgetsOnIos("beside an expanded selection's downstream handle places the caret", (tester) async {
          await _pumpAppWithLongText(tester);

          // Select the word "dolor".
          await tester.doubleTapInParagraph("1", 14);
          await tester.pumpAndSettle();
          expect(SuperEditorInspector.findDocumentSelection(), _wordDolorSelection);

          // Long-press on the text just downstream from the downstream handle, close
          // enough that a tap there would still grab the handle.
          final downstreamHandle = tester.getRect(find.byKey(DocumentKeys.downstreamHandle));
          await _longPressAt(tester, Offset(downstreamHandle.center.dx + 14, downstreamHandle.top + 8));

          // Ensure that the long-press placed the caret downstream from the word.
          final selection = SuperEditorInspector.findDocumentSelection()!;
          expect(selection.isCollapsed, isTrue);
          expect((selection.extent.nodePosition as TextNodePosition).offset, greaterThan(17));
        });

        testWidgetsOnIos("tap beside an expanded selection's handle keeps the selection", (tester) async {
          await _pumpAppWithLongText(tester);

          // Select the word "dolor".
          await tester.doubleTapInParagraph("1", 14);
          await tester.pumpAndSettle();
          expect(SuperEditorInspector.findDocumentSelection(), _wordDolorSelection);

          // Tap just upstream from the upstream handle, where a long-press places the caret.
          final upstreamHandle = tester.getRect(find.byKey(DocumentKeys.upstreamHandle));
          await tester.tapAt(Offset(upstreamHandle.center.dx - 14, upstreamHandle.bottom - 8));
          await tester.pumpAndSettle();

          // Ensure that the tap counted as a tap on the handle, which keeps the selection.
          expect(SuperEditorInspector.findDocumentSelection(), _wordDolorSelection);
        });

        testWidgetsOnIos("moves the caret with the finger when dragging", (tester) async {
          await _pumpAppWithLongText(tester);

          // Long press on the middle of "do|lor".
          final gesture = await tester.longPressDownInParagraph("1", 14);
          await tester.pump();
          expect(SuperEditorInspector.findDocumentSelection(), _caretAt(14));

          // Drag downstream.
          const dragIncrementCount = 10;
          for (int i = 0; i < dragIncrementCount; i += 1) {
            await gesture.moveBy(const Offset(80 / dragIncrementCount, 0));
            await tester.pump();
          }

          // Ensure that the caret followed the finger downstream, without selecting
          // anything, and that the magnifier is still visible.
          final downstreamSelection = SuperEditorInspector.findDocumentSelection()!;
          expect(downstreamSelection.isCollapsed, isTrue);
          final downstreamOffset = (downstreamSelection.extent.nodePosition as TextNodePosition).offset;
          expect(downstreamOffset, greaterThan(14));
          expect(SuperEditorInspector.isMobileMagnifierVisible(), isTrue);

          // Drag back upstream, past the original long-press offset.
          for (int i = 0; i < dragIncrementCount; i += 1) {
            await gesture.moveBy(const Offset(-130 / dragIncrementCount, 0));
            await tester.pump();
          }

          // Ensure that the caret followed the finger upstream, without selecting anything.
          final upstreamSelection = SuperEditorInspector.findDocumentSelection()!;
          expect(upstreamSelection.isCollapsed, isTrue);
          expect((upstreamSelection.extent.nodePosition as TextNodePosition).offset, lessThan(14));

          // Release the gesture, and ensure the magnifier goes away.
          await gesture.up();
          await tester.pumpAndSettle();
          expect(SuperEditorInspector.findDocumentSelection()!.isCollapsed, isTrue);
          expect(SuperEditorInspector.isMobileMagnifierVisible(), isFalse);
        });

        testWidgetsOnIos("places the caret beside an image and moves it into text", (tester) async {
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

          // Long press near the top left of the image.
          final tapDownOffset = tester.getTopLeft(find.byType(ImageComponent)) + const Offset(10, 10);
          final gesture = await tester.startGesture(tapDownOffset);
          await tester.pump(kLongPressTimeout + kPressTimeout);

          // Ensure that the caret sits before the image, rather than the image being selected.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(nodeId: '1', nodePosition: UpstreamDownstreamNodePosition.upstream()),
            ),
          );

          // Drag down from the image to the beginning of the paragraph.
          const dragIncrementCount = 10;
          final verticalDragDistance =
              Offset(0, (tester.getTopLeft(find.byType(TextComponent)).dy - tapDownOffset.dy) / dragIncrementCount);
          for (int i = 0; i < dragIncrementCount; i += 1) {
            await gesture.moveBy(verticalDragDistance);
            await tester.pump();
          }

          // Ensure that the caret moved into the paragraph, without selecting anything.
          final selection = SuperEditorInspector.findDocumentSelection()!;
          expect(selection.isCollapsed, isTrue);
          expect(selection.extent.nodeId, '2');

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

      testWidgetsOnIos("keeps the caret in an empty paragraph when the IME reports it", (tester) async {
        // An empty paragraph begins and ends at the same position, so a caret in it covers the whole
        // paragraph. This test ensures that a caret in an empty paragraph isn't mistaken for the user
        // pressing "Select all", which the test above covers.
        //
        // iOS reports a caret like this whenever it sends a selection change, e.g., right after the user
        // moves the floating cursor onto an empty paragraph.
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
                  text: AttributedText(),
                ),
                ParagraphNode(
                  id: '3',
                  text: AttributedText('Third paragraph'),
                ),
              ],
            ))
            .pump();

        // Place the caret in the empty paragraph.
        await tester.placeCaretInParagraph('2', 0);

        // Simulate iOS reporting the caret in the empty paragraph. The IME text of an empty paragraph is
        // only its invisible placeholder characters, so the caret sits after them.
        await tester.ime.sendDeltas(const [
          TextEditingDeltaNonTextUpdate(
            oldText: '. ',
            selection: TextSelection.collapsed(offset: 2),
            composing: TextRange(start: -1, end: -1),
          ),
        ], getter: imeClientGetter);

        // Ensure that the caret stayed in the empty paragraph, rather than selecting the entire document.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: '2',
              nodePosition: TextNodePosition(offset: 0),
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

/// Long-presses at the given global [offset], and releases.
Future<void> _longPressAt(WidgetTester tester, Offset offset) async {
  final gesture = await tester.startGesture(offset);
  await tester.pump(kLongPressTimeout + kPressTimeout);
  await gesture.up();
  await tester.pumpAndSettle();
}

DocumentSelection _caretAt(int offset) => DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: "1",
        nodePosition: TextNodePosition(offset: offset),
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
