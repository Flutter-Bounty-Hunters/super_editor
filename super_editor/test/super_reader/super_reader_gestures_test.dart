import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/multi_tap_gesture.dart';
import 'package:super_editor/src/super_reader/super_reader.dart';
import 'package:super_editor/super_reader_test.dart';

import '../test_tools.dart';

void main() {
  group('SuperReader gestures', () {
    testWidgetsOnDesktop('scrolls the content when dragging the scrollbar (downstream)', (tester) async {
      final scrollController = ScrollController();
      await tester //
          .createDocument()
          .withSingleParagraph()
          .withEditorSize(const Size(300, 300))
          .withScrollController(scrollController)
          .pump();

      // Ensure the editor didn't start scrolled.
      expect(scrollController.position.pixels, 0.0);

      // Double tap to select "Lorem".
      await tester.doubleTapInParagraph('1', 0);
      expect(
        SuperReaderInspector.findDocumentSelection(),
        selectionEquivalentTo(const DocumentSelection(
          base: DocumentPosition(nodeId: '1', nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: '1', nodePosition: TextNodePosition(offset: 5)),
        )),
      );

      // Find the approximate position of the scrollbar thumb.
      final startingDragLocation = tester.getTopRight(find.byType(SuperReader)) + const Offset(-10, 10);

      final testPointer = TestPointer(1, PointerDeviceKind.mouse);

      // Hover to make the thumb visible with a duration long enough to run the fade animation.
      await tester.sendEventToBinding(testPointer.hover(startingDragLocation, timeStamp: const Duration(seconds: 1)));
      await tester.pumpAndSettle();

      // Tap and hold the thumb.
      await tester.sendEventToBinding(testPointer.down(startingDragLocation));
      await tester.pump(kTapMinTime);

      // Move the thumb down.
      await tester.sendEventToBinding(testPointer.move(startingDragLocation + const Offset(0, 300)));
      await tester.pump();

      // Release the pointer.
      await tester.sendEventToBinding(testPointer.up());
      await tester.pump();

      // Ensure the content scrolled down.
      expect(scrollController.position.pixels, greaterThan(0));

      // Ensure the selection didn't change.
      expect(
        SuperReaderInspector.findDocumentSelection(),
        selectionEquivalentTo(const DocumentSelection(
          base: DocumentPosition(nodeId: '1', nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: '1', nodePosition: TextNodePosition(offset: 5)),
        )),
      );
    });

    testWidgetsOnDesktop('scrolls the content when dragging the scrollbar (upstream)', (tester) async {
      final scrollController = ScrollController();
      await tester //
          .createDocument()
          .withSingleParagraph()
          .withEditorSize(const Size(300, 300))
          .withScrollController(scrollController)
          .pump();

      // Double tap to select "Lorem".
      await tester.doubleTapInParagraph('1', 0);
      expect(
        SuperReaderInspector.findDocumentSelection(),
        selectionEquivalentTo(const DocumentSelection(
          base: DocumentPosition(nodeId: '1', nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: '1', nodePosition: TextNodePosition(offset: 5)),
        )),
      );

      // Jump to the end of the document.
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
      await tester.pump();

      // Find the approximate position of the scrollbar thumb.
      final startingDragLocation = tester.getBottomRight(find.byType(SuperReader)) - const Offset(10, 10);

      final testPointer = TestPointer(1, PointerDeviceKind.mouse);

      // Hover to make the thumb visible with a duration long enough to run the fade animation.
      await tester.sendEventToBinding(testPointer.hover(startingDragLocation, timeStamp: const Duration(seconds: 1)));
      await tester.pumpAndSettle();

      // Tap and hold the thumb.
      await tester.sendEventToBinding(testPointer.down(startingDragLocation));
      await tester.pump(kTapMinTime);

      // Move the thumb up.
      await tester.sendEventToBinding(testPointer.move(startingDragLocation - const Offset(0, 300)));
      await tester.pump();

      // Release the pointer.
      await tester.sendEventToBinding(testPointer.up());
      await tester.pump();

      // Ensure the content scrolled up.
      expect(scrollController.position.pixels, 0);

      // Ensure the selection didn't change.
      expect(
        SuperReaderInspector.findDocumentSelection(),
        selectionEquivalentTo(
          const DocumentSelection(
            base: DocumentPosition(nodeId: '1', nodePosition: TextNodePosition(offset: 0)),
            extent: DocumentPosition(nodeId: '1', nodePosition: TextNodePosition(offset: 5)),
          ),
        ),
      );
    });
  });
}
