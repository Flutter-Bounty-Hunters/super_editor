import 'package:flutter/painting.dart';
import 'package:super_editor/src/core/styles.dart';

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
    _stylesheetChanged = true;
    markDirty();
  }

  /// Whether the [stylesheet] changed since this phase last styled.
  bool _stylesheetChanged = false;

  /// Restyles the changed components and the ones next to them, or all of
  /// them when the [stylesheet] changed.
  ///
  /// A [BlockSelector] can depend on a node's neighbors, as with
  /// [BlockSelector.after] and [BlockSelector.before], and its index, which
  /// only changes when nodes are added, removed, or moved, and then the whole
  /// document is styled again. A rule's styler must depend on no more than
  /// that.
  @override
  SingleColumnLayoutViewModel styleChanges(
    Document document,
    SingleColumnLayoutViewModel viewModel, {
    required SingleColumnLayoutViewModel previousOutput,
    required Set<String> changedNodeIds,
  }) {
    if (_stylesheetChanged) {
      return style(document, viewModel);
    }

    final restyle = <String>{};
    for (final nodeId in changedNodeIds) {
      final index = document.getNodeIndexById(nodeId);
      if (index < 0) {
        return style(document, viewModel);
      }
      restyle.add(nodeId);
      if (index > 0) {
        restyle.add(document.getNodeAt(index - 1)!.id);
      }
      if (index + 1 < document.nodeCount) {
        restyle.add(document.getNodeAt(index + 1)!.id);
      }
    }

    return restyleOnly(
      viewModel,
      nodeIds: restyle,
      previousOutput: previousOutput,
      padding: _stylesheet.documentPadding ?? viewModel.padding,
      styleComponent: (component) => _styleComponent(
        document,
        document.getNodeById(component.nodeId)!,
        component.copy(),
      ),
    );
  }

  @override
  SingleColumnLayoutViewModel style(Document document, SingleColumnLayoutViewModel viewModel) {
    _stylesheetChanged = false;
    return SingleColumnLayoutViewModel(
      padding: _stylesheet.documentPadding ?? viewModel.padding,
      componentViewModels: [
        for (final componentViewModel in viewModel.componentViewModels)
          _styleComponent(
            document,
            document.getNodeById(componentViewModel.nodeId)!,
            componentViewModel.copy(),
          ),
      ],
    );
  }

  SingleColumnLayoutComponentViewModel _styleComponent(
    Document document,
    DocumentNode node,
    SingleColumnLayoutComponentViewModel viewModel,
  ) {
    // Combine all applicable style rules into a single set of styles
    // for this component.
    final aggregateStyles = <String, dynamic>{
      Styles.inlineTextStyler: _stylesheet.inlineTextStyler,
      Styles.inlineWidgetBuilders: _stylesheet.inlineWidgetBuilders,
    };
    for (final rule in _stylesheet.rules) {
      if (rule.selector.matches(document, node)) {
        _mergeStyles(
          existingStyles: aggregateStyles,
          newStyles: rule.styler(document, node),
        );
      }
    }

    viewModel.applyStyles(aggregateStyles);

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
