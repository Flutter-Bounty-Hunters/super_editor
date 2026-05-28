import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_text_layout/super_text_layout.dart';

import 'test_tools.dart';

void main() {
  group('SuperText strut style', () {
    const inheritedStrut = StrutStyle(
      fontSize: 18,
      height: 1.6,
      forceStrutHeight: true,
    );
    const explicitStrut = StrutStyle(
      fontSize: 20,
      height: 1.4,
      forceStrutHeight: true,
    );

    testWidgets(
      'uses an inherited strut style when no explicit strut is provided',
      (tester) async {
        await tester.pumpWidget(
          buildTestScaffold(
            child: const SuperTextStrutStyle(
              strutStyle: inheritedStrut,
              child: SuperText(
                richText: TextSpan(text: 'Text with inherited strut'),
              ),
            ),
          ),
        );

        final richText = tester.widget<LayoutAwareRichText>(
          find.byType(LayoutAwareRichText),
        );
        expect(richText.strutStyle, inheritedStrut);
      },
    );

    testWidgets(
      'prefers an explicit strut style over an inherited strut style',
      (tester) async {
        await tester.pumpWidget(
          buildTestScaffold(
            child: const SuperTextStrutStyle(
              strutStyle: inheritedStrut,
              child: SuperText(
                richText: TextSpan(text: 'Text with explicit strut'),
                strutStyle: explicitStrut,
              ),
            ),
          ),
        );

        final richText = tester.widget<LayoutAwareRichText>(
          find.byType(LayoutAwareRichText),
        );
        expect(richText.strutStyle, explicitStrut);
      },
    );

    testWidgets('updates text layout when the inherited strut style changes', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestScaffold(
          child: const SuperTextStrutStyle(
            strutStyle: inheritedStrut,
            child: SuperText(
              richText: TextSpan(text: 'Text with changing strut'),
            ),
          ),
        ),
      );

      LayoutAwareRichText richText = tester.widget<LayoutAwareRichText>(
        find.byType(LayoutAwareRichText),
      );
      expect(richText.strutStyle, inheritedStrut);

      await tester.pumpWidget(
        buildTestScaffold(
          child: const SuperTextStrutStyle(
            strutStyle: explicitStrut,
            child: SuperText(
              richText: TextSpan(text: 'Text with changing strut'),
            ),
          ),
        ),
      );

      richText = tester.widget<LayoutAwareRichText>(
        find.byType(LayoutAwareRichText),
      );
      expect(richText.strutStyle, explicitStrut);
    });
  });
}
