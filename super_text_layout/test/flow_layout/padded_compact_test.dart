import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_text_layout/experimental_flow.dart';
import 'support/reference_paragraph.dart';

const _style = TextStyle(
    fontFamily: kIsWeb ? 'FlowDemo' : 'PaddedCompact',
    fontSize: 20,
    color: Colors.black);

void main() {
  setUpAll(() async {
    if (kIsWeb) return;
    await (FontLoader('PaddedCompact')
          ..addFont(rootBundle
              .load('packages/flow_layout_test_fonts/Roboto-Regular.ttf')))
        .load();
    await (FontLoader('PaddedCode')
          ..addFont(rootBundle
              .load('packages/flow_layout_test_fonts/FiraMono-Regular.ttf')))
        .load();
  });
  testWidgets(
      'prepared padding preserves nested fragments and interactions across edits',
      (tester) async {
    final normal = FlowLayoutController(), exact = FlowLayoutController();
    var text =
        'office affinity AVATAR To WA final code words with wrapping ' * 3;
    var padding = const EdgeInsets.fromLTRB(7, 3, 11, 5);
    Future<void> show(double width, bool obstacle) async {
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
                      obstacles: obstacle
                          ? [Rect.fromLTWH(width / 3, 0, width / 4, 65)]
                          : []),
                  children: [
                    const FlowText('prefix ', id: 'prefix'),
                    FlowDecoration(
                        id: 'outer',
                        padding: padding,
                        radius: 9,
                        child: FlowSequence(children: [
                          const FlowText('fi', id: 'head'),
                          FlowDecoration(
                              id: 'inner',
                              padding: const EdgeInsets.fromLTRB(2, 1, 4, 2),
                              child: FlowSequence(children: [
                                FlowText(text, id: 'code'),
                                const FlowText(' finish ',
                                    id: 'suffix',
                                    style: TextStyle(color: Colors.blue)),
                              ])),
                          const FlowBox(
                              id: 'box',
                              child: SizedBox(width: 15, height: 32)),
                          const FlowText('tail words', id: 'tail'),
                        ])),
                    const FlowText(' after', id: 'after'),
                  ])),
      ]))));
      expect(tester.takeException(), isNull);
      _compare(normal.layout!, exact.layout!,
          ['prefix', 'head', 'code', 'suffix', 'tail', 'after']);
    }

    for (final edit in ['initial', 'beginning', 'middle', 'end']) {
      if (edit != 'initial') {
        final at = edit == 'beginning'
            ? 0
            : edit == 'middle'
                ? text.length ~/ 2
                : text.length;
        text = text.replaceRange(at, at, 'changed');
      }
      for (final width in [45.0, 100.0, 240.0, 360.0]) {
        await show(width, false);
        await show(width, true);
      }
    }
    final render = tester
        .renderObject<RenderFlowParagraph>(find.byKey(const ValueKey(false)));
    expect(render.debugCompactRejections, greaterThan(0));
    padding = const EdgeInsets.fromLTRB(12, 1, 3, 8);
    await show(170, false);
    await tester.pumpWidget(const SizedBox());
    normal.dispose();
    exact.dispose();
  });
  testWidgets(
      'padding preserves emergency breaks overflow empty owners and fallback',
      (tester) async {
    final normal = FlowLayoutController(), exact = FlowLayoutController();
    for (final text in [
      'W' * 90,
      'ordinary words ' * 8,
      '',
      'protected\u00a0words',
      'line\nbreak'
    ]) {
      for (final spacing in [0.0, -5.0]) {
        for (final width in [12.0, 45.0, 180.0]) {
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
                      children: [
                        FlowDecoration(
                            id: 'decoration',
                            padding: const EdgeInsets.fromLTRB(16, 2, 23, 4),
                            child: FlowText(text,
                                id: 'text',
                                style: TextStyle(letterSpacing: spacing))),
                        if (text.isEmpty) const FlowText('', id: 'empty'),
                      ])),
          ]))));
          expect(tester.takeException(), isNull);
          _compare(normal.layout!, exact.layout!, ['text', 'empty']);
          if (spacing < 0 || text.contains('\u00a0') || text.contains('\n')) {
            final render = tester.renderObject<RenderFlowParagraph>(
                find.byKey(const ValueKey(false)));
            expect(render.debugCompactRejections, 0);
          }
          await tester.pumpWidget(const SizedBox());
        }
      }
    }
    normal.dispose();
    exact.dispose();
  });

  testWidgets(
      'intrinsic numeric preparation matches exact geometry across fonts and spacing',
      (tester) async {
    final normal = FlowLayoutController(), exact = FlowLayoutController();
    const text = ' office  affinity AVATAR 0123456789  a b   ';
    for (final font in [
      _style.fontFamily!,
      kIsWeb ? 'FlowCode' : 'PaddedCode'
    ]) {
      for (final size in [12.0, 21.0, 45.0]) {
        for (final spacing in [0.0, 1.5]) {
          final style = _style.copyWith(
              fontFamily: font,
              fontSize: size,
              letterSpacing: spacing,
              wordSpacing: spacing,
              height: 1.25,
              leadingDistribution: TextLeadingDistribution.even,
              locale: const Locale('en'),
              fontFamilyFallback: [_style.fontFamily!]);
          for (final padded in [false, true]) {
            for (final width in [75.0, 240.0]) {
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
                          style: style,
                          children: [
                            FlowDecoration(
                                id: 'decoration',
                                padding: padded
                                    ? const EdgeInsets.fromLTRB(3, 2, 5, 4)
                                    : EdgeInsets.zero,
                                child: FlowText(text * 4, id: 'text'))
                          ])),
              ]))));
              expect(tester.takeException(), isNull);
              _compare(normal.layout!, exact.layout!, ['text']);
            }
          }
          await tester.pumpWidget(const SizedBox());
        }
      }
    }
    normal.dispose();
    exact.dispose();
  });
}

void _compare(
    FlowLayoutSnapshot actual, FlowLayoutSnapshot reference, List<String> ids) {
  expect(actual.size, reference.size);
  expect(actual.lineRetries, reference.lineRetries);
  expect(
      actual.fragments
          .map((f) => (f.participant, f.range, f.bounds, f.line, f.baseline)),
      orderedEquals(reference.fragments
          .map((f) => (f.participant, f.range, f.bounds, f.line, f.baseline))));
  for (final id in ids) {
    for (final fragment in actual.fragmentsFor(id)) {
      for (final offset in [fragment.range.start, fragment.range.end]) {
        for (final affinity in TextAffinity.values) {
          final position = FlowPosition(id, offset, affinity: affinity);
          expect(actual.caretFor(position), reference.caretFor(position));
        }
      }
      for (final point in [
        fragment.bounds.center,
        fragment.bounds.topLeft,
        fragment.bounds.bottomRight
      ]) {
        expect(actual.positionNearestTo(point),
            reference.positionNearestTo(point));
      }
      final selection = FlowSelection(FlowPosition(id, fragment.range.start),
          FlowPosition(id, fragment.range.end));
      expect(actual.boxesForSelection(selection),
          reference.boxesForSelection(selection));
    }
  }
}
