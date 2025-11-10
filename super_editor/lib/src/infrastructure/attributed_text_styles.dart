import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

/// Creates the desired [TextStyle] given the [attributions] associated
/// with a span of text.
///
/// The [attributions] set may be empty.
typedef AttributionStyleBuilder = TextStyle Function(Set<Attribution> attributions);

extension ToSpanRange on TextRange {
  SpanRange toSpanRange() => SpanRange(start, end);
}

extension ComputeTextSpan on AttributedText {
  /// Returns a Flutter [InlineSpan] comprised of styled text and widgets
  /// based on an [AttributedText].
  ///
  /// The given [styleBuilder] interprets the meaning of every attribution
  /// and constructs [TextStyle]s accordingly.
  ///
  /// The given [inlineWidgetBuilders] interprets every placeholder `Object`
  /// and builds a corresponding inline widget.
  ///
  /// If [defaultTextStyle] is non-`null`, the [TextStyle] computed by [styleBuilder]
  /// is applied on top of the [defaultTextStyle], taking priority.
  InlineSpan computeInlineSpan(
    BuildContext context,
    AttributionStyleBuilder styleBuilder,
    InlineWidgetBuilderChain inlineWidgetBuilders, {
    TextStyle? defaultTextStyle,
  }) {
    if (isEmpty) {
      // There is no text and therefore no attributions.
      return TextSpan(
        text: '',
        style: defaultTextStyle != null //
            ? defaultTextStyle.merge(styleBuilder({}))
            : styleBuilder({}),
      );
    }

    final inlineSpans = <InlineSpan>[];

    final collapsedSpans = spans.collapseSpans(contentLength: length);

    for (final span in collapsedSpans) {
      final textStyle = defaultTextStyle != null
          ? defaultTextStyle.merge(styleBuilder(span.attributions))
          : styleBuilder(span.attributions);

      // A single span might be divided in multiple inline spans if there are placeholders.
      // Keep track of the start of the current inline span.
      int startOfMostRecentTextRun = span.start;

      // Look for placeholders within the current span and split the span accordingly.
      for (int i = span.start; i <= span.end; i++) {
        if (placeholders[i] != null) {
          // We found a placeholder. Build a widget for it.

          if (i > startOfMostRecentTextRun) {
            // There is text before the placeholder. Add the current text run to the span.
            inlineSpans.add(
              TextSpan(
                text: substring(startOfMostRecentTextRun, i),
                style: textStyle,
              ),
            );
          }

          Widget? inlineWidget;
          for (final builder in inlineWidgetBuilders) {
            inlineWidget = builder(context, textStyle, placeholders[i]!);
            if (inlineWidget != null) {
              break;
            }
          }

          if (inlineWidget != null) {
            inlineSpans.add(
              _LayoutOptimizedWidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: inlineWidget,
              ),
            );
          }

          // Start another inline span after the placeholder.
          startOfMostRecentTextRun = i + 1;
        }
      }

      if (startOfMostRecentTextRun <= span.end) {
        // There is text after the last placeholder or there is no placeholder at all.
        inlineSpans.add(
          TextSpan(
            text: substring(startOfMostRecentTextRun, span.end + 1),
            style: textStyle,
          ),
        );
      }
    }

    return TextSpan(
      text: "",
      children: inlineSpans,
      style: styleBuilder({}),
    );
  }

  /// Returns a Flutter [TextSpan] that is styled based on the
  /// attributions within this [AttributedText].
  ///
  /// The given [styleBuilder] interprets the meaning of every
  /// attribution and constructs [TextStyle]s accordingly.
  @Deprecated("Use computeInlineSpan() instead, which adds support for inline widgets.")
  TextSpan computeTextSpan(AttributionStyleBuilder styleBuilder) {
    attributionsLog.fine('text length: ${text.length}');
    attributionsLog.fine('attributions used to compute spans:');
    attributionsLog.fine(spans.toString());

    if (text.isEmpty) {
      // There is no text and therefore no attributions.
      attributionsLog.fine('text is empty. Returning empty TextSpan.');
      return TextSpan(text: '', style: styleBuilder({}));
    }

    final collapsedSpans = spans.collapseSpans(contentLength: text.length);
    final textSpans = collapsedSpans
        .map((attributedSpan) => TextSpan(
              text: text.substring(attributedSpan.start, attributedSpan.end + 1),
              style: styleBuilder(attributedSpan.attributions),
            ))
        .toList();

    return textSpans.length == 1
        ? textSpans.first
        : TextSpan(
            children: textSpans,
            style: styleBuilder({}),
          );
  }
}

/// A Chain of Responsibility that builds widgets for text inline placeholders.
///
/// The first [InlineWidgetBuilder] that returns a non-null [Widget] is used by
/// the client.
typedef InlineWidgetBuilderChain = List<InlineWidgetBuilder>;

/// Builder that returns a [Widget] for a given [placeholder], or `null`
/// if this builder doesn't know how to build the given [placeholder].
///
/// The given [textStyle] is the style applied to the text in the vicinity
/// of the placeholder.
typedef InlineWidgetBuilder = Widget? Function(
  BuildContext context,
  TextStyle textStyle,
  Object placeholder,
);

/// A [WidgetSpan] that does not re-layout its child changed.
///
/// The [WidgetSpan] class always invalidates its layout when the child
/// widget changes. However, this shouldn't happen, since invalidating
/// the layout should happen at `RenderObject` level.
///
/// When the child widget do change its layout, i.e., by changing its size,
/// the build pipeline will already mark the layout as dirty.
class _LayoutOptimizedWidgetSpan extends WidgetSpan {
  const _LayoutOptimizedWidgetSpan({
    required Widget child,
    required PlaceholderAlignment alignment,
  }) : super(child: child, alignment: alignment);

  @override
  RenderComparison compareTo(InlineSpan other) {
    if (identical(this, other)) {
      return RenderComparison.identical;
    }
    if (other.runtimeType != runtimeType) {
      return RenderComparison.layout;
    }
    if ((style == null) != (other.style == null)) {
      return RenderComparison.layout;
    }
    final typedOther = other as WidgetSpan;
    if (alignment != typedOther.alignment) {
      return RenderComparison.layout;
    }
    RenderComparison result = RenderComparison.identical;
    if (style != null) {
      final candidate = style!.compareTo(other.style!);
      if (candidate.index > result.index) {
        result = candidate;
      }
      if (result == RenderComparison.layout) {
        return result;
      }
    }
    return result;
  }
}
