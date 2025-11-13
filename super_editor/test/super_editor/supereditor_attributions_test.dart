import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import 'supereditor_test_tools.dart';
import 'test_documents.dart';

void main() {
  group("SuperEditor >", () {
    group("applies attributions >", () {
      group("when continuing existing attributions >", () {
        group("by placing caret >", () {
          // Bold is a stand-in for any value-based attribution extension, e.g.,
          // italics, underline, strikethrough.
          testWidgetsOnAllPlatforms("bold", (tester) async {
            await tester //
                .createDocument()
                .fromMarkdown("A **bold** text")
                .withInputSource(TextInputSource.ime)
                .pump();

            final doc = SuperEditorInspector.findDocument()!;

            // Place the caret at "bold|".
            await tester.placeCaretInParagraph(doc.first.id, 6);

            // Type at an offset that should expand the bold attribution.
            await tester.typeImeText("er");

            // Ensure the bold attribution was applied to the inserted text.
            expect(doc, equalsMarkdown("A **bolder** text"));
          });

          // Text color is a stand-in for any type-based attribution, e.g.,
          // background color.
          testWidgetsOnAllPlatforms("text color", (tester) async {
            final testContext = await tester //
                .createDocument()
                .withCustomContent(
                  MutableDocument(
                    nodes: [
                      ParagraphNode(
                        id: '1',
                        text: AttributedText(
                          'Color text',
                          AttributedSpans(
                            attributions: [
                              const SpanMarker(
                                attribution: ColorAttribution(Colors.orange),
                                offset: 0,
                                markerType: SpanMarkerType.start,
                              ),
                              const SpanMarker(
                                attribution: ColorAttribution(Colors.orange),
                                offset: 4,
                                markerType: SpanMarkerType.end,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                .pump();

            final document = testContext.document;

            // Place the caret at "Color|".
            await tester.placeCaretInParagraph(document.first.id, 5);

            // Type text that should expand the color attribution.
            await tester.typeImeText("s");

            // Ensure the color attribution was applied to the inserted text.
            final text = SuperEditorInspector.findTextInComponent(document.first.id);
            expect(text.toPlainText(), "Colors text");
            expect(
              text.spans,
              AttributedSpans(attributions: [
                const SpanMarker(
                  attribution: ColorAttribution(Colors.orange),
                  offset: 0,
                  markerType: SpanMarkerType.start,
                ),
                const SpanMarker(
                  attribution: ColorAttribution(Colors.orange),
                  offset: 5,
                  markerType: SpanMarkerType.end,
                ),
              ]),
            );
          });
        });

        group("by deleting characters and typing again >", () {
          // Bold is a stand-in for any value-based attribution extension, e.g.,
          // italics, underline, strikethrough.
          testWidgetsOnAllPlatforms("bold", (tester) async {
            await tester //
                .createDocument()
                .fromMarkdown("A **bold** text")
                .withInputSource(TextInputSource.ime)
                .pump();

            final doc = SuperEditorInspector.findDocument()!;

            // Place the caret at " text|".
            await tester.placeCaretInParagraph(doc.first.id, 11);

            // Delete all the back to "bold|".
            await tester.pressBackspace();
            await tester.pressBackspace();
            await tester.pressBackspace();
            await tester.pressBackspace();
            await tester.pressBackspace();

            // Type text that should expand the bold attribution.
            await tester.typeImeText("er");

            // Ensure the bold attribution was applied to the inserted text.
            expect(doc, equalsMarkdown("A **bolder**"));
          });

          // Text color is a stand-in for any type-based attribution, e.g.,
          // background color.
          testWidgetsOnAllPlatforms("text color", (tester) async {
            final testContext = await tester //
                .createDocument()
                .withCustomContent(
                  MutableDocument(
                    nodes: [
                      ParagraphNode(
                        id: '1',
                        text: AttributedText(
                          'Color text',
                          AttributedSpans(
                            attributions: [
                              const SpanMarker(
                                attribution: ColorAttribution(Colors.orange),
                                offset: 0,
                                markerType: SpanMarkerType.start,
                              ),
                              const SpanMarker(
                                attribution: ColorAttribution(Colors.orange),
                                offset: 4,
                                markerType: SpanMarkerType.end,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                .pump();

            final document = testContext.document;

            // Place the caret at " text|".
            await tester.placeCaretInParagraph(document.first.id, 10);

            // Delete all the back to "Color|".
            await tester.pressBackspace();
            await tester.pressBackspace();
            await tester.pressBackspace();
            await tester.pressBackspace();
            await tester.pressBackspace();

            // Type at a character that should expand the color attribution.
            await tester.typeImeText("s");

            // Ensure the color attribution was applied to the inserted text.
            final text = SuperEditorInspector.findTextInComponent(document.first.id);
            expect(text.toPlainText(), "Colors");
            expect(
              text.spans,
              AttributedSpans(attributions: [
                const SpanMarker(
                  attribution: ColorAttribution(Colors.orange),
                  offset: 0,
                  markerType: SpanMarkerType.start,
                ),
                const SpanMarker(
                  attribution: ColorAttribution(Colors.orange),
                  offset: 5,
                  markerType: SpanMarkerType.end,
                ),
              ]),
            );
          });
        });
      });

      group("when selecting by tapping", () {
        testWidgetsOnAllPlatforms("and typing at the end of the attributed text", (tester) async {
          await tester //
              .createDocument()
              .fromMarkdown("A **bold** text")
              .withInputSource(TextInputSource.ime)
              .pump();

          final document = SuperEditorInspector.findDocument()!;

          // Place the caret at "bold|".
          await tester.placeCaretInParagraph(document.first.id, 6);

          // Type at an offset that should expand the bold attribution.
          await tester.typeImeText("er");

          // Place the caret at "text|".
          await tester.placeCaretInParagraph(document.first.id, 13);

          // Type at an offset that shouldn't expand any attributions.
          await tester.typeImeText(".");

          // Ensure the bold attribution was applied to the inserted text.
          expect(document, equalsMarkdown("A **bolder** text."));
        });

        testWidgetsOnAllPlatforms("and typing at the middle of the attributed text", (tester) async {
          await tester //
              .createDocument()
              .fromMarkdown("A **bld** text")
              .withInputSource(TextInputSource.ime)
              .pump();

          final document = SuperEditorInspector.findDocument()!;

          // Place the caret at b|ld.
          await tester.placeCaretInParagraph(document.first.id, 3);

          // Type at an offset that should expand the bold attribution.
          await tester.typeImeText("o");

          // Place the caret at A|.
          await tester.placeCaretInParagraph(document.first.id, 1);

          // Type at an offset that shouldn't expand any attributions.
          await tester.typeImeText("nother");

          // Ensure the bold attribution was applied to the inserted text.
          expect(document, equalsMarkdown("Another **bold** text"));
        });

        testWidgetsOnAllPlatforms("and typing at the middle of a link", (tester) async {
          await tester //
              .createDocument()
              .fromMarkdown("[This is a link](https://google.com) to google")
              .withInputSource(TextInputSource.ime)
              .pump();

          final document = SuperEditorInspector.findDocument()!;

          // Place the caret at This is a|.
          await tester.placeCaretInParagraph(document.first.id, 9);

          // Type at an offset that should expand the link attribution.
          await tester.typeImeText("nother");

          // Place the caret at google|.
          await tester.placeCaretInParagraph(document.first.id, 30);

          // Type at an offset that shouldn't expand any attributions.
          await tester.typeImeText(".");

          // Ensure the link attribution was applied to the inserted text.
          expect(document, equalsMarkdown("[This is another link](https://google.com) to google."));
        });
      });

      group("when selecting by the keyboard", () {
        testWidgetsOnAllPlatforms("and typing at the end of the attributed text", (tester) async {
          await tester //
              .createDocument()
              .fromMarkdown("A **bold** text")
              .withInputSource(TextInputSource.ime)
              .pump();

          final document = SuperEditorInspector.findDocument()!;

          // Place the caret at |text.
          await tester.placeCaretInParagraph(document.first.id, 7);

          // Press left arrow to place the caret at bold|.
          await tester.pressLeftArrow();

          // Type at an offset that should expand the bold attribution.
          await tester.typeImeText("er");

          // Press right arrow to place the caret at |text.
          await tester.pressRightArrow();

          // Type at an offset that shouldn't expand any attributions.
          await tester.typeImeText("new ");

          // Ensure the bold attribution was applied to the inserted text.
          expect(document, equalsMarkdown("A **bolder** new text"));
        });

        testWidgetsOnAllPlatforms("and typing at the middle of the attributed text", (tester) async {
          await tester //
              .createDocument()
              .fromMarkdown("A **bld** text")
              .withInputSource(TextInputSource.ime)
              .pump();

          final document = SuperEditorInspector.findDocument()!;

          // Place the caret at A|.
          await tester.placeCaretInParagraph(document.first.id, 1);

          // Press right arrow twice to place the caret at b|ld.
          await tester.pressRightArrow();
          await tester.pressRightArrow();

          // Type at an offset that should expand the bold attribution.
          await tester.typeImeText("o");

          // Pres right arrow three times to place the caret at bold |text.
          await tester.pressRightArrow();
          await tester.pressRightArrow();
          await tester.pressRightArrow();

          // Type at an offset that shouldn't expand any attributions.
          await tester.typeImeText("new ");

          // Ensure the bold attribution was applied to the inserted text.
          expect(document, equalsMarkdown("A **bold** new text"));
        });

        testWidgetsOnAllPlatforms("and typing at the middle of a link", (tester) async {
          await tester //
              .createDocument()
              .fromMarkdown("[This is a link](https://google.com) to google")
              .withInputSource(TextInputSource.ime)
              .pump();

          final document = SuperEditorInspector.findDocument()!;

          // Place the caret at |to google.
          await tester.placeCaretInParagraph(document.first.id, 15);

          // Press left arrow twice to place caret at lin|k.
          await tester.pressLeftArrow();
          await tester.pressLeftArrow();

          // Typing at this offset should expand the link attribution.
          await tester.typeImeText("n");

          // Press right arrow twice to place caret at |to google.
          await tester.pressRightArrow();
          await tester.pressRightArrow();

          // Typing at this offset shouldn't expand any attributions.
          await tester.typeImeText("pointing ");

          // Ensure the link attribution was applied to the inserted text.
          expect(document, equalsMarkdown("[This is a linnk](https://google.com) pointing to google"));
        });
      });

      group("when collapsing the selection", () {
        testWidgetsOnMac("by keyboard and typing at the end of the attributed text", (tester) async {
          await tester //
              .createDocument()
              .fromMarkdown("A bold text")
              .pump();

          final doc = SuperEditorInspector.findDocument()!;

          // Double tap to select the word "bold".
          await tester.doubleTapInParagraph(doc.first.id, 4);

          // Press command + b to apply bold attribution to the selected text.
          await tester.pressCmdB();

          // Press right arrow to place the caret at the end of the word "bold".
          await tester.pressRightArrow();

          // Type "er" so "bold" becomes "bolder".
          await tester.typeImeText("er");

          // Ensure the bold attribution was applied to the inserted text.
          expect(doc, equalsMarkdown("A **bolder** text"));
        });

        testWidgetsOnMac("by tapping and typing at the end of the attributed text", (tester) async {
          await tester //
              .createDocument()
              .fromMarkdown("A bold text")
              .pump();

          final doc = SuperEditorInspector.findDocument()!;

          // Double tap to select the word "bold".
          await tester.doubleTapInParagraph(doc.first.id, 4);

          // Press command + b to apply bold attribution to the selected text.
          await tester.pressCmdB();

          // Place the caret at "bold|".
          await tester.placeCaretInParagraph(doc.first.id, 6);

          // Type "er" so "bold" becomes "bolder".
          await tester.typeImeText("er");

          // Ensure the bold attribution was applied to the inserted text.
          expect(doc, equalsMarkdown("A **bolder** text"));
        });
      });

      group("when a single node is selected", () {
        testWidgetsOnAllPlatforms("toggles attribution throughout a node", (tester) async {
          final context = await tester //
              .createDocument()
              .withCustomContent(
                singleParagraphDocShortText(),
              )
              .pump();

          final editor = context.editor;
          final document = SuperEditorInspector.findDocument()!;

          // Ensure markers are empty.
          expect(
            SuperEditorInspector.findTextInComponent("1").spans.markers,
            isEmpty,
          );

          var firstNode = document.getNodeById("1")!.asTextNode;
          editor.toggleAttributionsForDocumentSelection(
            firstNode.selectionBetween(0, firstNode.text.length),
            {boldAttribution},
          );

          // Ensure attribution was applied throughout the selection.
          expect(
            document,
            equalsMarkdown(
              "**This is the first node in a document.**",
            ),
          );

          firstNode = document.getNodeById("1")!.asTextNode;
          editor.toggleAttributionsForDocumentSelection(
            firstNode.selectionBetween(0, firstNode.text.length),
            {boldAttribution},
          );

          // Ensure bold attribution was removed from the selection.
          expect(
            SuperEditorInspector.findTextInComponent("1").spans.markers,
            isEmpty,
          );
        });

        testWidgetsOnAllPlatforms("toggles attribution on a partial node selection", (tester) async {
          final context = await tester //
              .createDocument()
              .withCustomContent(
                singleParagraphDocShortText(),
              )
              .pump();

          final editor = context.editor;
          final document = SuperEditorInspector.findDocument()!;

          var firstNode = document.getNodeById("1")! as TextNode;

          // Ensure markers are empty.
          expect(
            firstNode.text.spans.markers,
            isEmpty,
          );

          editor.toggleAttributionsForDocumentSelection(
            firstNode.selectionBetween(0, 17),
            {boldAttribution},
          );

          // Ensure attribution was applied to the selection.
          expect(
            document,
            equalsMarkdown(
              "**This is the first** node in a document.",
            ),
          );

          editor.toggleAttributionsForDocumentSelection(
            firstNode.selectionBetween(0, 17),
            {boldAttribution},
          );

          // Ensure bold attribution was removed from the selection.
          expect(
            document.getNodeById("1")!.asTextNode.text.spans.markers,
            isEmpty,
          );
        });

        testWidgetsOnAllPlatforms("toggles an attribution within a sub-range of an existing same attribution",
            (tester) async {
          final context = await tester //
              .createDocument()
              .withCustomContent(
                singleParagraphDocAllBold(),
              )
              .pump();

          final editor = context.editor;
          final document = SuperEditorInspector.findDocument()!;

          // Ensure bold attribution is present.
          expect(
            document,
            equalsMarkdown(
              "**This is the first node in a document.**",
            ),
          );

          var firstNode = document.getNodeById("1")!.asTextNode;

          editor.toggleAttributionsForDocumentSelection(
            firstNode.selectionBetween(0, 17),
            {boldAttribution},
          );

          // Ensure bold attribution is removed from the selection.
          expect(
            document,
            equalsMarkdown(
              "This is the first** node in a document.**",
            ),
          );

          firstNode = document.getNodeById("1")!.asTextNode;
          editor.toggleAttributionsForDocumentSelection(
            firstNode.selectionBetween(0, 17),
            {boldAttribution},
          );

          // Ensure bold attribution is applied throughout the node.
          expect(
            document,
            equalsMarkdown(
              "**This is the first**** node in a document.**",
            ),
          );
        });

        testWidgetsOnAllPlatforms("toggles a different attribution within a sub-range of another existing attribution",
            (tester) async {
          final context = await tester //
              .createDocument()
              .withCustomContent(
                singleParagraphDocAllBold(),
              )
              .pump();

          final editor = context.editor;
          final document = SuperEditorInspector.findDocument()!;

          // Ensure bold attribution is present.
          expect(
            document,
            equalsMarkdown(
              "**This is the first node in a document.**",
            ),
          );

          var firstNode = document.getNodeById("1")!.asTextNode;

          editor.toggleAttributionsForDocumentSelection(
            firstNode.selectionBetween(0, 17),
            {italicsAttribution},
          );

          // Ensure italic attribution is applied to the selection.
          expect(
            document,
            equalsMarkdown(
              "***This is the first* node in a document.**",
            ),
          );

          firstNode = document.getNodeById("1")!.asTextNode;
          editor.toggleAttributionsForDocumentSelection(
            firstNode.selectionBetween(0, 17),
            {italicsAttribution},
          );

          // Ensure bold attribution is applied throughout the node.
          expect(
            document,
            equalsMarkdown(
              "**This is the first node in a document.**",
            ),
          );
        });

        testWidgetsOnAllPlatforms("toggles multiple attributions throughout a node", (tester) async {
          final context = await tester //
              .createDocument()
              .withCustomContent(
                singleParagraphDocShortText(),
              )
              .pump();

          final editor = context.editor;
          final document = SuperEditorInspector.findDocument()!;

          var firstNode = document.getNodeById("1")!.asTextNode;

          // Ensure markers are empty.
          expect(
            document.getNodeById("1")!.asTextNode.text.spans.markers,
            isEmpty,
          );

          editor.toggleAttributionsForDocumentSelection(
            firstNode.selectionBetween(0, firstNode.text.length),
            {italicsAttribution, boldAttribution},
          );

          // Ensure both bold and italic attributions were applied throughout the node.
          expect(
            document,
            equalsMarkdown(
              "***This is the first node in a document.***",
            ),
          );

          editor.toggleAttributionsForDocumentSelection(
            firstNode.selectionBetween(0, firstNode.text.length),
            {boldAttribution, italicsAttribution},
          );

          // Ensure both bold and italic attributions are removed from the node.
          expect(
            document.getNodeById("1")!.asTextNode.text.spans.markers,
            isEmpty,
          );
        });
      });

      group("when multiple nodes are selected", () {
        testWidgetsOnAllPlatforms("toggles attribution throughout multiple nodes", (tester) async {
          final context = await tester //
              .createDocument()
              .withCustomContent(
                twoParagraphDoc(),
              )
              .pump();

          final editor = context.editor;
          final document = SuperEditorInspector.findDocument()!;

          // Ensure markers are empty for both nodes.
          expect(
            document.getNodeById("1")!.asTextNode.text.spans.markers.isEmpty &&
                document.getNodeById("2")!.asTextNode.text.spans.markers.isEmpty,
            true,
          );

          editor.toggleAttributionsForDocumentSelection(
            DocumentSelection(
              base: document.getNodeById("1")!.beginningDocumentPosition,
              extent: document.getNodeById("2")!.endDocumentPosition,
            ),
            {boldAttribution},
          );

          // Ensure bold attribution is applied throughout both nodes.
          expect(
            document,
            equalsMarkdown(
              "**This is the first node in a document.**\n\n**This is the second node in a document.**",
            ),
          );

          editor.toggleAttributionsForDocumentSelection(
            DocumentSelection(
              base: document.getNodeById("1")!.beginningDocumentPosition,
              extent: document.getNodeById("2")!.endDocumentPosition,
            ),
            {boldAttribution},
          );

          // Ensure bold attribution was removed from both nodes.
          expect(
            document.getNodeById("1")!.asTextNode.text.spans.markers.isEmpty &&
                document.getNodeById("2")!.asTextNode.text.spans.markers.isEmpty,
            true,
          );
        });

        testWidgetsOnAllPlatforms(
            "toggles an attribution across nodes with the attribution applied throughout first node", (tester) async {
          final context = await tester //
              .createDocument()
              .withCustomContent(
                _paragraphFullBoldThenParagraph(),
              )
              .pump();

          final editor = context.editor;
          final document = SuperEditorInspector.findDocument()!;

          // Ensure bold attribution is applied throughout the first node.
          expect(
            document,
            equalsMarkdown(
              "**This is the first node in a document.**\n\nThis is the second node in a document.",
            ),
          );

          editor.execute([
            ToggleTextAttributionsRequest(
              documentRange: DocumentSelection(
                base: document.getNodeById("1")!.beginningDocumentPosition,
                extent: document.getNodeById("2")!.endDocumentPosition,
              ),
              attributions: {boldAttribution},
            )
          ]);

          // Ensure bold attribution is applied throughout both nodes.
          //
          // The toggled attribution already existed across the selection. In
          // such cases, the attribution is applied throughout the selection without removing it from
          // any of the node selections that already have it.
          expect(
            document,
            equalsMarkdown(
              "**This is the first node in a document.**\n\n**This is the second node in a document.**",
            ),
          );

          editor.toggleAttributionsForDocumentSelection(
            DocumentSelection(
              base: document.getNodeById("1")!.beginningDocumentPosition,
              extent: document.getNodeById("2")!.endDocumentPosition,
            ),
            {boldAttribution},
          );

          // Ensure bold attribution was removed from both nodes.
          expect(
            document.getNodeById("1")!.asTextNode.text.spans.markers.isEmpty,
            true,
          );
          expect(
            document.getNodeById("2")!.asTextNode.text.spans.markers.isEmpty,
            true,
          );
        });

        testWidgetsOnAllPlatforms(
            "toggles an attribution across nodes with the attribution applied partially within first node",
            (tester) async {
          final context = await tester //
              .createDocument()
              .withCustomContent(
                _paragraphPartiallyBoldThenParagraph(),
              )
              .pump();

          final editor = context.editor;
          final document = SuperEditorInspector.findDocument()!;

          // Ensure bold attribution is applied partially to the first node.
          expect(
            document,
            equalsMarkdown(
              "**This is the first** node in a document.\n\nThis is the second node in a document.",
            ),
          );

          editor.toggleAttributionsForDocumentSelection(
            DocumentSelection(
              base: document.getNodeById("1")!.beginningDocumentPosition,
              extent: document.getNodeById("2")!.endDocumentPosition,
            ),
            {boldAttribution},
          );

          // Ensure bold attribution is applied throughout the both nodes.
          //
          // The toggled attribution already existed across the selection.In
          // such cases, the attribution is applied throughout the selection without removing it from
          // any of the node selections that already have it.
          expect(
            document,
            equalsMarkdown(
              "**This is the first node in a document.**\n\n**This is the second node in a document.**",
            ),
          );

          editor.toggleAttributionsForDocumentSelection(
            DocumentSelection(
              base: document.getNodeById("1")!.beginningDocumentPosition,
              extent: document.getNodeById("2")!.endDocumentPosition,
            ),
            {boldAttribution},
          );

          // Ensure bold attribution was removed from both nodes.
          expect(
            document.getNodeById("1")!.asTextNode.text.spans.markers.isEmpty,
            true,
          );
          expect(
            document.getNodeById("2")!.asTextNode.text.spans.markers.isEmpty,
            true,
          );
        });

        testWidgetsOnAllPlatforms(
            "toggles an attribution when selection spans multiple nodes and starts at the end of the first selected node",
            (tester) async {
          // Test situations where the selection starts after the last character of the first selected node. See #1948
          // for more information.

          final context = await tester //
              .createDocument()
              .fromMarkdown("First node\n\nSecond node")
              .pump();

          final editor = context.editor;
          final document = context.document;

          // Apply the bold attribution, starting after the last character of the first node.
          editor.toggleAttributionsForDocumentSelection(
            DocumentSelection(
              base: document.getNodeAt(0)!.endDocumentPosition,
              extent: document.getNodeAt(1)!.endDocumentPosition,
            ),
            {boldAttribution},
          );

          // Ensure bold attribution is applied only to the second node. Since the selection starts at the
          // end of the first node, there's no text there to apply the attribution to.
          expect(
            document,
            equalsMarkdown(
              "First node\n\n**Second node**",
            ),
          );

          // Remove the bold attribution, starting after the last character of the first node.
          editor.toggleAttributionsForDocumentSelection(
            DocumentSelection(
              base: document.getNodeAt(0)!.endDocumentPosition,
              extent: document.getNodeAt(1)!.endDocumentPosition,
            ),
            {boldAttribution},
          );

          // Ensure bold attribution was removed.
          expect(document.getNodeAt(1)!.asTextNode.text.spans.markers.isEmpty, true);
        });

        testWidgetsOnAllPlatforms(
            "toggles an attribution when selection spans multiple nodes and ends at the beginning of the last selected node",
            (tester) async {
          // Test situations where the selection ends before the first character of the last selected node. See #1948
          // for more information.

          final context = await tester //
              .createDocument()
              .fromMarkdown("First node\n\nSecond node")
              .pump();

          final editor = context.editor;
          final document = context.document;

          // Apply the bold attribution, with a selection that start at the beginning of the first node and ends
          // before the first character of the second node.
          editor.toggleAttributionsForDocumentSelection(
            DocumentSelection(
              base: document.getNodeAt(0)!.beginningDocumentPosition,
              extent: document.getNodeAt(1)!.beginningDocumentPosition,
            ),
            {boldAttribution},
          );

          // Ensure bold attribution is applied only to the first node. Since the selection ends before the first
          // character of the second node, there's no text there to apply the attribution to.
          expect(
            document,
            equalsMarkdown(
              "**First node**\n\nSecond node",
            ),
          );

          // Remove the bold attribution, with a selection that start at the beginning of the first node and ends
          // before the first character of the second node.
          editor.toggleAttributionsForDocumentSelection(
            DocumentSelection(
              base: document.getNodeAt(0)!.beginningDocumentPosition,
              extent: document.getNodeAt(1)!.beginningDocumentPosition,
            ),
            {boldAttribution},
          );

          // Ensure bold attribution was removed.
          final secondNode = document.getNodeAt(1)!.asTextNode;
          expect(secondNode.text.spans.markers.isEmpty, true);
        });

        testWidgetsOnAllPlatforms(
            "toggles an attribution across nodes with the attribution applied throughout and partially within first and second node respectively",
            (tester) async {
          final TestDocumentContext context = await tester //
              .createDocument()
              .withCustomContent(
                _paragraphFullyBoldThenParagraphPartiallyBold(),
              )
              .pump();

          final Editor editor = context.editor;
          final document = SuperEditorInspector.findDocument()!;

          // Ensure bold attribution is applied partially to first node and
          // throughout the second node.
          expect(
            document,
            equalsMarkdown(
              "**This is the first** node in a document.\n\n**This is the second node in a document.**",
            ),
          );

          editor.toggleAttributionsForDocumentSelection(
            DocumentSelection(
              base: document.getNodeById("1")!.beginningDocumentPosition,
              extent: document.getNodeById("2")!.asTextNode.endDocumentPosition,
            ),
            {boldAttribution},
          );

          // Ensure bold attribution is applied throughout the both nodes.
          //
          // The toggled attribution already existed across the selection. In
          // such cases, the attribution is applied throughout the selection without removing it from
          // any of the node selections that already have it.
          expect(
            document,
            equalsMarkdown(
              "**This is the first node in a document.**\n\n**This is the second node in a document.**",
            ),
          );

          editor.toggleAttributionsForDocumentSelection(
            DocumentSelection(
              base: document.getNodeById("1")!.asTextNode.beginningDocumentPosition,
              extent: document.getNodeById("2")!.asTextNode.endDocumentPosition,
            ),
            {boldAttribution},
          );

          // Ensure bold attribution was removed from both nodes.
          expect(
            document.getNodeById("1")!.asTextNode.text.spans.markers.isEmpty &&
                document.getNodeById("2")!.asTextNode.text.spans.markers.isEmpty,
            true,
          );
        });

        testWidgetsOnAllPlatforms(
            "toggles an attribution across nodes with the attribution applied partially within all nodes",
            (tester) async {
          final TestDocumentContext context = await tester //
              .createDocument()
              .withCustomContent(
                _paragraphPartiallyBoldThenParagraphPartiallyBold(),
              )
              .pump();

          final Editor editor = context.editor;
          final document = SuperEditorInspector.findDocument()!;

          // Ensure bold attribution is applied partially across both nodes.
          expect(
            document,
            equalsMarkdown(
              "**This is the first** node in a document.\n\n**This is the second** node in a document.",
            ),
          );

          editor.toggleAttributionsForDocumentSelection(
            DocumentSelection(
              base: document.getNodeById("1")!.beginningDocumentPosition,
              extent: document.getNodeById("2")!.endDocumentPosition,
            ),
            {boldAttribution},
          );

          // Ensure bold attribution is applied throughout the both nodes.
          //
          // The toggled attribution already existed across the selection. In
          // such cases, the attribution is applied throughout the selection without removing it from
          // any of the node selections that already have it.
          expect(
            document,
            equalsMarkdown(
              "**This is the first node in a document.**\n\n**This is the second node in a document.**",
            ),
          );

          editor.toggleAttributionsForDocumentSelection(
            DocumentSelection(
              base: document.getNodeById("1")!.beginningDocumentPosition,
              extent: document.getNodeById("2")!.endDocumentPosition,
            ),
            {boldAttribution},
          );

          // Ensure bold attribution was removed from both nodes.
          expect(
            document.getNodeById("1")!.asTextNode.text.spans.markers.isEmpty &&
                document.getNodeById("2")!.asTextNode.text.spans.markers.isEmpty,
            true,
          );
        });

        testWidgetsOnAllPlatforms(
            "toggles a different attribution across nodes with an existing attribution applied throughout them",
            (tester) async {
          final TestDocumentContext context = await tester //
              .createDocument()
              .withCustomContent(
                twoParagraphDocAllBold(),
              )
              .pump();

          final Editor editor = context.editor;
          final document = SuperEditorInspector.findDocument()!;

          // Ensure bold attribution is applied throughout both nodes.
          expect(
            document,
            equalsMarkdown(
              "**This is the first node in a document.**\n\n**This is the second node in a document.**",
            ),
          );

          editor.toggleAttributionsForDocumentSelection(
            DocumentSelection(
              base: document.getNodeById("1")!.beginningDocumentPosition,
              extent: document.getNodeById("2")!.endDocumentPosition,
            ),
            {italicsAttribution},
          );

          // Ensure both bold and italic attributions were applied throughout the selection.
          expect(
            document,
            equalsMarkdown(
              "***This is the first node in a document.***\n\n***This is the second node in a document.***",
            ),
          );

          editor.toggleAttributionsForDocumentSelection(
            DocumentSelection(
              base: document.getNodeById("1")!.beginningDocumentPosition,
              extent: document.getNodeById("2")!.endDocumentPosition,
            ),
            {italicsAttribution},
          );

          // Ensure italic attribution was removed from both nodes.
          expect(
            document,
            equalsMarkdown(
              "**This is the first node in a document.**\n\n**This is the second node in a document.**",
            ),
          );
        });

        testWidgetsOnAllPlatforms(
            "toggles a different attribution partially across nodes with an existing attribution applied throughout them",
            (tester) async {
          final TestDocumentContext context = await tester //
              .createDocument()
              .withCustomContent(
                twoParagraphDocAllBold(),
              )
              .pump();

          final editor = context.editor;
          final document = SuperEditorInspector.findDocument()!;

          // Ensure bold attribution is applied throughout the selection.
          expect(
            document,
            equalsMarkdown(
              "**This is the first node in a document.**\n\n**This is the second node in a document.**",
            ),
          );

          editor.toggleAttributionsForDocumentSelection(
            DocumentSelection(
              base: document.getNodeById("1")!.beginningDocumentPosition,
              extent: document.getNodeById("2")!.asTextNode.positionAt(18),
            ),
            {italicsAttribution},
          );

          // Ensure both bold and italic attributions were applied throughout
          // the selection.
          expect(
            document,
            equalsMarkdown(
              "***This is the first node in a document.***\n\n***This is the second* node in a document.**",
            ),
          );

          editor.toggleAttributionsForDocumentSelection(
            DocumentSelection(
              base: document.getNodeById("1")!.beginningDocumentPosition,
              extent: document.getNodeById("2")!.asTextNode.positionAt(18),
            ),
            {italicsAttribution},
          );

          // Ensure italic attribution was removed from the selection while keeping the bold
          // attribution.
          expect(
            document,
            equalsMarkdown(
              "**This is the first node in a document.**\n\n**This is the second node in a document.**",
            ),
          );
        });

        testWidgetsOnAllPlatforms("toggles multiple attributions throughout multiple nodes", (tester) async {
          final TestDocumentContext context = await tester //
              .createDocument()
              .withCustomContent(
                twoParagraphDoc(),
              )
              .pump();

          final editor = context.editor;
          final document = SuperEditorInspector.findDocument()!;

          // Ensure markers are empty for both nodes.
          expect(
            document.getNodeById("1")!.asTextNode.text.spans.markers.isEmpty &&
                document.getNodeById("2")!.asTextNode.text.spans.markers.isEmpty,
            true,
          );

          editor.toggleAttributionsForDocumentSelection(
            DocumentSelection(
              base: document.getNodeById("1")!.beginningDocumentPosition,
              extent: document.getNodeById("2")!.endDocumentPosition,
            ),
            {
              italicsAttribution,
              boldAttribution,
            },
          );

          // Ensure both bold and italic attributions were applied throughout the selection.
          expect(
            document,
            equalsMarkdown(
              "***This is the first node in a document.***\n\n***This is the second node in a document.***",
            ),
          );

          // Toggle bold attribution for both nodes.
          editor.toggleAttributionsForDocumentSelection(
            DocumentSelection(
              base: document.getNodeById("1")!.beginningDocumentPosition,
              extent: document.getNodeById("2")!.endDocumentPosition,
            ),
            {boldAttribution, italicsAttribution},
          );

          // Ensure markers are empty for both nodes.
          expect(
            document.getNodeById("1")!.asTextNode.text.spans.markers.isEmpty &&
                document.getNodeById("2")!.asTextNode.text.spans.markers.isEmpty,
            true,
          );
        });

        testWidgetsOnAllPlatforms(
            "toggles attribution for a selection going halfway from first node and halfway within second node",
            (tester) async {
          final TestDocumentContext context = await tester //
              .createDocument()
              .withCustomContent(
                twoParagraphDoc(),
              )
              .pump();

          final editor = context.editor;
          final document = SuperEditorInspector.findDocument()!;

          // Ensure markers are empty for both nodes.
          expect(
            document.getNodeById("1")!.asTextNode.text.spans.markers.isEmpty &&
                document.getNodeById("2")!.asTextNode.text.spans.markers.isEmpty,
            true,
          );

          editor.toggleAttributionsForDocumentSelection(
            DocumentSelection(
              base: document.getNodeById("1")!.asTextNode.positionAt(18),
              extent: document.getNodeById("2")!.asTextNode.positionAt(18),
            ),
            {boldAttribution},
          );

          // Ensure bold attribution was applied.
          expect(
            document,
            equalsMarkdown(
              "This is the first **node in a document.**\n\n**This is the second** node in a document.",
            ),
          );

          editor.toggleAttributionsForDocumentSelection(
            DocumentSelection(
              base: document.getNodeById("1")!.asTextNode.positionAt(18),
              extent: document.getNodeById("2")!.asTextNode.positionAt(18),
            ),
            {boldAttribution},
          );

          // Ensure markers are empty for both nodes.
          expect(
            document.getNodeById("1")!.asTextNode.text.spans.markers.isEmpty &&
                document.getNodeById("2")!.asTextNode.text.spans.markers.isEmpty,
            true,
          );
        });

        testWidgetsOnAllPlatforms(
            "toggles attribution for a selection going halfway in first node till the halfway into the third node",
            (tester) async {
          final TestDocumentContext context = await tester //
              .createDocument()
              .withCustomContent(
                threeParagraphDoc(),
              )
              .pump();

          final editor = context.editor;
          final document = SuperEditorInspector.findDocument()!;

          // Ensure no attributions are present.
          expect(
            document,
            equalsMarkdown(
              "This is the first node in a document.\n\nThis is the second node in a document.\n\nThis is the third node in a document.",
            ),
          );

          editor.toggleAttributionsForDocumentSelection(
            DocumentSelection(
              base: document.getNodeById("1")!.asTextNode.positionAt(18),
              extent: document.getNodeById("3")!.asTextNode.positionAt(18),
            ),
            {boldAttribution},
          );

          // Ensure bold attributions were applied.
          expect(
            document,
            equalsMarkdown(
              "This is the first **node in a document.**\n\n**This is the second node in a document.**\n\n**This is the third **node in a document.",
            ),
          );

          editor.toggleAttributionsForDocumentSelection(
            DocumentSelection(
              base: document.getNodeById("1")!.asTextNode.positionAt(18),
              extent: document.getNodeById("3")!.asTextNode.positionAt(18),
            ),
            {boldAttribution},
          );

          // Ensure no attributions are present.
          expect(
            document,
            equalsMarkdown(
              "This is the first node in a document.\n\nThis is the second node in a document.\n\nThis is the third node in a document.",
            ),
          );
        });
      });

      group("applies color attributions", () {
        testWidgetsOnAllPlatforms("to full text", (tester) async {
          await tester //
              .createDocument()
              .withCustomContent(
                singleParagraphFullColor(),
              )
              .pump();

          // Ensure the text is colored orange.
          expect(
            SuperEditorInspector.findRichTextInParagraph("1")
                .getSpanForPosition(
                  const TextPosition(offset: 0),
                )
                ?.style
                ?.color,
            Colors.orange,
          );
          expect(
            SuperEditorInspector.findRichTextInParagraph("1")
                .getSpanForPosition(
                  TextPosition(offset: SuperEditorInspector.findTextInComponent("1").length - 1),
                )
                ?.style
                ?.color,
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
            SuperEditorInspector.findRichTextInParagraph("1")
                .getSpanForPosition(const TextPosition(offset: 0))!
                .style!
                .color,
            Colors.black,
          );

          // Ensure the second span is colored orange.
          expect(
            SuperEditorInspector.findRichTextInParagraph("1")
                .getSpanForPosition(const TextPosition(offset: 5))!
                .style!
                .color,
            Colors.orange,
          );
        });
      });

      group("doesn't apply attributions", () {
        testWidgetsOnAllPlatforms("when typing before the start of the attributed text", (tester) async {
          await tester //
              .createDocument()
              .fromMarkdown("A **bold** text")
              .withInputSource(TextInputSource.ime)
              .pump();

          final document = SuperEditorInspector.findDocument()!;

          // Place the caret at |bold.
          await tester.placeCaretInParagraph(document.first.id, 2);

          // Type some letters.
          await tester.typeImeText("very ");

          // Ensure the bold attribution wasn't applied to the inserted text.
          expect(document, equalsMarkdown("A very **bold** text"));
        });
      });

      group("doesn't clear attributions", () {
        testWidgetsOnAllPlatforms("when changing the selection affinity", (tester) async {
          final context = await tester //
              .createDocument()
              .fromMarkdown("This text should be")
              .withInputSource(TextInputSource.ime)
              .pump();

          final document = context.findEditContext().document;
          final composer = context.findEditContext().composer;

          // Place the caret at the end of the paragraph.
          await tester.placeCaretInParagraph(document.first.id, 19);

          // Toggle the bold attribution.
          composer.preferences.toggleStyle(boldAttribution);
          await tester.pump();

          // Ensure we have an upstream selection.
          expect((composer.selection!.extent.nodePosition as TextNodePosition).affinity, TextAffinity.upstream);

          // Simulate the IME sending us a selection at the same offset
          // but with a different affinity.
          await tester.ime.sendDeltas(
            [
              const TextEditingDeltaNonTextUpdate(
                oldText: ". This text should be",
                selection: TextSelection.collapsed(offset: 21, affinity: TextAffinity.downstream),
                composing: TextRange.empty,
              ),
            ],
            getter: imeClientGetter,
          );

          // Type text at the end of the paragraph.
          await tester.typeImeText(" bold");

          // Ensure the bold attribution is applied.
          expect(document, equalsMarkdown("This text should be** bold**"));
        });
      });

      testWidgetsOnArbitraryDesktop(
          "and reports attribution change events when an attribution is added, removed, and toggled", (tester) async {
        final context = await tester //
            .createDocument()
            .withSingleParagraph()
            .pump();

        // Select the first word.
        await tester.doubleTapInParagraph("1", 1);

        // Listen for change events.
        final editor = context.editor;
        List<EditEvent>? changes;
        editor.addListener(FunctionalEditListener((List<EditEvent> changeList) {
          changes = changeList;
        }));

        // Apply bold attribution.
        await tester.pressCmdB();

        // Ensure that the change event includes the added attribution.
        expect(changes, isNotNull);
        expect(
          changes,
          [
            DocumentEdit(
              AttributionChangeEvent(
                nodeId: "1",
                change: AttributionChange.added,
                attributions: {boldAttribution},
                range: const SpanRange(0, 4),
              ),
            ),
          ],
        );

        // Expand the selection to include the second word.
        await tester.pressShiftAltRightArrow();

        // Toggle bold, which should add bold only to the second word.
        await tester.pressCmdB();

        // Ensure that the bold change is reported across the entire selected range.
        //
        // NOTE: There's an argument to be made that this change event should only
        //       include the range of text that was previously not bold, and now is
        //       bold. E.g., given the text "Lorem ipsum", because "Lorem" is already
        //       bold, the event should report " ipsum" as adding bold. I chose not to
        //       worry about that distinction because at the moment it doesn't seem that
        //       we need the distinction, and it would require more rework to achieve that
        //       distinction. If it's eventually needed, it would be reasonable to
        //       implement that approach, instead.
        expect(
          changes,
          [
            DocumentEdit(
              AttributionChangeEvent(
                nodeId: "1",
                change: AttributionChange.added,
                attributions: {boldAttribution},
                range: const SpanRange(0, 10),
              ),
            ),
          ],
        );

        // Remove the bold attribution by toggling bold again.
        await tester.pressCmdB();

        // Ensure that we received a removal change event.
        expect(
          changes,
          [
            DocumentEdit(
              AttributionChangeEvent(
                nodeId: "1",
                change: AttributionChange.removed,
                attributions: {boldAttribution},
                range: const SpanRange(0, 10),
              ),
            ),
          ],
        );
      });
    });

    testWidgetsOnArbitraryDesktop('overwrites spans with different colors', (tester) async {
      // Pump an editor with a single paragraph with blue color across the entire paragraph.
      final testContext = await tester //
          .createDocument()
          .withCustomContent(
            MutableDocument(
              nodes: [
                ParagraphNode(
                  id: '1',
                  text: AttributedText(
                    'blue orange pink',
                    _createAttributedSpansForAttribution(
                      attribution: const ColorAttribution(Colors.blue),
                      startOffset: 0,
                      endOffset: 15,
                    ),
                  ),
                )
              ],
            ),
          )
          .pump();

      // Apply orange color to the word "orange".
      testContext.editor.execute([
        AddTextAttributionsRequest(
          documentRange: _creatSingleNodeTextRange('1', 5, 11),
          attributions: {const ColorAttribution(Colors.orange)},
        ),
      ]);
      await tester.pump();

      // Apply pink color to the word "pink" by toggling the attribution.
      testContext.editor.execute([
        ToggleTextAttributionsRequest(
          documentRange: _creatSingleNodeTextRange('1', 11, 16),
          attributions: {const ColorAttribution(Colors.pink)},
        ),
      ]);
      await tester.pump();

      // Ensure the spans were overwritten.
      expect(
        SuperEditorInspector.findTextInComponent('1').spans,
        AttributedSpans(
          attributions: [
            ..._createSpanMarkersForAttribution(
              attribution: const ColorAttribution(Colors.blue),
              startOffset: 0,
              endOffset: 4,
            ),
            ..._createSpanMarkersForAttribution(
              attribution: const ColorAttribution(Colors.orange),
              startOffset: 5,
              endOffset: 10,
            ),
            ..._createSpanMarkersForAttribution(
              attribution: const ColorAttribution(Colors.pink),
              startOffset: 11,
              endOffset: 15,
            ),
          ],
        ),
      );
    });

    testWidgetsOnArbitraryDesktop('overwrites spans with different background colors', (tester) async {
      // Pump an editor with a single paragraph with blue background color across the entire paragraph.
      final testContext = await tester //
          .createDocument()
          .withCustomContent(
            MutableDocument(
              nodes: [
                ParagraphNode(
                  id: '1',
                  text: AttributedText(
                    'blue orange pink',
                    _createAttributedSpansForAttribution(
                      attribution: const BackgroundColorAttribution(Colors.blue),
                      startOffset: 0,
                      endOffset: 15,
                    ),
                  ),
                )
              ],
            ),
          )
          .pump();

      // Apply orange color to the word "orange".
      testContext.editor.execute([
        AddTextAttributionsRequest(
          documentRange: _creatSingleNodeTextRange('1', 5, 11),
          attributions: {const BackgroundColorAttribution(Colors.orange)},
        ),
      ]);
      await tester.pump();

      // Apply pink color to the word "pink" by toggling the attribution.
      testContext.editor.execute([
        ToggleTextAttributionsRequest(
          documentRange: _creatSingleNodeTextRange('1', 11, 16),
          attributions: {const BackgroundColorAttribution(Colors.pink)},
        ),
      ]);
      await tester.pump();

      // Ensure the spans were overwritten.
      expect(
        SuperEditorInspector.findTextInComponent('1').spans,
        AttributedSpans(
          attributions: [
            ..._createSpanMarkersForAttribution(
              attribution: const BackgroundColorAttribution(Colors.blue),
              startOffset: 0,
              endOffset: 4,
            ),
            ..._createSpanMarkersForAttribution(
              attribution: const BackgroundColorAttribution(Colors.orange),
              startOffset: 5,
              endOffset: 10,
            ),
            ..._createSpanMarkersForAttribution(
              attribution: const BackgroundColorAttribution(Colors.pink),
              startOffset: 11,
              endOffset: 15,
            ),
          ],
        ),
      );
    });

    testWidgetsOnArbitraryDesktop('overwrites spans with different font sizes', (tester) async {
      // Pump an editor with a single paragraph with 16px font size across the entire paragraph.
      final testContext = await tester //
          .createDocument()
          .withCustomContent(
            MutableDocument(
              nodes: [
                ParagraphNode(
                  id: '1',
                  text: AttributedText(
                    '16px 18px 14px',
                    _createAttributedSpansForAttribution(
                      attribution: const FontSizeAttribution(16),
                      startOffset: 0,
                      endOffset: 13,
                    ),
                  ),
                )
              ],
            ),
          )
          .pump();

      // Apply 18px font size to the text "18px".
      testContext.editor.execute([
        AddTextAttributionsRequest(
          documentRange: _creatSingleNodeTextRange('1', 5, 9),
          attributions: {const FontSizeAttribution(18)},
        ),
      ]);
      await tester.pump();

      // Apply 14px color to the text "14px" by toggling the attribution.
      testContext.editor.execute([
        ToggleTextAttributionsRequest(
          documentRange: _creatSingleNodeTextRange('1', 9, 14),
          attributions: {const FontSizeAttribution(14)},
        ),
      ]);
      await tester.pump();

      // Ensure the spans were overwritten.
      expect(
        SuperEditorInspector.findTextInComponent('1').spans,
        AttributedSpans(
          attributions: [
            ..._createSpanMarkersForAttribution(
              attribution: const FontSizeAttribution(16),
              startOffset: 0,
              endOffset: 4,
            ),
            ..._createSpanMarkersForAttribution(
              attribution: const FontSizeAttribution(18),
              startOffset: 5,
              endOffset: 8,
            ),
            ..._createSpanMarkersForAttribution(
              attribution: const FontSizeAttribution(14),
              startOffset: 9,
              endOffset: 13,
            ),
          ],
        ),
      );
    });

    testWidgetsOnArbitraryDesktop('adds and removes attributions with placeholders', (tester) async {
      // A test that locks down a fix for bug: https://github.com/superlistapp/super_editor/issues/2776
      // The problem was a behavior in the command that was incorrectly copying the `AttributedText`
      // when the `AttributedText` has placeholders.
      final testContext = await tester //
          .createDocument()
          .withCustomContent(
            MutableDocument(
              nodes: [
                ParagraphNode(
                  id: '1',
                  text: AttributedText(
                    'this [] orange [] that',
                    null,
                    {
                      6: 'first',
                      17: 'second',
                    },
                  ),
                )
              ],
            ),
          )
          .pump();

      // Apply orange color to the word "orange".
      testContext.editor.execute([
        AddTextAttributionsRequest(
          documentRange: _creatSingleNodeTextRange('1', 5, 11),
          attributions: {const ColorAttribution(Colors.orange)},
        ),
      ]);
      await tester.pump();

      // Ensure the plain text value didn't change, the attribution was applied, and the placeholders remain.
      expect(
        SuperEditorInspector.findTextInComponent('1').toPlainText(includePlaceholders: false),
        'this [] orange [] that',
      );

      expect(
        SuperEditorInspector.findTextInComponent('1').spans,
        AttributedSpans(
          attributions: [
            ..._createSpanMarkersForAttribution(
              attribution: const ColorAttribution(Colors.orange),
              startOffset: 5,
              endOffset: 10,
            ),
          ],
        ),
      );

      expect(
        SuperEditorInspector.findTextInComponent('1').placeholders,
        {
          6: 'first',
          17: 'second',
        },
      );

      // Now test the removal command by removing the attribution.
      testContext.editor.execute([
        RemoveTextAttributionsRequest(
          documentRange: _creatSingleNodeTextRange('1', 5, 11),
          attributions: {const ColorAttribution(Colors.orange)},
        ),
      ]);
      await tester.pump();

      // Ensure the plain text value didn't change, the attribution was removed, and the placeholders remain.
      expect(
        SuperEditorInspector.findTextInComponent('1').toPlainText(includePlaceholders: false),
        'this [] orange [] that',
      );

      expect(
        SuperEditorInspector.findTextInComponent('1').spans,
        AttributedSpans(),
      );

      expect(
        SuperEditorInspector.findTextInComponent('1').placeholders,
        {
          6: 'first',
          17: 'second',
        },
      );
    });
  });
}

MutableDocument _paragraphFullBoldThenParagraph() => MutableDocument(
      nodes: [
        ParagraphNode(
          id: "1",
          text: AttributedText(
            "This is the first node in a document.",
            _createAttributedSpansForAttribution(
              attribution: boldAttribution,
              startOffset: 0,
              endOffset: 36,
            ),
          ),
        ),
        ParagraphNode(
          id: "2",
          text: AttributedText(
            "This is the second node in a document.",
          ),
        ),
      ],
    );

MutableDocument _paragraphPartiallyBoldThenParagraph() => MutableDocument(
      nodes: [
        ParagraphNode(
          id: "1",
          text: AttributedText(
            "This is the first node in a document.",
            _createAttributedSpansForAttribution(
              attribution: boldAttribution,
              startOffset: 0,
              endOffset: 16,
            ),
          ),
        ),
        ParagraphNode(
          id: "2",
          text: AttributedText(
            "This is the second node in a document.",
          ),
        ),
      ],
    );

MutableDocument _paragraphFullyBoldThenParagraphPartiallyBold() => MutableDocument(
      nodes: [
        ParagraphNode(
          id: "1",
          text: AttributedText(
            "This is the first node in a document.",
            _createAttributedSpansForAttribution(
              attribution: boldAttribution,
              startOffset: 0,
              endOffset: 16,
            ),
          ),
        ),
        ParagraphNode(
          id: "2",
          text: AttributedText(
            "This is the second node in a document.",
            _createAttributedSpansForAttribution(
              attribution: boldAttribution,
              startOffset: 0,
              endOffset: 37,
            ),
          ),
        ),
      ],
    );

MutableDocument _paragraphPartiallyBoldThenParagraphPartiallyBold() => MutableDocument(
      nodes: [
        ParagraphNode(
          id: "1",
          text: AttributedText(
            "This is the first node in a document.",
            _createAttributedSpansForAttribution(
              attribution: boldAttribution,
              startOffset: 0,
              endOffset: 16,
            ),
          ),
        ),
        ParagraphNode(
          id: "2",
          text: AttributedText(
            "This is the second node in a document.",
            _createAttributedSpansForAttribution(
              attribution: boldAttribution,
              startOffset: 0,
              endOffset: 17,
            ),
          ),
        ),
      ],
    );

extension _GetDocumentPosition on DocumentNode {
  DocumentPosition get beginningDocumentPosition {
    return DocumentPosition(
      nodeId: id,
      nodePosition: beginningPosition,
    );
  }

  DocumentPosition get endDocumentPosition {
    return DocumentPosition(
      nodeId: id,
      nodePosition: endPosition,
    );
  }
}

extension _ToggleAttributions on Editor {
  /// Toggles given [attributions] for the [documentSelection].
  void toggleAttributionsForDocumentSelection(
    DocumentSelection documentSelection,
    Set<Attribution> attributions,
  ) {
    return execute([
      ToggleTextAttributionsRequest(
        documentRange: documentSelection,
        attributions: attributions,
      )
    ]);
  }
}

/// Creates an [AttributedSpans] for the [attribution] starting at [startOffset]
/// and ending at [endOffset].
AttributedSpans _createAttributedSpansForAttribution({
  required Attribution attribution,
  required int startOffset,
  required int endOffset,
}) {
  return AttributedSpans(
    attributions: [
      SpanMarker(
        attribution: attribution,
        offset: startOffset,
        markerType: SpanMarkerType.start,
      ),
      SpanMarker(
        attribution: attribution,
        offset: endOffset,
        markerType: SpanMarkerType.end,
      ),
    ],
  );
}

/// Creates start and end markers for the [attribution], starting at [startOffset]
/// and ending at [endOffset].
List<SpanMarker> _createSpanMarkersForAttribution({
  required Attribution attribution,
  required int startOffset,
  required int endOffset,
}) {
  return [
    SpanMarker(
      attribution: attribution,
      offset: startOffset,
      markerType: SpanMarkerType.start,
    ),
    SpanMarker(
      attribution: attribution,
      offset: endOffset,
      markerType: SpanMarkerType.end,
    ),
  ];
}

/// Creates a [DocumentRange] that starts at node [nodeId] at [start] and
/// ends at [nodeId] at [end].
DocumentRange _creatSingleNodeTextRange(String nodeId, int start, int end) {
  return DocumentRange(
    start: DocumentPosition(
      nodeId: nodeId,
      nodePosition: TextNodePosition(offset: start),
    ),
    end: DocumentPosition(
      nodeId: nodeId,
      nodePosition: TextNodePosition(offset: end),
    ),
  );
}
