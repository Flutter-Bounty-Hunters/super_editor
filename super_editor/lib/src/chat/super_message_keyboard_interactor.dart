import 'package:flutter/widgets.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/keyboard.dart';
import 'package:super_editor/src/infrastructure/document_context.dart';

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
class SuperMessageKeyboardInteractor extends StatelessWidget {
  const SuperMessageKeyboardInteractor({
    Key? key,
    required this.focusNode,
    required this.messageContext,
    required this.keyboardActions,
    required this.child,
    this.autofocus = false,
  }) : super(key: key);

  /// The source of all key events.
  final FocusNode focusNode;

  /// Service locator for document display dependencies.
  final DocumentContext messageContext;

  /// All the actions that the user can execute with keyboard keys.
  ///
  /// [keyboardActions] operates as a Chain of Responsibility. Starting
  /// from the beginning of the list, a [DocumentKeyboardAction] is
  /// given the opportunity to handle the currently pressed keys. If that
  /// [DocumentKeyboardAction] reports the keys as handled, then execution
  /// stops. Otherwise, execution continues to the next [DocumentKeyboardAction].
  final List<DocumentKeyboardAction> keyboardActions;

  /// Whether or not the [SuperMessageKeyboardInteractor] should autofocus
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
        documentContext: messageContext,
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
