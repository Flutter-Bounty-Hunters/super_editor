import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../tool/src/profile_baseline.dart';

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
    'fixtureVersion': 1,
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
      for (final name in ['test_boxes', 'demo_buttons'])
        {
          'name': name,
          'textCharacters': 10000,
          'inlineWidgets': 100,
          'fontSize': name == 'demo_buttons' ? 18 : 20,
          'obstacle': name == 'demo_buttons',
          'samples': {
            for (final phase in ['initial', 'resize', 'update'])
              phase: [
                for (final time in [1000, 1100, 1200]) {'fullLayoutUs': time}
              ]
          },
          'summary': {
            for (final phase in ['initial', 'resize', 'update'])
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
  test('all scenarios and statistics receive the allowance', () {
    final (baseline, host) = fixture();
    final budgets = makeProfileBudgets(baseline, host, samples: 3);
    for (final dynamic phases
        in (budgets['scenarios'] as Map<String, dynamic>).values) {
      expect(phases, hasLength(3));
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
      'fixtureVersion': 2,
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
}
