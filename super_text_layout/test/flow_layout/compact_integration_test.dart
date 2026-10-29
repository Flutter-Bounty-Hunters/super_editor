import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_text_layout/experimental_flow.dart';
import 'support/reference_paragraph.dart';

const _style = TextStyle(
    fontFamily: kIsWeb ? 'FlowDemo' : 'CompactIntegration',
    fontSize: 20,
    color: Colors.black);

void main() {
  setUpAll(() async {
    if (kIsWeb) return;
    await (FontLoader('CompactIntegration')
          ..addFont(rootBundle
              .load('packages/flow_layout_test_fonts/Roboto-Regular.ttf')))
        .load();
  });

  testWidgets(
      'integrated compact routing preserves mixed widget, decoration and interaction geometry',
      (tester) async {
    final normal = FlowLayoutController(), exact = FlowLayoutController();
    var negative = false;
    var text = 'office affinity AVATAR To WA final ordinary words ';
    Future<RenderFlowParagraph> show(double width, bool obstacle) async {
      await tester.pumpWidget(MaterialApp(
          home: SingleChildScrollView(
              child: Column(children: [
        for (final reference in [false, true])
          SizedBox(
              width: width,
              child: ReferenceFlowParagraph(
                key: ValueKey(reference),
                exhaustive: reference,
                controller: reference ? exact : normal,
                style: _style,
                regions: RectangularFlowRegions(
                    obstacles:
                        obstacle ? [const Rect.fromLTWH(40, 0, 30, 55)] : []),
                children: [
                  FlowText(text, id: 'a', style: _style),
                  FlowText('Wi WiWi iiiiiii WWW AVATAR ',
                      id: 'b',
                      style: _style.copyWith(letterSpacing: negative ? -5 : 0)),
                  const FlowText('ordinary trailing text that wraps again ',
                      id: 'c', style: _style),
                  const FlowBox(
                      id: 'widget', child: SizedBox(width: 24, height: 28)),
                  const FlowDecoration(
                      id: 'code',
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: FlowText('padded inline code also wraps here',
                          id: 'code-text', style: _style)),
                ],
              )),
      ]))));
      expect(tester.takeException(), isNull);
      final a = normal.layout!, b = exact.layout!;
      expect(a.size, b.size);
      expect(
          a.fragments.map(
              (f) => (f.participant, f.range, f.bounds, f.line, f.baseline)),
          orderedEquals(b.fragments.map(
              (f) => (f.participant, f.range, f.bounds, f.line, f.baseline))));
      for (final id in ['a', 'b', 'c', 'code-text']) {
        final fragments = a.fragmentsFor(id);
        for (final f in fragments) {
          for (final offset in [f.range.start, f.range.end]) {
            expect(a.caretFor(FlowPosition(id, offset)),
                b.caretFor(FlowPosition(id, offset)));
          }
          expect(a.positionNearestTo(f.bounds.center),
              b.positionNearestTo(f.bounds.center));
        }
      }
      const selection =
          FlowSelection(FlowPosition('a', 0), FlowPosition('code-text', 20));
      expect(a.boxesForSelection(selection), b.boxesForSelection(selection));
      return tester
          .renderObject<RenderFlowParagraph>(find.byKey(const ValueKey(false)));
    }

    // The first text group has no padding: the real widget separates it from
    // the decorated group, so this also verifies compact and fallback coexist.
    final render = await show(180, false);
    expect(render.debugCompactRejections, greaterThan(0));
    for (final spacing in [false, true, false]) {
      negative = spacing;
      for (final width in [80.0, 180.0, 320.0]) {
        await show(width, true);
        text = 'changed$text';
        await show(width, false);
      }
    }
    await tester.pumpWidget(const SizedBox());
    normal.dispose();
    exact.dispose();
  });

  testWidgets(
      'mostly repeated short runs keep the existing shape and decision path',
      (tester) async {
    const text = 'ordinary words repeat across these short inline runs ';
    final controller = FlowLayoutController();
    Future<RenderFlowParagraph> show(bool edit) async {
      await tester.pumpWidget(MaterialApp(
          home: SingleChildScrollView(
              child: SizedBox(
                  width: 180,
                  child: FlowParagraph(
                      controller: controller,
                      style: _style,
                      children: [
                        for (var i = 0; i < 20; i++) ...[
                          FlowText(i == 0 && edit ? 'changed$text' : text,
                              style: _style),
                          const FlowBox(child: SizedBox(width: 20, height: 20)),
                        ],
                      ])))));
      expect(tester.takeException(), isNull);
      return tester
          .renderObject<RenderFlowParagraph>(find.byType(FlowParagraph));
    }

    final render = await show(false);
    expect(render.debugCompactBuilds, 0);
    await show(true);
    expect(render.debugCompactBuilds, 0);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('non-inheriting text styles retain exact paragraph semantics',
      (tester) async {
    final a = FlowLayoutController(), b = FlowLayoutController();
    await tester.pumpWidget(MaterialApp(
        home: Column(children: [
      for (final reference in [false, true])
        SizedBox(
            width: 100,
            child: ReferenceFlowParagraph(
                exhaustive: reference,
                controller: reference ? b : a,
                style: _style.copyWith(fontSize: 10),
                children: const [
                  FlowText('ordinary words that wrap across several lines',
                      id: 'text',
                      style: TextStyle(
                          inherit: false,
                          fontFamily:
                              kIsWeb ? 'FlowDemo' : 'CompactIntegration')),
                ])),
    ])));
    expect(tester.takeException(), isNull);
    expect(
        a.layout!.fragments.map((f) => (f.range, f.bounds, f.line)),
        orderedEquals(
            b.layout!.fragments.map((f) => (f.range, f.bounds, f.line))));
    final render = tester.renderObject<RenderFlowParagraph>(
        find.byType(ReferenceFlowParagraph).first);
    expect(render.debugCompactBuilds, 0);
    await tester.pumpWidget(const SizedBox());
    a.dispose();
    b.dispose();
  });

  testWidgets(
      'binary break lookup skips the oversized tail and matches exact geometry',
      (tester) async {
    final normal = FlowLayoutController(), exact = FlowLayoutController();
    final text = List.generate(90, (i) => 'word$i ').join();
    for (final width in [30.0, 80.0, 180.0, 320.0]) {
      await tester.pumpWidget(MaterialApp(
          home: SingleChildScrollView(
              child: Column(children: [
        for (final reference in [false, true])
          SizedBox(
              width: width,
              child: ReferenceFlowParagraph(
                  key: ValueKey(reference),
                  exhaustive: reference,
                  controller: reference ? exact : normal,
                  style: _style,
                  children: [FlowText(text, id: 'text', style: _style)])),
      ]))));
      expect(tester.takeException(), isNull);
      final a = normal.layout!, b = exact.layout!;
      expect(a.fragments.map((f) => (f.range, f.bounds, f.line)),
          orderedEquals(b.fragments.map((f) => (f.range, f.bounds, f.line))));
      expect(a.caretFor(FlowPosition('text', text.length)),
          b.caretFor(FlowPosition('text', text.length)));
      final render = tester
          .renderObject<RenderFlowParagraph>(find.byKey(const ValueKey(false)));
      expect(render.debugCompactBinarySearches, greaterThan(0));
      expect(render.debugCompactBinarySkipped,
          greaterThan(render.debugCompactBinaryProbes));
    }
    final stats = tester
        .renderObject<RenderFlowParagraph>(find.byKey(const ValueKey(false)));
    // ignore: avoid_print
    print(
        'BINARY_SEARCH_STATS searches=${stats.debugCompactBinarySearches} probes=${stats.debugCompactBinaryProbes} skipped=${stats.debugCompactBinarySkipped}');
    await tester.pumpWidget(const SizedBox());
    normal.dispose();
    exact.dispose();
  });

  testWidgets(
      'binary lookup preserves maximum-width inspection in narrow regions',
      (tester) async {
    final normal = FlowLayoutController(), exact = FlowLayoutController();
    final text = List.generate(60, (i) => 'word$i ').join();
    final prefix = text.substring(0, text.indexOf('word6'));
    final painter = TextPainter(
        text: TextSpan(
            style: _style, children: [TextSpan(text: prefix, style: _style)]),
        textDirection: TextDirection.ltr)
      ..layout();
    final maximum = painter.width + .005;
    painter.dispose();
    await tester.pumpWidget(MaterialApp(
        home: SingleChildScrollView(
            child: Column(children: [
      for (final reference in [false, true])
        SizedBox(
            width: maximum,
            child: ReferenceFlowParagraph(
                key: ValueKey(reference),
                exhaustive: reference,
                controller: reference ? exact : normal,
                style: _style,
                regions: RectangularFlowRegions(
                    obstacles: [Rect.fromLTWH(80, 0, maximum - 80, 50)]),
                children: [FlowText(text, id: 'text', style: _style)])),
    ]))));
    expect(tester.takeException(), isNull);
    expect(
        normal.layout!.fragments.map((f) => (f.range, f.bounds, f.line)),
        orderedEquals(
            exact.layout!.fragments.map((f) => (f.range, f.bounds, f.line))));
    final render = tester
        .renderObject<RenderFlowParagraph>(find.byKey(const ValueKey(false)));
    expect(render.debugCompactMaximumGuards, greaterThan(0));
    await tester.pumpWidget(const SizedBox());
    normal.dispose();
    exact.dispose();
  });

  testWidgets('unordered margin-adjusted widths retain linear fitting',
      (tester) async {
    final normal = FlowLayoutController(), exact = FlowLayoutController();
    final tiny =
        _style.copyWith(fontSize: .00001, letterSpacing: 0, wordSpacing: 0);
    final text = List.filled(80, 'tiny words ').join();
    await tester.pumpWidget(MaterialApp(
        home: Column(children: [
      for (final reference in [false, true])
        SizedBox(
            width: 180,
            child: ReferenceFlowParagraph(
                key: ValueKey(reference),
                exhaustive: reference,
                controller: reference ? exact : normal,
                style: tiny,
                children: [FlowText(text, id: 'text', style: tiny)])),
    ])));
    expect(tester.takeException(), isNull);
    expect(normal.layout!.fragments.map((f) => (f.range, f.bounds)),
        orderedEquals(exact.layout!.fragments.map((f) => (f.range, f.bounds))));
    final render = tester
        .renderObject<RenderFlowParagraph>(find.byKey(const ValueKey(false)));
    expect(render.debugCompactUnorderedSearches, greaterThan(0));
    expect(render.debugCompactBinarySearches, 0);
    await tester.pumpWidget(const SizedBox());
    normal.dispose();
    exact.dispose();
  });

  testWidgets(
      'compact data is bounded, invalidates on fonts, and clears on detach',
      (tester) async {
    final controller = FlowLayoutController();
    Future<RenderFlowParagraph> show(int revision) async {
      await tester.pumpWidget(MaterialApp(
          home: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                  width: 180,
                  child: FlowParagraph(
                      controller: controller,
                      style: _style,
                      children: [
                        FlowText(
                            'revision$revision ordinary words with enough spaces to wrap several times',
                            id: 'text',
                            style: _style)
                      ])))));
      expect(tester.takeException(), isNull);
      return tester
          .renderObject<RenderFlowParagraph>(find.byType(FlowParagraph));
    }

    final render = await show(0);
    expect(render.debugCompactRejections, greaterThan(0));
    final before = render.debugCompactBuilds;
    await tester.binding.handleSystemMessage({'type': 'fontsChange'});
    expect(render.debugCompactEntries, 0);
    expect(render.debugCompactMeasurementEntries, 0);
    await tester.pump();
    expect(render.debugCompactBuilds, greaterThan(before));
    for (var i = 1; i <= 270; i++) {
      await show(i);
    }
    expect(render.debugCompactEntries, lessThanOrEqualTo(256));
    expect(render.debugCompactUnits, lessThanOrEqualTo(65536));
    expect(render.debugCompactMeasurementEntries, lessThanOrEqualTo(4096));
    expect(render.debugCompactMeasurementUnits, lessThanOrEqualTo(73728));
    expect(
        controller.layout!.caretFor(const FlowPosition('text', 10)), isNotNull);
    await tester.pumpWidget(const SizedBox());
    expect(render.debugCompactEntries, 0);
    expect(render.debugCompactUnits, 0);
    expect(render.debugCompactMeasurementEntries, 0);
    expect(render.debugCompactMeasurementUnits, 0);
    expect(render.debugTextShapeLive, 0);
    controller.dispose();
  });
}
