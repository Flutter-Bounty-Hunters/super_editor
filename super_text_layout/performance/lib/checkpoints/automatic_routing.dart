/// Isolated automatic routing experiment; not used by FlowParagraph.
library;

import 'package:flutter/widgets.dart';
import 'package:super_text_layout/experimental_flow.dart';
import 'prepared_text.dart';

class RoutingSpan {
  const RoutingSpan(this.text, this.style);
  final String text;
  final TextStyle style;
}

class RoutingSource {
  RoutingSource(this.spans, this.paragraphStyle) {
    text = spans.map((s) => s.text).join();
    breaks = CheckpointSource(text, paragraphStyle);
    for (final span in spans) {
      starts.add(starts.last + span.text.length);
      final unsupported = !_eligible(paragraphStyle.merge(span.style));
      for (var i = 0; i < span.text.length; i++) {
        excluded.add(excluded.last + (unsupported ? 1 : 0));
      }
    }
  }
  final List<RoutingSpan> spans;
  final TextStyle paragraphStyle;
  late final String text;
  late final CheckpointSource breaks;
  final starts = <int>[0], excluded = <int>[0];
  int exactMeasurements = 0;

  static bool _eligible(TextStyle style) =>
      (style.letterSpacing ?? 0) >= 0 &&
      (style.wordSpacing ?? 0) >= 0 &&
      (style.fontFeatures?.isEmpty ?? true) &&
      (style.fontVariations?.isEmpty ?? true) &&
      style.foreground == null &&
      style.background == null;

  bool eligible(int start, int end) => excluded[end] == excluded[start];

  InlineSpan span(int start, int end) =>
      TextSpan(style: paragraphStyle, children: [
        for (var i = 0; i < spans.length; i++)
          if (starts[i] < end && starts[i + 1] > start)
            TextSpan(
                text: spans[i].text.substring(
                    start > starts[i] ? start - starts[i] : 0,
                    end < starts[i + 1]
                        ? end - starts[i]
                        : spans[i].text.length),
                style: spans[i].style),
      ]);

  double measure(int start, int end) {
    exactMeasurements++;
    final painter =
        TextPainter(text: span(start, end), textDirection: TextDirection.ltr)
          ..layout();
    try {
      return painter.width;
    } finally {
      painter.dispose();
    }
  }

  void dispose() => breaks.dispose();
}

class AutomaticRoutingModel {
  AutomaticRoutingModel(this.source)
      : prepared = CompactPreparedSegments(source.breaks,
            spanForRange: source.span, canPrepareRange: source.eligible);
  final RoutingSource source;
  final CompactPreparedSegments prepared;
  int compactCandidates = 0, exactCandidates = 0;
  double width(int start, int end) {
    if (source.eligible(start, end)) {
      compactCandidates++;
      return prepared.width(start, end);
    }
    exactCandidates++;
    return source.measure(start, end);
  }

  List<CheckpointLine> fit(List<double> widths) => fitCheckpoint(
      length: source.text.length,
      ordinary: prepared.ordinary,
      emergency: prepared.emergency,
      widths: widths,
      measure: width);
}

List<CheckpointLine> fitRoutingExact(
    RoutingSource source, List<double> widths) {
  final ordinary = source.breaks.breaks
      .where((b) => b.kind != FlowBreakKind.emergency)
      .map((b) => b.offset)
      .toList();
  final emergency = source.breaks.breaks
      .where((b) => b.kind == FlowBreakKind.emergency)
      .map((b) => b.offset)
      .toList();
  return fitCheckpoint(
      length: source.text.length,
      ordinary: ordinary,
      emergency: emergency,
      widths: widths,
      measure: source.measure);
}
