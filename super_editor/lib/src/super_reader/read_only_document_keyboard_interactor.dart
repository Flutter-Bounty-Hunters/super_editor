import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/document_operations/selection_operations.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/keyboard.dart';
import 'package:super_editor/src/infrastructure/platforms/platform.dart';
import 'package:super_editor/src/infrastructure/document_context.dart';

import '../core/document_composer.dart';
import 'reader_context.dart';

/// Governs document input that comes from a physical keyboard.
///
/// Keyboard input won't work on a mobile device with a software
/// keyboard because the software keyboard sends input through
/// the operating system's Input Method Engine. For mobile use-cases,
/// see IME input support.

/// Receives all hardware keyboard input, when focused, and changes the read-only
/// document display, as needed.
///
/// [keyboardActions] determines the mapping from keyboard key presses
/// to document editing behaviors. [keyboardActions] operates as a
/// Chain of Responsibility.
///
/// The difference between a read-only keyboard interactor, and an editing keyboard
/// interactor, is the type of service locator that's passed to each handler. For
/// example, the read-only keyboard interactor can't pass a `DocumentEditor` to
/// the keyboard handlers, because read-only documents don't support edits.
class ReadOnlyDocumentKeyboardInteractor extends StatelessWidget {
  const ReadOnlyDocumentKeyboardInteractor({
    Key? key,
    required this.focusNode,
    required this.readerContext,
    required this.keyboardActions,
    required this.child,
    this.autofocus = false,
  }) : super(key: key);

  /// The source of all key events.
  final FocusNode focusNode;

  /// Service locator for document display dependencies.
  final SuperReaderContext readerContext;

  /// All the actions that the user can execute with keyboard keys.
  ///
  /// [keyboardActions] operates as a Chain of Responsibility. Starting
  /// from the beginning of the list, a [DocumentKeyboardAction] is
  /// given the opportunity to handle the currently pressed keys. If that
  /// [DocumentKeyboardAction] reports the keys as handled, then execution
  /// stops. Otherwise, execution continues to the next [DocumentKeyboardAction].
  final List<SuperReaderKeyboardAction> keyboardActions;

  /// Whether or not the [ReadOnlyDocumentKeyboardInteractor] should autofocus
  final bool autofocus;

  /// The [child] widget, which is expected to include the document UI
  /// somewhere in the sub-tree.
  final Widget child;

  KeyEventResult _onKeyEventPressed(FocusNode node, KeyEvent keyEvent) {
    readerKeyLog.info("Handling key press: $keyEvent");
    ExecutionInstruction instruction = ExecutionInstruction.continueExecution;
    int index = 0;
    while (instruction == ExecutionInstruction.continueExecution && index < keyboardActions.length) {
      instruction = keyboardActions[index](
        documentContext: readerContext,
        keyEvent: keyEvent,
      );
      index += 1;
    }

    switch (instruction) {
      case ExecutionInstruction.haltExecution:
        return KeyEventResult.handled;
      case ExecutionInstruction.continueExecution:
      case ExecutionInstruction.blocked:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      includeSemantics: false,
      onKeyEvent: _onKeyEventPressed,
      autofocus: autofocus,
      child: child,
    );
  }
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
typedef SuperReaderKeyboardAction = ExecutionInstruction Function({
  required SuperReaderContext documentContext,
  required KeyEvent keyEvent,
});

/// Keyboard actions for the standard [SuperReader].
final superReaderDefaultKeyboardActions = <SuperReaderKeyboardAction>[
  removeCollapsedSelectionWhenShiftIsReleased,
  scrollUpWithArrowKey,
  scrollDownWithArrowKey,
  expandSelectionWithLeftArrow,
  expandSelectionWithRightArrow,
  expandSelectionWithUpArrow,
  expandSelectionWithDownArrow,
  expandSelectionToLineStartWithHomeOnWindowsAndLinux,
  expandSelectionToLineEndWithEndOnWindowsAndLinux,
  expandSelectionToLineStartWithCtrlAOnWindowsAndLinux,
  expandSelectionToLineEndWithCtrlEOnWindowsAndLinux,
  selectAllWhenCmdAIsPressedOnMac,
  selectAllWhenCtlAIsPressedOnWindowsAndLinux,
  copyWhenCmdCIsPressedOnMac,
  copyWhenCtlCIsPressedOnWindowsAndLinux,
];

/// Shortcut to remove a document selection when the shift key is released
/// and the selection is collapsed.
///
/// Read-only documents should only display expanded selections (selections that
/// contain at least one character or block of content). The user might expand
/// or contract a selection while holding the shift key. As long as the user is
/// pressing shift, we want to allow any selection. When the user releases the
/// shift key (and triggers this shortcut), we want to remove the document selection
/// if it's collapsed.
final removeCollapsedSelectionWhenShiftIsReleased = createDocumentShortcut(
  ({
    required DocumentContext documentContext,
    required KeyEvent keyEvent,
  }) {
    final selection = documentContext.composer.selection;
    if (selection == null || !selection.isCollapsed) {
      return ExecutionInstruction.continueExecution;
    }

    // The selection is collapsed, and the shift key was released. We don't
    // want to retain the selection any longer. Remove it.
    documentContext.editor.execute([
      const ClearSelectionRequest(),
    ]);
    return ExecutionInstruction.haltExecution;
  },
  keyPressedOrReleased: LogicalKeyboardKey.shift,
  isShiftPressed: false,
  onKeyUp: true,
  onKeyDown: false,
);

final scrollUpWithArrowKey = createSuperReaderShortcut(
  ({
    required SuperReaderContext documentContext,
    required KeyEvent keyEvent,
  }) {
    documentContext.scroller.jumpBy(-20);
    return ExecutionInstruction.haltExecution;
  },
  keyPressedOrReleased: LogicalKeyboardKey.arrowUp,
  isShiftPressed: false,
);

final scrollDownWithArrowKey = createSuperReaderShortcut(
  ({
    required SuperReaderContext documentContext,
    required KeyEvent keyEvent,
  }) {
    documentContext.scroller.jumpBy(20);
    return ExecutionInstruction.haltExecution;
  },
  keyPressedOrReleased: LogicalKeyboardKey.arrowDown,
  isShiftPressed: false,
);

final expandSelectionWithLeftArrow = createDocumentShortcut(
  ({
    required DocumentContext documentContext,
    required KeyEvent keyEvent,
  }) {
    if (defaultTargetPlatform == TargetPlatform.windows && HardwareKeyboard.instance.isAltPressed) {
      return ExecutionInstruction.continueExecution;
    }

    if (defaultTargetPlatform == TargetPlatform.linux &&
        HardwareKeyboard.instance.isAltPressed &&
        (keyEvent.logicalKey == LogicalKeyboardKey.arrowUp || keyEvent.logicalKey == LogicalKeyboardKey.arrowDown)) {
      return ExecutionInstruction.continueExecution;
    }

    // Move the caret left/upstream.
    final didMove = moveCaretUpstream(
      editor: documentContext.editor,
      documentLayout: documentContext.documentLayout,
      movementModifier: _getHorizontalMovementModifier(keyEvent),
      retainCollapsedSelection: HardwareKeyboard.instance.isShiftPressed,
    );

    return didMove ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
  },
  keyPressedOrReleased: LogicalKeyboardKey.arrowLeft,
);

final expandSelectionWithRightArrow = createDocumentShortcut(
  ({
    required DocumentContext documentContext,
    required KeyEvent keyEvent,
  }) {
    if (defaultTargetPlatform == TargetPlatform.windows && HardwareKeyboard.instance.isAltPressed) {
      return ExecutionInstruction.continueExecution;
    }

    if (defaultTargetPlatform == TargetPlatform.linux &&
        HardwareKeyboard.instance.isAltPressed &&
        (keyEvent.logicalKey == LogicalKeyboardKey.arrowUp || keyEvent.logicalKey == LogicalKeyboardKey.arrowDown)) {
      return ExecutionInstruction.continueExecution;
    }

    // Move the caret right/downstream.
    final didMove = moveCaretDownstream(
      editor: documentContext.editor,
      documentLayout: documentContext.documentLayout,
      movementModifier: _getHorizontalMovementModifier(keyEvent),
      retainCollapsedSelection: HardwareKeyboard.instance.isShiftPressed,
    );

    return didMove ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
  },
  keyPressedOrReleased: LogicalKeyboardKey.arrowRight,
);

MovementModifier? _getHorizontalMovementModifier(KeyEvent keyEvent) {
  if ((defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux) &&
      HardwareKeyboard.instance.isControlPressed) {
    return MovementModifier.word;
  } else if (CurrentPlatform.isApple && HardwareKeyboard.instance.isMetaPressed) {
    return MovementModifier.line;
  } else if (CurrentPlatform.isApple && HardwareKeyboard.instance.isAltPressed) {
    return MovementModifier.word;
  }

  return null;
}

final expandSelectionWithUpArrow = createDocumentShortcut(
  ({
    required DocumentContext documentContext,
    required KeyEvent keyEvent,
  }) {
    if (defaultTargetPlatform == TargetPlatform.windows && HardwareKeyboard.instance.isAltPressed) {
      return ExecutionInstruction.continueExecution;
    }

    if (defaultTargetPlatform == TargetPlatform.linux && HardwareKeyboard.instance.isAltPressed) {
      return ExecutionInstruction.continueExecution;
    }

    final didMove = moveCaretUp(
      editor: documentContext.editor,
      documentLayout: documentContext.documentLayout,
      retainCollapsedSelection: HardwareKeyboard.instance.isShiftPressed,
    );

    return didMove ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
  },
  keyPressedOrReleased: LogicalKeyboardKey.arrowUp,
);

final expandSelectionWithDownArrow = createDocumentShortcut(
  ({
    required DocumentContext documentContext,
    required KeyEvent keyEvent,
  }) {
    if (defaultTargetPlatform == TargetPlatform.windows && HardwareKeyboard.instance.isAltPressed) {
      return ExecutionInstruction.continueExecution;
    }

    if (defaultTargetPlatform == TargetPlatform.linux && HardwareKeyboard.instance.isAltPressed) {
      return ExecutionInstruction.continueExecution;
    }

    final didMove = moveCaretDown(
      editor: documentContext.editor,
      documentLayout: documentContext.documentLayout,
      retainCollapsedSelection: HardwareKeyboard.instance.isShiftPressed,
    );

    return didMove ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
  },
  keyPressedOrReleased: LogicalKeyboardKey.arrowDown,
);

final expandSelectionToLineStartWithHomeOnWindowsAndLinux = createDocumentShortcut(
  ({
    required DocumentContext documentContext,
    required KeyEvent keyEvent,
  }) {
    final didMove = moveCaretUpstream(
      editor: documentContext.editor,
      documentLayout: documentContext.documentLayout,
      movementModifier: MovementModifier.line,
      retainCollapsedSelection: HardwareKeyboard.instance.isShiftPressed,
    );

    return didMove ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
  },
  keyPressedOrReleased: LogicalKeyboardKey.home,
  isShiftPressed: true,
  platforms: {TargetPlatform.windows, TargetPlatform.linux, TargetPlatform.fuchsia},
);

final expandSelectionToLineEndWithEndOnWindowsAndLinux = createDocumentShortcut(
  ({
    required DocumentContext documentContext,
    required KeyEvent keyEvent,
  }) {
    final didMove = moveCaretDownstream(
      editor: documentContext.editor,
      documentLayout: documentContext.documentLayout,
      movementModifier: MovementModifier.line,
      retainCollapsedSelection: HardwareKeyboard.instance.isShiftPressed,
    );

    return didMove ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
  },
  keyPressedOrReleased: LogicalKeyboardKey.end,
  isShiftPressed: true,
  platforms: {TargetPlatform.windows, TargetPlatform.linux, TargetPlatform.fuchsia},
);

final expandSelectionToLineStartWithCtrlAOnWindowsAndLinux = createDocumentShortcut(
  ({
    required DocumentContext documentContext,
    required KeyEvent keyEvent,
  }) {
    final didMove = moveCaretUpstream(
      editor: documentContext.editor,
      documentLayout: documentContext.documentLayout,
      movementModifier: MovementModifier.line,
      retainCollapsedSelection: HardwareKeyboard.instance.isShiftPressed,
    );

    return didMove ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
  },
  keyPressedOrReleased: LogicalKeyboardKey.keyA,
  isShiftPressed: true,
  isCtlPressed: true,
  platforms: {TargetPlatform.windows, TargetPlatform.linux, TargetPlatform.fuchsia},
);

final expandSelectionToLineEndWithCtrlEOnWindowsAndLinux = createDocumentShortcut(
  ({
    required DocumentContext documentContext,
    required KeyEvent keyEvent,
  }) {
    final didMove = moveCaretDownstream(
      editor: documentContext.editor,
      documentLayout: documentContext.documentLayout,
      movementModifier: MovementModifier.line,
      retainCollapsedSelection: HardwareKeyboard.instance.isShiftPressed,
    );

    return didMove ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
  },
  keyPressedOrReleased: LogicalKeyboardKey.keyE,
  isShiftPressed: true,
  isCtlPressed: true,
  platforms: {TargetPlatform.windows, TargetPlatform.linux, TargetPlatform.fuchsia},
);

final selectAllWhenCmdAIsPressedOnMac = createDocumentShortcut(
  ({
    required DocumentContext documentContext,
    required KeyEvent keyEvent,
  }) {
    final didSelectAll = selectAll(documentContext.editor);
    return didSelectAll ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
  },
  keyPressedOrReleased: LogicalKeyboardKey.keyA,
  isCmdPressed: true,
  platforms: {TargetPlatform.macOS, TargetPlatform.iOS},
);

final selectAllWhenCtlAIsPressedOnWindowsAndLinux = createDocumentShortcut(
  ({
    required DocumentContext documentContext,
    required KeyEvent keyEvent,
  }) {
    final didSelectAll = selectAll(documentContext.editor);
    return didSelectAll ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
  },
  keyPressedOrReleased: LogicalKeyboardKey.keyA,
  isCtlPressed: true,
  platforms: {
    TargetPlatform.windows,
    TargetPlatform.linux,
    TargetPlatform.fuchsia,
    TargetPlatform.android,
  },
);

final copyWhenCmdCIsPressedOnMac = createDocumentShortcut(
  ({
    required DocumentContext documentContext,
    required KeyEvent keyEvent,
  }) {
    if (documentContext.composer.selection == null) {
      return ExecutionInstruction.continueExecution;
    }
    if (documentContext.composer.selection!.isCollapsed) {
      // Nothing to copy, but we technically handled the task.
      return ExecutionInstruction.haltExecution;
    }

    copy(
      document: documentContext.document,
      selection: documentContext.composer.selection!,
    );

    return ExecutionInstruction.haltExecution;
  },
  keyPressedOrReleased: LogicalKeyboardKey.keyC,
  isCmdPressed: true,
  platforms: {TargetPlatform.macOS, TargetPlatform.iOS},
);

final copyWhenCtlCIsPressedOnWindowsAndLinux = createDocumentShortcut(
  ({
    required DocumentContext documentContext,
    required KeyEvent keyEvent,
  }) {
    if (documentContext.composer.selection == null) {
      return ExecutionInstruction.continueExecution;
    }
    if (documentContext.composer.selection!.isCollapsed) {
      // Nothing to copy, but we technically handled the task.
      return ExecutionInstruction.haltExecution;
    }

    copy(
      document: documentContext.document,
      selection: documentContext.composer.selection!,
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

/// A proxy for a [SuperReaderKeyboardAction] that filters events based
/// on [onKeyUp], [onKeyDown], and [shortcut].
///
/// If [onKeyUp] is `false`, all key-up events are ignored. If [onKeyDown] is
/// `false`, all key-down events are ignored. If [shortcut] is non-null, all
/// events that don't match the [shortcut] key presses are ignored.
///
/// This proxy is optional. Individual [SuperReaderKeyboardAction]s can
/// make these same decisions about key handling. This proxy is provided as
/// a convenience for the average use-case, which typically tries to match
/// a specific shortcut for either an up or down key event.
SuperReaderKeyboardAction createSuperReaderShortcut(
  SuperReaderKeyboardAction action, {
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

  return ({required SuperReaderContext documentContext, required KeyEvent keyEvent}) {
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

@Deprecated("Use createReadOnlyShortcut or createSuperReaderShortcut instead")
SuperReaderKeyboardAction createShortcut(
  SuperReaderKeyboardAction action, {
  LogicalKeyboardKey? keyPressedOrReleased,
  Set<LogicalKeyboardKey>? triggers,
  bool? isShiftPressed,
  bool? isCmdPressed,
  bool? isCtlPressed,
  bool? isAltPressed,
  bool onKeyUp = false,
  bool onKeyDown = true,
  Set<TargetPlatform>? platforms,
}) =>
    createSuperReaderShortcut(
      action,
      keyPressedOrReleased: keyPressedOrReleased,
      triggers: triggers,
      isShiftPressed: isShiftPressed,
      isCmdPressed: isCmdPressed,
      isCtlPressed: isCtlPressed,
      isAltPressed: isAltPressed,
      onKeyUp: onKeyUp,
      onKeyDown: onKeyDown,
      platforms: platforms,
    );
