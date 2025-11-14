import 'package:flutter/painting.dart';
import 'package:super_editor/src/core/styles.dart';
import 'package:super_editor/src/default_editor/layout_single_column/composite_nodes.dart';

import '../../core/document.dart';
import '_presenter.dart';

/// Style phase that applies a given [Stylesheet] to the document view model.
class SingleColumnStylesheetStyler extends SingleColumnLayoutStylePhase {
  SingleColumnStylesheetStyler({
    required Stylesheet stylesheet,
  }) : _stylesheet = stylesheet;

  Stylesheet _stylesheet;

  /// Sets the [stylesheet] that's used by this styler to generate view models
  /// for document content.
  ///
  /// If [newStylesheet] is the same as the existing stylesheet, this method
  /// does nothing.
  ///
  /// If [newStylesheet] is different than the existing stylesheet, this method
  /// marks this style phase a dirty, which will cause the associated presenter
  /// to re-run this style phase, and all presentation phases after it.
  set stylesheet(Stylesheet newStylesheet) {
    if (newStylesheet == _stylesheet) {
      return;
    }

    _stylesheet = newStylesheet;
    markDirty();
  }

  @override
  SingleColumnLayoutViewModel style(Document document, SingleColumnLayoutViewModel viewModel) {
    return SingleColumnLayoutViewModel(
      padding: _stylesheet.documentPadding ?? viewModel.padding,
      componentViewModels: [
        for (final componentViewModel in viewModel.componentViewModels)
          _styleComponent(
            document,
            document.getNodeById(componentViewModel.nodeId)!,
            null,
            componentViewModel.copy(),
          ),
      ],
    );
  }

  // TODO: We need to pass DocumentPosition here, not just [node] in order to
  // before / next API get working.
  SingleColumnLayoutComponentViewModel _styleComponent(
    Document document,
    DocumentNode node,
    DocumentNode? parent,
    SingleColumnLayoutComponentViewModel viewModel,
  ) {
    // print("_styleComponent() - node: $node, viewModel: $viewModel");

    // Combine all applicable style rules into a single set of styles
    // for this component.
    final aggregateStyles = <String, dynamic>{
      Styles.inlineTextStyler: _stylesheet.inlineTextStyler,
      Styles.inlineWidgetBuilders: _stylesheet.inlineWidgetBuilders,
    };
    for (final rule in _stylesheet.rules) {
      if (rule.selector.matches(document, node, parent)) {
        _mergeStyles(
          existingStyles: aggregateStyles,
          newStyles: rule.styler(document, node),
        );
      }
    }

    viewModel.applyStyles(aggregateStyles);

    if (node is CompositeNode && viewModel is CompositeNodeViewModel) {
      // print(" - this is a composite node. Styling recursively.");
      for (int i = 0; i < node.children.length; i += 1) {
        // print(" - styling sub-view model: ${viewModel.children[i]}");
        _styleComponent(document, node.getChildAt(i), node, viewModel.children[i]);
      }
    }

    return viewModel;
  }

  void _mergeStyles({
    required Map<String, dynamic> existingStyles,
    required Map<String, dynamic> newStyles,
  }) {
    for (final entry in newStyles.entries) {
      if (existingStyles.containsKey(entry.key)) {
        // Try to merge. If we can't, then overwrite.
        final oldValue = existingStyles[entry.key];
        final newValue = entry.value;

        if (oldValue is TextStyle && newValue is TextStyle) {
          existingStyles[entry.key] = oldValue.merge(newValue);
        } else if (oldValue is CascadingPadding && newValue is CascadingPadding) {
          existingStyles[entry.key] = newValue.applyOnTopOf(oldValue);
        }
      } else {
        // This is a new entry, just set it.
        existingStyles[entry.key] = entry.value;
      }
    }
  }
}
