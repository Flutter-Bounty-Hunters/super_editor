import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:super_editor/super_test.dart';

void main() {
  group('SuperEditor > RTL mode >', () {
    testGoldensOnAllPlatforms(
      'inserts text and paints caret on the left side of paragraph for downstream position',
      (tester) async {
        await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .withInputSource(TextInputSource.ime)
            .pump();

        // Place the caret at the beginning of the paragraph.
        await tester.placeCaretInParagraph('1', 0);

        // Type the text "Example".
        await tester.ime.typeText(
          'مثال',
          getter: imeClientGetter,
        );

        await screenMatchesGolden(
            tester, 'super-editor-rtl-caret-at-leftmost-character-paragraph-${defaultTargetPlatform.name}');
      },
      windowSize: goldenSizeSmall,
    );

    testGoldensOnAllPlatforms(
      'inserts text and paints caret on the left side of unordered list item for downstream position',
      (tester) async {
        await tester //
            .createDocument()
            .withCustomContent(
              MutableDocument(
                nodes: [
                  ListItemNode.unordered(id: '1', text: AttributedText()),
                ],
              ),
            )
            .withInputSource(TextInputSource.ime)
            .pump();

        // Place the caret at the beginning of the list item.
        await tester.placeCaretInParagraph('1', 0);

        // Type the text "Example".
        await tester.ime.typeText(
          'مثال',
          getter: imeClientGetter,
        );

        await screenMatchesGolden(
            tester, 'super-editor-rtl-caret-at-leftmost-character-unordered-list-item-${defaultTargetPlatform.name}');
      },
      windowSize: goldenSizeSmall,
    );

    testGoldensOnAllPlatforms(
      'inserts text and paints caret on the left side of ordered list item for downstream position',
      (tester) async {
        await tester //
            .createDocument()
            .withCustomContent(
              MutableDocument(
                nodes: [
                  ListItemNode.ordered(id: '1', text: AttributedText()),
                ],
              ),
            )
            .withInputSource(TextInputSource.ime)
            .pump();

        // Place the caret at the beginning of the list item.
        await tester.placeCaretInParagraph('1', 0);

        // Type the text "Example".
        await tester.ime.typeText(
          'مثال',
          getter: imeClientGetter,
        );

        await screenMatchesGolden(
            tester, 'super-editor-rtl-caret-at-leftmost-character-ordered-list-item-${defaultTargetPlatform.name}');
      },
      windowSize: goldenSizeSmall,
    );

    testGoldensOnAllPlatforms(
      'inserts text and paints caret on the left side of task for downstream position',
      (tester) async {
        await tester //
            .createDocument()
            .withCustomContent(
              MutableDocument(
                nodes: [
                  TaskNode(id: '1', text: AttributedText(), isComplete: false),
                ],
              ),
            )
            .withInputSource(TextInputSource.ime)
            .pump();

        // Place the caret at the beginning of the task.
        await tester.placeCaretInParagraph('1', 0);

        // Type the text "Example".
        await tester.ime.typeText(
          'مثال',
          getter: imeClientGetter,
        );

        await screenMatchesGolden(
            tester, 'super-editor-rtl-caret-at-leftmost-character-task-${defaultTargetPlatform.name}');
      },
      windowSize: goldenSizeSmall,
    );
  });
}
