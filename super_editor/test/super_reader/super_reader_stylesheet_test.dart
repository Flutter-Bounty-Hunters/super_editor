import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart';

import '../../lib/src/test/flutter_extensions/test_documents.dart';

void main() {
  group("SuperReader stylesheets", () {
    group("style text", () {
      testWidgetsOnArbitraryDesktop("with left alignment", (tester) async {
        await _pumpReader(tester, stylesheet: _stylesheetWithTextAlignment(TextAlign.left));

        expect(_findTextWithAlignment(TextAlign.left), findsOneWidget);
      });

      testWidgetsOnArbitraryDesktop("with center alignment", (tester) async {
        await _pumpReader(tester, stylesheet: _stylesheetWithTextAlignment(TextAlign.center));

        expect(_findTextWithAlignment(TextAlign.center), findsOneWidget);
      });

      testWidgetsOnArbitraryDesktop("with right alignment", (tester) async {
        await _pumpReader(tester, stylesheet: _stylesheetWithTextAlignment(TextAlign.right));

        expect(_findTextWithAlignment(TextAlign.right), findsOneWidget);
      });

      testWidgetsOnArbitraryDesktop("with justify alignment", (tester) async {
        await _pumpReader(tester, stylesheet: _stylesheetWithTextAlignment(TextAlign.justify));

        expect(_findTextWithAlignment(TextAlign.justify), findsOneWidget);
      });
    });
  });
}

Finder _findTextWithAlignment(TextAlign textAlign) =>
    find.byWidgetPredicate((widget) => (widget is SuperText) && widget.textAlign == textAlign);

Future<void> _pumpReader(
  WidgetTester tester, {
  required Stylesheet stylesheet,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SuperReader(
          editor: createDefaultDocumentEditor(
            document: singleParagraphDoc(),
            composer: MutableDocumentComposer(),
          ),
          stylesheet: stylesheet,
        ),
      ),
    ),
  );
}

Stylesheet _stylesheetWithTextAlignment(TextAlign textAlign) {
  return Stylesheet(
    inlineTextStyler: defaultInlineTextStyler,
    rules: [
      StyleRule(
        BlockSelector.all,
        (doc, docNode) {
          return {
            "textAlign": textAlign,
          };
        },
      ),
    ],
  );
}
