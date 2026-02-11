import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

void main() {
  group('SuperEditor > content deletion >', () {
    testWidgetsOnAllPlatforms('clears document', (tester) async {
      final testContext = await tester //
          .createDocument()
          .withLongDoc()
          .pump();

      // Place the caret at an arbitraty node. We don't place the caret at the
      // beginning of the document to make sure the selection will move
      // to the beginning of the document after the deletion.
      await tester.placeCaretInParagraph('2', 0);

      // Hold the state sent to the platform.
      String? text;
      int? selectionBase;
      int? selectionExtent;
      String? selectionAffinity;
      int? composingBase;
      int? composingExtent;

      // Intercept the setEditingState message sent to the platform.
      tester
          .interceptChannel(SystemChannels.textInput.name) //
          .interceptMethod(
        'TextInput.setEditingState',
        (methodCall) {
          if (methodCall.method == 'TextInput.setEditingState') {
            text = methodCall.arguments['text'];
            selectionBase = methodCall.arguments['selectionBase'];
            selectionExtent = methodCall.arguments['selectionExtent'];
            selectionAffinity = methodCall.arguments['selectionAffinity'];
            composingBase = methodCall.arguments["composingBase"];
            composingExtent = methodCall.arguments["composingExtent"];
          }
          return null;
        },
      );

      // Delete all content.
      testContext.editor.execute([const ClearDocumentRequest()]);
      await tester.pump();

      // Ensure the document was cleared and a new empty paragraph was added.
      final document = testContext.document;
      expect(document.length, equals(1));
      expect(document.first, isA<ParagraphNode>());
      expect((document.first as ParagraphNode).text.text, equals(''));

      // Ensure the selection was moved to the end of the document.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: document.first.id,
            nodePosition: const TextNodePosition(offset: 0),
          ),
        ),
      );

      // Ensure the composing region was cleared.
      expect(testContext.composer.composingRegion.value, isNull);

      // Ensure the state was correctly sent to the platform.
      expect(text, equals('. '));
      expect(selectionBase, equals(2));
      expect(selectionExtent, equals(2));
      expect(selectionAffinity, equals('TextAffinity.downstream'));
      expect(composingBase, equals(-1));
      expect(composingExtent, equals(-1));

      // Ensure the user can still type text.
      await tester.typeImeText('Hello world!');
      expect((document.first as ParagraphNode).text.text, equals('Hello world!'));
    });
  });
}
