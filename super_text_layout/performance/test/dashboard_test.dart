import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:performance/main.dart';
import 'package:performance/src/metrics.dart';
import 'package:performance/src/widgets.dart';
import 'package:performance/fixtures/profile_fixture_data.dart';
import 'package:super_text_layout/experimental_flow.dart';
import 'metrics_test.dart' show readDocuments;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MetricsData data;
  setUpAll(() async {
    data = MetricsData.fromJson(readDocuments());
    for (final font in [
      ('DashboardSans', 'assets/fonts/Roboto-Regular.ttf'),
      ('DashboardMono', 'assets/fonts/FiraMono-Regular.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
      ('FlowBenchmark', 'assets/fonts/Roboto-Regular.ttf'),
      ('FlowBenchmarkCode', 'assets/fonts/FiraMono-Regular.ttf')
    ]) {
      await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
    }
  });

  Future<void> show(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(RepaintBoundary(
        key: const ValueKey('capture'), child: PerformanceApp(data: data)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(Theme.of(tester.element(find.text('Performance Lab'))).brightness,
        Brightness.dark);
  }

  Future<void> screenshot(WidgetTester tester, String name) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('capture')));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/screenshots').create(recursive: true);
      await File('build/screenshots/$name.png')
          .writeAsBytes(png!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('single dashboard exposes every case and statistic together',
      (tester) async {
    await show(tester, const Size(1440, 1100));
    expect(find.textContaining('5 regression failures'), findsOneWidget);
    expect(find.byKey(const ValueKey('run-setup-link')), findsNothing);
    expect(find.text('RECORDED SNAPSHOT'), findsNothing);
    final appBar = find.byKey(const ValueKey('dashboard-app-bar'));
    expect(find.descendant(of: appBar, matching: find.text('Performance Lab')),
        findsOneWidget);
    expect(
        find.descendant(
            of: appBar,
            matching:
                find.text('Text layout benchmarks. Current regressions.')),
        findsOneWidget);
    expect(find.text('Performance Lab'), findsOneWidget);
    expect(find.text('Text layout benchmarks. Current regressions.'),
        findsOneWidget);

    final timings = tester.getRect(find.byKey(const ValueKey('all-timings')));
    expect(tester.getRect(find.byKey(const ValueKey('fps-picker'))).right,
        closeTo(timings.right - 34, 1));
    final checks =
        tester.getRect(find.byKey(const ValueKey('regression-checks')));
    final attention = find.ancestor(
        of: find.text('5 CHECKS NEED ATTENTION'), matching: find.byType(Tag));
    expect(tester.getRect(attention).right, closeTo(checks.right - 23, 1));

    expect(
        tester.getTopLeft(find.byKey(const ValueKey('regression-checks'))).dy,
        lessThan(
            tester.getTopLeft(find.byKey(const ValueKey('all-timings'))).dy));
    expect(find.byType(StatCard), findsNothing);
    expect(find.byKey(const ValueKey('performance-summary')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('summary-regressions-link')), findsOneWidget);
    expect(find.textContaining('(Median or P95)'), findsOneWidget);
    for (final benchmark in data.current) {
      for (final phase in operations.keys) {
        for (final stat in TimingStatistic.values) {
          expect(
              find.byKey(ValueKey('timing-${benchmark.id}-$phase-${stat.key}')),
              findsOneWidget);
          expect(
              find.byKey(
                  ValueKey('baseline-${benchmark.id}-$phase-${stat.key}')),
              findsNothing);
        }
        expect(find.byKey(ValueKey('samples-${benchmark.id}-$phase')),
            findsNothing);
      }
    }
    expect(find.byKey(const ValueKey('sample-stability')), findsNothing);
    expect(find.byKey(const ValueKey('benchmark-picker')), findsNothing);
    expect(find.byKey(const ValueKey('stat-p95')), findsNothing);
    expect(find.byKey(const ValueKey('cpu-profile')), findsNothing);
    expect(find.text('CPU not recorded'), findsNWidgets(20));
    expect(find.text('Apple M4 · arm64'), findsOneWidget);
    await screenshot(tester, 'single-dashboard-overview');
    await tester.ensureVisible(find.byKey(const ValueKey('regression-checks')));
    await tester.pumpAndSettle();
    await screenshot(tester, 'single-dashboard-checks');
    await tester.ensureVisible(
        find.byKey(const ValueKey('cpu-bar-decorated_code-initial')));
    await tester.pumpAndSettle();
    await screenshot(tester, 'single-dashboard-cpu');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'variability is hidden by default and toggles independently per benchmark',
      (tester) async {
    await show(tester, const Size(1440, 1100));
    expect(find.byType(SampleSparkline), findsNothing);
    expect(find.text('Show variability'), findsNWidgets(data.current.length));
    final first = data.current.first;
    final second = data.current[1];
    Future<void> toggle(Benchmark benchmark) async {
      final button = find.byKey(ValueKey('toggle-variability-${benchmark.id}'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    await toggle(first);
    expect(find.byType(SampleSparkline), findsNWidgets(operations.length));
    for (final phase in operations.keys) {
      final meter = tester
          .getRect(find.byKey(ValueKey('timing-plot-${first.id}-$phase')));
      final areaFinder = find.byKey(ValueKey('sample-area-${first.id}-$phase'));
      final area = tester.getRect(areaFinder);
      final line = tester
          .getRect(find.byKey(ValueKey('timing-line-${first.id}-$phase')));
      expect(area.top, closeTo(meter.bottom + 16, 1));
      expect(area.left, line.left);
      expect(area.right, line.right);
      expect(tester.widget<Container>(areaFinder).color, Palette.background);
    }
    await screenshot(tester, 'expanded-variability');
    await toggle(second);
    expect(find.byType(SampleSparkline), findsNWidgets(operations.length * 2));
    await toggle(first);
    expect(find.byType(SampleSparkline), findsNWidgets(operations.length));
    for (final phase in operations.keys) {
      expect(find.byKey(ValueKey('samples-${first.id}-$phase')), findsNothing);
      expect(
          find.byKey(ValueKey('samples-${second.id}-$phase')), findsOneWidget);
    }
    await toggle(second);
    expect(find.byType(SampleSparkline), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('variability expands and collapses vertically over time',
      (tester) async {
    await show(tester, const Size(1440, 1100));
    final benchmark = data.current.first;
    final button = find.byKey(ValueKey('toggle-variability-${benchmark.id}'));
    final transition =
        find.byKey(ValueKey('variability-transition-${benchmark.id}-initial'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    expect(tester.getSize(transition).height, 0);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));
    final expandingHeight = tester.getSize(transition).height;
    expect(expandingHeight, greaterThan(0));
    expect(expandingHeight, lessThan(72));
    await tester.pumpAndSettle();
    expect(tester.getSize(transition).height, 72);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));
    final collapsingHeight = tester.getSize(transition).height;
    expect(collapsingHeight, greaterThan(0));
    expect(collapsingHeight, lessThan(72));
    expect(find.byKey(ValueKey('samples-${benchmark.id}-initial')),
        findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.getSize(transition).height, 0);
    expect(find.byType(SampleSparkline), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('summary links scroll to their associated cards', (tester) async {
    await show(tester, const Size(1440, 1100));
    final summary = find.byKey(const ValueKey('performance-summary'));
    for (final entry in [
      ('summary-regressions-link', 'regression-checks'),
      ('summary-budget-link', 'all-timings'),
    ]) {
      await tester.ensureVisible(summary);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey(entry.$1)));
      await tester.pumpAndSettle();
      final card = tester.getRect(find.byKey(ValueKey(entry.$2)));
      final bar =
          tester.getRect(find.byKey(const ValueKey('dashboard-app-bar')));
      expect(card.top, closeTo(bar.bottom, 2));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('CPU bars partition the capture and show descriptions on hover',
      (tester) async {
    await show(tester, const Size(1440, 1100));
    for (final capture in data.cpuCurrent) {
      final bar = tester.getRect(find.byKey(
          ValueKey('cpu-bar-${capture.benchmark}-${capture.operation}')));
      final timingBar = tester.getRect(find.byKey(
          ValueKey('p95-bar-${capture.benchmark}-${capture.operation}')));
      expect(bar.left, timingBar.left);
      expect(bar.width, closeTo(timingBar.width, 1e-6));
      for (final entry
          in capture.buckets.entries.where((entry) => entry.value > 0)) {
        final segment = find.byKey(ValueKey(
            'cpu-segment-${capture.benchmark}-${capture.operation}-${entry.key}'));
        expect(tester.getSize(segment).width / bar.width,
            closeTo(entry.value / capture.samples, 1e-6));
      }
    }
    final segment = find.byKey(const ValueKey(
        'cpu-segment-decorated_code-initial-numeric_model_preparation'));
    await tester.ensureVisible(segment);
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(segment));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Width-model preparation · 62.8%',
            findRichText: true),
        findsOneWidget);
    expect(
        find.textContaining('Builds the fast text-width model.',
            findRichText: true),
        findsOneWidget);
    await screenshot(tester, 'cpu-breakdown-popover');
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
  });

  testWidgets('all timing columns fit a normal 800px desktop window',
      (tester) async {
    await show(tester, const Size(800, 1100));
    for (final benchmark in data.current) {
      for (final phase in operations.keys) {
        for (final stat in TimingStatistic.values) {
          final bounds = tester.getRect(find
              .byKey(ValueKey('timing-${benchmark.id}-$phase-${stat.key}')));
          expect(bounds.left, greaterThanOrEqualTo(0));
          expect(bounds.right, lessThanOrEqualTo(800));
        }
      }
    }
    await screenshot(tester, 'single-dashboard-compact');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'mobile shows both frame cadences without hiding timing or checks',
      (tester) async {
    await show(tester, const Size(390, 844));
    await screenshot(tester, 'single-dashboard-mobile');
    expect(find.byKey(const ValueKey('frame-budget')), findsNothing);
    expect(
        find.textContaining(
            '${25 - data.withinFrame(TimingStatistic.p95, 1000 / 60)} operations'),
        findsOneWidget);
    expect(find.textContaining('5 regression failures'), findsOneWidget);
    expect(find.byKey(const ValueKey('frame-marker-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('frame-marker-2')), findsOneWidget);
    await tester.ensureVisible(
        find.byKey(const ValueKey('cpu-bar-decorated_code-initial')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'current timings share a scale with repeating solid and dashed frame markers',
      (tester) async {
    await show(tester, const Size(1440, 1100));
    Rect? firstPlot, lastPlot;
    for (final benchmark in data.current) {
      double? previousY;
      for (final phase in operations.keys) {
        final line = tester.getRect(
            find.byKey(ValueKey('timing-line-${benchmark.id}-$phase')));
        final title = tester.getRect(
            find.byKey(ValueKey('timing-title-${benchmark.id}-$phase')));
        final plot = tester.getRect(
            find.byKey(ValueKey('timing-plot-${benchmark.id}-$phase')));
        final median = tester.getRect(
            find.byKey(ValueKey('timing-${benchmark.id}-$phase-median')));
        final p95 = tester
            .getRect(find.byKey(ValueKey('timing-${benchmark.id}-$phase-p95')));
        if (previousY != null) expect(line.top, greaterThan(previousY));
        previousY = line.top;
        expect(title.left, lessThan(plot.left));
        expect(median.left, greaterThan(plot.right));
        expect(p95.left, greaterThan(median.right));
        firstPlot ??= plot;
        expect(plot.left, firstPlot.left);
        expect(plot.width, firstPlot.width);
        lastPlot = plot;
        for (final stat in TimingStatistic.values) {
          final value = tester.widget<Text>(find
              .byKey(ValueKey('timing-${benchmark.id}-$phase-${stat.key}')));
          final bar = tester.widget<Container>(
              find.byKey(ValueKey('${stat.key}-bar-${benchmark.id}-$phase')));
          expect(value.style!.color, (bar.decoration! as BoxDecoration).color);
        }
      }
    }
    // Current p95 tops out at 49.86 ms, so the chart ends at 50 ms. The old
    // baseline's 61.31 ms must not stretch the current-only scale to 70 ms.
    for (var frame = 1; frame <= 6; frame++) {
      final finder = find.byKey(ValueKey('frame-marker-$frame'));
      final widget = tester.widget<FrameMarkerLine>(finder);
      final marker = tester.getRect(finder);
      expect(widget.major, frame.isEven);
      expect(marker.width, frame.isEven ? 3 : 1.5);
      expect(marker.top, lessThanOrEqualTo(firstPlot!.top));
      expect(marker.bottom, greaterThanOrEqualTo(lastPlot!.bottom));
      expect(marker.center.dx - firstPlot.left,
          closeTo(firstPlot.width * (frame * 1000 / 120) / 50, 1e-6));
    }
    expect(find.byKey(const ValueKey('frame-marker-7')), findsNothing);
    expect(find.text('16.67 ms'), findsOneWidget);
    expect(find.text('33.33 ms'), findsOneWidget);
    expect(find.text('50.00 ms'), findsOneWidget);
    final initial = tester
        .getSize(
            find.byKey(const ValueKey('median-bar-decorated_code-initial')))
        .width;
    expect(
        initial / firstPlot!.width,
        closeTo(
            data
                    .benchmark('decorated_code')
                    .timings['initial']!
                    .value(TimingStatistic.median) /
                50,
            1e-9));
    expect(find.textContaining('was '), findsNothing);
    expect(find.textContaining('baseline / current'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'compact rows use column titles and FPS updates guides and budget colors',
      (tester) async {
    await show(tester, const Size(1440, 1100));
    expect(find.byKey(const ValueKey('median-column-title')), findsOneWidget);
    expect(find.byKey(const ValueKey('p95-column-title')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('timing-label-decorated_code-resize-median')),
        findsNothing);
    expect(
        tester
            .getSize(
                find.byKey(const ValueKey('timing-line-decorated_code-resize')))
            .height,
        lessThanOrEqualTo(36));
    Color valueColor(String id, String phase, String stat) => tester
        .widget<Text>(find.byKey(ValueKey('timing-$id-$phase-$stat')))
        .style!
        .color!;
    expect(valueColor('decorated_code', 'resize', 'median'), Palette.green);
    expect(valueColor('decorated_code', 'initial', 'median'), Palette.red);
    expect(
        valueColor('decorated_code', 'edit_end', 'p95'),
        timingColor(TimingStatistic.p95,
            milliseconds: 13.514, budget: 1000 / 60));
    await tester.ensureVisible(find.byKey(const ValueKey('fps-picker')));
    await tester.tap(find.byKey(const ValueKey('fps-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('120 FPS').last);
    await tester.pumpAndSettle();
    for (var frame = 1; frame <= 6; frame++) {
      final marker = find.byKey(ValueKey('frame-marker-$frame'));
      expect(tester.widget<FrameMarkerLine>(marker).major, isTrue);
      expect(tester.getSize(marker).width, 3);
    }
    expect(
        find.textContaining(
            '${25 - data.withinFrame(TimingStatistic.p95, 1000 / 120)} operations'),
        findsOneWidget);
    expect(find.textContaining('5 regression failures'), findsOneWidget);
    expect(valueColor('decorated_code', 'resize', 'median'), Palette.red);
    expect(
        valueColor('demo_buttons', 'resize', 'p95'),
        timingColor(TimingStatistic.p95,
            milliseconds: 8.054, budget: 1000 / 120));
    await screenshot(tester, '120-fps-timings');
    expect(tester.takeException(), isNull);
  });

  testWidgets('run setup stays inline and copies a usable reproduction command',
      (tester) async {
    await show(tester, const Size(1440, 1100));
    String? copied;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() =>
        messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    expect(find.byType(Dialog), findsNothing);
    await tester.ensureVisible(find.byTooltip('Copy command'));
    await tester.tap(find.byTooltip('Copy command'));
    await tester.pumpAndSettle();
    expect(copied, data.reproduceCommand);
    final codeBlock =
        tester.getRect(find.byKey(const ValueKey('reproduction-code-block')));
    final copyButton = tester.getRect(find.byTooltip('Copy command'));
    expect(codeBlock.right - copyButton.right, inInclusiveRange(6, 16));
    expect(copyButton.top - codeBlock.top, inInclusiveRange(6, 16));
    await tester.ensureVisible(find.text('Copy current JSON'));
    await tester.tap(find.text('Copy current JSON'));
    await tester.pumpAndSettle();
    expect(jsonDecode(copied!), data.currentRaw);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'every benchmark link opens its full live fixture and closes back to the dashboard',
      (tester) async {
    await show(tester, const Size(1440, 1100));
    for (final benchmark in data.current) {
      final link = find.byKey(ValueKey('preview-${benchmark.id}'));
      await tester.ensureVisible(link);
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('benchmark-layout-popover')),
          findsOneWidget);
      final paragraphFinder = find.byKey(const ValueKey('preview-paragraph'));
      final paragraph = tester.widget<FlowParagraph>(paragraphFinder);
      final texts = tester.widgetList<FlowText>(find.descendant(
          of: paragraphFinder, matching: find.byType(FlowText)));
      expect(texts.map((t) => t.text).join(),
          profileFixtureChunks[benchmark.id]!.join());
      expect(texts.map((t) => t.text.length).fold(0, (a, b) => a + b),
          benchmark.characters);
      expect(
          find.descendant(of: paragraphFinder, matching: find.byType(FlowBox)),
          findsNWidgets(benchmark.widgets));
      expect(
          find.descendant(
              of: paragraphFinder, matching: find.byType(FlowDecoration)),
          findsNWidgets(benchmark.decorations));
      expect(tester.getSize(paragraphFinder).width, 600);
      expect(paragraph.controller.layout!.fragments, isNotEmpty);
      if (benchmark.id == 'demo_buttons') {
        await tester.tap(find.text('0: 0'));
        await tester.pumpAndSettle();
        expect(find.text('0: 1'), findsOneWidget);
      }
      if (benchmark.id == 'decorated_code') {
        await screenshot(tester, 'padded-code-popover');
      }
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('close-layout-preview')));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const ValueKey('benchmark-layout-popover')), findsNothing);
      expect(find.textContaining('5 regression failures'), findsOneWidget);
    }
  });

  testWidgets('mobile popover preserves measured widths and each edit location',
      (tester) async {
    await show(tester, const Size(390, 844));
    final link = find.byKey(const ValueKey('preview-decorated_code'));
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pumpAndSettle();
    final paragraph = find.byKey(const ValueKey('preview-paragraph'));
    expect(tester.getSize(paragraph).width, 600);
    for (final phase in operations.keys.skip(1)) {
      await tester.tap(find.byKey(const ValueKey('preview-operation')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(operations[phase]!).last);
      await tester.pumpAndSettle();
      expect(tester.getSize(paragraph).width, 320);
      final texts = tester.widgetList<FlowText>(
          find.descendant(of: paragraph, matching: find.byType(FlowText)));
      final expectedEdit = switch (phase) {
        'edit_beginning' => ProfileEdit.beginning,
        'edit_middle' => ProfileEdit.middle,
        'edit_end' => ProfileEdit.end,
        _ => null,
      };
      final expected = [
        for (var i = 0; i < 100; i++)
          profileChunkText('decorated_code', i, expectedEdit)
      ].join();
      expect(texts.map((t) => t.text).join(), expected);
      expect(tester.takeException(), isNull);
    }
    await screenshot(tester, 'mobile-code-popover');
    await tester.tap(find.byKey(const ValueKey('close-layout-preview')));
    await tester.pumpAndSettle();
    expect(find.textContaining('5 regression failures'), findsOneWidget);
  });

  testWidgets(
      'application reads its actual bundled metrics without injected data',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.runAsync(() async {
      await tester.pumpWidget(const PerformanceApp());
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(find.text('Performance Lab'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
