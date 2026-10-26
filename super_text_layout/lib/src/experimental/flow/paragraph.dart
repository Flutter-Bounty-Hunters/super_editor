part of 'flow.dart';

/// Box-to-fragment bridge. Currently horizontal LTR, bounded width, greedy
/// wrapping. Existing SuperText widgets and their APIs are unaffected.
class FlowParagraph extends MultiChildRenderObjectWidget {
  const FlowParagraph(
      {super.key,
      required super.children,
      required this.controller,
      this.regions,
      this.style = const TextStyle(fontSize: 18, color: Color(0xFF202630)),
      this.backgroundPainter,
      this.foregroundPainter});
  final FlowLayoutController controller;
  final FlowRegionProvider? regions;
  final TextStyle style;
  final FlowLayerPainter? backgroundPainter;
  final FlowLayerPainter? foregroundPainter;
  @override
  RenderFlowParagraph createRenderObject(BuildContext context) =>
      RenderFlowParagraph(controller, regions ?? RectangularFlowRegions(),
          style, backgroundPainter, foregroundPainter);
  @override
  void updateRenderObject(
      BuildContext context, RenderFlowParagraph renderObject) {
    renderObject.update(controller, regions ?? RectangularFlowRegions(), style,
        backgroundPainter, foregroundPainter);
  }
}

class RenderFlowParagraph extends RenderBox
    with ContainerRenderObjectMixin<RenderFlowParticipant, _FlowParentData> {
  RenderFlowParagraph(this._controller, this._regions, this._style,
      this._background, this._foreground) {
    _connect();
  }
  FlowLayoutController _controller;
  FlowRegionProvider _regions;
  TextStyle _style;
  FlowLayerPainter? _background;
  FlowLayerPainter? _foreground;
  FlowLayoutSnapshot? _snapshot;
  final _textAnalysisCache = _TextAnalysisCache();
  final _textChoiceCache = _TextChoiceCache();
  final _textWidthCache = _TextWidthCache();
  @visibleForTesting
  int get debugTextWidthHits => _textWidthCache.debugHits;
  @visibleForTesting
  int get debugTextWidthEvictions => _textWidthCache.debugEvictions;
  @visibleForTesting
  int get debugTextWidthEntries => _textWidthCache._entries.length;
  @visibleForTesting
  int get debugTextWidthUnits => _textWidthCache._units;
  @visibleForTesting
  int get debugTextChoiceHits => _textChoiceCache.debugHits;
  @visibleForTesting
  int get debugTextChoiceEntries => _textChoiceCache._entries.length;
  _TextShapeCache? _lastShapes;
  final _debugShapePools = <_TextShapeCache>[];
  @visibleForTesting
  int get debugTextShapeBuilds => _lastShapes?.debugBuilds ?? 0;
  @visibleForTesting
  int get debugTextShapeHits => _lastShapes?.debugHits ?? 0;
  @visibleForTesting
  int get debugTextShapeLive =>
      _debugShapePools.fold(0, (sum, pool) => sum + pool._active.length);
  @visibleForTesting
  int get debugTextShapePeakEntries => _lastShapes?.debugPeakEntries ?? 0;
  @visibleForTesting
  int get debugTextAnalysisBuilds => _textAnalysisCache.debugBuilds;
  @visibleForTesting
  int get debugTextAnalysisEntries => _textAnalysisCache._entries.length;

  void _fontsChanged() {
    _textAnalysisCache.clear();
    _textChoiceCache.clear();
    _textWidthCache.clear();
    markNeedsLayout();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    PaintingBinding.instance.systemFonts.addListener(_fontsChanged);
    // Fonts can have changed while a retained paragraph was detached.
    markNeedsLayout();
  }

  @override
  void detach() {
    PaintingBinding.instance.systemFonts.removeListener(_fontsChanged);
    _textAnalysisCache.clear();
    _textChoiceCache.clear();
    _textWidthCache.clear();
    super.detach();
  }

  void _connect() {
    assert(
        _controller._renderObject == null || _controller._renderObject == this,
        'A FlowLayoutController cannot be shared between paragraphs.');
    _controller._renderObject = this;
    _controller.addListener(markNeedsPaint);
  }

  void update(
      FlowLayoutController controller,
      FlowRegionProvider regions,
      TextStyle style,
      FlowLayerPainter? background,
      FlowLayerPainter? foreground) {
    if (_controller != controller) {
      _controller.removeListener(markNeedsPaint);
      _controller._renderObject = null;
      _controller = controller;
      _connect();
    }
    _regions = regions;
    _style = style;
    _background = background;
    _foreground = foreground;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! _FlowParentData) {
      child.parentData = _FlowParentData();
    }
  }

  List<RenderFlowParticipant> get _children {
    final result = <RenderFlowParticipant>[];
    var child = firstChild;
    while (child != null) {
      result.add(child);
      child = (child.parentData! as _FlowParentData).nextSibling;
    }
    return result;
  }

  @override
  void performLayout() {
    if (!constraints.hasBoundedWidth) {
      throw FlutterError(
          'The flow prototype requires a bounded paragraph width.');
    }
    final previousTag = _profileFlow ? _flowLayoutTag.makeCurrent() : null;
    try {
      final watch = Stopwatch()..start();
      final measure = FlowMeasureConstraints(constraints.maxWidth, Object());
      final previousChildTag =
          _profileFlow ? _flowChildrenTag.makeCurrent() : null;
      try {
        for (final child in _children) {
          child.layout(measure, parentUsesSize: true);
        }
      } finally {
        previousChildTag?.makeCurrent();
      }

      final entries = [for (final child in _children) ...child.content];
      final shapes = _TextShapeCache();
      _lastShapes = shapes;
      assert(() {
        _debugShapePools
            .removeWhere((pool) => pool._closed && pool._active.isEmpty);
        _debugShapePools.add(shapes);
        return true;
      }());
      late final FlowLayoutSnapshot result;
      try {
        final engine = _Composer(
            entries,
            _regions,
            _style,
            constraints.maxWidth,
            _textAnalysisCache,
            shapes,
            _textChoiceCache,
            _textWidthCache);
        result = engine.compose(watch);
      } catch (_) {
        shapes.abort();
        rethrow;
      } finally {
        shapes.close();
      }
      size = constraints.constrain(result.size);
      _snapshot?._dispose();
      _snapshot = result;
      for (final child in _children) {
        child.commitFragments(result);
      }
    } finally {
      previousTag?.makeCurrent();
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final snapshot = _snapshot;
    if (snapshot == null) {
      return;
    }
    _paintLayer(context.canvas, offset, _background, snapshot);
    for (final child in _children) {
      context.paintChild(child, offset);
    }
    for (final placement in snapshot._placements) {
      placement.measurement.paint(context.canvas, offset + placement.origin);
    }
    _paintLayer(context.canvas, offset, _foreground, snapshot);
  }

  void _paintLayer(Canvas canvas, Offset offset, FlowLayerPainter? painter,
      FlowLayoutSnapshot layout) {
    if (painter == null) {
      return;
    }
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    painter(canvas, layout);
    canvas.restore();
  }

  @override
  bool hitTestSelf(Offset position) => true;
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in _children.reversed) {
      if (child.hitTestFlow(result, position)) {
        return true;
      }
    }
    return false;
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {}
  @override
  void dispose() {
    _controller.removeListener(markNeedsPaint);
    _controller._renderObject = null;
    _snapshot?._dispose();
    _textAnalysisCache.clear();
    _textChoiceCache.clear();
    _textWidthCache.clear();
    super.dispose();
  }
}

class _Run {
  _Run(this.prepared, this.rank);
  final FlowPreparedContent prepared;
  final int rank;
  int get length => prepared.length;
  List<RenderFlowDecoration> get padded => prepared.measuresDecorationPadding
      ? const []
      : prepared.entries.first.decorations
          .where((d) => d.padding != EdgeInsets.zero)
          .toList();
  List<RenderFlowDecoration> paddingAt(int offset) {
    var start = 0;
    for (final entry in prepared.entries) {
      if (offset < start + entry.length ||
          (entry.length == 0 && offset == start)) {
        return entry.decorations
            .where((d) => d.padding != EdgeInsets.zero)
            .toList();
      }
      start += entry.length;
    }
    return prepared.entries.last.decorations
        .where((d) => d.padding != EdgeInsets.zero)
        .toList();
  }

  EdgeInsets get padding =>
      padded.fold(EdgeInsets.zero, (sum, d) => sum + d.padding);
}

class _PlacedRange {
  _PlacedRange(this.measurement, this.origin, this.run, this.line);
  final FlowRangeMeasurement measurement;
  final Offset origin;
  final _Run run;
  final int line;
  int get rank => run.rank + measurement.caretRange.start;
  int get length => measurement.caretRange.end - measurement.caretRange.start;
}

class _Cursor {
  const _Cursor(this.run, this.offset);
  final int run;
  final int offset;
}

class _Piece {
  _Piece(this.run, this.measurement, this.opportunity, this.x, this.segment);
  final _Run run;
  final FlowRangeMeasurement measurement;
  final FlowBreakOpportunity opportunity;
  final double x;
  final int segment;
  int get consumed => measurement.range.end - measurement.range.start;
  double get width => measurement.width;
  double get ascent => measurement.ascent + run.padding.top;
  double get descent => measurement.descent + run.padding.bottom;
}

/// Composes only prepared opportunities and measured ranges. No content-type
/// dispatch or text fitting is performed here.
class _Composer {
  _Composer(
      this.entries,
      this.regions,
      this.style,
      this.width,
      _TextAnalysisCache analysisCache,
      _TextShapeCache shapeCache,
      _TextChoiceCache choiceCache,
      _TextWidthCache widthCache)
      : runs = _prepareRuns(
            entries, style, analysisCache, shapeCache, choiceCache, widthCache);
  final List<FlowContent> entries;
  final FlowRegionProvider regions;
  final TextStyle style;
  final double width;
  final List<_Run> runs;
  final List<FlowFragment> fragments = [];
  final List<FlowLine> lines = [];
  final List<_PlacedRange> placements = [];
  final Map<(Object, int, int), int> decorationFragments = {};
  int retries = 0;

  FlowLayoutSnapshot compose(Stopwatch watch) {
    final metrics = _defaultTextMetrics(style);
    final defaultAscent = metrics.$1;
    final defaultDescent = metrics.$2;
    var cursor = const _Cursor(0, 0);
    var y = 0.0;
    if (width > 0) {
      while (cursor.run < runs.length) {
        var ascent = defaultAscent;
        var descent = defaultDescent;
        var attempts = 0;
        var heightRetry = false;
        FlowLineSpace? pendingSpace;
        // Height only grows during retries: no oscillating region/height loop.
        while (true) {
          if (++attempts > 256) {
            throw FlutterError(
                'Flow line did not converge after 256 region/height attempts. '
                'Check participant measurements and region-provider progress.');
          }
          final previousAttemptTag = _profileFlow
              ? (heightRetry ? _flowRetryTag : _flowAttemptTag).makeCurrent()
              : null;
          try {
            var space = pendingSpace ?? _spaceFor(y, ascent + descent);
            pendingSpace = null;
            if (space.segments.isEmpty) {
              final next = space.nextTop;
              if (next == null || !next.isFinite || next <= y) {
                throw FlutterError(
                    'No flow space and no later nextTop: region provider cannot make progress.');
              }
              y = next;
              continue;
            }
            final pieces = <_Piece>[];
            var attempt = cursor;
            var endLine = false;
            for (var segment = 0;
                segment < space.segments.length && !endLine;
                segment++) {
              final rect = space.segments[segment];
              var x = rect.left;
              List<RenderFlowDecoration> previous = const [];
              while (attempt.run < runs.length) {
                final run = runs[attempt.run];
                var common = 0;
                final ownsPadding = run.prepared.measuresDecorationPadding;
                final padded =
                    ownsPadding ? run.paddingAt(attempt.offset) : run.padded;
                while (common < previous.length &&
                    common < padded.length &&
                    previous[common] == padded[common]) {
                  common++;
                }
                final reclaimed = previous
                    .take(common)
                    .fold(0.0, (sum, d) => sum + d.padding.right);
                // Internally padded measurements include both edges. Reuse the
                // common leading edge when continuing an enclosing decoration.
                final left = ownsPadding
                    ? -padded
                        .take(common)
                        .fold(0.0, (sum, d) => sum + d.padding.left)
                    : padded
                        .skip(common)
                        .fold(0.0, (sum, d) => sum + d.padding.left);
                final right = ownsPadding
                    ? 0.0
                    : padded.fold(0.0, (sum, d) => sum + d.padding.right);
                final available = rect.right - x + reclaimed - left - right;
                if (available <= 0) {
                  break;
                }
                final piece = _select(run, attempt.offset, available,
                    x - reclaimed + left, segment);
                if (piece == null) {
                  break;
                }
                pieces.add(piece);
                x = piece.x + piece.width + right;
                previous = ownsPadding
                    ? run.paddingAt(math.max(
                        attempt.offset, piece.measurement.range.end - 1))
                    : padded;
                if (attempt.offset + piece.consumed >= run.length) {
                  attempt = _Cursor(attempt.run + 1, 0);
                } else {
                  attempt =
                      _Cursor(attempt.run, attempt.offset + piece.consumed);
                }
                if (piece.opportunity.endsLine) {
                  endLine = true;
                  break;
                }
                if (attempt.offset != 0) {
                  break;
                }
              }
            }
            if (pieces.isEmpty) {
              if (space.nextTop != null && space.nextTop! > y) {
                y = space.nextTop!;
                continue;
              }
              throw FlutterError(
                  'An inline participant cannot fit at the maximum available width. '
                  'Participants must handle their own oversized content.');
            }
            final nextAscent = pieces.fold(
                ascent, (value, piece) => math.max(value, piece.ascent));
            final nextDescent = pieces.fold(
                descent, (value, piece) => math.max(value, piece.descent));
            if (nextAscent > ascent + 0.01 || nextDescent > descent + 0.01) {
              ascent = nextAscent;
              descent = nextDescent;
              retries++;
              heightRetry = true;
              FlowLineSpace tallerSpace;
              try {
                tallerSpace = _spaceFor(y, ascent + descent);
              } catch (_) {
                for (final piece in pieces) {
                  piece.measurement.dispose();
                }
                rethrow;
              }
              // Measurements depend on widths, not the proposed line height.
              // With identical horizontal segments every available-width
              // constraint and the greedy result remain unchanged.
              if (_sameHorizontalSpace(space, tallerSpace)) {
                space = tallerSpace;
              } else {
                for (final piece in pieces) {
                  piece.measurement.dispose();
                }
                pendingSpace = tallerSpace;
                continue;
              }
            }
            final line = lines.length;
            lines.add(FlowLine(y, ascent + descent, y + ascent,
                List.unmodifiable(space.segments)));
            for (final piece in pieces) {
              _commit(piece, line, y + ascent);
            }
            cursor = attempt;
            y += ascent + descent;
            break;
          } finally {
            previousAttemptTag?.makeCurrent();
          }
        }
      }
    }
    if (lines.isEmpty) {
      y = defaultAscent + defaultDescent;
    }
    watch.stop();
    return FlowLayoutSnapshot._(
        List.unmodifiable(fragments),
        List.unmodifiable(lines),
        placements,
        List.unmodifiable(entries),
        Size(width, y),
        watch.elapsed,
        retries);
  }

  FlowLineSpace _spaceFor(double top, double height) {
    final space = regions.spaceFor(top: top, height: height, width: width);
    _validateSpace(space, top, height);
    return space;
  }

  bool _sameHorizontalSpace(FlowLineSpace a, FlowLineSpace b) {
    if (a.segments.length != b.segments.length) {
      return false;
    }
    for (var i = 0; i < a.segments.length; i++) {
      if (a.segments[i].left != b.segments[i].left ||
          a.segments[i].right != b.segments[i].right) {
        return false;
      }
    }
    return true;
  }

  void _validateSpace(FlowLineSpace space, double top, double height) {
    var right = 0.0;
    for (final segment in space.segments) {
      if (!segment.isFinite ||
          segment.left < right ||
          segment.right > width ||
          segment.width <= 0 ||
          segment.top != top ||
          (segment.height - height).abs() > 0.01) {
        throw FlutterError(
            'Region segments must be finite, ordered, non-overlapping rectangles '
            'within the paragraph width and spanning the requested line height.');
      }
      right = segment.right;
    }
  }

  _Piece? _select(
      _Run run, int start, double available, double x, int segment) {
    final constraints = FlowFragmentConstraints(
        availableWidth: available,
        maximumWidth: math.max(0, width - run.padding.horizontal));
    late final candidates = _candidatesFor(run.prepared, start);
    late final firstOrdinary = candidates.ordinary.first;
    double? firstOrdinaryWidth;
    _Piece? measure(FlowBreakOpportunity opportunity,
        {bool recordFirstOrdinary = false}) {
      final range = TextRange(start: start, end: opportunity.offset);
      final measurement = run.prepared.measureRange(range, constraints);
      final measuredWidth = measurement.width;
      if (measurement.range != range ||
          !measuredWidth.isFinite ||
          measuredWidth < 0) {
        measurement.dispose();
        throw FlutterError(
            'Invalid exact-range measurement from an inline participant.');
      }
      if (recordFirstOrdinary && identical(opportunity, firstOrdinary)) {
        firstOrdinaryWidth = measuredWidth;
      }
      final fits = measuredWidth <= available + .01 ||
          (measurement.allowsOverflow &&
              available >= constraints.maximumWidth - .01);
      if (fits) {
        // Vertical metrics can cross into the text engine. Candidates that
        // fail the width test never need them.
        final ascent = measurement.ascent;
        final descent = measurement.descent;
        if (!ascent.isFinite ||
            ascent < 0 ||
            !descent.isFinite ||
            descent < 0) {
          measurement.dispose();
          throw FlutterError(
              'Invalid exact-range measurement from an inline participant.');
        }
        return _Piece(run, measurement, opportunity, x, segment);
      }
      measurement.dispose();
      return null;
    }

    _Piece? choose(_BreakWindow candidates) {
      // Preserve the exact reverse search; no monotonic-width assumption.
      for (final opportunity in candidates.reversed) {
        final piece = measure(opportunity, recordFirstOrdinary: true);
        if (piece != null) return piece;
      }
      return null;
    }

    final prepared = run.prepared;
    final reusable = prepared is _ReusableBreakSource
        ? prepared as _ReusableBreakSource
        : null;
    final cached = reusable?.lookupChoice(start, constraints);
    if (cached != null) {
      if (cached.opportunity == null) return null;
      final piece = measure(cached.opportunity!);
      if (piece != null) return piece;
      // If a retained choice unexpectedly stops fitting, do the full search.
    }
    _Piece? remember(_Piece? piece) {
      reusable?.rememberChoice(start, constraints, piece?.opportunity);
      return piece;
    }

    final ordinaryPiece = choose(candidates.ordinary);
    if (ordinaryPiece != null) {
      return remember(ordinaryPiece);
    }
    // A narrow remainder alone does not justify breaking a normally fitting word.
    // If no ordinary candidate fit, the reverse search measured the first one
    // last; its width still decides whether emergency wrapping is permitted.
    if (firstOrdinaryWidth == null ||
        firstOrdinaryWidth! > constraints.maximumWidth + .01) {
      return remember(choose(candidates.emergency));
    }
    return remember(null);
  }

  void _commit(_Piece piece, int line, double baseline) {
    final origin = Offset(piece.x, baseline - piece.measurement.ascent);
    placements.add(_PlacedRange(piece.measurement, origin, piece.run, line));
    for (final fragment in piece.measurement.fragments) {
      _record(fragment.content, fragment.bounds.shift(origin), fragment.range,
          line, baseline, piece.segment);
    }
  }

  void _record(FlowContent entry, Rect bounds, TextRange range, int line,
      double baseline, int segment) {
    fragments.add(FlowFragment(
        participant: entry.owner.identity,
        bounds: bounds,
        range: range,
        line: line,
        baseline: baseline));
    var decorated = bounds;
    for (final decoration in entry.decorations.reversed) {
      decorated = Rect.fromLTRB(
          decorated.left - decoration.padding.left,
          decorated.top - decoration.padding.top,
          decorated.right + decoration.padding.right,
          decorated.bottom + decoration.padding.bottom);
      final key = (decoration.identity, line, segment);
      final existing = decorationFragments[key];
      if (existing == null) {
        decorationFragments[key] = fragments.length;
        fragments.add(FlowFragment(
            participant: decoration.identity,
            bounds: decorated,
            range: TextRange.empty,
            line: line,
            baseline: baseline));
      } else {
        final old = fragments[existing];
        fragments[existing] = FlowFragment(
            participant: decoration.identity,
            bounds: old.bounds.expandToInclude(decorated),
            range: TextRange.empty,
            line: line,
            baseline: baseline);
      }
    }
  }
}
