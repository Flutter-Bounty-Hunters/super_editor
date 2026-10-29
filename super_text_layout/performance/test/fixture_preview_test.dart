import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:performance/fixtures/profile_fixture_data.dart';
import 'package:performance/fixtures/profile_fixture_widgets.dart';
import 'package:super_text_layout/experimental_flow.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font in [
      ('FlowBenchmark', 'Roboto-Regular.ttf'),
      ('FlowBenchmarkCode', 'FiraMono-Regular.ttf')
    ]) {
      await (FontLoader(font.$1)
            ..addFont(rootBundle.load('assets/fonts/${font.$2}')))
          .load();
    }
  });
  testWidgets(
      'dark preview paint and visible box outlines preserve benchmark geometry',
      (tester) async {
    final original = FlowLayoutController(), preview = FlowLayoutController();
    for (final scenario in profileFixtureMetadata.keys) {
      for (final width in [600.0, 320.0]) {
        final metadata = profileFixtureMetadata[scenario]!;
        await tester.pumpWidget(MaterialApp(
            home: SingleChildScrollView(
                child: Column(children: [
          for (final dark in [false, true])
            Theme(
                data: ThemeData(
                    fontFamily: 'FlowBenchmark',
                    brightness: dark ? Brightness.dark : Brightness.light,
                    useMaterial3: true),
                child: DefaultTextStyle(
                    style: TextStyle(
                        fontFamily: 'FlowBenchmark',
                        fontSize: (metadata['fontSize'] as num).toDouble(),
                        color: dark ? Colors.white : Colors.black),
                    child: SizedBox(
                        width: width,
                        child: FlowParagraph(
                          controller: dark ? preview : original,
                          style: TextStyle(
                              fontFamily: 'FlowBenchmark',
                              fontSize:
                                  (metadata['fontSize'] as num).toDouble(),
                              color: dark ? Colors.white : Colors.black),
                          regions: RectangularFlowRegions(
                              obstacles: metadata['obstacle'] == true
                                  ? [profileObstacle]
                                  : []),
                          children: buildProfileFixture(scenario,
                              colors: dark
                                  ? const ProfileFixtureColors(
                                      decoration: Color(0xFF26332E),
                                      code: Color(0xFF91D9BB),
                                      boxFill: Color(0x1354DCA0),
                                      boxBorder: Color(0x6654DCA0))
                                  : null),
                        )))),
        ]))));
        expect(tester.takeException(), isNull);
        expect(preview.layout!.size, original.layout!.size,
            reason: '$scenario at $width');
        expect(
            preview.layout!.fragments
                .map((f) => (f.range, f.bounds, f.line, f.baseline)),
            orderedEquals(original.layout!.fragments
                .map((f) => (f.range, f.bounds, f.line, f.baseline))),
            reason: '$scenario at $width');
      }
    }
    await tester.pumpWidget(const SizedBox());
    original.dispose();
    preview.dispose();
  });
}
