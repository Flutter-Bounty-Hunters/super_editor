import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:performance/checkpoints/shaping_study.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('shaping context study records native findings', (tester) async {
    expect(kProfileMode, isTrue);
    await tester.pumpWidget(const SizedBox());
    final report = await runShapingStudy(assetPrefix: 'packages/performance/');
    binding.reportData = {'checkpoint': report};
    final results = report['results']! as List<Map<String, Object>>;
    expect(results, hasLength(19));
    for (final name in ['latin_control', 'mono_control']) {
      final item = results.singleWhere((r) => r['name'] == name);
      for (final context in item['contexts']! as List<Map<String, Object>>) {
        expect(context['rangeFailures'], 0);
        expect(context['breakFailures'], 0);
      }
    }
    // Other cases are research findings, including mismatches and missing fonts.
  }, timeout: const Timeout(Duration(minutes: 3)));
}
