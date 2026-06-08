import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

void main() {
  group('IME input >', () {
    group('typing characters near a link', () {
      testWidgetsOnMobile('does not expand the link when inserting before the link', (tester) async {
        // Configure and render a document.
        await tester //
            .createDocument()
            .withCustomContent(_singleParagraphWithLinkDoc())
            .pump();

        // Place the caret at the start of the link.
        await tester.placeCaretInParagraph('1', 0);

        // Type characters before the link using the IME
        await tester.ime.typeText("Go to ", getter: imeClientGetter);

        // Ensure that the link is unchanged
        expect(
          SuperEditorInspector.findDocument(),
          equalsMarkdown("Go to [https://google.com](https://google.com)"),
        );
      });

      testWidgetsOnMobile('does not expand the link when inserting after the link', (tester) async {
        // Configure and render a document.
        await tester //
            .createDocument()
            .withCustomContent(_singleParagraphWithLinkDoc())
            .pump();

        // Place the caret at the end of the link.
        await tester.placeCaretInParagraph('1', 18);

        // Type characters after the link using the IME
        await tester.ime.typeText(" to learn anything", getter: imeClientGetter);

        // Ensure that the link is unchanged
        expect(
          SuperEditorInspector.findDocument(),
          equalsMarkdown("[https://google.com](https://google.com) to learn anything"),
        );
      });
    });
  });
}

MutableDocument _singleParagraphWithLinkDoc() {
  return MutableDocument(
    nodes: [
      ParagraphNode(
        id: "1",
        text: AttributedText(
          "https://google.com",
          AttributedSpans(
            attributions: [
              SpanMarker(
                attribution: LinkAttribution.fromUri(Uri.parse('https://google.com')),
                offset: 0,
                markerType: SpanMarkerType.start,
              ),
              SpanMarker(
                attribution: LinkAttribution.fromUri(Uri.parse('https://google.com')),
                offset: 17,
                markerType: SpanMarkerType.end,
              ),
            ],
          ),
        ),
      )
    ],
  );
}
