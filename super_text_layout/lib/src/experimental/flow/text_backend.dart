part of 'flow.dart';

int _runeAt(String text, int offset) {
  final first = text.codeUnitAt(offset);
  if (first >= 0xd800 && first <= 0xdbff && offset + 1 < text.length) {
    final second = text.codeUnitAt(offset + 1);
    if (second >= 0xdc00 && second <= 0xdfff) {
      return 0x10000 + ((first - 0xd800) << 10) + second - 0xdc00;
    }
  }
  return first;
}

int _runeBefore(String text, int offset) {
  final last = text.codeUnitAt(offset - 1);
  if (last >= 0xdc00 && last <= 0xdfff && offset > 1) {
    final first = text.codeUnitAt(offset - 2);
    if (first >= 0xd800 && first <= 0xdbff) {
      return 0x10000 + ((first - 0xd800) << 10) + last - 0xdc00;
    }
  }
  return last;
}

bool _isHardBreak(int rune) => const {_Lb.bk, _Lb.cr, _Lb.lf, _Lb.nl}
    .contains(_Lb.values[_unicodeBreakProperty(rune) & 63]);

String _visibleText(String value, bool showSoftHyphen) =>
    showSoftHyphen && value.endsWith('\u00ad')
        ? '${value.substring(0, value.length - 1)}-'
        : value;

bool _canEmergencyBreak(String text, int offset) {
  final before =
      _Lb.values[_unicodeBreakProperty(_runeBefore(text, offset)) & 63];
  final after = _Lb.values[_unicodeBreakProperty(_runeAt(text, offset)) & 63];
  const protected = {_Lb.gl, _Lb.wj, _Lb.bk, _Lb.cr, _Lb.lf, _Lb.nl, _Lb.qu};
  return !protected.contains(before) &&
      !protected.contains(after) &&
      before != _Lb.op &&
      before != _Lb.zwj &&
      !const {_Lb.cl, _Lb.cp, _Lb.ex, _Lb.is_, _Lb.sy, _Lb.ns, _Lb.cj, _Lb.in_}
          .contains(after);
}

(double, double) _defaultTextMetrics(TextStyle style) {
  final painter = TextPainter(
      text: TextSpan(text: 'M', style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1)
    ..layout();
  final metrics = painter.computeLineMetrics().first;
  painter.dispose();
  return (metrics.ascent, metrics.descent);
}

/// Horizontal text backend using Unicode 16 default line breaks. Flutter word
/// segmentation tailors complex-context (SA) runs where the engine supplies it.
class _PreparedText extends FlowPreparedContent {
  _PreparedText(this.entries, this.style) {
    final candidates = <int, FlowBreakOpportunity>{};
    final graphemeEnds = <int>{0};
    var offset = 0;
    for (final grapheme in text.characters) {
      offset += grapheme.length;
      graphemeEnds.add(offset);
    }
    for (final boundary in UnicodeLineBreaks.compute(text)) {
      if (graphemeEnds.contains(boundary.offset)) {
        candidates[boundary.offset] = FlowBreakOpportunity(boundary.offset,
            kind: boundary.mandatory
                ? FlowBreakKind.required
                : FlowBreakKind.ordinary,
            endsLine: boundary.mandatory);
      }
    }
    _addDictionaryOpportunities(candidates, graphemeEnds);
    // Preserve the existing empty-line layout independently of the Unicode
    // analyzer: retain the visual boundary before a hard-break control and the
    // empty line consuming that control. Treat CRLF as one control sequence.
    for (var i = 0; i < text.length;) {
      final rune = _runeAt(text, i);
      final size = rune > 0xffff ? 2 : 1;
      if (_isHardBreak(rune)) {
        final end =
            rune == 13 && i + 1 < text.length && text.codeUnitAt(i + 1) == 10
                ? i + 2
                : i + size;
        _hardBreaks.add(TextRange(start: i, end: end));
        if (i > 0 && graphemeEnds.contains(i)) {
          candidates[i] = FlowBreakOpportunity(i,
              kind: FlowBreakKind.required, endsLine: true);
        }
        candidates[end] = FlowBreakOpportunity(end,
            kind: FlowBreakKind.required, endsLine: true);
        i = end;
      } else {
        i += size;
      }
    }
    for (final end in graphemeEnds) {
      if (end > 0 &&
          end < text.length &&
          !candidates.containsKey(end) &&
          _canEmergencyBreak(text, end)) {
        candidates[end] =
            FlowBreakOpportunity(end, kind: FlowBreakKind.emergency);
      }
    }
    _breaks.addAll(candidates.values.toList()
      ..sort((a, b) => a.offset.compareTo(b.offset)));
  }
  final List<TextRange> _hardBreaks = [];
  @override
  bool get measuresDecorationPadding => true;

  void _addDictionaryOpportunities(
      Map<int, FlowBreakOpportunity> candidates, Set<int> graphemeEnds) {
    if (!text.runes
        .any((r) => _Lb.values[_unicodeBreakProperty(r) & 63] == _Lb.sa)) {
      return;
    }
    final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr)
      ..layout();
    try {
      var offset = 0;
      while (offset < text.length) {
        final word = painter.getWordBoundary(TextPosition(offset: offset));
        if (word.end <= offset) {
          break;
        }
        final end = word.end;
        if (end < text.length &&
            graphemeEnds.contains(end) &&
            _Lb.values[_unicodeBreakProperty(_runeBefore(text, end)) & 63] ==
                _Lb.sa &&
            _Lb.values[_unicodeBreakProperty(_runeAt(text, end)) & 63] ==
                _Lb.sa) {
          candidates[end] = FlowBreakOpportunity(end);
        }
        offset = end;
      }
    } finally {
      painter.dispose();
    }
  }

  @override
  final List<FlowContent> entries;
  final TextStyle style;
  late final String text = entries.map((e) => e.textContribution!.text).join();
  final List<FlowBreakOpportunity> _breaks = [];
  @override
  Iterable<FlowBreakOpportunity> breaksAfter(int start) sync* {
    for (final candidate in _breaks) {
      if (candidate.offset <= start && text.isNotEmpty) {
        continue;
      }
      yield candidate;
      if (candidate.kind == FlowBreakKind.required) {
        break;
      }
    }
  }

  InlineSpan span(int start, int end, {bool showSoftHyphen = false}) {
    var offset = 0;
    final spans = <InlineSpan>[];
    for (final entry in entries) {
      final contribution = entry.textContribution!;
      final from = math.max(0, start - offset);
      final to = math.min(entry.length, end - offset);
      if (to > from ||
          (start == end && spans.isEmpty && start <= offset + entry.length)) {
        spans.add(TextSpan(
            text: to > from
                ? _visibleText(contribution.text.substring(from, to),
                    showSoftHyphen && offset + to == end)
                : '',
            style: contribution.style));
      }
      offset += entry.length;
      if (offset >= end && spans.isNotEmpty) {
        break;
      }
    }
    return TextSpan(style: style, children: spans);
  }

  @override
  FlowRangeMeasurement measureRange(
      TextRange range, FlowFragmentConstraints constraints) {
    if (range.start < 0 ||
        range.end > length ||
        range.end < range.start ||
        !_breaks.any((b) => b.offset == range.end) ||
        (range.start != 0 && !_breaks.any((b) => b.offset == range.start)) ||
        _breaks.any((b) =>
            b.kind == FlowBreakKind.required &&
            b.offset > range.start &&
            b.offset < range.end)) {
      throw ArgumentError('Invalid text candidate range: $range');
    }
    var visibleEnd = range.end;
    for (final control in _hardBreaks) {
      if (control.end == range.end && control.start >= range.start) {
        visibleEnd = control.start;
        break;
      }
    }
    final chunks = <_TextChunk>[];
    var offset = 0;
    for (final entry in entries) {
      final from = math.max(range.start, offset);
      final to = math.min(visibleEnd, offset + entry.length);
      final emptyHere = entry.length == 0 &&
          offset >= range.start &&
          (offset < visibleEnd || (offset == length && offset == visibleEnd));
      if (to > from || emptyHere) {
        final padding = entry.decorations
            .where((d) => d.padding != EdgeInsets.zero)
            .toList();
        if (chunks.isNotEmpty &&
            _matchingDecorations(chunks.last.padding, padding)) {
          chunks.last.end = to;
          chunks.last.entries.add(entry);
        } else {
          chunks.add(_TextChunk(from, to, padding, [entry]));
        }
      }
      offset += entry.length;
    }
    if (chunks.isEmpty) {
      var owner = entries.last;
      var offset = 0;
      for (final entry in entries) {
        if (range.start >= offset && range.start < offset + entry.length) {
          owner = entry;
          break;
        }
        offset += entry.length;
      }
      chunks.add(_TextChunk(
          range.start,
          visibleEnd,
          owner.decorations.where((d) => d.padding != EdgeInsets.zero).toList(),
          [owner]));
    }
    final measured = <_MeasuredTextChunk>[];
    for (var i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      final end = i == chunks.length - 1 ? range.end : chunk.end;
      final painter = TextPainter(
          text: chunk.start == chunk.end
              ? TextSpan(
                  text: '',
                  style:
                      style.merge(chunk.entries.first.textContribution!.style))
              : span(chunk.start, chunk.end,
                  showSoftHyphen: i == chunks.length - 1 &&
                      visibleEnd > range.start &&
                      text.codeUnitAt(visibleEnd - 1) == 0xad &&
                      range.end < length),
          textDirection: TextDirection.ltr,
          maxLines: 1)
        ..layout();
      measured.add(_MeasuredTextChunk(
          _TextMeasurement(this, TextRange(start: chunk.start, end: end),
              chunk.end, painter, constraints.maximumWidth,
              owners: chunk.entries.toSet()),
          chunk.padding));
    }
    if (measured.length == 1 && measured.single.padding.isEmpty) {
      return measured.single.measurement;
    }
    return _CompoundTextMeasurement(
        this, range, visibleEnd, measured, constraints.maximumWidth);
  }
}

class _TextMeasurement extends FlowRangeMeasurement {
  _TextMeasurement(
      this.source, this.range, this.visibleEnd, this.painter, this.maximumWidth,
      {this.owners});
  final _PreparedText source;
  final Set<FlowContent>? owners;
  @override
  final TextRange range;
  final int visibleEnd;
  final TextPainter painter;
  final double maximumWidth;
  @override
  TextRange get caretRange => TextRange(start: range.start, end: visibleEnd);
  @override
  double get width => painter.width;
  // Exact-range painters are immutable after layout. Validation, retries, and
  // committing can query these metrics repeatedly without asking the engine.
  late final _metrics = painter.computeLineMetrics();
  @override
  double get ascent =>
      _metrics.isEmpty ? painter.preferredLineHeight : _metrics.first.baseline;

  @override
  double get descent => painter.height - ascent;
  @override
  bool get allowsOverflow =>
      width > maximumWidth &&
      !source._breaks
          .any((b) => b.offset > range.start && b.offset < range.end);
  @override
  List<FlowLocalFragment> get fragments {
    var offset = 0;
    final result = <FlowLocalFragment>[];
    for (final entry in source.entries) {
      final from = math.max(range.start, offset);
      final to = math.min(visibleEnd, offset + entry.length);
      if ((owners == null || owners!.contains(entry)) &&
          (to > from || (entry.length == 0 && from == to))) {
        final boxes = boxesForRange(TextRange(start: from, end: to));
        final localRange = TextRange(
            start: entry.start + from - offset, end: entry.start + to - offset);
        if (boxes.isEmpty) {
          final caret = caretAt(from, TextAffinity.downstream);
          result.add(FlowLocalFragment(
              entry, localRange, Rect.fromLTWH(caret.dx, 0, 0, height)));
        } else {
          result.addAll(
              boxes.map((b) => FlowLocalFragment(entry, localRange, b)));
        }
      }
      offset += entry.length;
    }
    return result;
  }

  @override
  void paint(Canvas canvas, Offset origin) => painter.paint(canvas, origin);
  @override
  List<Rect> boxesForRange(TextRange selection) {
    final start = math.max(selection.start, range.start);
    final end = math.min(selection.end, visibleEnd);
    if (end <= start) {
      return [];
    }
    return painter
        .getBoxesForSelection(TextSelection(
            baseOffset: start - range.start, extentOffset: end - range.start))
        .map((b) => b.toRect())
        .toList();
  }

  @override
  Offset caretAt(int offset, TextAffinity affinity, {Object? participant}) =>
      painter.getOffsetForCaret(
          TextPosition(
              offset: offset.clamp(range.start, visibleEnd) - range.start,
              affinity: affinity),
          Rect.zero);
  @override
  FlowPosition positionAt(Offset point) {
    final offset = painter.getPositionForOffset(point).offset;
    final affinity = offset > 0 && offset == visibleEnd - range.start
        ? TextAffinity.upstream
        : TextAffinity.downstream;
    var local = range.start + offset;
    for (final entry in source.entries) {
      if (local <= entry.length &&
          (owners == null || owners!.contains(entry))) {
        return FlowPosition(entry.owner.identity, entry.start + local,
            affinity: affinity);
      }
      local -= entry.length;
    }
    final last = source.entries.last;
    return FlowPosition(last.owner.identity, last.end, affinity: affinity);
  }

  @override
  void dispose() => painter.dispose();
}

bool _matchingDecorations(
    List<RenderFlowDecoration> a, List<RenderFlowDecoration> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!identical(a[i], b[i])) return false;
  }
  return true;
}

class _TextChunk {
  _TextChunk(this.start, this.end, this.padding, this.entries);
  final int start;
  int end;
  final List<RenderFlowDecoration> padding;
  final List<FlowContent> entries;
}

class _MeasuredTextChunk {
  _MeasuredTextChunk(this.measurement, this.padding);
  final _TextMeasurement measurement;
  final List<RenderFlowDecoration> padding;
  double x = 0;
}

/// Text shares break context across widgets, even when padding requires separate
/// shaping. Common enclosing padding is charged once for the chosen fragment.
class _CompoundTextMeasurement extends FlowRangeMeasurement {
  _CompoundTextMeasurement(this.source, this.range, this.visibleEnd,
      this.chunks, this.maximumWidth) {
    var previous = <RenderFlowDecoration>[];
    var x = 0.0;
    for (final chunk in chunks) {
      var common = 0;
      while (common < previous.length &&
          common < chunk.padding.length &&
          identical(previous[common], chunk.padding[common])) {
        common++;
      }
      for (final decoration in previous.take(common)) {
        x -= decoration.padding.right;
      }
      for (final decoration in chunk.padding.skip(common)) {
        x += decoration.padding.left;
      }
      chunk.x = x;
      x += chunk.measurement.width;
      var top = 0.0;
      var bottom = 0.0;
      for (final decoration in chunk.padding) {
        x += decoration.padding.right;
        top += decoration.padding.top;
        bottom += decoration.padding.bottom;
      }
      ascent = math.max(ascent, chunk.measurement.ascent + top);
      descent = math.max(descent, chunk.measurement.descent + bottom);
      previous = chunk.padding;
    }
    width = x;
  }
  final _PreparedText source;
  @override
  final TextRange range;
  final int visibleEnd;
  final List<_MeasuredTextChunk> chunks;
  final double maximumWidth;
  @override
  double width = 0;
  @override
  double ascent = 0;
  @override
  double descent = 0;
  Offset _origin(_MeasuredTextChunk chunk) =>
      Offset(chunk.x, ascent - chunk.measurement.ascent);
  @override
  TextRange get caretRange => TextRange(start: range.start, end: visibleEnd);
  @override
  bool get allowsOverflow =>
      width > maximumWidth &&
      !source._breaks
          .any((b) => b.offset > range.start && b.offset < range.end);
  @override
  List<FlowLocalFragment> get fragments => [
        for (final chunk in chunks)
          for (final fragment in chunk.measurement.fragments)
            FlowLocalFragment(fragment.content, fragment.range,
                fragment.bounds.shift(_origin(chunk)))
      ];
  @override
  void paint(Canvas canvas, Offset origin) {
    for (final chunk in chunks) {
      chunk.measurement.paint(canvas, origin + _origin(chunk));
    }
  }

  @override
  List<Rect> boxesForRange(TextRange selection) => [
        for (final chunk in chunks)
          for (final box in chunk.measurement.boxesForRange(selection))
            box.shift(_origin(chunk))
      ];
  @override
  Offset caretAt(int offset, TextAffinity affinity, {Object? participant}) {
    final ordered =
        affinity == TextAffinity.downstream ? chunks.reversed : chunks;
    final candidates = ordered
        .where((chunk) =>
            offset >= chunk.measurement.caretRange.start &&
            offset <= chunk.measurement.caretRange.end)
        .toList();
    final matching = candidates.where((chunk) => chunk.measurement.owners!
        .any((entry) => entry.owner.identity == participant));
    final chunk = matching.isNotEmpty
        ? matching.first
        : candidates.isNotEmpty
            ? candidates.first
            : ordered.first;
    return chunk.measurement.caretAt(offset, affinity) + _origin(chunk);
  }

  @override
  FlowPosition positionAt(Offset point) {
    var closest = chunks.first;
    var distance = double.infinity;
    for (final chunk in chunks) {
      final rect = _origin(chunk) &
          Size(chunk.measurement.width, chunk.measurement.height);
      final dx =
          math.max(rect.left - point.dx, math.max(0.0, point.dx - rect.right));
      final dy =
          math.max(rect.top - point.dy, math.max(0.0, point.dy - rect.bottom));
      final next = dx * dx + dy * dy;
      if (next < distance) {
        distance = next;
        closest = chunk;
      }
    }
    return closest.measurement.positionAt(point - _origin(closest));
  }

  @override
  void dispose() {
    for (final chunk in chunks) {
      chunk.measurement.dispose();
    }
  }
}
