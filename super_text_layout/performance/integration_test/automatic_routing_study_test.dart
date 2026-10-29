import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:performance/checkpoints/routing_study.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('automatic routing matches native exact fitting', (tester) async {
    expect(kProfileMode, isTrue);
    await tester.pumpWidget(const SizedBox());
    final report = await runRoutingStudy(assetPrefix: 'packages/performance/');
    binding.reportData = {'checkpoint': report};
    final results = report['results']! as List<Map<String, Object>>;
    expect(results, hasLength(10));
    for (final r in results) {
      expect(r['breakFailures'], 0, reason: '$r');
      expect(r['geometryFailures'], 0, reason: '$r');
    }
    final supported = results.singleWhere((r) => r['fixture'] == 'supported');
    expect(supported['exactCandidates'], 0);
    final fallback =
        results.singleWhere((r) => r['fixture'] == 'negative_only');
    expect(fallback['compactCandidates'], 0);
  });
}
