import 'package:flutter/material.dart' show TextOverflow;
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/default_editor/layout_single_column/layout_single_column.dart';
import 'package:super_editor/src/default_editor/super_editor.dart';
import 'package:super_editor/src/default_editor/text.dart';

/// A [SuperEditorPlugin] that adds the concept of a "preview mode", intended for chat use-cases,
/// where a user might open a chat screen with a draft message, and only the beginning of the
/// message should be displayed.
class ChatPreviewModePlugin extends SuperEditorPlugin {
  final _previewStylePhase = ChatPreviewStylePhase();

  bool get isInPreviewMode => _previewStylePhase.isInPreviewMode;
  set isInPreviewMode(bool newValue) => _previewStylePhase.isInPreviewMode = newValue;

  @override
  List<SingleColumnLayoutStylePhase> get appendedStylePhases => <SingleColumnLayoutStylePhase>[
        _previewStylePhase,
      ];
}

class ChatPreviewStylePhase extends SingleColumnLayoutStylePhase {
  ChatPreviewStylePhase({
    bool isInPreviewMode = false,
  }) : _isInPreviewMode = isInPreviewMode;

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
        ..maxLines = 1
        ..overflow = TextOverflow.ellipsis;
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
