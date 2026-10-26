part of 'flow.dart';

/// A location in a participant, not an index into a document.
@immutable
class FlowPosition {
  const FlowPosition(this.participant, this.offset,
      {this.affinity = TextAffinity.downstream})
      : edge = null;
  const FlowPosition.boundary(this.participant, this.edge)
      : offset = 0,
        affinity = TextAffinity.downstream;

  final Object participant;
  final int offset;
  final FlowEdge? edge;

  /// Chooses the visual side when a text boundary appears in two fragments.
  /// This does not describe document structure or insertion formatting.
  final TextAffinity affinity;

  @override
  bool operator ==(Object other) =>
      other is FlowPosition &&
      participant == other.participant &&
      offset == other.offset &&
      edge == other.edge &&
      affinity == other.affinity;
  @override
  int get hashCode => Object.hash(participant, offset, edge, affinity);
}

enum FlowEdge { before, insideStart, insideEnd, after }

@immutable
class FlowSelection {
  const FlowSelection(this.base, this.extent);
  final FlowPosition base;
  final FlowPosition extent;
}

/// A piece of one participant. Bounds use paragraph coordinates.
@immutable
class FlowFragment {
  const FlowFragment(
      {required this.participant,
      required this.bounds,
      required this.range,
      required this.line,
      required this.baseline});
  final Object participant;
  final Rect bounds;
  final TextRange range;
  final int line;
  final double baseline;
}

@immutable
class FlowLine {
  const FlowLine(this.top, this.height, this.baseline, this.segments);
  final double top;
  final double height;
  final double baseline;
  final List<Rect> segments;
}

/// Empty regions must specify a strictly later [nextTop], or indicate that
/// there is no more space. This makes advancing past obstacles explicit.
@immutable
class FlowLineSpace {
  const FlowLineSpace(this.segments, {this.nextTop});
  final List<Rect> segments;
  final double? nextTop;
}

abstract class FlowRegionProvider {
  const FlowRegionProvider();
  FlowLineSpace spaceFor(
      {required double top, required double height, required double width});
}

class RectangularFlowRegions extends FlowRegionProvider {
  RectangularFlowRegions({List<Rect> obstacles = const []})
      : obstacles = List.unmodifiable(obstacles);
  final List<Rect> obstacles;

  @override
  FlowLineSpace spaceFor(
      {required double top, required double height, required double width}) {
    var intervals = <(double, double)>[(0, width)];
    double? nextTop;
    for (final obstacle in obstacles) {
      if (obstacle.bottom <= top ||
          obstacle.top >= top + height ||
          obstacle.right <= 0 ||
          obstacle.left >= width) {
        continue;
      }
      nextTop = math.min(nextTop ?? double.infinity, obstacle.bottom);
      final remaining = <(double, double)>[];
      for (final interval in intervals) {
        if (obstacle.right <= interval.$1 || obstacle.left >= interval.$2) {
          remaining.add(interval);
        } else {
          if (obstacle.left > interval.$1) {
            remaining.add((interval.$1, obstacle.left));
          }
          if (obstacle.right < interval.$2) {
            remaining.add((obstacle.right, interval.$2));
          }
        }
      }
      intervals = remaining;
    }
    return FlowLineSpace(
        List.unmodifiable([
          for (final interval in intervals)
            if (interval.$2 > interval.$1)
              Rect.fromLTRB(interval.$1, top, interval.$2, top + height),
        ]),
        nextTop: nextTop);
  }
}

/// Owns committed measurement artifacts until the next layout. Do not retain
/// across layouts.
class FlowLayoutSnapshot {
  FlowLayoutSnapshot._(this.fragments, this.lines, this._placements,
      this._entries, this.size, this.layoutDuration, this.lineRetries);
  final List<FlowFragment> fragments;
  final List<FlowLine> lines;
  final List<_PlacedRange> _placements;
  final List<FlowContent> _entries;
  final Size size;
  final Duration layoutDuration;
  final int lineRetries;

  List<FlowFragment> fragmentsFor(Object participant) => fragments
      .where((fragment) => fragment.participant == participant)
      .toList(growable: false);

  int _rank(FlowPosition position) {
    var rank = 0;
    int? first;
    int? last;
    for (final entry in _entries) {
      if (entry.owner.identity == position.participant) {
        if (position.edge == null) {
          if (position.offset < entry.start || position.offset > entry.end) {
            rank += entry.length;
            continue;
          }
          return rank + position.offset - entry.start;
        }
        first ??= rank;
        last = rank + entry.length;
      }
      if (entry.decorations.any((d) => d.identity == position.participant)) {
        first ??= rank;
        last = rank + entry.length;
      }
      rank += entry.length;
    }
    if (first != null) {
      return position.edge == FlowEdge.before ||
              position.edge == FlowEdge.insideStart
          ? first
          : last!;
    }
    throw ArgumentError(
        'Position does not belong to this layout: ${position.participant}');
  }

  /// Content boxes only. Decorated fragment bounds are separately available.
  List<Rect> boxesForSelection(FlowSelection selection) {
    final a = _rank(selection.base);
    final b = _rank(selection.extent);
    final start = math.min(a, b);
    final end = math.max(a, b);
    if (start == end) {
      return const [];
    }
    final boxes = <Rect>[];
    for (final placement in _placements) {
      final from = math.max(
          start - placement.run.rank, placement.measurement.range.start);
      final to =
          math.min(end - placement.run.rank, placement.measurement.range.end);
      if (to <= from) {
        continue;
      }
      boxes.addAll(placement.measurement
          .boxesForRange(TextRange(start: from, end: to))
          .map((box) => box.shift(placement.origin)));
    }
    return boxes;
  }

  Rect? caretFor(FlowPosition position) {
    if (position.edge != null) {
      final pieces = fragmentsFor(position.participant);
      if (pieces.isEmpty) {
        return null;
      }
      final first = position.edge == FlowEdge.before ||
          position.edge == FlowEdge.insideStart;
      final fragment = first ? pieces.first : pieces.last;
      final entry = _entries.where(
          (e) => e.decorations.any((d) => d.identity == position.participant));
      final decorator = entry.isEmpty
          ? null
          : entry.first.decorations
              .firstWhere((d) => d.identity == position.participant);
      var x = first ? fragment.bounds.left : fragment.bounds.right;
      if (position.edge == FlowEdge.insideStart) {
        x += decorator?.padding.left ?? 0;
      }
      if (position.edge == FlowEdge.insideEnd) {
        x -= decorator?.padding.right ?? 0;
      }
      return Rect.fromLTWH(x, fragment.bounds.top, 1, fragment.bounds.height);
    }
    final rank = _rank(position);
    final candidates = position.affinity == TextAffinity.upstream
        ? _placements
        : _placements.reversed;
    for (final text in candidates) {
      if (!text.run.prepared.entries
          .any((entry) => entry.owner.identity == position.participant)) {
        continue;
      }
      if (rank < text.rank || rank > text.rank + text.length) {
        continue;
      }
      final offset = text.measurement.caretAt(
          rank - text.run.rank, position.affinity,
          participant: position.participant);
      return Rect.fromLTWH(text.origin.dx + offset.dx,
          text.origin.dy + offset.dy, 1, text.measurement.height);
    }
    final pieces = fragmentsFor(position.participant);
    if (pieces.isEmpty) {
      return null;
    }
    final piece = position.offset <= pieces.first.range.start
        ? pieces.first
        : pieces.last;
    return Rect.fromLTWH(
        position.offset <= piece.range.start
            ? piece.bounds.left
            : piece.bounds.right,
        piece.bounds.top,
        1,
        piece.bounds.height);
  }

  /// Nearest content location, or a distinct decorator edge in its padding.
  FlowPosition? positionNearestTo(Offset point) {
    if (lines.isEmpty) {
      return null;
    }
    // First choose the visual line, including its full vertical extent. A
    // blank line has no ink and zero text width, but owns the same pointer
    // band as a populated line. Global 2D distance would favor nearby ink on
    // another line when the pointer is to the right of a blank line's caret.
    var targetLine = 0;
    var verticalDistance = double.infinity;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (point.dy >= line.top && point.dy < line.top + line.height) {
        targetLine = i;
        break;
      }
      final distance =
          (point.dy - point.dy.clamp(line.top, line.top + line.height)).abs();
      if (distance < verticalDistance) {
        targetLine = i;
        verticalDistance = distance;
      }
    }
    for (final fragment in fragments.reversed) {
      if (fragment.line != targetLine || !fragment.bounds.contains(point)) {
        continue;
      }
      final decorators = _entries
          .expand((e) => e.decorations)
          .where((d) => d.identity == fragment.participant);
      if (decorators.isEmpty) {
        continue;
      }
      final decoration = decorators.first;
      final pieces = fragmentsFor(fragment.participant);
      if (fragment == pieces.first &&
          point.dx < fragment.bounds.left + decoration.padding.left) {
        return FlowPosition.boundary(
            fragment.participant,
            point.dx < fragment.bounds.left + decoration.padding.left / 2
                ? FlowEdge.before
                : FlowEdge.insideStart);
      }
      if (fragment == pieces.last &&
          point.dx > fragment.bounds.right - decoration.padding.right) {
        return FlowPosition.boundary(
            fragment.participant,
            point.dx < fragment.bounds.right - decoration.padding.right / 2
                ? FlowEdge.insideEnd
                : FlowEdge.after);
      }
    }
    _PlacedRange? nearest;
    var distance = double.infinity;
    for (final text in _placements) {
      if (text.line != targetLine) {
        continue;
      }
      final bounds =
          text.origin & Size(text.measurement.width, text.measurement.height);
      final delta = point -
          Offset(point.dx.clamp(bounds.left, bounds.right),
              point.dy.clamp(bounds.top, bounds.bottom));
      if (delta.distanceSquared < distance) {
        nearest = text;
        distance = delta.distanceSquared;
      }
    }
    if (nearest == null) {
      return null;
    }
    return nearest.measurement.positionAt(point - nearest.origin);
  }

  void _dispose() {
    for (final text in _placements) {
      text.measurement.dispose();
    }
  }
}

class FlowLayoutController extends ChangeNotifier {
  FlowLayoutSnapshot? get layout => _renderObject?._snapshot;
  RenderFlowParagraph? _renderObject;
  FlowSelection? get selection => _selection;
  FlowSelection? _selection;
  set selection(FlowSelection? value) {
    _selection = value;
    notifyListeners();
  }
}

typedef FlowLayerPainter = void Function(
    Canvas canvas, FlowLayoutSnapshot layout);
