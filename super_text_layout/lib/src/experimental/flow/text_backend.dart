part of 'flow.dart';

int _lowerOffset(List<int> values, int offset) {
  var low = 0, high = values.length;
  while (low < high) {
    final mid = (low + high) >> 1;
    if (values[mid] < offset) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  return low;
}

int _upperOffset(List<int> values, int offset) {
  var low = 0, high = values.length;
  while (low < high) {
    final mid = (low + high) >> 1;
    if (values[mid] <= offset) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  return low;
}

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

class _TextBreakIndex {
  _TextBreakIndex(Iterable<FlowBreakOpportunity> values)
      : values = List.unmodifiable(values);
  final List<FlowBreakOpportunity> values;
  late final offsets =
      values.map((value) => value.offset).toList(growable: false);
  _BreakWindow after(int start, int limit) => _BreakWindow(
      values, _upperOffset(offsets, start), _upperOffset(offsets, limit));
}

/// Unicode 16 break analysis, with Flutter dictionary tailoring for SA text.
class _TextBreakAnalysis {
  _TextBreakAnalysis(this.text, this.style) {
    final candidates = <int, FlowBreakOpportunity>{};
    final hardBreaks = <TextRange>[];
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
        hardBreaks.add(TextRange(start: i, end: end));
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
    _breaks = List.unmodifiable(candidates.values.toList()
      ..sort((a, b) => a.offset.compareTo(b.offset)));
    _hardBreaks = List.unmodifiable(hardBreaks);
  }
  final String text;
  final TextStyle style;
  late final List<TextRange> _hardBreaks;
  late final List<FlowBreakOpportunity> _breaks;
  late final offsets = List<int>.unmodifiable(_breaks.map((b) => b.offset));
  late final legalOffsets = offsets.toSet();
  late final requiredOffsets = List<int>.unmodifiable(_breaks
      .where((b) => b.kind == FlowBreakKind.required)
      .map((b) => b.offset));
  late final controlsByEnd = {
    for (final control in _hardBreaks) control.end: control
  };
  late final _ordinaryIndex =
      _TextBreakIndex(_breaks.where((b) => b.kind != FlowBreakKind.emergency));
  late final _emergencyIndex =
      _TextBreakIndex(_breaks.where((b) => b.kind == FlowBreakKind.emergency));

  _BreakCandidates candidatesAfter(int start) {
    final from = text.isEmpty ? -1 : start;
    final required = _upperOffset(requiredOffsets, from);
    final limit = required < requiredOffsets.length
        ? requiredOffsets[required]
        : text.length;
    return _BreakCandidates(
        _ordinaryIndex.after(from, limit), _emergencyIndex.after(from, limit));
  }

  bool hasBreakInside(TextRange range) {
    final i = _upperOffset(offsets, range.start);
    return i < offsets.length && offsets[i] < range.end;
  }

  bool crossesRequired(TextRange range) {
    final i = _upperOffset(requiredOffsets, range.start);
    return i < requiredOffsets.length && requiredOffsets[i] < range.end;
  }

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
}

class _TextAnalysisCache {
  final _entries = <({String text, TextStyle style}), _TextBreakAnalysis>{};
  int _units = 0;
  int debugBuilds = 0;
  _TextBreakAnalysis get(String text, TextStyle style) {
    final key = (text: text, style: style);
    final cached = _entries.remove(key);
    if (cached != null) {
      _entries[key] = cached;
      return cached;
    }
    assert(() {
      debugBuilds++;
      return true;
    }());
    final analysis = _TextBreakAnalysis(text, style);
    final weight = math.max(1, text.length);
    if (weight > 65536) return analysis;
    while (_entries.isNotEmpty &&
        (_entries.length >= 256 || _units + weight > 65536)) {
      final oldest = _entries.remove(_entries.keys.first)!;
      _units -= math.max(1, oldest.text.length);
    }
    _entries[key] = analysis;
    _units += weight;
    return analysis;
  }

  void clear() {
    _entries.clear();
    _units = 0;
  }
}

class _PreparedText extends FlowPreparedContent
    implements
        _IndexedBreakSource,
        _ReusableBreakSource,
        _FlutterLineHintSource {
  factory _PreparedText(List<FlowContent> entries, TextStyle style,
      {_TextAnalysisCache? analysisCache,
      _TextShapeCache? shapeCache,
      _TextChoiceCache? choiceCache,
      _TextWidthCache? widthCache,
      bool nativeFitting = false,
      _CompactTextCache? compactCache,
      String? preparedText,
      bool cacheShapes = true}) {
    if (compactCache != null &&
        (preparedText ?? entries.map((e) => e.textContribution!.text).join())
            .codeUnits
            .every((c) => c >= 32 && c <= 126) &&
        style.foreground == null &&
        style.background == null &&
        entries.every((entry) =>
            entry.textContribution!.style.foreground == null &&
            entry.textContribution!.style.background == null) &&
        entries.any((entry) =>
            _nativeStyle(style.merge(entry.textContribution!.style)))) {
      if (entries.any((entry) =>
          entry.decorations.any((d) => d.padding != EdgeInsets.zero))) {
        return _CompactPaddedText(entries, style,
            analysisCache: analysisCache,
            shapeCache: shapeCache,
            choiceCache: choiceCache,
            widthCache: widthCache,
            nativeFitting: nativeFitting,
            compactCache: compactCache,
            preparedText: preparedText,
            cacheShapes: cacheShapes);
      }
      return _CompactPreparedText(entries, style,
          analysisCache: analysisCache,
          shapeCache: shapeCache,
          choiceCache: choiceCache,
          widthCache: widthCache,
          nativeFitting: nativeFitting,
          compactCache: compactCache,
          preparedText: preparedText,
          cacheShapes: cacheShapes);
    }
    return _PreparedText._exact(entries, style,
        analysisCache: analysisCache,
        shapeCache: shapeCache,
        choiceCache: choiceCache,
        widthCache: widthCache,
        nativeFitting: nativeFitting,
        preparedText: preparedText,
        cacheShapes: cacheShapes);
  }
  _PreparedText._exact(this.entries, this.style,
      {_TextAnalysisCache? analysisCache,
      this.shapeCache,
      this.choiceCache,
      this.widthCache,
      this.nativeFitting = false,
      String? preparedText,
      this.cacheShapes = true})
      : _analysisCache = analysisCache {
    text = preparedText ?? entries.map((e) => e.textContribution!.text).join();
  }
  final _TextShapeCache? shapeCache;
  final _TextChoiceCache? choiceCache;
  final _TextWidthCache? widthCache;
  final bool nativeFitting;
  final bool cacheShapes;
  final _TextAnalysisCache? _analysisCache;
  // Numeric-only chunk sessions may never query breaks. In particular, short
  // chunks and cached interaction models do not need a second Unicode analysis.
  late final _TextBreakAnalysis _analysis =
      _analysisCache?.get(text, style) ?? _TextBreakAnalysis(text, style);
  List<FlowBreakOpportunity> get _breaks => _analysis._breaks;
  @override
  bool get measuresDecorationPadding => true;
  @override
  final List<FlowContent> entries;
  final TextStyle style;
  late final String text;
  // Decorations without padding still paint from committed fragments; they do
  // not split shaping. Current-owner geometry remains in this prepared session.
  late final bool _plain = entries.length == 1 &&
      entries.single.decorations.every((d) => d.padding == EdgeInsets.zero);

  late final bool _cacheWidths = _plain &&
      text.length >= 256 &&
      widthCache != null &&
      style.foreground == null &&
      style.background == null &&
      entries.single.textContribution!.style.foreground == null &&
      entries.single.textContribution!.style.background == null;

  static bool _nativeStyle(TextStyle style) =>
      style.inherit &&
      (style.letterSpacing ?? 0) >= 0 &&
      (style.wordSpacing ?? 0) >= 0 &&
      (style.fontFeatures?.isEmpty ?? true) &&
      (style.fontVariations?.isEmpty ?? true) &&
      style.foreground == null &&
      style.background == null;

  late final bool _nativeEligible = nativeFitting &&
      _plain &&
      _nativeStyle(style) &&
      _nativeStyle(entries.single.textContribution!.style) &&
      text.codeUnits.every((unit) => unit >= 32 && unit <= 126);

  @override
  int? suggestLineEnd(int start, FlowFragmentConstraints constraints) {
    if (!_nativeEligible || start >= length) return null;
    final ordinary = _analysis.candidatesAfter(start).ordinary;
    // One ordinary candidate is cheap to measure directly. This also leaves
    // protected/overlong single words on the fully general emergency path.
    if (ordinary.end - ordinary.start < 2) return null;
    final painter = TextPainter(
        text: span(start, length),
        textDirection: TextDirection.ltr,
        maxLines: 1);
    try {
      painter.layout(maxWidth: constraints.availableWidth + .01);
      final line = painter.getLineBoundary(const TextPosition(offset: 0));
      if (line.start != 0 || line.end <= 0 || line.end > length - start) {
        return null;
      }
      return start + line.end;
    } finally {
      painter.dispose();
    }
  }

  _TextChoiceKey? _choiceKey(int start, FlowFragmentConstraints constraints) {
    if (!_plain || choiceCache == null) return null;
    final contentStyle = entries.single.textContribution!.style;
    // TextStyle can contain mutable Paint objects; keep that path uncached.
    if (style.foreground != null ||
        style.background != null ||
        contentStyle.foreground != null ||
        contentStyle.background != null) {
      return null;
    }
    return (
      text: text,
      paragraphStyle: style,
      contentStyle: contentStyle,
      start: start,
      availableWidth: constraints.availableWidth,
      maximumWidth: constraints.maximumWidth
    );
  }

  @override
  _BreakDecision? lookupChoice(int start, FlowFragmentConstraints constraints) {
    final key = _choiceKey(start, constraints);
    return key == null ? null : choiceCache!.lookup(key);
  }

  @override
  void rememberChoice(int start, FlowFragmentConstraints constraints,
      FlowBreakOpportunity? opportunity) {
    final key = _choiceKey(start, constraints);
    if (key != null) choiceCache!.remember(key, opportunity);
  }

  @override
  _BreakCandidates indexedCandidatesAfter(int start) =>
      _analysis.candidatesAfter(start);

  @override
  Iterable<FlowBreakOpportunity> breaksAfter(int start) sync* {
    final first = text.isEmpty ? 0 : _upperOffset(_analysis.offsets, start);
    for (var i = first; i < _breaks.length; i++) {
      final candidate = _breaks[i];
      yield candidate;
      if (candidate.kind == FlowBreakKind.required) {
        break;
      }
    }
  }

  late final List<int> _starts = () {
    final result = <int>[0];
    for (final entry in entries) {
      result.add(result.last + entry.length);
    }
    return result;
  }();
  @override
  int get length => _starts.last;
  // Include the preceding entry at a shared boundary so empty participants and
  // upstream carets retain their existing ordering.
  int _firstEntry(int offset) => math.max(0, _lowerOffset(_starts, offset) - 1);

  InlineSpan span(int start, int end, {bool showSoftHyphen = false}) {
    final first = _firstEntry(start);
    var offset = _starts[first];
    final spans = <InlineSpan>[];
    for (var i = first; i < entries.length; i++) {
      final entry = entries[i];
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
        !_analysis.legalOffsets.contains(range.end) ||
        (range.start != 0 && !_analysis.legalOffsets.contains(range.start)) ||
        _analysis.crossesRequired(range)) {
      throw ArgumentError('Invalid text candidate range: $range');
    }
    var visibleEnd = range.end;
    final control = _analysis.controlsByEnd[range.end];
    if (control != null && control.start >= range.start) {
      visibleEnd = control.start;
    }
    if (_plain) {
      final contribution = entries.single.textContribution!;
      final showSoftHyphen = visibleEnd > range.start &&
          text.codeUnitAt(visibleEnd - 1) == 0xad &&
          range.end < length;
      final spanToShape = range.start == visibleEnd
          ? TextSpan(text: '', style: style.merge(contribution.style))
          : TextSpan(style: style, children: [
              TextSpan(
                  text: _visibleText(
                      contribution.text.substring(range.start, visibleEnd),
                      showSoftHyphen),
                  style: contribution.style)
            ]);
      if (_cacheWidths) {
        final cached = widthCache!.lookup(spanToShape);
        if (cached != null) {
          return _TextMeasurement.deferred(
              this,
              range,
              visibleEnd,
              cached,
              () =>
                  shapeCache?.acquire(spanToShape, visibleEnd - range.start,
                      allowCache: cacheShapes) ??
                  _TextShape.build(spanToShape),
              constraints.maximumWidth);
        }
      }
      final shape = shapeCache?.acquire(spanToShape, visibleEnd - range.start,
              allowCache: cacheShapes) ??
          _TextShape.build(spanToShape);
      if (_cacheWidths) {
        widthCache!.remember(
            spanToShape, visibleEnd - range.start, shape.painter.width);
      }
      // The source has exactly one owner, so no owner set/chunk wrappers are
      // needed. Hard controls retain the original consumed and visible ranges.
      return _TextMeasurement(
          this, range, visibleEnd, shape, constraints.maximumWidth);
    }
    final chunks = <_TextChunk>[];
    final first = _firstEntry(range.start);
    var offset = _starts[first];
    for (var i = first; i < entries.length; i++) {
      final entry = entries[i];
      if (offset > visibleEnd ||
          (offset == visibleEnd && visibleEnd < length)) {
        break;
      }
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
      var offset = _starts[first];
      for (var i = first; i < entries.length; i++) {
        final entry = entries[i];
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
    try {
      for (var i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        final end = i == chunks.length - 1 ? range.end : chunk.end;
        final spanToShape = chunk.start == chunk.end
            ? TextSpan(
                text: '',
                style: style.merge(chunk.entries.first.textContribution!.style))
            : span(chunk.start, chunk.end,
                showSoftHyphen: i == chunks.length - 1 &&
                    visibleEnd > range.start &&
                    text.codeUnitAt(visibleEnd - 1) == 0xad &&
                    range.end < length);
        final shape = shapeCache?.acquire(spanToShape, chunk.end - chunk.start,
                allowCache: cacheShapes) ??
            _TextShape.build(spanToShape);
        measured.add(_MeasuredTextChunk(
            _TextMeasurement(this, TextRange(start: chunk.start, end: end),
                chunk.end, shape, constraints.maximumWidth,
                owners: chunk.entries.toSet()),
            chunk.padding));
      }
    } catch (_) {
      for (final chunk in measured) {
        chunk.measurement.dispose();
      }
      rethrow;
    }
    if (measured.length == 1 && measured.single.padding.isEmpty) {
      return measured.single.measurement;
    }
    return _CompoundTextMeasurement(
        this, range, visibleEnd, measured, constraints.maximumWidth);
  }
}

class _TextMeasurement extends FlowRangeMeasurement {
  _TextMeasurement(this.source, this.range, this.visibleEnd, _TextShape shape,
      this.maximumWidth,
      {this.owners})
      : _shape = shape,
        _createShape = null,
        _cachedWidth = null;
  _TextMeasurement.deferred(this.source, this.range, this.visibleEnd,
      double width, _TextShape Function() createShape, this.maximumWidth)
      : _shape = null,
        _createShape = createShape,
        _cachedWidth = width,
        owners = null;
  final _PreparedText source;
  final Set<FlowContent>? owners;
  @override
  final TextRange range;
  final int visibleEnd;
  _TextShape? _shape;
  final _TextShape Function()? _createShape;
  final double? _cachedWidth;
  _TextShape get shape {
    assert(!_disposed);
    final result = _shape ??= _createShape!();
    assert(_cachedWidth == null ||
        (result.painter.width - _cachedWidth!).abs() < .001);
    return result;
  }

  TextPainter get painter => shape.painter;
  bool _disposed = false;
  final double maximumWidth;
  @override
  TextRange get caretRange => TextRange(start: range.start, end: visibleEnd);
  @override
  double get width => _cachedWidth ?? painter.width;
  // Exact-range painters are immutable after layout. Validation, retries, and
  // committing can query these metrics repeatedly without asking the engine.
  late final _metrics = shape.metrics;
  @override
  double get ascent =>
      _metrics.isEmpty ? painter.preferredLineHeight : _metrics.first.baseline;

  @override
  double get descent => painter.height - ascent;
  @override
  bool get allowsOverflow =>
      width > maximumWidth && !source._analysis.hasBreakInside(range);
  @override
  List<FlowLocalFragment> get fragments {
    final first = source._firstEntry(range.start);
    var offset = source._starts[first];
    final result = <FlowLocalFragment>[];
    for (var i = first; i < source.entries.length; i++) {
      final entry = source.entries[i];
      if (offset > visibleEnd) break;
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
    final global = range.start + offset;
    for (var i = source._firstEntry(global); i < source.entries.length; i++) {
      final entry = source.entries[i];
      final local = global - source._starts[i];
      if (local <= entry.length &&
          (owners == null || owners!.contains(entry))) {
        return FlowPosition(entry.owner.identity, entry.start + local,
            affinity: affinity);
      }
    }
    final last = source.entries.last;
    return FlowPosition(last.owner.identity, last.end, affinity: affinity);
  }

  @override
  void dispose() {
    assert(!_disposed);
    _disposed = true;
    _shape?.release();
  }
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
      for (final decoration in chunk.padding) {
        x += decoration.padding.right;
      }
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
  late final (double, double) _verticalMetrics = () {
    var ascent = 0.0, descent = 0.0;
    for (final chunk in chunks) {
      var top = 0.0, bottom = 0.0;
      for (final decoration in chunk.padding) {
        top += decoration.padding.top;
        bottom += decoration.padding.bottom;
      }
      ascent = math.max(ascent, chunk.measurement.ascent + top);
      descent = math.max(descent, chunk.measurement.descent + bottom);
    }
    return (ascent, descent);
  }();
  @override
  double get ascent => _verticalMetrics.$1;
  @override
  double get descent => _verticalMetrics.$2;
  Offset _origin(_MeasuredTextChunk chunk) =>
      Offset(chunk.x, ascent - chunk.measurement.ascent);
  @override
  TextRange get caretRange => TextRange(start: range.start, end: visibleEnd);
  @override
  bool get allowsOverflow =>
      width > maximumWidth && !source._analysis.hasBreakInside(range);
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
