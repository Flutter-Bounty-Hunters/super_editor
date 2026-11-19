import 'package:flutter/material.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_text_layout/src/text_underline_layer.dart';

import 'test_tools.dart';
import 'test_tools_goldens.dart';

void main() {
  testGoldensOnAndroid("Underline layer paints an underline", (tester) async {
    await pumpThreeLinePlainSuperText(
      tester,
      beneathBuilder: (context, textLayout) {
        return TextUnderlineLayer(
          textLayout: textLayout,
          style: const StraightUnderlineStyle(
            color: Colors.lightBlue,
            thickness: 4,
          ),
          underlines: const [
            TextLayoutUnderline(
              range: TextSelection(
                baseOffset: 36,
                extentOffset: 79,
              ),
            ),
            TextLayoutUnderline(
              range: TextSelection(
                baseOffset: 88,
                extentOffset: 110,
              ),
            ),
          ],
        );
      },
    );

    await screenMatchesGolden(tester, "TextUnderlineLayer_paints-underline");
  });
}
