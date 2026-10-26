part of 'flow.dart';

/// Exact widths of immutable spans shaped with the backend's fixed LTR,
/// single-line, unconstrained TextPainter configuration. No native resources,
/// source offsets, break decisions, or participant references are retained.
class _TextWidthCache {
  final _entries = <InlineSpan, ({double width, int units})>{};
  int _units = 0;
  int debugHits = 0;
  int debugEvictions = 0;

  double? lookup(InlineSpan span) {
    final value = _entries.remove(span);
    if (value == null) return null;
    _entries[span] = value;
    assert(() {
      debugHits++;
      return true;
    }());
    return value.width;
  }

  void remember(InlineSpan span, int length, double width) {
    final units = math.max(1, length);
    if (units > 2097152) return;
    final previous = _entries.remove(span);
    if (previous != null) _units -= previous.units;
    while (_entries.isNotEmpty &&
        (_entries.length >= 4096 || _units + units > 2097152)) {
      _units -= _entries.remove(_entries.keys.first)!.units;
      assert(() {
        debugEvictions++;
        return true;
      }());
    }
    _entries[span] = (width: width, units: units);
    _units += units;
  }

  void clear() {
    _entries.clear();
    _units = 0;
  }
}
