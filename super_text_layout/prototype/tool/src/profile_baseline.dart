/// Validates a reviewed integration baseline and derives timing limits.
/// No Flutter imports: the command-line runner uses the regular Dart VM.
Map<String, dynamic> makeProfileBudgets(
  Object? input,
  Map<String, dynamic> host, {
  required int samples,
  double maxRegressionPercent = 20,
  bool allowSdkChange = false,
}) {
  if (samples < 1 ||
      !maxRegressionPercent.isFinite ||
      maxRegressionPercent < 0) {
    throw const FormatException(
        'Samples must be positive and the regression allowance finite and nonnegative.');
  }
  final baseline = _object(input, 'Baseline');
  final expected = <String, dynamic>{
    'schemaVersion': 1,
    'fixtureVersion': 1,
    'execution': 'integration_test',
    'mode': 'profile',
    'platform': 'macOS',
    'web': false,
    'warmupCycles': 5,
    'samplesPerPhase': samples,
    'widths': [600, 320],
    'viewport': [800, 600],
  };
  for (final entry in expected.entries) {
    if (!baseline.containsKey(entry.key) ||
        !_sameValue(baseline[entry.key], entry.value)) {
      throw FormatException(
          'Incompatible baseline ${entry.key}: expected ${entry.value}; '
          'record a baseline with this integration test and settings.');
    }
  }
  final previousHost = _object(baseline['host'], 'Baseline host');
  for (final field in [
    'cpu',
    'architecture',
    'macOS',
    'physicalCores',
    'memoryBytes'
  ]) {
    if (!previousHost.containsKey(field) ||
        previousHost[field] != host[field]) {
      throw FormatException(
          'Baseline host $field differs; use a baseline from the same benchmark machine.');
    }
  }
  if (!allowSdkChange) {
    final previousSdk =
        _object(previousHost['flutter'], 'Baseline Flutter metadata');
    final currentSdk = _object(host['flutter'], 'Current Flutter metadata');
    for (final field in [
      'frameworkRevision',
      'engineRevision',
      'dartSdkVersion'
    ]) {
      if (previousSdk[field] == null ||
          previousSdk[field] != currentSdk[field]) {
        throw FormatException(
            'Baseline Flutter $field differs; use --allow-sdk-change only for an intentional SDK comparison.');
      }
    }
  }
  final scenarios = _list(baseline['scenarios'], 'Baseline scenarios');
  final names = scenarios.map((s) => _object(s, 'Scenario')['name']).toSet();
  if (scenarios.length != 2 ||
      names.length != 2 ||
      !names.containsAll(['test_boxes', 'demo_buttons'])) {
    throw const FormatException(
        'Baseline must contain both standard benchmark scenarios.');
  }
  final factor = 1 + maxRegressionPercent / 100;
  final budgets = <String, dynamic>{};
  for (final value in scenarios) {
    final scenario = _object(value, 'Scenario');
    final name = scenario['name'] as String;
    final fixture = {
      'textCharacters': 10000,
      'inlineWidgets': 100,
      'fontSize': name == 'demo_buttons' ? 18 : 20,
      'obstacle': name == 'demo_buttons'
    };
    if (fixture.entries.any((e) => scenario[e.key] != e.value)) {
      throw FormatException('Baseline fixture $name differs.');
    }
    final sampleSets = _object(scenario['samples'], 'Samples for $name');
    final summaries = _object(scenario['summary'], 'Summary for $name');
    final phases = <String, dynamic>{};
    for (final phase in ['initial', 'resize', 'update']) {
      final values = _list(sampleSets[phase], 'Samples for $name.$phase');
      final times = <num>[];
      for (final sample in values) {
        final time = _object(sample, 'Sample for $name.$phase')['fullLayoutUs'];
        if (time is! num || !time.isFinite || time <= 0) {
          throw FormatException('Invalid baseline samples for $name.$phase.');
        }
        times.add(time);
      }
      if (times.length != samples) {
        throw FormatException(
            'Invalid baseline sample count for $name.$phase.');
      }
      times.sort();
      final mid = times.length ~/ 2;
      final median =
          times.length.isOdd ? times[mid] : (times[mid - 1] + times[mid]) / 2;
      final p95 = times[(times.length * .95).ceil() - 1];
      final summary = _object(summaries[phase], 'Summary for $name.$phase');
      final recorded =
          _object(summary['fullLayoutUs'], 'Timing summary for $name.$phase');
      if (recorded['median'] != median || recorded['p95'] != p95) {
        throw FormatException(
            'Baseline summary disagrees with raw samples for $name.$phase.');
      }
      phases[phase] = {'median': median * factor, 'p95': p95 * factor};
    }
    budgets[name] = phases;
  }
  return {'fixtureVersion': 1, 'scenarios': budgets};
}

Map<String, dynamic> _object(Object? value, String label) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('$label must be a JSON object.');
  }
  return value;
}

List<dynamic> _list(Object? value, String label) {
  if (value is! List<dynamic>) {
    throw FormatException('$label must be a JSON array.');
  }
  return value;
}

bool _sameValue(Object? actual, Object? expected) {
  if (actual is List && expected is List) {
    if (actual.length != expected.length) return false;
    for (var i = 0; i < actual.length; i++) {
      if (!_sameValue(actual[i], expected[i])) return false;
    }
    return true;
  }
  return actual == expected;
}
