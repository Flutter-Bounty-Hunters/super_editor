import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../fixtures/profile_fixture_data.dart';
import 'prepared_text.dart';

final checkpointFixtures = <String, String>{
  'nonrepeating_prose': profileFixtureChunks['long_prose']!.single,
  'kerning': 'AVATAR WA To Ta VA Yo. Away we travel toward a wide valley.',
  'ligatures':
      'office affinity efficient fluffy difficult final waffle offline.',
  'spaces': '  alpha   beta     gamma  delta    epsilon   ',
  'emergency':
      'AVATARAVATARAVATARAVATAR affinityofficeaffinityoffice WWWiiiiWWWiiii',
};
Future<void> loadCheckpointFonts({String prefix = ''}) async {
  for (final font in [
    ('CheckpointRoboto', 'Roboto-Regular.ttf'),
    ('CheckpointMono', 'FiraMono-Regular.ttf')
  ]) {
    await (FontLoader(font.$1)
          ..addFont(rootBundle.load('${prefix}assets/fonts/${font.$2}')))
        .load();
  }
}

Map<String, Object> _summary(List<double> values) {
  final sorted = [...values]..sort();
  return {
    'samplesUs': values,
    'medianUs': sorted[sorted.length ~/ 2],
    'p95Us': sorted[(sorted.length * .95).ceil() - 1]
  };
}

Map<String, Object> runPreparedTextCheckpoint(
    {int samples = 3, int warmups = 3, int layoutBatch = 100}) {
  final results = <Map<String, Object>>[];
  for (final font in ['CheckpointRoboto', 'CheckpointMono']) {
    final style = TextStyle(
        fontFamily: font, fontSize: 20, color: const Color(0xff000000));
    for (final fixture in checkpointFixtures.entries) {
      final prepTimes = <double>[];
      late CheckpointSource source;
      late PreparedWidthModel prepared;
      for (var sample = -warmups; sample < samples; sample++) {
        final watch = Stopwatch()..start();
        final nextSource = CheckpointSource(fixture.value, style);
        final nextPrepared = CompactPreparedSegments(nextSource);
        watch.stop();
        if (sample >= 0) prepTimes.add(watch.elapsedMicroseconds.toDouble());
        if (sample == samples - 1) {
          source = nextSource;
          prepared = nextPrepared;
        } else {
          nextSource.dispose();
        }
      }
      // Preserve checkpoint 1's probe widths for a directly comparable matrix.
      final baseline = PreparedSegments(source,
          correctJoins: false, contextualFragments: false);
      final ordinaryAudit = auditOrdinaryRanges(source, prepared);
      final plans = <String, List<double>>{
        '40': [40],
        '80': [80],
        '160': [160],
        '320': [320],
        'changing': [60, 180, 90, 240],
      };
      for (final b in source.breaks
          .where((b) => b.offset <= math.min(48, source.text.length))
          .take(fixture.key == 'nonrepeating_prose' ? 0 : 24)) {
        final exact = source.measure(0, b.offset, 10000),
            estimate = baseline.width(0, b.offset);
        for (final value in {
          exact - .02,
          exact + .02,
          estimate - .02,
          estimate + .02
        }) {
          if (value >= 24) {
            plans['threshold_${b.offset}_${value.toStringAsFixed(5)}'] = [
              value
            ];
          }
        }
      }
      final comparisons = <Map<String, Object>>[];
      var breakFailures = 0, geometryFailures = 0;
      for (final plan in plans.entries) {
        final oracle = fitExact(source, plan.value);
        final before = source.measurements;
        final model = fitPrepared(prepared, plan.value);
        if (source.measurements != before) {
          throw StateError('Prepared fitting measured text');
        }
        final same = listEquals(
            oracle.map((l) => (l.row, l.start, l.end)).toList(),
            model.map((l) => (l.row, l.start, l.end)).toList());
        final errors = <Map<String, Object>>[];
        var maxError = 0.0;
        for (final line in model) {
          final actual =
              source.measure(line.start, line.end, plan.value.reduce(math.max));
          maxError = math.max(maxError, (line.width - actual).abs());
          if ((line.width - actual).abs() > .01 && errors.length < 3) {
            errors.add({
              'start': line.start,
              'end': line.end,
              'text': source.text.substring(line.start, line.end),
              'predicted': line.width,
              'exact': actual,
              'emergencyBoundary': (line.start != 0 &&
                      !prepared.ordinary.contains(line.start)) ||
                  !prepared.ordinary.contains(line.end),
            });
          }
        }
        if (!same) breakFailures++;
        if (maxError > .01) geometryFailures++;
        comparisons.add({
          'plan': plan.key,
          'widths': plan.value,
          'breaksMatch': same,
          'maxWidthError': maxError,
          'exactLines': oracle.map((l) => l.toJson()).toList(),
          'preparedLines': model.map((l) => l.toJson()).toList(),
          'firstWidthErrors': errors
        });
      }
      final timings = <String, Object>{};
      for (final plan in plans.entries.take(5)) {
        final layoutTimes = <double>[], exactTimes = <double>[];
        for (var sample = -warmups; sample < samples; sample++) {
          final calls = source.measurements;
          final watch = Stopwatch()..start();
          for (var repeat = 0; repeat < layoutBatch; repeat++) {
            final lines = fitPrepared(prepared, plan.value);
            if (lines.isEmpty || lines.last.end != source.text.length) {
              throw StateError('Incomplete layout');
            }
          }
          watch.stop();
          if (source.measurements != calls) {
            throw StateError('Hot path measured text');
          }
          if (sample >= 0) {
            layoutTimes.add(watch.elapsedMicroseconds / layoutBatch);
          }
          watch
            ..reset()
            ..start();
          fitExact(source, plan.value);
          watch.stop();
          if (sample >= 0) exactTimes.add(watch.elapsedMicroseconds.toDouble());
        }
        timings[plan.key] = {
          'preparedLayout': _summary(layoutTimes),
          'exactFitting': _summary(exactTimes)
        };
      }
      results.add({
        'fixture': fixture.key,
        'font': font,
        'characters': source.text.length,
        'segments': prepared.ordinary.length,
        'preparationMeasurementCalls': prepared.measurementCalls,
        'ordinaryRangeAudit': ordinaryAudit,
        'fragmentEntries': prepared.fragmentEntries,
        'joinEntries': prepared.joinEntries,
        'hotPathMeasurementCalls': 0,
        'preparation': _summary(prepTimes),
        'plans': comparisons.length,
        'breakFailures': breakFailures,
        'geometryFailures': geometryFailures,
        'comparisons': comparisons,
        'timings': timings
      });
      source.dispose();
    }
  }
  return {
    'checkpointVersion': 4,
    'longTokenDiagnostic': auditLongTokens(),
    'measurementModel':
        'Bounded three-grapheme interactions stored as prefix sums; exact checkpoint-3 tables retained as test reference.',
    'contextGraphemes': 3,
    'probeModel': 'Checkpoint-1 widths retained for direct comparison.',
    'recordedAtUtc': DateTime.now().toUtc().toIso8601String(),
    'mode': kProfileMode ? 'profile' : 'debug',
    'samples': samples,
    'warmups': warmups,
    'layoutBatch': layoutBatch,
    'scope':
        'Preparation includes source/break analysis and fresh segment/grapheme measurement cache. Hot layout includes numeric exhaustive fitting and line records, no Flutter measurement. Exact fitting uses uncached public range measurement. Neither includes widget layout, painting, caret or selection geometry. Warm engine/font caches; not process-cold startup.',
    'results': results
  };
}

/// Exhaustively checks ordinary-aligned ranges, including different line starts.
/// Accuracy-only work: excluded from both preparation and layout timers.
Map<String, Object> auditOrdinaryRanges(
    CheckpointSource source, PreparedWidthModel prepared) {
  var checked = 0, failures = 0;
  var maxError = 0.0;
  final examples = <Map<String, Object>>[];
  final starts = [0, ...prepared.ordinary];
  for (var i = 0; i < starts.length - 1; i++) {
    for (var j = i; j < prepared.ordinary.length; j++) {
      final start = starts[i], end = prepared.ordinary[j];
      final actual = source.measure(start, end, 10000);
      final predicted = prepared.width(start, end);
      final error = (predicted - actual).abs();
      checked++;
      maxError = math.max(maxError, error);
      if (error > .01) {
        failures++;
        if (examples.length < 5) {
          examples.add({
            'start': start,
            'end': end,
            'text': source.text.substring(start, end),
            'predicted': predicted,
            'exact': actual
          });
        }
      }
    }
  }
  return {
    'checked': checked,
    'failures': failures,
    'maxWidthError': maxError,
    'examples': examples
  };
}

/// Additional stress probes, explicitly reported separately from the original
/// passing matrix. Width errors remain failures of the model, not rounded away.
List<Map<String, Object>> auditLongTokens() {
  final results = <Map<String, Object>>[];
  for (final repeats in [10, 100, 200, 400]) {
    final text = List.filled(repeats, 'officeAVATAR').join();
    final source = CheckpointSource(
        text, const TextStyle(fontFamily: 'CheckpointRoboto', fontSize: 20));
    final prepared = CompactPreparedSegments(source);
    final ranges = [
      (0, text.length),
      (1, 117),
      (text.length - 51, text.length)
    ];
    for (final range in ranges) {
      final exact = source.measure(range.$1, range.$2, 100000);
      final predicted = prepared.width(range.$1, range.$2);
      results.add({
        'characters': text.length,
        'start': range.$1,
        'end': range.$2,
        'predicted': predicted,
        'exact': exact,
        'error': (predicted - exact).abs(),
        'matches': (predicted - exact).abs() <= .01,
        'tableEntries': prepared.fragmentEntries + prepared.joinEntries
      });
    }
    source.dispose();
  }
  return results;
}
