import 'package:flow_layout_prototype/profile_fixture_data.dart';

/// Pure comparison used by the integration test. All limits are microseconds;
/// the runner derives them from a compatible machine's recorded baseline.
List<String> profileBudgetFailures(
    Map<String, dynamic> result, Map<String, dynamic> budgets) {
  if (budgets.isEmpty) return [];
  final failures = <String>[];
  if (budgets['fixtureVersion'] != result['fixtureVersion']) {
    return ['Benchmark fixture version differs from the baseline.'];
  }
  final rawLimits = budgets['scenarios'];
  if (rawLimits is! Map<String, dynamic>) {
    return ['Missing scenario timing budgets.'];
  }
  final limits = rawLimits;
  final scenarios = result['scenarios'] as List<dynamic>;
  final names = scenarios.map((dynamic s) => s['name'] as String).toSet();
  if (names.length != scenarios.length ||
      names.length != limits.length ||
      !names.containsAll(limits.keys)) {
    return ['Benchmark scenario set differs from the baseline.'];
  }
  for (final dynamic scenario in scenarios) {
    final name = scenario['name'] as String;
    final phases = limits[name];
    if (phases is! Map<String, dynamic>) {
      failures.add('Missing timing budgets for $name.');
      continue;
    }
    for (final phase in profilePhases) {
      final stats =
          scenario['summary'][phase]['fullLayoutUs'] as Map<String, dynamic>;
      final caps = phases[phase];
      if (caps is! Map<String, dynamic>) {
        failures.add('Missing timing budgets for $name.$phase.');
        continue;
      }
      for (final statistic in ['median', 'p95']) {
        final observed = stats[statistic];
        final cap = caps[statistic];
        if (observed is! num ||
            cap is! num ||
            !observed.isFinite ||
            observed < 0 ||
            !cap.isFinite ||
            cap <= 0) {
          failures
              .add('$name.$phase.$statistic has an invalid timing or budget.');
        } else if (observed > cap) {
          failures.add(
              '$name.$phase $statistic: ${(observed / 1000).toStringAsFixed(2)} ms '
              'exceeds ${(cap / 1000).toStringAsFixed(2)} ms budget.');
        }
      }
    }
  }
  return failures;
}
