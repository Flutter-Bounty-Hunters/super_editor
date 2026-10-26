part of 'flow.dart';

enum FlowBreakKind { ordinary, emergency, required }

/// An alternative supplied by content, not a break chosen for a width.
class FlowBreakOpportunity {
  const FlowBreakOpportunity(this.offset,
      {this.kind = FlowBreakKind.ordinary, this.endsLine = false});
  final int offset;
  final FlowBreakKind kind;
  final bool endsLine;
}

class FlowPreparationContext {
  const FlowPreparationContext(this.content, this.paragraphStyle);
  final FlowContent content;
  final TextStyle paragraphStyle;
}

/// Widths exclude padding charged by the composer. A compound prepared source
/// can account for its own decoration padding via [FlowPreparedContent.measuresDecorationPadding].
class FlowFragmentConstraints {
  const FlowFragmentConstraints(
      {required this.availableWidth, required this.maximumWidth});
  final double availableWidth;
  final double maximumWidth;
}

/// A stable, per-layout content session. Offsets are local to this session;
/// they do not prescribe an editor/document indexing scheme.
abstract class FlowPreparedContent {
  /// Compound sources can include nested fragment padding in measured width
  /// and vertical metrics. The composer reuses common leading/trailing padding
  /// with neighboring sources, using the decoration ancestry of [entries].
  bool get measuresDecorationPadding => false;
  List<FlowContent> get entries;
  int get length => entries.fold(0, (sum, entry) => sum + entry.length);

  /// Ordered opportunities after start, stopping at the first required break.
  /// Empty content supplies its single zero-length opportunity.
  Iterable<FlowBreakOpportunity> breaksAfter(int start);

  /// Measures exactly the requested legal range. The result is owned by the
  /// caller and must be disposed if rejected, retried, or superseded.
  /// No fragment placements or widget state may change here.
  FlowRangeMeasurement measureRange(
      TextRange range, FlowFragmentConstraints constraints);
}

/// Participant geometry relative to the measured range's origin.
class FlowLocalFragment {
  const FlowLocalFragment(this.content, this.range, this.bounds);
  final FlowContent content;
  final TextRange range;
  final Rect bounds;
}

/// The same artifact is used for measurement and committed drawing/queries.
/// Implementations can draw custom content without exposing text or RenderBox.
abstract class FlowRangeMeasurement {
  TextRange get range;
  double get width;

  /// May be computed lazily: width-rejected candidates need no vertical metrics.
  double get ascent;
  double get descent;
  double get height => ascent + descent;
  TextRange get caretRange => range;
  bool get allowsOverflow => false;
  List<FlowLocalFragment> get fragments;
  void paint(Canvas canvas, Offset origin);
  List<Rect> boxesForRange(TextRange selection);

  /// Participant disambiguates a shared text offset on opposite sides of
  /// layout-changing padding; it is not a document/content index.
  Offset caretAt(int offset, TextAffinity affinity, {Object? participant});
  FlowPosition positionAt(Offset point);
  void dispose() {}
}

class _PreparedAtom extends FlowPreparedContent {
  _PreparedAtom(this.entry, this.atom);
  final FlowContent entry;
  final FlowAtomicContent atom;
  @override
  List<FlowContent> get entries => [entry];
  @override
  Iterable<FlowBreakOpportunity> breaksAfter(int start) sync* {
    if (start == 0) {
      yield const FlowBreakOpportunity(1);
    }
  }

  @override
  FlowRangeMeasurement measureRange(
      TextRange range, FlowFragmentConstraints constraints) {
    if (range != const TextRange(start: 0, end: 1)) {
      throw ArgumentError('An ordinary widget is indivisible.');
    }
    return _AtomMeasurement(entry, atom);
  }
}

class _AtomMeasurement extends FlowRangeMeasurement {
  _AtomMeasurement(this.entry, this.atom);
  final FlowContent entry;
  final FlowAtomicContent atom;
  @override
  TextRange get range => const TextRange(start: 0, end: 1);
  @override
  double get width => atom.size.width;
  @override
  double get ascent => atom.baseline;
  @override
  double get descent => atom.size.height - atom.baseline;
  @override
  List<FlowLocalFragment> get fragments => [
        FlowLocalFragment(entry, TextRange(start: entry.start, end: entry.end),
            Offset.zero & atom.size)
      ];
  // Ordinary widgets paint through their retained render objects.
  @override
  void paint(Canvas canvas, Offset origin) {}
  @override
  List<Rect> boxesForRange(TextRange selection) =>
      selection.start < 1 && selection.end > 0 ? [Offset.zero & atom.size] : [];
  @override
  Offset caretAt(int offset, TextAffinity affinity, {Object? participant}) =>
      Offset(offset <= 0 ? 0 : width, 0);
  @override
  FlowPosition positionAt(Offset point) => FlowPosition(
      entry.owner.identity, point.dx < width / 2 ? entry.start : entry.end);
}

class _DecoratedContent extends FlowContent {
  _DecoratedContent(this.original, List<RenderFlowDecoration> decorations)
      : super(original.owner, original.start, original.end, decorations);
  final FlowContent original;
  @override
  FlowTextContent? get textContribution => original.textContribution;
  @override
  FlowPreparedContent prepare(FlowPreparationContext context) =>
      original.prepare(context);
}

List<_Run> _prepareRuns(List<FlowContent> entries, TextStyle style) {
  final previousTag = _profileFlow ? _flowPrepareTag.makeCurrent() : null;
  try {
    final groups = <List<FlowContent>>[];
    for (final entry in entries) {
      if (entry.textContribution != null &&
          groups.isNotEmpty &&
          groups.last.first.textContribution != null) {
        groups.last.add(entry);
      } else {
        groups.add([entry]);
      }
    }
    var rank = 0;
    final result = <_Run>[];
    for (final group in groups) {
      final prepared = group.first.textContribution != null
          ? _PreparedText(group, style)
          : group.single.prepare(FlowPreparationContext(group.single, style));
      result.add(_Run(prepared, rank));
      rank += prepared.length;
    }
    return result;
  } finally {
    previousTag?.makeCurrent();
  }
}
