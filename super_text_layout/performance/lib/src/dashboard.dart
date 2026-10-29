import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'metrics.dart';
import 'benchmark_preview.dart';
import 'widgets.dart';

class PerformanceDashboard extends StatefulWidget {
  const PerformanceDashboard({super.key, required this.data});
  final MetricsData data;
  @override
  State<PerformanceDashboard> createState() => _DashboardState();
}

class _DashboardState extends State<PerformanceDashboard> {
  final scroll = ScrollController();
  final checksAnchor = GlobalKey();
  final timingsAnchor = GlobalKey();
  static const frame60 = 1000 / 60;
  static const frame120 = 1000 / 120;
  int selectedFps = 60;
  final expandedVariability = <String>{};
  MetricsData get data => widget.data;
  double get frameBudget => selectedFps == 60 ? frame60 : frame120;
  int get measurementCount => data.current.length * operations.length;
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
          body: Column(children: [
        _topbar(),
        Expanded(
            child: Scrollbar(
                controller: scroll,
                child: SingleChildScrollView(
                  key: const ValueKey('dashboard-scroll'),
                  controller: scroll,
                  child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1700),
                        child: LayoutBuilder(
                            builder: (context, constraints) => Padding(
                                  padding: EdgeInsets.all(
                                      constraints.maxWidth < 650 ? 18 : 32),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _summary(),
                                        const SizedBox(height: 26),
                                        _failures(),
                                        const SizedBox(height: 32),
                                        _timingOverview(),
                                        const SizedBox(height: 32),
                                        _runSetup(),
                                      ]),
                                )),
                      )),
                ))),
      ]));

  Widget _topbar() => Container(
      key: const ValueKey('dashboard-app-bar'),
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
          color: Palette.sidebar,
          border: Border(bottom: BorderSide(color: Palette.border))),
      child: const Row(children: [
        Icon(Icons.stacked_bar_chart_rounded, size: 23, color: Palette.green),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Performance Lab',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              SizedBox(height: 4),
              Text('Text layout benchmarks. Current regressions.',
                  style: TextStyle(fontSize: 11, color: Palette.muted)),
            ],
          ),
        ),
      ]));

  Widget _summary() {
    final failures = data.failures.length;
    final overBudget = data.current
        .expand((benchmark) => benchmark.timings.values)
        .where((timing) => TimingStatistic.values
            .any((statistic) => timing.value(statistic) > frameBudget))
        .length;
    final hasIssues = failures > 0 || overBudget > 0;
    return Panel(
      child: Text.rich(
        TextSpan(children: [
          if (!hasIssues)
            TextSpan(
                text:
                    'No regression failures or operations over the $selectedFps FPS budget.')
          else ...[
            const TextSpan(text: 'Investigate '),
            if (failures > 0)
              _summaryLink(
                '$failures regression ${failures == 1 ? 'failure' : 'failures'}',
                key: const ValueKey('summary-regressions-link'),
                target: checksAnchor,
              ),
            if (failures > 0 && overBudget > 0) const TextSpan(text: ' and '),
            if (overBudget > 0) ...[
              _summaryLink(
                '$overBudget ${overBudget == 1 ? 'operation' : 'operations'}',
                key: const ValueKey('summary-budget-link'),
                target: timingsAnchor,
              ),
              TextSpan(
                  text:
                      ' exceeding the $selectedFps FPS budget (Median or P95)'),
            ],
            const TextSpan(text: '.'),
          ],
        ]),
        key: const ValueKey('performance-summary'),
        style: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: hasIssues ? Palette.amber : Palette.green),
      ),
    );
  }

  InlineSpan _summaryLink(String label,
          {required Key key, required GlobalKey target}) =>
      WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: TextButton(
          key: key,
          onPressed: () => Scrollable.ensureVisible(target.currentContext!,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut),
          style: TextButton.styleFrom(
            foregroundColor: Palette.amber,
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(
                fontFamily: 'DashboardSans',
                fontSize: 14,
                height: 1.6,
                decoration: TextDecoration.underline),
          ),
          child: Text(label),
        ),
      );

  Widget _sectionHeading(String title, String description, {Widget? action}) =>
      Padding(
          padding: const EdgeInsets.fromLTRB(22, 21, 22, 18),
          child: _headingWithAction(
            heading:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              muted(description, size: 11),
            ]),
            action: action,
          ));

  Widget _headingWithAction({required Widget heading, Widget? action}) =>
      LayoutBuilder(builder: (context, constraints) {
        if (action == null) return heading;
        if (constraints.maxWidth < 700) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: action),
            ],
          );
        }
        return Row(children: [
          Expanded(child: heading),
          const SizedBox(width: 20),
          action,
        ]);
      });

  Widget _timingOverview() => Panel(
      key: const ValueKey('all-timings'),
      padding: EdgeInsets.zero,
      child: Column(
          key: timingsAnchor,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeading('All benchmark timings',
                'Current timing snapshot · five operations per benchmark · milliseconds',
                action: _fpsPicker()),
            _wideTable(680, (width) {
              final compact = width < 1000;
              final caseWidth = compact ? 160.0 : 218.0;
              final titleWidth = compact ? 116.0 : 148.0;
              final statsWidth = compact ? 164.0 : 200.0;
              const padding = 22.0, gap = 16.0, axisHeight = 58.0;
              final plotWidth = width -
                  padding * 2 -
                  caseWidth -
                  titleWidth -
                  statsWidth -
                  gap;
              final plotLeft = padding + caseWidth + titleWidth;
              final frameCount = (_chartMaximum / frame120 + 1e-9).floor();
              // Keep milestone labels readable on narrow or longer timelines;
              // every frame marker is still drawn even when a label is skipped.
              final labelStride = math.max(
                  1, (68 / (plotWidth * frameBudget / _chartMaximum)).ceil());
              return Stack(children: [
                Column(children: [
                  Container(
                      height: axisHeight,
                      color: Palette.background.withValues(alpha: .35),
                      padding: const EdgeInsets.symmetric(horizontal: padding),
                      child: Row(children: [
                        SizedBox(width: caseWidth, child: caption('BENCHMARK')),
                        SizedBox(
                            width: titleWidth, child: caption('OPERATION')),
                        SizedBox(
                            width: plotWidth,
                            child: Align(
                                alignment: Alignment.centerLeft,
                                child: mono('0 ms',
                                    size: 9, color: Palette.muted))),
                        const SizedBox(width: gap),
                        SizedBox(
                            width: statsWidth,
                            child: const Row(children: [
                              Expanded(
                                  child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Text('Median',
                                          key: ValueKey('median-column-title'),
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Palette.green)))),
                              Expanded(
                                  child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Text('P95',
                                          key: ValueKey('p95-column-title'),
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Palette.p95))))
                            ])),
                      ])),
                  for (final benchmark in data.current)
                    Container(
                        key: ValueKey('benchmark-${benchmark.id}'),
                        decoration: const BoxDecoration(
                            border:
                                Border(top: BorderSide(color: Palette.border))),
                        padding: const EdgeInsets.symmetric(
                            horizontal: padding, vertical: 8),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                  width: caseWidth,
                                  child: Padding(
                                      padding: const EdgeInsets.only(
                                          top: 10, right: 20),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _layoutLink(benchmark,
                                                key: ValueKey(
                                                    'preview-${benchmark.id}')),
                                            const SizedBox(height: 9),
                                            muted(
                                                '${number(benchmark.characters)} chars · ${benchmark.widgets} widgets',
                                                size: 10),
                                            const SizedBox(height: 4),
                                            muted(
                                                benchmark.decorations > 0
                                                    ? '${benchmark.decorations} decorations · obstacle flow'
                                                    : benchmark.obstacle
                                                        ? 'Obstacle flow'
                                                        : 'Standard flow',
                                                size: 9),
                                            const SizedBox(height: 8),
                                            Semantics(
                                              toggled: expandedVariability
                                                  .contains(benchmark.id),
                                              child: TextButton.icon(
                                                key: ValueKey(
                                                    'toggle-variability-${benchmark.id}'),
                                                onPressed: () => setState(() {
                                                  if (!expandedVariability
                                                      .remove(benchmark.id)) {
                                                    expandedVariability
                                                        .add(benchmark.id);
                                                  }
                                                }),
                                                style: TextButton.styleFrom(
                                                  padding: EdgeInsets.zero,
                                                  minimumSize:
                                                      const Size(0, 32),
                                                  foregroundColor:
                                                      Palette.muted,
                                                  textStyle: const TextStyle(
                                                      fontFamily:
                                                          'DashboardSans',
                                                      fontSize: 11),
                                                ),
                                                icon: Icon(
                                                    expandedVariability
                                                            .contains(
                                                                benchmark.id)
                                                        ? Icons.expand_less
                                                        : Icons.expand_more,
                                                    size: 16),
                                                label: Text(expandedVariability
                                                        .contains(benchmark.id)
                                                    ? 'Hide variability'
                                                    : 'Show variability'),
                                              ),
                                            ),
                                          ]))),
                              Expanded(
                                  child: Column(children: [
                                for (final phase in operations.keys) ...[
                                  _timingLine(benchmark, phase,
                                      titleWidth: titleWidth,
                                      statsWidth: statsWidth,
                                      compact: compact),
                                  _cpuLine(benchmark, phase,
                                      titleWidth: titleWidth,
                                      statsWidth: statsWidth),
                                  AnimatedSwitcher(
                                    key: ValueKey(
                                        'variability-transition-${benchmark.id}-$phase'),
                                    duration:
                                        MediaQuery.disableAnimationsOf(context)
                                            ? Duration.zero
                                            : const Duration(milliseconds: 220),
                                    switchInCurve: Curves.easeInOutCubic,
                                    switchOutCurve: Curves.easeInOutCubic,
                                    transitionBuilder: (child, animation) =>
                                        SizeTransition(
                                      sizeFactor: animation,
                                      alignment: Alignment.topCenter,
                                      child: child,
                                    ),
                                    child: expandedVariability
                                            .contains(benchmark.id)
                                        ? _timingSamples(benchmark, phase,
                                            titleWidth: titleWidth,
                                            statsWidth: statsWidth)
                                        : const SizedBox.shrink(),
                                  ),
                                  if (phase != operations.keys.last)
                                    Divider(
                                      key: ValueKey(
                                          'operation-divider-${benchmark.id}-$phase'),
                                      height: 1,
                                      color:
                                          Palette.border.withValues(alpha: .45),
                                    ),
                                ],
                              ])),
                            ])),
                ]),
                // At 60 FPS, odd 120 Hz boundaries are secondary. At 120 FPS,
                // every boundary uses the primary style.
                for (var frame = 1; frame <= frameCount; frame++)
                  Positioned(
                      left: plotLeft +
                          frame * frame120 / _chartMaximum * plotWidth -
                          ((selectedFps == 120 || frame.isEven) ? 1.5 : .75),
                      top: 31,
                      bottom: 0,
                      child: IgnorePointer(
                          child: FrameMarkerLine(
                              key: ValueKey('frame-marker-$frame'),
                              major: selectedFps == 120 || frame.isEven))),
                for (var frame = selectedFps == 120 ? 1 : 2;
                    frame <= frameCount;
                    frame += selectedFps == 120 ? 1 : 2)
                  if (((selectedFps == 120 ? frame : frame ~/ 2) - 1) %
                          labelStride ==
                      0)
                    Positioned(
                        left: plotLeft +
                            frame * frame120 / _chartMaximum * plotWidth -
                            30,
                        top: 8,
                        child: IgnorePointer(
                            child: Container(
                          key: ValueKey('frame-marker-label-$frame'),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 5),
                          decoration: BoxDecoration(
                              color: const Color(0xFF3C3020),
                              border: Border.all(color: Palette.amber),
                              borderRadius: BorderRadius.circular(4)),
                          child: Text(
                              '${(frame * frame120).toStringAsFixed(2)} ms',
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Palette.amber)),
                        ))),
              ]);
            }),
            Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
                child: Wrap(spacing: 22, runSpacing: 8, children: [
                  _legend('Median', Palette.green),
                  _legend('p95 tail', Palette.p95),
                  _frameLegend(
                      '$selectedFps FPS · ${frameBudget.toStringAsFixed(2)} ms per frame',
                      major: true),
                  if (selectedFps == 60)
                    _frameLegend('120 FPS · 8.33 ms', major: false),
                  _legend('Near budget · 80–100%', Palette.amber),
                  _legend('Over budget', Palette.red),
                  _legend('Recorded regression', Palette.red),
                  muted(
                      'Timing: shared 0–${_chartMaximum.toStringAsFixed(0)} ms scale. CPU: sampled proportions scaled to P95, from a separate capture; not per-task timings. Variability: individual vertical ranges.',
                      size: 10),
                ])),
          ]));

  double get _chartMaximum {
    final largest = data.current
        .expand((b) => b.timings.values)
        .map((t) => t.value(TimingStatistic.p95))
        .reduce(math.max);
    return (math.max(frameBudget, largest) / 10).ceil() * 10.0;
  }

  Widget _layoutLink(Benchmark benchmark,
          {required Key key, String phase = 'initial'}) =>
      Tooltip(
        message: 'View ${benchmark.title} layout',
        child: InkWell(
          key: key,
          onTap: () => showBenchmarkLayout(context, benchmark,
              fixtureVersion: data.currentRaw['fixtureVersion'] as int,
              phase: phase),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
                child: Text(benchmark.title,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Palette.green,
                        decoration: TextDecoration.underline,
                        decorationColor: Palette.green))),
            const SizedBox(width: 4),
            const Icon(Icons.open_in_new_rounded,
                size: 11, color: Palette.green),
          ]),
        ),
      );

  Widget _timingLine(Benchmark benchmark, String phase,
      {required double titleWidth,
      required double statsWidth,
      required bool compact}) {
    final timing = benchmark.timings[phase]!;
    final median = timing.value(TimingStatistic.median),
        p95 = timing.value(TimingStatistic.p95);
    final failed = TimingStatistic.values.any(
        (stat) => timing.value(stat) > data.limit(benchmark.id, phase, stat));
    return SizedBox(
        key: ValueKey('timing-line-${benchmark.id}-$phase'),
        height: 30,
        child: Tooltip(
          message:
              '${benchmark.title} · ${operations[phase]}\nMedian ${milliseconds(median)} ms · p95 ${milliseconds(p95)} ms\nMin ${milliseconds(timing.statistics['min']!)} / max ${milliseconds(timing.statistics['max']!)} ms${failed ? '\nRecorded regression limit exceeded' : ''}',
          child: Row(children: [
            SizedBox(
                width: titleWidth,
                child: Row(children: [
                  Flexible(
                      child: Text(operations[phase]!,
                          key: ValueKey('timing-title-${benchmark.id}-$phase'),
                          style: const TextStyle(fontSize: 12))),
                  if (failed)
                    const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.circle, size: 5, color: Palette.red)),
                ])),
            Expanded(
                child: LayoutBuilder(
                    builder: (context, constraints) => SizedBox(
                          key: ValueKey('timing-plot-${benchmark.id}-$phase'),
                          height: 30,
                          child: Stack(children: [
                            Positioned(
                                left: 0,
                                right: 0,
                                top: 0,
                                bottom: 0,
                                child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                        width: 1, color: Palette.border))),
                            Positioned(
                                left: 0,
                                top: 10,
                                width:
                                    constraints.maxWidth * p95 / _chartMaximum,
                                height: 10,
                                child: Container(
                                    key: ValueKey(
                                        'p95-bar-${benchmark.id}-$phase'),
                                    decoration: BoxDecoration(
                                        color: timingColor(TimingStatistic.p95,
                                            milliseconds: p95,
                                            budget: frameBudget),
                                        borderRadius:
                                            BorderRadius.circular(2)))),
                            Positioned(
                                left: 0,
                                top: 10,
                                width: constraints.maxWidth *
                                    median /
                                    _chartMaximum,
                                height: 10,
                                child: Container(
                                    key: ValueKey(
                                        'median-bar-${benchmark.id}-$phase'),
                                    decoration: BoxDecoration(
                                        color: timingColor(
                                            TimingStatistic.median,
                                            milliseconds: median,
                                            budget: frameBudget),
                                        borderRadius:
                                            BorderRadius.circular(2)))),
                          ]),
                        ))),
            const SizedBox(width: 16),
            SizedBox(
                width: statsWidth,
                child: Row(children: [
                  for (final stat in TimingStatistic.values)
                    Expanded(
                      child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                _timingValue(
                                    benchmark, phase, stat, timing.value(stat),
                                    compact: compact),
                              ])),
                    )
                ])),
          ]),
        ));
  }

  Widget _cpuLine(Benchmark benchmark, String operation,
      {required double titleWidth, required double statsWidth}) {
    CpuPhase? capture;
    for (final phase in data.cpuCurrent) {
      if (phase.benchmark == benchmark.id && phase.operation == operation) {
        capture = phase;
        break;
      }
    }
    final recorded = capture != null && capture.samples > 0;
    return SizedBox(
      key: ValueKey('cpu-line-${benchmark.id}-$operation'),
      height: 16,
      child: Row(children: [
        SizedBox(width: titleWidth, child: muted('CPU share', size: 9)),
        Expanded(
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor:
                benchmark.timings[operation]!.value(TimingStatistic.p95) /
                    _chartMaximum,
            child: SizedBox(
              key: ValueKey('cpu-bar-${benchmark.id}-$operation'),
              height: 4,
              child: recorded
                  ? Row(children: [
                      for (final bucket in {
                        ...cpuNames.keys,
                        ...capture.buckets.keys,
                      })
                        if ((capture.buckets[bucket] ?? 0) > 0)
                          Expanded(
                            flex: capture.buckets[bucket]!,
                            child: Tooltip(
                              waitDuration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Palette.raised,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Palette.border),
                              ),
                              richMessage: TextSpan(
                                style: const TextStyle(
                                    fontFamily: 'DashboardSans',
                                    fontSize: 12,
                                    color: Palette.text,
                                    height: 1.5),
                                children: [
                                  TextSpan(
                                    text: '${cpuNames[bucket] ?? bucket} · '
                                        '${(capture.buckets[bucket]! / capture.samples * 100).toStringAsFixed(1)}%\n',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  TextSpan(
                                      text: cpuDescriptions[bucket] ??
                                          'Other sampled layout work.'),
                                ],
                              ),
                              child: Container(
                                key: ValueKey(
                                    'cpu-segment-${benchmark.id}-$operation-$bucket'),
                                color: cpuColors[bucket] ?? Palette.muted,
                              ),
                            ),
                          ),
                    ])
                  : Tooltip(
                      message: 'No CPU capture was recorded for this test.',
                      child: Container(color: Palette.border),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
            width: statsWidth,
            child: Align(
                alignment: Alignment.centerRight,
                child: muted(
                    recorded ? 'CPU share · scaled to P95' : 'CPU not recorded',
                    size: 9))),
      ]),
    );
  }

  Widget _timingSamples(Benchmark benchmark, String phase,
      {required double titleWidth, required double statsWidth}) {
    final timing = benchmark.timings[phase]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        key: ValueKey('sample-area-${benchmark.id}-$phase'),
        color: Palette.background,
        child: Row(children: [
          SizedBox(width: titleWidth),
          Expanded(
            child: Tooltip(
              message:
                  'Layout time across ${timing.samples.length} measured runs, in run order. '
                  'Each chart uses its own vertical range to show variation. The overlaid frame grid uses the timing meter’s scale, not the chart’s run-order axis.',
              child: Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 38,
                        child: SampleSparkline(
                          key: ValueKey('samples-${benchmark.id}-$phase'),
                          samples: timing.samples,
                        ),
                      ),
                      Text(
                        '${timing.samples.length} runs · min ${milliseconds(timing.statistics['min']!)} / max ${milliseconds(timing.statistics['max']!)} ms',
                        style:
                            const TextStyle(fontSize: 9, color: Palette.muted),
                      ),
                    ]),
              ),
            ),
          ),
          SizedBox(width: statsWidth + 16),
        ]),
      ),
    );
  }

  Widget _timingValue(
      Benchmark benchmark, String phase, TimingStatistic stat, double value,
      {bool compact = false}) {
    final failed = value > data.limit(benchmark.id, phase, stat);
    final color = timingColor(stat, milliseconds: value, budget: frameBudget);
    return Semantics(
        label:
            '${benchmark.title}, ${operations[phase]}, current ${stat.label} ${milliseconds(value)} milliseconds${failed ? ', regression limit exceeded' : ''}',
        child: Text(milliseconds(value),
            key: ValueKey('timing-${benchmark.id}-$phase-${stat.key}'),
            style: TextStyle(
                fontFamily: 'DashboardMono',
                fontSize: compact ? 12 : 14,
                color: color)));
  }

  Widget _fpsPicker() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
          border: Border.all(color: Palette.border),
          borderRadius: BorderRadius.circular(5)),
      child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
        key: const ValueKey('fps-picker'),
        value: selectedFps,
        dropdownColor: Palette.raised,
        style: const TextStyle(
            fontFamily: 'DashboardSans', fontSize: 12, color: Palette.text),
        items: [
          for (final fps in [60, 120])
            DropdownMenuItem(value: fps, child: Text('$fps FPS'))
        ],
        onChanged: (fps) {
          if (fps != null) setState(() => selectedFps = fps);
        },
      )));

  Widget _frameLegend(String label, {required bool major}) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
            width: 20,
            height: 12,
            child: Center(
                child: SizedBox(
                    height: 12, child: FrameMarkerLine(major: major)))),
        const SizedBox(width: 6),
        muted(label, size: 10),
      ]);
  Widget _legend(String label, Color color) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, color: color),
        const SizedBox(width: 6),
        muted(label, size: 10)
      ]);

  Widget _wideTable(double minimumWidth, Widget Function(double) builder) =>
      LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                  width: math.max(minimumWidth, constraints.maxWidth),
                  child:
                      builder(math.max(minimumWidth, constraints.maxWidth)))));

  Widget _failures() => Panel(
      key: const ValueKey('regression-checks'),
      padding: EdgeInsets.zero,
      child: Column(
          key: checksAnchor,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeading('Regression checks',
                '${data.failures.length} failures shown below · ${data.checks.length - data.failures.length} of ${data.checks.length} checks passed against saved timing limits',
                action: Tag('${data.failures.length} CHECKS NEED ATTENTION',
                    color: Palette.amber, icon: Icons.warning_amber_rounded)),
            _wideTable(
                830,
                (_) => Column(children: [
                      _failureHeader(),
                      for (final check in data.failures)
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 22, vertical: 14),
                            decoration: const BoxDecoration(
                                border: Border(
                                    top: BorderSide(color: Palette.border))),
                            child: Row(children: [
                              Expanded(
                                  flex: 3,
                                  child: _layoutLink(check.benchmark,
                                      key: ValueKey(
                                          'preview-failure-${check.benchmark.id}-${check.operation}-${check.statistic.key}'),
                                      phase: check.operation)),
                              Expanded(
                                  flex: 3,
                                  child: muted(
                                      '${operations[check.operation]} · ${check.statistic.label}',
                                      size: 11)),
                              Expanded(
                                  flex: 2,
                                  child: mono(
                                      '${milliseconds(check.current)} ms',
                                      color: Palette.red,
                                      size: 12)),
                              Expanded(
                                  flex: 2,
                                  child: mono('${milliseconds(check.limit)} ms',
                                      size: 12)),
                              Expanded(
                                  flex: 2,
                                  child: Text(
                                      '${check.excessPercent.toStringAsFixed(1)}% over',
                                      style: const TextStyle(
                                          color: Palette.red, fontSize: 11))),
                            ])),
                    ])),
            Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
                child: muted(
                    'These recorded failures remain unresolved. Regression limits are independent of the frame grid.',
                    size: 11)),
          ]));
  Widget _failureHeader() => Container(
      color: Palette.background.withValues(alpha: .35),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
      child: Row(children: [
        Expanded(flex: 3, child: caption('BENCHMARK')),
        Expanded(flex: 3, child: caption('OPERATION / STAT')),
        Expanded(flex: 2, child: caption('CURRENT')),
        Expanded(flex: 2, child: caption('LIMIT')),
        Expanded(flex: 2, child: caption('EXCESS'))
      ]));

  Widget _runSetup() {
    final flutter = data.host['flutter'] as Map<String, dynamic>;
    final entries = <String, String>{
      'Machine': '${data.host['cpu']} · ${data.host['architecture']}',
      'OS / memory':
          'macOS ${data.host['macOS']} / ${((data.host['memoryBytes'] as num) / 1073741824).toStringAsFixed(0)} GiB',
      'Flutter / Dart':
          '${flutter['frameworkVersion']} / ${flutter['dartSdkVersion']}',
      'Recorded at': data.recordedAt
          .toIso8601String()
          .replaceAll('T', ' ')
          .replaceAll('Z', ' UTC'),
      'Implementation': '${data.currentRaw['fittingImplementation']}',
      'Sample protocol':
          '${data.samples} samples after ${data.warmups} warm-ups · fixture v${data.currentRaw['fixtureVersion']}',
    };
    return Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Run setup & reproduction',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
      const SizedBox(height: 22),
      LayoutBuilder(
          builder: (context, constraints) =>
              Wrap(spacing: 24, runSpacing: 18, children: [
                for (final entry in entries.entries)
                  SizedBox(
                      width: constraints.maxWidth >= 850
                          ? (constraints.maxWidth - 48) / 3
                          : constraints.maxWidth >= 540
                              ? (constraints.maxWidth - 24) / 2
                              : constraints.maxWidth,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            caption(entry.key.toUpperCase()),
                            const SizedBox(height: 8),
                            SelectableText(entry.value,
                                style: const TextStyle(
                                    fontFamily: 'DashboardMono',
                                    fontSize: 11,
                                    height: 1.5))
                          ])),
              ])),
      const SizedBox(height: 24),
      const Divider(height: 1),
      const SizedBox(height: 20),
      muted(data.currentRaw['editSetup'] as String),
      const SizedBox(height: 10),
      muted(
          'Timings were recorded on the machine and SDK above. CPU captures are separate, and early GC events may be missing from the timeline ring buffer.'),
      const SizedBox(height: 22),
      caption('RUN FROM THE REPOSITORY ROOT'),
      const SizedBox(height: 12),
      Container(
          key: const ValueKey('reproduction-code-block'),
          width: double.infinity,
          decoration: BoxDecoration(
              color: Palette.background,
              border: Border.all(color: Palette.border),
              borderRadius: BorderRadius.circular(6)),
          child: Stack(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 58, 18),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText(data.reproduceCommand,
                    style: const TextStyle(
                        fontFamily: 'DashboardMono',
                        fontSize: 11,
                        color: Palette.green,
                        height: 1.9)),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: IconButton(
                tooltip: 'Copy command',
                onPressed: () => _copy(data.reproduceCommand),
                icon: const Icon(Icons.copy_outlined, size: 18),
              ),
            ),
          ])),
      const SizedBox(height: 16),
      Wrap(spacing: 12, runSpacing: 10, children: [
        OutlinedButton.icon(
            onPressed: () => _copy(
                const JsonEncoder.withIndent('  ').convert(data.currentRaw)),
            icon: const Icon(Icons.data_object_rounded, size: 15),
            label: const Text('Copy current JSON')),
      ]),
    ]));
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Copied to clipboard'),
          duration: Duration(seconds: 2)));
    }
  }
}
