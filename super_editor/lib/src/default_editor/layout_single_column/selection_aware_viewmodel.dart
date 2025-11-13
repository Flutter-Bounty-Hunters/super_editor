import 'package:flutter/material.dart';
import 'package:super_editor/src/core/document.dart' show NodeSelection;
import 'package:super_editor/src/core/styles.dart';
import 'package:super_editor/src/default_editor/layout_single_column/layout_single_column.dart';

/// Allows a [SingleColumnLayoutComponentViewModel] to be aware of the selection within its node.
///
/// This mixin enables non-text components, to render their selection.
///
/// During the styling pipeline, any [SingleColumnLayoutComponentViewModel] that mixes in
/// [SelectionAwareViewModelMixin] will have its [selection] and [selectionColor] properties set.
///
/// In the [SingleColumnLayoutComponentViewModel.copy] subclass implementation, both [selection] and
/// [selectionColor] must be copied to the new instance.
mixin SelectionAwareViewModelMixin on SingleColumnLayoutComponentViewModel {
  /// The selection within the node represented by this view model.
  DocumentNodeSelection? selection;

  /// The color to be applied to the selection.
  ///
  /// During the styling pass, this color is set according to the [SelectionStyles] used.
  Color selectionColor = Colors.transparent;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is SelectionAwareViewModelMixin &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          selection == other.selection &&
          selectionColor == other.selectionColor;

  @override
  int get hashCode => super.hashCode ^ nodeId.hashCode ^ selection.hashCode ^ selectionColor.hashCode;
}
