import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:performance/checkpoints/prepared_text_benchmark.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('prepared text checkpoint records accuracy and separate timings',
      (tester) async {
    expect(kProfileMode, isTrue);
    await tester.pumpWidget(const SizedBox());
    await loadCheckpointFonts(prefix: 'packages/performance/');
    final report = runPreparedTextCheckpoint(
        samples: const int.fromEnvironment('PREPARED_TEXT_CHECKPOINT_SAMPLES',
            defaultValue: 3));
    binding.reportData = {'checkpoint': report};
    // Preserve diagnostics before enforcing the checkpoint accuracy contract.
    expect(report['results'], hasLength(10));
    for (final result in report['results']! as List<Map<String, Object>>) {
      expect((result['ordinaryRangeAudit']! as Map<String, Object>)['failures'],
          0);
      expect(result['hotPathMeasurementCalls'], 0);
      expect(result['breakFailures'], 0);
      expect(result['geometryFailures'], 0);
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
