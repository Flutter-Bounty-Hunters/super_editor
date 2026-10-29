import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_text_layout/experimental_flow.dart';
import 'package:performance/checkpoints/automatic_routing.dart';
import 'package:performance/checkpoints/prepared_text_benchmark.dart';
import 'package:performance/checkpoints/routing_study.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCheckpointFonts);
  test('automatic mixed routing matches exact fitting at fixed/changing widths',
      () async {
    final report = evaluateRoutingStudy();
    final file = File('build/profile/automatic-routing-debug.json');
    await file.parent.create(recursive: true);
    await file
        .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    final results = report['results']! as List<Map<String, Object>>;
    for (final r in results) {
      expect(r['breakFailures'], 0, reason: '$r');
      expect(r['geometryFailures'], 0, reason: '$r');
      if (r['fixture'] == 'supported' ||
          r['fixture'] == 'mixed_fonts' ||
          r['fixture'] == 'positive_spacing') {
        expect(r['exactCandidates'], 0);
        expect(r['compactCandidates']! as int, greaterThan(0));
      } else if (r['fixture'] == 'negative_only') {
        expect(r['compactCandidates'], 0);
        expect(r['exactCandidates']! as int, greaterThan(0));
        expect(r['preparationMeasurements'], 0);
      } else {
        expect(r['exactCandidates']! as int, greaterThan(0));
        expect(r['compactCandidates']! as int, greaterThan(0));
      }
    }
  });
  test(
      'routing updates with style changes and reuses supported preparation across widths',
      () {
    for (final spacing in [0.0, -5.0, 0.0]) {
      final source = RoutingSource([
        RoutingSpan('Wi WiWi iiiiiii WWW AVATAR',
            routingStyle.copyWith(letterSpacing: spacing))
      ], routingStyle);
      final model = AutomaticRoutingModel(source);
      final initialCalls = source.exactMeasurements;
      model.fit([40]);
      model.fit([80]);
      model.fit([40, 160, 80, 320]);
      if (spacing < 0) {
        expect(model.exactCandidates, greaterThan(0));
        expect(model.compactCandidates, 0);
      } else {
        expect(model.exactCandidates, 0);
        expect(source.exactMeasurements, initialCalls);
        expect(model.compactCandidates, greaterThan(0));
      }
      source.dispose();
    }
  });
  test('effective inherited styles control eligibility', () {
    final inherited = routingStyle.copyWith(letterSpacing: -5);
    final source = RoutingSource([
      const RoutingSpan('tight text ', TextStyle()),
      const RoutingSpan('normal text', TextStyle(letterSpacing: 0)),
    ], inherited);
    expect(source.eligible(0, 11), isFalse);
    expect(source.eligible(11, 22), isTrue);
    expect(source.eligible(0, 22), isFalse);
    source.dispose();
  });
  test('mixed exact oracle agrees with production paragraph line ranges', () {
    for (final fixture in routingFixtures().entries) {
      final source = RoutingSource(fixture.value, routingStyle);
      for (final width in [40.0, 80.0, 160.0, 320.0]) {
        final controller = FlowLayoutController();
        final paragraph = RenderFlowParagraph(
            controller, RectangularFlowRegions(), routingStyle, null, null);
        final offsets = <int>[0];
        for (var i = 0; i < fixture.value.length; i++) {
          final span = fixture.value[i];
          offsets.add(offsets.last + span.text.length);
          paragraph.add(RenderFlowText(span.text, span.style, id: i));
        }
        paragraph.layout(BoxConstraints.tightFor(width: width));
        final actual = <int, (int, int)>{};
        for (final fragment in controller.layout!.fragments) {
          final base = offsets[fragment.participant as int];
          final start = base + fragment.range.start,
              end = base + fragment.range.end;
          final old = actual[fragment.line];
          actual[fragment.line] = (old == null ? start : old.$1, end);
        }
        final oracle = fitRoutingExact(source, [width]);
        expect(
            actual.values, orderedEquals(oracle.map((l) => (l.start, l.end))),
            reason: '${fixture.key} / $width');
        paragraph.dispose();
        controller.dispose();
      }
      source.dispose();
    }
  });
}
