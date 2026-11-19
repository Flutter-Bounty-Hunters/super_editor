import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_text_layout/super_text_layout.dart';

import 'test_tools_goldens.dart';

void main() {
  group("SuperText inline widgets >", () {
    testGoldensOnAndroid("vertical alignments", (tester) async {
      await tester.pumpWidget(
        _buildScaffold(
          // ignore: prefer_const_constructors
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SuperTextWithSelection.single(
                richText: _allAlignmentsWithText,
                userSelection: const UserSelection(
                  selection: TextSelection(baseOffset: 0, extentOffset: 69),
                ),
              ),
              const SizedBox(height: 24),
              SuperTextWithSelection.single(
                richText: _allAlignmentsNoText,
                userSelection: const UserSelection(
                  selection: TextSelection(baseOffset: 0, extentOffset: 6),
                ),
              ),
              const SizedBox(height: 24),
              SuperTextWithSelection.single(
                richText: _allAlignmentsMultipleSizesSmallToLarge,
                userSelection: const UserSelection(
                  selection: TextSelection(baseOffset: 0, extentOffset: 42),
                ),
              ),
              const SizedBox(height: 24),
              SuperTextWithSelection.single(
                richText: _allAlignmentsMultipleSizesLargeToSmall,
                userSelection: const UserSelection(
                  selection: TextSelection(baseOffset: 0, extentOffset: 42),
                ),
              ),
            ],
          ),
        ),
      );

      await screenMatchesGolden(tester, "SuperText-inline-widgets-alignment");
    });

    testGoldensOnAndroid("sizing", (tester) async {
      // This test demonstrates the mechanism that we can use to make
      // inline widgets the same height as the surrounding text (assuming
      // the surrounding text uses the same text style).
      final textPainter12 = TextPainter(
        text: TextSpan(
          text: 'a',
          style: _testTextStyle.copyWith(fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final textPainter18 = TextPainter(
        text: TextSpan(
          text: 'a',
          style: _testTextStyle.copyWith(fontSize: 18),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final textPainter32 = TextPainter(
        text: TextSpan(
          text: 'a',
          style: _testTextStyle.copyWith(fontSize: 32),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final textPainter64 = TextPainter(
        text: TextSpan(
          text: 'a',
          style: _testTextStyle.copyWith(fontSize: 64),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      await tester.pumpWidget(
        _buildScaffold(
          // ignore: prefer_const_constructors
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SuperTextWithSelection.single(
                richText: TextSpan(
                  text: '',
                  children: [
                    const TextSpan(text: 'Hello '),
                    WidgetSpan(
                        child: _inlineSquare(textPainter12.height),
                        alignment: PlaceholderAlignment.middle,
                        baseline: TextBaseline.alphabetic),
                    const TextSpan(text: 'World!'),
                  ],
                  style: _testTextStyle.copyWith(
                    fontSize: 12,
                  ),
                ),
                userSelection: const UserSelection(
                  selection: TextSelection(baseOffset: 0, extentOffset: 69),
                ),
              ),
              const SizedBox(height: 24),
              SuperTextWithSelection.single(
                richText: TextSpan(
                  text: '',
                  children: [
                    const TextSpan(text: 'Hello '),
                    WidgetSpan(
                        child: _inlineSquare(textPainter18.height),
                        alignment: PlaceholderAlignment.middle,
                        baseline: TextBaseline.alphabetic),
                    const TextSpan(text: 'World!'),
                  ],
                  style: _testTextStyle.copyWith(
                    fontSize: 18,
                  ),
                ),
                userSelection: const UserSelection(
                  selection: TextSelection(baseOffset: 0, extentOffset: 69),
                ),
              ),
              const SizedBox(height: 24),
              SuperTextWithSelection.single(
                richText: TextSpan(
                  text: '',
                  children: [
                    const TextSpan(text: 'Hello '),
                    WidgetSpan(
                        child: _inlineSquare(textPainter32.height),
                        alignment: PlaceholderAlignment.middle,
                        baseline: TextBaseline.alphabetic),
                    const TextSpan(text: 'World!'),
                  ],
                  style: _testTextStyle.copyWith(
                    fontSize: 32,
                  ),
                ),
                userSelection: const UserSelection(
                  selection: TextSelection(baseOffset: 0, extentOffset: 69),
                ),
              ),
              const SizedBox(height: 24),
              SuperTextWithSelection.single(
                richText: TextSpan(
                  text: '',
                  children: [
                    const TextSpan(text: 'Hello '),
                    WidgetSpan(
                        child: _inlineSquare(textPainter64.height),
                        alignment: PlaceholderAlignment.middle,
                        baseline: TextBaseline.alphabetic),
                    const TextSpan(text: 'World!'),
                  ],
                  style: _testTextStyle.copyWith(
                    fontSize: 64,
                  ),
                ),
                userSelection: const UserSelection(
                  selection: TextSelection(baseOffset: 0, extentOffset: 69),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );

      await screenMatchesGolden(tester, "SuperText-inline-widgets-sizing");
    });
  });
}

final _allAlignmentsWithText = TextSpan(
  text: "",
  children: [
    WidgetSpan(child: _inlineBlock(), alignment: PlaceholderAlignment.top),
    const TextSpan(
      text: "< Top",
    ),
    WidgetSpan(child: _inlineBlock(), alignment: PlaceholderAlignment.middle),
    const TextSpan(
      text: "< Middle",
    ),
    WidgetSpan(child: _inlineBlock(), alignment: PlaceholderAlignment.bottom),
    const TextSpan(
      text: "< Bottom",
    ),
    WidgetSpan(child: _inlineBlock(), alignment: PlaceholderAlignment.aboveBaseline, baseline: TextBaseline.alphabetic),
    const TextSpan(
      text: "< Above Baseline",
    ),
    WidgetSpan(child: _inlineBlock(), alignment: PlaceholderAlignment.baseline, baseline: TextBaseline.alphabetic),
    const TextSpan(
      text: "< Baseline",
    ),
    WidgetSpan(child: _inlineBlock(), alignment: PlaceholderAlignment.belowBaseline, baseline: TextBaseline.alphabetic),
    const TextSpan(
      text: "< Below Baseline",
    ),
  ],
  style: _testTextStyle,
);

final _allAlignmentsNoText = TextSpan(
  text: "",
  children: [
    WidgetSpan(child: _inlineBlock(), alignment: PlaceholderAlignment.top),
    WidgetSpan(child: _inlineBlock(), alignment: PlaceholderAlignment.middle),
    WidgetSpan(child: _inlineBlock(), alignment: PlaceholderAlignment.bottom),
    WidgetSpan(child: _inlineBlock(), alignment: PlaceholderAlignment.aboveBaseline, baseline: TextBaseline.alphabetic),
    WidgetSpan(child: _inlineBlock(), alignment: PlaceholderAlignment.baseline, baseline: TextBaseline.alphabetic),
    WidgetSpan(child: _inlineBlock(), alignment: PlaceholderAlignment.belowBaseline, baseline: TextBaseline.alphabetic),
  ],
  style: _testTextStyle,
);

final _allAlignmentsMultipleSizesSmallToLarge = TextSpan(
  text: "",
  children: [
    // Thin
    WidgetSpan(child: _inlineBlock(), alignment: PlaceholderAlignment.top),
    WidgetSpan(child: _inlineBlock(), alignment: PlaceholderAlignment.middle),
    WidgetSpan(child: _inlineBlock(), alignment: PlaceholderAlignment.bottom),
    WidgetSpan(child: _inlineBlock(), alignment: PlaceholderAlignment.aboveBaseline, baseline: TextBaseline.alphabetic),
    WidgetSpan(child: _inlineBlock(), alignment: PlaceholderAlignment.baseline, baseline: TextBaseline.alphabetic),
    WidgetSpan(child: _inlineBlock(), alignment: PlaceholderAlignment.belowBaseline, baseline: TextBaseline.alphabetic),
    const TextSpan(
      text: "Hello World!",
    ),
    // ~Height of text
    WidgetSpan(child: _inlineBlock(20), alignment: PlaceholderAlignment.top),
    WidgetSpan(child: _inlineBlock(20), alignment: PlaceholderAlignment.middle),
    WidgetSpan(child: _inlineBlock(20), alignment: PlaceholderAlignment.bottom),
    WidgetSpan(
        child: _inlineBlock(20), alignment: PlaceholderAlignment.aboveBaseline, baseline: TextBaseline.alphabetic),
    WidgetSpan(child: _inlineBlock(20), alignment: PlaceholderAlignment.baseline, baseline: TextBaseline.alphabetic),
    WidgetSpan(
        child: _inlineBlock(20), alignment: PlaceholderAlignment.belowBaseline, baseline: TextBaseline.alphabetic),
    const TextSpan(
      text: "Hello World!",
    ),
    // Taller than text
    WidgetSpan(child: _inlineBlock(40), alignment: PlaceholderAlignment.top),
    WidgetSpan(child: _inlineBlock(40), alignment: PlaceholderAlignment.middle),
    WidgetSpan(child: _inlineBlock(40), alignment: PlaceholderAlignment.bottom),
    WidgetSpan(
        child: _inlineBlock(40), alignment: PlaceholderAlignment.aboveBaseline, baseline: TextBaseline.alphabetic),
    WidgetSpan(child: _inlineBlock(40), alignment: PlaceholderAlignment.baseline, baseline: TextBaseline.alphabetic),
    WidgetSpan(
        child: _inlineBlock(40), alignment: PlaceholderAlignment.belowBaseline, baseline: TextBaseline.alphabetic),
  ],
  style: _testTextStyle,
);

final _allAlignmentsMultipleSizesLargeToSmall = TextSpan(
  text: "",
  children: [
    // Taller than text
    WidgetSpan(child: _inlineBlock(40), alignment: PlaceholderAlignment.top),
    WidgetSpan(child: _inlineBlock(40), alignment: PlaceholderAlignment.middle),
    WidgetSpan(child: _inlineBlock(40), alignment: PlaceholderAlignment.bottom),
    WidgetSpan(
        child: _inlineBlock(40), alignment: PlaceholderAlignment.aboveBaseline, baseline: TextBaseline.alphabetic),
    WidgetSpan(child: _inlineBlock(40), alignment: PlaceholderAlignment.baseline, baseline: TextBaseline.alphabetic),
    WidgetSpan(
        child: _inlineBlock(40), alignment: PlaceholderAlignment.belowBaseline, baseline: TextBaseline.alphabetic),
    const TextSpan(
      text: "Hello World!",
    ),
    // ~Height of text
    WidgetSpan(child: _inlineBlock(20), alignment: PlaceholderAlignment.top),
    WidgetSpan(child: _inlineBlock(20), alignment: PlaceholderAlignment.middle),
    WidgetSpan(child: _inlineBlock(20), alignment: PlaceholderAlignment.bottom),
    WidgetSpan(
        child: _inlineBlock(20), alignment: PlaceholderAlignment.aboveBaseline, baseline: TextBaseline.alphabetic),
    WidgetSpan(child: _inlineBlock(20), alignment: PlaceholderAlignment.baseline, baseline: TextBaseline.alphabetic),
    WidgetSpan(
        child: _inlineBlock(20), alignment: PlaceholderAlignment.belowBaseline, baseline: TextBaseline.alphabetic),
    const TextSpan(
      text: "Hello World!",
    ),
    // Thin
    WidgetSpan(child: _inlineBlock(), alignment: PlaceholderAlignment.top),
    WidgetSpan(child: _inlineBlock(), alignment: PlaceholderAlignment.middle),
    WidgetSpan(child: _inlineBlock(), alignment: PlaceholderAlignment.bottom),
    WidgetSpan(child: _inlineBlock(), alignment: PlaceholderAlignment.aboveBaseline, baseline: TextBaseline.alphabetic),
    WidgetSpan(child: _inlineBlock(), alignment: PlaceholderAlignment.baseline, baseline: TextBaseline.alphabetic),
    WidgetSpan(child: _inlineBlock(), alignment: PlaceholderAlignment.belowBaseline, baseline: TextBaseline.alphabetic),
  ],
  style: _testTextStyle,
);

Widget _inlineBlock([double height = 4]) => Container(
      width: 24,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.black,
    );

Widget _inlineSquare([double height = 4]) => Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: const AspectRatio(
        aspectRatio: 1.0,
        child: ColoredBox(color: Colors.black),
      ),
    );

const _testTextStyle = TextStyle(
  color: Color(0xFF000000),
  fontFamily: 'Roboto',
  fontSize: 20,
);

Widget _buildScaffold({
  required Widget child,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: child,
      ),
    ),
    debugShowCheckedModeBanner: false,
  );
}
