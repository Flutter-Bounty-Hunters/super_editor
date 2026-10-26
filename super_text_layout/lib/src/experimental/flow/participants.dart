part of 'flow.dart';

/// Measurement is separate from committing placements. The revision is unique
/// per paragraph layout so invalidations cannot leave stale child measurements.
class FlowMeasureConstraints extends Constraints {
  const FlowMeasureConstraints(this.maxWidth, this.revision);
  final double maxWidth;
  final Object revision;
  @override
  bool get isTight => false;
  @override
  bool get isNormalized => maxWidth.isFinite && maxWidth >= 0;
}

/// Content supplied by participants. Sequence order defines reading order;
/// [start]/[end] identify locations inside the owning participant only.
abstract class FlowContent {
  FlowContent(this.owner, this.start, this.end, this.decorations);
  final RenderFlowParticipant owner;
  final int start;
  final int end;
  int get length => end - start;
  final List<RenderFlowDecoration> decorations;
  FlowTextContent? get textContribution => null;
  FlowPreparedContent prepare(FlowPreparationContext context);
  FlowContent withDecorations(List<RenderFlowDecoration> decorations) =>
      _DecoratedContent(this, List.unmodifiable(decorations));
}

class FlowTextContent extends FlowContent {
  FlowTextContent(RenderFlowParticipant owner, this.text, this.style,
      {List<RenderFlowDecoration> decorations = const []})
      : super(owner, 0, text.length, decorations);
  final String text;
  final TextStyle style;
  @override
  FlowTextContent get textContribution => this;
  @override
  FlowPreparedContent prepare(FlowPreparationContext context) =>
      _PreparedText([context.content], context.paragraphStyle);
}

/// An indivisible piece. A custom participant can emit several atomic pieces,
/// choosing its own local offsets and painting the committed fragments itself.
class FlowAtomicContent extends FlowContent {
  FlowAtomicContent(RenderFlowParticipant owner, this.size, this.baseline,
      {int offset = 0, List<RenderFlowDecoration> decorations = const []})
      : super(owner, offset, offset + 1, decorations);
  final Size size;
  final double baseline;
  @override
  FlowPreparedContent prepare(FlowPreparationContext context) =>
      _PreparedAtom(context.content, this);
}

abstract class RenderFlowParticipant extends RenderObject {
  RenderFlowParticipant({Object? id}) : _id = id;
  Object get identity => _id ?? this;
  Object? _id;
  set id(Object? value) {
    if (_id == value) {
      return;
    }
    _id = value;
    markNeedsLayout();
  }

  List<FlowContent> get content;
  List<FlowFragment> get fragments => _fragments;
  List<FlowFragment> _fragments = const [];

  FlowMeasureConstraints get flowConstraints =>
      constraints as FlowMeasureConstraints;

  @override
  void performResize() {}

  @override
  void debugAssertDoesMeetConstraints() {}

  /// Called only after the paragraph has selected its final layout. Candidate
  /// exploration never writes fragment state or creates widget instances.
  void commitFragments(FlowLayoutSnapshot layout) {
    _fragments = List.unmodifiable(layout.fragmentsFor(identity));
    visitChildren((child) {
      if (child is RenderFlowParticipant) {
        child.commitFragments(layout);
      }
    });
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  Rect get paintBounds {
    Rect? bounds;
    for (final piece in fragments) {
      bounds = bounds?.expandToInclude(piece.bounds) ?? piece.bounds;
    }
    visitChildren((child) {
      if (child is RenderFlowParticipant && !child.paintBounds.isEmpty) {
        bounds =
            bounds?.expandToInclude(child.paintBounds) ?? child.paintBounds;
      }
    });
    return bounds ?? Rect.zero;
  }

  @override
  Rect get semanticBounds => paintBounds;

  /// All flow participants share the paragraph's coordinate plane. Ordinary
  /// box children cross that boundary in RenderFlowBoxAdapter instead.
  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {}

  bool hitTestFlow(BoxHitTestResult result, Offset position) => false;
}

class FlowText extends LeafRenderObjectWidget {
  const FlowText(this.text,
      {super.key, this.id, this.style = const TextStyle()});
  final String text;
  final Object? id;
  final TextStyle style;
  @override
  RenderFlowText createRenderObject(BuildContext context) =>
      RenderFlowText(text, DefaultTextStyle.of(context).style.merge(style),
          id: id);
  @override
  void updateRenderObject(BuildContext context, RenderFlowText renderObject) {
    renderObject
      ..id = id
      ..update(text, DefaultTextStyle.of(context).style.merge(style));
  }
}

class RenderFlowText extends RenderFlowParticipant {
  RenderFlowText(this._text, this._style, {super.id});
  String _text;
  TextStyle _style;
  void update(String text, TextStyle style) {
    if (_text == text && _style == style) {
      return;
    }
    _text = text;
    _style = style;
    markNeedsLayout();
  }

  @override
  List<FlowContent> get content => [FlowTextContent(this, _text, _style)];
  @override
  void performLayout() {}
  // The paragraph paints shared text runs once, preserving shaping across
  // adjacent text participants and decoration-only wrappers.
  @override
  void paint(PaintingContext context, Offset offset) {}
  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..textDirection = TextDirection.ltr
      ..label = _text;
  }
}

class _FlowParentData extends ParentData
    with ContainerParentDataMixin<RenderFlowParticipant> {}

/// A fragmentable sequence of children. It introduces no document indices.
class FlowSequence extends MultiChildRenderObjectWidget {
  const FlowSequence({super.key, super.children = const [], this.id});
  final Object? id;
  @override
  RenderFlowSequence createRenderObject(BuildContext context) =>
      RenderFlowSequence(id: id);
  @override
  void updateRenderObject(
      BuildContext context, RenderFlowSequence renderObject) {
    renderObject.id = id;
  }
}

class RenderFlowSequence extends RenderFlowParticipant
    with ContainerRenderObjectMixin<RenderFlowParticipant, _FlowParentData> {
  RenderFlowSequence({super.id});
  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! _FlowParentData) {
      child.parentData = _FlowParentData();
    }
  }

  List<RenderFlowParticipant> get flowChildren {
    final result = <RenderFlowParticipant>[];
    var child = firstChild;
    while (child != null) {
      result.add(child);
      child = (child.parentData! as _FlowParentData).nextSibling;
    }
    return result;
  }

  @override
  List<FlowContent> get content =>
      [for (final child in flowChildren) ...child.content];
  @override
  void performLayout() {
    for (final child in flowChildren) {
      child.layout(flowConstraints, parentUsesSize: true);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in flowChildren) {
      context.paintChild(child, offset);
    }
  }

  @override
  bool hitTestFlow(BoxHitTestResult result, Offset position) {
    for (final child in flowChildren.reversed) {
      if (child.hitTestFlow(result, position)) {
        return true;
      }
    }
    return false;
  }
}

/// Fragment padding is cloned at each segment/line boundary. A zero-padding
/// decoration remains transparent to text shaping and word boundaries.
class FlowDecoration extends SingleChildRenderObjectWidget {
  const FlowDecoration(
      {super.key,
      required super.child,
      this.id,
      this.padding = EdgeInsets.zero,
      this.color = const Color(0xFFE8EAF0),
      this.radius = 6});
  final Object? id;
  final EdgeInsets padding;
  final Color color;
  final double radius;
  @override
  RenderFlowDecoration createRenderObject(BuildContext context) =>
      RenderFlowDecoration(
          id: id, padding: padding, color: color, radius: radius);
  @override
  void updateRenderObject(
      BuildContext context, RenderFlowDecoration renderObject) {
    renderObject
      ..id = id
      ..update(padding, color, radius);
  }
}

class RenderFlowDecoration extends RenderFlowParticipant
    with RenderObjectWithChildMixin<RenderFlowParticipant> {
  RenderFlowDecoration(
      {super.id,
      required this.padding,
      required this.color,
      required this.radius});
  EdgeInsets padding;
  Color color;
  double radius;
  void update(EdgeInsets newPadding, Color newColor, double newRadius) {
    if (padding == newPadding && color == newColor && radius == newRadius) {
      return;
    }
    padding = newPadding;
    color = newColor;
    radius = newRadius;
    markNeedsLayout();
  }

  @override
  List<FlowContent> get content => [
        for (final entry in child?.content ?? <FlowContent>[])
          entry.withDecorations([this, ...entry.decorations]),
      ];
  @override
  void performLayout() {
    child?.layout(
        FlowMeasureConstraints(
            math.max(0, flowConstraints.maxWidth - padding.horizontal),
            flowConstraints.revision),
        parentUsesSize: true);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final fragment in fragments) {
      context.canvas.drawRRect(
          RRect.fromRectAndRadius(
              fragment.bounds.shift(offset), Radius.circular(radius)),
          Paint()..color = color);
    }
    if (child != null) {
      context.paintChild(child!, offset);
    }
  }

  @override
  bool hitTestFlow(BoxHitTestResult result, Offset position) =>
      child?.hitTestFlow(result, position) ?? false;
}

/// Adapts an existing widget as one indivisible piece. Its State and render
/// object are retained when its position or the number of surrounding fragments changes.
class FlowBox extends SingleChildRenderObjectWidget {
  const FlowBox({super.key, required super.child, this.id});
  final Object? id;
  @override
  RenderFlowBoxAdapter createRenderObject(BuildContext context) =>
      RenderFlowBoxAdapter(id: id);
  @override
  void updateRenderObject(
      BuildContext context, RenderFlowBoxAdapter renderObject) {
    renderObject.id = id;
  }
}

class RenderFlowBoxAdapter extends RenderFlowParticipant
    with RenderObjectWithChildMixin<RenderBox> {
  RenderFlowBoxAdapter({super.id});
  List<FlowContent> _content = const [];
  @override
  List<FlowContent> get content => _content;
  @override
  void performLayout() {
    child?.layout(BoxConstraints(maxWidth: flowConstraints.maxWidth),
        parentUsesSize: true);
    _content = child == null
        ? []
        : [
            FlowAtomicContent(
                this,
                child!.size,
                child!.getDistanceToBaseline(TextBaseline.alphabetic,
                        onlyReal: true) ??
                    child!.size.height)
          ];
  }

  Offset get _childOffset =>
      fragments.isEmpty ? Offset.zero : fragments.first.bounds.topLeft;
  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null && fragments.isNotEmpty) {
      context.paintChild(child!, offset + _childOffset);
    }
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    transform.translateByDouble(_childOffset.dx, _childOffset.dy, 0, 1);
  }

  @override
  bool hitTestFlow(BoxHitTestResult result, Offset position) {
    if (child == null || fragments.isEmpty) {
      return false;
    }
    return result.addWithPaintOffset(
        offset: _childOffset,
        position: position,
        hitTest: (result, transformed) =>
            child!.hitTest(result, position: transformed));
  }
}
