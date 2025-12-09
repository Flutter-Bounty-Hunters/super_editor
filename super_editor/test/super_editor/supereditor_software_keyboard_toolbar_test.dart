import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

// TODO: Make the software keyboard toolbar testable
//       Until then, this suite contains pieces of functionality that mirror the
//       software keyboard toolbar behavior.

void main() {
  group('SuperEditor software keyboard toolbar >', () {
    testWidgetsOnAllPlatforms('converts empty paragraph a horizontal rule', (tester) async {
      final context = await tester //
          .createDocument()
          .withSingleEmptyParagraph()
          .withInputSource(TextInputSource.ime)
          .pump();

      final document = SuperEditorInspector.findDocument()!;

      // Place the caret at the beginning of the empty document.
      await tester.placeCaretInParagraph(document.first.id, 0);

      // Convert the empty paragraph into a horizontal rule.
      final toolbarOps = KeyboardEditingToolbarOperations(
        editor: context.findEditContext().editor,
        document: context.findEditContext().document,
        composer: context.findEditContext().composer,
        commonOps: context.findEditContext().commonOps,
      );
      toolbarOps.convertToHr();
      await tester.pump();

      // Ensure the first node is now a horizontal rule node, and there's a
      // a second node, which is a paragraph node.
      final firstNode = document.first;
      expect(firstNode, isA<HorizontalRuleNode>());

      final secondNode = document.getNodeAt(1)!;
      expect(secondNode, isA<ParagraphNode>());
      expect((secondNode as ParagraphNode).text.toPlainText(), isEmpty);

      // Ensure the caret sits in the new paragraph node.
      final selection = SuperEditorInspector.findDocumentSelection()!;
      expect(selection.isCollapsed, isTrue);
      expect(selection.extent.nodeId, secondNode.id);
      expect((selection.extent.nodePosition as TextNodePosition).offset, 0);
    });
  });
}
