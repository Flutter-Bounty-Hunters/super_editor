/// Isolated measurement experiment. Not used by FlowParagraph.
library;

import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:super_text_layout/experimental_flow.dart';

class CheckpointSource {
  CheckpointSource(this.text, this.style) {
    owner = RenderFlowText(text, style, id: 'checkpoint');
    final entry = owner.content.single;
    exact = entry.prepare(FlowPreparationContext(entry, style));
    breaks = exact.breaksAfter(0).toList();
    if (breaks.any((b) => b.kind == FlowBreakKind.required)) {
      throw ArgumentError('Hard breaks are outside this first checkpoint.');
    }
  }
  final String text;
  final TextStyle style;
  late final RenderFlowText owner;
  late final FlowPreparedContent exact;
  late final List<FlowBreakOpportunity> breaks;
  int measurements = 0;

  double measure(int start, int end, double maximum) {
    measurements++;
    final m = exact.measureRange(
        TextRange(start: start, end: end),
        FlowFragmentConstraints(
            availableWidth: maximum, maximumWidth: maximum));
    try {
      return m.width;
    } finally {
      m.dispose();
    }
  }

  void dispose() => owner.dispose();
}

abstract interface class PreparedWidthModel {
  int get length;
  List<int> get ordinary;
  List<int> get emergency;
  int get measurementCalls;
  int get fragmentEntries;
  int get joinEntries;
  double width(int start, int end);
}

class PreparedSegments implements PreparedWidthModel {
  PreparedSegments(CheckpointSource source,
      {this.correctJoins = true, this.contextualFragments = true}) {
    length = source.text.length;
    ordinary = source.breaks
        .where((b) => b.kind != FlowBreakKind.emergency)
        .map((b) => b.offset)
        .toList();
    emergency = source.breaks
        .where((b) => b.kind == FlowBreakKind.emergency)
        .map((b) => b.offset)
        .toList();
    final cache = <String, double>{};
    double measure(String text) => cache.putIfAbsent(text, () {
          measurementCalls++;
          final painter = TextPainter(
              text: TextSpan(style: source.style, children: [
                TextSpan(text: text, style: source.style),
              ]),
              textDirection: TextDirection.ltr)
            ..layout();
          try {
            return painter.width;
          } finally {
            painter.dispose();
          }
        });
    var start = 0;
    for (final end in ordinary) {
      final text = source.text.substring(start, end);
      final offsets = <int>[start];
      final advances = <double>[0];
      for (final grapheme in text.characters) {
        offsets.add(offsets.last + grapheme.length);
        advances.add(advances.last + measure(grapheme));
      }
      final segment = _Segment(start, end, measure(text), offsets, advances);
      if (contextualFragments) {
        for (var a = 0; a < offsets.length - 1; a++) {
          for (var b = a + 1; b < offsets.length; b++) {
            segment.fragments[(offsets[a], offsets[b])] =
                measure(source.text.substring(offsets[a], offsets[b]));
          }
        }
      }
      segments.add(segment);
      totals.add(totals.last + segment.fullWidth);
      start = end;
    }
    for (var i = 0; i < segments.length; i++) {
      final correction = !correctJoins || i == 0
          ? 0.0
          : measure(source.text
                  .substring(segments[i - 1].start, segments[i].end)) -
              segments[i - 1].fullWidth -
              segments[i].fullWidth;
      joins.add(joins.last + correction);
      final pairs = <(int, int), double>{};
      if (contextualFragments && correctJoins && i > 0) {
        for (final from in segments[i - 1]
            .offsets
            .take(segments[i - 1].offsets.length - 1)) {
          for (final to in segments[i].offsets.skip(1)) {
            pairs[(from, to)] = measure(source.text.substring(from, to));
          }
        }
      }
      pairWidths.add(pairs);
    }
  }
  final bool correctJoins;
  final bool contextualFragments;
  final pairWidths = <Map<(int, int), double>>[];
  @override
  int get fragmentEntries => segments.fold(0, (n, s) => n + s.fragments.length);
  @override
  int get joinEntries => pairWidths.fold(0, (n, pairs) => n + pairs.length);
  final joins = <double>[0];
  @override
  late final int length;
  @override
  late final List<int> ordinary, emergency;
  final segments = <_Segment>[];
  final totals = <double>[0];
  @override
  int measurementCalls = 0;

  @override
  double width(int start, int end) {
    final first = _upper(ordinary, start);
    final last = _upper(ordinary, end - 1);
    if (first == last) return segments[first].width(start, end);
    if (contextualFragments && correctJoins) {
      if (last == first + 1) return pairWidths[last][(start, end)]!;
      final leading = segments[first].width(start, segments[first].end);
      final trailing = segments[last].width(segments[last].start, end);
      final leadingJoin = pairWidths[first + 1]
              [(start, segments[first + 1].end)]! -
          leading -
          segments[first + 1].fullWidth;
      final trailingJoin = pairWidths[last][(segments[last - 1].start, end)]! -
          segments[last - 1].fullWidth -
          trailing;
      // Interior joins keep the checkpoint-2 correction. Edge joins are
      // measured with exactly the suffix/prefix that the new line retains.
      return leading +
          totals[last] -
          totals[first + 1] +
          trailing +
          leadingJoin +
          trailingJoin +
          joins[last] -
          joins[first + 2];
    }
    // Historical checkpoint-1/2 models remain available for comparisons.
    final correction =
        start == segments[first].start && end == segments[last].end
            ? joins[last + 1] - joins[first + 1]
            : 0.0;
    return correction +
        segments[first].width(start, segments[first].end) +
        totals[last] -
        totals[first + 1] +
        segments[last].width(segments[last].start, end);
  }
}

class _Segment {
  _Segment(this.start, this.end, this.fullWidth, this.offsets, this.advances);
  final int start, end;
  final double fullWidth;
  final List<int> offsets;
  final List<double> advances;
  final fragments = <(int, int), double>{};
  double width(int from, int to) {
    if (from == start && to == end) return fullWidth;
    final contextual = fragments[(from, to)];
    if (contextual != null) return contextual;
    final a = _upper(offsets, from) - 1, b = _upper(offsets, to) - 1;
    if (offsets[a] != from || offsets[b] != to) {
      throw StateError('A legal break split a grapheme');
    }
    return advances[b] - advances[a];
  }
}

int _upper(List<int> values, int value) {
  var low = 0, high = values.length;
  while (low < high) {
    final mid = (low + high) ~/ 2;
    if (values[mid] <= value) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  return low;
}

class CheckpointLine {
  const CheckpointLine(this.row, this.start, this.end, this.width);
  final int row, start, end;
  final double width;
  Map<String, Object> toJson() =>
      {'row': row, 'start': start, 'end': end, 'width': width};
}

/// Same ordinary-before-emergency, maximum-width rule as the exact composer.
/// Both walkers search numeric candidates exhaustively: this isolates the
/// measurement model from search heuristics or monotonicity assumptions.
List<CheckpointLine> fitCheckpoint(
    {required int length,
    required List<int> ordinary,
    required List<int> emergency,
    required List<double> widths,
    required double Function(int, int) measure}) {
  if (widths.isEmpty || widths.any((w) => !w.isFinite || w <= 0)) {
    throw ArgumentError('Widths must be finite and positive');
  }
  final maximum = widths.reduce(math.max);
  final lines = <CheckpointLine>[];
  var start = 0, row = 0;
  while (start < length) {
    if (row > length * widths.length + 10) {
      throw StateError('No layout progress');
    }
    final available = widths[row % widths.length];
    CheckpointLine? choose(List<int> candidates) {
      for (var i = candidates.length - 1;
          i >= 0 && candidates[i] > start;
          i--) {
        final width = measure(start, candidates[i]);
        if (width <= available + .01) {
          return CheckpointLine(row, start, candidates[i], width);
        }
      }
      return null;
    }

    var selected = choose(ordinary);
    if (selected == null) {
      final first = _upper(ordinary, start);
      if (first == ordinary.length ||
          measure(start, ordinary[first]) > maximum + .01) {
        selected = choose(emergency);
      }
    }
    if (selected != null) {
      lines.add(selected);
      start = selected.end;
    }
    row++;
  }
  return lines;
}

List<CheckpointLine> fitExact(CheckpointSource source, List<double> widths) =>
    fitCheckpoint(
        length: source.text.length,
        ordinary: source.breaks
            .where((b) => b.kind != FlowBreakKind.emergency)
            .map((b) => b.offset)
            .toList(),
        emergency: source.breaks
            .where((b) => b.kind == FlowBreakKind.emergency)
            .map((b) => b.offset)
            .toList(),
        widths: widths,
        measure: (a, b) => source.measure(a, b, widths.reduce(math.max)));

List<CheckpointLine> fitPrepared(
        PreparedWidthModel prepared, List<double> widths) =>
    fitCheckpoint(
        length: prepared.length,
        ordinary: prepared.ordinary,
        emergency: prepared.emergency,
        widths: widths,
        measure: prepared.width);

/// Bounded-context experiment. Interactions longer than maxContext are omitted;
/// equivalence is tested, not guaranteed for arbitrary font shaping.
class CompactPreparedSegments implements PreparedWidthModel {
  CompactPreparedSegments(CheckpointSource source,
      {this.maxContext = 3,
      InlineSpan Function(int, int)? spanForRange,
      bool Function(int, int)? canPrepareRange}) {
    if (maxContext < 1) throw ArgumentError.value(maxContext);
    length = source.text.length;
    ordinary = source.breaks
        .where((b) => b.kind != FlowBreakKind.emergency)
        .map((b) => b.offset)
        .toList();
    emergency = source.breaks
        .where((b) => b.kind == FlowBreakKind.emergency)
        .map((b) => b.offset)
        .toList();
    for (final grapheme in source.text.characters) {
      offsets.add(offsets.last + grapheme.length);
    }
    final cache = <Object, double>{};
    double measure(int a, int b) {
      if (a == b) return 0;
      final text = source.text.substring(offsets[a], offsets[b]);
      final customSpan = spanForRange?.call(offsets[a], offsets[b]);
      return cache.putIfAbsent(customSpan ?? text, () {
        measurementCalls++;
        final span = customSpan ??
            TextSpan(
                style: source.style,
                children: [TextSpan(text: text, style: source.style)]);
        final painter =
            TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
        try {
          return painter.width;
        } finally {
          painter.dispose();
        }
      });
    }

    final count = offsets.length - 1;
    for (var size = 1; size <= math.min(maxContext, count); size++) {
      final sums = <double>[0];
      for (var start = 0; start + size <= count; start++) {
        final end = start + size;
        if (canPrepareRange != null &&
            !canPrepareRange(offsets[start], offsets[end])) {
          sums.add(sums.last);
          continue;
        }
        final interaction = size == 1
            ? measure(start, end)
            : measure(start, end) -
                measure(start + 1, end) -
                measure(start, end - 1) +
                measure(start + 1, end - 1);
        sums.add(sums.last + interaction);
      }
      interactions.add(sums);
    }
  }
  final int maxContext;
  @override
  late final int length;
  @override
  late final List<int> ordinary, emergency;
  final offsets = <int>[0];
  final interactions = <List<double>>[];
  @override
  int measurementCalls = 0;
  @override
  int get fragmentEntries =>
      interactions.fold(0, (n, values) => n + values.length);
  @override
  int get joinEntries => 0;
  @override
  double width(int start, int end) {
    final a = _upper(offsets, start) - 1, b = _upper(offsets, end) - 1;
    if (offsets[a] != start || offsets[b] != end) {
      throw StateError('Split grapheme');
    }
    var width = 0.0;
    for (var size = 1; size <= math.min(interactions.length, b - a); size++) {
      width += interactions[size - 1][b - size + 1] - interactions[size - 1][a];
    }
    return width;
  }
}
