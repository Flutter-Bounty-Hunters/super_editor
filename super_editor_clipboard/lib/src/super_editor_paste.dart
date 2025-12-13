import 'dart:async';

import 'package:flutter/services.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_clipboard/src/editor_paste.dart';

/// Pastes rich text from the system clipboard when the user presses CMD+V on
/// Mac, or CTRL+V on Windows/Linux.
///
/// This method expects to find rich text on the system clipboard as HTML, which
/// is then converted to Markdown, and then converted to a [Document].
ExecutionInstruction pasteRichTextOnCmdCtrlV({
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
}) {
  if (keyEvent is! KeyDownEvent) {
    return ExecutionInstruction.continueExecution;
  }

  if (!HardwareKeyboard.instance.isMetaPressed && !HardwareKeyboard.instance.isControlPressed) {
    return ExecutionInstruction.continueExecution;
  }

  if (keyEvent.logicalKey != LogicalKeyboardKey.keyV) {
    return ExecutionInstruction.continueExecution;
  }

  // Cmd/Ctrl+V detected - handle clipboard paste
  _pasteFromClipboard(editContext.editor);

  return ExecutionInstruction.haltExecution;
}

Future<void> _pasteFromClipboard(Editor editor) async {
  final clipboard = SystemClipboard.instance;
  if (clipboard == null) {
    return;
  }

  final reader = await clipboard.read();

  // Try to paste rich text (via HTML).
  var didPaste = await _maybePasteHtml(editor, reader);
  if (didPaste) {
    return;
  }

  // Fall back to plain text.
  _pastePlainText(editor, reader);
}

Future<bool> _maybePasteHtml(Editor editor, ClipboardReader reader) async {
  final completer = Completer<bool>();

  reader.getValue(
    Formats.htmlText,
    (html) {
      if (html == null) {
        completer.complete(false);
        return;
      }

      // Do the paste.
      editor.pasteHtml(editor, html);

      completer.complete(true);
    },
    onError: (_) {
      completer.complete(false);
    },
  );

  final didPaste = await completer.future;
  return didPaste;
}

void _pastePlainText(Editor editor, ClipboardReader reader) {
  reader.getValue(Formats.plainText, (value) {
    if (value != null) {
      editor.execute([InsertPlainTextAtCaretRequest(value)]);
    }
  });
}
