part of 'flow.dart';

typedef _TextChoiceKey = ({
  String text,
  TextStyle paragraphStyle,
  TextStyle contentStyle,
  int start,
  double availableWidth,
  double maximumWidth,
});

class _BreakDecision {
  const _BreakDecision(this.opportunity);
  // Null means the complete search found no fitting candidate.
  final FlowBreakOpportunity? opportunity;
}

/// Retains only immutable text inputs and decisions, never participants or
/// native painters. A cache hit still measures and commits a fresh artifact.
class _TextChoiceCache {
  final _entries = <_TextChoiceKey, _BreakDecision>{};
  int _units = 0;
  int debugHits = 0;

  _BreakDecision? lookup(_TextChoiceKey key) {
    final decision = _entries.remove(key);
    if (decision == null) return null;
    _entries[key] = decision;
    assert(() {
      debugHits++;
      return true;
    }());
    return decision;
  }

  void remember(_TextChoiceKey key, FlowBreakOpportunity? opportunity) {
    final weight = math.max(1, key.text.length);
    if (weight > 65536) return;
    if (_entries.remove(key) != null) _units -= weight;
    while (_entries.isNotEmpty &&
        (_entries.length >= 1024 || _units + weight > 65536)) {
      final oldest = _entries.keys.first;
      _entries.remove(oldest);
      _units -= math.max(1, oldest.text.length);
    }
    _entries[key] = _BreakDecision(opportunity);
    _units += weight;
  }

  void clear() {
    _entries.clear();
    _units = 0;
  }
}

// Private capability: only deterministic built-in text opts in. Custom sources
// can depend on mutable widget state and must continue their full search.
abstract interface class _ReusableBreakSource {
  _BreakDecision? lookupChoice(int start, FlowFragmentConstraints constraints);
  void rememberChoice(int start, FlowFragmentConstraints constraints,
      FlowBreakOpportunity? opportunity);
}
