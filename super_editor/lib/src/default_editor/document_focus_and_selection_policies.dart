import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

/// Widget that applies policies to an editor's focus and selection, such as placing the
/// caret at the end of a document when the editor receives focus, and clearing the
/// selection when the editor loses focus.
class EditorSelectionAndFocusPolicy extends StatefulWidget {
  const EditorSelectionAndFocusPolicy({
    Key? key,
    required this.focusNode,
    required this.editor,
    required this.document,
    required this.selection,
    required this.isDocumentLayoutAvailable,
    required this.getDocumentLayout,
    this.placeCaretAtEndOfDocumentOnGainFocus = true,
    this.restorePreviousSelectionOnGainFocus = true,
    this.clearSelectionWhenEditorLosesFocus = true,
    required this.child,
  }) : super(key: key);

  /// Returns whether or not we can access the document layout, which is needed for [placeCaretAtEndOfDocumentOnGainFocus].
  ///
  /// When [SuperEditor] has `autofocus`, the focus change callback is called before we can access
  /// the document layout using [getDocumentLayout]. If [getDocumentLayout] is called before we can
  /// access the document layout we get an exception.
  ///
  /// When this method returns `true`, we assume it's safe to call [getDocumentLayout].
  final bool Function() isDocumentLayoutAvailable;

  /// The document editor's [FocusNode].
  ///
  /// When focus is lost, this widget may clear the editor's selection.
  final FocusNode focusNode;

  /// The [Editor], which alters the [document].
  final Editor editor;

  /// The editor's [Document].
  final Document document;

  /// The document editor's current selection.
  final ValueListenable<DocumentSelection?> selection;

  /// Document layout, used to locate the last selectable piece of content in a document,
  /// which is needed for [placeCaretAtEndOfDocumentOnGainFocus].
  final DocumentLayoutResolver getDocumentLayout;

  /// Whether the editor should automatically place the caret at the end of the document,
  /// if the editor receives focus without an existing selection.
  ///
  /// [restorePreviousSelectionOnGainFocus] takes priority over this policy.
  final bool placeCaretAtEndOfDocumentOnGainFocus;

  /// Whether the editor's previous selection should be restored when the editor re-gains
  /// focus, after having previous lost focus.
  final bool restorePreviousSelectionOnGainFocus;

  /// Whether the editor's selection should be removed when the editor loses
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

  final Widget child;

  @override
  State<EditorSelectionAndFocusPolicy> createState() => _EditorSelectionAndFocusPolicyState();
}

class _EditorSelectionAndFocusPolicyState extends State<EditorSelectionAndFocusPolicy> {
  bool _wasFocused = false;
  DocumentSelection? _previousSelection;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
    _wasFocused = widget.focusNode.hasFocus;

    widget.selection.addListener(_onSelectionChange);
    _previousSelection = widget.selection.value;
  }

  @override
  void didUpdateWidget(EditorSelectionAndFocusPolicy oldWidget) {
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
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    widget.selection.removeListener(_onSelectionChange);
    super.dispose();
  }

  void _onFocusChange() {
    // Ensure the editor has a selection when focused.
    if (!_wasFocused && widget.focusNode.hasFocus) {
      if (widget.restorePreviousSelectionOnGainFocus && _previousSelection != null) {
        if (widget.document.getNodeById(_previousSelection!.base.nodeId) == null ||
            widget.document.getNodeById(_previousSelection!.extent.nodeId) == null) {
          editorPoliciesLog.info(
              "[${widget.runtimeType}] - not restoring previous editor selection because one of the selected nodes was deleted");
          return;
        }

        if (widget.selection.value == _previousSelection) {
          // The editor already has the correct selection.
          return;
        }

        if (_previousSelection == null) {
          // There's no selection to restore.
          return;
        }

        // Restore the previous selection.
        editorPoliciesLog
            .info("[${widget.runtimeType}] - restoring previous editor selection because the editor re-gained focus");
        final previousSelection = _previousSelection!;
        late final DocumentSelection restoredSelection;
        final baseNode = widget.editor.context.document.getNodeById(previousSelection.base.nodeId);
        final extentNode = widget.editor.context.document.getNodeById(previousSelection.extent.nodeId);
        if (baseNode == null && extentNode == null) {
          // The node(s) where the selection was previously are gone. Possibly deleted.
          // Therefore, we can't restore the previous selection. Fizzle.
          return;
        }

        if (baseNode != null && extentNode != null) {
          if (!baseNode.containsPosition(previousSelection.base.nodePosition)) {
            // Either the base node content changed and the selection no longer fits, or the
            // type of content in the node changed. Either way, we can't restore this selection.
            return;
          }
          if (!extentNode.containsPosition(previousSelection.extent.nodePosition)) {
            // Either the extent node content changed and the selection no longer fits, or the
            // type of content in the node changed. Either way, we can't restore this selection.
            return;
          }

          // The base and extent nodes both still exist. Use the previous selection
          // without modification.
          restoredSelection = previousSelection;
        } else if (baseNode == null) {
          // The base node disappeared, but the extent node remains.
          if (!extentNode!.containsPosition(previousSelection.extent.nodePosition)) {
            // Either the extent node content changed and the selection no longer fits, or the
            // type of content in the node changed. Either way, we can't restore this selection.
            return;
          }

          restoredSelection = DocumentSelection.collapsed(position: previousSelection.extent);
        } else if (extentNode == null) {
          // The extent node disappeared, but the base node remains.
          if (!baseNode.containsPosition(previousSelection.base.nodePosition)) {
            // Either the base node content changed and the selection no longer fits, or the
            // type of content in the node changed. Either way, we can't restore this selection.
            return;
          }

          restoredSelection = DocumentSelection.collapsed(position: previousSelection.base);
        }

        widget.editor.execute([
          ChangeSelectionRequest(
            restoredSelection,
            restoredSelection.isCollapsed ? SelectionChangeType.placeCaret : SelectionChangeType.expandSelection,
            SelectionReason.contentChange,
          ),
        ]);
      } else if (widget.placeCaretAtEndOfDocumentOnGainFocus) {
        // Place the caret at the end of the document.
        editorPoliciesLog
            .info("[${widget.runtimeType}] - placing caret at end of document because the editor gained focus");
        if (!widget.isDocumentLayoutAvailable()) {
          // We are focused, but the document hasn't been laid out yet. This could happen if SuperEditor has autofocus.
          // Wait until the end of the frame, so we have access to the document layout.
          editorPoliciesLog.info(
              "[${widget.runtimeType}] - the document hasn't been laid out yet. Trying again at the end of the frame");
          WidgetsBinding.instance.scheduleFrameCallback((timeStamp) {
            if (!mounted) {
              return;
            }

            _onFocusChange();
          });
          return;
        }

        DocumentPosition? position = widget.getDocumentLayout().findLastSelectablePosition();
        if (position != null) {
          widget.editor.execute([
            ChangeSelectionRequest(
              DocumentSelection.collapsed(
                position: position,
              ),
              SelectionChangeType.placeCaret,
              SelectionReason.contentChange,
            ),
          ]);
        }
      }
    }

    // (Maybe) remove the editor's selection when it loses focus.
    if (!widget.focusNode.hasFocus && widget.clearSelectionWhenEditorLosesFocus) {
      editorPoliciesLog.info("[${widget.runtimeType}] - clearing editor selection because the editor lost all focus");

      widget.editor.execute([
        const ClearSelectionRequest(),
      ]);
    }

    _wasFocused = widget.focusNode.hasFocus;
  }

  void _onSelectionChange() {
    // TODO: avoiding null selections isn't always the right thing to do. If the editor purposefully clears
    //       its selection, we wouldn't want to restore the previous selection when focus changes.
    if (widget.selection.value != null) {
      _previousSelection = widget.selection.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
