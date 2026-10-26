import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flow_layout_prototype/profile_benchmark.dart';
import 'package:flow_layout_prototype/profile_budgets.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets(
      'profile layout benchmark stays within its matching-machine budget',
      (tester) async {
    expect(kProfileMode, isTrue,
        reason: 'Run this integration test with --profile.');
    expect(const bool.fromEnvironment('FLOW_PROFILE_LAYOUT'), isFalse,
        reason: 'Timing regression runs must have CPU-sampling tags disabled.');
    expect(const bool.fromEnvironment('FLOW_BENCHMARK_WAIT_FOR_PROFILER'),
        isFalse);
    await binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => binding.setSurfaceSize(null));
    final raw =
        await tester.runAsync(() => runFlowProfileBenchmark(logResult: false));
    final result = Map<String, dynamic>.from(raw!);
    result['execution'] = 'integration_test';
    result['viewport'] = [800, 600];
    const budgetText = String.fromEnvironment('FLOW_BENCHMARK_BUDGETS');
    final budgets = budgetText.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(budgetText) as Map<String, dynamic>;
    // Preserve samples even if a budget or assertion is invalid.
    binding.reportData = {
      'benchmark': result,
      'budgets': budgets,
      'budgetFailures': <String>[],
      'budgetEnforced': budgets.isNotEmpty
    };
    final failures = profileBudgetFailures(result, budgets);
    binding.reportData!['budgetFailures'] = failures;
    expect(result['scenarios'], hasLength(2));
    final samples = result['samplesPerPhase'] as int;
    expect(samples, greaterThan(0));
    for (final dynamic scenario in result['scenarios'] as List<dynamic>) {
      expect(scenario['textCharacters'], 10000);
      expect(scenario['inlineWidgets'], 100);
      for (final phase in ['initial', 'resize', 'update']) {
        final values = scenario['samples'][phase] as List<dynamic>;
        expect(values, hasLength(samples));
        for (final dynamic sample in values) {
          expect(sample['fullLayoutUs'], greaterThan(0));
          expect(sample['compositionUs'],
              lessThanOrEqualTo(sample['fullLayoutUs'] as num));
          expect(sample['lines'], greaterThan(0));
          expect(sample['fragments'], greaterThan(0));
        }
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
    await tester.pumpWidget(const SizedBox.shrink());
  }, timeout: const Timeout(Duration(minutes: 5)));
}
