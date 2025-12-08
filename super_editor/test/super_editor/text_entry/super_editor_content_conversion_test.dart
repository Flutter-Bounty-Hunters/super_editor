import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

void main() {
  group('SuperEditor', () {
    group('link conversion', () {
      // This is not neccessary a desktop platform test suite, but it utilizes the
      // simulation of pasting on desktop
      // Note: This covers cases on mobile as well, so separated tests for mobile
      // is not necessary
      group('recognizes links in pasted code', () {
        testWidgetsOnMac('when pasting into an empty paragraph', (tester) async {
          tester
            ..simulateClipboard()
            ..setSimulatedClipboardContent("Link: https://flutter.dev and link: https://pub.dev");

          // Configure and render a document.
          await tester //
              .createDocument()
              .withSingleEmptyParagraph()
              .forDesktop()
              .pump();

          // Tap to place the caret in the first paragraph.
          await tester.placeCaretInParagraph("1", 0);
          // Simulate the user pasting content from clipboard
          await tester.pressCmdV();

          // Ensure that URLs are converted into links
          expect(
            SuperEditorInspector.findDocument(),
            equalsMarkdown(
              'Link: [https://flutter.dev](https://flutter.dev) and link: [https://pub.dev](https://pub.dev)',
            ),
          );
        });

        testWidgetsOnMac('when pasting at the start of text', (tester) async {
          tester
            ..simulateClipboard()
            ..setSimulatedClipboardContent("Link: https://flutter.dev and link: https://pub.dev");

          // Configure and render a document.
          await tester
              .createDocument()
              .withCustomContent(MutableDocument(
                nodes: [
                  ParagraphNode(id: "1", text: AttributedText("Some text")),
                ],
              ))
              .forDesktop()
              .pump();

          // Tap to place the caret at `|Some text` in the paragraph.
          await tester.placeCaretInParagraph("1", 0);
          // Simulate the user pasting content from clipboard
          await tester.pressCmdV();

          // Ensure that URLs are converted into links
          expect(
            SuperEditorInspector.findDocument(),
            equalsMarkdown(
              'Link: [https://flutter.dev](https://flutter.dev) and link: [https://pub.dev](https://pub.dev)Some text',
            ),
          );
        });

        testWidgetsOnMac('when pasting in the middle of text', (tester) async {
          tester
            ..simulateClipboard()
            ..setSimulatedClipboardContent("Link: https://flutter.dev and link: https://pub.dev");

          // Configure and render a document.
          await tester
              .createDocument()
              .withCustomContent(MutableDocument(
                nodes: [
                  ParagraphNode(id: "1", text: AttributedText("Some text")),
                ],
              ))
              .forDesktop()
              .pump();

          // Tap to place the caret at `Some te|xt` in the paragraph.
          await tester.placeCaretInParagraph("1", 7);
          // Simulate the user pasting content from clipboard
          await tester.pressCmdV();

          // Ensure that URLs are converted into links
          expect(
            SuperEditorInspector.findDocument(),
            equalsMarkdown(
              'Some teLink: [https://flutter.dev](https://flutter.dev) and link: [https://pub.dev](https://pub.dev)xt',
            ),
          );
        });

        testWidgetsOnMac('when pasting at the end of text', (tester) async {
          tester
            ..simulateClipboard()
            ..setSimulatedClipboardContent("Link: https://flutter.dev and link: https://pub.dev");

          // Configure and render a document.
          await tester
              .createDocument()
              .withCustomContent(MutableDocument(
                nodes: [
                  ParagraphNode(id: "1", text: AttributedText("Some text")),
                ],
              ))
              .forDesktop()
              .pump();

          // Tap to place the caret at `Some text|` in the paragraph.
          await tester.placeCaretInParagraph("1", 9);
          // Simulate the user pasting content from clipboard
          await tester.pressCmdV();

          // Ensure that URLs are converted into links
          expect(
            SuperEditorInspector.findDocument(),
            equalsMarkdown(
              'Some textLink: [https://flutter.dev](https://flutter.dev) and link: [https://pub.dev](https://pub.dev)',
            ),
          );
        });

        testWidgetsOnMac('when pasting at the start of a link', (tester) async {
          tester
            ..simulateClipboard()
            ..setSimulatedClipboardContent("Link: https://flutter.dev");

          // Configure and render a document.
          await tester //
              .createDocument()
              .withCustomContent(_singleParagraphWithLinkDoc())
              .forDesktop()
              .pump();

          // Tap to place the caret in the first paragraph.
          await tester.placeCaretInParagraph("1", 0);
          // Simulate the user pasting content from clipboard
          await tester.pressCmdV();

          // Ensure that the link is unchanged
          expect(
            SuperEditorInspector.findDocument(),
            equalsMarkdown("Link: [https://flutter.dev](https://flutter.dev)[https://google.com](https://google.com)"),
          );
        });

        testWidgetsOnMac('when pasting at the end of a link', (tester) async {
          tester
            ..simulateClipboard()
            ..setSimulatedClipboardContent("Link: https://flutter.dev");

          // Configure and render a document.
          await tester //
              .createDocument()
              .withCustomContent(_singleParagraphWithLinkDoc())
              .forDesktop()
              .pump();

          // Tap to place the caret in the first paragraph.
          await tester.placeCaretInParagraph("1", 18);
          // Simulate the user pasting content from clipboard
          await tester.pressCmdV();

          // Ensure that the link is unchanged
          expect(
            SuperEditorInspector.findDocument(),
            equalsMarkdown("[https://google.com](https://google.com)Link: [https://flutter.dev](https://flutter.dev)"),
          );
        });

        testWidgetsOnMac('when pasting in the middle of a link', (tester) async {
          tester
            ..simulateClipboard()
            ..setSimulatedClipboardContent("Link: https://flutter.dev");

          // Configure and render a document.
          await tester //
              .createDocument()
              .withCustomContent(_singleParagraphWithLinkDoc())
              .forDesktop()
              .pump();

          // Tap to place the caret in the first paragraph.
          await tester.placeCaretInParagraph("1", 9);
          // Simulate the user pasting content from clipboard
          await tester.pressCmdV();

          // Ensure that the link is unchanged
          expect(
            SuperEditorInspector.findDocument(),
            // Notice that the pasted text splits the existing link. Each
            // piece of the existing link continues to link to the full URL.
            equalsMarkdown(
                "[https://g](https://google.com)Link: [https://flutter.dev](https://flutter.dev)[oogle.com](https://google.com)"),
          );
        });
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
              const SpanMarker(
                attribution: LinkAttribution('https://google.com'),
                offset: 0,
                markerType: SpanMarkerType.start,
              ),
              const SpanMarker(
                attribution: LinkAttribution('https://google.com'),
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
