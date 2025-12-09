import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_clipboard/src/document_copy.dart';

/// [SuperReader] shortcut to copy the selected content within the document
/// as rich text, on Mac.
final copyAsRichTextWhenCmdCIsPressedOnMac = createShortcut(
  ({required SuperReaderContext documentContext, required KeyEvent keyEvent}) {
    if (documentContext.editor.composer.selection == null) {
      return ExecutionInstruction.continueExecution;
    }
    if (documentContext.editor.composer.selection!.isCollapsed) {
      // Nothing to copy, but we technically handled the task.
      return ExecutionInstruction.haltExecution;
    }

    documentContext.editor.document.copyAsRichTextWithPlainTextFallback(
      selection: documentContext.editor.composer.selection!,
    );

    return ExecutionInstruction.haltExecution;
  },
  keyPressedOrReleased: LogicalKeyboardKey.keyC,
  isCmdPressed: true,
  platforms: {TargetPlatform.macOS, TargetPlatform.iOS},
);

/// [SuperReader] shortcut to copy the selected content within the document
/// as rich text, on Windows and Linux.
final copyAsRichTextWhenCtrlCIsPressedOnWindowsAndLinux = createShortcut(
  ({required SuperReaderContext documentContext, required KeyEvent keyEvent}) {
    if (documentContext.editor.composer.selection == null) {
      return ExecutionInstruction.continueExecution;
    }
    if (documentContext.editor.composer.selection!.isCollapsed) {
      // Nothing to copy, but we technically handled the task.
      return ExecutionInstruction.haltExecution;
    }

    documentContext.editor.document.copyAsRichTextWithPlainTextFallback(
      selection: documentContext.editor.composer.selection!,
    );

    return ExecutionInstruction.haltExecution;
  },
  keyPressedOrReleased: LogicalKeyboardKey.keyC,
  isCtlPressed: true,
  platforms: {
    TargetPlatform.windows,
    TargetPlatform.linux,
    TargetPlatform.fuchsia,
    TargetPlatform.android,
  },
);
