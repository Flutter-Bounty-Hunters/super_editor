import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_reader_test.dart';
import 'package:super_editor/super_test.dart';

void main() {
  group("SuperReader selection >", () {
    group("color >", () {
      testGoldensOnMac("default selection color", (tester) async {
        await tester //
            .createDocument()
            .withSingleParagraphShort()
            .pump();

        // Select the whole paragraph so that the selection color is clearly visible.
        await tester.tripleTapInParagraph("1", 0);

        await screenMatchesGolden(tester, "super-reader_selection-color_default");
      }, windowSize: goldenSizeLarge);

      testGoldensOnMac("custom selection color", (tester) async {
        await tester //
            .createDocument()
            .withSingleParagraphShort()
            .withSelectionStyles(const SelectionStyles(selectionColor: Colors.deepPurple))
            .useStylesheet(defaultStylesheet.copyWith(
              selectedTextColorStrategy: ({
                required Color originalTextColor,
                required Color selectionHighlightColor,
              }) =>
                  Colors.white,
            ))
            .pump();

        // Select the whole paragraph so that the selection color is clearly visible.
        await tester.tripleTapInParagraph("1", 0);

        await screenMatchesGolden(tester, "super-reader_selection-color_custom");
      }, windowSize: goldenSizeLarge);
    });
  });
}
