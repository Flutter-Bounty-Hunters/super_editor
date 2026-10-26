import 'dart:convert';
import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_text_layout/experimental_flow.dart';
import 'profile_fixture_data.dart';
import 'profile_fixture_widgets.dart';

const _waitForProfiler =
    bool.fromEnvironment('FLOW_BENCHMARK_WAIT_FOR_PROFILER');
final _profileStart = Completer<void>();
bool _profileReady = false;
Map<String, Object>? _profileResult;

/// Dedicated benchmark entry point; the interactive demo is unchanged.
Future<void> main() async {
  await runFlowProfileBenchmark();
}

/// Shared by the standalone app and the profile-mode integration test. The
/// returned future completes after all measured frames and summary display.
Future<Map<String, Object>> runFlowProfileBenchmark(
    {bool logResult = true}) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kProfileMode) {
    throw StateError('Run this benchmark with --profile.');
  }
  if (_waitForProfiler) {
    developer.registerExtension(
        'ext.flowBenchmark.status',
        (method, params) async =>
            developer.ServiceExtensionResponse.result(jsonEncode({
              'ready': _profileReady,
              'done': _profileResult != null,
              'result': _profileResult,
            })));
    developer.registerExtension('ext.flowBenchmark.start',
        (method, params) async {
      if (!_profileReady) throw StateError('Benchmark has not warmed up yet.');
      if (!_profileStart.isCompleted) _profileStart.complete();
      return developer.ServiceExtensionResponse.result('{}');
    });
  }
  const asset = String.fromEnvironment('FLOW_BENCHMARK_FONT_ASSET',
      defaultValue: 'assets/fonts/Roboto-Regular.ttf');
  await (FontLoader('FlowBenchmark')..addFont(rootBundle.load(asset))).load();
  await (FontLoader('FlowBenchmarkCode')
        ..addFont(rootBundle.load(
            asset.replaceFirst('Roboto-Regular.ttf', 'FiraMono-Regular.ttf'))))
      .load();
  final complete = Completer<Map<String, Object>>();
  runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'FlowBenchmark'),
      home: _Benchmark(
          onComplete: complete.complete,
          onError: complete.completeError,
          logResult: logResult)));
  return complete.future;
}

class _Benchmark extends StatefulWidget {
  const _Benchmark(
      {required this.onComplete,
      required this.onError,
      required this.logResult});
  final void Function(Map<String, Object> result) onComplete;
  final void Function(Object error, StackTrace stack) onError;
  final bool logResult;
  @override
  State<_Benchmark> createState() => _BenchmarkState();
}

class _BenchmarkState extends State<_Benchmark> {
  static const samples =
      int.fromEnvironment('FLOW_BENCHMARK_SAMPLES', defaultValue: 30);
  static const warmups = 5;
  final _controller = FlowLayoutController();
  final _paragraphKey = GlobalKey();
  bool _showParagraph = false;
  String _scenario = 'test_boxes';
  double get _fontSize =>
      (profileFixtureMetadata[_scenario]!['fontSize']! as int).toDouble();
  double _width = 600;
  ProfileEdit? _edit;
  String _status = 'Preparing profile benchmark';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _frame(VoidCallback change) async {
    setState(change);
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<Map<String, Object>> _measure(VoidCallback change) async {
    final before = _paragraphKey.currentContext?.findRenderObject()
        as _TimedRenderParagraph?;
    final previousCalls = before?.calls ?? 0;
    final previousSnapshot = _controller.layout;
    await _frame(change);
    final render = _paragraphKey.currentContext!.findRenderObject()!
        as _TimedRenderParagraph;
    final layout = _controller.layout!;
    final calls =
        render.calls - (identical(before, render) ? previousCalls : 0);
    if (calls != 1 ||
        identical(layout, previousSnapshot) ||
        render.size.width != _width) {
      throw StateError(
          'Expected one fresh layout at width $_width; got $calls calls.');
    }
    return {
      'fullLayoutUs': render.elapsed.inMicroseconds,
      'compositionUs': layout.layoutDuration.inMicroseconds,
      'lines': layout.lines.length,
      'fragments': layout.fragments.length,
      'heightRetries': layout.lineRetries,
      if (_waitForProfiler) 'layoutStartMicros': render.profileStart,
      if (_waitForProfiler) 'layoutEndMicros': render.profileEnd,
    };
  }

  Future<Map<String, Map<String, Object>>> _cycle() async {
    final results = <String, Map<String, Object>>{};
    // Every edit gets the same initial/resize history in a fresh render object.
    // Restoring text in-place would retain choices from earlier edit cases.
    for (final edit in ProfileEdit.values) {
      await _frame(() => _showParagraph = false);
      final initial = await _measure(() {
        _width = 600;
        _edit = null;
        _showParagraph = true;
      });
      final resize = await _measure(() => _width = 320);
      if (edit == ProfileEdit.beginning) {
        results['initial'] = initial;
        results['resize'] = resize;
      }
      results[edit.phase] = await _measure(() => _edit = edit);
    }
    return results;
  }

  Future<void> _run() async {
    try {
      if (samples < 1) throw StateError('At least one sample is required.');
      final scenarios = <Map<String, Object>>[];
      for (final scenario in (_waitForProfiler
          ? [
              const String.fromEnvironment('FLOW_CPU_SCENARIO',
                  defaultValue: 'unique_prose')
            ]
          : profileFixtureMetadata.keys)) {
        await _frame(() {
          _scenario = scenario;
          _status = 'Measuring $scenario';
        });
        final cold = await _cycle();
        for (var i = 0; i < warmups; i++) {
          await _cycle();
        }
        if (_waitForProfiler) {
          _profileReady = true;
          // ignore: avoid_print
          print('FLOW_CPU_PROFILE_READY');
          await _profileStart.future;
        }
        final raw = <String, List<Map<String, Object>>>{
          for (final phase in profilePhases) phase: [],
        };
        for (var i = 0; i < samples; i++) {
          final cycle = await _cycle();
          for (final phase in raw.keys) {
            raw[phase]!.add(cycle[phase]!);
          }
        }
        scenarios.add({
          'name': scenario,
          ...profileFixtureMetadata[scenario]!,
          'editLocations': {
            for (final edit in ProfileEdit.values)
              edit.phase: {
                'chunk': profileEditLocation(scenario, edit).chunk,
                'offset': profileEditLocation(scenario, edit).offset
              },
          },
          // This is the first run of this scenario in the current process,
          // not an isolated process-cold run for each scenario.
          'firstObserved': cold,
          'summary': {
            for (final phase in raw.keys)
              phase: {
                'fullLayoutUs': _stats(raw[phase]!, 'fullLayoutUs'),
                'compositionUs': _stats(raw[phase]!, 'compositionUs'),
              },
          },
          'samples': raw,
        });
      }
      final result = {
        'schemaVersion': 1,
        'fixtureVersion': profileFixtureVersion,
        'execution': 'standalone',
        'mode': 'profile',
        'platform': defaultTargetPlatform.name,
        'web': kIsWeb,
        'recordedAtUtc': DateTime.now().toUtc().toIso8601String(),
        'warmupCycles': warmups,
        'samplesPerPhase': samples,
        'widths': [600, 320],
        'editSetup': profileEditSetup,
        'editText': profileEditText,
        'timingScope':
            'fullLayoutUs wraps RenderFlowParagraph.performLayout, including snapshot disposal and fragment commits; compositionUs is the existing internal timer. Neither includes widget build, painting, rasterization, or frame scheduling.',
        'scenarios': scenarios,
      };
      if (_waitForProfiler) _profileResult = result;
      // Machine-readable output consumed by the benchmark runner/log collector.
      if (widget.logResult) {
        // ignore: avoid_print
        print('FLOW_BENCHMARK_RESULT ${jsonEncode(result)}');
      }
      await _frame(() {
        _showParagraph = false;
        _status = const JsonEncoder.withIndent('  ').convert({
          for (final scenario in scenarios)
            scenario['name'] as String: scenario['summary'],
        });
      });
      widget.onComplete(result);
    } catch (error, stack) {
      // ignore: avoid_print
      print('FLOW_BENCHMARK_ERROR $error\n$stack');
      await _frame(() => _status = 'Benchmark failed: $error');
      widget.onError(error, stack);
    }
  }

  Map<String, num> _stats(List<Map<String, Object>> values, String key) {
    final sorted = values.map((v) => v[key]! as int).toList()..sort();
    final middle = sorted.length ~/ 2;
    return {
      'min': sorted.first,
      'median': sorted.length.isOdd
          ? sorted[middle]
          : (sorted[middle - 1] + sorted[middle]) / 2,
      'p95': sorted[math.max(0, (sorted.length * .95).ceil() - 1)],
      'max': sorted.last,
    };
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Flow layout · profile benchmark'),
                const SizedBox(height: 12),
                Expanded(
                    child: SingleChildScrollView(
                        child: _showParagraph
                            ? SizedBox(
                                width: _width,
                                child: DefaultTextStyle(
                                    style: TextStyle(
                                        fontFamily: 'FlowBenchmark',
                                        fontSize: _fontSize,
                                        color: Colors.black),
                                    child: _TimedParagraph(
                                      key: _paragraphKey,
                                      controller: _controller,
                                      style: TextStyle(
                                          fontFamily: 'FlowBenchmark',
                                          fontSize: _fontSize,
                                          color: Colors.black),
                                      regions: RectangularFlowRegions(
                                          obstacles: profileFixtureMetadata[
                                                      _scenario]!['obstacle']!
                                                  as bool
                                              ? [
                                                  const Rect.fromLTWH(
                                                      210, 20, 130, 80)
                                                ]
                                              : []),
                                      children: buildProfileFixture(_scenario,
                                          edit: _edit),
                                    )))
                            : Text(_status))),
              ],
            )),
      );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _TimedParagraph extends FlowParagraph {
  const _TimedParagraph(
      {super.key,
      required super.controller,
      required super.style,
      required super.regions,
      required super.children});
  @override
  RenderFlowParagraph createRenderObject(BuildContext context) =>
      _TimedRenderParagraph(controller, regions!, style);
}

class _TimedRenderParagraph extends RenderFlowParagraph {
  _TimedRenderParagraph(FlowLayoutController controller,
      FlowRegionProvider regions, TextStyle style)
      : super(controller, regions, style, null, null);
  Duration elapsed = Duration.zero;
  int calls = 0;
  int profileStart = 0;
  int profileEnd = 0;
  @override
  void performLayout() {
    final watch = Stopwatch()..start();
    if (_waitForProfiler) profileStart = developer.Timeline.now;
    try {
      super.performLayout();
    } finally {
      if (_waitForProfiler) profileEnd = developer.Timeline.now;
      elapsed = watch.elapsed;
      calls++;
    }
  }
}
