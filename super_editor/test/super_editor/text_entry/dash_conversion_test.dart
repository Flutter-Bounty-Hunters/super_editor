import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/default_editor/default_document_editor.dart';

import 'package:super_editor/src/default_editor/super_editor.dart';
import 'package:super_editor/src/default_editor/tasks.dart';
import 'package:super_editor/src/infrastructure/strings.dart';
import 'package:super_editor/src/infrastructure/text_input.dart';
import 'package:super_editor/super_editor_test.dart';

import '../../test_runners.dart';

void main() {
  group('SuperEditor dash conversion', () {
    group('converts two dashes to an em dash', () {
      testAllInputsOnAllPlatforms('at the beginning of an empty paragraph', (
        tester, {
        required TextInputSource inputSource,
      }) async {
        final context = await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .withInputSource(inputSource)
            .pump();

        // Place the caret at the beginning of the document.
        await tester.placeCaretInParagraph('1', 0);

        // Type the first dash.
        await tester.typeTextAdaptive('-');

        // Ensure no conversion happened.
        expect(SuperEditorInspector.findTextInComponent('1').toPlainText(), '-');

        // Type the second dash.
        await tester.typeTextAdaptive('-');

        // Ensure the two dashes were converted to an em-dash.
        expect(context.document.nodeCount, 1);
        expect(SuperEditorInspector.findTextInComponent('1').toPlainText(), SpecialCharacters.emDash);

        // Type some arbitrary text.
        await tester.typeTextAdaptive(' is an em-dash');

        // Ensure the text was inserted.
        expect(SuperEditorInspector.findTextInComponent('1').toPlainText(), '— is an em-dash');
      });

      testAllInputsOnAllPlatforms('at the beginning of a non-empty paragraph', (
        tester, {
        required TextInputSource inputSource,
      }) async {
        final context = await tester //
            .createDocument()
            .fromMarkdown('was inserted')
            .withInputSource(inputSource)
            .pump();

        final nodeId = context.document.first.id;

        // Place the caret at the beginning of a paragraph.
        await tester.placeCaretInParagraph(nodeId, 0);

        // Type the first dash.
        await tester.typeTextAdaptive('-');

        // Ensure no conversion happened.
        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), '-was inserted');

        // Type the second dash.
        await tester.typeTextAdaptive('-');

        // Ensure the two dashes were converted to an em-dash.
        expect(context.document.nodeCount, 1);
        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), '—was inserted');

        // Type some arbitrary text.
        await tester.typeTextAdaptive('(em-dash) ');

        // Ensure the text was inserted.
        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), '—(em-dash) was inserted');
      });

      testAllInputsOnAllPlatforms('at the middle of a paragraph', (
        tester, {
        required TextInputSource inputSource,
      }) async {
        final context = await tester //
            .createDocument()
            .fromMarkdown('Inserting with a reaction')
            .withInputSource(inputSource)
            .pump();

        final nodeId = context.document.first.id;

        // Place the caret at "|with".
        await tester.placeCaretInParagraph(nodeId, 10);

        // Type the first dash.
        await tester.typeTextAdaptive('-');

        // Ensure no conversion happened.
        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), 'Inserting -with a reaction');

        // Type the second dash.
        await tester.typeTextAdaptive('-');

        // Ensure the two dashes were converted to an em-dash.
        expect(context.document.nodeCount, 1);
        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), 'Inserting —with a reaction');

        // Type some arbitrary text.
        await tester.typeTextAdaptive(' typing two dashes ');

        // Type three dashes. The first two should be converted to an em-dash
        // and the second should be inserted as is.
        await tester.typeTextAdaptive('---');
        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(),
            'Inserting — typing two dashes —-with a reaction');

        // Type another dash. The previously inserted dash and the current one
        // should be converted to an em-dash.
        await tester.typeTextAdaptive('-');
        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(),
            'Inserting — typing two dashes ——with a reaction');
      });

      testAllInputsOnAllPlatforms('at the end of a paragraph', (
        tester, {
        required TextInputSource inputSource,
      }) async {
        final context = await tester //
            .createDocument()
            .fromMarkdown('Inserting')
            .withInputSource(inputSource)
            .pump();

        final nodeId = context.document.first.id;

        // Place the caret at the end of the paragraph and add a space
        // just to separate the first word from the dash.
        // Converting from markdown removes the trailing spaces.
        await tester.placeCaretInParagraph(nodeId, 9);
        await tester.typeTextAdaptive(' ');

        // Type the first dash.
        await tester.typeTextAdaptive('-');

        // Ensure no conversion happened.
        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), 'Inserting -');

        // Type the second dash.
        await tester.typeTextAdaptive('-');

        // Ensure the two dashes were converted to an em-dash.
        expect(context.document.nodeCount, 1);
        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), 'Inserting —');

        // Type some arbitrary text.
        await tester.typeTextAdaptive(' by typing two dashes');

        // Ensure the text was inserted.
        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), 'Inserting — by typing two dashes');
      });

      testAllInputsOnAllPlatforms('at the beginning of an empty list item', (
        tester, {
        required TextInputSource inputSource,
      }) async {
        final context = await tester //
            .createDocument()
            .fromMarkdown('* ')
            .withInputSource(inputSource)
            .pump();

        final nodeId = context.document.first.id;

        // Place the caret at the beginning of the document.
        await tester.placeCaretInParagraph(nodeId, 0);

        // Type the first dash.
        await tester.typeTextAdaptive('-');

        // Ensure no conversion happened.
        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), '-');

        // Type the second dash.
        await tester.typeTextAdaptive('-');

        // Ensure the two dashes were converted to an em-dash.
        expect(context.document.nodeCount, 1);
        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), '—');

        // Type some arbitrary text.
        await tester.typeTextAdaptive(' is an em-dash');

        // Ensure the text was inserted.
        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), '— is an em-dash');
      });

      testAllInputsOnAllPlatforms('at the beginning of a non-empty list item', (
        tester, {
        required TextInputSource inputSource,
      }) async {
        final context = await tester //
            .createDocument()
            .fromMarkdown('* was inserted')
            .withInputSource(inputSource)
            .pump();

        final nodeId = context.document.first.id;

        // Place the caret at the beginning of the document.
        await tester.placeCaretInParagraph(nodeId, 0);

        // Type the first dash.
        await tester.typeTextAdaptive('-');

        // Ensure no conversion happened.
        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), '-was inserted');

        // Type the second dash.
        await tester.typeTextAdaptive('-');

        // Ensure the two dashes were converted to an em-dash.
        expect(context.document.nodeCount, 1);
        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), '—was inserted');

        // Type a third dash.
        await tester.typeTextAdaptive('-');

        // Ensure a dash was inserted and no other nodes were added.
        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), '—-was inserted');
        expect(context.document.nodeCount, 1);

        // Type some arbitrary text.
        await tester.typeTextAdaptive('(em-dash) ');

        // Ensure the text was inserted.
        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), '—-(em-dash) was inserted');
      });

      testAllInputsOnAllPlatforms('at the middle of a list item', (
        tester, {
        required TextInputSource inputSource,
      }) async {
        final context = await tester //
            .createDocument()
            .fromMarkdown('* Inserting with a reaction')
            .withInputSource(inputSource)
            .pump();

        final nodeId = context.document.first.id;

        // Place the caret at "|with".
        await tester.placeCaretInParagraph(nodeId, 10);

        // Type the first dash.
        await tester.typeTextAdaptive('-');

        // Ensure no conversion happened.
        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), 'Inserting -with a reaction');

        // Type the second dash.
        await tester.typeTextAdaptive('-');

        // Ensure the two dashes were converted to an em-dash.
        expect(context.document.nodeCount, 1);
        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), 'Inserting —with a reaction');

        // Type some arbitrary text.
        await tester.typeTextAdaptive(' typing two dashes ');

        // Type three dashes. The first two should be converted to an em-dash
        // and the second should be inserted as is.
        await tester.typeTextAdaptive('---');
        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(),
            'Inserting — typing two dashes —-with a reaction');

        // Type another dash. The previously inserted dash and the current one
        // should be converted to an em-dash.
        await tester.typeTextAdaptive('-');
        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(),
            'Inserting — typing two dashes ——with a reaction');
      });

      testAllInputsOnAllPlatforms('at the end of a list item', (
        tester, {
        required TextInputSource inputSource,
      }) async {
        final context = await tester //
            .createDocument()
            .fromMarkdown('* Inserting')
            .withInputSource(inputSource)
            .pump();

        final nodeId = context.document.first.id;

        // Place the caret at the end of the list item and add a space
        // just to separate the first word from the dash.
        // Converting from markdown removes the trailing spaces.
        await tester.placeCaretInParagraph(nodeId, 9);
        await tester.typeTextAdaptive(' ');

        // Type the first dash.
        await tester.typeTextAdaptive('-');

        // Ensure no conversion happened.
        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), 'Inserting -');

        // Type the second dash.
        await tester.typeTextAdaptive('-');

        // Ensure the two dashes were converted to an em-dash.
        expect(context.document.nodeCount, 1);
        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), 'Inserting —');

        // Type some arbitrary text.
        await tester.typeTextAdaptive(' by typing two dashes');

        // Ensure the text was inserted.
        expect(SuperEditorInspector.findTextInComponent(nodeId).toPlainText(), 'Inserting — by typing two dashes');
      });

      testAllInputsOnAllPlatforms('at the beginning of an empty task', (
        tester, {
        required TextInputSource inputSource,
      }) async {
        final document = MutableDocument(
          nodes: [
            TaskNode(id: "1", text: AttributedText(""), isComplete: false),
          ],
        );
        final composer = MutableDocumentComposer();
        final editor = createDefaultDocumentEditor(document: document, composer: composer);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SuperEditor(
                editor: editor,
                componentBuilders: [
                  TaskComponentBuilder(editor),
                  ...defaultComponentBuilders,
                ],
              ),
            ),
          ),
        );

        final nodeId = document.first.id;

        // Place the caret at the beginning of the document.
        await tester.placeCaretInParagraph(nodeId, 0);

        // Type the first dash.
        await tester.typeTextAdaptive('-');

        // Ensure no conversion happened.
        expect((document.first as TaskNode).text.toPlainText(), '-');

        // Type the second dash.
        await tester.typeTextAdaptive('-');

        // Ensure the two dashes were converted to an em-dash.
        expect(document.nodeCount, 1);
        expect((document.first as TaskNode).text.toPlainText(), '—');

        // Type some arbitrary text.
        await tester.typeTextAdaptive(' is an em-dash');

        // Ensure the text was inserted.
        expect((document.first as TaskNode).text.toPlainText(), '— is an em-dash');
      });

      testAllInputsOnAllPlatforms('at the beginning of a non-empty task', (
        tester, {
        required TextInputSource inputSource,
      }) async {
        final document = MutableDocument(
          nodes: [
            TaskNode(id: "1", text: AttributedText("was inserted"), isComplete: false),
          ],
        );
        final composer = MutableDocumentComposer();
        final editor = createDefaultDocumentEditor(document: document, composer: composer);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SuperEditor(
                editor: editor,
                componentBuilders: [
                  TaskComponentBuilder(editor),
                  ...defaultComponentBuilders,
                ],
              ),
            ),
          ),
        );

        // Place the caret at the beginning of the document.
        await tester.placeCaretInParagraph(document.first.id, 0);

        // Type the first dash.
        await tester.typeTextAdaptive('-');

        // Ensure no conversion happened.
        expect((document.first as TaskNode).text.toPlainText(), '-was inserted');

        // Type the second dash.
        await tester.typeTextAdaptive('-');

        // Ensure the two dashes were converted to an em-dash.
        expect(document.nodeCount, 1);
        expect((document.first as TaskNode).text.toPlainText(), '—was inserted');

        // Type a third dash.
        await tester.typeTextAdaptive('-');

        // Ensure a dash was inserted and no other nodes were added.
        expect((document.first as TaskNode).text.toPlainText(), '—-was inserted');
        expect(document.nodeCount, 1);

        // Type some arbitrary text.
        await tester.typeTextAdaptive('(em-dash) ');

        // Ensure the text was inserted.
        expect((document.first as TaskNode).text.toPlainText(), '—-(em-dash) was inserted');
      });

      testAllInputsOnAllPlatforms('at the middle of a task', (
        tester, {
        required TextInputSource inputSource,
      }) async {
        final document = MutableDocument(
          nodes: [
            TaskNode(id: "1", text: AttributedText("Inserting with a reaction"), isComplete: false),
          ],
        );
        final composer = MutableDocumentComposer();
        final editor = createDefaultDocumentEditor(document: document, composer: composer);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SuperEditor(
                editor: editor,
                componentBuilders: [
                  TaskComponentBuilder(editor),
                  ...defaultComponentBuilders,
                ],
              ),
            ),
          ),
        );

        // Place the caret at "|with".
        await tester.placeCaretInParagraph(document.first.id, 10);

        // Type the first dash.
        await tester.typeTextAdaptive('-');

        // Ensure no conversion happened.
        expect((document.first as TaskNode).text.toPlainText(), 'Inserting -with a reaction');

        // Type the second dash.
        await tester.typeTextAdaptive('-');

        // Ensure the two dashes were converted to an em-dash.
        expect(document.nodeCount, 1);
        expect((document.first as TaskNode).text.toPlainText(), 'Inserting —with a reaction');

        // Type some arbitrary text.
        await tester.typeTextAdaptive(' typing two dashes ');

        // Type three dashes. The first two should be converted to an em-dash
        // and the second should be inserted as is.
        await tester.typeTextAdaptive('---');
        expect((document.first as TaskNode).text.toPlainText(), 'Inserting — typing two dashes —-with a reaction');

        // Type another dash. The previously inserted dash and the current one
        // should be converted to an em-dash.
        await tester.typeTextAdaptive('-');
        expect((document.first as TaskNode).text.toPlainText(), 'Inserting — typing two dashes ——with a reaction');
      });

      testAllInputsOnAllPlatforms('at the end of a task', (
        tester, {
        required TextInputSource inputSource,
      }) async {
        final document = MutableDocument(
          nodes: [
            TaskNode(id: "1", text: AttributedText("Inserting"), isComplete: false),
          ],
        );
        final composer = MutableDocumentComposer();
        final editor = createDefaultDocumentEditor(document: document, composer: composer);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SuperEditor(
                editor: editor,
                componentBuilders: [
                  TaskComponentBuilder(editor),
                  ...defaultComponentBuilders,
                ],
              ),
            ),
          ),
        );

        // Place the caret at the end of the task and add a space
        // just to separate the first word from the dash.
        // Converting from markdown removes the trailing spaces.
        await tester.placeCaretInParagraph(document.first.id, 9);
        await tester.typeTextAdaptive(' ');

        // Type the first dash.
        await tester.typeTextAdaptive('-');

        // Ensure no conversion happened.
        expect((document.first as TaskNode).text.toPlainText(), 'Inserting -');

        // Type the second dash.
        await tester.typeTextAdaptive('-');

        // Ensure the two dashes were converted to an em-dash.
        expect(document.nodeCount, 1);
        expect((document.first as TaskNode).text.toPlainText(), 'Inserting —');

        // Type some arbitrary text.
        await tester.typeTextAdaptive(' by typing two dashes');

        // Ensure the text was inserted.
        expect((document.first as TaskNode).text.toPlainText(), 'Inserting — by typing two dashes');
      });
    });
  });
}
