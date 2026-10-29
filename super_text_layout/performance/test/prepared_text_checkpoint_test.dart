import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_text_layout/experimental_flow.dart';
import 'package:performance/checkpoints/prepared_text.dart';
import 'package:performance/checkpoints/prepared_text_benchmark.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCheckpointFonts);
  test('exact oracle matches production fragment ranges at fixed widths', () {
    const style = TextStyle(fontFamily: 'CheckpointRoboto', fontSize: 20);
    for (final text in checkpointFixtures.values) {
      final source = CheckpointSource(text, style);
      for (final width in [40.0, 80.0, 160.0, 320.0]) {
        final oracle = fitExact(source, [width]);
        final controller = FlowLayoutController();
        final paragraph = RenderFlowParagraph(
            controller, RectangularFlowRegions(), style, null, null)
          ..add(RenderFlowText(text, style, id: 'text'))
          ..layout(BoxConstraints.tightFor(width: width));
        expect(
            controller.layout!
                .fragmentsFor('text')
                .map((f) => (f.range.start, f.range.end)),
            orderedEquals(oracle.map((l) => (l.start, l.end))));
        paragraph.dispose();
        controller.dispose();
      }
      source.dispose();
    }
  });
  test('exact oracle matches production with widths changing between lines',
      () {
    const style = TextStyle(fontFamily: 'CheckpointRoboto', fontSize: 20);
    const widths = [60.0, 180.0, 90.0, 240.0];
    for (final text in checkpointFixtures.values) {
      final source = CheckpointSource(text, style);
      final metric = TextPainter(
          text: const TextSpan(text: ' ', style: style),
          textDirection: TextDirection.ltr)
        ..layout();
      final regions = _ChangingWidths(widths, metric.height);
      metric.dispose();
      final controller = FlowLayoutController();
      final paragraph =
          RenderFlowParagraph(controller, regions, style, null, null)
            ..add(RenderFlowText(text, style, id: 'text'))
            ..layout(const BoxConstraints.tightFor(width: 240));
      final oracle = fitExact(source, widths);
      expect(
          controller.layout!
              .fragmentsFor('text')
              .map((f) => (f.range.start, f.range.end)),
          orderedEquals(oracle.map((l) => (l.start, l.end))));
      paragraph.dispose();
      controller.dispose();
      source.dispose();
    }
  });
  test('pair corrections preserve every ordinary range across both fonts', () {
    for (final font in ['CheckpointRoboto', 'CheckpointMono']) {
      for (final fixture in checkpointFixtures.entries) {
        final source = CheckpointSource(
            fixture.value, TextStyle(fontFamily: font, fontSize: 20));
        final prepared = PreparedSegments(source);
        final audit = auditOrdinaryRanges(source, prepared);
        expect(audit['failures'], 0, reason: '$font / ${fixture.key}: $audit');
        source.dispose();
      }
    }
  });
  test('contextual fragments match every legal range in short fixtures', () {
    for (final font in ['CheckpointRoboto', 'CheckpointMono']) {
      for (final text
          in checkpointFixtures.values.where((text) => text.length < 100)) {
        final source =
            CheckpointSource(text, TextStyle(fontFamily: font, fontSize: 20));
        final prepared = PreparedSegments(source);
        final offsets = [0, ...source.breaks.map((b) => b.offset)];
        for (var a = 0; a < offsets.length - 1; a++) {
          for (var b = a + 1; b < offsets.length; b++) {
            expect(prepared.width(offsets[a], offsets[b]),
                closeTo(source.measure(offsets[a], offsets[b], 10000), .01),
                reason: '$font ${text.substring(offsets[a], offsets[b])}');
          }
        }
        source.dispose();
      }
    }
  });
  test('compact context widths match exact tables over every legal short range',
      () {
    final errors = <int, int>{2: 0, 3: 0, 4: 0, 6: 0};
    for (final font in ['CheckpointRoboto', 'CheckpointMono']) {
      for (final text
          in checkpointFixtures.values.where((text) => text.length < 100)) {
        final source =
            CheckpointSource(text, TextStyle(fontFamily: font, fontSize: 20));
        final exact = PreparedSegments(source);
        final models = {
          for (final size in errors.keys)
            size: CompactPreparedSegments(source, maxContext: size)
        };
        final offsets = [0, ...source.breaks.map((b) => b.offset)];
        for (var a = 0; a < offsets.length - 1; a++) {
          for (var b = a + 1; b < offsets.length; b++) {
            final width = exact.width(offsets[a], offsets[b]);
            for (final model in models.entries) {
              if ((model.value.width(offsets[a], offsets[b]) - width).abs() >
                  .01) {
                errors[model.key] = errors[model.key]! + 1;
              }
            }
          }
        }
        source.dispose();
      }
    }
    // Diagnostic output records which context lengths the fixtures require.
    // ignore: avoid_print
    print('CONTEXT_WIDTH_ERRORS: $errors');
    expect(errors[2], greaterThan(0));
    expect(errors[3], 0);
    expect(errors[4], 0);
    expect(errors[6], 0);
  });
  test('long-token diagnostic retains exact errors and bounds storage', () {
    final diagnostic = auditLongTokens();
    expect(diagnostic, hasLength(12));
    for (final entry in diagnostic) {
      expect(entry['tableEntries']! as int,
          lessThan(4 * (entry['characters']! as int)));
      expect(
          entry['error'],
          ((entry['predicted']! as double) - (entry['exact']! as double))
              .abs());
      expect(entry['matches'], (entry['error']! as double) <= .01);
    }
    // Diagnostic, not a claim that these extra accuracy probes all pass.
    // ignore: avoid_print
    print('LONG_TOKEN_DIAGNOSTIC: $diagnostic');
  });
  test('compact model matches the full checkpoint matrix', () {
    final report =
        runPreparedTextCheckpoint(samples: 1, warmups: 0, layoutBatch: 1);
    final results = report['results']! as List<Map<String, Object>>;
    expect(results, hasLength(10));
    expect(results.every((r) => r['hotPathMeasurementCalls'] == 0), isTrue);
    expect(results.every((r) => r['breakFailures'] == 0), isTrue);
    expect(results.every((r) => r['geometryFailures'] == 0), isTrue);
  });
}

class _ChangingWidths extends FlowRegionProvider {
  const _ChangingWidths(this.widths, this.lineHeight);
  final List<double> widths;
  final double lineHeight;
  @override
  FlowLineSpace spaceFor(
      {required double top, required double height, required double width}) {
    final row = (top / lineHeight).round();
    return FlowLineSpace(
        [Rect.fromLTWH(0, top, widths[row % widths.length], height)],
        nextTop: top + lineHeight);
  }
}
