import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_text_layout/experimental_flow.dart';

const _style = TextStyle(
    fontFamily: kIsWeb ? 'FlowDemo' : 'FlowCacheTest',
    fontSize: 20,
    color: Colors.black);
Future<RenderFlowParagraph> mountCache(
    WidgetTester tester, FlowLayoutController controller,
    {double width = 240,
    String end = 'gamma delta',
    String owner = 'b',
    TextStyle style = _style}) async {
  await tester.pumpWidget(MaterialApp(
      home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
              width: width,
              child: FlowParagraph(
                  controller: controller,
                  style: style,
                  children: [
                    const FlowText('alpha beta', id: 'a'),
                    const FlowBox(
                        id: 'separator', child: SizedBox(width: 1, height: 1)),
                    FlowText(end, id: owner),
                  ])))));
  expect(tester.takeException(), isNull);
  return tester.renderObject<RenderFlowParagraph>(find.byType(FlowParagraph));
}

void main() {
  setUpAll(() async {
    if (kIsWeb) return;
    await (FontLoader('FlowCacheTest')
          ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf')))
        .load();
  });
  testWidgets(
      'break cache reuses width-only analysis but retains current owners',
      (tester) async {
    final controller = FlowLayoutController();
    final render = await mountCache(tester, controller);
    expect(render.debugTextAnalysisBuilds, 2);
    await mountCache(tester, controller, width: 130, owner: 'new-owner');
    expect(render.debugTextAnalysisBuilds, 2);
    expect(controller.layout!.fragmentsFor('b'), isEmpty);
    expect(controller.layout!.fragmentsFor('new-owner'), isNotEmpty);
    expect(controller.layout!.caretFor(const FlowPosition('new-owner', 3)),
        isNotNull);
  });
  testWidgets('changed text and paragraph segmentation context miss the cache',
      (tester) async {
    final controller = FlowLayoutController();
    final render = await mountCache(tester, controller);
    await mountCache(tester, controller, end: 'changed phrase');
    expect(render.debugTextAnalysisBuilds, 3);
    await mountCache(tester, controller,
        end: 'changed phrase',
        style: _style.copyWith(locale: const Locale('th'), fontSize: 21));
    expect(render.debugTextAnalysisBuilds, 5);
  });
  testWidgets(
      'font notifications invalidate cached analysis and request layout',
      (tester) async {
    final controller = FlowLayoutController();
    final render = await mountCache(tester, controller);
    await tester.binding.handleSystemMessage({'type': 'fontsChange'});
    await tester.pump();
    expect(render.debugTextAnalysisBuilds, 4);
    expect(tester.takeException(), isNull);
  });
  testWidgets('analysis retention remains bounded with many unique sources',
      (tester) async {
    final controller = FlowLayoutController();
    await tester.pumpWidget(MaterialApp(
        home: SizedBox(
            width: 600,
            child:
                FlowParagraph(controller: controller, style: _style, children: [
              for (var i = 0; i < 270; i++) ...[
                FlowText('source $i ', id: 'source-$i'),
                FlowBox(
                    id: 'box-$i', child: const SizedBox(width: 1, height: 1)),
              ]
            ]))));
    final render =
        tester.renderObject<RenderFlowParagraph>(find.byType(FlowParagraph));
    expect(render.debugTextAnalysisEntries, lessThanOrEqualTo(256));
    expect(controller.layout!.fragmentsFor('source-269'), isNotEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'indexed multi-owner text retains shaping and empty-boundary carets',
      (tester) async {
    final split = FlowLayoutController(), whole = FlowLayoutController();
    await tester.pumpWidget(MaterialApp(
        home: DefaultTextStyle(
            style: _style,
            child: Column(children: [
              SizedBox(
                  width: 95,
                  child: FlowParagraph(
                      controller: split,
                      style: _style,
                      children: const [
                        FlowText('of', id: 'a'),
                        FlowText('', id: 'empty'),
                        FlowText('fice ', id: 'b'),
                        FlowText('alpha ', id: 'c'),
                        FlowText('', id: 'empty2'),
                        FlowText('beta', id: 'd'),
                      ])),
              SizedBox(
                  width: 95,
                  child: FlowParagraph(
                      controller: whole,
                      style: _style,
                      children: const [
                        FlowText('office alpha beta', id: 'whole')
                      ])),
            ]))));
    expect(split.layout!.lines.map((l) => (l.top, l.height, l.baseline)),
        whole.layout!.lines.map((l) => (l.top, l.height, l.baseline)));
    expect(
        split.layout!.boxesForSelection(
            const FlowSelection(FlowPosition('a', 0), FlowPosition('d', 4))),
        whole.layout!.boxesForSelection(const FlowSelection(
            FlowPosition('whole', 0), FlowPosition('whole', 17))));
    expect(split.layout!.caretFor(const FlowPosition('empty', 0)),
        whole.layout!.caretFor(const FlowPosition('whole', 2)));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'indexed endpoints reject CRLF and emoji interiors and required-break crossings',
      (tester) async {
    final controller = FlowLayoutController();
    const key = ValueKey('indexed-source');
    const text = 'alpha beta\r\n\nco\u00adoperate 👩🏽‍💻 end';
    await tester.pumpWidget(MaterialApp(
        home: SizedBox(
            width: 300,
            child: FlowParagraph(
                controller: controller,
                style: _style,
                children: const [FlowText(text, id: 'source', key: key)]))));
    final entry =
        tester.renderObject<RenderFlowText>(find.byKey(key)).content.single;
    final prepared = entry.prepare(FlowPreparationContext(entry, _style));
    const constraints =
        FlowFragmentConstraints(availableWidth: 300, maximumWidth: 300);
    expect(
        () => prepared.measureRange(
            const TextRange(start: 0, end: 11), constraints),
        throwsArgumentError);
    expect(
        () => prepared.measureRange(
            const TextRange(start: 0, end: text.length), constraints),
        throwsArgumentError);
    final emoji = text.indexOf('👩');
    expect(
        () => prepared.measureRange(
            TextRange(start: emoji, end: emoji + 1), constraints),
        throwsArgumentError);
    var start = 0;
    while (start < text.length) {
      final opportunities = prepared.breaksAfter(start).toList();
      expect(opportunities, isNotEmpty);
      for (final opportunity in opportunities) {
        prepared
            .measureRange(
                TextRange(start: start, end: opportunity.offset), constraints)
            .dispose();
      }
      start = opportunities.last.offset;
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'padded exact-range metrics remain correct after width-only measurement',
      (tester) async {
    final controller = FlowLayoutController();
    const key = ValueKey('metric-wrapper');
    await tester.pumpWidget(MaterialApp(
        home: DefaultTextStyle(
            style: _style,
            child: FlowParagraph(
                controller: controller,
                style: _style,
                children: const [
                  FlowDecoration(
                      key: key,
                      padding: EdgeInsets.fromLTRB(6, 4, 8, 5),
                      child: FlowDecoration(
                          padding: EdgeInsets.fromLTRB(2, 3, 4, 7),
                          child: FlowText('office', id: 'code'))),
                ]))));
    final entry = tester
        .renderObject<RenderFlowDecoration>(find.byKey(key))
        .content
        .single;
    final prepared = entry.prepare(FlowPreparationContext(entry, _style));
    final expected = TextPainter(
        text: const TextSpan(text: 'office', style: _style),
        textDirection: TextDirection.ltr)
      ..layout();
    final measured = prepared.measureRange(const TextRange(start: 0, end: 6),
        const FlowFragmentConstraints(availableWidth: 300, maximumWidth: 300));
    expect(measured.width, closeTo(expected.width + 20, .01));
    final baseline = expected.computeLineMetrics().first.baseline;
    expect(measured.ascent, closeTo(baseline + 7, .01));
    expect(measured.descent, closeTo(expected.height - baseline + 12, .01));
    expect(measured.height, closeTo(expected.height + 19, .01));
    expect(measured.caretAt(0, TextAffinity.downstream).dx, 8);
    measured.dispose();
    expected.dispose();
    expect(tester.takeException(), isNull);
  });
  testWidgets('shared exact shapes retain separate owners and reference counts',
      (tester) async {
    final controller = FlowLayoutController();
    Future<void> show() => tester.pumpWidget(MaterialApp(
        home: DefaultTextStyle(
            style: _style,
            child: SizedBox(
                width: 400,
                child: FlowParagraph(
                    controller: controller,
                    style: _style,
                    children: const [
                      FlowText('office', id: 'one'),
                      FlowBox(child: SizedBox(width: 1, height: 1)),
                      FlowText('office', id: 'two'),
                    ])))));
    await show();
    final render =
        tester.renderObject<RenderFlowParagraph>(find.byType(FlowParagraph));
    expect(render.debugTextShapeBuilds, 1);
    expect(render.debugTextShapeHits, 1);
    expect(render.debugTextShapeLive, 1);
    final a = controller.layout!.caretFor(const FlowPosition('one', 0))!;
    final b = controller.layout!.caretFor(const FlowPosition('two', 0))!;
    expect(b.left, greaterThan(a.left));
    expect(controller.layout!.positionNearestTo(b.center)!.participant, 'two');
    await show();
    expect(render.debugTextShapeLive,
        1); // Previous snapshot released both leases.
    await tester.pumpWidget(const SizedBox());
    expect(render.debugTextShapeLive, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'evicting live shapes preserves committed text and releases on unmount',
      (tester) async {
    final controller = FlowLayoutController();
    await tester.pumpWidget(MaterialApp(
        home: DefaultTextStyle(
            style: _style,
            child: SizedBox(
                width: 400,
                child: FlowParagraph(
                    controller: controller,
                    style: _style,
                    children: [
                      for (var i = 0; i < 400; i++) ...[
                        FlowDecoration(
                            padding: const EdgeInsets.all(1),
                            child: FlowText('item$i', id: 'item-$i')),
                        const FlowBox(child: SizedBox(width: 1, height: 1)),
                      ]
                    ])))));
    final render =
        tester.renderObject<RenderFlowParagraph>(find.byType(FlowParagraph));
    expect(render.debugTextShapePeakEntries, lessThanOrEqualTo(256));
    expect(render.debugTextShapeLive, 400);
    expect(controller.layout!.caretFor(const FlowPosition('item-0', 0)),
        isNotNull);
    expect(controller.layout!.caretFor(const FlowPosition('item-399', 7)),
        isNotNull);
    await tester.pumpWidget(const SizedBox());
    expect(render.debugTextShapeLive, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('plain source path matches compound shaping and control geometry',
      (tester) async {
    for (final text in [
      '',
      'alpha office words wrap here',
      'a\r\nb\n\nc',
      'a soft\u00adhyphenated word',
      'a e\u0301 😀 words'
    ]) {
      final split = text.isEmpty ? 0 : 1;
      for (final width in [70.0, 240.0]) {
        final plain = FlowLayoutController(), compound = FlowLayoutController();
        await tester.pumpWidget(MaterialApp(
            home: DefaultTextStyle(
                style: _style,
                child: Column(children: [
                  SizedBox(
                      width: width,
                      child: FlowParagraph(
                          controller: plain,
                          style: _style,
                          children: [FlowText(text, id: 'plain')])),
                  SizedBox(
                      width: width,
                      child: FlowParagraph(
                          controller: compound,
                          style: _style,
                          children: [
                            FlowText(text.substring(0, split), id: 'a'),
                            FlowText(text.substring(split), id: 'b')
                          ])),
                ]))));
        final a = plain.layout!, b = compound.layout!;
        expect(b.size, a.size);
        expect(b.lines.map((l) => (l.top, l.height, l.baseline)),
            orderedEquals(a.lines.map((l) => (l.top, l.height, l.baseline))));
        for (var offset = 0; offset <= text.length; offset++) {
          // CRLF is an indivisible control; its interior is not a caret site.
          if (offset > 0 &&
              offset < text.length &&
              text.codeUnitAt(offset - 1) == 13 &&
              text.codeUnitAt(offset) == 10) {
            continue;
          }
          for (final affinity in TextAffinity.values) {
            final owner = offset <= split ? 'a' : 'b';
            expect(
                b.caretFor(FlowPosition(
                    owner, offset <= split ? offset : offset - split,
                    affinity: affinity)),
                a.caretFor(FlowPosition('plain', offset, affinity: affinity)),
                reason:
                    'text=$text width=$width offset=$offset affinity=$affinity');
          }
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    }
  });
  testWidgets('retained choices use current owners and remain bounded',
      (tester) async {
    final controller = FlowLayoutController();
    final render = await mountCache(tester, controller);
    await mountCache(tester, controller, owner: 'new-owner');
    expect(render.debugTextChoiceHits, greaterThan(0));
    expect(controller.layout!.fragmentsFor('b'), isEmpty);
    expect(controller.layout!.caretFor(const FlowPosition('new-owner', 2)),
        isNotNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(
        home: DefaultTextStyle(
            style: _style,
            child: SizedBox(
                width: 600,
                child: FlowParagraph(
                    controller: controller,
                    style: _style,
                    children: [
                      for (var i = 0; i < 1200; i++) ...[
                        FlowText('word$i', id: 'word-$i'),
                        const FlowBox(child: SizedBox(width: 5, height: 5)),
                      ]
                    ])))));
    final many =
        tester.renderObject<RenderFlowParagraph>(find.byType(FlowParagraph));
    expect(many.debugTextChoiceEntries, 1024);
    expect(controller.layout!.caretFor(const FlowPosition('word-1199', 3)),
        isNotNull);
    await tester.pumpWidget(const SizedBox());
    expect(many.debugTextChoiceEntries, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('unique unpadded text bypasses shape-cache admission',
      (tester) async {
    final controller = FlowLayoutController();
    final render = await mountCache(tester, controller);
    expect(render.debugTextShapePeakEntries, 0);
    expect(render.debugTextShapeHits, 0);
    expect(controller.layout!.fragmentsFor('b'), isNotEmpty);
  });
  testWidgets('participant index preserves order and isolates query results',
      (tester) async {
    final controller = FlowLayoutController();
    await tester.pumpWidget(MaterialApp(
        home: SizedBox(
            width: 100,
            child: FlowParagraph(
                controller: controller,
                style: _style,
                children: const [
                  FlowDecoration(
                      id: 'outer',
                      padding: EdgeInsets.all(2),
                      child: FlowDecoration(
                          id: 'inner',
                          padding: EdgeInsets.all(1),
                          child: FlowText('one two three four five six seven',
                              id: 'text'))),
                ]))));
    final snapshot = controller.layout!;
    for (final owner in ['outer', 'inner', 'text', 'missing']) {
      final expected =
          snapshot.fragments.where((f) => f.participant == owner).toList();
      final actual = snapshot.fragmentsFor(owner);
      expect(actual, orderedEquals(expected));
      if (actual.length > 1) actual[0] = actual.last;
      expect(snapshot.fragmentsFor(owner), orderedEquals(expected));
    }
    expect(snapshot.fragmentsFor('outer').length, greaterThan(1));
    await tester.pumpWidget(const SizedBox());
    await mountCache(tester, controller);
    expect(controller.layout!.fragmentsFor('outer'), isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('different text paint styles never alias a shaped resource',
      (tester) async {
    final controller = FlowLayoutController();
    await tester.pumpWidget(MaterialApp(
        home: DefaultTextStyle(
            style: _style,
            child: SizedBox(
                width: 400,
                child: FlowParagraph(
                    controller: controller,
                    style: _style,
                    children: const [
                      FlowText('office',
                          id: 'red', style: TextStyle(color: Colors.red)),
                      FlowBox(child: SizedBox(width: 1, height: 1)),
                      FlowText('office',
                          id: 'blue', style: TextStyle(color: Colors.blue)),
                    ])))));
    final render =
        tester.renderObject<RenderFlowParagraph>(find.byType(FlowParagraph));
    expect(render.debugTextShapeHits, 0);
    expect(render.debugTextShapeBuilds, 2);
    await tester.pumpWidget(const SizedBox());
    expect(render.debugTextShapeLive, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('mutable Paint styles preserve the uncached shaping path',
      (tester) async {
    final controller = FlowLayoutController();
    final style = _style.copyWith(foreground: Paint()..color = Colors.purple);
    await tester.pumpWidget(MaterialApp(
        home: DefaultTextStyle(
            style: style,
            child: SizedBox(
                width: 400,
                child: FlowParagraph(
                    controller: controller,
                    style: style,
                    children: const [
                      FlowText('office', id: 'one'),
                      FlowBox(child: SizedBox(width: 1, height: 1)),
                      FlowText('office', id: 'two'),
                    ])))));
    final render =
        tester.renderObject<RenderFlowParagraph>(find.byType(FlowParagraph));
    expect(render.debugTextShapeHits, 0);
    expect(render.debugTextShapeBuilds, 2);
    expect(
        controller.layout!.boxesForSelection(const FlowSelection(
            FlowPosition('one', 0), FlowPosition('two', 6))),
        isNotEmpty);
    await tester.pumpWidget(const SizedBox());
    expect(render.debugTextShapeLive, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'failed composition drops new leases without damaging the old snapshot',
      (tester) async {
    final controller = FlowLayoutController();
    const key = ValueKey('failure');
    await tester.pumpWidget(MaterialApp(
        home: DefaultTextStyle(
            style: _style,
            child: SizedBox(
                width: 400,
                child: FlowParagraph(
                    controller: controller,
                    style: _style,
                    children: const [
                      FlowText('office', id: 'prefix'),
                      _FailureWidget(key: key)
                    ])))));
    final render =
        tester.renderObject<RenderFlowParagraph>(find.byType(FlowParagraph));
    final previous = controller.layout;
    expect(render.debugTextShapeLive, 1);
    tester.renderObject<_FailureRender>(find.byKey(key)).fail = true;
    render.update(controller, RectangularFlowRegions(), _style, null, null);
    render.layout(const BoxConstraints.tightFor(width: 400));
    expect(tester.takeException(), isA<StateError>());
    expect(controller.layout, same(previous));
    expect(render.debugTextShapeLive, 1);
    expect(controller.layout!.caretFor(const FlowPosition('prefix', 0)),
        isNotNull);
    await tester.pumpWidget(const SizedBox());
    expect(render.debugTextShapeLive, 0);
  });
}

class _FailureWidget extends LeafRenderObjectWidget {
  const _FailureWidget({super.key});
  @override
  RenderObject createRenderObject(BuildContext context) => _FailureRender();
}

class _FailureRender extends RenderFlowParticipant {
  _FailureRender() : super(id: 'failure');
  bool fail = false;
  @override
  List<FlowContent> get content => [_FailureContent(this)];
  @override
  void performLayout() {}
}

class _FailureContent extends FlowContent {
  _FailureContent(RenderFlowParticipant owner) : super(owner, 0, 1, const []);
  @override
  FlowPreparedContent prepare(FlowPreparationContext context) =>
      (owner as _FailureRender).fail
          ? _ThrowPrepared(this)
          : FlowAtomicContent(owner, const Size(8, 8), 8).prepare(context);
}

class _ThrowPrepared extends FlowPreparedContent {
  _ThrowPrepared(this.entry);
  final FlowContent entry;
  @override
  List<FlowContent> get entries => [entry];
  @override
  Iterable<FlowBreakOpportunity> breaksAfter(int start) =>
      [const FlowBreakOpportunity(1)];
  @override
  FlowRangeMeasurement measureRange(
          TextRange range, FlowFragmentConstraints constraints) =>
      throw StateError('intentional measurement failure');
}
