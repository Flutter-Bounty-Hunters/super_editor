import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_text_layout/experimental_flow.dart';
import 'package:flow_layout_prototype/flow_palette.dart';

const style =
    TextStyle(fontFamily: 'FlowTest', fontSize: 20, color: Colors.black);

Future<void> mount(
    WidgetTester tester, FlowLayoutController controller, List<Widget> children,
    {double width = 240,
    FlowRegionProvider? regions,
    FlowLayerPainter? foreground}) async {
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: Align(
    alignment: Alignment.topLeft,
    child: DefaultTextStyle(
        style: style,
        child: SizedBox(
            width: width,
            child: FlowParagraph(
                controller: controller,
                style: style,
                regions: regions,
                foregroundPainter: foreground,
                children: children))),
  ))));
  expect(tester.takeException(), isNull);
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('FlowTest')
      ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    await loader.load();
  });
  testWidgets(
      'inline code clones padding across fragments; following text uses the last line',
      (tester) async {
    final controller = FlowLayoutController();
    await mount(tester, controller, const [
      FlowText('Hi ', id: 'intro'),
      FlowDecoration(
          id: 'code',
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: FlowText('alpha beta gamma delta epsilon', id: 'code-text')),
      FlowText(' end', id: 'outro'),
    ]);
    final layout = controller.layout!;
    final code = layout.fragmentsFor('code');
    final content = layout.fragmentsFor('code-text');
    expect(code.length, greaterThan(1));
    expect(code.first.bounds.left, greaterThan(0));
    for (final fragment in content) {
      final decoration = code.firstWhere((d) => d.line == fragment.line);
      expect(decoration.bounds.left, closeTo(fragment.bounds.left - 8, .01));
      expect(decoration.bounds.right, closeTo(fragment.bounds.right + 8, .01));
    }
    expect(layout.fragmentsFor('outro').first.line, code.last.line);
  });

  testWidgets('text uses both sides of an obstacle on one line',
      (tester) async {
    final controller = FlowLayoutController();
    const obstacle = Rect.fromLTWH(100, 0, 60, 60);
    await mount(
        tester,
        controller,
        const [
          FlowText('alpha beta gamma delta epsilon zeta eta theta', id: 'text')
        ],
        width: 280,
        regions: RectangularFlowRegions(obstacles: [obstacle]));
    final layout = controller.layout!;
    expect(layout.lines.first.segments.length, 2);
    final firstLine =
        layout.fragmentsFor('text').where((f) => f.line == 0).toList();
    expect(firstLine.any((f) => f.bounds.right <= obstacle.left), isTrue);
    expect(firstLine.any((f) => f.bounds.left >= obstacle.right), isTrue);
    for (final fragment in layout.fragmentsFor('text')) {
      expect(fragment.bounds.overlaps(obstacle), isFalse);
    }
  });

  testWidgets('tall inline box retries regions using the full line height',
      (tester) async {
    final controller = FlowLayoutController();
    const obstacle = Rect.fromLTWH(60, 30, 70, 60);
    await mount(
        tester,
        controller,
        const [
          FlowBox(id: 'tall', child: SizedBox(width: 50, height: 80)),
          FlowText(' alpha beta gamma delta', id: 'text'),
        ],
        width: 200,
        regions: RectangularFlowRegions(obstacles: [obstacle]));
    final layout = controller.layout!;
    expect(layout.lineRetries, greaterThan(0));
    for (final fragment in layout.fragments) {
      expect(fragment.bounds.overlaps(obstacle), isFalse);
    }
    expect(layout.fragmentsFor('tall').single.bounds.height, 80);
  });

  testWidgets('full-width obstacle advances without looping', (tester) async {
    final controller = FlowLayoutController();
    await mount(tester, controller, const [FlowText('hello', id: 'text')],
        regions: RectangularFlowRegions(
            obstacles: [const Rect.fromLTWH(0, 0, 240, 75)]));
    expect(controller.layout!.lines.first.top, 75);
  });

  testWidgets(
      'counter state, child transforms, and pointer interaction survive resizing',
      (tester) async {
    final controller = FlowLayoutController();
    const children = [
      FlowText('before '),
      FlowSequence(children: [
        FlowBox(child: _Counter(key: ValueKey('counter'))),
        FlowBox(child: SizedBox(width: 70, height: 30)),
      ]),
      FlowText(' after'),
    ];
    await mount(tester, controller, children, width: 350);
    final state = tester.state(find.byType(_Counter));
    await tester.tap(find.text('Count 0'));
    await tester.pump();
    expect(find.text('Count 1'), findsOneWidget);
    await mount(tester, controller, children, width: 150);
    expect(identical(tester.state(find.byType(_Counter)), state), isTrue);
    await tester.tap(find.text('Count 1'));
    await tester.pump();
    expect(find.text('Count 2'), findsOneWidget);
  });

  testWidgets('decoration-only text boundaries share shaping and word wrapping',
      (tester) async {
    final controller = FlowLayoutController();
    await mount(tester, controller, const [
      FlowText('of', id: 'a'),
      FlowDecoration(id: 'highlight', child: FlowText('fi', id: 'b')),
      FlowText('ce', id: 'c'),
    ]);
    final expected = TextPainter(
        text: const TextSpan(text: 'office', style: style),
        textDirection: TextDirection.ltr)
      ..layout();
    final layout = controller.layout!;
    final box = layout.boxesForSelection(
        const FlowSelection(FlowPosition('a', 0), FlowPosition('c', 2)));
    final expectedBox = expected.getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: 6));
    expect(box.length, expectedBox.length);
    expect(box.single.width,
        closeTo(expectedBox.single.right - expectedBox.single.left, .01));
    expect(layout.lines.length, 1);
    expected.dispose();
  });

  testWidgets(
      'local selection crosses participants; outside painters own visuals',
      (tester) async {
    final controller = FlowLayoutController();
    var paints = 0;
    await mount(tester, controller, const [
      FlowText('hello ', id: 'a'),
      FlowText('world', id: 'b')
    ], foreground: (canvas, layout) {
      paints++;
    });
    final layout = controller.layout!;
    final boxes = layout.boxesForSelection(
        const FlowSelection(FlowPosition('a', 3), FlowPosition('b', 3)));
    expect(boxes, isNotEmpty);
    final caret = layout.caretFor(const FlowPosition('b', 2))!;
    expect(layout.positionNearestTo(caret.center), const FlowPosition('b', 2));
    final before = paints;
    controller.selection =
        const FlowSelection(FlowPosition('a', 0), FlowPosition('b', 5));
    await tester.pump();
    expect(paints, greaterThan(before));
    expect(identical(controller.layout, layout), isTrue,
        reason: 'selection changes repaint without layout');
  });

  testWidgets('selecting a visual line end keeps the caret on that line',
      (tester) async {
    final controller = FlowLayoutController();
    await mount(
        tester,
        controller,
        const [
          FlowText('alpha beta gamma delta\n\nnext', id: 'text'),
        ],
        width: 120);
    final layout = controller.layout!;
    final first = layout.fragmentsFor('text').first;
    final endpoint = layout
        .positionNearestTo(Offset(first.bounds.right, first.bounds.center.dy))!;
    expect(endpoint.offset, first.range.end);
    final caret = layout.caretFor(endpoint)!;
    expect(caret.center.dy,
        inInclusiveRange(first.bounds.top, first.bounds.bottom));
    expect(caret.left, closeTo(first.bounds.right, .01));
    final next =
        layout.fragmentsFor('text').firstWhere((f) => f.line == first.line + 1);
    final nextEndpoint = layout
        .positionNearestTo(Offset(next.bounds.left, next.bounds.center.dy))!;
    expect(nextEndpoint.offset, endpoint.offset);
    expect(layout.caretFor(nextEndpoint)!.center.dy,
        inInclusiveRange(next.bounds.top, next.bounds.bottom));
  });

  testWidgets(
      'caret stays before an explicit newline followed by an empty line',
      (tester) async {
    final controller = FlowLayoutController();
    await mount(
        tester, controller, const [FlowText('alpha\n\nnext', id: 'text')]);
    final layout = controller.layout!;
    final first = layout.fragmentsFor('text').first;
    final endpoint = layout
        .positionNearestTo(Offset(first.bounds.right, first.bounds.center.dy))!;
    expect(endpoint.offset, 5);
    expect(layout.caretFor(endpoint)!.center.dy,
        inInclusiveRange(first.bounds.top, first.bounds.bottom));
  });

  testWidgets('dragging vertically into a blank line moves the caret onto it',
      (tester) async {
    final controller = FlowLayoutController();
    await mount(
        tester, controller, const [FlowText('alpha\n\nnext', id: 'text')]);
    final layout = controller.layout!;
    expect(layout.lines, hasLength(4));
    final first = layout.fragmentsFor('text').first;
    final x = first.bounds.right + 20;
    final endOfFirst =
        layout.positionNearestTo(Offset(x, first.bounds.center.dy))!;
    expect(endOfFirst.offset, 5);
    final blank = layout.lines[1];
    for (final y in [
      blank.top + .1,
      blank.top + blank.height / 2,
      blank.top + blank.height - .1
    ]) {
      final endpoint = layout.positionNearestTo(Offset(x, y))!;
      expect(endpoint.offset, endOfFirst.offset);
      expect(endpoint.affinity, TextAffinity.downstream);
      expect(endOfFirst.affinity, TextAffinity.upstream);
      final caret = layout.caretFor(endpoint)!;
      expect(caret.center.dy,
          inInclusiveRange(blank.top, blank.top + blank.height));
      expect(caret.left, closeTo(blank.segments.first.left, .01));
    }
    expect(layout.positionNearestTo(Offset(x, first.bounds.center.dy)),
        endOfFirst);
  });

  testWidgets(
      'original empty line stays in place while drag crosses its shared text boundary',
      (tester) async {
    final controller = FlowLayoutController();
    await mount(
        tester, controller, const [FlowText('alpha\nnext', id: 'text')]);
    final layout = controller.layout!;
    // Preserve the prototype's original visual layout: populated line, blank
    // line, populated line. Fixing hit testing must not collapse that space.
    expect(layout.lines, hasLength(3));
    final first = layout.lines[0];
    final blank = layout.lines[1];
    final last = layout.lines[2];
    expect(blank.top, closeTo(first.top + first.height, .01));
    expect(last.top, closeTo(blank.top + blank.height, .01));
    final firstText = layout.fragmentsFor('text').first;
    for (final x in [firstText.bounds.right, 200.0]) {
      final above =
          layout.positionNearestTo(Offset(x, first.top + first.height / 2))!;
      final below =
          layout.positionNearestTo(Offset(x, blank.top + blank.height / 2))!;
      expect(above.offset, 5);
      expect(below.offset, above.offset);
      expect(above.affinity, TextAffinity.upstream);
      expect(below.affinity, TextAffinity.downstream);
      expect(layout.caretFor(above)!.center.dy,
          inInclusiveRange(first.top, first.top + first.height));
      expect(layout.caretFor(below)!.center.dy,
          inInclusiveRange(blank.top, blank.top + blank.height));
      expect(layout.caretFor(below)!.left,
          closeTo(blank.segments.first.left, .01));
    }
  });

  testWidgets(
      'inside and outside caret locations differ without document indices',
      (tester) async {
    final controller = FlowLayoutController();
    await mount(tester, controller, const [
      FlowDecoration(
          id: 'code',
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: FlowText('code', id: 'text')),
    ]);
    final layout = controller.layout!;
    final inside = layout
        .caretFor(const FlowPosition.boundary('code', FlowEdge.insideEnd))!;
    final outside =
        layout.caretFor(const FlowPosition.boundary('code', FlowEdge.after))!;
    expect(outside.left - inside.left, closeTo(12, .01));
    expect(
        layout.positionNearestTo(Offset(outside.left - 1, outside.center.dy)),
        const FlowPosition.boundary('code', FlowEdge.after));
  });

  testWidgets('empty padded code has an insertion location', (tester) async {
    final controller = FlowLayoutController();
    await mount(tester, controller, const [
      FlowDecoration(
          id: 'empty',
          padding: EdgeInsets.all(8),
          child: FlowText('', id: 'text')),
      FlowText('after', id: 'after'),
    ]);
    expect(controller.layout!.fragmentsFor('empty').single.bounds.width, 16);
    expect(
        controller.layout!.caretFor(const FlowPosition('text', 0)), isNotNull);
  });

  testWidgets('wrapping never splits an emoji grapheme', (tester) async {
    final controller = FlowLayoutController();
    const text = 'a👩🏽‍💻b👨‍👩‍👧‍👦c';
    await mount(tester, controller, const [FlowText(text, id: 'text')],
        width: 80);
    final boundaries = <int>{0};
    var offset = 0;
    for (final grapheme in text.characters) {
      offset += grapheme.length;
      boundaries.add(offset);
    }
    for (final fragment in controller.layout!.fragmentsFor('text')) {
      expect(boundaries, contains(fragment.range.start));
      expect(boundaries, contains(fragment.range.end));
    }
  });

  testWidgets(
      'one text semantics node survives fragmentation; ordinary controls retain semantics',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final controller = FlowLayoutController();
    const label = 'alpha beta gamma delta epsilon';
    await mount(
        tester,
        controller,
        const [
          FlowDecoration(
              child:
                  FlowText(label, key: ValueKey('semantic-text'), id: 'text')),
          FlowBox(child: _Counter()),
        ],
        width: 150);
    expect(controller.layout!.fragmentsFor('text').length, greaterThan(1));
    expect(
        tester.getSemantics(find.byKey(const ValueKey('semantic-text'))).label,
        label);
    expect(tester.getSemantics(find.text('Count 0')).label, 'Count 0');
    semantics.dispose();
  });

  testWidgets(
      'independent canvas participant wraps only at its declared group boundaries',
      (tester) async {
    final controller = FlowLayoutController();
    await mount(
        tester,
        controller,
        const [
          FlowText('Hi '),
          FlowDecoration(
              id: 'outer',
              padding: EdgeInsets.all(3),
              child: FlowDecoration(
                  id: 'inner',
                  padding: EdgeInsets.all(2),
                  child: FlowPalette(id: 'palette'))),
          FlowText(' after'),
        ],
        width: 160);
    final layout = controller.layout!;
    final pieces = layout.fragmentsFor('palette');
    expect(pieces, hasLength(12));
    expect(pieces.map((p) => p.line).toSet().length, greaterThan(1));
    for (var group = 0; group < 4; group++) {
      expect(pieces.skip(group * 3).take(3).map((p) => p.line).toSet(),
          hasLength(1));
    }
    final selected = layout.boxesForSelection(const FlowSelection(
        FlowPosition('palette', 3), FlowPosition('palette', 6)));
    expect(selected, hasLength(3));
    final caret = layout.caretFor(const FlowPosition('palette', 4))!;
    expect(layout.positionNearestTo(caret.center),
        const FlowPosition('palette', 4));
    for (final outer in layout.fragmentsFor('outer')) {
      final inner =
          layout.fragmentsFor('inner').singleWhere((p) => p.line == outer.line);
      expect(outer.bounds.left, closeTo(inner.bounds.left - 3, .01));
      expect(outer.bounds.right, closeTo(inner.bounds.right + 3, .01));
    }
  });

  testWidgets(
      'text exposes alternatives and measures a middle range without changing committed fragments',
      (tester) async {
    final controller = FlowLayoutController();
    const key = ValueKey('measured-text');
    await mount(tester, controller,
        const [FlowText('alpha beta gamma', id: 'text', key: key)]);
    final render = tester.renderObject<RenderFlowText>(find.byKey(key));
    final entry = render.content.single;
    final prepared = entry.prepare(FlowPreparationContext(entry, style));
    final ordinary = prepared
        .breaksAfter(0)
        .where((b) => b.kind == FlowBreakKind.ordinary)
        .map((b) => b.offset);
    expect(ordinary, containsAllInOrder([6, 11, 16]));
    final committed = render.fragments;
    final before = controller.layout;
    const constraints =
        FlowFragmentConstraints(availableWidth: 240, maximumWidth: 240);
    final middle =
        prepared.measureRange(const TextRange(start: 6, end: 11), constraints);
    final longer =
        prepared.measureRange(const TextRange(start: 6, end: 16), constraints);
    expect(middle.range, const TextRange(start: 6, end: 11));
    expect(longer.width, greaterThan(middle.width));
    expect(identical(render.fragments, committed), isTrue);
    expect(identical(controller.layout, before), isTrue);
    middle.dispose();
    longer.dispose();
  });

  testWidgets(
      'composer tests nonmonotonic alternatives and commits the exact measured artifact',
      (tester) async {
    final controller = FlowLayoutController();
    final measurements = <_ProbeMeasurement>[];
    final committedDuringMeasure = <int>[];
    const key = ValueKey('probe');
    await mount(
        tester,
        controller,
        [
          _NegotiationProbe(
              key: key,
              measurements: measurements,
              committedDuringMeasure: committedDuringMeasure),
        ],
        width: 100);
    // Range 0..3 is too wide, 0..2 fits, and 0..1 is too wide again.
    // Descending offsets find the furthest fit without assuming additivity;
    // the shorter candidate cannot improve that result and need not be measured.
    expect(measurements.map((m) => m.range), [
      const TextRange(start: 0, end: 3),
      const TextRange(start: 0, end: 2),
      const TextRange(start: 2, end: 3),
    ]);
    expect(committedDuringMeasure.every((count) => count == 0), isTrue);
    final painted = measurements.where((m) => m.painted).toList();
    expect(painted.map((m) => m.range),
        [const TextRange(start: 0, end: 2), const TextRange(start: 2, end: 3)]);
    expect(painted.every((m) => !m.disposed), isTrue);
    expect(
        measurements.where((m) => !m.painted).every((m) => m.disposed), isTrue);
    final render =
        tester.renderObject<_RenderNegotiationProbe>(find.byKey(key));
    final fragments = render.fragments;
    final prepared = render.content.single
        .prepare(FlowPreparationContext(render.content.single, style));
    final extra = prepared.measureRange(const TextRange(start: 1, end: 2),
        const FlowFragmentConstraints(availableWidth: 100, maximumWidth: 100));
    expect(identical(render.fragments, fragments), isTrue);
    extra.dispose();
    await tester.pumpWidget(const SizedBox());
    expect(measurements.every((m) => m.disposed), isTrue);
  });

  testWidgets('furthest fitting candidate skips all shorter measurements',
      (tester) async {
    final controller = FlowLayoutController();
    final measurements = <_ProbeMeasurement>[];
    await mount(
        tester,
        controller,
        [
          _NegotiationProbe(
              measurements: measurements,
              committedDuringMeasure: List<int>.empty(growable: true),
              widths: const {1: 20, 2: 40, 3: 60}),
        ],
        width: 100);
    expect(
        measurements.map((m) => m.range), [const TextRange(start: 0, end: 3)]);
    expect(measurements.single.painted, isTrue);
    expect(measurements.single.disposed, isFalse);
    await tester.pumpWidget(const SizedBox());
    expect(measurements.single.disposed, isTrue);
  });

  testWidgets(
      'a fitting full-width ordinary range prevents emergency wrapping in a remainder',
      (tester) async {
    final controller = FlowLayoutController();
    final measurements = <_ProbeMeasurement>[];
    await mount(
        tester,
        controller,
        [
          const FlowBox(child: SizedBox(width: 50, height: 10)),
          _NegotiationProbe(
              measurements: measurements,
              committedDuringMeasure: List<int>.empty(growable: true),
              widths: const {1: 60, 2: 30, 3: 200},
              emergencyOffsets: const {2}),
        ],
        width: 100);
    final first = controller.layout!.fragmentsFor('probe').first;
    expect(first.line, 1);
    expect(first.range, const TextRange(start: 0, end: 1));
    expect(
        measurements.where((m) => m.range == const TextRange(start: 0, end: 2)),
        isEmpty);
    await tester.pumpWidget(const SizedBox());
    expect(measurements.every((m) => m.disposed), isTrue);
  });

  testWidgets(
      'oversized first ordinary range permits emergency wrapping in a remainder',
      (tester) async {
    final controller = FlowLayoutController();
    final measurements = <_ProbeMeasurement>[];
    await mount(
        tester,
        controller,
        [
          const FlowBox(child: SizedBox(width: 50, height: 10)),
          _NegotiationProbe(
              measurements: measurements,
              committedDuringMeasure: List<int>.empty(growable: true),
              widths: const {1: 120, 2: 30, 3: 200},
              emergencyOffsets: const {2}),
        ],
        width: 100);
    final first = controller.layout!.fragmentsFor('probe').first;
    expect(first.line, 0);
    expect(first.range, const TextRange(start: 0, end: 2));
    expect(measurements.where((m) => m.painted).map((m) => m.range), [
      const TextRange(start: 0, end: 2),
      const TextRange(start: 2, end: 3),
    ]);
    expect(
        measurements.where((m) => !m.painted).every((m) => m.disposed), isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(measurements.every((m) => m.disposed), isTrue);
  });

  testWidgets(
      'ordinary alternatives take priority over later fitting emergencies',
      (tester) async {
    final controller = FlowLayoutController();
    final measurements = <_ProbeMeasurement>[];
    await mount(
        tester,
        controller,
        [
          _NegotiationProbe(
              measurements: measurements,
              committedDuringMeasure: List<int>.empty(growable: true),
              widths: const {1: 60, 2: 30, 3: 200},
              emergencyOffsets: const {2}),
        ],
        width: 100);
    expect(controller.layout!.fragmentsFor('probe').first.range,
        const TextRange(start: 0, end: 1));
    expect(
        measurements.where((m) => m.range == const TextRange(start: 0, end: 2)),
        isEmpty);
  });

  testWidgets('width-rejected candidates never request vertical metrics',
      (tester) async {
    final controller = FlowLayoutController();
    final measurements = <_ProbeMeasurement>[];
    await mount(
        tester,
        controller,
        [
          _NegotiationProbe(
              measurements: measurements,
              committedDuringMeasure: List<int>.empty(growable: true)),
        ],
        width: 100);
    final rejected = measurements.where((m) => m.disposed).toList();
    expect(rejected, isNotEmpty);
    expect(rejected.every((m) => m.ascentReads == 0 && m.descentReads == 0),
        isTrue);
    expect(
        measurements
            .where((m) => m.painted)
            .every((m) => m.ascentReads > 0 && m.descentReads > 0),
        isTrue);
  });

  testWidgets(
      'selected candidates still validate and dispose invalid vertical metrics',
      (tester) async {
    final controller = FlowLayoutController();
    final measurements = <_ProbeMeasurement>[];
    const key = ValueKey('invalid-metrics-probe');
    await mount(
        tester,
        controller,
        [
          _NegotiationProbe(
              key: key,
              measurements: measurements,
              committedDuringMeasure: List<int>.empty(growable: true),
              widths: const {1: 20, 2: 40, 3: 60}),
        ],
        width: 100);
    final committed = measurements.single;
    tester
        .renderObject<_RenderNegotiationProbe>(find.byKey(key))
        .candidateAscent = double.nan;
    final render =
        tester.renderObject<RenderFlowParagraph>(find.byType(FlowParagraph));
    render.update(controller, RectangularFlowRegions(), style, null, null);
    render.layout(const BoxConstraints.tightFor(width: 100));
    expect(tester.takeException(), isA<FlutterError>());
    expect(measurements, hasLength(2));
    expect(measurements.last.ascentReads, greaterThan(0));
    expect(measurements.last.disposed, isTrue);
    expect(committed.disposed, isFalse);
    await tester.pumpWidget(const SizedBox());
    expect(measurements.every((m) => m.disposed), isTrue);
  });

  testWidgets(
      'height requery retains the exact artifact until snapshot replacement',
      (tester) async {
    final controller = FlowLayoutController();
    final measurements = <_ProbeMeasurement>[];
    final regions = _RecordingRegions(RectangularFlowRegions());
    Widget content() => _NegotiationProbe(
        key: const ValueKey('tall-probe'),
        measurements: measurements,
        committedDuringMeasure: List<int>.empty(growable: true),
        widths: const {1: 20, 2: 40, 3: 60},
        candidateAscent: 60,
        candidateDescent: 10);
    await mount(tester, controller, [content()], width: 100, regions: regions);
    expect(measurements, hasLength(1));
    final first = measurements.single;
    expect(first.painted, isTrue);
    expect(first.disposed, isFalse);
    final line = controller.layout!.lines.single;
    expect(line.height, 70);
    expect(line.baseline, 60);
    expect(line.segments.single.height, 70);
    expect(controller.layout!.lineRetries, 1);
    expect(regions.requests, hasLength(2));
    expect(regions.requests.first.height, lessThan(70));
    expect(regions.requests.last.height, 70);
    await mount(tester, controller, [content()], width: 110, regions: regions);
    expect(measurements, hasLength(2));
    expect(first.disposed, isTrue);
    expect(measurements.last.disposed, isFalse);
    await tester.pumpWidget(const SizedBox());
    expect(measurements.every((m) => m.disposed), isTrue);
  });

  testWidgets('unchanged split regions reuse tall padded custom fragments',
      (tester) async {
    final controller = FlowLayoutController();
    final measurements = <_ProbeMeasurement>[];
    final regions = _RecordingRegions(RectangularFlowRegions(
        obstacles: [const Rect.fromLTWH(40, 0, 20, 200)]));
    await mount(
        tester,
        controller,
        [
          FlowDecoration(
              id: 'wrapper',
              padding: const EdgeInsets.all(3),
              child: _NegotiationProbe(
                  measurements: measurements,
                  committedDuringMeasure: List<int>.empty(growable: true),
                  widths: const {1: 20, 2: 30, 3: 60},
                  candidateAscent: 60,
                  candidateDescent: 10)),
        ],
        width: 100,
        regions: regions);
    expect(measurements.map((m) => m.range), [
      const TextRange(start: 0, end: 3),
      const TextRange(start: 0, end: 2),
      const TextRange(start: 2, end: 3),
    ]);
    final layout = controller.layout!;
    expect(layout.lines.single.segments, hasLength(2));
    expect(layout.lines.single.height, 76);
    expect(layout.lines.single.segments.every((r) => r.height == 76), isTrue);
    final fragments = layout.fragmentsFor('probe');
    expect(fragments.map((f) => f.bounds.left), [3, 63]);
    expect(fragments.every((f) => f.bounds.top == 3), isTrue);
    expect(
        layout.boxesForSelection(const FlowSelection(
            FlowPosition('probe', 0), FlowPosition('probe', 3))),
        hasLength(2));
    expect(regions.requests, hasLength(2));
    expect(measurements.first.disposed, isTrue);
    expect(measurements.first.ascentReads, 0);
    expect(measurements.skip(1).every((m) => m.painted && !m.disposed), isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(measurements.every((m) => m.disposed), isTrue);
  });

  testWidgets(
      'height growth into an obstacle discards old widths and recomposes',
      (tester) async {
    final controller = FlowLayoutController();
    final measurements = <_ProbeMeasurement>[];
    final regions = _RecordingRegions(RectangularFlowRegions(
        obstacles: [const Rect.fromLTWH(50, 30, 50, 100)]));
    await mount(
        tester,
        controller,
        [
          _NegotiationProbe(
              measurements: measurements,
              committedDuringMeasure: List<int>.empty(growable: true),
              widths: const {1: 20, 2: 40, 3: 60},
              candidateAscent: 60,
              candidateDescent: 10),
        ],
        width: 100,
        regions: regions);
    expect(measurements.map((m) => m.range), [
      const TextRange(start: 0, end: 3),
      const TextRange(start: 0, end: 3),
      const TextRange(start: 0, end: 2),
      const TextRange(start: 2, end: 3),
    ]);
    expect(measurements.first.constraints.availableWidth, 100);
    expect(measurements[1].constraints.availableWidth, 50);
    expect(measurements.first.ascentReads, greaterThan(0));
    expect(measurements.first.disposed, isTrue);
    expect(measurements.first.painted, isFalse);
    expect(measurements[1].ascentReads, 0);
    final layout = controller.layout!;
    expect(layout.lines, hasLength(2));
    expect(layout.lines.every((l) => l.segments.single.width == 50), isTrue);
    expect(layout.fragmentsFor('probe').map((f) => f.range),
        [const TextRange(start: 0, end: 2), const TextRange(start: 2, end: 3)]);
    expect(regions.requests, hasLength(4));
    await tester.pumpWidget(const SizedBox());
    expect(measurements.every((m) => m.disposed), isTrue);
  });

  testWidgets('height growth that adds a segment remeasures before placement',
      (tester) async {
    final controller = FlowLayoutController();
    final measurements = <_ProbeMeasurement>[];
    final regions = _RecordingRegions(RectangularFlowRegions(
        obstacles: [const Rect.fromLTWH(40, 30, 20, 100)]));
    await mount(
        tester,
        controller,
        [
          _NegotiationProbe(
              measurements: measurements,
              committedDuringMeasure: List<int>.empty(growable: true),
              widths: const {1: 20, 2: 30, 3: 60},
              candidateAscent: 60,
              candidateDescent: 10),
        ],
        width: 100,
        regions: regions);
    expect(controller.layout!.lines, hasLength(1));
    expect(controller.layout!.lines.single.segments, hasLength(2));
    expect(measurements, hasLength(4));
    expect(measurements.first.disposed, isTrue);
    expect(measurements.first.painted, isFalse);
    expect(measurements.where((m) => m.painted).map((m) => m.range),
        [const TextRange(start: 0, end: 2), const TextRange(start: 2, end: 3)]);
    expect(regions.requests, hasLength(2));
    await tester.pumpWidget(const SizedBox());
    expect(measurements.every((m) => m.disposed), isTrue);
  });

  testWidgets('a failed taller-region query disposes proposed artifacts',
      (tester) async {
    final controller = FlowLayoutController();
    final measurements = <_ProbeMeasurement>[];
    await mount(
        tester,
        controller,
        [
          _NegotiationProbe(
              measurements: measurements,
              committedDuringMeasure: List<int>.empty(growable: true),
              widths: const {1: 20, 2: 40, 3: 60},
              candidateAscent: 60,
              candidateDescent: 10),
        ],
        width: 100);
    final committed = measurements.single;
    final render =
        tester.renderObject<RenderFlowParagraph>(find.byType(FlowParagraph));
    render.update(controller, _RejectTallerRegions(), style, null, null);
    render.layout(const BoxConstraints.tightFor(width: 100));
    expect(tester.takeException(), isA<StateError>());
    expect(measurements, hasLength(2));
    expect(measurements.last.disposed, isTrue);
    expect(committed.disposed, isFalse);
    await tester.pumpWidget(const SizedBox());
    expect(measurements.every((m) => m.disposed), isTrue);
  });

  testWidgets(
      'local caret positions retain their owner at a text and box boundary',
      (tester) async {
    final controller = FlowLayoutController();
    await mount(tester, controller, const [
      FlowBox(id: 'box', child: SizedBox(width: 30, height: 70)),
      FlowText('after', id: 'text'),
    ]);
    final layout = controller.layout!;
    final boxCaret = layout.caretFor(const FlowPosition('box', 1))!;
    final textCaret = layout.caretFor(const FlowPosition('text', 0))!;
    expect(boxCaret.left, textCaret.left);
    expect(boxCaret.height, 70);
    expect(textCaret.height, lessThan(30));
    expect(boxCaret.top, lessThan(textCaret.top));
  });

  testWidgets(
      'decorated ordinary widgets report selection through the same measurement contract',
      (tester) async {
    final controller = FlowLayoutController();
    await mount(tester, controller, const [
      FlowDecoration(
          padding: EdgeInsets.all(5),
          child: FlowSequence(children: [
            FlowBox(id: 'box-a', child: SizedBox(width: 25, height: 20)),
            FlowBox(id: 'box-b', child: SizedBox(width: 25, height: 20)),
          ])),
    ]);
    final boxes = controller.layout!.boxesForSelection(const FlowSelection(
        FlowPosition('box-a', 0), FlowPosition('box-b', 1)));
    expect(boxes, hasLength(2));
    expect(boxes.every((b) => b.width == 25), isTrue);
  });

  testWidgets(
      '10k characters and 100 inline widgets make progress through resize and updates',
      (tester) async {
    final controller = FlowLayoutController();
    List<Widget> content(String suffix) => [
          for (var i = 0; i < 100; i++) ...[
            FlowText(
                ('a short sentence with enough spaces to wrap. ' * 3)
                        .substring(0, 100) +
                    (i == 99 ? suffix : ''),
                id: 'text-$i'),
            FlowBox(id: 'box-$i', child: const SizedBox(width: 30, height: 25)),
          ]
        ];
    final measurements = <int>[];
    for (final width in [600.0, 320.0]) {
      await mount(tester, controller, content(''), width: width);
      measurements.add(controller.layout!.layoutDuration.inMicroseconds);
      expect(controller.layout!.fragmentsFor('box-99'), hasLength(1));
      expect(controller.layout!.fragmentsFor('text-99').last.range.end, 100);
    }
    await mount(tester, controller, content('changed'), width: 320);
    measurements.add(controller.layout!.layoutDuration.inMicroseconds);
    expect(controller.layout!.fragmentsFor('text-99').last.range.end, 107);
    // Evidence, not a timing assertion: debug widget tests are not a frame budget.
    debugPrint('FLOW_STRESS layout microseconds: wide=${measurements[0]}, '
        'resize=${measurements[1]}, update=${measurements[2]}');
  });
}

class _Counter extends StatefulWidget {
  const _Counter({super.key});
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;
  @override
  Widget build(BuildContext context) => TextButton(
      onPressed: () => setState(() => count++), child: Text('Count $count'));
}

class _NegotiationProbe extends LeafRenderObjectWidget {
  const _NegotiationProbe(
      {super.key,
      required this.measurements,
      required this.committedDuringMeasure,
      this.widths = const {1: 200, 2: 70, 3: 200},
      this.emergencyOffsets = const {},
      this.candidateAscent = 16,
      this.candidateDescent = 4});
  final List<_ProbeMeasurement> measurements;
  final List<int> committedDuringMeasure;
  final Map<int, double> widths;
  final Set<int> emergencyOffsets;
  final double candidateAscent;
  final double candidateDescent;
  @override
  _RenderNegotiationProbe createRenderObject(BuildContext context) =>
      _RenderNegotiationProbe(measurements, committedDuringMeasure, widths,
          emergencyOffsets, candidateAscent, candidateDescent);
}

class _RenderNegotiationProbe extends RenderFlowParticipant {
  _RenderNegotiationProbe(
      this.measurements,
      this.committedDuringMeasure,
      this.widths,
      this.emergencyOffsets,
      this.candidateAscent,
      this.candidateDescent)
      : super(id: 'probe');
  final Map<int, double> widths;
  final Set<int> emergencyOffsets;
  double candidateAscent;
  final double candidateDescent;
  final List<_ProbeMeasurement> measurements;
  final List<int> committedDuringMeasure;
  @override
  List<FlowContent> get content => [_ProbeContent(this)];
  @override
  void performLayout() {}
  @override
  void paint(PaintingContext context, Offset offset) {}
}

class _ProbeContent extends FlowContent {
  _ProbeContent(_RenderNegotiationProbe owner) : super(owner, 0, 3, const []);
  @override
  FlowPreparedContent prepare(FlowPreparationContext context) =>
      _PreparedProbe(context.content);
}

class _PreparedProbe extends FlowPreparedContent {
  _PreparedProbe(this.entry);
  final FlowContent entry;
  @override
  List<FlowContent> get entries => [entry];
  @override
  Iterable<FlowBreakOpportunity> breaksAfter(int start) sync* {
    for (var end = start + 1; end <= length; end++) {
      final owner = entry.owner as _RenderNegotiationProbe;
      yield FlowBreakOpportunity(end,
          kind: owner.emergencyOffsets.contains(end)
              ? FlowBreakKind.emergency
              : FlowBreakKind.ordinary);
    }
  }

  @override
  FlowRangeMeasurement measureRange(
      TextRange range, FlowFragmentConstraints constraints) {
    final owner = entry.owner as _RenderNegotiationProbe;
    owner.committedDuringMeasure.add(owner.fragments.length);
    final result = _ProbeMeasurement(entry, range, constraints);
    owner.measurements.add(result);
    return result;
  }
}

class _ProbeMeasurement extends FlowRangeMeasurement {
  _ProbeMeasurement(this.entry, this.range, this.constraints);
  final FlowContent entry;
  final FlowFragmentConstraints constraints;
  int ascentReads = 0;
  int descentReads = 0;
  @override
  final TextRange range;
  bool painted = false;
  bool disposed = false;
  @override
  double get width => range.start == 0
      ? (entry.owner as _RenderNegotiationProbe).widths[range.end]!
      : 30;
  @override
  double get ascent {
    ascentReads++;
    return (entry.owner as _RenderNegotiationProbe).candidateAscent;
  }

  @override
  double get descent {
    descentReads++;
    return (entry.owner as _RenderNegotiationProbe).candidateDescent;
  }

  @override
  List<FlowLocalFragment> get fragments =>
      [FlowLocalFragment(entry, range, Rect.fromLTWH(0, 0, width, height))];
  @override
  void paint(Canvas canvas, Offset origin) {
    expect(disposed, isFalse);
    painted = true;
  }

  @override
  List<Rect> boxesForRange(TextRange selection) =>
      selection.start < range.end && selection.end > range.start
          ? [Rect.fromLTWH(0, 0, width, height)]
          : [];
  @override
  Offset caretAt(int offset, TextAffinity affinity, {Object? participant}) =>
      Offset(offset <= range.start ? 0 : width, 0);
  @override
  FlowPosition positionAt(Offset point) =>
      FlowPosition(entry.owner.identity, range.start);
  @override
  void dispose() {
    expect(disposed, isFalse);
    disposed = true;
  }
}

class _RecordingRegions extends FlowRegionProvider {
  _RecordingRegions(this.delegate);
  final FlowRegionProvider delegate;
  final requests = <({double top, double height, double width})>[];
  @override
  FlowLineSpace spaceFor(
      {required double top, required double height, required double width}) {
    requests.add((top: top, height: height, width: width));
    return delegate.spaceFor(top: top, height: height, width: width);
  }
}

class _RejectTallerRegions extends FlowRegionProvider {
  @override
  FlowLineSpace spaceFor(
      {required double top, required double height, required double width}) {
    if (height > 30) {
      throw StateError('Taller region unavailable');
    }
    return FlowLineSpace([Rect.fromLTWH(0, top, width, height)]);
  }
}
