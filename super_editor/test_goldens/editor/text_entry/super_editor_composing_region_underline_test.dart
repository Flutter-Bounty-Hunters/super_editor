import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_test.dart';

void main() {
  group("SuperEditor > text entry > composing region >", () {
    testGoldensOnAndroid("is underlined in paragraph", _showsUnderlineInParagraph, windowSize: goldenSizeLongStrip);
    testGoldensOnAndroid("is underlined in blockquote", _showsUnderlineInBlockquote, windowSize: goldenSizeLongStrip);
    testGoldensOnAndroid("is underlined in list item", _showsUnderlineInListItem, windowSize: goldenSizeLongStrip);
    testGoldensOnAndroid("is underlined in task", _showsUnderlineInTask, windowSize: goldenSizeLongStrip);

    testGoldensOniOS("is underlined in paragraph", _showsUnderlineInParagraph, windowSize: goldenSizeLongStrip);
    testGoldensOniOS("is underlined in blockquote", _showsUnderlineInBlockquote, windowSize: goldenSizeLongStrip);
    testGoldensOniOS("is underlined in list item", _showsUnderlineInListItem, windowSize: goldenSizeLongStrip);
    testGoldensOniOS("is underlined in task", _showsUnderlineInTask, windowSize: goldenSizeLongStrip);

    testGoldensOnMac("is underlined in paragraph", _showsUnderlineInParagraph, windowSize: goldenSizeLongStrip);
    testGoldensOnMac("is underlined in blockquote", _showsUnderlineInBlockquote, windowSize: goldenSizeLongStrip);
    testGoldensOnMac("is underlined in list item", _showsUnderlineInListItem, windowSize: goldenSizeLongStrip);
    testGoldensOnMac("is underlined in task", _showsUnderlineInTask, windowSize: goldenSizeLongStrip);
  });

  group("SuperEditor > text entry > composing region >", () {
    testGoldensOnWindows("shows nothing in paragraph", _showsNothingInParagraph, windowSize: goldenSizeLongStrip);
    testGoldensOnWindows("shows nothing in blockquote", _showsNothingInBlockquote, windowSize: goldenSizeLongStrip);
    testGoldensOnWindows("shows nothing in list item", _showsNothingInListItem, windowSize: goldenSizeLongStrip);
    testGoldensOnWindows("shows nothing in task", _showsNothingInTask, windowSize: goldenSizeLongStrip);

    testGoldensOnLinux("shows nothing in paragraph", _showsNothingInParagraph, windowSize: goldenSizeLongStrip);
    testGoldensOnLinux("shows nothing in blockquote", _showsNothingInBlockquote, windowSize: goldenSizeLongStrip);
    testGoldensOnLinux("shows nothing in list item", _showsNothingInListItem, windowSize: goldenSizeLongStrip);
    testGoldensOnLinux("shows nothing in task", _showsNothingInTask, windowSize: goldenSizeLongStrip);
  });
}

Future<void> _showsUnderlineInParagraph(WidgetTester tester) async {
  final (editor, document) = await _pumpScaffold(tester, _paragraphMarkdown);

  await _simulateComposingRegion(tester, editor, document);

  // Ensure the composing region is underlined.
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFileWithPixelAllowance(
      "goldens/super-editor_text-entry_composing-region-shows-underline_paragraph_${defaultTargetPlatform.name}_1.png",
      7,
    ),
  );

  await _clearComposingRegion(tester, editor, document);

  // Ensure the underline disappeared now that the composing region is null.
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFileWithPixelAllowance(
      "goldens/super-editor_text-entry_composing-region-shows-underline_paragraph_${defaultTargetPlatform.name}_2.png",
      7,
    ),
  );
}

Future<void> _showsUnderlineInBlockquote(WidgetTester tester) async {
  final (editor, document) = await _pumpScaffold(tester, _blockquoteMarkdown);

  await _simulateComposingRegion(tester, editor, document);

  // Ensure the composing region is underlined.
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFileWithPixelAllowance(
      "goldens/super-editor_text-entry_composing-region-shows-underline_blockquote_${defaultTargetPlatform.name}_1.png",
      7,
    ),
  );

  await _clearComposingRegion(tester, editor, document);

  // Ensure the underline disappeared now that the composing region is null.
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFileWithPixelAllowance(
      "goldens/super-editor_text-entry_composing-region-shows-underline_blockquote_${defaultTargetPlatform.name}_2.png",
      7,
    ),
  );
}

Future<void> _showsNothingInParagraph(WidgetTester tester) async {
  final (editor, document) = await _pumpScaffold(tester, _paragraphMarkdown);

  await _simulateComposingRegion(tester, editor, document);

  // Ensure the composing region is underlined.
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFileWithPixelAllowance(
      "goldens/super-editor_text-entry_composing-region-showing-nothing_paragraph_${defaultTargetPlatform.name}.png",
      7,
    ),
  );
}

Future<void> _showsNothingInBlockquote(WidgetTester tester) async {
  final (editor, document) = await _pumpScaffold(tester, _blockquoteMarkdown);

  await _simulateComposingRegion(tester, editor, document);

  // Ensure the composing region is underlined.
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFileWithPixelAllowance(
      "goldens/super-editor_text-entry_composing-region-showing-nothing_blockquote_${defaultTargetPlatform.name}.png",
      7,
    ),
  );
}

Future<void> _showsUnderlineInListItem(WidgetTester tester) async {
  final (editor, document) = await _pumpScaffold(tester, _listItemMarkdown);

  await _simulateComposingRegion(tester, editor, document);

  // Ensure the composing region is underlined.
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFileWithPixelAllowance(
      "goldens/super-editor_text-entry_composing-region-shows-underline_list-item_${defaultTargetPlatform.name}_1.png",
      7,
    ),
  );

  await _clearComposingRegion(tester, editor, document);

  // Ensure the underline disappeared now that the composing region is null.
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFileWithPixelAllowance(
      "goldens/super-editor_text-entry_composing-region-shows-underline_list-item_${defaultTargetPlatform.name}_2.png",
      7,
    ),
  );
}

Future<void> _showsNothingInListItem(WidgetTester tester) async {
  final (editor, document) = await _pumpScaffold(tester, _listItemMarkdown);

  await _simulateComposingRegion(tester, editor, document);

  // Ensure the composing region is underlined.
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFileWithPixelAllowance(
      "goldens/super-editor_text-entry_composing-region-shows-nothing_list-item_${defaultTargetPlatform.name}.png",
      7,
    ),
  );
}

Future<void> _showsUnderlineInTask(WidgetTester tester) async {
  final (editor, document) = await _pumpScaffold(tester, _taskMarkdown);

  await _simulateComposingRegion(tester, editor, document);

  // Ensure the composing region is underlined.
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFileWithPixelAllowance(
      "goldens/super-editor_text-entry_composing-region-shows-underline_task_${defaultTargetPlatform.name}_1.png",
      7,
    ),
  );

  await _clearComposingRegion(tester, editor, document);

  // Ensure the underline disappeared now that the composing region is null.
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFileWithPixelAllowance(
      "goldens/super-editor_text-entry_composing-region-shows-underline_task_${defaultTargetPlatform.name}_2.png",
      7,
    ),
  );
}

Future<void> _showsNothingInTask(WidgetTester tester) async {
  final (editor, document) = await _pumpScaffold(tester, _taskMarkdown);

  await _simulateComposingRegion(tester, editor, document);

  // Ensure the composing region is underlined.
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFileWithPixelAllowance(
      "goldens/super-editor_text-entry_composing-region-shows-nothing_task_${defaultTargetPlatform.name}.png",
      7,
    ),
  );
}

Future<(Editor, Document)> _pumpScaffold(WidgetTester tester, String contentMarkdown) async {
  // TODO: Whenever we're able to create a TaskComponentBuilder without passing the Editor, refactor
  //       this setup to look like a normal SuperEditor test.
  final document = deserializeMarkdownToDocument(contentMarkdown);
  final composer = MutableDocumentComposer();
  final editor = createDefaultDocumentEditor(document: document, composer: composer);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: SuperEditor(
          editor: editor,
          componentBuilders: [
            TaskComponentBuilder(editor),
            ...defaultComponentBuilders,
          ],
          stylesheet: _stylesheet,
        ),
      ),
    ),
    debugShowCheckedModeBanner: false,
  ));

  return (editor, document);
}

Future<void> _simulateComposingRegion(WidgetTester tester, Editor editor, Document document) async {
  final nodeId = document.first.id;
  editor.execute([
    ChangeSelectionRequest(
      DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: nodeId,
          nodePosition: const TextNodePosition(offset: 23),
        ),
      ),
      SelectionChangeType.placeCaret,
      SelectionReason.userInteraction,
    ),
    ChangeComposingRegionRequest(
      DocumentRange(
        start: DocumentPosition(
          nodeId: nodeId,
          nodePosition: const TextNodePosition(offset: 22),
        ),
        end: DocumentPosition(
          nodeId: nodeId,
          nodePosition: const TextNodePosition(offset: 23),
        ),
      ),
    ),
  ]);
  await tester.pumpAndSettle();
}

Future<void> _clearComposingRegion(WidgetTester tester, Editor editor, Document document) async {
  final nodeId = document.first.id;
  editor.execute([
    ChangeSelectionRequest(
      DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: nodeId,
          nodePosition: const TextNodePosition(offset: 23),
        ),
      ),
      SelectionChangeType.placeCaret,
      SelectionReason.userInteraction,
    ),
    const ClearComposingRegionRequest(),
  ]);
  await tester.pump();
}

const _paragraphMarkdown = "Typing with composing a";
const _blockquoteMarkdown = "> Typing with composing a";
const _listItemMarkdown = " * Typing with composing a";
const _taskMarkdown = "- [ ] Typing with composing a";

/// A [StyleSheet] which applies the Roboto font for all nodes.
///
/// This is needed to use real font glyphs in the golden tests.
final _stylesheet = defaultStylesheet.copyWith(
  addRulesAfter: [
    StyleRule(BlockSelector.all, (doc, node) {
      return {
        Styles.textStyle: const TextStyle(
          fontFamily: 'Roboto',
        ),
      };
    })
  ],
);
