part of 'flow.dart';

/// A glyph resource has no participant, range, origin, or decoration ownership.
/// All current painter inputs except the span are fixed by this factory. Sharing
/// stays within one synchronous layout, so font changes cannot leave stale data.
class _TextShape {
  _TextShape(this.painter, {this.onDispose});
  final TextPainter painter;
  final void Function(_TextShape)? onDispose;
  int _references = 1;
  late final metrics = painter.computeLineMetrics();

  static _TextShape build(InlineSpan span,
      {void Function(_TextShape)? onDispose}) {
    final painter =
        TextPainter(text: span, textDirection: TextDirection.ltr, maxLines: 1);
    try {
      painter.layout();
    } catch (_) {
      painter.dispose();
      rethrow;
    }
    return _TextShape(painter, onDispose: onDispose);
  }

  void retain() {
    assert(_references > 0);
    _references++;
  }

  void release() {
    assert(_references > 0);
    if (--_references == 0) {
      painter.dispose();
      onDispose?.call(this);
    }
  }

  void abort() {
    assert(_references > 0);
    _references = 0;
    painter.dispose();
    onDispose?.call(this);
  }
}

class _TextShapeCache {
  final _entries = <InlineSpan, ({_TextShape shape, int weight})>{};
  final _active = <_TextShape>{};
  int _units = 0;
  bool _closed = false;
  int debugBuilds = 0, debugHits = 0, debugPeakEntries = 0;

  _TextShape acquire(InlineSpan span, int units, {bool allowCache = true}) {
    assert(!_closed);
    final shareable = allowCache && _canShare(span);
    if (shareable) {
      final cached = _entries.remove(span);
      if (cached != null) {
        _entries[span] = cached;
        cached.shape.retain();
        assert(() {
          debugHits++;
          return true;
        }());
        return cached.shape;
      }
    }
    final shape = _TextShape.build(span, onDispose: _active.remove);
    _active.add(shape);
    assert(() {
      debugBuilds++;
      return true;
    }());
    final weight = math.max(1, units);
    if (!shareable || weight > 65536) {
      return shape; // Caller owns the initial lease.
    }
    while (_entries.isNotEmpty &&
        (_entries.length >= 256 || _units + weight > 65536)) {
      final evicted = _entries.remove(_entries.keys.first)!;
      _units -= evicted.weight;
      evicted.shape.release(); // Committed users retain their own leases.
    }
    _entries[span] = (shape: shape, weight: weight);
    _units += weight;
    assert(() {
      debugPeakEntries = math.max(debugPeakEntries, _entries.length);
      return true;
    }());
    shape.retain(); // One cache lease and one caller lease.
    return shape;
  }

  // Paint is explicitly mutable; identity equality cannot snapshot its state.
  // Such text retains the uncached path and all existing paint capabilities.
  bool _canShare(InlineSpan span) {
    if (span is! TextSpan ||
        span.style?.foreground != null ||
        span.style?.background != null) {
      return false;
    }
    return span.children?.every(_canShare) ?? true;
  }

  void close() {
    if (_closed) return;
    _closed = true;
    for (final entry in _entries.values) {
      entry.shape.release();
    }
    _entries.clear();
    _units = 0;
  }

  void abort() {
    if (_closed) return;
    _closed = true;
    // Only called before any snapshot is published. Discarded proposal leases
    // cannot escape the failed composition; previous snapshots use other pools.
    for (final shape in _active.toList()) {
      shape.abort();
    }
    _entries.clear();
    _units = 0;
  }
}
