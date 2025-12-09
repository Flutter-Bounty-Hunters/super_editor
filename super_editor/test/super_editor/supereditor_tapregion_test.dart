import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/multi_tap_gesture.dart';
import 'package:super_editor/super_editor_test.dart';

import '../test_tools.dart';

void main() {
  group('SuperEditor inside a TapRegion', () {
    testWidgetsOnAndroid("allows interaction with collapsed handle", (tester) async {
      const tapRegionGroupId = 'super_editor_group_id';
      final focusNode = FocusNode();

      final context = await tester //
          .createDocument()
          .fromMarkdown('Single line document.')
          .withFocusNode(focusNode)
          .withTapRegionGroupId(tapRegionGroupId)
          .withCustomWidgetTreeBuilder(
            (superEditor) => MaterialApp(
              home: Scaffold(
                body: TapRegion(
                  groupId: tapRegionGroupId,
                  onTapOutside: (e) {
                    // Unfocus on tap outside so that we're sure that the test
                    // pass when using TapRegion's for focus, because apps should be able
                    // to do that.
                    focusNode.unfocus();
                  },
                  child: superEditor,
                ),
              ),
            ),
          )
          .pump();

      final nodeId = context.document.first.id;

      // Place the caret at the start of the document to show the drag handle.
      await tester.placeCaretInParagraph(nodeId, 0);
      await tester.pump(kDoubleTapTimeout);

      // Drag the handle all the way to the end of the content.
      final gesture = await tester.pressDownOnCollapsedMobileHandle();
      await gesture.moveBy(const Offset(500, 0));
      await tester.pump();

      // Ensure the selection was placed at the end of the document.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        selectionEquivalentTo(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: nodeId,
              nodePosition: const TextNodePosition(offset: 21),
            ),
          ),
        ),
      );
    });

    testWidgetsOnMobile("allows interaction with expanded handle", (tester) async {
      const tapRegionGroupId = 'super_editor_group_id';
      final focusNode = FocusNode();

      final context = await tester //
          .createDocument()
          .fromMarkdown('Single line document.')
          .withFocusNode(focusNode)
          .withTapRegionGroupId(tapRegionGroupId)
          .withCustomWidgetTreeBuilder(
            (superEditor) => MaterialApp(
              home: Scaffold(
                body: TapRegion(
                  groupId: tapRegionGroupId,
                  onTapOutside: (e) {
                    // Unfocus on tap outside so that we're sure that the test
                    // pass when using TapRegion's for focus, because apps should be able
                    // to do that.
                    focusNode.unfocus();
                  },
                  child: superEditor,
                ),
              ),
            ),
          )
          .pump();

      final nodeId = context.document.first.id;

      // Double tap to show the expanded handle.
      await tester.doubleTapInParagraph(nodeId, 0);

      // Drag the downstream handle all the way to the end of the content.
      final gesture = await tester.pressDownOnDownstreamMobileHandle();
      await gesture.moveBy(const Offset(500, 0));
      await tester.pump();

      // Ensure the selection expanded to the end of the document.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        selectionEquivalentTo(
          DocumentSelection(
            base: DocumentPosition(
              nodeId: nodeId,
              nodePosition: const TextNodePosition(offset: 0),
            ),
            extent: DocumentPosition(
              nodeId: nodeId,
              nodePosition: const TextNodePosition(offset: 21),
            ),
          ),
        ),
      );

      // Pump with enough time to expire the tap recognizer timer.
      await tester.pump(kTapTimeout);
    });
  });
}
