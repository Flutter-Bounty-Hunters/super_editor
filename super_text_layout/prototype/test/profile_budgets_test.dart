import 'package:flow_layout_prototype/profile_fixture_data.dart';

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flow_layout_prototype/profile_budgets.dart';

Map<String, dynamic> result() => {
      'fixtureVersion': 1,
      'scenarios': [
        for (final name in ['test_boxes', 'demo_buttons'])
          {
            'name': name,
            'summary': {
              for (final phase in profilePhases)
                phase: {
                  'fullLayoutUs': <String, dynamic>{
                    'median': 20000,
                    'p95': 30000
                  },
                },
            }
          },
      ]
    };
Map<String, dynamic> budgets() => {
      'fixtureVersion': 1,
      'scenarios': {
        for (final name in ['test_boxes', 'demo_buttons'])
          name: {
            for (final phase in profilePhases)
              phase: <String, dynamic>{'median': 24000, 'p95': 36000},
          },
      }
    };

void main() {
  test('record-only mode does not apply a timing assertion', () {
    expect(profileBudgetFailures(result(), {}), isEmpty);
  });
  test('all median and p95 limits accept matching or faster samples', () {
    expect(profileBudgetFailures(result(), budgets()), isEmpty);
    final exact = budgets();
    exact['scenarios']['test_boxes']['initial']['median'] = 20000;
    exact['scenarios']['demo_buttons']['edit_end']['p95'] = 30000;
    expect(profileBudgetFailures(result(), exact), isEmpty);
  });
  test('median and tail regressions both fail with scenario and phase names',
      () {
    final current = result();
    current['scenarios'][0]['summary']['initial']['fullLayoutUs']['median'] =
        25000;
    current['scenarios'][1]['summary']['resize']['fullLayoutUs']['p95'] = 37000;
    final failures = profileBudgetFailures(current, budgets());
    expect(failures, hasLength(2));
    expect(failures[0], contains('test_boxes.initial median'));
    expect(failures[1], contains('demo_buttons.resize p95'));
  });
  test('fixture and scenario changes cannot silently bypass budgets', () {
    final changed = result()..['fixtureVersion'] = 2;
    expect(
        profileBudgetFailures(changed, budgets()).single, contains('version'));
    final missing = result();
    (missing['scenarios'] as List<dynamic>).removeLast();
    expect(profileBudgetFailures(missing, budgets()).single,
        contains('scenario set'));
  });
  test('missing or invalid limits fail closed', () {
    for (final value in [null, 0, -1, double.nan, double.infinity]) {
      final limits = budgets();
      limits['scenarios']['test_boxes']['initial']['median'] = value;
      expect(profileBudgetFailures(result(), limits), isNotEmpty);
    }
    final missing = budgets();
    (missing['scenarios']['test_boxes'] as Map<String, dynamic>)
        .remove('resize');
    expect(profileBudgetFailures(result(), missing).single,
        contains('test_boxes.resize'));
  });
  test('nonfinite or negative observations fail instead of passing', () {
    for (final value in [double.nan, double.infinity, -1]) {
      final current = result();
      current['scenarios'][0]['summary']['initial']['fullLayoutUs']['median'] =
          value;
      expect(profileBudgetFailures(current, budgets()), isNotEmpty);
    }
  });
  test('JSON round-trip preserves threshold comparison', () {
    final decoded = jsonDecode(jsonEncode(budgets())) as Map<String, dynamic>;
    expect(profileBudgetFailures(result(), decoded), isEmpty);
  });
  test('beginning and middle median/p95 regressions are gated', () {
    for (final phase in ['edit_beginning', 'edit_middle', 'edit_end']) {
      for (final statistic in ['median', 'p95']) {
        final current = result();
        current['scenarios'][0]['summary'][phase]['fullLayoutUs'][statistic] =
            999999;
        expect(profileBudgetFailures(current, budgets()).single,
            contains('test_boxes.$phase $statistic'));
      }
    }
  });
}
