import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/default_editor/common_editor_operations.dart';
import 'package:super_editor/src/default_editor/multi_node_editing.dart';
import 'package:super_editor/src/infrastructure/keyboard.dart';
import 'package:super_editor/src/infrastructure/serialization/markdown/markdown_to_document_parsing.dart';

/// A [SuperEditor] keyboard action that pastes clipboard content into the document,
/// interpreting the clipboard content as Markdown.
ExecutionInstruction pasteMarkdownOnCmdAndCtrlV({
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
}) {
  if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) {
    return ExecutionInstruction.continueExecution;
  }

  if (!keyEvent.isPrimaryShortcutKeyPressed || keyEvent.logicalKey != LogicalKeyboardKey.keyV) {
    return ExecutionInstruction.continueExecution;
  }
  if (editContext.composer.selection == null) {
    return ExecutionInstruction.continueExecution;
  }

  pasteMarkdown(
    editor: editContext.editor,
    document: editContext.document,
    composer: editContext.composer,
  );

  return ExecutionInstruction.haltExecution;
}

/// Deletes all selected content, and then pastes the current clipboard
/// content at the given location, interpreting the clipboard content
/// as Markdown.
///
/// The clipboard operation is asynchronous. As a result, if the user quickly
/// moves the caret, it's possible that the clipboard content will be pasted
/// at the wrong spot.
Future<void> pasteMarkdown({
  required Editor editor,
  required Document document,
  required DocumentComposer composer,
}) async {
  // Delete all currently selected content.
  if (!composer.selection!.isCollapsed) {
    final pastePosition = CommonEditorOperations.getDocumentPositionAfterExpandedDeletion(
      document: document,
      selection: composer.selection!,
    );

    if (pastePosition == null) {
      // A null pastePosition means that the selection can't be deleted. This might happen
      // when the selection contains only non-deletable nodes. Therefore, we cannot paste.
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

  final markdownToPaste = (await Clipboard.getData('text/plain'))?.text ?? '';
  final deserializedMarkdown = deserializeMarkdownToDocument(markdownToPaste);

  // Paste the structured content into the document.
  editor.execute([
    PasteStructuredContentEditorRequest(
      content: deserializedMarkdown,
      pastePosition: composer.selection!.extent,
    ),
  ]);
}
