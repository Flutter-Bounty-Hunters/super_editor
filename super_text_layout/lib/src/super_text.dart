import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:super_text_layout/super_text_layout_logging.dart';

import 'text_layout.dart';

/// Displays text with a visual layer above the text, and a visual layer
/// beneath the text, which can be used to add text decorations, like
/// selections and carets.
///
/// To display a widget that includes standard text selection display,
/// see [SuperTextWithSelection].
///
/// The layers in a [SuperText] are built by provided [SuperTextLayerBuilder]s.
/// These builders are similar to a typical `WidgetBuilder`, except that
/// [SuperTextLayerBuilder]s are also given a reference to the [TextLayout]
/// within this [SuperText]. The layer builders can then use the [TextLayout] to
/// position widgets and paint coordinates near lines and characters in the text.
///
/// If you discover performance issues with your [SuperText], consider wrapping
/// the [SuperTextLayerBuilder] content with [RepaintBoundary]s, which might prevent
/// unnecessary repaints between your layers and the text content.
class SuperText extends StatefulWidget {
  const SuperText({
    Key? key,
    required this.richText,
    this.textAlign = TextAlign.left,
    this.textDirection = TextDirection.ltr,
    this.textScaler,
    this.layerBeneathBuilder,
    this.layerAboveBuilder,
    this.debugTrackTextBuilds = false,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  }) : super(key: key);

  /// The text to display in this [SuperText] widget.
  final InlineSpan richText;

  /// The alignment to use for [richText] display.
  final TextAlign textAlign;

  /// The text direction to use for [richText] display.
  final TextDirection textDirection;

  /// Builds a widget that appears beneath the text, e.g., to render text
  /// selection boxes.
  final SuperTextLayerBuilder? layerBeneathBuilder;

  /// Builds a widget that appears above the text, e.g., to render a caret.
  final SuperTextLayerBuilder? layerAboveBuilder;

  /// Whether this [SuperText] widget should track the number of times it
  /// builds its inner rich text, so that tests can ensure the inner text
  /// is not rebuilt unnecessarily, due to text decorations.
  final bool debugTrackTextBuilds;

  /// The text scaling policy.
  ///
  /// Defaults to `MediaQuery.textScalerOf`.
  final TextScaler? textScaler;

  /// The maximum number of lines to display.
  ///
  /// If null, the text will be displayed without truncation.
  /// If set, the text will be limited to the specified number of lines.
  final int? maxLines;

  /// How to handle text overflow.
  ///
  /// Defaults to [TextOverflow.clip].
  final TextOverflow overflow;

  @override
  State<SuperText> createState() => SuperTextState();
}

@visibleForTesting
class SuperTextState extends ProseTextState<SuperText> with ProseTextBlock {
  final _textLayoutKey = GlobalKey();
  @override
  ProseTextLayout get textLayout => RenderSuperTextLayout.textLayoutFrom(_textLayoutKey)!;

  int _textBuildCount = 0;
  @visibleForTesting
  int get textBuildCount => _textBuildCount;

  RenderLayoutAwareParagraph? _paragraph;
  void _invalidateParagraph() => _paragraph = null;

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      if (widget.debugTrackTextBuilds || SuperTextAnalytics.of(context)?.trackBuilds == true) {
        _textBuildCount += 1;
      }
    }

    return _SuperTextLayout(
      key: _textLayoutKey,
      state: this,
      text: LayoutAwareRichText(
        text: widget.richText,
        textAlign: widget.textAlign,
        textDirection: widget.textDirection,
        textScaler: widget.textScaler ?? MediaQuery.textScalerOf(context),
        onMarkNeedsLayout: _invalidateParagraph,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
      ),
      background: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final background = widget.layerBeneathBuilder;
          if (background != null && _paragraph != null) {
            return background(
              context,
              RenderParagraphProseTextLayout(
                richText: widget.richText,
                renderParagraph: _paragraph!,
              ),
            );
          } else {
            return const SizedBox();
          }
        },
      ),
      foreground: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final foreground = widget.layerAboveBuilder;
          if (foreground != null && _paragraph != null) {
            return foreground(
              context,
              RenderParagraphProseTextLayout(
                richText: widget.richText,
                renderParagraph: _paragraph!,
              ),
            );
          } else {
            return const SizedBox();
          }
        },
      ),
    );
  }
}

@visibleForTesting
class SuperTextAnalytics extends InheritedWidget {
  static SuperTextAnalytics? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SuperTextAnalytics>();
  }

  const SuperTextAnalytics({
    Key? key,
    this.trackBuilds = false,
    required Widget child,
  }) : super(
          key: key,
          child: child,
        );

  final bool trackBuilds;

  @override
  bool updateShouldNotify(SuperTextAnalytics oldWidget) {
    return trackBuilds != oldWidget.trackBuilds;
  }
}

class _SuperTextLayout extends MultiChildRenderObjectWidget {
  _SuperTextLayout({
    Key? key,
    required this.state,
    required LayoutAwareRichText text,
    required Widget foreground,
    required Widget background,
  }) : super(key: key, children: [background, text, foreground]);

  final SuperTextState state;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderSuperTextLayout(state: state);
  }

  @override
  void updateRenderObject(BuildContext context, RenderSuperTextLayout renderObject) {
    renderObject.state = state;
  }
}

class _SuperTextLayoutParentData extends ContainerBoxParentData<RenderBox> {}

class RenderSuperTextLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _SuperTextLayoutParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _SuperTextLayoutParentData> {
  /// Returns the [ProseTextLayout] within a [SuperText] that's connected
  /// to the given [key].
  static ProseTextLayout? textLayoutFrom(GlobalKey key) {
    final renderTextLayout = key.currentContext?.findRenderObject() as RenderSuperTextLayout?;
    if (renderTextLayout == null || renderTextLayout.state._paragraph == null) {
      return null;
    }

    return RenderParagraphProseTextLayout(
      richText: renderTextLayout.state.widget.richText,
      renderParagraph: renderTextLayout.state._paragraph!,
    );
  }

  RenderSuperTextLayout({
    required SuperTextState state,
  }) : _state = state;

  SuperTextState? _state;

  SuperTextState get state => _state!;

  set state(SuperTextState value) {
    if (_state != value) {
      _state = value;
      markNeedsLayout();
      markNeedsPaint();
    }
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _SuperTextLayoutParentData) {
      child.parentData = _SuperTextLayoutParentData();
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    final children = getChildrenAsList();
    final text = children[1];
    return text.getMinIntrinsicWidth(height);
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final children = getChildrenAsList();
    final text = children[1];
    return text.getMaxIntrinsicWidth(height);
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    final children = getChildrenAsList();
    final text = children[1];
    return text.getMinIntrinsicHeight(width);
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final children = getChildrenAsList();
    final text = children[1];
    return text.getMaxIntrinsicHeight(width);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final children = getChildrenAsList();
    final text = children[1];
    return text.getDryLayout(constraints);
  }

  @override
  void performLayout() {
    layoutLog.info("Running SuperText layout. Incoming constraints: $constraints");
    final children = getChildrenAsList();
    final background = children[0];
    final text = children[1];
    final foreground = children[2];

    text.layout(constraints, parentUsesSize: true);
    state._paragraph = text as RenderLayoutAwareParagraph;
    layoutLog.info("SuperText text layout size: ${text.size}");

    final layerConstraints = BoxConstraints.tight(text.size);

    layoutLog.finer("Laying out SuperText background layer. Constraints: $layerConstraints");
    background.layout(layerConstraints);

    layoutLog.finer("Laying out SuperText foreground layer. Constraints: $layerConstraints");
    foreground.layout(layerConstraints);

    size = text.size;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}

/// A version of [RichText] that notifies clients when the underlying
/// [RenderParagraph] invalidates its layout, so that clients can avoid
/// accessing properties when the layout is invalid.
@visibleForTesting
class LayoutAwareRichText extends RichText {
  LayoutAwareRichText({
    Key? key,
    required InlineSpan text,
    TextAlign textAlign = TextAlign.left,
    TextDirection textDirection = TextDirection.ltr,
    TextScaler textScaler = TextScaler.noScaling,
    required this.onMarkNeedsLayout,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  }) : super(
          key: key,
          text: text,
          textAlign: textAlign,
          textDirection: textDirection,
          textScaler: textScaler,
        );

  /// Callback invoked when the underlying [RenderParagraph] invalidates
  /// its layout.
  final VoidCallback onMarkNeedsLayout;

  /// The maximum number of lines to display.
  final int? maxLines;

  /// How to handle text overflow.
  final TextOverflow overflow;

  @override
  RenderLayoutAwareParagraph createRenderObject(BuildContext context) {
    assert(textDirection != null || debugCheckHasDirectionality(context));
    return RenderLayoutAwareParagraph(
      text,
      textAlign: textAlign,
      textDirection: textDirection ?? Directionality.of(context),
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      strutStyle: strutStyle,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      locale: locale ?? Localizations.maybeLocaleOf(context),
      onMarkNeedsLayout: onMarkNeedsLayout,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderLayoutAwareParagraph renderObject) {
    assert(textDirection != null || debugCheckHasDirectionality(context));
    renderObject
      ..text = text
      ..textAlign = textAlign
      ..textDirection = textDirection ?? Directionality.of(context)
      ..softWrap = softWrap
      ..overflow = overflow
      ..textScaler = textScaler
      ..maxLines = maxLines
      ..strutStyle = strutStyle
      ..textWidthBasis = textWidthBasis
      ..textHeightBehavior = textHeightBehavior
      ..locale = locale ?? Localizations.maybeLocaleOf(context)
      ..onMarkNeedsLayout = onMarkNeedsLayout;
  }
}

/// A [RenderParagraph] that publicly reports whether or not its
/// layout is valid, and also accepts a callback to notify a listener
/// when the layout is marked invalid.
class RenderLayoutAwareParagraph extends RenderParagraph {
  RenderLayoutAwareParagraph(
    InlineSpan text, {
    TextAlign textAlign = TextAlign.start,
    required TextDirection textDirection,
    bool softWrap = true,
    TextOverflow overflow = TextOverflow.clip,
    TextScaler textScaler = TextScaler.noScaling,
    int? maxLines,
    Locale? locale,
    StrutStyle? strutStyle,
    TextWidthBasis textWidthBasis = TextWidthBasis.parent,
    TextHeightBehavior? textHeightBehavior,
    List<RenderBox>? children,
    VoidCallback? onMarkNeedsLayout,
  })  : _onMarkNeedsLayout = onMarkNeedsLayout,
        super(
          text,
          textAlign: textAlign,
          textDirection: textDirection,
          softWrap: softWrap,
          overflow: overflow,
          textScaler: textScaler,
          maxLines: maxLines,
          locale: locale,
          strutStyle: strutStyle,
          textWidthBasis: textWidthBasis,
          textHeightBehavior: textHeightBehavior,
          children: children,
        );

  VoidCallback? get onMarkNeedsLayout => _onMarkNeedsLayout;
  VoidCallback? _onMarkNeedsLayout;
  set onMarkNeedsLayout(VoidCallback? value) {
    if (_onMarkNeedsLayout != value) {
      _onMarkNeedsLayout = value;
    }
  }

  // We override the default textAlign setter because Flutter's RenderParagraph setter
  // only calls markNeedsPaint, not markNeedsLayout. However, changing alignment does
  // change the layout of the text.
  //
  // https://github.com/flutter/flutter/issues/140756
  @override
  set textAlign(TextAlign value) {
    if (value == super.textAlign) {
      return;
    }

    super.textAlign = value;
    markNeedsLayout();
  }

  bool get needsLayout => _needsLayout;
  bool _needsLayout = true;

  @override
  void markNeedsLayout() {
    super.markNeedsLayout();
    _needsLayout = true;
    _onMarkNeedsLayout?.call();
  }

  @override
  void performLayout() {
    super.performLayout();
    _needsLayout = false;

    // FIXME: Remove this after Flutter #155620 is fixed.
    // Directly measure the line height for non-empty text because Flutter's
    // measurement for empty text is wrong for a random set of font sizes.
    if (text.toPlainText().isEmpty) {
      final textStyle = text.style;
      if (textStyle != null) {
        _textPainter
          ..text = TextSpan(text: "a", style: textStyle)
          ..textDirection = textDirection
          ..textAlign = textAlign
          ..layout();

        // We have no text, so we set the height of this render object to the line height
        // of an arbitrary character of the given style. However, it's possible that our
        // parent render object imposed constraints that are shorter than a single line
        // of text. To avoid breaking Flutter's layout rules, we take the minimum height
        // between the single line of text, and the incoming height constraints.
        size = constraints.constrain(Size(size.width, _textPainter.height));
      }
    }
  }

  final _textPainter = TextPainter();
}

typedef SuperTextLayerBuilder = Widget Function(BuildContext, TextLayout textLayout);

/// A [SuperTextLayerBuilder] that combines multiple other layers into a single
/// layer, to be displayed above or beneath [SuperText].
///
/// The layers are drawn bottom-to-top, with the bottom layer being the first
/// layer in the list of layers.
class MultiLayerBuilder {
  const MultiLayerBuilder(this._layers);

  final List<SuperTextLayerBuilder> _layers;

  Widget build(BuildContext context, TextLayout textLayout) {
    return Stack(
      children: [
        for (final layer in _layers) //
          layer(context, textLayout),
      ],
    );
  }
}
