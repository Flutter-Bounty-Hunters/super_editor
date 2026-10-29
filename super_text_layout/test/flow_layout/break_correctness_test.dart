import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_text_layout/experimental_flow.dart';

const _style = TextStyle(
    fontFamily: kIsWeb ? 'FlowDemo' : 'BreakTest',
    fontSize: 20,
    color: Colors.black);

Future<(FlowLayoutController, FlowPreparedContent)> _prepare(
    WidgetTester tester, String text,
    {double width = 240}) async {
  final controller = FlowLayoutController();
  const key = ValueKey('text');
  await tester.pumpWidget(MaterialApp(
      home: Align(
          alignment: Alignment.topLeft,
          child: DefaultTextStyle(
              style: _style,
              child: SizedBox(
                  width: width,
                  child: FlowParagraph(
                      controller: controller,
                      style: _style,
                      children: [FlowText(text, id: 'text', key: key)]))))));
  expect(tester.takeException(), isNull);
  final entry =
      tester.renderObject<RenderFlowText>(find.byKey(key)).content.single;
  return (controller, entry.prepare(FlowPreparationContext(entry, _style)));
}

void main() {
  setUpAll(() async {
    // Web loads this font from the app manifest; native widget tests register it.
    if (kIsWeb) return;
    await (FontLoader('BreakTest')
          ..addFont(rootBundle
              .load('packages/flow_layout_test_fonts/Roboto-Regular.ttf')))
        .load();
  });

  testWidgets(
      'nonbreaking spaces and word joiners stay protected even in emergency alternatives',
      (tester) async {
    for (final glue in ['\u00a0', '\u202f', '\u2060', '\ufeff']) {
      final (controller, prepared) =
          await _prepare(tester, 'prefix 10${glue}kg more', width: 100);
      final positions = prepared.breaksAfter(7).map((b) => b.offset).toList();
      expect(positions, isNot(contains(9)));
      expect(positions, isNot(contains(10)));
      for (final fragment in controller.layout!.fragmentsFor('text')) {
        expect([9, 10], isNot(contains(fragment.range.start)));
        expect([9, 10], isNot(contains(fragment.range.end)));
      }
    }
  });

  testWidgets('CJK ordinary breaks respect opening and closing punctuation',
      (tester) async {
    final (controller, prepared) =
        await _prepare(tester, '甲乙（丙丁）戊己', width: 80);
    final ordinary = prepared
        .breaksAfter(0)
        .where((b) => b.kind == FlowBreakKind.ordinary)
        .map((b) => b.offset)
        .toList();
    expect(ordinary, containsAll([1, 2, 6, 7, 8]));
    expect(ordinary, isNot(contains(3))); // after opening parenthesis
    expect(ordinary, isNot(contains(5))); // before closing parenthesis
    for (final fragment in controller.layout!.fragmentsFor('text')) {
      expect([3, 5], isNot(contains(fragment.range.end)));
    }
  });

  testWidgets(
      'zero-width space is an ordinary break and soft hyphen is rendered only at a selected break',
      (tester) async {
    final (_, zeroWidth) = await _prepare(tester, 'a\u200bb');
    expect(
        zeroWidth
            .breaksAfter(0)
            .where((b) => b.kind == FlowBreakKind.ordinary)
            .map((b) => b.offset),
        contains(2));
    final (_, prepared) = await _prepare(tester, 'co\u00adoperate');
    const constraints =
        FlowFragmentConstraints(availableWidth: 240, maximumWidth: 240);
    final split =
        prepared.measureRange(const TextRange(start: 0, end: 3), constraints);
    final whole =
        prepared.measureRange(const TextRange(start: 0, end: 10), constraints);
    final hyphen = TextPainter(
        text: const TextSpan(text: 'co-', style: _style),
        textDirection: TextDirection.ltr)
      ..layout();
    final word = TextPainter(
        text: const TextSpan(text: 'cooperate', style: _style),
        textDirection: TextDirection.ltr)
      ..layout();
    expect(split.width, closeTo(hyphen.width, .01));
    expect(whole.width, closeTo(word.width, .01));
    expect(split.boxesForRange(const TextRange(start: 2, end: 3)), isNotEmpty);
    split.dispose();
    whole.dispose();
    hyphen.dispose();
    word.dispose();
  });

  testWidgets(
      'hard-break controls preserve the existing empty-line layout; CRLF is indivisible',
      (tester) async {
    for (final control in [
      '\n',
      '\r',
      '\r\n',
      '\u000b',
      '\u000c',
      '\u0085',
      '\u2028',
      '\u2029'
    ]) {
      final (controller, prepared) = await _prepare(tester, 'a${control}b');
      expect(controller.layout!.lines, hasLength(3));
      final blank = controller.layout!.lines[1];
      final endpoint = controller.layout!
          .positionNearestTo(Offset(150, blank.top + blank.height / 2))!;
      expect(endpoint.offset, 1);
      final caret = controller.layout!.caretFor(endpoint)!;
      expect(caret.center.dy,
          inInclusiveRange(blank.top, blank.top + blank.height));
      if (control == '\r\n') {
        expect(prepared.breaksAfter(1).map((b) => b.offset), [3]);
      }
    }
  });

  testWidgets('Flutter dictionary word boundaries supply Thai opportunities',
      (tester) async {
    final (_, prepared) = await _prepare(tester, 'ภาษาไทยภาษาไทย');
    final ordinary = prepared
        .breaksAfter(0)
        .where((b) => b.kind == FlowBreakKind.ordinary)
        .map((b) => b.offset);
    expect(ordinary, containsAllInOrder([4, 7, 11, 14]));
  });

  testWidgets(
      'decoration-only boundaries do not introduce a break inside a word or a joiner sequence',
      (tester) async {
    final controller = FlowLayoutController();
    await tester.pumpWidget(MaterialApp(
        home: Align(
            alignment: Alignment.topLeft,
            child: DefaultTextStyle(
                style: _style,
                child: SizedBox(
                    width: 140,
                    child: FlowParagraph(
                        controller: controller,
                        style: _style,
                        children: const [
                          FlowText('prefix '),
                          FlowText('10\u00a0', id: 'left'),
                          FlowDecoration(child: FlowText('kg', id: 'right')),
                        ]))))));
    expect(tester.takeException(), isNull);
    final left = controller.layout!.fragmentsFor('left').last;
    final right = controller.layout!.fragmentsFor('right').first;
    expect(left.line, right.line);
  });
  testWidgets('padded text retains nonbreaking context across participants',
      (tester) async {
    final controller = FlowLayoutController();
    await tester.pumpWidget(MaterialApp(
        home: Align(
            alignment: Alignment.topLeft,
            child: DefaultTextStyle(
                style: _style,
                child: SizedBox(
                    width: 140,
                    child: FlowParagraph(
                        controller: controller,
                        style: _style,
                        children: const [
                          FlowText('prefix '),
                          FlowText('10\u00a0', id: 'left'),
                          FlowDecoration(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: FlowText('kg', id: 'right')),
                        ]))))));
    expect(tester.takeException(), isNull);
    expect(controller.layout!.fragmentsFor('left').last.line,
        controller.layout!.fragmentsFor('right').first.line);
  });

  testWidgets('a word across padded participants moves intact to a fresh line',
      (tester) async {
    double measure(String text) {
      final painter = TextPainter(
          text: TextSpan(text: text, style: _style),
          textDirection: TextDirection.ltr)
        ..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final controller = FlowLayoutController();
    final width = measure('of') + measure('fice') + 12 + .5;
    await tester.pumpWidget(MaterialApp(
        home: Align(
            alignment: Alignment.topLeft,
            child: DefaultTextStyle(
                style: _style,
                child: SizedBox(
                    width: width,
                    child: FlowParagraph(
                        controller: controller,
                        style: _style,
                        children: const [
                          FlowText('a ', id: 'prefix'),
                          FlowText('of', id: 'left'),
                          FlowDecoration(
                              id: 'wrapper',
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: FlowText('fice', id: 'right')),
                        ]))))));
    expect(tester.takeException(), isNull);
    final left = controller.layout!.fragmentsFor('left').single;
    final right = controller.layout!.fragmentsFor('right').single;
    expect(left.line, 1);
    expect(right.line, left.line);
    expect(controller.layout!.caretFor(const FlowPosition('left', 2))!.left,
        closeTo(left.bounds.right, .01));
    expect(controller.layout!.caretFor(const FlowPosition('right', 0))!.left,
        closeTo(right.bounds.left, .01));
    expect(right.bounds.left - left.bounds.right, closeTo(6, .01));
  });

  testWidgets('emergency alternatives never split emoji or combining graphemes',
      (tester) async {
    for (final grapheme in ['a\u0301', '👩🏽‍💻', '🇺🇸', 'क्‍ष']) {
      final (_, prepared) = await _prepare(tester, 'X${grapheme}Y');
      final boundaries = prepared.breaksAfter(0).map((b) => b.offset).toList();
      for (var offset = 2; offset < 1 + grapheme.length; offset++) {
        expect(boundaries, isNot(contains(offset)), reason: grapheme);
      }
    }
  });

  testWidgets('nested padding is charged once per common fragment',
      (tester) async {
    final controller = FlowLayoutController();
    final painter = TextPainter(
        text: const TextSpan(text: 'abc', style: _style),
        textDirection: TextDirection.ltr)
      ..layout();
    final expectedWidth = painter.width + 16;
    painter.dispose();
    await tester.pumpWidget(MaterialApp(
        home: Align(
            alignment: Alignment.topLeft,
            child: DefaultTextStyle(
                style: _style,
                child: SizedBox(
                    width: expectedWidth + .5,
                    child: FlowParagraph(
                        controller: controller,
                        style: _style,
                        children: const [
                          FlowDecoration(
                              id: 'outer',
                              padding: EdgeInsets.all(5),
                              child: FlowSequence(children: [
                                FlowText('a', id: 'a'),
                                FlowDecoration(
                                    id: 'inner',
                                    padding: EdgeInsets.all(3),
                                    child: FlowText('b', id: 'b')),
                                FlowText('c', id: 'c'),
                              ])),
                        ]))))));
    expect(tester.takeException(), isNull);
    expect(controller.layout!.lines, hasLength(1));
    final outer = controller.layout!.fragmentsFor('outer').single;
    expect(outer.bounds.width, closeTo(expectedWidth, .01));
    final inner = controller.layout!.fragmentsFor('inner').single;
    final b = controller.layout!.fragmentsFor('b').single;
    expect(inner.bounds, b.bounds.inflate(3));
  });
  testWidgets(
      'text and ordinary widgets share enclosing padding on the same line',
      (tester) async {
    final controller = FlowLayoutController();
    final painter = TextPainter(
        text: const TextSpan(text: 'pabq', style: _style),
        textDirection: TextDirection.ltr)
      ..layout();
    final expectedWidth = painter.width + 20 + 12;
    painter.dispose();
    await tester.pumpWidget(MaterialApp(
        home: Align(
            alignment: Alignment.topLeft,
            child: DefaultTextStyle(
                style: _style,
                child: SizedBox(
                    width: expectedWidth + .5,
                    child: FlowParagraph(
                        controller: controller,
                        style: _style,
                        children: const [
                          FlowText('p'),
                          FlowDecoration(
                              id: 'wrapper',
                              padding: EdgeInsets.all(6),
                              child: FlowSequence(children: [
                                FlowText('a', id: 'a'),
                                FlowBox(
                                    id: 'box',
                                    child: SizedBox(width: 20, height: 20)),
                                FlowText('b', id: 'b'),
                              ])),
                          FlowText('q', id: 'end'),
                        ]))))));
    expect(tester.takeException(), isNull);
    final layout = controller.layout!;
    expect(layout.lines, hasLength(1));
    final a = layout.fragmentsFor('a').single;
    final box = layout.fragmentsFor('box').single;
    final b = layout.fragmentsFor('b').single;
    expect(box.bounds.left, closeTo(a.bounds.right, .01));
    expect(b.bounds.left, closeTo(box.bounds.right, .01));
    expect(layout.fragmentsFor('end').single.bounds.right,
        closeTo(expectedWidth, .01));
  });
}
