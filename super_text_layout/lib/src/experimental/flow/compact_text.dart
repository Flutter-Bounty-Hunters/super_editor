part of 'flow.dart';

/// Owner-free numeric data, retained only by one paragraph. Mutable Paint and
/// control-containing runs never enter this cache. Padding stays in the current
/// prepared session; these cached values describe text only.
class _CompactStyleKey {
  _CompactStyleKey(TextStyle value)
      : style = value.copyWith(
            fontFamilyFallback: value.fontFamilyFallback == null
                ? null
                : List.unmodifiable(value.fontFamilyFallback!),
            fontFeatures: value.fontFeatures == null
                ? null
                : List.unmodifiable(value.fontFeatures!),
            fontVariations: value.fontVariations == null
                ? null
                : List.unmodifiable(value.fontVariations!),
            shadows: value.shadows == null
                ? null
                : List.unmodifiable(value.shadows!)) {
    _hash = style.hashCode;
  }
  final TextStyle style;
  // Immutable encoded styles can be reused without retaining glyph resources.
  late final ui.ParagraphStyle paragraphStyle = style.getParagraphStyle(
      textAlign: TextAlign.start, textDirection: TextDirection.ltr);
  late final ui.TextStyle textStyle = style.getTextStyle();
  late final int _hash;
  @override
  int get hashCode => _hash;
  @override
  bool operator ==(Object other) =>
      other is _CompactStyleKey && style == other.style;
}

class _CompactTextCache {
  final _models = <Object, ({_CompactTextModel? model, int units})>{};
  // Keep tiny shaping measurements separate from calibration strings so word
  // and paragraph measurements cannot evict the shared grapheme data.
  final _widths = <Object, ({double width, int units})>{};
  final _calibrations = <Object, ({double width, int units})>{};
  final _styles = <TextStyle, _CompactStyleKey>{};
  int _units = 0, _widthUnits = 0, _calibrationUnits = 0;
  int debugBuilds = 0,
      debugHits = 0,
      debugRejections = 0,
      debugCalibrationFailures = 0;
  int debugBinarySearches = 0,
      debugBinaryProbes = 0,
      debugBinarySkipped = 0,
      debugUnorderedSearches = 0,
      debugMaximumGuards = 0;

  _CompactStyleKey styleKey(TextStyle style) {
    final cached = _styles[style];
    if (cached != null) return cached;
    if (_styles.length >= 64) _styles.remove(_styles.keys.first);
    final key = _CompactStyleKey(style);
    _styles[key.style] = key;
    return key;
  }

  Object rangeKey(_CompactPreparedText source, int start, int end) =>
      source._compactPlain
          ? (source.text.substring(start, end), source._compactStyleKey)
          : source.span(start, end);

  double measure(_CompactPreparedText source, int start, int end) {
    final key = rangeKey(source, start, end);
    final length = end - start;
    final small = length <= 3;
    final cache = small ? _widths : _calibrations;
    final cached = cache.remove(key);
    if (cached != null) {
      cache[key] = cached;
      return cached.width;
    }
    late final double width;
    if (source._compactPlain && source.numericOnly) {
      // This is TextPainter's unbounded, LTR intrinsic-width path with a flat
      // span. No caret/paint/line-metric state is needed for numeric rejection.
      final styleKey = source._compactStyleKey;
      final builder = ui.ParagraphBuilder(styleKey.paragraphStyle)
        ..pushStyle(styleKey.textStyle)
        ..addText(source.text.substring(start, end))
        ..pop();
      final paragraph = builder.build();
      try {
        paragraph.layout(const ui.ParagraphConstraints(width: double.infinity));
        width = paragraph.maxIntrinsicWidth;
      } finally {
        paragraph.dispose();
      }
    } else {
      final span = source._compactPlain
          ? TextSpan(
              text: source.text.substring(start, end),
              style: source._compactStyleKey.style)
          : key as InlineSpan;
      final painter = TextPainter(text: span, textDirection: TextDirection.ltr);
      try {
        painter.layout();
        width = painter.width;
      } finally {
        painter.dispose();
      }
    }
    final units = math.max(1, length);
    final limit = small ? 8192 : 65536;
    if (units <= limit) {
      while (cache.isNotEmpty &&
          (cache.length >= 2048 ||
              (small ? _widthUnits : _calibrationUnits) + units > limit)) {
        final removed = cache.remove(cache.keys.first)!.units;
        if (small) {
          _widthUnits -= removed;
        } else {
          _calibrationUnits -= removed;
        }
      }
      cache[key] = (width: width, units: units);
      if (small) {
        _widthUnits += units;
      } else {
        _calibrationUnits += units;
      }
    }
    return width;
  }

  _CompactTextModel? get(_CompactPreparedText source, List<int> excluded) {
    final key = rangeKey(source, 0, source.length);
    final existing = _models.remove(key);
    if (existing != null) {
      _models[key] = existing;
      assert(() {
        debugHits++;
        return true;
      }());
      return existing.model;
    }
    assert(() {
      debugBuilds++;
      return true;
    }());
    final model = _CompactTextModel(source, excluded, this);
    final accepted = model.calibrate(source, excluded, this);
    assert(() {
      if (!accepted) debugCalibrationFailures++;
      return true;
    }());
    final units = math.max(1, source.length);
    if (units <= 65536) {
      while (_models.isNotEmpty &&
          (_models.length >= 256 || _units + units > 65536)) {
        _units -= _models.remove(_models.keys.first)!.units;
      }
      _models[key] = (model: accepted ? model : null, units: units);
      _units += units;
    }
    return accepted ? model : null;
  }

  void clear() {
    _models.clear();
    _widths.clear();
    _calibrations.clear();
    _styles.clear();
    _units = 0;
    _widthUnits = 0;
    _calibrationUnits = 0;
  }
}

class _CompactTextModel {
  _CompactTextModel(_CompactPreparedText source, List<int> excluded,
      _CompactTextCache cache) {
    double measure(int a, int b) => a == b ? 0 : cache.measure(source, a, b);
    // Each n-gram is measured once. Lower-order widths are already available
    // when constructing interactions; looking them up again churns the LRU.
    final widths = <List<double>>[];
    for (var size = 1; size <= math.min(3, source.length); size++) {
      final raw = <double>[];
      final sums = <double>[0];
      for (var start = 0; start + size <= source.length; start++) {
        final end = start + size;
        if (excluded[end] != excluded[start]) {
          raw.add(0);
          sums.add(sums.last);
          continue;
        }
        final width = measure(start, end);
        raw.add(width);
        final delta = size == 1
            ? width
            : width -
                widths[size - 2][start + 1] -
                widths[size - 2][start] +
                (size == 2 ? 0 : widths[size - 3][start + 1]);
        sums.add(sums.last + delta);
      }
      widths.add(raw);
      _sums.add(sums);
    }
  }

  final _sums = <List<double>>[];
  double width(int start, int end) {
    var result = 0.0;
    for (var size = 1; size <= math.min(_sums.length, end - start); size++) {
      result += _sums[size - 1][end - size + 1] - _sums[size - 1][start];
    }
    return result;
  }

  // For ranges of at least three characters, changing the start subtracts
  // only a constant from these margin-adjusted end coordinates. Validate the
  // complete sequence once; every ordinary/emergency candidate subset then
  // has the same ordering. Near-flat steps conservatively use linear search.
  late final bool orderedEnds = () {
    final count = _sums.isEmpty ? 0 : _sums.first.length - 1;
    if (count < 3) return false;
    final singles = _sums[0], pairs = _sums[1], triples = _sums[2];
    var previous = singles[3] + pairs[2] + triples[1] - slack(3);
    for (var end = 4; end <= count; end++) {
      final value =
          singles[end] + pairs[end - 1] + triples[end - 2] - slack(end);
      final precision =
          math.max(1.0, math.max(value.abs(), previous.abs())) * 1e-12;
      if (value - previous <= precision) return false;
      previous = value;
    }
    return true;
  }();

  // A practical guard against wider shaping interactions. This is not a proof
  // for every possible font; exact artifacts still decide every accepted fit.
  bool calibrate(_CompactPreparedText source, List<int> excluded,
      _CompactTextCache cache) {
    bool matches(int a, int b) {
      if (excluded[a] != excluded[b]) return true;
      return (width(a, b) - cache.measure(source, a, b)).abs() <= slack(b - a);
    }

    if (!matches(0, source.length)) return false;
    var previous = 0, beforePrevious = 0;
    for (final opportunity
        in source._analysis.candidatesAfter(0).ordinary.values) {
      final end = opportunity.offset;
      if (!matches(previous, end) ||
          (previous > 0 && !matches(beforePrevious, end))) {
        return false;
      }
      beforePrevious = previous;
      previous = end;
    }
    return true;
  }

  static double slack(int length) => .01 + length * .0001;
}

/// A private fitting hint, separate from the public exact measurement protocol.
abstract interface class _CompactRejectionSource {
  double? rejectedWidth(TextRange range, FlowFragmentConstraints constraints);
}

/// Returns an inclusive candidate-list bound, not an exact measurement.
/// Null means retain the original search; start-1 means no numeric candidate.
abstract interface class _PreparedBreakSearch {
  int? furthestPotentialBreak(
      int start, _BreakWindow candidates, FlowFragmentConstraints constraints);
}

/// The reference source keeps its original measurement body and instance data.
/// Only admitted groups allocate compact state or execute this prefilter.
class _CompactPreparedText extends _PreparedText
    implements _CompactRejectionSource, _PreparedBreakSearch {
  _CompactPreparedText(super.entries, super.style,
      {super.analysisCache,
      super.shapeCache,
      super.choiceCache,
      super.widthCache,
      super.nativeFitting,
      required this.compactCache,
      this.numericOnly = false,
      super.preparedText,
      super.cacheShapes})
      : super._exact();
  final _CompactTextCache compactCache;
  final bool numericOnly;
  // Padding changes fragment composition, not the text's numeric shape key.
  bool get _compactPlain => entries.length == 1;
  late final _CompactStyleKey _compactStyleKey = compactCache
      .styleKey(style.merge(entries.single.textContribution!.style));
  late final List<int> _compactExcluded = () {
    final result = <int>[0];
    for (final entry in entries) {
      final allowed = _PreparedText._nativeStyle(
          style.merge(entry.textContribution!.style));
      for (var i = 0; i < entry.length; i++) {
        result.add(result.last + (allowed ? 0 : 1));
      }
    }
    return result;
  }();
  late final _CompactTextModel? _compactModel =
      compactCache.get(this, _compactExcluded);

  @override
  int? furthestPotentialBreak(
      int start, _BreakWindow candidates, FlowFragmentConstraints constraints) {
    if (const bool.fromEnvironment('FLOW_BENCHMARK_LINEAR_BREAKS') ||
        candidates.end - candidates.start < 32 ||
        _compactExcluded.last != 0) {
      return null;
    }
    final model = _compactModel;
    if (model == null) return null;
    if (!model.orderedEnds) {
      assert(() {
        compactCache.debugUnorderedSearches++;
        return true;
      }());
      return null;
    }
    assert(() {
      compactCache.debugBinarySearches++;
      return true;
    }());
    bool potentiallyFits(int index, double limit) {
      assert(() {
        compactCache.debugBinaryProbes++;
        return true;
      }());
      final end = candidates.values[index].offset;
      return model.width(start, end) <=
          limit + .01 + _CompactTextModel.slack(end - start);
    }

    if (potentiallyFits(candidates.end - 1, constraints.availableWidth)) {
      return candidates.end - 1;
    }
    // The first two characters have truncated shaping context; leave them
    // in the exact-correction window instead of assuming the global order.
    var low = candidates.start, high = candidates.end;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (candidates.values[mid].offset <= start + 2) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    final firstLong = low;
    int upperBound(double limit) {
      var left = firstLong, right = candidates.end;
      while (left < right) {
        final mid = (left + right) >> 1;
        if (potentiallyFits(mid, limit)) {
          left = mid + 1;
        } else {
          right = mid;
        }
      }
      return left - 1;
    }

    var bound = math.max(firstLong - 1, upperBound(constraints.availableWidth));
    // Preserve the existing prefilter's exact-inspection band around maximum
    // paragraph width. It can matter in a narrow region. Every skipped point
    // must already be rejectable by the linear prefilter, not just by a new
    // assumption about its actual Flutter width.
    if (constraints.maximumWidth > constraints.availableWidth) {
      final maximumBound = upperBound(constraints.maximumWidth);
      if (maximumBound >= firstLong && maximumBound > bound) {
        final end = candidates.values[maximumBound].offset;
        final estimate = model.width(start, end);
        final precision = math.max(1.0, constraints.maximumWidth.abs()) * 1e-12;
        if (estimate >= constraints.maximumWidth ||
            constraints.maximumWidth - estimate <=
                _CompactTextModel.slack(end - start) + .01 + precision) {
          bound = maximumBound;
          assert(() {
            compactCache.debugMaximumGuards++;
            return true;
          }());
        }
      }
    }
    // Indivisible ranges retain their exact overflow behavior, including
    // ranges containing more than one character (e.g. protected spaces).
    final first = candidates.first;
    if (first != null &&
        !_analysis.hasBreakInside(TextRange(start: start, end: first.offset))) {
      bound = math.max(bound, candidates.start);
    }
    assert(() {
      compactCache.debugBinarySkipped += candidates.end - bound - 1;
      return true;
    }());
    return bound;
  }

  @override
  double? rejectedWidth(TextRange range, FlowFragmentConstraints constraints) {
    if (range.start < 0 ||
        range.end > length ||
        range.end < range.start ||
        !_analysis.legalOffsets.contains(range.end) ||
        (range.start != 0 && !_analysis.legalOffsets.contains(range.start)) ||
        _analysis.crossesRequired(range)) {
      throw ArgumentError('Invalid text candidate range: $range');
    }
    // Numeric rejection only: anything potentially fitting follows the exact
    // artifact path below. Indivisible ranges preserve the overflow contract.
    if (_analysis.hasBreakInside(range) &&
        _compactExcluded[range.end] == _compactExcluded[range.start]) {
      final model = _compactModel;
      if (model != null) {
        final estimate = model.width(range.start, range.end);
        final margin = _CompactTextModel.slack(range.end - range.start);
        if (estimate > constraints.availableWidth + .01 + margin &&
            (estimate - constraints.maximumWidth).abs() > margin + .01) {
          assert(() {
            compactCache.debugRejections++;
            return true;
          }());
          return estimate;
        }
      }
    }
    return null;
  }
}

/// Rejection-only widths for the same shaping chunks as the exact compound
/// measurement. Decorations and owners live here, never in the numeric cache.
/// This path deliberately retains linear break traversal.
class _CompactPaddedText extends _PreparedText
    implements _CompactRejectionSource {
  _CompactPaddedText(super.entries, super.style,
      {_TextAnalysisCache? analysisCache,
      super.shapeCache,
      super.choiceCache,
      super.widthCache,
      super.nativeFitting,
      required this.compactCache,
      super.preparedText,
      super.cacheShapes})
      : _chunkAnalysisCache = analysisCache,
        super._exact(analysisCache: analysisCache);
  final _TextAnalysisCache? _chunkAnalysisCache;
  final _CompactTextCache compactCache;

  late final List<
      ({
        int start,
        int end,
        _CompactPreparedText source,
        List<RenderFlowDecoration> padding
      })> _numericChunks = () {
    final chunks = <_TextChunk>[];
    var offset = 0;
    for (final entry in entries) {
      final padding =
          entry.decorations.where((d) => d.padding != EdgeInsets.zero).toList();
      if (chunks.isNotEmpty &&
          _matchingDecorations(chunks.last.padding, padding)) {
        chunks.last.end = offset + entry.length;
        chunks.last.entries.add(entry);
      } else {
        chunks.add(_TextChunk(offset, offset + entry.length, padding, [entry]));
      }
      offset += entry.length;
    }
    return [
      for (final chunk in chunks)
        (
          start: chunk.start,
          end: chunk.end,
          padding: chunk.padding,
          source: _CompactPreparedText(chunk.entries, style,
              compactCache: compactCache,
              numericOnly: true,
              analysisCache: _chunkAnalysisCache,
              preparedText: text.substring(chunk.start, chunk.end))
        )
    ];
  }();

  @override
  double? rejectedWidth(TextRange range, FlowFragmentConstraints constraints) {
    if (range.start < 0 ||
        range.end > length ||
        range.end < range.start ||
        !_analysis.legalOffsets.contains(range.end) ||
        (range.start != 0 && !_analysis.legalOffsets.contains(range.start)) ||
        _analysis.crossesRequired(range)) {
      throw ArgumentError('Invalid text candidate range: $range');
    }
    if (!_analysis.hasBreakInside(range)) return null;
    var width = 0.0, margin = 0.0;
    var previous = <RenderFlowDecoration>[];
    for (final chunk in _numericChunks) {
      final from = math.max(range.start, chunk.start);
      final to = math.min(range.end, chunk.end);
      // Empty owners have boundary-sensitive inclusion in the exact path.
      // Leave such groups on exact measurement rather than guessing ownership.
      if (chunk.start == chunk.end) return null;
      if (to <= from) continue;
      final source = chunk.source;
      if (source._compactExcluded.last != 0) return null;
      final localStart = from - chunk.start, localEnd = to - chunk.start;
      if (source.length < 32 || to - from == source.length) {
        // Whole chunks and short padding-edge snippets do not justify building
        // an interaction table. Cache their exact numeric width instead.
        width += compactCache.measure(source, localStart, localEnd);
      } else {
        final model = source._compactModel;
        if (model == null) return null;
        width += model.width(localStart, localEnd);
        margin += _CompactTextModel.slack(to - from);
      }
      var common = 0;
      while (common < previous.length &&
          common < chunk.padding.length &&
          identical(previous[common], chunk.padding[common])) {
        common++;
      }
      for (final decoration in previous.take(common)) {
        width -= decoration.padding.right;
      }
      for (final decoration in chunk.padding.skip(common)) {
        width += decoration.padding.left;
      }
      for (final decoration in chunk.padding) {
        width += decoration.padding.right;
      }
      previous = chunk.padding;
    }
    if (width > constraints.availableWidth + .01 + margin &&
        (width - constraints.maximumWidth).abs() > margin + .01) {
      assert(() {
        compactCache.debugRejections++;
        return true;
      }());
      return width;
    }
    return null;
  }
}
