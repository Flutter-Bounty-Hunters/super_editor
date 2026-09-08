import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

void main() {
  group("SuperEditor > IME visual information reporting >", () {
    testWidgetsOnAllPlatforms("does not continuously schedule frames when idle", (tester) async {
      final document = MutableDocument(
        nodes: [
          ParagraphNode(id: "1", text: AttributedText("Hello world")),
        ],
      );

      await tester //
          .createDocument()
          .withCustomContent(document)
          .withInputSource(TextInputSource.ime)
          .pump();

      // Focus and place caret.
      await tester.placeCaretInParagraph("1", 5);
      await tester.pumpAndSettle();

      // Ensure that when the editor is idle, frames are not continuously being scheduled
      // by _reportVisualInformationToIme().
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });
}
