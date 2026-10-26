// Command-line benchmark orchestration; output is intentionally printed.
// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'src/profile_baseline.dart';

ArgParser profileArgumentParser() => ArgParser()
  ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage.')
  ..addOption('flutter', defaultsTo: 'flutter', help: 'Flutter executable.')
  ..addOption('samples', defaultsTo: '30', help: 'Samples per operation.')
  ..addOption('output',
      help: 'Result JSON; defaults to build/profile/macos.json.')
  ..addOption('baseline',
      help: 'Reviewed integration result from this benchmark machine.')
  ..addOption('max-regression-percent',
      defaultsTo: '20', help: 'Allowed increase in median and p95.')
  ..addFlag('allow-sdk-change',
      negatable: false,
      help: 'Permit an intentional SDK comparison; hardware checks remain.')
  ..addOption('host-directory',
      help:
          'Disposable host to reuse; its manifest, main, test and driver are overwritten.');

class ProfileOptions {
  ProfileOptions._(this.root, this.flutter, this.samples, this.output,
      this.baseline, this.maxRegressionPercent, this.allowSdkChange, this.host);
  final String root;
  final String flutter;
  final int samples;
  final String output;
  final String? baseline;
  final double maxRegressionPercent;
  final bool allowSdkChange;
  final String? host;
  String get log => p.setExtension(output, '.log');
  String get response => p.setExtension(output, '.integration-response.json');

  factory ProfileOptions.parse(List<String> arguments,
      {required String prototypeRoot}) {
    final args = profileArgumentParser().parse(arguments);
    if (args.rest.isNotEmpty) {
      throw const FormatException('Unexpected positional arguments.');
    }
    final samples = int.tryParse(args['samples'] as String);
    final allowance = double.tryParse(args['max-regression-percent'] as String);
    if (samples == null || samples < 1) {
      throw const FormatException('--samples must be positive.');
    }
    if (allowance == null || !allowance.isFinite || allowance < 0) {
      throw const FormatException(
          '--max-regression-percent must be finite and nonnegative.');
    }
    final root = canonicalProfilePath(prototypeRoot);
    final output = canonicalProfilePath(
        args['output'] as String? ?? p.join(root, 'build/profile/macos.json'));
    final baseline = args['baseline'] == null
        ? null
        : canonicalProfilePath(args['baseline'] as String);
    if (baseline != null &&
        [
          output,
          p.setExtension(output, '.log'),
          p.setExtension(output, '.integration-response.json')
        ].map(canonicalProfilePath).contains(baseline)) {
      throw const FormatException(
          '--output and its log/response must not overwrite the baseline.');
    }
    var flutter = args['flutter'] as String;
    if (flutter.contains(p.separator)) flutter = canonicalProfilePath(flutter);
    final host = args['host-directory'] == null
        ? null
        : canonicalProfilePath(args['host-directory'] as String);
    if (host != null) validateProfileHost(host, root);
    return ProfileOptions._(root, flutter, samples, output, baseline, allowance,
        args['allow-sdk-change'] as bool, host);
  }
}

/// Resolve existing symlink ancestors even for output files not yet created.
String canonicalProfilePath(String path) {
  var existing = p.normalize(p.absolute(path));
  final suffix = <String>[];
  while (FileSystemEntity.typeSync(existing, followLinks: false) ==
      FileSystemEntityType.notFound) {
    final parent = p.dirname(existing);
    if (parent == existing) break;
    suffix.insert(0, p.basename(existing));
    existing = parent;
  }
  final resolved = FileSystemEntity.isDirectorySync(existing)
      ? Directory(existing).resolveSymbolicLinksSync()
      : File(existing).resolveSymbolicLinksSync();
  return p.joinAll([resolved, ...suffix]);
}

void validateProfileHost(String host, String root) {
  if (p.equals(host, root) ||
      p.isWithin(root, host) ||
      p.isWithin(host, root)) {
    throw const FormatException(
        'The disposable host must be outside the prototype and its ancestor directories.');
  }
  final type = FileSystemEntity.typeSync(host);
  if (type == FileSystemEntityType.notFound) return;
  if (type != FileSystemEntityType.directory) {
    throw const FormatException('The disposable host must be a directory.');
  }
  if (Directory(host).listSync().isEmpty) return;
  final manifest = File(p.join(host, 'pubspec.yaml'));
  if (!manifest.existsSync() ||
      !RegExp(r'^name:\s*flow_profile_host\s*$', multiLine: true)
          .hasMatch(manifest.readAsStringSync())) {
    throw const FormatException(
        'Refusing to overwrite a nonempty directory that is not a flow_profile_host.');
  }
}

Future<String> _command(String executable, List<String> arguments) async {
  final result = await Process.run(executable, arguments);
  if (result.exitCode != 0) {
    throw ProcessException(
        executable, arguments, '${result.stderr}', result.exitCode);
  }
  return (result.stdout as String).trim();
}

Future<Map<String, dynamic>> _hostMetadata(String flutter) async => {
      'cpu': await _command('sysctl', ['-n', 'machdep.cpu.brand_string']),
      'architecture': await _command('uname', ['-m']),
      'macOS': await _command('sw_vers', ['-productVersion']),
      'physicalCores':
          int.parse(await _command('sysctl', ['-n', 'hw.physicalcpu'])),
      'memoryBytes': int.parse(await _command('sysctl', ['-n', 'hw.memsize'])),
      'flutter':
          jsonDecode(await _command(flutter, ['--version', '--machine'])),
    };

Future<void> _deleteIfPresent(String path) async {
  final file = File(path);
  if (await file.exists()) await file.delete();
}

Future<int> _drive(
    ProfileOptions options, String host, Map<String, dynamic> budgets) async {
  final arguments = [
    'drive',
    '--profile',
    '-d',
    'macos',
    '--driver=test_driver/profile_driver.dart',
    '--target=integration_test/flow_profile_test.dart',
    '--dart-define=INTEGRATION_TEST_SHOULD_REPORT_RESULTS_TO_NATIVE=false',
    '--dart-define=FLOW_BENCHMARK_FONT_ASSET=packages/flow_layout_prototype/assets/fonts/Roboto-Regular.ttf',
    '--dart-define=FLOW_BENCHMARK_SAMPLES=${options.samples}',
    if (budgets.isNotEmpty)
      '--dart-define=FLOW_BENCHMARK_BUDGETS=${jsonEncode(budgets)}',
  ];
  final log = File(options.log).openWrite();
  Process? child;
  StreamSubscription<ProcessSignal>? interrupt;
  StreamSubscription<ProcessSignal>? terminate;
  Timer? forceStop;
  Future<List<void>>? streams;
  int? cancelled;
  var finished = false;
  try {
    child = await Process.start(options.flutter, arguments,
        workingDirectory: host,
        environment: {'FLOW_BENCHMARK_OUTPUT': options.response});
    final process = child;
    streams = Future.wait(
        [process.stdout.forEach(log.add), process.stderr.forEach(log.add)]);
    void stop(ProcessSignal signal, int code) {
      cancelled = code;
      process.kill(signal);
      forceStop ??= Timer(const Duration(seconds: 15),
          () => process.kill(ProcessSignal.sigkill));
    }

    interrupt = ProcessSignal.sigint
        .watch()
        .listen((_) => stop(ProcessSignal.sigint, 130));
    terminate = ProcessSignal.sigterm
        .watch()
        .listen((_) => stop(ProcessSignal.sigterm, 143));
    final code = await process.exitCode.timeout(const Duration(minutes: 10));
    finished = true;
    if (cancelled != null) throw _Cancelled(cancelled!);
    return code;
  } finally {
    await interrupt?.cancel();
    await terminate?.cancel();
    forceStop?.cancel();
    if (child != null && !finished) {
      child.kill(ProcessSignal.sigint);
      try {
        await child.exitCode.timeout(const Duration(seconds: 15));
      } on TimeoutException {
        child.kill(ProcessSignal.sigkill);
        await child.exitCode;
      }
    }
    if (streams != null) await streams;
    await log.close();
  }
}

Future<void> _run(ProfileOptions options, String host,
    Map<String, dynamic> metadata, Map<String, dynamic> budgets) async {
  validateProfileHost(host, options.root);
  print('Preparing disposable macOS host...');
  await _command(options.flutter, [
    'create',
    '--platforms=macos',
    '--project-name=flow_profile_host',
    '--no-pub',
    host
  ]);
  await File(p.join(host, 'pubspec.yaml'))
      .writeAsString('''name: flow_profile_host
publish_to: none
environment:
  sdk: '>=3.4.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
  flow_layout_prototype:
    path: ${jsonEncode(options.root)}
dev_dependencies:
  integration_test:
    sdk: flutter
  flutter_test:
    sdk: flutter
flutter:
  uses-material-design: true
''');
  await File(p.join(host, 'lib/main.dart')).writeAsString(
      "import 'package:flow_layout_prototype/profile_benchmark.dart' as benchmark;\n"
      'Future<void> main() => benchmark.main();\n');
  for (final file in [
    'integration_test/flow_profile_test.dart',
    'test_driver/profile_driver.dart'
  ]) {
    final target = File(p.join(host, file));
    await target.parent.create(recursive: true);
    await File(p.join(options.root, file)).copy(target.path);
  }
  await File(options.output).parent.create(recursive: true);
  await _deleteIfPresent(options.response);
  await _deleteIfPresent(options.output);
  print('Running profile integration test; log: ${options.log}');
  final code = await _drive(options, host, budgets);
  final response = File(options.response);
  final report = await response.exists()
      ? jsonDecode(await response.readAsString())
      : null;
  if (report is! Map<String, dynamic> ||
      report['benchmark'] is! Map<String, dynamic>) {
    throw StateError(
        'No integration benchmark result (Flutter exit $code); inspect ${options.log}');
  }
  final result = report['benchmark'] as Map<String, dynamic>;
  result['host'] = metadata;
  result['budgetEnforced'] = report['budgetEnforced'] ?? false;
  result['budgetFailures'] = report['budgetFailures'] ?? [];
  if (options.baseline != null) {
    result['baselineComparison'] = {
      'path': options.baseline,
      'maxRegressionPercent': options.maxRegressionPercent,
      'allowSDKChange': options.allowSdkChange,
    };
  }
  await File(options.output)
      .writeAsString('${const JsonEncoder.withIndent('  ').convert(result)}\n');
  print('\nSaved ${options.output}\nFull paragraph layout, milliseconds:');
  for (final dynamic scenario in result['scenarios'] as List<dynamic>) {
    print(scenario['name']);
    for (final phase in ['initial', 'resize', 'update']) {
      final stats = scenario['summary'][phase]['fullLayoutUs'];
      print('  $phase: median ${(stats['median'] / 1000).toStringAsFixed(2)}; '
          'p95 ${(stats['p95'] / 1000).toStringAsFixed(2)}');
    }
  }
  if (code != 0 ||
      (result['budgetFailures'] as List<dynamic>).isNotEmpty ||
      result['budgetEnforced'] != budgets.isNotEmpty) {
    throw StateError(
        'Integration benchmark failed: ${result['budgetFailures']}; inspect ${options.log}');
  }
  print(budgets.isNotEmpty
      ? 'Timing budgets passed.'
      : 'Recorded only: no timing baseline was enforced.');
}

class _Cancelled implements Exception {
  _Cancelled(this.code);
  final int code;
}

Future<void> main(List<String> arguments) async {
  try {
    if (profileArgumentParser().parse(arguments)['help'] as bool) {
      print(
          'Run a native profile integration test and optionally enforce a matching-machine baseline.\n'
          'dart run tool/profile_macos.dart [options]\n${profileArgumentParser().usage}');
      return;
    }
    final options = ProfileOptions.parse(arguments,
        prototypeRoot: File.fromUri(Platform.script).parent.parent.path);
    if (!Platform.isMacOS) {
      throw const FormatException(
          'This convenience runner targets macOS; use a native host for other platforms.');
    }
    final metadata = await _hostMetadata(options.flutter);
    final budgets = options.baseline == null
        ? <String, dynamic>{}
        : makeProfileBudgets(
            jsonDecode(await File(options.baseline!).readAsString()),
            metadata,
            samples: options.samples,
            maxRegressionPercent: options.maxRegressionPercent,
            allowSdkChange: options.allowSdkChange,
          );
    if (options.host != null) {
      await _run(options, options.host!, metadata, budgets);
    } else {
      final temporary = await Directory.systemTemp.createTemp('flow_profile_');
      try {
        await _run(options, p.join(temporary.path, 'host'), metadata, budgets);
      } finally {
        await temporary.delete(recursive: true);
      }
    }
  } on _Cancelled catch (error) {
    exitCode = error.code;
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 2;
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
