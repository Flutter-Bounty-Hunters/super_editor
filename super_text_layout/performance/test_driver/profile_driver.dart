import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
      timeout: const Duration(minutes: 6),
      writeResponseOnFailure: true,
      responseDataCallback: (data) async {
        final path = Platform.environment['FLOW_BENCHMARK_OUTPUT'] ??
            'build/profile/integration-response.json';
        final output = File(path);
        await output.parent.create(recursive: true);
        await output
            .writeAsString(const JsonEncoder.withIndent('  ').convert(data));
      },
    );
