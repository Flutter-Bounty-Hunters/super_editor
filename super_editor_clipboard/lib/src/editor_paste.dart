import 'package:html2md/html2md.dart' as html2md;
import 'package:super_editor/super_editor.dart';

extension RichTextPaste on Editor {
  void pasteHtml(Editor editor, String html) {
    final markdown = html2md.convert(html);
    final contentToPaste = deserializeMarkdownToDocument(markdown);

    final composer = editor.composer;
    DocumentPosition? pastePosition = composer.selection!.extent;

    // Delete all currently selected content.
    if (!composer.selection!.isCollapsed) {
      pastePosition = CommonEditorOperations.getDocumentPositionAfterExpandedDeletion(
        document: editor.document,
        selection: composer.selection!,
      );

      if (pastePosition == null) {
        // There are no deletable nodes in the selection. Do nothing.
        return;
      }

      // Delete the selected content.
      editor.execute([
        DeleteContentRequest(documentRange: composer.selection!),
        ChangeSelectionRequest(
          DocumentSelection.collapsed(position: pastePosition),
          SelectionChangeType.deleteContent,
          SelectionReason.userInteraction,
        ),
      ]);
    }

    editor.execute([
      PasteStructuredContentEditorRequest(
        content: contentToPaste,
        pastePosition: pastePosition,
      ),
    ]);
  }
}
