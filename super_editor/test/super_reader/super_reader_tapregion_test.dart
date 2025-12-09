import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/multi_tap_gesture.dart';
import 'package:super_editor/src/test/super_reader_test/super_reader_inspector.dart';
import 'package:super_editor/src/test/super_reader_test/super_reader_robot.dart';

import '../test_tools.dart';
import '../../lib/src/test/super_reader_test/reader_test_tools.dart';

void main() {
  group('SuperReader inside a TapRegion', () {
    testWidgetsOnMobile("does not report a tap outside when the user touches overlay controls", (tester) async {
      const tapRegionId = 'super_editor_group_id';
      final focusNode = FocusNode();

      final context = await tester //
          .createDocument()
          .fromMarkdown('Single line document.')
          .withFocusNode(focusNode)
          .withTapRegionGroupId(tapRegionId)
          .withCustomWidgetTreeBuilder(
            (superEditor) => MaterialApp(
              home: Scaffold(
                body: TapRegion(
                  groupId: tapRegionId,
                  onTapOutside: (e) {
                    // Fail on tap outside so that we're sure that the test
                    // pass when using TapRegion's for focus, because apps should be able
                    // to do that.
                    fail('Tapped outside of SuperReader');
                  },
                  child: superEditor,
                ),
              ),
            ),
          )
          .pump();

      final nodeId = context.document.first.id;

      // Double tap to show the expanded handle.
      await SuperReaderRobot(tester).doubleTapInParagraph(nodeId, 0);

      // Drag the downstream handle all the way to the end of the content.
      final gesture = await SuperReaderRobot(tester).pressDownOnDownstreamMobileHandle();
      await gesture.moveBy(const Offset(500, 0));
      await tester.pump();

      // Ensure the selection expanded to the end of the document.
      expect(
        SuperReaderInspector.findDocumentSelection(),
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
