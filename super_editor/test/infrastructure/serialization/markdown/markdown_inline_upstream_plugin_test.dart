import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

void main() {
  group("Super Editor upstream Markdown reaction >", () {
    group("at beginning of paragraph >", () {
      testWidgets("bold", (tester) async {
        final (document, _) = await _pumpScaffold(tester);

        final nodeId = document.first.id;
        await tester.placeCaretInParagraph(nodeId, 0);
        await tester.typeImeText("**bold**");

        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), "bold");
        expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), [
          const SpanMarker(attribution: boldAttribution, offset: 0, markerType: SpanMarkerType.start),
          const SpanMarker(attribution: boldAttribution, offset: 3, markerType: SpanMarkerType.end),
        ]);
      });

      testWidgets("italics", (tester) async {
        final (document, _) = await _pumpScaffold(tester);

        final nodeId = document.first.id;
        await tester.placeCaretInParagraph(nodeId, 0);
        await tester.typeImeText("*italics*");

        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), "italics");
        expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), [
          const SpanMarker(attribution: italicsAttribution, offset: 0, markerType: SpanMarkerType.start),
          const SpanMarker(attribution: italicsAttribution, offset: 6, markerType: SpanMarkerType.end),
        ]);
      });

      testWidgets("strikethrough", (tester) async {
        final (document, _) = await _pumpScaffold(tester);

        final nodeId = document.first.id;
        await tester.placeCaretInParagraph(nodeId, 0);
        await tester.typeImeText("~strikethrough");

        // Simulate an insertion containing a composing region.
        await tester.ime.sendDeltas([
          const TextEditingDeltaInsertion(
            oldText: '. ~strikethrough',
            textInserted: '~',
            insertionOffset: 16,
            selection: TextSelection.collapsed(offset: 16),
            composing: TextRange.collapsed(16),
          )
        ], getter: imeClientGetter);
        await tester.pump();

        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), "strikethrough");
        expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), [
          const SpanMarker(attribution: strikethroughAttribution, offset: 0, markerType: SpanMarkerType.start),
          const SpanMarker(attribution: strikethroughAttribution, offset: 12, markerType: SpanMarkerType.end),
        ]);
      });

      testWidgets("code", (tester) async {
        final (document, _) = await _pumpScaffold(tester);

        final nodeId = document.first.id;
        await tester.placeCaretInParagraph(nodeId, 0);
        await tester.typeImeText("`code");

        // Simulate an insertion containing a composing region.
        await tester.ime.sendDeltas([
          const TextEditingDeltaInsertion(
            oldText: '. `code',
            textInserted: '`',
            insertionOffset: 7,
            selection: TextSelection.collapsed(offset: 7),
            composing: TextRange.collapsed(7),
          )
        ], getter: imeClientGetter);
        await tester.pump();

        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), "code");
        expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), [
          const SpanMarker(attribution: codeAttribution, offset: 0, markerType: SpanMarkerType.start),
          const SpanMarker(attribution: codeAttribution, offset: 3, markerType: SpanMarkerType.end),
        ]);
      });

      group("unbalanced >", () {
        testWidgets("bold then italics", (tester) async {
          final (document, _) = await _pumpScaffold(tester);

          final nodeId = document.first.id;
          await tester.placeCaretInParagraph(nodeId, 0);
          await tester.typeImeText("**token*");

          expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), "**token*");
          expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers, isEmpty);
        });

        testWidgets("italics then bold", (tester) async {
          final (document, _) = await _pumpScaffold(tester);

          final nodeId = document.first.id;
          await tester.placeCaretInParagraph(nodeId, 0);
          await tester.typeImeText("*token**");

          expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), "token*");
          expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), [
            const SpanMarker(attribution: italicsAttribution, offset: 0, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: italicsAttribution, offset: 4, markerType: SpanMarkerType.end),
          ]);
        });
      });
    });

    group("in middle of paragraph >", () {
      testWidgets("bold", (tester) async {
        final (document, _) = await _pumpScaffold(tester, "Hello");

        final nodeId = document.first.id;
        await tester.placeCaretInParagraph(nodeId, 5);

        await tester.typeImeText(" **bold**");

        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), "Hello bold");
        expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), [
          const SpanMarker(attribution: boldAttribution, offset: 6, markerType: SpanMarkerType.start),
          const SpanMarker(attribution: boldAttribution, offset: 9, markerType: SpanMarkerType.end),
        ]);
      });

      testWidgets("italics", (tester) async {
        final (document, _) = await _pumpScaffold(tester, "Hello");

        final nodeId = document.first.id;
        await tester.placeCaretInParagraph(nodeId, 5);

        await tester.typeImeText(" *italics*");

        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), "Hello italics");
        expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), [
          const SpanMarker(attribution: italicsAttribution, offset: 6, markerType: SpanMarkerType.start),
          const SpanMarker(attribution: italicsAttribution, offset: 12, markerType: SpanMarkerType.end),
        ]);
      });

      testWidgets("strikethrough", (tester) async {
        final (document, _) = await _pumpScaffold(tester, "Hello");

        final nodeId = document.first.id;
        await tester.placeCaretInParagraph(nodeId, 5);

        await tester.typeImeText(" ~strikethrough~");

        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), "Hello strikethrough");
        expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), [
          const SpanMarker(attribution: strikethroughAttribution, offset: 6, markerType: SpanMarkerType.start),
          const SpanMarker(attribution: strikethroughAttribution, offset: 18, markerType: SpanMarkerType.end),
        ]);
      });

      group("unbalanced >", () {
        testWidgets("bold then italics", (tester) async {
          final (document, _) = await _pumpScaffold(tester, "Hello");

          final nodeId = document.first.id;
          await tester.placeCaretInParagraph(nodeId, 5);
          await tester.typeImeText(" **token*");

          expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), "Hello **token*");
          expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers, isEmpty);
        });

        testWidgets("italics then bold", (tester) async {
          final (document, _) = await _pumpScaffold(tester, "Hello");

          final nodeId = document.first.id;
          await tester.placeCaretInParagraph(nodeId, 5);
          await tester.typeImeText(" *token**");

          expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), "Hello token*");
          expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), [
            const SpanMarker(attribution: italicsAttribution, offset: 6, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: italicsAttribution, offset: 10, markerType: SpanMarkerType.end),
          ]);
        });
      });
    });

    group("prevented deserializations >", () {
      testWidgets("unbalanced italics", (tester) async {
        final (document, _) = await _pumpScaffold(tester, "");

        final nodeId = document.first.id;
        await tester.placeCaretInParagraph(nodeId, 0);

        await tester.typeImeText("**noitalics*");

        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), "**noitalics*");
        expect((document.first as ParagraphNode).text.spans.markers.isEmpty, isTrue);
      });
    });

    testWidgets("multiple styles", (tester) async {
      final (document, _) = await _pumpScaffold(tester, "Hello");

      final nodeId = document.first.id;
      await tester.placeCaretInParagraph(nodeId, 5);

      // Italics
      await tester.typeImeText(" *italics*");

      expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), "Hello italics");
      expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), [
        const SpanMarker(attribution: italicsAttribution, offset: 6, markerType: SpanMarkerType.start),
        const SpanMarker(attribution: italicsAttribution, offset: 12, markerType: SpanMarkerType.end),
      ]);

      // Bold
      await tester.typeImeText(" and **bold**");
      expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), "Hello italics and bold");
      expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), [
        const SpanMarker(attribution: italicsAttribution, offset: 6, markerType: SpanMarkerType.start),
        const SpanMarker(attribution: italicsAttribution, offset: 12, markerType: SpanMarkerType.end),
        const SpanMarker(attribution: boldAttribution, offset: 18, markerType: SpanMarkerType.start),
        const SpanMarker(attribution: boldAttribution, offset: 21, markerType: SpanMarkerType.end),
      ]);

      // Strikethrough
      await tester.typeImeText(" and ~strikethrough~");
      expect(
          SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), "Hello italics and bold and strikethrough");
      expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), [
        const SpanMarker(attribution: italicsAttribution, offset: 6, markerType: SpanMarkerType.start),
        const SpanMarker(attribution: italicsAttribution, offset: 12, markerType: SpanMarkerType.end),
        const SpanMarker(attribution: boldAttribution, offset: 18, markerType: SpanMarkerType.start),
        const SpanMarker(attribution: boldAttribution, offset: 21, markerType: SpanMarkerType.end),
        const SpanMarker(attribution: strikethroughAttribution, offset: 27, markerType: SpanMarkerType.start),
        const SpanMarker(attribution: strikethroughAttribution, offset: 39, markerType: SpanMarkerType.end),
      ]);
    });

    testWidgets("preserves non-Markdown attributions", (tester) async {
      final (document, editor) = await _pumpScaffold(tester, "Hello *italics");

      final nodeId = document.first.id;

      // Add a non-Markdown attribution to the text.
      const colorAttribution = ColorAttribution(Color(0xFFFF0000));
      editor.execute([
        AddTextAttributionsRequest(
          // Attribution applied to: "He[llo *ital]ics", which is start: 2, end: 11,
          // because the end is exclusive.
          documentRange: DocumentRange(
            start: DocumentPosition(
              nodeId: nodeId,
              nodePosition: const TextNodePosition(offset: 2),
            ),
            end: DocumentPosition(
              nodeId: nodeId,
              nodePosition: const TextNodePosition(offset: 11),
            ),
          ),
          attributions: {
            colorAttribution,
          },
        ),
      ]);

      // Add a "*" to add italics attribution through Markdown.
      await tester.placeCaretInParagraph(nodeId, 14);
      await tester.typeImeText("*");
      expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), "Hello italics");
      expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), [
        const SpanMarker(attribution: colorAttribution, offset: 2, markerType: SpanMarkerType.start),
        const SpanMarker(attribution: italicsAttribution, offset: 6, markerType: SpanMarkerType.start),
        const SpanMarker(attribution: colorAttribution, offset: 9, markerType: SpanMarkerType.end),
        const SpanMarker(attribution: italicsAttribution, offset: 12, markerType: SpanMarkerType.end),
      ]);
    });

    testWidgets("replicates same ambiguity behaviors as other products", (tester) async {
      // This test verifies that the reaction does the same thing as Notion and Linear
      // when given a specific ambiguous input.
      final (document, _) = await _pumpScaffold(tester, "Hello");

      final nodeId = document.first.id;
      await tester.placeCaretInParagraph(nodeId, 5);

      // "**this*" should do nothing because the downstream syntax doesn't have a
      // balancing upstream syntax. We don't peel a single "*" out of the upstream "**".
      await tester.typeImeText(" **this*");
      expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), "Hello **this*");
      expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), isEmpty);

      // Type " and *" which results in a segment of "* and *". This segment shouldn't be
      // applied as Markdown because we ignore situations where the downstream syntax
      // immediately follows a space.
      await tester.typeImeText(" and *");
      expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), "Hello **this* and *");
      expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), isEmpty);

      // Surround "that" with italics "*". This should be found and applied.
      await tester.typeImeText("that*");
      expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), "Hello **this* and that");
      expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), [
        const SpanMarker(attribution: italicsAttribution, offset: 18, markerType: SpanMarkerType.start),
        const SpanMarker(attribution: italicsAttribution, offset: 21, markerType: SpanMarkerType.end),
      ]);

      await tester.typeImeText("*");
      expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), "Hello **this* and that*");
      expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), [
        const SpanMarker(attribution: italicsAttribution, offset: 18, markerType: SpanMarkerType.start),
        const SpanMarker(attribution: italicsAttribution, offset: 21, markerType: SpanMarkerType.end),
      ]);

      // Surround "this* and that" with bold "**" on both side. This should be found and applied.
      await tester.typeImeText("*");
      expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), "Hello this* and that");
      expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), [
        const SpanMarker(attribution: boldAttribution, offset: 6, markerType: SpanMarkerType.start),
        const SpanMarker(attribution: italicsAttribution, offset: 16, markerType: SpanMarkerType.start),
        const SpanMarker(attribution: italicsAttribution, offset: 19, markerType: SpanMarkerType.end),
        const SpanMarker(attribution: boldAttribution, offset: 19, markerType: SpanMarkerType.end),
      ]);
    });

    group("does not parse upstream syntax creation >", () {
      testWidgets("italics", (tester) async {
        final (document, _) = await _pumpScaffold(tester, "Hello italics*");

        final nodeId = document.first.id;
        await tester.placeCaretInParagraph(nodeId, 6);

        await tester.typeImeText("*");

        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), "Hello *italics*");
        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection.collapsed(
            position: DocumentPosition(nodeId: nodeId, nodePosition: const TextNodePosition(offset: 7)),
          ),
        );
        expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), isEmpty);
      });

      testWidgets("bold", (tester) async {
        final (document, _) = await _pumpScaffold(tester, "Hello bold**");

        final nodeId = document.first.id;
        await tester.placeCaretInParagraph(nodeId, 6);

        await tester.typeImeText("*");
        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), "Hello *bold**");
        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection.collapsed(
            position: DocumentPosition(nodeId: nodeId, nodePosition: const TextNodePosition(offset: 7)),
          ),
        );
        expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), isEmpty);

        await tester.typeImeText("*");
        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), "Hello **bold**");
        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection.collapsed(
            position: DocumentPosition(nodeId: nodeId, nodePosition: const TextNodePosition(offset: 8)),
          ),
        );
        expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), isEmpty);
      });
    });

    group("does not parse syntax with empty content >", () {
      testWidgets("bold", (tester) async {
        final (document, _) = await _pumpScaffold(tester);

        final nodeId = document.first.id;
        await tester.placeCaretInParagraph(nodeId, 0);

        // Type the trigger characters, without any content between them.
        await tester.typeImeText("****");

        // Ensure we didn't try to parse the trigger characters.
        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), "****");
        expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers, isEmpty);
      });

      testWidgets("italics > single trigger > star", (tester) async {
        final (document, _) = await _pumpScaffold(tester);

        final nodeId = document.first.id;
        await tester.placeCaretInParagraph(nodeId, 0);

        // Type the trigger characters, without any content between them.
        await tester.typeImeText("**");

        // Ensure we didn't try to parse the trigger characters.
        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), "**");
        expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers, isEmpty);
      });

      testWidgets("italics > tripple trigger > star", (tester) async {
        final (document, _) = await _pumpScaffold(tester);

        final nodeId = document.first.id;
        await tester.placeCaretInParagraph(nodeId, 0);

        // Type the trigger characters, without any content between them.
        await tester.typeImeText("******");

        // Ensure we didn't try to parse the trigger characters.
        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), "******");
        expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers, isEmpty);
      });

      testWidgets("italics > single trigger > underscore", (tester) async {
        final (document, _) = await _pumpScaffold(tester);

        final nodeId = document.first.id;
        await tester.placeCaretInParagraph(nodeId, 0);

        // Type the trigger characters, without any content between them.
        await tester.typeImeText("__");

        // Ensure we didn't try to parse the trigger characters.
        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), "__");
        expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers, isEmpty);
      });

      testWidgets("italics > tripple trigger > underscore", (tester) async {
        final (document, _) = await _pumpScaffold(tester);

        final nodeId = document.first.id;
        await tester.placeCaretInParagraph(nodeId, 0);

        // Type the trigger characters, without any content between them.
        await tester.typeImeText("______");

        // Ensure we didn't try to parse the trigger characters.
        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), "______");
        expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers, isEmpty);
      });

      testWidgets("strikethrough", (tester) async {
        final (document, _) = await _pumpScaffold(tester);

        final nodeId = document.first.id;
        await tester.placeCaretInParagraph(nodeId, 0);

        // Type the trigger characters, without any content between them.
        await tester.typeImeText("~~");

        // Ensure we didn't try to parse the trigger characters.
        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), "~~");
        expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers, isEmpty);
      });

      testWidgets("code", (tester) async {
        final (document, _) = await _pumpScaffold(tester);

        final nodeId = document.first.id;
        await tester.placeCaretInParagraph(nodeId, 0);

        // Type the trigger characters, without any content between them.
        await tester.typeImeText("``");

        // Ensure we didn't try to parse the trigger characters.
        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), "``");
        expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers, isEmpty);
      });
    });

    group("parses Markdown link >", () {
      testWidgets("but only when a space follows the syntax", (tester) async {
        final (document, _) = await _pumpScaffold(tester);

        final nodeId = document.first.id;
        await tester.placeCaretInParagraph(nodeId, 0);

        // Enter a link syntax, but no characters after it.
        await tester.typeImeText("[google](www.google.com)");

        // Ensure the syntax wasn't linkified.
        var text = SuperEditorInspector.findTextInComponent(nodeId);
        expect(text.toPlainText(), "[google](www.google.com)");
        expect(text.getAttributionSpansByFilter((a) => true), isEmpty);

        // Enter a non-space character.
        await tester.typeImeText("a");

        // Ensure we still haven't linkified
        text = SuperEditorInspector.findTextInComponent(nodeId);
        expect(text.toPlainText(), "[google](www.google.com)a");
        expect(text.getAttributionSpansByFilter((a) => true), isEmpty);

        // Enter a space after the non-space character.
        await tester.typeImeText(" ");

        // Ensure we still haven't linkified
        text = SuperEditorInspector.findTextInComponent(nodeId);
        expect(text.toPlainText(), "[google](www.google.com)a ");
        expect(text.getAttributionSpansByFilter((a) => true), isEmpty);
      });

      testWidgets("parses Markdown link syntax and plays nice with built-in linkification reaction", (tester) async {
        final (document, _) = await _pumpScaffold(tester);

        final nodeId = document.first.id;
        await tester.placeCaretInParagraph(nodeId, 0);

        await tester.typeImeText("[google](www.google.com) ");

        // Ensure that the Markdown was parsed and replaced with a link.
        final text = SuperEditorInspector.findTextInComponent(nodeId);
        expect(text.toPlainText(), "google ");
        expect(text.getAttributionSpansByFilter((a) => true), {
          const AttributionSpan(
            attribution: LinkAttribution("www.google.com"),
            start: 0,
            end: 5,
          ),
        });
        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: nodeId,
              nodePosition: const TextNodePosition(offset: 7),
            ),
          ),
        );
      });
    });
  });
}

Future<(Document, Editor)> _pumpScaffold(WidgetTester tester, [String initialMarkdown = ""]) async {
  final document = deserializeMarkdownToDocument(initialMarkdown);
  final composer = MutableDocumentComposer();
  final editor = createDefaultDocumentEditor(document: document, composer: composer);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SuperEditor(
          editor: editor,
          plugins: {
            MarkdownInlineUpstreamSyntaxPlugin(),
          },
        ),
      ),
    ),
  );

  return (document, editor);
}
