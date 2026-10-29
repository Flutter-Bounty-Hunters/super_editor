import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'automatic_routing.dart';
import 'prepared_text_benchmark.dart';

const routingStyle = TextStyle(fontFamily: 'CheckpointRoboto', fontSize: 20);
Map<String, List<RoutingSpan>> routingFixtures() {
  final negative = routingStyle.copyWith(letterSpacing: -5);
  const normal =
      RoutingSpan('office affinity AVATAR To WA final ', routingStyle);
  final tight = RoutingSpan('Wi WiWi iiiiiii WWW AVATAR ', negative);
  return {
    'supported': [normal],
    'negative_only': [tight],
    'negative_beginning': [tight, normal],
    'negative_middle': [normal, tight, normal],
    'negative_end': [normal, tight],
    'split_word': [
      const RoutingSpan('of', routingStyle),
      RoutingSpan(
          'fice ',
          routingStyle
              .copyWith(fontFeatures: const [FontFeature.disable('liga')])),
      normal
    ],
    'mixed_fonts': [
      normal,
      RoutingSpan('office ffi To ',
          routingStyle.copyWith(fontFamily: 'CheckpointMono')),
      normal
    ],
    'positive_spacing': [
      normal,
      RoutingSpan('office ffi To ', routingStyle.copyWith(letterSpacing: 1)),
      normal
    ],
    'negative_word_spacing': [
      normal,
      RoutingSpan('alpha beta gamma ', routingStyle.copyWith(wordSpacing: -2)),
      normal
    ],
    'mutable_paint': [
      normal,
      RoutingSpan(
          'painted text ',
          routingStyle.copyWith(
              foreground: Paint()..color = const Color(0xff000000))),
      normal
    ],
  };
}

Future<Map<String, Object>> runRoutingStudy({String assetPrefix = ''}) async {
  await loadCheckpointFonts(prefix: assetPrefix);
  return evaluateRoutingStudy();
}

Map<String, Object> evaluateRoutingStudy() {
  final results = <Map<String, Object>>[];
  for (final fixture in routingFixtures().entries) {
    final source = RoutingSource(fixture.value, routingStyle);
    try {
      final model = AutomaticRoutingModel(source);
      final plans = <String, List<double>>{
        '40': [40],
        '80': [80],
        '160': [160],
        '320': [320],
        'changing': [40, 160, 80, 320],
      };
      for (final b in source.breaks.breaks.take(24)) {
        final width = source.measure(0, b.offset);
        for (final value in [width - .02, width + .02]) {
          if (value >= 24 && value <= 400) {
            plans['threshold_${b.offset}_$value'] = [value];
          }
        }
      }
      var breakFailures = 0, geometryFailures = 0;
      final failures = <Map<String, Object>>[];
      for (final plan in plans.entries) {
        final oracle = fitRoutingExact(source, plan.value);
        final actual = model.fit(plan.value);
        final same = listEquals(
            oracle.map((l) => (l.row, l.start, l.end)).toList(),
            actual.map((l) => (l.row, l.start, l.end)).toList());
        var maxError = 0.0;
        for (final line in actual) {
          final error =
              (line.width - source.measure(line.start, line.end)).abs();
          if (error > maxError) maxError = error;
        }
        if (!same) breakFailures++;
        if (maxError > .01) geometryFailures++;
        if ((!same || maxError > .01) && failures.length < 3) {
          failures.add({
            'plan': plan.key,
            'maxWidthError': maxError,
            'exact': oracle.map((l) => l.toJson()).toList(),
            'actual': actual.map((l) => l.toJson()).toList()
          });
        }
      }
      results.add({
        'fixture': fixture.key,
        'plans': plans.length,
        'breakFailures': breakFailures,
        'geometryFailures': geometryFailures,
        'compactCandidates': model.compactCandidates,
        'exactCandidates': model.exactCandidates,
        'preparationMeasurements': model.prepared.measurementCalls,
        'failures': failures
      });
    } finally {
      source.dispose();
    }
  }
  return {
    'checkpointVersion': 6,
    'study': 'automatic-routing',
    'mode': kProfileMode ? 'profile' : 'debug',
    'recordedAtUtc': DateTime.now().toUtc().toIso8601String(),
    'scope':
        'Mixed text-style width fitting only. No production/widget routing or painting. Exact fallback is automatic for negative spacing, custom features/variations and mutable Paint. Three-grapheme compact context remains experimental.',
    'results': results
  };
}
