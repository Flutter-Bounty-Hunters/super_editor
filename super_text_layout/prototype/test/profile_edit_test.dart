import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flow_layout_prototype/profile_fixture_data.dart';
import 'package:flow_layout_prototype/profile_fixture_widgets.dart';
import 'package:super_text_layout/experimental_flow.dart';

void main() {
  setUpAll(() async {
    if (kIsWeb) return;
    for (final font in [
      ('FlowBenchmark', 'Roboto-Regular.ttf'),
      ('FlowBenchmarkCode', 'FiraMono-Regular.ttf')
    ]) {
      await (FontLoader(font.$1)
            ..addFont(rootBundle.load('assets/fonts/${font.$2}')))
          .load();
    }
  });

  for (final scenario in profileFixtureMetadata.keys) {
    for (final edit in ProfileEdit.values) {
      testWidgets('$scenario ${edit.phase} matches a fresh edited layout',
          (tester) async {
        final warm = FlowLayoutController(), cold = FlowLayoutController();
        final metadata = profileFixtureMetadata[scenario]!;
        final style = TextStyle(
            fontFamily: 'FlowBenchmark',
            fontSize: (metadata['fontSize']! as int).toDouble(),
            color: Colors.black);
        Future<void> show(double width, {ProfileEdit? insertion}) =>
            tester.pumpWidget(MaterialApp(
                theme: ThemeData(fontFamily: 'FlowBenchmark'),
                home: DefaultTextStyle(
                    style: style,
                    child: SingleChildScrollView(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          for (final isWarm in [
                            true,
                            if (insertion != null) false
                          ])
                            SizedBox(
                                width: width,
                                child: FlowParagraph(
                                    key: ValueKey(isWarm),
                                    controller: isWarm ? warm : cold,
                                    style: style,
                                    regions: RectangularFlowRegions(
                                        obstacles: metadata['obstacle'] == true
                                            ? [
                                                const Rect.fromLTWH(
                                                    210, 20, 130, 80)
                                              ]
                                            : []),
                                    children: buildProfileFixture(scenario,
                                        edit: insertion))),
                        ])))));
        await show(600);
        expect(tester.takeException(), isNull);
        final render = tester.renderObject<RenderFlowParagraph>(
            find.byKey(const ValueKey(true)));
        await show(320);
        await show(320, insertion: edit);
        expect(tester.takeException(), isNull);
        expect(
            tester.renderObject<RenderFlowParagraph>(
                find.byKey(const ValueKey(true))),
            same(render));
        final a = warm.layout!, b = cold.layout!;
        expect(a.size, b.size);
        expect(a.lineRetries, b.lineRetries);
        expect(a.lines.map((l) => (l.top, l.height, l.baseline)),
            orderedEquals(b.lines.map((l) => (l.top, l.height, l.baseline))));
        expect(a.lines.map((l) => l.segments).toList(),
            b.lines.map((l) => l.segments).toList());
        // Decorators without explicit IDs have different render identities in
        // these paragraphs. Their ordered geometry must still match exactly.
        expect(
            a.fragments.map((f) => (f.range, f.bounds, f.line, f.baseline)),
            orderedEquals(b.fragments
                .map((f) => (f.range, f.bounds, f.line, f.baseline))));
        final location = profileEditLocation(scenario, edit);
        var id =
            scenario == 'long_prose' ? 'long-text' : 'text-${location.chunk}';
        var offset = location.offset;
        if (scenario == 'decorated_code') {
          if (offset < 12) {
            id += '-head';
          } else if (offset < 76) {
            id += '-body';
            offset -= 12;
          } else {
            id += '-tail';
            offset -= 76;
          }
        }
        final start = FlowPosition(id, offset);
        final end = FlowPosition(id, offset + profileEditText.length);
        expect(a.caretFor(end), isNotNull);
        expect(a.caretFor(end), b.caretFor(end));
        final selection = FlowSelection(start, end);
        expect(a.boxesForSelection(selection), isNotEmpty);
        expect(a.boxesForSelection(selection), b.boxesForSelection(selection));
        await tester.pumpWidget(const SizedBox());
        warm.dispose();
        cold.dispose();
      });
    }
  }
}
