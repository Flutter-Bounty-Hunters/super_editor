import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_text_layout/super_text_layout.dart';

import 'test_tools_goldens.dart';

void main() {
  group("SuperText", () {
    group("text layout", () {
      testGoldensOnAndroid("renders a visual reference for non-visual tests", (tester) async {
        await _pumpThreeLinePlainText(tester);
        await screenMatchesGolden(tester, "SuperText-reference-render");
      });

      testGoldensOnAndroid("applies textScaleFactor", (tester) async {
        await tester.pumpWidget(
          _buildScaffold(
            // ignore: prefer_const_constructors
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: const [
                Expanded(
                  child: SuperText(
                    richText: _threeLineSpan,
                    textScaler: TextScaler.noScaling,
                  ),
                ),
                Expanded(
                  child: SuperText(
                    richText: _threeLineSpan,
                    textScaler: TextScaler.linear(2.0),
                  ),
                ),
              ],
            ),
          ),
        );

        await screenMatchesGolden(tester, "SuperText-text-scale-factor");
      });

      testGoldensOnAndroid("respects max lines and overflow", (tester) async {
        await tester.pumpWidget(
          _buildScaffold(
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 24,
                children: [
                  SuperText(
                    richText: _threeLineSpan,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SuperText(
                    richText: _threeLineSpan,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SuperText(
                    richText: _threeLineSpan,
                  ),
                ],
              ),
            ),
          ),
        );

        await screenMatchesGolden(tester, "SuperText-max-lines");
      });
    });
  });
}

Future<void> _pumpThreeLinePlainText(WidgetTester tester) async {
  await tester.pumpWidget(
    _buildScaffold(
      child: SuperText(
        key: _textKey,
        richText: _threeLineSpan,
      ),
    ),
  );
}

final _textKey = GlobalKey(debugLabel: "super_text");

const _threeLineSpan = TextSpan(
  text: "This is some text. It is explicitly laid out in\n" // Line indices: 0 -> 47/48 (upstream/downstream)
      "multiple lines so that we don't need to guess\n" // Line indices: 48 ->  93/94 (upstream/downstream)
      "where the layout forces a line break", // Line indices: 94 -> 130
  style: _testTextStyle,
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
