// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;

/// Creates its own disposable host; never modifies an application checkout.
Future<void> main(List<String> arguments) async {
  final args = (ArgParser()
        ..addOption('flutter', defaultsTo: 'flutter')
        ..addOption('samples', defaultsTo: '3')
        ..addOption('study',
            defaultsTo: 'prepared', allowed: ['prepared', 'shaping', 'routing'])
        ..addOption('output',
            defaultsTo: 'build/profile/prepared-text-checkpoint.json')
        ..addFlag('help', negatable: false))
      .parse(arguments);
  if (args['help'] as bool) {
    print(
        'dart run lib/main_prepared_text_checkpoint.dart [--flutter path] [--output path] [--samples count] [--study prepared|shaping|routing]');
    return;
  }
  if (!Platform.isMacOS || args.rest.isNotEmpty) {
    throw ArgumentError('Run on macOS from performance, with named options.');
  }
  final samples = int.tryParse(args['samples'] as String);
  if (samples == null || samples < 1) {
    throw ArgumentError('--samples must be positive');
  }
  final root = Directory.current.resolveSymbolicLinksSync();
  if (!File(p.join(root, 'integration_test/prepared_text_checkpoint_test.dart'))
      .existsSync()) {
    throw StateError('Run from performance.');
  }
  final study = args['study'] as String;
  final targetTest = switch (study) {
    'shaping' => 'integration_test/shaping_study_test.dart',
    'routing' => 'integration_test/automatic_routing_study_test.dart',
    _ => 'integration_test/prepared_text_checkpoint_test.dart',
  };
  final output = File(p.absolute(args['output'] as String));
  await output.parent.create(recursive: true);
  if (await output.exists()) await output.delete();
  final log = File('${output.path}.log').openWrite();
  final host =
      await Directory.systemTemp.createTemp('prepared_text_checkpoint_');
  final flutter = args['flutter'] as String;
  Future<void> run(List<String> command, {bool inHost = true}) async {
    final process = await Process.start(flutter, command,
        workingDirectory: inHost ? host.path : root,
        environment: {'FLOW_BENCHMARK_OUTPUT': output.path});
    await Future.wait(
        [process.stdout.forEach(log.add), process.stderr.forEach(log.add)]);
    final code = await process.exitCode;
    if (code != 0) {
      throw StateError('Flutter exited $code. See ${output.path}.log');
    }
  }

  try {
    print('Preparing disposable native profile host. Log: ${output.path}.log');
    await run([
      'create',
      '--platforms=macos',
      '--project-name=prepared_text_checkpoint_host',
      '--no-pub',
      host.path
    ], inHost: false);
    await File(p.join(host.path, 'pubspec.yaml'))
        .writeAsString('''name: prepared_text_checkpoint_host
publish_to: none
environment:
  sdk: '>=3.4.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
  performance:
    path: ${jsonEncode(root)}
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
flutter:
  uses-material-design: true
''');
    for (final name in [targetTest, 'test_driver/profile_driver.dart']) {
      final target = File(p.join(host.path, name));
      await target.parent.create(recursive: true);
      await File(p.join(root, name)).copy(target.path);
    }
    await run(['pub', 'get']);
    print(
        'Measuring preparation, numeric fitting, and exact reference fitting.');
    await run([
      'drive',
      '--profile',
      '-d',
      'macos',
      '--no-pub',
      '--driver=test_driver/profile_driver.dart',
      '--target=$targetTest',
      '--dart-define=INTEGRATION_TEST_SHOULD_REPORT_RESULTS_TO_NATIVE=false',
      '--dart-define=PREPARED_TEXT_CHECKPOINT_SAMPLES=$samples'
    ]);
    final data =
        jsonDecode(await output.readAsString()) as Map<String, dynamic>;
    if (data['checkpoint']?['mode'] != 'profile') {
      throw StateError('Missing profile results');
    }
    data['host'] = {
      'os': Platform.operatingSystemVersion,
      'flutter': jsonDecode(
          (await Process.run(flutter, ['--version', '--machine'])).stdout
              as String)
    };
    await output
        .writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    print('Checkpoint results: ${output.path}');
  } finally {
    await log.close();
    // Flutter drive can leave its test app alive when interrupted. Only stop
    // the executable inside this runner's uniquely owned temporary directory.
    final executable = p.join(host.resolveSymbolicLinksSync(),
        'build/macos/Build/Products/Profile/prepared_text_checkpoint_host.app/Contents/MacOS/prepared_text_checkpoint_host');
    final processes = await Process.run('ps', ['-axo', 'pid=,comm=']);
    for (final line in (processes.stdout as String).split('\n')) {
      final match = RegExp(r'^\s*(\d+)\s+(.+)$').firstMatch(line);
      if (match != null && match.group(2) == executable) {
        Process.killPid(int.parse(match.group(1)!), ProcessSignal.sigterm);
      }
    }
    await host.delete(recursive: true);
  }
}
