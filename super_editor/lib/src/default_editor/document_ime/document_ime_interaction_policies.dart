import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/default_editor/document_ime/shared_ime.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/flutter/flutter_scheduler.dart';

/// Widget that opens and closes an [imeConnection] based on the [focusNode] gaining
/// and losing primary focus.
class ImeFocusPolicy extends StatefulWidget {
  const ImeFocusPolicy({
    Key? key,
    this.focusNode,
    required this.inputId,
    required this.imeClientFactory,
    required this.imeConfiguration,
    this.openImeOnPrimaryFocusGain = true,
    this.closeImeOnPrimaryFocusLost = false,
    this.openImeOnNonPrimaryFocusGain = true,
    this.closeImeOnNonPrimaryFocusLost = true,
    required this.child,
  }) : super(key: key);

  /// The document editor's [FocusNode], which is watched for changes based
  /// on this widget's [closeImeOnPrimaryFocusLost] policy.
  final FocusNode? focusNode;

  /// The input ID of the widget that owns this [ImeFocusPolicy].
  ///
  /// For example, this [ImeFocusPolicy] might be inside of a chat message
  /// editor - this [inputId] would uniquely identify the chat message editor
  /// vs any other input in the widget tree. It's used to manage IME ownership.
  final SuperImeInputId inputId;

  /// Factory method that creates a [TextInputClient], which is used to
  /// attach to the platform IME based on this widget's policy.
  final TextInputClient Function() imeClientFactory;

  /// The desired [TextInputConfiguration] for the IME connection, used
  /// when this widget attaches to the platform IME based on this widget's
  /// policy.
  final TextInputConfiguration imeConfiguration;

  /// Whether to open an [imeConnection] when the [FocusNode] gains primary focus.
  ///
  /// Defaults to `false`.
  final bool openImeOnPrimaryFocusGain;

  /// Whether to close the [imeConnection] when the [FocusNode] loses primary focus.
  ///
  /// Defaults to `false`.
  final bool closeImeOnPrimaryFocusLost;

  /// Whether to open an [imeConnection] when the [FocusNode] gains NON-primary focus.
  ///
  /// Defaults to `true`.
  final bool openImeOnNonPrimaryFocusGain;

  /// Whether to close the [imeConnection] when the [FocusNode] loses NON-primary focus.
  ///
  /// Defaults to `true`.
  final bool closeImeOnNonPrimaryFocusLost;

  final Widget child;

  @override
  State<ImeFocusPolicy> createState() => _ImeFocusPolicyState();
}

class _ImeFocusPolicyState extends State<ImeFocusPolicy> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = (widget.focusNode ?? FocusNode())..addListener(_onFocusChange);

    // Sync the keyboard with initial focus status. Do this at the end of the
    // frame just to make sure that any downstream code that runs when we open/close
    // the IME doesn't blow up by calling setState() during the build process.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onFocusChange();
    });
  }

  @override
  void didUpdateWidget(ImeFocusPolicy oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode.removeListener(_onFocusChange);
      _focusNode = (widget.focusNode ?? FocusNode())..addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && !SuperIme.instance.isOwner(widget.inputId)) {
      // We have focus but we don't own the IME. Take it over.
      SuperIme.instance.takeOwnership(widget.inputId);
    }

    bool shouldOpenIme = false;
    if (_focusNode.hasPrimaryFocus &&
        widget.openImeOnPrimaryFocusGain &&
        !SuperIme.instance.isInputAttachedToOS(widget.inputId)) {
      editorPoliciesLog
          .info("[${widget.runtimeType}] - Document editor gained primary focus. Opening an IME connection.");
      shouldOpenIme = true;
    } else if (!_focusNode.hasPrimaryFocus &&
        _focusNode.hasFocus &&
        widget.openImeOnNonPrimaryFocusGain &&
        !SuperIme.instance.isInputAttachedToOS(widget.inputId)) {
      editorPoliciesLog
          .info("[${widget.runtimeType}] - Document editor gained non-primary focus. Opening an IME connection.");
      shouldOpenIme = true;
    }

    if (shouldOpenIme) {
      WidgetsBinding.instance.runAsSoonAsPossible(() {
        if (!mounted) {
          return;
        }

        editorImeLog.finer("[${widget.runtimeType}] - creating new TextInputConnection to IME");
        SuperIme.instance.openConnection(
          widget.inputId,
          widget.imeClientFactory(),
          widget.imeConfiguration,
          showKeyboard: true,
        );
      }, debugLabel: 'Open IME Connection on Primary Focus Change');
    }

    bool shouldCloseIme = false;
    if (!_focusNode.hasPrimaryFocus && widget.closeImeOnPrimaryFocusLost && SuperIme.instance.isOwner(widget.inputId)) {
      editorPoliciesLog
          .info("[${widget.runtimeType}] - Document editor lost primary focus. Closing the IME connection.");
      shouldCloseIme = true;
    } else if (!_focusNode.hasFocus &&
        widget.closeImeOnNonPrimaryFocusLost &&
        SuperIme.instance.isOwner(widget.inputId)) {
      editorPoliciesLog.info("[${widget.runtimeType}] - Document editor lost all focus. Closing the IME connection.");
      shouldCloseIme = true;
    }

    if (shouldCloseIme) {
      SuperIme.instance
        ..clearConnection(widget.inputId)
        ..releaseOwnership(widget.inputId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Widget that enforces policies between IME connections, focus, and document selections.
///
/// This widget can automatically open and close the software keyboard when the document
/// selection changes, such as when the user places the caret in the middle of a
/// paragraph.
///
/// This widget can automatically remove the document selection when the editor loses focus.
class DocumentSelectionOpenAndCloseImePolicy extends StatefulWidget {
  const DocumentSelectionOpenAndCloseImePolicy({
    Key? key,
    required this.focusNode,
    this.isEnabled = true,
    required this.editor,
    required this.selection,
    required this.inputId,
    required this.imeClientFactory,
    required this.imeConfiguration,
    this.openKeyboardOnSelectionChange = true,
    this.closeKeyboardOnSelectionLost = true,
    this.clearSelectionWhenEditorLosesFocus = true,
    this.clearSelectionWhenImeConnectionCloses = true,
    required this.child,
  }) : super(key: key);

  /// The document editor's [FocusNode].
  ///
  /// Focus plays a role in multiple policies:
  ///
  ///  * When focus is lost, this widget may clear the editor's selection.
  ///
  ///  * When this widget closes the IME connection, it unfocuses this [focusNode].
  final FocusNode focusNode;

  /// Whether this widget's policies should be enabled.
  ///
  /// When `false`, this widget does nothing.
  final bool isEnabled;

  /// The [Editor] that alters the [selection].
  final Editor editor;

  /// The document editor's current selection.
  final ValueListenable<DocumentSelection?> selection;

  final SuperImeInputId inputId;

  /// Factory method that creates a [TextInputClient], which is used to
  /// attach to the platform IME based on this widget's selection policy.
  final TextInputClient Function() imeClientFactory;

  /// The desired [TextInputConfiguration] for the IME connection, used
  /// when this widget attaches to the platform IME based on this widget's
  /// selection policy.
  final TextInputConfiguration imeConfiguration;

  /// Whether the software keyboard should be raised whenever the editor's selection
  /// changes, such as when a user taps to place the caret.
  ///
  /// In a typical app, this property should be `true`. In some apps, the keyboard
  /// needs to be closed and opened to reveal special editing controls. In those cases
  /// this property should probably be `false`, and the app should take responsibility
  /// for opening and closing the keyboard.
  final bool openKeyboardOnSelectionChange;

  /// Whether the software keyboard should be closed whenever the editor goes from
  /// having a selection to not having a selection.
  ///
  /// In a typical app, this property should be `true`, because there's no place to
  /// apply IME input when there's no editor selection.
  final bool closeKeyboardOnSelectionLost;

  /// Whether the document's selection should be removed when the editor loses
  /// all focus (not just primary focus).
  ///
  /// If `true`, when focus moves to a different subtree, such as a popup text
  /// field, or a button somewhere else on the screen, the editor will remove
  /// its selection. When focus returns to the editor, the previous selection can
  /// be restored, but that's controlled by other policies.
  ///
  /// If `false`, the editor will retain its selection, including a visual caret
  /// and selected content, even when the editor doesn't have any focus, and can't
  /// process any input.
  final bool clearSelectionWhenEditorLosesFocus;

  /// Whether the editor's selection should be removed when the editor closes or loses
  /// its IME connection.
  ///
  /// Defaults to `true`.
  ///
  /// Apps that include a custom input mode, such as an editing panel that sometimes
  /// replaces the software keyboard, should set this to `false` and instead control the
  /// IME connection manually.
  final bool clearSelectionWhenImeConnectionCloses;

  final Widget child;

  @override
  State<DocumentSelectionOpenAndCloseImePolicy> createState() => _DocumentSelectionOpenAndCloseImePolicyState();
}

class _DocumentSelectionOpenAndCloseImePolicyState extends State<DocumentSelectionOpenAndCloseImePolicy> {
  bool _wasAttached = false;

  @override
  void initState() {
    super.initState();

    _wasAttached = SuperIme.instance.isInputAttachedToOS(widget.inputId);
    SuperIme.instance.addListener(_onConnectionChange);

    widget.focusNode.addListener(_onFocusChange);

    widget.selection.addListener(_onSelectionChange);
    if (widget.selection.value != null) {
      _onSelectionChange();
      _onConnectionChange();
    }
  }

  @override
  void didUpdateWidget(DocumentSelectionOpenAndCloseImePolicy oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
      _onFocusChange();
    }

    if (widget.selection != oldWidget.selection) {
      oldWidget.selection.removeListener(_onSelectionChange);
      widget.selection.addListener(_onSelectionChange);
      _onSelectionChange();
    }

    if (widget.inputId != oldWidget.inputId) {
      onNextFrame((_) {
        // We switched IME connection references, which means we may have switched
        // from one with a connection to one without a connection, or vis-a-versa.
        // Run our connection change check.
        //
        // Also, we run this at the end of the frame, because this call might clear
        // the document selection, which might cause other widgets in the tree
        // to call setState(), which would cause an exception during didUpdateWidget().
        _onConnectionChange();
      });
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    widget.selection.removeListener(_onSelectionChange);
    SuperIme.instance.removeListener(_onConnectionChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (!widget.isEnabled) {
      return;
    }

    if (!widget.focusNode.hasFocus && widget.clearSelectionWhenEditorLosesFocus) {
      editorPoliciesLog.info("[${widget.runtimeType}] - clearing editor selection because the editor lost all focus");
      widget.editor.execute([
        const ClearSelectionRequest(),
      ]);
    }

    if (!widget.focusNode.hasFocus) {
      widget.editor.execute([
        const ClearComposingRegionRequest(),
      ]);
    }
  }

  void _onSelectionChange() {
    if (!widget.isEnabled) {
      return;
    }

    if (widget.selection.value != null && widget.focusNode.hasPrimaryFocus && widget.openKeyboardOnSelectionChange) {
      // There's a new document selection, and our policy wants the keyboard to be
      // displayed whenever the selection changes. Show the keyboard.
      if (!SuperIme.instance.isOwner(widget.inputId)) {
        SuperIme.instance.takeOwnership(widget.inputId);
      }

      if (!SuperIme.instance.isInputAttachedToOS(widget.inputId)) {
        WidgetsBinding.instance.runAsSoonAsPossible(() {
          if (!mounted) {
            return;
          }
          // Ensure we didn't lose ownership across frame boundaries.
          if (!SuperIme.instance.isOwner(widget.inputId)) {
            return;
          }
          // Ensure that a connection wasn't opened between frames.
          if (SuperIme.instance.isInputAttachedToOS(widget.inputId)) {
            return;
          }

          editorPoliciesLog
              .info("[${widget.runtimeType}] - opening the IME keyboard because the document selection changed");
          editorImeConnectionLog.finer("[${widget.runtimeType}] - creating new TextInputConnection to IME");
          SuperIme.instance.openConnection(
            widget.inputId,
            widget.imeClientFactory(),
            widget.imeConfiguration,
            showKeyboard: true,
          );
        }, debugLabel: 'Open IME Connection on Selection Change');
      } else {
        SuperIme.instance.getImeConnectionForOwner(widget.inputId)!.show();
      }
    } else if (SuperIme.instance.isInputAttachedToOS(widget.inputId) &&
        widget.selection.value == null &&
        widget.closeKeyboardOnSelectionLost) {
      // There's no document selection, and our policy wants the keyboard to be
      // closed whenever the editor loses its selection. Close the keyboard.
      editorPoliciesLog
          .info("[${widget.runtimeType}] - closing the IME keyboard because the document selection was cleared");
      SuperIme.instance.clearConnection(widget.inputId);
    }
  }

  void _onConnectionChange() {
    if (!mounted) {
      return;
    }

    _clearSelectionIfDesired();

    _wasAttached = SuperIme.instance.isInputAttachedToOS(widget.inputId);
  }

  void _clearSelectionIfDesired() {
    if (!widget.isEnabled) {
      // None of this widget's policies are activated.
      return;
    }

    if (!widget.clearSelectionWhenImeConnectionCloses) {
      // This policy isn't activated.
      return;
    }

    if (!_wasAttached || SuperIme.instance.isInputAttachedToOS(widget.inputId)) {
      // We didn't go from closed to open. Our policy doesn't apply.

      return;
    }

    final hasNonPrimaryFocus = widget.focusNode.hasFocus && !widget.focusNode.hasPrimaryFocus;
    if (hasNonPrimaryFocus) {
      // We don't want to mess with selection when the editor has non-primary focus. Non-primary
      // focus means that the editor is in the focus path, but isn't receiving input. The editor
      // might currently be deferring to something like a URL toolbar, where the user is typing
      // a URL. The user expects the editor to keep its current selection while they type the URL.
      editorPoliciesLog.info(
          "[${widget.runtimeType}] - policy wants to clear selection because IME closed, but the editor has non-primary focus, so we aren't clearing the selection");
      return;
    }

    // The IME connection closed and our policy wants us to clear the document
    // selection when that happens.
    editorPoliciesLog.info(
        "[${widget.runtimeType}] - clearing document selection because the IME closed and the editor didn't have non-primary focus");
    widget.editor.execute([
      const ClearSelectionRequest(),
    ]);

    // If we clear SuperEditor's selection, but leave SuperEditor with primary focus,
    // then SuperEditor will automatically place the caret at the end of the document.
    // This is because SuperEditor always expects a place for text input when it
    // has primary focus. To prevent this from happening, we explicitly remove focus
    // from SuperEditor.
    widget.focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
