import 'dart:ui';

import 'package:flutter/material.dart' show TextOverflow;
import 'package:flutter/widgets.dart' show FocusNode, EdgeInsets;
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/default_editor/layout_single_column/layout_single_column.dart';
import 'package:super_editor/src/default_editor/list_items.dart';
import 'package:super_editor/src/default_editor/super_editor.dart';
import 'package:super_editor/src/default_editor/text.dart';

/// A [SuperEditorPlugin] that adds the concept of a "preview mode", intended for chat use-cases,
/// where a user might open a chat screen with a draft message, and only the beginning of the
/// message should be displayed.
class ChatPreviewModePlugin extends SuperEditorPlugin {
  static const defaultPreviewAdjusters = [
    shortenPreviewText,
    adjustListItemPadding,
  ];

  /// A preview adjuster that cuts off the text in a text component after the first
  /// line, and inserts an ellipsis overflow indicator.
  ///
  /// Does nothing if it's not given a [TextComponentViewModel].
  static SingleColumnLayoutComponentViewModel shortenPreviewText(
    Document document,
    SingleColumnLayoutComponentViewModel previewViewModel,
  ) {
    if (previewViewModel is! TextComponentViewModel) {
      return previewViewModel;
    }

    return previewViewModel //
      ..maxLines = 1
      ..overflow = TextOverflow.ellipsis;
  }

  /// A preview adjuster that reduces the left-side padding on a list item, and
  /// also sets the bottom padding to match the top padding, so that the list item
  /// component can be vertically centered in the preview editor.
  ///
  /// Does nothing if it's not given a [ListItemComponentViewModel].
  static SingleColumnLayoutComponentViewModel adjustListItemPadding(
    Document document,
    SingleColumnLayoutComponentViewModel previewModel,
  ) {
    if (previewModel is! ListItemComponentViewModel) {
      return previewModel;
    }

    return previewModel
      ..padding = previewModel.padding.subtract(
        EdgeInsets.only(left: previewModel.padding.resolve(TextDirection.ltr).left),
      );
  }

  ChatPreviewModePlugin({
    List<PreviewComponentViewModelAdjuster> previewAdjusters = defaultPreviewAdjusters,
  }) {
    _previewStylePhase = ChatPreviewStylePhase(
      previewAdjusters: previewAdjusters,
    );
  }

  set previewAdjusters(List<PreviewComponentViewModelAdjuster> previewAdjusters) {
    _previewStylePhase.previewAdjusters
      ..clear()
      ..addAll(previewAdjusters);
  }

  late final ChatPreviewStylePhase _previewStylePhase;

  /// Returns `true` if this plugin is currently restricting the editor visuals
  /// to "preview mode", or `false` if this plugin is doing nothing.
  bool get isInPreviewMode => _previewStylePhase.isInPreviewMode;
  set isInPreviewMode(bool newValue) => _previewStylePhase.isInPreviewMode = newValue;

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
/// The "preview mode" version consists of two changes:
///  1. Only the first component in the document is displayed.
///  2. The view model for the first component might be altered by [previewAdjusters]
///     so that the component looks different in preview mode, e.g., a paragraph
///     view model might be limited to a single line, with ellipsis overflow, when
///     in preview mode.
class ChatPreviewStylePhase extends SingleColumnLayoutStylePhase {
  ChatPreviewStylePhase({
    bool isInPreviewMode = false,
    List<PreviewComponentViewModelAdjuster> previewAdjusters = const [],
  }) : _isInPreviewMode = isInPreviewMode {
    // We create a list here so that the list is modifiable (not const).
    this.previewAdjusters = [...previewAdjusters];
  }

  bool get isInPreviewMode => _isInPreviewMode;
  late bool _isInPreviewMode;
  set isInPreviewMode(bool newValue) {
    if (newValue == _isInPreviewMode) {
      return;
    }

    _isInPreviewMode = newValue;
    markDirty();
  }

  late final List<PreviewComponentViewModelAdjuster> previewAdjusters;

  @override
  SingleColumnLayoutViewModel style(Document document, SingleColumnLayoutViewModel viewModel) {
    if (!_isInPreviewMode) {
      // We're not in preview mode. Don't mess with the view model.
      return viewModel;
    }

    if (viewModel.componentViewModels.isEmpty) {
      return viewModel;
    }

    // Adjust the appearance of the preview view model, e.g., limit text to a single line.
    var firstViewModel = viewModel.componentViewModels.first.copy();
    for (final adjuster in previewAdjusters) {
      firstViewModel = adjuster(document, firstViewModel);
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

/// A function that takes the current preview component view model and returns an
/// adjusted version of that view model, which allows apps to make unique adjustments
/// and/or adjust non-standard view models that Super Editor doesn't know about.
///
/// Example: Custom padding - your app wants to add or remove padding in preview mode
/// to better fit your specific editor. That can be done with an adjuster.
///
/// Example: Custom component - your app includes its own `MyTableComponent` and you
/// want a preview version of that component. You can identify the incoming
/// `MyTableComponentViewModel` and then produce whatever kind of view model your
/// app wants to use for its preview display.
typedef PreviewComponentViewModelAdjuster = SingleColumnLayoutComponentViewModel Function(
  Document document,
  SingleColumnLayoutComponentViewModel previewViewModel,
);
