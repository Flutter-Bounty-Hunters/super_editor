import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

void main() {
  group('SuperEditor > single column layout >', () {
    testWidgetsOnAllPlatforms('updates component width when component styles are changed by the editor',
        (tester) async {
      // Pump an editor with an arbitrary size, so we know
      // the maximum width a component can be.
      final context = await tester
          .createDocument() //
          .withCustomContent(
            MutableDocument(nodes: [
              ParagraphNode(
                id: '1',
                text: AttributedText(),
                metadata: const SingleColumnLayoutComponentStyles(
                  width: 600.0,
                ).toMetadata(),
              ),
            ]),
          )
          .withEditorSize(const Size(1000.0, 5000.0))
          .useStylesheet(
            defaultStylesheet.copyWith(addRulesAfter: [
              StyleRule(
                BlockSelector.all,
                (doc, docNode) => {
                  // Zeroes the padding so the component is exactly
                  // the requested size.
                  Styles.padding: const CascadingPadding.all(0.0),
                },
              )
            ]),
          )
          .pump();

      // Ensure the component initially has the requested size.
      expect(SuperEditorInspector.findComponentSize('1').width, 600.0);

      // Change the width the of the first component in the document layout.
      context.editor.execute(
        const [
          ChangeSingleColumnLayoutComponentStylesRequest(
            nodeId: '1',
            styles: SingleColumnLayoutComponentStyles(
              width: 400.0,
            ),
          ),
        ],
      );
      await tester.pump();

      // Ensure the component width changed to the requested value.
      expect(SuperEditorInspector.findComponentSize('1').width, 400.0);
    });
  });

  testWidgetsOnAllPlatforms(
      'updates padding around each component in a document layout, when the overall document layout padding is changed by the editor',
      (tester) async {
    final context = await tester
        .createDocument() //
        .withSingleEmptyParagraph()
        .pump();

    // Ensure the component started with some padding.
    final paddingBefore = tester.widget<Padding>(find
        .ancestor(
          of: find.byWidget(SuperEditorInspector.findWidgetForComponent('1')),
          matching: find.byType(Padding),
        )
        .first);
    expect(paddingBefore.padding.horizontal, greaterThan(0.0));

    // Changes the padding.
    context.editor.execute(
      const [
        ChangeSingleColumnLayoutComponentStylesRequest(
          nodeId: '1',
          styles: SingleColumnLayoutComponentStyles(
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
    await tester.pump();

    // Ensure the padding was removed.
    final paddingAfter = tester.widget<Padding>(find
        .ancestor(
          of: find.byWidget(SuperEditorInspector.findWidgetForComponent('1')),
          matching: find.byType(Padding),
        )
        .first);
    expect(paddingAfter.padding.horizontal, 0.0);
  });
}
