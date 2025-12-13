import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/keyboard.dart';

/// Applies appropriate edits to a document and selection when the user presses
/// hardware keys.
///
/// Hardware key events are dispatched through [FocusNode]s, therefore, this
/// widget's [FocusNode] needs to be focused for key events to be applied. A
/// [FocusNode] can be provided, or this widget will create its own [FocusNode]
/// internally, which is wrapped around the given [child].
///
/// [keyboardActions] determines the mapping from keyboard key presses
/// to document editing behaviors. [keyboardActions] operates as a
/// Chain of Responsibility.
class SuperEditorHardwareKeyHandler extends StatefulWidget {
  const SuperEditorHardwareKeyHandler({
    Key? key,
    this.focusNode,
    required this.editContext,
    this.keyboardActions = const [],
    this.autofocus = false,
    required this.child,
  }) : super(key: key);

  /// The source of all key events.
  final FocusNode? focusNode;

  /// Service locator for document editing dependencies.
  final SuperEditorContext editContext;

  /// All the actions that the user can execute with keyboard keys.
  ///
  /// [keyboardActions] operates as a Chain of Responsibility. Starting
  /// from the beginning of the list, a [SuperEditorKeyboardAction] is
  /// given the opportunity to handle the currently pressed keys. If that
  /// [SuperEditorKeyboardAction] reports the keys as handled, then execution
  /// stops. Otherwise, execution continues to the next [SuperEditorKeyboardAction].
  final List<SuperEditorKeyboardAction> keyboardActions;

  /// Whether or not the [SuperEditorHardwareKeyHandler] should autofocus
  final bool autofocus;

  /// The [child] widget, which is expected to include the document UI
  /// somewhere in the sub-tree.
  final Widget child;

  @override
  State<SuperEditorHardwareKeyHandler> createState() => _SuperEditorHardwareKeyHandlerState();
}

class _SuperEditorHardwareKeyHandlerState extends State<SuperEditorHardwareKeyHandler> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = (widget.focusNode ?? FocusNode());
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  KeyEventResult _onKeyPressed(FocusNode node, KeyEvent keyEvent) {
    if (!node.hasPrimaryFocus) {
      // The editor is focused, but doesn't have primary focus. For example:
      // - The editor has a node with a focused widget.
      // - There is a focused widget somewhere else in the tree which shares
      //   focus with the editor, typically a popover toolbar.
      // Don't run any of the editor key handlers and let the event bubble up.
      return KeyEventResult.ignored;
    }
    editorKeyLog.info("Handling key press: $keyEvent");
    ExecutionInstruction instruction = ExecutionInstruction.continueExecution;
    int index = 0;
    while (instruction == ExecutionInstruction.continueExecution && index < widget.keyboardActions.length) {
      instruction = widget.keyboardActions[index](
        editContext: widget.editContext,
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
      focusNode: _focusNode,
      onKeyEvent: widget.keyboardActions.isEmpty ? null : _onKeyPressed,
      autofocus: widget.autofocus,
      // Semantics node would create a RenderBox, which does not work within
      // a sliver.
      includeSemantics: false,
      child: widget.child,
    );
  }
}

/// Executes this action, if the action wants to run, and returns
/// a desired `ExecutionInstruction` to either continue or halt
/// execution of actions.
///
/// It is possible that an action makes changes and then returns
/// `ExecutionInstruction.continueExecution` to continue execution.
///
/// It is possible that an action does nothing and then returns
/// `ExecutionInstruction.haltExecution` to prevent further execution.
typedef SuperEditorKeyboardAction = ExecutionInstruction Function({
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
});

/// A [SuperEditorKeyboardAction] that reports [ExecutionInstruction.blocked]
/// for any key combination that matches one of the given [keys].
SuperEditorKeyboardAction ignoreKeyCombos(List<ShortcutActivator> keys) {
  return ({
    required SuperEditorContext editContext,
    required KeyEvent keyEvent,
  }) {
    for (final key in keys) {
      if (key.accepts(keyEvent, HardwareKeyboard.instance)) {
        return ExecutionInstruction.blocked;
      }
    }
    return ExecutionInstruction.continueExecution;
  };
}
