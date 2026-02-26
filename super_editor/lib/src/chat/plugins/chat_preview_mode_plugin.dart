import 'package:flutter/material.dart' show TextOverflow;
import 'package:flutter/widgets.dart' show FocusNode;
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/default_editor/layout_single_column/layout_single_column.dart';
import 'package:super_editor/src/default_editor/super_editor.dart';
import 'package:super_editor/src/default_editor/text.dart';

/// A [SuperEditorPlugin] that adds the concept of a "preview mode", intended for chat use-cases,
/// where a user might open a chat screen with a draft message, and only the beginning of the
/// message should be displayed.
class ChatPreviewModePlugin extends SuperEditorPlugin {
  final _previewStylePhase = ChatPreviewStylePhase();

  /// Returns `true` if this plugin is currently restricting the editor visuals
  /// to "preview mode", or `false` if this plugin is doing nothing.
  bool get isInPreviewMode => _previewStylePhase.isInPreviewMode;

  set _isInPreviewMode(bool newValue) => _previewStylePhase.isInPreviewMode = newValue;

  bool _isModeLocked = false;

  /// Sets this plugin to "preview mode", regardless of the current focus state, and
  /// keeps it there until [unlockDisplayMode] is called.
  void lockInPreviewMode() {
    _isModeLocked = true;
    _isInPreviewMode = true;
  }

  /// Sets this plugin to "normal mode" (not preview), regardless of the current focus
  /// state, and keeps it there until [unlockDisplayMode] is called.
  void lockInNormalMode() {
    _isModeLocked = true;
    _isInPreviewMode = false;
  }

  /// Undoes any previous call to [lockInPreviewMode] or [lockInNormalMode], and synchronizes
  /// "preview mode" with the editor's focus state.
  void unlockDisplayMode() {
    _isModeLocked = false;
    _syncPreviewModeWithFocus();
  }

  bool _hasFocus = false;

  @override
  void onFocusChange(FocusNode editorFocusNode) {
    _hasFocus = editorFocusNode.hasFocus;

    if (!_isModeLocked) {
      _syncPreviewModeWithFocus();
    }
  }

  /// Sets the plugin to "preview mode" if the editor isn't focused, or "normal mode" if
  /// it is focused.
  void _syncPreviewModeWithFocus() {
    _isInPreviewMode = !_hasFocus;
  }

  @override
  List<SingleColumnLayoutStylePhase> get appendedStylePhases => <SingleColumnLayoutStylePhase>[
        _previewStylePhase,
      ];
}

/// A [SingleColumnLayoutStylePhase], which restricts the output of the document
/// view model to just a "preview mode".
///
/// The "preview mode" version removes all component view models after the first
/// view model, and if the first view model is a text model, it's re-configured to
/// restrict to the given [maxLines], and use the given [overflow] indicator.
class ChatPreviewStylePhase extends SingleColumnLayoutStylePhase {
  ChatPreviewStylePhase({
    bool isInPreviewMode = false,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  }) : _isInPreviewMode = isInPreviewMode;

  /// The max number of lines of text to display within the first text component,
  /// when [isInPreviewMode].
  final int maxLines;

  /// The [TextOverflow] indicator to use, when truncating text in the first text
  /// component, due to [maxLines].
  final TextOverflow overflow;

  bool get isInPreviewMode => _isInPreviewMode;
  late bool _isInPreviewMode;
  set isInPreviewMode(bool newValue) {
    if (newValue == _isInPreviewMode) {
      return;
    }

    _isInPreviewMode = newValue;
    markDirty();
  }

  @override
  SingleColumnLayoutViewModel style(Document document, SingleColumnLayoutViewModel viewModel) {
    if (!_isInPreviewMode) {
      // We're not in preview mode. Don't mess with the view model.
      return viewModel;
    }

    if (viewModel.componentViewModels.isEmpty) {
      return viewModel;
    }

    var firstViewModel = viewModel.componentViewModels.first;
    if (firstViewModel is TextComponentViewModel) {
      firstViewModel = (firstViewModel.copy() as TextComponentViewModel)
        ..maxLines = maxLines
        ..overflow = overflow;
    }

    // In preview mode, only show the first node/component.
    return SingleColumnLayoutViewModel(
      componentViewModels: [
        firstViewModel,
      ],
      padding: viewModel.padding,
    );
  }
}
