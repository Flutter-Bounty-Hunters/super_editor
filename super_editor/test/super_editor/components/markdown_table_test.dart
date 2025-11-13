import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../supereditor_test_tools.dart';

void main() {
  group('SuperEditor > Markdown Table >', () {
    group('gestures >', () {
      testWidgetsOnAllPlatforms('places caret at left edge when tapping at the left side', (tester) async {
        await _pumpTestApp(tester);

        // Tap close to the left edge of the table to place the caret
        // upstream on the table.
        await tester.tapAt(
          tester.getTopLeft(find.byType(MarkdownTableComponent)) + const Offset(20, 20),
        );
        await tester.pump();

        // Ensure the caret is placed at the upstream side of the table.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: SuperEditorInspector.findDocument()!.first.id,
              nodePosition: const UpstreamDownstreamNodePosition.upstream(),
            ),
          ),
        );

        // Allow the long press timer to resolve.
        await tester.pumpAndSettle();
      });

      testWidgetsOnAllPlatforms('places caret at right edge when tapping at the right side', (tester) async {
        await _pumpTestApp(tester);

        // Tap close to the right edge of the table to place the caret
        // downstream on the table.
        await tester.tapAt(
          tester.getTopRight(find.byType(MarkdownTableComponent)) + const Offset(-20, 20),
        );
        await tester.pump();

        // Ensure the caret is placed at the downstream side of the table.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: SuperEditorInspector.findDocument()!.first.id,
              nodePosition: const UpstreamDownstreamNodePosition.downstream(),
            ),
          ),
        );

        // Allow the long press timer to resolve.
        await tester.pumpAndSettle();
      });

      testWidgetsOnAllPlatforms('places an expanded selection when double tapping', (tester) async {
        await _pumpTestApp(tester);

        // Double tap in the middle of the table to select the entire table.
        await tester.tapAt(
          tester.getCenter(find.byType(MarkdownTableComponent)),
        );
        await tester.pump(kTapMinTime);
        await tester.tapAt(
          tester.getCenter(find.byType(MarkdownTableComponent)),
        );
        await tester.pump(kTapMinTime);

        // The entire table should be selected.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection(
            base: DocumentPosition(
              nodeId: SuperEditorInspector.findDocument()!.first.id,
              nodePosition: const UpstreamDownstreamNodePosition.upstream(),
            ),
            extent: DocumentPosition(
              nodeId: SuperEditorInspector.findDocument()!.first.id,
              nodePosition: const UpstreamDownstreamNodePosition.downstream(),
            ),
          ),
        );
      });
    });
  });
}

Future<void> _pumpTestApp(WidgetTester tester) async {
  await tester //
      .createDocument()
      .fromMarkdown('''
| Header 1 | Header 2 |
|---|---|
| Cell 1 | Cell 2 |
| Cell 3 | Cell 4 |''') //
      .withAddedComponents([const MarkdownTableComponentBuilder()]) //
      .pump();
}
