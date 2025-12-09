import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/infrastructure/keyboard.dart';

/// Collection of core artifacts used to create various document use-cases.
class DocumentContext {
  DocumentContext({
    required this.editor,
    required DocumentLayout Function() getDocumentLayout,
  }) : _getDocumentLayout = getDocumentLayout;

  final Editor editor;

  /// The [Document] that's currently being displayed.
  Document get document => editor.document;

  /// The current selection within the displayed document.
  DocumentComposer get composer => editor.composer;

  /// The document layout that is a visual representation of the document.
  ///
  /// This member might change over time.
  DocumentLayout get documentLayout => _getDocumentLayout();
  final DocumentLayout Function() _getDocumentLayout;
}

/// Executes this action, if the action wants to run, and returns
/// a desired [ExecutionInstruction] to either continue or halt
/// execution of actions.
///
/// It is possible that an action makes changes and then returns
/// [ExecutionInstruction.continueExecution] to continue execution.
///
/// It is possible that an action does nothing and then returns
/// [ExecutionInstruction.haltExecution] to prevent further execution.
typedef DocumentKeyboardAction = ExecutionInstruction Function({
  required DocumentContext documentContext,
  required KeyEvent keyEvent,
});

/// A proxy for a [DocumentKeyboardAction] that filters events based
/// on [onKeyUp], [onKeyDown], and [shortcut].
///
/// If [onKeyUp] is `false`, all key-up events are ignored. If [onKeyDown] is
/// `false`, all key-down events are ignored. If [shortcut] is non-null, all
/// events that don't match the [shortcut] key presses are ignored.
///
/// This proxy is optional. Individual [DocumentKeyboardAction]s can
/// make these same decisions about key handling. This proxy is provided as
/// a convenience for the average use-case, which typically tries to match
/// a specific shortcut for either an up or down key event.
DocumentKeyboardAction createDocumentShortcut(
  DocumentKeyboardAction action, {
  LogicalKeyboardKey? keyPressedOrReleased,
  Set<LogicalKeyboardKey>? triggers,
  bool? isShiftPressed,
  bool? isCmdPressed,
  bool? isCtlPressed,
  bool? isAltPressed,
  bool onKeyUp = false,
  bool onKeyDown = true,
  Set<TargetPlatform>? platforms,
}) {
  if (onKeyUp == false && onKeyDown == false) {
    throw Exception(
        "Invalid shortcut definition. Both onKeyUp and onKeyDown are false. This shortcut will never be triggered.");
  }

  return ({required DocumentContext documentContext, required KeyEvent keyEvent}) {
    if (keyEvent is KeyUpEvent && !onKeyUp) {
      return ExecutionInstruction.continueExecution;
    }

    if ((keyEvent is KeyDownEvent || keyEvent is KeyRepeatEvent) && !onKeyDown) {
      return ExecutionInstruction.continueExecution;
    }

    if (isCmdPressed != null && isCmdPressed != HardwareKeyboard.instance.isMetaPressed) {
      return ExecutionInstruction.continueExecution;
    }

    if (isCtlPressed != null && isCtlPressed != HardwareKeyboard.instance.isControlPressed) {
      return ExecutionInstruction.continueExecution;
    }

    if (isAltPressed != null && isAltPressed != HardwareKeyboard.instance.isAltPressed) {
      return ExecutionInstruction.continueExecution;
    }

    if (isShiftPressed != null) {
      if (isShiftPressed && !HardwareKeyboard.instance.isShiftPressed) {
        return ExecutionInstruction.continueExecution;
      } else if (!isShiftPressed && HardwareKeyboard.instance.isShiftPressed) {
        return ExecutionInstruction.continueExecution;
      }
    }

    if (keyPressedOrReleased != null && keyEvent.logicalKey != keyPressedOrReleased) {
      // Manually account for the fact that Flutter pretends that different
      // shift keys mean different things.
      if ((keyPressedOrReleased == LogicalKeyboardKey.shift ||
              keyPressedOrReleased == LogicalKeyboardKey.shiftLeft ||
              keyPressedOrReleased == LogicalKeyboardKey.shiftRight) &&
          (keyEvent.logicalKey == LogicalKeyboardKey.shift ||
              keyEvent.logicalKey == LogicalKeyboardKey.shiftLeft ||
              keyEvent.logicalKey == LogicalKeyboardKey.shiftRight)) {
        // This is a false positive signal. We're looking for a shift key trigger, and
        // one of the shifts is the trigger. We don't care which one.
      } else {
        return ExecutionInstruction.continueExecution;
      }
    }

    if (triggers != null) {
      for (final key in triggers) {
        if (!HardwareKeyboard.instance.isLogicalKeyPressed(key)) {
          // Manually account for the fact that Flutter pretends that different
          // shift keys mean different things.
          if (key == LogicalKeyboardKey.shift ||
              key == LogicalKeyboardKey.shiftLeft ||
              key == LogicalKeyboardKey.shiftRight) {
            if (keyEvent.logicalKey == LogicalKeyboardKey.shift ||
                keyEvent.logicalKey == LogicalKeyboardKey.shiftLeft ||
                keyEvent.logicalKey == LogicalKeyboardKey.shiftRight) {
              // This is a false positive signal. We're looking for a shift key trigger, and
              // one of the shifts is the trigger. We don't care which one.
              continue;
            }
          }

          // A required trigger key isn't currently pressed. We don't
          // want to respond to this key event.
          return ExecutionInstruction.continueExecution;
        }
      }
    }

    if (platforms != null && !platforms.contains(defaultTargetPlatform)) {
      return ExecutionInstruction.continueExecution;
    }

    // The key event has passed all the proxy conditions. Run the real key action.
    return action(documentContext: documentContext, keyEvent: keyEvent);
  };
}
