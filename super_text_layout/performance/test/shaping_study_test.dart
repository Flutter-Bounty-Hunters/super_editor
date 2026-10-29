import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:performance/checkpoints/shaping_study.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('shaping study records contexts and keeps controls exact', () async {
    final report = await runShapingStudy();
    final file = File('build/profile/shaping-context-debug.json');
    await file.parent.create(recursive: true);
    await file
        .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    final results = report['results']! as List<Map<String, Object>>;
    expect(results, hasLength(19));
    for (final name in ['latin_control', 'mono_control']) {
      final item = results.singleWhere((r) => r['name'] == name);
      for (final context in item['contexts']! as List<Map<String, Object>>) {
        expect(context['rangeFailures'], 0);
        expect(context['breakFailures'], 0);
      }
    }
    for (final item in results.where((r) => !r.containsKey('skipped'))) {
      expect(item['contexts'], hasLength(4));
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
