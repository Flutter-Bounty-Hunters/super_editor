import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:performance/profiling/profile_baseline.dart';
import 'package:performance/fixtures/profile_fixture_data.dart';

(Map<String, dynamic>, Map<String, dynamic>) fixture() {
  final host = {
    'cpu': 'test cpu',
    'architecture': 'arm64',
    'macOS': 'test os',
    'physicalCores': 10,
    'memoryBytes': 1000,
    'flutter': {
      'frameworkRevision': 'f',
      'engineRevision': 'e',
      'dartSdkVersion': 'd'
    }
  };
  final baseline = {
    'schemaVersion': 1,
    'fixtureVersion': profileFixtureVersion,
    'editSetup': profileEditSetup,
    'editText': profileEditText,
    'execution': 'integration_test',
    'mode': 'profile',
    'platform': 'macOS',
    'web': false,
    'warmupCycles': 5,
    'samplesPerPhase': 3,
    'widths': [600, 320],
    'viewport': [800, 600],
    'host': host,
    'scenarios': [
      for (final name in profileFixtureMetadata.keys)
        {
          'name': name,
          ...profileFixtureMetadata[name]!,
          'samples': {
            for (final phase in profilePhases)
              phase: [
                for (final time in [1000, 1100, 1200]) {'fullLayoutUs': time}
              ]
          },
          'summary': {
            for (final phase in profilePhases)
              phase: {
                'fullLayoutUs': {'median': 1100, 'p95': 1200}
              }
          },
        }
    ],
  };
  // Use JSON-decoded collection types just like the runner's saved artifacts.
  return (
    jsonDecode(jsonEncode(baseline)) as Map<String, dynamic>,
    jsonDecode(jsonEncode(host)) as Map<String, dynamic>
  );
}

void main() {
  test(
      'automatic baselines distinguish compact integration from older automatic runs',
      () {
    final (baseline, host) = fixture();
    baseline['textFitting'] = 'automatic';
    expect(
        () => makeProfileBudgets(baseline, host,
            samples: 3, textFitting: 'automatic'),
        throwsFormatException);
    baseline['fittingImplementation'] = 'compact-v1';
    expect(
        makeProfileBudgets(baseline, host,
            samples: 3, textFitting: 'automatic'),
        isNotEmpty);
    baseline['fittingImplementation'] = 'compact-binary-v1';
    expect(
        makeProfileBudgets(baseline, host,
            samples: 3, textFitting: 'automatic'),
        isNotEmpty);
    baseline['fittingImplementation'] = 'compact-padded-v1';
    expect(
        makeProfileBudgets(baseline, host,
            samples: 3, textFitting: 'automatic'),
        isNotEmpty);
    baseline['fittingImplementation'] = 'compact-intrinsic-v1';
    expect(
        makeProfileBudgets(baseline, host,
            samples: 3, textFitting: 'automatic'),
        isNotEmpty);
  });

  test('linear compact baselines retain their implementation identity', () {
    final (baseline, host) = fixture();
    baseline['textFitting'] = 'linear-compact';
    baseline['fittingImplementation'] = 'compact-v1';
    expect(
        makeProfileBudgets(baseline, host,
            samples: 3, textFitting: 'linear-compact'),
        isNotEmpty);
    baseline['fittingImplementation'] = 'compact-binary-v1';
    expect(
        () => makeProfileBudgets(baseline, host,
            samples: 3, textFitting: 'linear-compact'),
        throwsFormatException);
    baseline['fittingImplementation'] = 'compact-padded-linear-v1';
    expect(
        makeProfileBudgets(baseline, host,
            samples: 3, textFitting: 'linear-compact'),
        isNotEmpty);
    baseline['fittingImplementation'] = 'compact-intrinsic-linear-v1';
    expect(
        makeProfileBudgets(baseline, host,
            samples: 3, textFitting: 'linear-compact'),
        isNotEmpty);
  });
  test('all scenarios and statistics receive the allowance', () {
    final (baseline, host) = fixture();
    final budgets = makeProfileBudgets(baseline, host, samples: 3);
    for (final dynamic phases
        in (budgets['scenarios'] as Map<String, dynamic>).values) {
      expect(phases, hasLength(profilePhases.length));
      for (final dynamic stats in (phases as Map<String, dynamic>).values) {
        expect(stats, {'median': 1320, 'p95': 1440});
      }
    }
  });
  test('different machine or OS is rejected', () {
    for (final entry in {
      'cpu': 'other',
      'architecture': 'x64',
      'macOS': 'other',
      'physicalCores': 8,
      'memoryBytes': 2000
    }.entries) {
      final (baseline, host) = fixture();
      host[entry.key] = entry.value;
      expect(() => makeProfileBudgets(baseline, host, samples: 3),
          throwsFormatException);
    }
  });
  test('SDK changes require an override that retains hardware checks', () {
    final (baseline, host) = fixture();
    host['flutter']['engineRevision'] = 'new';
    expect(() => makeProfileBudgets(baseline, host, samples: 3),
        throwsFormatException);
    expect(makeProfileBudgets(baseline, host, samples: 3, allowSdkChange: true),
        isNotEmpty);
    host['cpu'] = 'other';
    expect(
        () => makeProfileBudgets(baseline, host,
            samples: 3, allowSdkChange: true),
        throwsFormatException);
  });
  test('mode, harness, fixture, viewport and sample-count changes are rejected',
      () {
    for (final entry in {
      'mode': 'debug',
      'execution': 'standalone',
      'fixtureVersion': profileFixtureVersion + 1,
      'samplesPerPhase': 2,
      'widths': [300, 200],
      'viewport': [1000, 800]
    }.entries) {
      final (baseline, host) = fixture();
      baseline[entry.key] = entry.value;
      expect(() => makeProfileBudgets(baseline, host, samples: 3),
          throwsFormatException);
    }
  });
  test('missing and changed scenarios are rejected', () {
    final (baseline, host) = fixture();
    (baseline['scenarios'] as List<dynamic>).removeLast();
    expect(() => makeProfileBudgets(baseline, host, samples: 3),
        throwsFormatException);
    final (changed, currentHost) = fixture();
    changed['scenarios'][0]['fontSize'] = 30;
    expect(() => makeProfileBudgets(changed, currentHost, samples: 3),
        throwsFormatException);
  });
  test('stale summaries cannot create incorrect budgets', () {
    final (baseline, host) = fixture();
    baseline['scenarios'][0]['summary']['initial']['fullLayoutUs']['median'] =
        50000;
    expect(() => makeProfileBudgets(baseline, host, samples: 3),
        throwsFormatException);
  });
  test('invalid samples and allowances are rejected', () {
    for (final value in [0, -1, double.nan, double.infinity, true, '1000']) {
      final (baseline, host) = fixture();
      baseline['scenarios'][0]['samples']['initial'][0]['fullLayoutUs'] = value;
      expect(() => makeProfileBudgets(baseline, host, samples: 3),
          throwsFormatException);
    }
    for (final value in [-1.0, double.nan, double.infinity]) {
      final (baseline, host) = fixture();
      expect(
          () => makeProfileBudgets(baseline, host,
              samples: 3, maxRegressionPercent: value),
          throwsFormatException);
    }
  });
  test('incomplete JSON fails with a diagnostic instead of producing budgets',
      () {
    final (_, host) = fixture();
    for (final value in [null, [], <String, dynamic>{}]) {
      expect(() => makeProfileBudgets(value, host, samples: 3),
          throwsFormatException);
    }
  });
  test('all edit phases and independent edit setup are required', () {
    for (final phase in ['edit_beginning', 'edit_middle', 'edit_end']) {
      final (baseline, host) = fixture();
      (baseline['scenarios'][0]['samples'] as Map).remove(phase);
      expect(() => makeProfileBudgets(baseline, host, samples: 3),
          throwsFormatException);
    }
    final (baseline, host) = fixture();
    baseline['editSetup'] = 'reuse the previous edit';
    expect(() => makeProfileBudgets(baseline, host, samples: 3),
        throwsFormatException);
  });
  test('text-fitting policies cannot silently share timing budgets', () {
    final (baseline, host) = fixture();
    expect(
        () => makeProfileBudgets(baseline, host,
            samples: 3, textFitting: 'flutter'),
        throwsFormatException);
    baseline['textFitting'] = 'flutter';
    expect(() => makeProfileBudgets(baseline, host, samples: 3),
        throwsFormatException);
    expect(
        makeProfileBudgets(baseline, host, samples: 3, textFitting: 'flutter'),
        isNotEmpty);
  });
}
