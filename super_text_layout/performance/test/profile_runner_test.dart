import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:performance/main_profile_macos.dart' as runner;

void main() {
  late Directory temporary;
  late String root;
  setUp(() {
    temporary = Directory.systemTemp.createTempSync('flow_cli_test_');
    final performance = Directory(p.join(temporary.path, 'performance'))
      ..createSync();
    root = performance.resolveSymbolicLinksSync();
  });
  tearDown(() => temporary.deleteSync(recursive: true));

  runner.ProfileOptions parse(List<String> arguments) =>
      runner.ProfileOptions.parse(arguments, performanceRoot: root);

  test('defaults preserve the benchmark settings and file names', () {
    final options = parse([]);
    expect(options.samples, 30);
    expect(options.textFitting, 'automatic');
    expect(options.maxRegressionPercent, 20);
    expect(options.output, p.join(root, 'build/profile/macos.json'));
    expect(options.log, p.join(root, 'build/profile/macos.log'));
    expect(options.response,
        p.join(root, 'build/profile/macos.integration-response.json'));
  });
  test('linear compact mode remains available for before/after measurements',
      () {
    expect(parse(['--text-fitting', 'linear-compact']).textFitting,
        'linear-compact');
  });
  test('invalid options fail before a Flutter process is launched', () {
    for (final arguments in [
      ['--samples', '0'],
      ['--samples', 'bad'],
      ['--samples', '-1'],
      ['--max-regression-percent', '-1'],
      ['--max-regression-percent', 'NaN'],
      ['--max-regression-percent', 'Infinity'],
      ['--unknown'],
      ['extra'],
    ]) {
      expect(() => parse(arguments), throwsFormatException);
    }
  });
  test('baseline cannot be overwritten by output, log or response', () {
    final output = p.join(root, 'current.json');
    for (final baseline in [
      output,
      p.setExtension(output, '.log'),
      p.setExtension(output, '.integration-response.json')
    ]) {
      expect(() => parse(['--output', output, '--baseline', baseline]),
          throwsFormatException);
    }
  });
  test('symlinks cannot hide a baseline/output collision', () {
    final baseline = File(p.join(root, 'baseline.json'))
      ..writeAsStringSync('{}');
    final output = p.join(root, 'current.json');
    Link(p.setExtension(output, '.log')).createSync(baseline.path);
    expect(() => parse(['--output', output, '--baseline', baseline.path]),
        throwsFormatException);
  },
      skip: Platform
          .isWindows); // Windows symlink creation needs extra privileges.
  test('a disposable host cannot overwrite source directories or their parents',
      () {
    for (final host in [root, p.join(root, 'host'), p.dirname(root)]) {
      expect(() => parse(['--host-directory', host]), throwsFormatException);
    }
  });
  test('unknown nonempty host directories are protected', () {
    final host = Directory(p.join(temporary.path, 'other'))..createSync();
    File(p.join(host.path, 'pubspec.yaml'))
        .writeAsStringSync('name: other_app\n');
    expect(() => parse(['--host-directory', host.path]), throwsFormatException);
    File(p.join(host.path, 'pubspec.yaml'))
        .writeAsStringSync('name: flow_profile_host\n');
    expect(parse(['--host-directory', host.path]).host,
        host.resolveSymbolicLinksSync());
  });
}
