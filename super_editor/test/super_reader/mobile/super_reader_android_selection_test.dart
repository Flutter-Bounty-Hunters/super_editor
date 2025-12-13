import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/src/infrastructure/platforms/android/magnifier.dart';
import 'package:super_editor/src/infrastructure/platforms/android/selection_handles.dart';
import 'package:super_editor/src/test/super_reader_test/super_reader_inspector.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart' show SuperEditorRobot;
import 'package:super_editor/super_reader_test.dart';

void main() {
  group("SuperReader mobile selection >", () {
    group("Android >", () {
      group("long press >", () {
        testWidgetsOnAndroid("selects word under finger", (tester) async {
          await _pumpAppWithLongText(tester);

          // Ensure that no overlay controls are visible.
          _expectNoControlsAreVisible();

          // Long press on the middle of "conse|ctetur"
          await tester.longPressInParagraph("1", 33);
          await tester.pumpAndSettle();

          // Ensure the word was selected.
          expect(SuperReaderInspector.findDocumentSelection(), isNotNull);
          expect(SuperReaderInspector.findDocumentSelection(), _wordConsecteturSelection);

          // Ensure the drag handles and toolbar are visible, but the magnifier isn't.
          _expectHandlesAndToolbar();
        });

        testWidgetsOnAndroid("selects by word when dragging upstream", (tester) async {
          await _pumpAppWithLongText(tester);

          // Long press on the middle of "do|lor".
          final gesture = await tester.longPressDownInParagraph("1", 14);
          await tester.pumpAndSettle();

          // Ensure the word was selected.
          expect(SuperReaderInspector.findDocumentSelection(), _wordDolorSelection);

          // Ensure the toolbar is visible, but drag handles and magnifier aren't.
          _expectOnlyToolbar();

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
            SuperReaderInspector.findDocumentSelection(),
            const DocumentSelection(
              base: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 17),
              ),
              extent: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 6),
              ),
            ),
          );

          // Now that we've started dragging, ensure the magnifier is visible and the
          // toolbar is hidden.
          expect(find.byType(AndroidTextEditingFloatingToolbar), findsNothing);
          expect(find.byType(AndroidMagnifyingGlass), findsOne);

          // Release the gesture so the test system doesn't complain.
          await gesture.up();
          await tester.pump();

          // Now that the drag is done, ensure the handles and toolbar are visible and
          // the magnifier isn't.
          _expectHandlesAndToolbar();
        });

        testWidgetsOnAndroid("selects by character when dragging upstream in reverse", (tester) async {
          await _pumpAppWithLongText(tester);

          // Long press on the middle of "do|lor".
          final gesture = await tester.longPressDownInParagraph("1", 14);
          await tester.pumpAndSettle();

          // Ensure the word was selected.
          expect(SuperReaderInspector.findDocumentSelection(), _wordDolorSelection);

          // Drag near the end of the upstream word.
          // "Lorem i|psum dolor sit amet"
          //         ^ position 7
          //
          // We do this with manual distances because the attempt to look up character
          // offsets was producing unpredictable results.
          const dragIncrementCount = 10;
          const upstreamDragDistance = -15.0;
          for (int i = 0; i < dragIncrementCount; i += 1) {
            await gesture.moveBy(const Offset(upstreamDragDistance, 0));
            await tester.pump();
          }

          // Ensure the original word and upstream word are both selected.
          expect(
            SuperReaderInspector.findDocumentSelection(),
            const DocumentSelection(
              base: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 17),
              ),
              extent: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 6),
              ),
            ),
          );

          // Drag in reverse toward the initial selection.
          //
          // Drag far enough to trigger a per-character selection, and then
          // drag a little more to deselect some characters.
          const downstreamDragDistance = 110 / dragIncrementCount;
          for (int i = 0; i < dragIncrementCount; i += 1) {
            await gesture.moveBy(const Offset(downstreamDragDistance, 0));
            await tester.pump();
          }

          // Ensure that part of the upstream word is selected because we're now
          // in per-character selection mode.
          //
          // "Lorem ipsu|m dolor sit amet"
          //            ^ position 10
          expect(
            SuperReaderInspector.findDocumentSelection(),
            const DocumentSelection(
              base: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 17),
              ),
              extent: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 10),
              ),
            ),
          );

          // Release the gesture so the test system doesn't complain.
          await gesture.up();
          await tester.pump();
        });

        testWidgetsOnAndroid("selects by word when jumping up a line and dragging upstream", (tester) async {
          await _pumpAppWithLongText(tester);

          // Long press on the middle of "adi|piscing".
          final gesture = await tester.longPressDownInParagraph("1", 42);
          await tester.pumpAndSettle();

          // Ensure the word was selected.
          expect(SuperReaderInspector.findDocumentSelection(), _wordAdipiscingSelection);

          // Ensure the toolbar is visible, but drag handles and magnifier aren't.
          _expectOnlyToolbar();

          // Drag up one line to select "dolor".
          const dragIncrementCount = 10;
          const verticalDragDistance = -24 / dragIncrementCount;
          for (int i = 0; i < dragIncrementCount; i += 1) {
            await gesture.moveBy(const Offset(0, verticalDragDistance));
            await tester.pump();
          }

          // Ensure the selection begins at the end of "adipiscing" and goes to the
          // beginning of "dolor", which is upstream.
          expect(
            SuperReaderInspector.findDocumentSelection(),
            const DocumentSelection(
              base: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: _wordAdipiscingEnd),
              ),
              extent: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: _wordDolorStart),
              ),
            ),
          );

          // Drag upstream to select the previous word.
          const upstreamDragDistance = -80 / dragIncrementCount;
          for (int i = 0; i < dragIncrementCount; i += 1) {
            await gesture.moveBy(const Offset(upstreamDragDistance, 0));
            await tester.pump();
          }

          expect(
            SuperReaderInspector.findDocumentSelection(),
            const DocumentSelection(
              base: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: _wordAdipiscingEnd),
              ),
              extent: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: _wordIpsumStart),
              ),
            ),
          );

          // Release the gesture so the test system doesn't complain.
          await gesture.up();
          await tester.pump();
        });

        testWidgetsOnAndroid("selects by word when dragging downstream", (tester) async {
          await _pumpAppWithLongText(tester);

          // Long press on the middle of "do|lor".
          final gesture = await tester.longPressDownInParagraph("1", 14);
          await tester.pumpAndSettle();

          // Ensure the word was selected.
          expect(SuperReaderInspector.findDocumentSelection(), _wordDolorSelection);

          // Ensure the toolbar is visible, but drag handles and magnifier aren't.
          _expectOnlyToolbar();

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
          //
          // "Lorem ipsum dolor sit| amet"
          //                       ^ position 21
          expect(
            SuperReaderInspector.findDocumentSelection(),
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

          // Now that we've started dragging, ensure the magnifier is visible and the
          // toolbar is hidden.
          _expectOnlyMagnifier();

          // Release the gesture so the test system doesn't complain.
          await gesture.up();
          await tester.pump();

          // Now that the drag is done, ensure the handles and toolbar are visible and
          // the magnifier isn't.
          _expectHandlesAndToolbar();
        });

        testWidgetsOnAndroid("selects by character when dragging downstream in reverse", (tester) async {
          await _pumpAppWithLongText(tester);

          // Long press on the middle of "do|lor".
          final gesture = await tester.longPressDownInParagraph("1", 14);
          await tester.pumpAndSettle();

          // Ensure the word was selected.
          expect(SuperReaderInspector.findDocumentSelection(), _wordDolorSelection);

          // Drag near the end of the downstream word.
          // "Lorem ipsum dolor si|t amet"
          //                      ^ position 20
          //
          // We do this with manual distances because the attempt to look up character
          // offsets was producing unpredictable results.
          const dragIncrementCount = 10;
          const upstreamDragDistance = 100 / dragIncrementCount;
          for (int i = 0; i < dragIncrementCount; i += 1) {
            await gesture.moveBy(const Offset(upstreamDragDistance, 0));
            await tester.pump();
          }

          // Ensure the original word and downstream word are both selected.
          expect(
            SuperReaderInspector.findDocumentSelection(),
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

          // Drag in reverse toward the initial selection.
          //
          // Drag far enough to trigger a per-character selection, and then
          // drag a little more to deselect some characters.
          const downstreamDragDistance = -40 / dragIncrementCount;
          for (int i = 0; i < dragIncrementCount; i += 1) {
            await gesture.moveBy(const Offset(downstreamDragDistance, 0));
            await tester.pump();
          }

          // Ensure that part of the downstream word is selected because we're now
          // in per-character selection mode.
          //
          // "Lorem ipsum dolor s|it amet"
          //                     ^ position 19
          expect(
            SuperReaderInspector.findDocumentSelection(),
            const DocumentSelection(
              base: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 12),
              ),
              extent: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 19),
              ),
            ),
          );

          // Release the gesture so the test system doesn't complain.
          await gesture.up();
          await tester.pump();
        });

        testWidgetsOnAndroid("selects by word when jumping down a line and dragging downstream", (tester) async {
          await _pumpAppWithLongText(tester);

          // Long press on the middle of "adi|piscing".
          final gesture = await tester.longPressDownInParagraph("1", 42);
          await tester.pumpAndSettle();

          // Ensure the word was selected.
          expect(SuperReaderInspector.findDocumentSelection(), _wordAdipiscingSelection);

          // Drag down one line to select "tempor".
          const dragIncrementCount = 10;
          const verticalDragDistance = 24 / dragIncrementCount;
          for (int i = 0; i < dragIncrementCount; i += 1) {
            await gesture.moveBy(const Offset(0, verticalDragDistance));
            await tester.pump();
          }

          // Ensure the selection begins at the start of "adipiscing" and goes to the
          // end of "tempor", which is upstream.
          expect(
            SuperReaderInspector.findDocumentSelection(),
            const DocumentSelection(
              base: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: _wordAdipiscingStart),
              ),
              extent: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: _wordTemporEnd),
              ),
            ),
          );

          // Drag downstream to select the next word.
          const downstreamDragDistance = 80 / dragIncrementCount;
          for (int i = 0; i < dragIncrementCount; i += 1) {
            await gesture.moveBy(const Offset(downstreamDragDistance, 0));
            await tester.pump();
          }

          expect(
            SuperReaderInspector.findDocumentSelection(),
            const DocumentSelection(
              base: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: _wordAdipiscingStart),
              ),
              extent: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: _wordIncididuntEnd),
              ),
            ),
          );

          // Release the gesture so the test system doesn't complain.
          await gesture.up();
          await tester.pump();
        });
      });
    });
  });
}

// The test suite was originally laid out and calculated with:
//  - physical size: 2400x1800
//  - device pixel ratio: 3.0

// 01) Lorem ipsum dolor sit amet,      [0, 28]
// 02) consectetur adipiscing elit, sed [28, 61]
// 03) do eiusmod tempor incididunt ut  [61, 93]
// 04) labore et dolore magna aliqua.
// 05) Ut enim ad minim veniam, quis
// 06) nostrud exercitation ullamco
// 07) laboris nisi ut aliquip ex ea
// 08) commodo consequat. Duis aute
// 09) irure dolor in reprehenderit in
// 10) voluptate velit esse cillum
// 11) dolore eu fugiat nulla pariatur.
// 12) Excepteur sint occaecat
// 13) cupidatat non proident, sunt in
// 14) culpa qui officia deserunt
// 15) mollit anim id est laborum.

Future<void> _pumpAppWithLongText(WidgetTester tester) async {
  await tester
      .createDocument()
      // "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod...",
      .withSingleParagraph()
      .withAndroidToolbarBuilder((context) => const AndroidTextEditingFloatingToolbar())
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

const _wordIpsumStart = 6;
// ignore: unused_element
const _wordIpsumEnd = 11;

const _wordDolorStart = 12;
const _wordDolorEnd = 17;
const _wordDolorSelection = DocumentSelection(
  base: DocumentPosition(
    nodeId: "1",
    nodePosition: TextNodePosition(offset: _wordDolorStart),
  ),
  extent: DocumentPosition(
    nodeId: "1",
    nodePosition: TextNodePosition(offset: _wordDolorEnd),
  ),
);

const _wordAdipiscingStart = 40;
const _wordAdipiscingEnd = 50;
const _wordAdipiscingSelection = DocumentSelection(
  base: DocumentPosition(
    nodeId: "1",
    nodePosition: TextNodePosition(offset: _wordAdipiscingStart),
  ),
  extent: DocumentPosition(
    nodeId: "1",
    nodePosition: TextNodePosition(offset: _wordAdipiscingEnd),
  ),
);

// ignore: unused_element
const _wordTemporStart = 72;
const _wordTemporEnd = 78;

// ignore: unused_element
const _wordIncididuntStart = 79;
const _wordIncididuntEnd = 89;

void _expectNoControlsAreVisible() {
  expect(find.byType(AndroidSelectionHandle), findsNothing);
  expect(find.byType(AndroidTextEditingFloatingToolbar), findsNothing);
  expect(find.byType(AndroidMagnifyingGlass), findsNothing);
}

void _expectOnlyToolbar() {
  expect(find.byType(AndroidSelectionHandle), findsNothing);
  expect(find.byType(AndroidTextEditingFloatingToolbar), findsOne);
  expect(find.byType(AndroidMagnifyingGlass), findsNothing);
}

void _expectOnlyMagnifier() {
  expect(find.byType(AndroidSelectionHandle), findsNothing);
  expect(find.byType(AndroidTextEditingFloatingToolbar), findsNothing);
  expect(find.byType(AndroidMagnifyingGlass), findsOne);
}

void _expectHandlesAndToolbar() {
  expect(find.byType(AndroidSelectionHandle), findsExactly(2));
  expect(find.byType(AndroidTextEditingFloatingToolbar), findsOne);
  expect(find.byType(AndroidMagnifyingGlass), findsNothing);
}
