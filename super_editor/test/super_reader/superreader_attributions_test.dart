import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/src/test/super_reader_test/super_reader_inspector.dart';

import '../super_editor/test_documents.dart';
import '../../lib/src/test/super_reader_test/reader_test_tools.dart';

void main() {
  group("SuperReader", () {
    group("applies color attributions", () {
      testWidgetsOnAllPlatforms("to full text", (tester) async {
        await tester //
            .createDocument()
            .withCustomContent(
              singleParagraphFullColor(),
            )
            .pump();

        // Ensure the text is colored orange.
        final text = SuperReaderInspector.findTextInParagraph("1");
        final richText = SuperReaderInspector.findRichTextInParagraph("1");
        expect(
          richText.getSpanForPosition(const TextPosition(offset: 1))!.style!.color,
          Colors.orange,
        );
        expect(
          richText.getSpanForPosition(TextPosition(offset: text.length - 1))!.style!.color,
          Colors.orange,
        );
      });

      testWidgetsOnAllPlatforms("to partial text", (tester) async {
        await tester //
            .createDocument()
            .withCustomContent(
              singleParagraphWithPartialColor(),
            )
            .pump();

        // Ensure the first span is colored black.
        expect(
          SuperReaderInspector.findRichTextInParagraph("1")
              .getSpanForPosition(const TextPosition(offset: 0))!
              .style!
              .color,
          Colors.black,
        );

        // Ensure the second span is colored orange.
        expect(
          SuperReaderInspector.findRichTextInParagraph("1")
              .getSpanForPosition(const TextPosition(offset: 5))!
              .style!
              .color,
          Colors.orange,
        );
      });
    });
  });
}
