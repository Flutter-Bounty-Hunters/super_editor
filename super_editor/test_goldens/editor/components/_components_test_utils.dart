import 'package:flutter/material.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_editor/super_test.dart';

void testComponentGolden(String description, Widget componentBuilder, String fileName) {
  testGoldensOnAndroid(description, (tester) async {
    tester.view
      ..physicalSize = const Size(600, 400)
      ..devicePixelRatio = 1.0;
    tester.binding.platformDispatcher.textScaleFactorTestValue = 1.0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: componentBuilder,
          ),
        ),
        debugShowCheckedModeBanner: false,
      ),
    );

    await screenMatchesGolden(tester, fileName);
  });
}
