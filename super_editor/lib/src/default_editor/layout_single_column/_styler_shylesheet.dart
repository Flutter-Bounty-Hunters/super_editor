import 'package:flutter/painting.dart';
import 'package:super_editor/src/core/styles.dart';

import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/default_editor/layout_single_column/_presenter.dart';

/// Style phase that applies a given [Stylesheet] to the document view model.
class SingleColumnStylesheetStyler extends SingleColumnLayoutStylePhase {
  /// Creates a [SingleColumnStylesheetStyler] that applies the given [stylesheet]
  /// to the document view model.
  ///
  /// The `defaultTextStyle` is Flutter's default text style, which should be provided
  /// as the result of `DefaultTextStyle.of(context)`. If it's `non-null`, the stylesheet text
  /// styles are applied on top of the base style, taking priority. If `null`,  the stylesheet
  /// text styles are applied directly. Has no effect if [Stylesheet.inheritDefaultTextStyle] is `false`.
  SingleColumnStylesheetStyler({
    required Stylesheet stylesheet,
    TextStyle? defaultTextStyle,
  })  : _stylesheet = stylesheet,
        _defaultTextStyle = defaultTextStyle;

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

  TextStyle? _defaultTextStyle;

  /// The default Flutter text style that applies to the document that this presenter is styling,
  /// which users must set to `DefaultTextStyle.of(context)`.
  ///
  /// Stylesheets include the concept of "inheriting the default text style". This requires that
  /// stylesheets have access to the default text style. However, stylesheets are not given access
  /// to the widget tree, and therefore they can't query this value on their own. Instead, users
  /// of `SingleColumnStylesheetStyler` must provide the default text style to this styler, so that
  /// this styler can provide it to the stylesheet.
  ///
  /// Has no effect if [Stylesheet.inheritDefaultTextStyle] is `false`.
  ///
  /// If [newDefaultTextStyle] is the same as the existing default text style,
  /// this method does nothing.
  ///
  /// If [newDefaultTextStyle] is different than the existing default text style,
  /// this method marks this style phase a dirty, which will cause the associated presenter
  /// to re-run this style phase, and all presentation phases after it.
  set defaultTextStyle(TextStyle? newDefaultTextStyle) {
    if (newDefaultTextStyle == _defaultTextStyle) {
      return;
    }

    _defaultTextStyle = newDefaultTextStyle;
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

    if (_stylesheet.inheritDefaultTextStyle && _defaultTextStyle != null) {
      // We have a default text style, use it as the base for all text styles.
      //
      // Stylesheet text styles are applied on top of the base style, taking priority.
      aggregateStyles[Styles.textStyle] = _defaultTextStyle!;
    }

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
