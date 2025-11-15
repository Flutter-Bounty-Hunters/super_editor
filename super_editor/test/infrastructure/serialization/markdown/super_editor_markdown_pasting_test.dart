import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import 'test_tools.dart';

void main() {
  group("SuperEditor > pasting markdown >", () {
    testWidgetsOnArbitraryDesktop("can paste into an empty document", (tester) async {
      final document = MutableDocument.empty("1");
      final composer = MutableDocumentComposer();
      final editor = Editor(
        editables: {
          Editor.documentKey: document,
          Editor.composerKey: composer,
        },
        requestHandlers: [
          (editor, request) => request is PasteStructuredContentEditorRequest
              ? PasteStructuredContentEditorCommand(
                  content: request.content,
                  pastePosition: request.pastePosition,
                )
              : null,
          ...defaultRequestHandlers,
        ],
        reactionPipeline: List.from(defaultEditorReactions),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SuperEditor(
              editor: editor,
              keyboardActions: [
                pasteMarkdownOnCmdAndCtrlV,
                ...defaultKeyboardActions,
              ],
              componentBuilders: [
                TaskComponentBuilder(editor),
                ...defaultComponentBuilders,
              ],
            ),
          ),
        ),
      );

      // Place the caret in the empty document.
      await tester.placeCaretInParagraph("1", 0);

      // Ensure that the document has the caret.
      expect(composer.selection, isNotNull);

      // Simulate the user copying a full markdown document
      tester
        ..simulateClipboard()
        ..setSimulatedClipboardContent(_fullDocumentMarkdown);

      // Paste the markdown content into the empty document.
      await tester.pressCmdV();

      // The editor should now contain a full document that was deserialized
      // from pasted markdown. To verify this, re-serialize the document's
      // content and compare it to the Markdown that we pasted.
      final documentMarkdown = serializeDocumentToMarkdown(document);

      expect(documentMarkdown, _fullDocumentMarkdown);
    });

    testWidgetsOnArbitraryDesktop("can paste at the beginning of a document (without merging text)", (tester) async {
      final (editor, document, composer) = await _pumpSuperEditor(
        tester,
        deserializeMarkdownToDocument('''
# Primary document

This is the document that exists before Markdown is pasted.
      '''),
      );

      // Place the caret at the beginning of the document.
      await tester.placeCaretInParagraph(document.first.id, 0);

      // Ensure that the document has the caret.
      expect(composer.selection, isNotNull);

      // Simulate the user copying a markdown snippet.
      tester
        ..simulateClipboard()
        ..setSimulatedClipboardContent(_markdownHeaderSnippet);

      // Paste the markdown content into the empty document.
      await tester.pressCmdV();

      // The editor should now contain the markdown snippet, followed by the
      // primary document content.
      //
      // To verify this, re-serialize the document's content and compare it
      // to a Markdown representation of the expected document content.
      final documentMarkdown = serializeDocumentToMarkdown(document);

      expect(
        documentMarkdown,
        '''# A Markdown snippet

---
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus sed sagittis urna. Aenean mattis ante justo, quis sollicitudin metus interdum id. Aenean ornare urna ac enim consequat mollis. In aliquet convallis efficitur. Phasellus convallis purus in fringilla scelerisque. Ut ac orci a turpis egestas lobortis. Morbi aliquam dapibus sem, vitae sodales arcu ultrices eu. Duis vulputate mauris quam, eleifend pulvinar quam blandit eget.

# Primary document

This is the document that exists before Markdown is pasted.''',
      );
    });

    testWidgetsOnArbitraryDesktop("can paste at the beginning of a document (with merging text)", (tester) async {
      final (_, document, composer) = await _pumpSuperEditor(
        tester,
        deserializeMarkdownToDocument('''
Primary document

This is the document that exists before Markdown is pasted.
      '''),
      );

      // Place the caret at the beginning of the document.
      await tester.placeCaretInParagraph(document.first.id, 0);

      // Ensure that the document has the caret.
      expect(composer.selection, isNotNull);

      // Simulate the user copying a markdown snippet.
      tester
        ..simulateClipboard()
        ..setSimulatedClipboardContent(_markdownPlainTextSnippet);

      // Paste the markdown content into the empty document.
      await tester.pressCmdV();

      // The editor should now contain the markdown snippet, followed by the
      // primary document content.
      //
      // To verify this, re-serialize the document's content and compare it
      // to a Markdown representation of the expected document content.
      final documentMarkdown = serializeDocumentToMarkdown(document);

      expect(
        documentMarkdown,
        '''Lorem ipsum dolor sit amet, consectetur adipiscing elit.

Phasellus sed sagittis urna.

Aenean mattis ante justo, quis sollicitudin metus interdum id.Primary document

This is the document that exists before Markdown is pasted.''',
      );
    });

    testWidgetsOnArbitraryDesktop("can paste in the middle of a document and merge both sides of text", (tester) async {
      final (_, document, composer) = await _pumpSuperEditor(
        tester,
        deserializeMarkdownToDocument('''This is a paragraph that will split >< here and continue.'''),
      );

      // Place the caret between chevrons ">|<"
      final lastParagraph = document.last as TextNode;
      await tester.placeCaretInParagraph(lastParagraph.id, 37);

      // Ensure that the document has the caret.
      expect(composer.selection, isNotNull);

      // Simulate the user copying a markdown snippet.
      tester
        ..simulateClipboard()
        ..setSimulatedClipboardContent(_markdownPlainTextSnippet);

      // Paste the markdown content into the empty document.
      await tester.pressCmdV();

      // Ensure that the pasted text split the existing paragraph and then merged
      // the starting and ending text of the pasted Markdown.
      final documentMarkdown = serializeDocumentToMarkdown(document);

      expect(
        documentMarkdown,
        '''This is a paragraph that will split >Lorem ipsum dolor sit amet, consectetur adipiscing elit.

Phasellus sed sagittis urna.

Aenean mattis ante justo, quis sollicitudin metus interdum id.< here and continue.''',
      );
    });

    testWidgetsOnArbitraryDesktop("can paste a text snippet within a single paragraph", (tester) async {
      final (_, document, composer) = await _pumpSuperEditor(
        tester,
        deserializeMarkdownToDocument('''This is a paragraph that will add text >< here and continue.'''),
      );

      // Place the caret between chevrons ">|<".
      final lastParagraph = document.last as TextNode;
      await tester.placeCaretInParagraph(lastParagraph.id, 40);

      // Ensure that the document has the caret.
      expect(composer.selection, isNotNull);

      // Simulate the user copying a markdown snippet.
      tester
        ..simulateClipboard()
        ..setSimulatedClipboardContent("this is a snippet of plain text");

      // Paste the markdown content into the empty document.
      await tester.pressCmdV();

      // Ensure that the pasted text split the existing paragraph and then merged
      // the starting and ending text of the pasted Markdown.
      final documentMarkdown = serializeDocumentToMarkdown(document);

      expect(
        documentMarkdown,
        '''This is a paragraph that will add text >this is a snippet of plain text< here and continue.''',
      );
    });

    testWidgetsOnArbitraryDesktop("can paste an image in the middle of a paragraph", (tester) async {
      final (_, document, composer) = await _pumpSuperEditor(
        tester,
        deserializeMarkdownToDocument(
          '''This is a paragraph that will split here >< and show an image between paragraphs.''',
        ),
      );

      // Place the caret between chevrons ">|<".
      final lastParagraph = document.last as TextNode;
      await tester.placeCaretInParagraph(lastParagraph.id, 42);

      // Ensure that the document has the caret.
      expect(composer.selection, isNotNull);

      // Simulate the user copying a markdown snippet.
      tester
        ..simulateClipboard()
        ..setSimulatedClipboardContent("![A Fake Test Image](https://flutter.dev/logo.png)");

      // Paste the markdown content into the empty document.
      await tester.pressCmdV();

      // Ensure that the pasted text split the existing paragraph and then inserted
      // an image in between.
      final documentMarkdown = serializeDocumentToMarkdown(document);

      expect(
        documentMarkdown,
        '''This is a paragraph that will split here >

![A Fake Test Image](https://flutter.dev/logo.png)
< and show an image between paragraphs.''',
      );
    });

    testWidgetsOnArbitraryDesktop("can paste at the end of a document (without merging text)", (tester) async {
      final (_, document, composer) = await _pumpSuperEditor(
        tester,
        deserializeMarkdownToDocument('''
# Primary document

This is the document that exists before Markdown is pasted.
      '''),
      );

      // Place the caret at the end of the existing document.
      final lastParagraph = document.last as TextNode;
      await tester.placeCaretInParagraph(lastParagraph.id, lastParagraph.endPosition.offset);

      // Ensure that the document has the caret.
      expect(composer.selection, isNotNull);

      // Simulate the user copying a markdown snippet.
      tester
        ..simulateClipboard()
        ..setSimulatedClipboardContent(_markdownHeaderSnippet);

      // Paste the markdown content into the empty document.
      await tester.pressCmdV();

      // The editor should now contain the primary document content, followed by
      // the Markdown snippet.
      //
      // To verify this, re-serialize the document's content and compare it
      // to a Markdown representation of the expected document content.
      final documentMarkdown = serializeDocumentToMarkdown(document);

      expect(
        documentMarkdown,
        '''# Primary document

This is the document that exists before Markdown is pasted.

# A Markdown snippet

---
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus sed sagittis urna. Aenean mattis ante justo, quis sollicitudin metus interdum id. Aenean ornare urna ac enim consequat mollis. In aliquet convallis efficitur. Phasellus convallis purus in fringilla scelerisque. Ut ac orci a turpis egestas lobortis. Morbi aliquam dapibus sem, vitae sodales arcu ultrices eu. Duis vulputate mauris quam, eleifend pulvinar quam blandit eget.''',
      );
    });

    testWidgetsOnArbitraryDesktop("can paste at the end of a document (with merging text)", (tester) async {
      final (_, document, composer) = await _pumpSuperEditor(
        tester,
        deserializeMarkdownToDocument('''
# Primary document

This is the document that exists before Markdown is pasted.
      '''),
      );

      // Place the caret at the end of the existing document.
      final lastParagraph = document.last as TextNode;
      await tester.placeCaretInParagraph(lastParagraph.id, lastParagraph.endPosition.offset);

      // Ensure that the document has the caret.
      expect(composer.selection, isNotNull);

      // Simulate the user copying a markdown snippet.
      tester
        ..simulateClipboard()
        ..setSimulatedClipboardContent(_markdownPlainTextSnippet);

      // Paste the markdown content into the empty document.
      await tester.pressCmdV();

      // The editor should now contain the primary document content, followed by
      // the Markdown snippet.
      //
      // To verify this, re-serialize the document's content and compare it
      // to a Markdown representation of the expected document content.
      final documentMarkdown = serializeDocumentToMarkdown(document);

      expect(
        documentMarkdown,
        '''# Primary document

This is the document that exists before Markdown is pasted.Lorem ipsum dolor sit amet, consectetur adipiscing elit.

Phasellus sed sagittis urna.

Aenean mattis ante justo, quis sollicitudin metus interdum id.''',
      );
    });

    testWidgetsOnMac("can paste a link", (tester) async {
      final (_, document, _) = await _pumpSuperEditor(
        tester,
        deserializeMarkdownToDocument(""),
      );

      // Place the caret in empty paragraph.
      final paragraph = document.first as TextNode;
      await tester.placeCaretInParagraph(paragraph.id, 0);

      // Simulate the user copying a markdown snippet.
      tester
        ..simulateClipboard()
        ..setSimulatedClipboardContent("Hello [link](www.google.com)");

      // Paste the markdown content into the empty document.
      await tester.pressCmdV();

      // Ensure that the Markdown link was linkified.
      expect(SuperEditorInspector.findTextInComponent(paragraph.id).toPlainText(), "Hello link");
      const expectedAttribution = LinkAttribution("www.google.com");
      expect(SuperEditorInspector.findTextInComponent(paragraph.id).getAttributionSpansByFilter((a) => true), {
        const AttributionSpan(attribution: expectedAttribution, start: 6, end: 9),
      });
      expect(
        SuperEditorInspector.findDocumentSelection(),
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: paragraph.id,
            nodePosition: const TextNodePosition(offset: 10),
          ),
        ),
      );
    });
  });
}

/// Pumps a [SuperEditor], which displays the given [document], including typical Markdown
/// extensions, and extensions to paste Markdown.
Future<(Editor, MutableDocument, MutableDocumentComposer)> _pumpSuperEditor(
    WidgetTester tester, MutableDocument document) async {
  final composer = MutableDocumentComposer();
  final editor = createDefaultDocumentEditor(document: document, composer: composer);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SuperEditor(
          editor: editor,
          keyboardActions: [
            pasteMarkdownOnCmdAndCtrlV,
            ...defaultKeyboardActions,
          ],
          componentBuilders: [
            TaskComponentBuilder(editor),
            const FakeImageComponentBuilder(size: Size(800, 400)), // Size doesn't matter.
            ...defaultComponentBuilders,
          ],
        ),
      ),
    ),
  );

  return (editor, document, composer);
}

const _markdownHeaderSnippet = '''
# A Markdown snippet

---
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus sed sagittis urna. Aenean mattis ante justo, quis sollicitudin metus interdum id. Aenean ornare urna ac enim consequat mollis. In aliquet convallis efficitur. Phasellus convallis purus in fringilla scelerisque. Ut ac orci a turpis egestas lobortis. Morbi aliquam dapibus sem, vitae sodales arcu ultrices eu. Duis vulputate mauris quam, eleifend pulvinar quam blandit eget.
''';

const _markdownPlainTextSnippet = '''
Lorem ipsum dolor sit amet, consectetur adipiscing elit.

Phasellus sed sagittis urna.

Aenean mattis ante justo, quis sollicitudin metus interdum id.
''';

const _fullDocumentMarkdown = '''
# Example Document

---
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus sed sagittis urna. Aenean mattis ante justo, quis sollicitudin metus interdum id. Aenean ornare urna ac enim consequat mollis. In aliquet convallis efficitur. Phasellus convallis purus in fringilla scelerisque. Ut ac orci a turpis egestas lobortis. Morbi aliquam dapibus sem, vitae sodales arcu ultrices eu. Duis vulputate mauris quam, eleifend pulvinar quam blandit eget.

  * This is an unordered list item
  * This is another list item
  * This is a 3rd list item, with [a link](https://flutter.dev)

Cras vitae sodales nisi. Vivamus dignissim vel purus vel aliquet. Sed viverra diam vel nisi rhoncus pharetra. Donec gravida ut ligula euismod pharetra. Etiam sed urna scelerisque, efficitur mauris vel, semper arcu. Nullam sed vehicula sapien. Donec id tellus volutpat, eleifend nulla eget, rutrum mauris.

  1. First thing to do
  1. Second thing to do
  1. Third thing to do

Nam hendrerit vitae elit ut placerat. Maecenas nec congue neque. Fusce eget tortor pulvinar, cursus neque vitae, sagittis lectus. Duis mollis libero eu scelerisque ullamcorper. Pellentesque eleifend arcu nec augue molestie, at iaculis dui rutrum. Etiam lobortis magna at magna pellentesque ornare. Sed accumsan, libero vel porta molestie, tortor lorem eleifend ante, at egestas leo felis sed nunc. Quisque mi neque, molestie vel dolor a, eleifend tempor odio.

Etiam id lacus interdum, efficitur ex convallis, accumsan ipsum. Integer faucibus mollis mauris, a suscipit ante mollis vitae. Fusce justo metus, congue non lectus ac, luctus rhoncus tellus. Phasellus vitae fermentum orci, sit amet sodales orci. Fusce at ante iaculis nunc aliquet pharetra. Nam placerat, nisl in gravida lacinia, nisl nibh feugiat nunc, in sagittis nisl sapien nec arcu. Nunc gravida faucibus massa, sit amet accumsan dolor feugiat in. Mauris ut elementum leo.

- [ ] This is an incomplete task
- [x] This is a completed task''';
