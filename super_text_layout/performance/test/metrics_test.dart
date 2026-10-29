import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:performance/src/metrics.dart';
import 'package:performance/src/widgets.dart';

List<Map<String, dynamic>> readDocuments() => [
      for (final file in [
        'baseline',
        'current',
        'budget_check',
        'cpu_baseline',
        'cpu_current'
      ])
        jsonDecode(File('assets/metrics/$file.json').readAsStringSync())
            as Map<String, dynamic>,
    ];

void main() {
  test('bundled raw results reproduce the recorded fifty-check outcome', () {
    final data = MetricsData.fromJson(readDocuments());
    expect(data.current.length, 5);
    expect(data.checks.length, 50);
    expect(
        data.failures
            .map((c) => '${c.benchmark.id}.${c.operation}.${c.statistic.key}'),
        [
          'demo_buttons.initial.median',
          'long_prose.resize.p95',
          'long_prose.edit_beginning.p95',
          'long_prose.edit_middle.p95',
          'long_prose.edit_end.p95',
        ]);
    expect(data.withinFrame(TimingStatistic.median, 1000 / 60), 23);
    expect(data.withinFrame(TimingStatistic.median, 1000 / 120), 14);
    // Displayed summaries must agree with raw samples, with µs converted once.
    for (final b in data.current) {
      for (final timing in b.timings.values) {
        final sorted = timing.samples.toList()..sort();
        expect(sorted.length, data.samples);
        expect(timing.value(TimingStatistic.median),
            closeTo((sorted[14] + sorted[15]) / 2, 1e-9));
        expect(timing.value(TimingStatistic.p95), sorted[28]);
      }
    }
    expect(
        data
            .benchmark('decorated_code')
            .timings['resize']!
            .value(TimingStatistic.median),
        9.0525);
    for (final phase in data.cpuCurrent) {
      expect(phase.buckets.values.reduce((a, b) => a + b), phase.samples);
      expect(phase.layouts, 10);
    }
    expect(data.reproduceCommand.split('\n').length, 4);
    expect(File('lib/main_profile_macos.dart').existsSync(), isTrue);
  });

  test(
      'budget warnings start at 80 percent and exceedance is strictly above budget',
      () {
    expect(timingColor(TimingStatistic.median, milliseconds: 7.99, budget: 10),
        Palette.green);
    expect(timingColor(TimingStatistic.median, milliseconds: 8, budget: 10),
        Palette.amber);
    expect(timingColor(TimingStatistic.median, milliseconds: 10, budget: 10),
        Palette.amber);
    expect(timingColor(TimingStatistic.median, milliseconds: 10.01, budget: 10),
        Palette.red);
    expect(timingColor(TimingStatistic.p95, milliseconds: 7.99, budget: 10),
        Palette.p95);
    expect(timingColor(TimingStatistic.p95, milliseconds: 8, budget: 10),
        isNot(Palette.p95));
    expect(timingColor(TimingStatistic.p95, milliseconds: 10.01, budget: 10),
        isNot(timingColor(TimingStatistic.p95, milliseconds: 10, budget: 10)));
  });

  test(
      'incompatible snapshots and inconsistent recorded checks fail explicitly',
      () {
    var documents = readDocuments();
    documents[1]['fixtureVersion'] = 99;
    expect(() => MetricsData.fromJson(documents), throwsFormatException);
    documents = readDocuments();
    documents[1]['budgetFailures'] = [];
    expect(() => MetricsData.fromJson(documents), throwsFormatException);
  });
}
