import 'dart:convert';
import 'package:flutter/services.dart';

enum TimingStatistic {
  median('median', 'Median'),
  p95('p95', 'p95');

  const TimingStatistic(this.key, this.label);
  final String key;
  final String label;
}

const operations = <String, String>{
  'initial': 'Initial layout',
  'resize': 'Resize',
  'edit_beginning': 'Edit at beginning',
  'edit_middle': 'Edit in middle',
  'edit_end': 'Edit at end',
};
const shortOperations = [
  'Initial',
  'Resize',
  'Edit start',
  'Edit middle',
  'Edit end'
];
const benchmarkNames = <String, String>{
  'test_boxes': 'Inline boxes',
  'demo_buttons': 'Interactive buttons',
  'long_prose': 'Long prose',
  'unique_prose': 'Nonrepeating prose',
  'decorated_code': 'Padded code',
};
const cpuNames = <String, String>{
  'numeric_model_preparation': 'Width-model preparation',
  'exact_fragment_artifacts': 'Exact Flutter fragments',
  'source_preparation': 'Source preparation',
  'numeric_chunk_preparation': 'Chunk preparation',
  'numeric_exact_widths': 'Other numeric widths',
  'numeric_candidate_search': 'Candidate search',
  'fragment_commit': 'Fragment commits',
  'gc': 'Garbage collection',
  'child_layout': 'Widget layout',
  'other_layout': 'Other layout work',
};

class Timing {
  Timing(Map<String, dynamic> json, List<dynamic> rawSamples)
      : statistics = Map.unmodifiable({
          for (final entry in json.entries)
            entry.key: (entry.value as num).toDouble() / 1000,
        }),
        samples = List.unmodifiable(rawSamples.map(
            (dynamic row) => (row['fullLayoutUs'] as num).toDouble() / 1000));
  final Map<String, double> statistics;
  final List<double> samples;
  double value(TimingStatistic statistic) => statistics[statistic.key]!;
}

class Benchmark {
  Benchmark(Map<String, dynamic> json)
      : id = json['name'] as String,
        characters = json['textCharacters'] as int,
        widgets = json['inlineWidgets'] as int,
        decorations = json['decorations'] as int? ?? 0,
        obstacle = json['obstacle'] as bool,
        timings = Map.unmodifiable({
          for (final phase in operations.keys)
            phase: Timing(
                Map<String, dynamic>.from(
                    json['summary'][phase]['fullLayoutUs'] as Map),
                json['samples'][phase] as List<dynamic>),
        });
  final String id;
  final int characters, widgets, decorations;
  final bool obstacle;
  final Map<String, Timing> timings;
  String get title => benchmarkNames[id] ?? id;
  String get description =>
      '${number(characters)} characters · $widgets inline widgets'
      '${decorations == 0 ? '' : ' · $decorations decorations'}'
      '${obstacle ? ' · obstacle flow' : ''}';
}

class RegressionCheck {
  const RegressionCheck(
      this.benchmark, this.operation, this.statistic, this.current, this.limit);
  final Benchmark benchmark;
  final String operation;
  final TimingStatistic statistic;
  final double current, limit;
  bool get passed => current <= limit;
  double get excessPercent => (current / limit - 1) * 100;
}

class CpuPhase {
  CpuPhase(Map<String, dynamic> json)
      : benchmark = json['scenario'] as String,
        operation = json['phase'] as String,
        samples = json['sampleCount'] as int,
        layouts = json['layoutCount'] as int,
        missing = json['layoutsWithoutSamples'] as int,
        buckets = Map<String, int>.from(json['exclusiveBuckets'] as Map),
        slowest = List<Map<String, dynamic>>.from(
            json['layoutsSlowestFirst'] as List);
  final String benchmark, operation;
  final int samples, layouts, missing;
  final Map<String, int> buckets;
  final List<Map<String, dynamic>> slowest;
}

class MetricsData {
  MetricsData._(this.baselineRaw, this.currentRaw, this.budgetRaw,
      this.cpuBaselineRaw, this.cpuCurrentRaw)
      : baseline = List.unmodifiable((baselineRaw['scenarios'] as List).map(
            (dynamic row) => Benchmark(Map<String, dynamic>.from(row as Map)))),
        current = List.unmodifiable((currentRaw['scenarios'] as List).map(
            (dynamic row) => Benchmark(Map<String, dynamic>.from(row as Map)))),
        cpuBaseline = List.unmodifiable((cpuBaselineRaw['phases'] as List).map(
            (dynamic row) => CpuPhase(Map<String, dynamic>.from(row as Map)))),
        cpuCurrent = List.unmodifiable((cpuCurrentRaw['phases'] as List).map(
            (dynamic row) => CpuPhase(Map<String, dynamic>.from(row as Map))));

  factory MetricsData.fromJson(List<Map<String, dynamic>> documents) {
    if (documents.length != 5) {
      throw const FormatException('Expected five metric documents.');
    }
    final before = documents[0], after = documents[1];
    for (final key in [
      'schemaVersion',
      'fixtureVersion',
      'platform',
      'mode',
      'samplesPerPhase'
    ]) {
      if (before[key] != after[key]) {
        throw FormatException('Incompatible snapshots: $key differs.');
      }
    }
    final data =
        MetricsData._(before, after, documents[2], documents[3], documents[4]);
    if (data.baseline.map((b) => b.id).join(',') !=
        data.current.map((b) => b.id).join(',')) {
      throw const FormatException('Benchmark cases do not match.');
    }
    if (data.failures.length != (after['budgetFailures'] as List).length) {
      throw const FormatException(
          'Recorded regression checks do not match the timing data.');
    }
    return data;
  }

  static Future<MetricsData> load({AssetBundle? bundle}) async {
    final assets = bundle ?? rootBundle;
    final documents = await Future.wait([
      for (final file in [
        'baseline',
        'current',
        'budget_check',
        'cpu_baseline',
        'cpu_current'
      ])
        assets
            .loadString('assets/metrics/$file.json')
            .then((text) => jsonDecode(text) as Map<String, dynamic>),
    ]);
    return MetricsData.fromJson(documents);
  }

  final Map<String, dynamic> baselineRaw,
      currentRaw,
      budgetRaw,
      cpuBaselineRaw,
      cpuCurrentRaw;
  final List<Benchmark> baseline, current;
  final List<CpuPhase> cpuBaseline, cpuCurrent;
  Map<String, dynamic> get host => currentRaw['host'] as Map<String, dynamic>;
  int get samples => currentRaw['samplesPerPhase'] as int;
  int get warmups => currentRaw['warmupCycles'] as int;
  DateTime get recordedAt =>
      DateTime.parse(currentRaw['recordedAtUtc'] as String).toUtc();
  double get allowance =>
      (currentRaw['baselineComparison']['maxRegressionPercent'] as num)
          .toDouble();
  Benchmark before(String id) => baseline.firstWhere((b) => b.id == id);
  Benchmark benchmark(String id) => current.firstWhere((b) => b.id == id);
  double limit(String id, String phase, TimingStatistic statistic) =>
      (budgetRaw['budgets']['scenarios'][id][phase][statistic.key] as num)
          .toDouble() /
      1000;
  List<RegressionCheck> get checks => [
        for (final benchmark in current)
          for (final phase in operations.keys)
            for (final statistic in TimingStatistic.values)
              RegressionCheck(
                  benchmark,
                  phase,
                  statistic,
                  benchmark.timings[phase]!.value(statistic),
                  limit(benchmark.id, phase, statistic)),
      ];
  List<RegressionCheck> get failures =>
      checks.where((check) => !check.passed).toList();
  int withinFrame(TimingStatistic statistic, double budget) => current.fold(
      0,
      (total, benchmark) =>
          total +
          benchmark.timings.values
              .where((timing) => timing.value(statistic) <= budget)
              .length);
  String get reproduceCommand => 'cd performance\n'
      'dart run lib/main_profile_macos.dart \\\n'
      '  --baseline assets/metrics/baseline.json \\\n'
      '  --output build/profile/performance-check.json';
}

String number(int value) => value
    .toString()
    .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
String milliseconds(double value) => value.toStringAsFixed(2);
String change(double current, double baseline) =>
    '${current <= baseline ? '−' : '+'}${((current / baseline - 1) * 100).abs().toStringAsFixed(1)}%';
String snapshotDate(DateTime date) => '${date.day} ${const [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ][date.month - 1]} ${date.year}';
