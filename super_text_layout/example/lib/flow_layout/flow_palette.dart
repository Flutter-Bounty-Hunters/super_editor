import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:super_text_layout/experimental_flow.dart';

/// An independent participant: canvas-drawn swatches, with breaks only between
/// groups of three. It uses neither FlowTextContent nor FlowAtomicContent.
class FlowPalette extends LeafRenderObjectWidget {
  const FlowPalette({super.key, this.id, this.count = 12});
  final Object? id;
  final int count;
  @override
  RenderFlowPalette createRenderObject(BuildContext context) =>
      RenderFlowPalette(count, id: id);
  @override
  void updateRenderObject(
      BuildContext context, RenderFlowPalette renderObject) {
    renderObject
      ..id = id
      ..count = count;
  }
}

class RenderFlowPalette extends RenderFlowParticipant {
  RenderFlowPalette(this._count, {super.id});
  int _count;
  set count(int value) {
    assert(value > 0);
    if (_count == value) {
      return;
    }
    _count = value;
    markNeedsLayout();
  }

  @override
  List<FlowContent> get content => [_PaletteContent(this, _count)];
  @override
  void performLayout() {}
  // Drawing comes from the exact artifact that the paragraph measured.
  @override
  void paint(PaintingContext context, Offset offset) {}
  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..textDirection = TextDirection.ltr
      ..label = 'Palette of $_count colour samples';
  }
}

class _PaletteContent extends FlowContent {
  _PaletteContent(RenderFlowPalette owner, int count)
      : super(owner, 0, count, const []);
  @override
  FlowPreparedContent prepare(FlowPreparationContext context) =>
      _PreparedPalette(context.content);
}

class _PreparedPalette extends FlowPreparedContent {
  _PreparedPalette(this.entry);
  final FlowContent entry;
  @override
  List<FlowContent> get entries => [entry];
  @override
  Iterable<FlowBreakOpportunity> breaksAfter(int start) sync* {
    for (var end = start + 3; end < length; end += 3) {
      yield FlowBreakOpportunity(end);
    }
    if (start < length) {
      yield FlowBreakOpportunity(length);
    }
  }

  @override
  FlowRangeMeasurement measureRange(
      TextRange range, FlowFragmentConstraints constraints) {
    if (range.start < 0 ||
        range.end > length ||
        range.start >= range.end ||
        range.start % 3 != 0 ||
        (range.end != length && range.end % 3 != 0)) {
      throw ArgumentError('Palette fragments must preserve groups of three.');
    }
    return _PaletteMeasurement(entry, range);
  }
}

class _PaletteMeasurement extends FlowRangeMeasurement {
  _PaletteMeasurement(this.entry, this.range);
  final FlowContent entry;
  @override
  final TextRange range;
  static const stride = 24.0;
  static const diameter = 18.0;
  @override
  double get width => (range.end - range.start) * stride - (stride - diameter);
  @override
  double get ascent => 16;
  @override
  double get descent => 2;
  Rect _box(int unit) =>
      Rect.fromLTWH((unit - range.start) * stride, 0, diameter, height);
  @override
  List<FlowLocalFragment> get fragments => [
        for (var unit = range.start; unit < range.end; unit++)
          FlowLocalFragment(
              entry, TextRange(start: unit, end: unit + 1), _box(unit)),
      ];
  @override
  void paint(Canvas canvas, Offset origin) {
    for (var unit = range.start; unit < range.end; unit++) {
      canvas.drawOval(
          _box(unit).shift(origin),
          Paint()
            ..color =
                HSVColor.fromAHSV(1, (unit * 31.0) % 360, .65, .85).toColor());
    }
  }

  @override
  List<Rect> boxesForRange(TextRange selection) => [
        for (var unit = math.max(range.start, selection.start);
            unit < math.min(range.end, selection.end);
            unit++)
          _box(unit),
      ];
  @override
  Offset caretAt(int offset, TextAffinity affinity, {Object? participant}) =>
      Offset(
          offset >= range.end
              ? width
              : math.max(0, offset - range.start) * stride,
          0);
  @override
  FlowPosition positionAt(Offset point) {
    final offset =
        (point.dx / stride).round().clamp(0, range.end - range.start) +
            range.start;
    return FlowPosition(entry.owner.identity, offset,
        affinity: offset == range.end
            ? TextAffinity.upstream
            : TextAffinity.downstream);
  }
}
