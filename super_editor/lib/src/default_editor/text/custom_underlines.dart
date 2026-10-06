import 'dart:ui';

import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/styles.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/default_editor/layout_single_column/_presenter.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_text_layout/super_text_layout.dart';

/// A style phase that inspects [TextComponentViewModel]s, finds text with
/// [CustomUnderlineAttribution]s and adds underline configurations to that
/// view model for each such attribution span.
///
/// The [TextComponentViewModel]s then configure some kind of `TextComponent`,
/// which finally paints the desired underline.
///
/// To associate an underline type with a visual style, see [CustomUnderlineStyles].
class CustomUnderlineStyler extends SingleColumnLayoutStylePhase {
  /// Restyles the changed components: each one's underlines come from its
  /// own text.
  @override
  SingleColumnLayoutViewModel styleChanges(
    Document document,
    SingleColumnLayoutViewModel viewModel, {
    required SingleColumnLayoutViewModel previousOutput,
    required Set<String> changedNodeIds,
  }) {
    return restyleOnly(
      viewModel,
      nodeIds: changedNodeIds,
      previousOutput: previousOutput,
      styleComponent: (component) => _applyUnderlines(component.copy()),
    );
  }

  @override
  SingleColumnLayoutViewModel style(Document document, SingleColumnLayoutViewModel viewModel) {
    final updatedViewModel = SingleColumnLayoutViewModel(
      padding: viewModel.padding,
      componentViewModels: [
        for (final previousViewModel in viewModel.componentViewModels) //
          _applyUnderlines(previousViewModel.copy()),
      ],
    );

    return updatedViewModel;
  }

  SingleColumnLayoutComponentViewModel _applyUnderlines(SingleColumnLayoutComponentViewModel viewModel) {
    if (viewModel is! TextComponentViewModel) {
      return viewModel;
    }

    final underlineSpans = viewModel.text.getAttributionSpansByFilter((a) => a is CustomUnderlineAttribution);
    if (underlineSpans.isEmpty) {
      return viewModel;
    }

    // Add each attributed underline to the text view model.
    viewModel.customUnderlines.clear();
    for (final span in underlineSpans) {
      final underlineAttribution = span.attribution as CustomUnderlineAttribution;

      viewModel.customUnderlines.add(
        CustomUnderline(
          underlineAttribution.type,
          TextRange(start: span.start, end: span.end + 1),
          // ^ +1 because SpanRange is inclusive and TextRange is exclusive.
        ),
      );
    }

    return viewModel;
  }
}

/// A data structure that describes how various custom underline styles should
/// be painted.
///
/// This data structure is a glorified map, which maps from underline names,
/// such as "squiggle", to an underline style, such as `SquiggleUnderlineStyle`.
///
/// A [CustomUnderlineStyles] can be placed in a document stylesheet in a style
/// rule with a key of [Styles.customUnderlineStyles].
class CustomUnderlineStyles {
  const CustomUnderlineStyles(this.stylesByType);

  /// Map from a custom underline type to its painter.
  final Map<String, UnderlineStyle> stylesByType;

  CustomUnderlineStyles copy() {
    return CustomUnderlineStyles(Map.from(stylesByType));
  }

  CustomUnderlineStyles addStyles(Map<String, UnderlineStyle> newStyles) {
    return CustomUnderlineStyles({
      ...stylesByType,
      ...newStyles,
    });
  }
}

/// Data structure, which describes a [type] of underline, which should be painted
/// across the given [textRange].
///
/// A [CustomUnderline] applies to a given piece of text - it does not encode any
/// particular document node/position.
class CustomUnderline {
  const CustomUnderline(this.type, this.textRange);

  /// A name that represents the type of underline, which maps to some painting
  /// style, e.g., "straight", "squiggle".
  ///
  /// The [type] can be anything - it's meaning is determined by the style system.
  final String type;

  /// The range of text within some text block to which this underline applies.
  final TextRange textRange;
}
