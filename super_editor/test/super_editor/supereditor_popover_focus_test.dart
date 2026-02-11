import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:super_editor/super_text_field_test.dart';

void main() {
  group("SuperEditor popover focus", () {
    testWidgetsOnDesktop("shares focus with editor", (tester) async {
      final editContext = await tester
          .createDocument()
          .withSingleParagraph()
          .withInputSource(TextInputSource.ime)
          .autoFocus(true)
          .pump();

      // Select some content in the document.
      // TODO: use robot selection when it becomes available (#672)
      const documentSelection = DocumentSelection(
        base: DocumentPosition(
          nodeId: "1",
          nodePosition: TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: "1",
          nodePosition: TextNodePosition(offset: 20),
        ),
      );
      editContext.findEditContext().editor.execute([
        const ChangeSelectionRequest(
          documentSelection,
          SelectionChangeType.expandSelection,
          SelectionReason.userInteraction,
        ),
      ]);
      await tester.pumpAndSettle();
      expect(SuperEditorInspector.findDocumentSelection(), documentSelection);

      // Show a popover that has a text field and give focus to the text field.
      await _showPopover(tester, editContext.focusNode.context!, editorFocusNode: editContext.focusNode);
      await tester.placeCaretInSuperTextField(0);

      // Ensure the popover has primary focus and the editor still has its selection.
      expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 0));
      expect(SuperEditorInspector.hasFocus(), isTrue);
      expect(SuperEditorInspector.findDocumentSelection(), documentSelection);

      // Close the popover.
      await _hidePopover(tester);

      // Ensure the editor regained focus and the selection is unchanged.
      expect(SuperEditorInspector.hasFocus(), isTrue);
      expect(SuperEditorInspector.findDocumentSelection(), documentSelection);
    });

    testWidgetsOnMobile("shares focus with editor", (tester) async {
      final editContext = await tester.createDocument().withSingleParagraph().autoFocus(true).pump();

      // Select some content in the document.
      // TODO: use robot selection when it becomes available (#672)
      const documentSelection = DocumentSelection(
        base: DocumentPosition(
          nodeId: "1",
          nodePosition: TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: "1",
          nodePosition: TextNodePosition(offset: 20),
        ),
      );
      editContext.findEditContext().editor.execute([
        const ChangeSelectionRequest(
          documentSelection,
          SelectionChangeType.expandSelection,
          SelectionReason.userInteraction,
        ),
      ]);
      await tester.pumpAndSettle();
      expect(SuperEditorInspector.findDocumentSelection(), documentSelection);

      // Show a popover that has a text field and give focus to the text field.
      await _showPopover(tester, editContext.focusNode.context!, editorFocusNode: editContext.focusNode);
      await tester.placeCaretInSuperTextField(0);
      expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 0));

      // Ensure the popover has primary focus and the editor still has its selection.
      expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 0));
      expect(SuperEditorInspector.hasFocus(), isTrue);
      expect(SuperEditorInspector.findDocumentSelection(), documentSelection);

      // Close the popover.
      await _hidePopover(tester);

      // Ensure the editor regained focus and the selection is unchanged.
      expect(SuperEditorInspector.hasFocus(), isTrue);
      expect(SuperEditorInspector.findDocumentSelection(), documentSelection);
    });
  });
}

OverlayEntry? _overlayEntry;

Future<void> _showPopover(
  WidgetTester tester,
  BuildContext context, {
  required FocusNode editorFocusNode,
}) async {
  _overlayEntry = OverlayEntry(builder: (innerContext) {
    return _Popover(
      editorFocusNode: editorFocusNode,
      textFieldFocusNode: FocusNode(),
    );
  });

  Overlay.of(context).insert(_overlayEntry!);

  await tester.pump();
}

Future<void> _hidePopover(WidgetTester tester) async {
  _overlayEntry!.remove();

  await tester.pump();
}

class _Popover extends StatefulWidget {
  const _Popover({
    Key? key,
    required this.editorFocusNode,
    required this.textFieldFocusNode,
  }) : super(key: key);

  final FocusNode editorFocusNode;
  final FocusNode textFieldFocusNode;

  @override
  State<_Popover> createState() => _PopoverState();
}

class _PopoverState extends State<_Popover> {
  final _popoverFocusNode = FocusNode();

  @override
  void dispose() {
    _popoverFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 300, minHeight: 56),
        child: Focus(
          focusNode: _popoverFocusNode,
          parentNode: widget.editorFocusNode,
          child: SuperTextField(
            focusNode: widget.textFieldFocusNode,
            lineHeight: 20,
          ),
        ),
      ),
    );
  }
}
