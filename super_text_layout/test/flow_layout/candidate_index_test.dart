import 'support/reference_paragraph.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_text_layout/experimental_flow.dart';

const _style = TextStyle(
    fontFamily: kIsWeb ? 'FlowDemo' : 'CandidateTest',
    fontSize: 20,
    color: Colors.black);

void main() {
  setUpAll(() async {
    if (kIsWeb) return;
    await (FontLoader('CandidateTest')
          ..addFont(rootBundle
              .load('packages/flow_layout_test_fonts/Roboto-Regular.ttf')))
        .load();
  });

  testWidgets(
      'automatic fitting or indexed fallback matches the public iterator path',
      (tester) async {
    for (final text in [
      '',
      'ordinary words with space',
      'a\r\nb\n\nc',
      'soft\u00adhyphenation',
      'a\u00a0b\u2060c more',
      '中文（标点）换行',
      'ภาษาไทยภาษาไทย',
      'emoji 😀 e\u0301 family 👩‍👩‍👧‍👦',
    ]) {
      for (final width in [40.0, 100.0, 240.0]) {
        for (final spacing in [0.0, -3.0]) {
          final indexed = FlowLayoutController(),
              iterator = FlowLayoutController();
          final style = _style.copyWith(letterSpacing: spacing);
          await tester.pumpWidget(MaterialApp(
              home: DefaultTextStyle(
                  style: style,
                  child: SingleChildScrollView(
                      child: Column(children: [
                    SizedBox(
                        width: width,
                        child: FlowParagraph(
                            controller: indexed,
                            style: style,
                            children: [FlowText(text, id: 'text')])),
                    SizedBox(
                        width: width,
                        child: FlowParagraph(
                            controller: iterator,
                            style: style,
                            children: [_IteratorText(text, style)])),
                  ])))));
          expect(tester.takeException(), isNull);
          final a = indexed.layout!, b = iterator.layout!;
          expect(b.size, a.size, reason: '$text / $width / $spacing');
          expect(b.lineRetries, a.lineRetries);
          expect(b.lines.map((l) => (l.top, l.height, l.baseline)),
              orderedEquals(a.lines.map((l) => (l.top, l.height, l.baseline))));
          expect(
              b.fragments.map((f) => (f.range, f.bounds, f.line, f.baseline)),
              orderedEquals(a.fragments
                  .map((f) => (f.range, f.bounds, f.line, f.baseline))));
          await tester.pumpWidget(const SizedBox());
        }
      }
    }
  });

  testWidgets(
      'compact fitting preserves ASCII geometry across styles and widths',
      (tester) async {
    const words = ['alpha', 'WIDE', 'i', 'ffi', '(code)', 'x=y;', '42', 'AV'];
    for (var sample = 0; sample < 16; sample++) {
      final text = List.generate(
          24,
          (i) =>
              words[(i * 7 + sample * 3 + i * i) % words.length] +
              (' ' * (1 + (i + sample) % 3))).join();
      final style = _style.copyWith(
        letterSpacing: sample % 2 == 0 ? 0 : 1.25,
        wordSpacing: sample % 3 == 0 ? 2 : 0,
        fontWeight: sample % 4 == 0 ? FontWeight.bold : FontWeight.normal,
        fontStyle: sample % 5 == 0 ? FontStyle.italic : FontStyle.normal,
      );
      for (final width in [30.0, 79.5, 140.0, 260.0]) {
        final controllers = [FlowLayoutController(), FlowLayoutController()];
        await tester.pumpWidget(MaterialApp(
            home: SingleChildScrollView(
          child: Column(children: [
            for (var i = 0; i < 2; i++)
              SizedBox(
                  width: width,
                  child: ReferenceFlowParagraph(
                    controller: controllers[i],
                    style: style,
                    exhaustive: i == 0,
                    children: [FlowText(text, id: 'text')],
                  )),
          ]),
        )));
        expect(tester.takeException(), isNull);
        final reference = controllers[0].layout!,
            actual = controllers[1].layout!;
        expect(actual.size, reference.size, reason: '$sample / $width');
        expect(
            actual.lines.map((l) => (l.top, l.height, l.baseline)),
            orderedEquals(
                reference.lines.map((l) => (l.top, l.height, l.baseline))));
        expect(
            actual.fragments
                .map((f) => (f.range, f.bounds, f.line, f.baseline)),
            orderedEquals(reference.fragments
                .map((f) => (f.range, f.bounds, f.line, f.baseline))));
        await tester.pumpWidget(const SizedBox());
        for (final controller in controllers) {
          controller.dispose();
        }
      }
    }
  });

  testWidgets(
      'retained decisions match fresh searches after edits and region changes',
      (tester) async {
    final cached = FlowLayoutController(), reference = FlowLayoutController();
    var text = 'ordinary words with space and soft\u00adhyphens';
    var width = 100.0;
    var style = _style;
    var obstacles = <Rect>[];
    Future<RenderFlowParagraph> show() async {
      await tester.pumpWidget(MaterialApp(
          home: DefaultTextStyle(
              style: style,
              child: SingleChildScrollView(
                  child: Column(children: [
                for (final optimized in [true, false])
                  SizedBox(
                      width: width,
                      child: FlowParagraph(
                          key: ValueKey(optimized),
                          controller: optimized ? cached : reference,
                          style: style,
                          regions: RectangularFlowRegions(obstacles: obstacles),
                          children: [
                            const FlowBox(
                                id: 'box',
                                child: SizedBox(width: 75, height: 25)),
                            if (optimized)
                              FlowText(text, id: 'text')
                            else
                              _IteratorText(text, style),
                          ])),
              ])))));
      expect(tester.takeException(), isNull);
      final a = cached.layout!, b = reference.layout!;
      expect(a.size, b.size);
      expect(a.lineRetries, b.lineRetries);
      expect(a.lines.map((l) => (l.top, l.height, l.baseline)),
          orderedEquals(b.lines.map((l) => (l.top, l.height, l.baseline))));
      expect(
          a.fragments.map((f) => (f.participant, f.range, f.bounds, f.line)),
          orderedEquals(b.fragments
              .map((f) => (f.participant, f.range, f.bounds, f.line))));
      return tester
          .renderObject<RenderFlowParagraph>(find.byKey(const ValueKey(true)));
    }

    final render = await show();
    expect(render.debugTextChoiceHits, 0);
    await show();
    expect(render.debugTextChoiceHits, greaterThan(0));
    // This includes a cached non-fit after the 75px box and fitting later lines.
    var hits = render.debugTextChoiceHits;
    width = 180;
    await show();
    expect(render.debugTextChoiceHits, hits);
    text += ' changed';
    await show();
    expect(render.debugTextChoiceHits, hits);
    style = _style.copyWith(fontSize: 23, letterSpacing: -2);
    await show();
    expect(render.debugTextChoiceHits, hits);
    await show();
    expect(render.debugTextChoiceHits, greaterThan(hits));
    obstacles = [const Rect.fromLTWH(80, 0, 30, 70)];
    await show();
    await show();
    hits = render.debugTextChoiceHits;
    await tester.binding.handleSystemMessage({'type': 'fontsChange'});
    await tester.pump();
    expect(render.debugTextChoiceHits, hits);
    await show();
    expect(render.debugTextChoiceHits, greaterThan(hits));
    style = _style.copyWith(foreground: Paint()..color = Colors.purple);
    hits = render.debugTextChoiceHits;
    await show();
    await show();
    expect(render.debugTextChoiceHits, hits);
  });

  testWidgets(
      'retained exact widths match uncached searches through edits and font changes',
      (tester) async {
    final cached = FlowLayoutController(), reference = FlowLayoutController();
    final original =
        List.generate(16, (i) => 'office$i soft\u00adhyphen e\u0301 😀 字 ')
            .join();
    var text = original;
    var width = 240.0;
    var style = _style;
    Future<RenderFlowParagraph> show() async {
      await tester.pumpWidget(MaterialApp(
          home: DefaultTextStyle(
              style: style,
              child: SingleChildScrollView(
                  child: Column(children: [
                for (final optimized in [true, false])
                  SizedBox(
                      width: width,
                      child: FlowParagraph(
                          key: ValueKey(optimized),
                          controller: optimized ? cached : reference,
                          style: style,
                          children: [
                            if (optimized)
                              FlowText(text, id: 'text')
                            else
                              _IteratorText(text, style)
                          ])),
              ])))));
      expect(tester.takeException(), isNull);
      final a = cached.layout!, b = reference.layout!;
      expect(a.size, b.size);
      expect(
          a.fragments.map((f) => (f.range, f.bounds, f.line, f.baseline)),
          orderedEquals(
              b.fragments.map((f) => (f.range, f.bounds, f.line, f.baseline))));
      expect(a.lines.map((l) => (l.top, l.height, l.baseline)),
          orderedEquals(b.lines.map((l) => (l.top, l.height, l.baseline))));
      final selection = FlowSelection(
          const FlowPosition('text', 0), FlowPosition('text', text.length));
      expect(a.boxesForSelection(selection), b.boxesForSelection(selection));
      expect(a.caretFor(FlowPosition('text', text.length)),
          b.caretFor(FlowPosition('text', text.length)));
      return tester
          .renderObject<RenderFlowParagraph>(find.byKey(const ValueKey(true)));
    }

    final render = await show();
    final initialHits = render.debugTextWidthHits;
    width = 120;
    await show();
    expect(render.debugTextWidthHits, greaterThan(initialHits));
    text = 'changed$original';
    await show();
    final mid = original.length ~/ 2;
    text = '${original.substring(0, mid)}changed${original.substring(mid)}';
    await show();
    text = '${original}changed';
    await show();
    style = _style.copyWith(fontSize: 24, letterSpacing: -2);
    await show();
    final afterStyle = render.debugTextWidthHits;
    text = 'more$text';
    await show();
    expect(render.debugTextWidthHits, greaterThan(afterStyle));
    await tester.binding.handleSystemMessage({'type': 'fontsChange'});
    expect(render.debugTextWidthEntries, 0);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await show();
    style = _style.copyWith(foreground: Paint()..color = Colors.purple);
    final beforeMutable = render.debugTextWidthHits;
    await show();
    text = '${text}again';
    await show();
    expect(render.debugTextWidthHits, beforeMutable);
    await tester.pumpWidget(const SizedBox());
    expect(render.debugTextWidthEntries, 0);
    expect(render.debugTextShapeLive, 0);
  });

  testWidgets(
      'width-cache eviction preserves chosen artifacts and bounds retention',
      (tester) async {
    final controller = FlowLayoutController();
    final text = List.generate(220, (i) => 'word$i ').join();
    await tester.pumpWidget(MaterialApp(
        home: DefaultTextStyle(
            style: _style,
            child: SingleChildScrollView(
                child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                        width: 140,
                        child: ReferenceFlowParagraph(
                            exhaustive: true,
                            controller: controller,
                            style: _style,
                            children: [FlowText(text, id: 'text')])))))));
    expect(tester.takeException(), isNull);
    final render = tester
        .renderObject<RenderFlowParagraph>(find.byType(ReferenceFlowParagraph));
    expect(render.debugTextWidthEvictions, greaterThan(0));
    expect(render.debugTextWidthEntries, lessThanOrEqualTo(4096));
    expect(render.debugTextWidthUnits, lessThanOrEqualTo(2097152));
    expect(controller.layout!.caretFor(FlowPosition('text', text.length)),
        isNotNull);
    expect(
        controller.layout!.boxesForSelection(FlowSelection(
            const FlowPosition('text', 0), FlowPosition('text', text.length))),
        isNotEmpty);
    await tester.pumpWidget(const SizedBox());
    expect(render.debugTextWidthEntries, 0);
    expect(render.debugTextWidthUnits, 0);
    expect(render.debugTextShapeLive, 0);
  });

  testWidgets(
      'compact fitting is automatic and preserves conservative fallbacks',
      (tester) async {
    final controller = FlowLayoutController();
    var text = 'ordinary words with enough spaces to wrap across several lines';
    var style = _style;
    var padded = false;
    Future<RenderFlowParagraph> show() async {
      await tester.pumpWidget(MaterialApp(
          home: DefaultTextStyle(
              style: style,
              child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                      width: 120,
                      child: FlowParagraph(
                          controller: controller,
                          style: style,
                          children: [
                            FlowDecoration(
                                padding: EdgeInsets.all(padded ? 2 : 0),
                                child: FlowText(text, id: 'text'))
                          ]))))));
      expect(tester.takeException(), isNull);
      return tester
          .renderObject<RenderFlowParagraph>(find.byType(FlowParagraph));
    }

    final render = await show();
    expect(render.debugFlutterLineFits, 0);
    expect(render.debugCompactRejections, greaterThan(0));
    final before = render.debugCompactRejections;
    render.debugUseExhaustiveTextFitting = true;
    await tester.pump();
    expect(render.debugCompactRejections, before);
    render.debugUseExhaustiveTextFitting = false;
    await tester.pump();
    padded = true;
    await show();
    expect(render.debugFlutterLineFits, 0);
    padded = false;
    for (final value in [
      'a\r\nb\n\nc',
      'soft\u00adhyphen text',
      'emoji 😀 text',
      '中文 text',
      'one\u00a0two text'
    ]) {
      text = value;
      await show();
      expect(render.debugFlutterLineFits, 0);
    }
    text = 'ordinary words with enough spaces to wrap';
    style = _style.copyWith(letterSpacing: -1);
    await show();
    expect(render.debugFlutterLineFits, 0);
    style = _style.copyWith(fontFeatures: const [FontFeature.disable('liga')]);
    await show();
    expect(render.debugFlutterLineFits, 0);
  });

  testWidgets('custom opportunities are still validated before measurement',
      (tester) async {
    for (final opportunities in [
      [const FlowBreakOpportunity(1), const FlowBreakOpportunity(1)],
      [const FlowBreakOpportunity(2), const FlowBreakOpportunity(1)],
      [
        const FlowBreakOpportunity(1, kind: FlowBreakKind.required),
        const FlowBreakOpportunity(2)
      ],
      [const FlowBreakOpportunity(-1)],
      [const FlowBreakOpportunity(0)],
      [const FlowBreakOpportunity(4)],
    ]) {
      await tester.pumpWidget(MaterialApp(
          home: FlowParagraph(
              controller: FlowLayoutController(),
              style: _style,
              children: const [_IteratorText('abc', _style)])));
      expect(tester.takeException(), isNull);
      final child =
          tester.renderObject<_IteratorRender>(find.byType(_IteratorText));
      child.opportunities = opportunities;
      final paragraph =
          tester.renderObject<RenderFlowParagraph>(find.byType(FlowParagraph));
      paragraph.markNeedsLayout();
      paragraph.layout(const BoxConstraints.tightFor(width: 240));
      expect(
          tester.takeException(),
          isA<FlutterError>().having((e) => e.message, 'message',
              contains('Invalid break opportunities')));
      await tester.pumpWidget(const SizedBox());
    }
  });
}

// Exercise exactly the same text measurements through the public custom-source
// contract, which intentionally does not expose the private indexed capability.
class _IteratorText extends LeafRenderObjectWidget {
  const _IteratorText(this.text, this.style);
  final String text;
  final TextStyle style;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _IteratorRender(text, style, null);
  @override
  void updateRenderObject(BuildContext context, _IteratorRender renderObject) {
    renderObject
      ..text = text
      ..style = style
      ..opportunities = null
      ..markNeedsLayout();
  }
}

class _IteratorRender extends RenderFlowParticipant {
  _IteratorRender(this.text, this.style, this.opportunities)
      : super(id: 'text');
  String text;
  TextStyle style;
  List<FlowBreakOpportunity>? opportunities;
  @override
  List<FlowContent> get content => [_IteratorContent(this)];
  @override
  void performLayout() {}
  @override
  void paint(PaintingContext context, Offset offset) {}
}

class _IteratorContent extends FlowContent {
  _IteratorContent(_IteratorRender owner)
      : super(owner, 0, owner.text.length, const []);
  @override
  FlowPreparedContent prepare(FlowPreparationContext context) {
    final render = owner as _IteratorRender;
    final entry = FlowTextContent(render, render.text, render.style);
    return _IteratorPrepared(
        entry.prepare(FlowPreparationContext(entry, context.paragraphStyle)),
        render.opportunities);
  }
}

class _IteratorPrepared extends FlowPreparedContent {
  _IteratorPrepared(this.delegate, this.opportunities);
  final FlowPreparedContent delegate;
  final List<FlowBreakOpportunity>? opportunities;
  @override
  bool get measuresDecorationPadding => delegate.measuresDecorationPadding;
  @override
  List<FlowContent> get entries => delegate.entries;
  @override
  Iterable<FlowBreakOpportunity> breaksAfter(int start) =>
      opportunities ?? delegate.breaksAfter(start);
  @override
  FlowRangeMeasurement measureRange(
          TextRange range, FlowFragmentConstraints constraints) =>
      delegate.measureRange(range, constraints);
}
