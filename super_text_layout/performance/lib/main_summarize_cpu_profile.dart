// Command-line profile reporting; output is intentionally printed.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'profiling/cpu_profile_summary.dart';

void main(List<String> args) {
  if (args.length != 2) {
    throw ArgumentError(
        'Usage: main_summarize_cpu_profile.dart CAPTURE_JSON SUMMARY_JSON');
  }
  final report = summarizeLayoutCpu(
      jsonDecode(File(args[0]).readAsStringSync()) as Map<String, dynamic>);
  final output = File(args[1]);
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(report)}\n');
  for (final dynamic phase in report['phases'] as List<dynamic>) {
    print(
        '${phase['phase']}: ${phase['sampleCount']} samples; ${phase['exclusiveBuckets']}; missing ${phase['layoutsWithoutSamples']} layouts');
  }
}
