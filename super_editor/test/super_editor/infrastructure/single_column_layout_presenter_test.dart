import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/default_editor/layout_single_column/_styler_composing_region.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group("SingleColumnLayoutPresenter", () {
    test("keeps the components of the paragraphs away from the one that's typed in", () {
      final pipeline = _Pipeline(_paragraphs(7));
      pipeline.placeCaret("4", 0);
      final before = pipeline.components;

      pipeline.type("x", "4", 0);
      final after = pipeline.components;

      for (final id in ["1", "2", "6", "7"]) {
        expect(after[id], same(before[id]), reason: "paragraph $id is two or more away from the edit");
      }
      expect((after["4"] as TextComponentViewModel).text.toPlainText(), startsWith("x"));
      pipeline.expectStyledAsFromScratch();
    });

    test("restyles only the paragraphs the caret leaves and enters", () {
      final pipeline = _Pipeline(_paragraphs(7));
      pipeline.placeCaret("2", 3);
      final before = pipeline.components;

      pipeline.placeCaret("5", 1);
      final after = pipeline.components;

      for (final id in ["1", "3", "4", "6", "7"]) {
        expect(after[id], same(before[id]), reason: "paragraph $id never had the caret");
      }
      expect((after["2"] as TextComponentViewModel).selection, isNull);
      expect((after["5"] as TextComponentViewModel).selection, const TextSelection.collapsed(offset: 1));
      pipeline.expectStyledAsFromScratch();
    });

    test("restyles the paragraph after one that becomes a header", () {
      final pipeline = _Pipeline(
        _paragraphs(5),
        stylesheet: defaultStylesheet.copyWith(
          addRulesAfter: [
            StyleRule(
              const BlockSelector("paragraph").after("header1"),
              (doc, docNode) => {Styles.padding: const CascadingPadding.only(top: 40)},
            ),
          ],
        ),
      );
      pipeline.components;

      pipeline.editor.execute([ChangeParagraphBlockTypeRequest(nodeId: "2", blockType: header1Attribution)]);

      expect((pipeline.components["3"]!.padding as EdgeInsets).top, 40);
      pipeline.expectStyledAsFromScratch();
    });

    test("applies new layout styles in a node's metadata", () {
      final pipeline = _Pipeline(_paragraphs(3));
      pipeline.components;

      pipeline.editor.execute([
        const ChangeSingleColumnLayoutComponentStylesRequest(
          nodeId: "2",
          styles: SingleColumnLayoutComponentStyles(width: 300),
        ),
      ]);

      expect(pipeline.components["2"]!.maxWidth, 300);
      pipeline.expectStyledAsFromScratch();
    });

    test("renumbers the list items after one that becomes a paragraph", () {
      final pipeline = _Pipeline([
        for (int i = 1; i <= 4; i += 1) ListItemNode.ordered(id: "$i", text: AttributedText("Item $i")),
      ]);
      pipeline.components;

      pipeline.editor.execute([ConvertListItemToParagraphRequest(nodeId: "2")]);

      final after = pipeline.components;
      expect((after["3"] as OrderedListItemComponentViewModel).ordinalValue, 1);
      expect((after["4"] as OrderedListItemComponentViewModel).ordinalValue, 2);
      pipeline.expectStyledAsFromScratch();
    });

    test("moves the composing region's underline to the paragraph it moves to", () {
      final pipeline = _Pipeline(_paragraphs(5));
      pipeline.composeIn("2");
      pipeline.components;

      pipeline.composeIn("4");

      final after = pipeline.components;
      expect((after["2"] as TextComponentViewModel).composingRegion, isNull);
      expect((after["4"] as TextComponentViewModel).composingRegion, const TextRange(start: 0, end: 4));
      pipeline.expectStyledAsFromScratch();
    });

    test("restyles every component when the stylesheet changes", () {
      final pipeline = _Pipeline(_paragraphs(3));
      pipeline.components;

      pipeline.stylesheet = defaultStylesheet.copyWith(documentPadding: const EdgeInsets.all(12));

      pipeline.expectStyledAsFromScratch();
    });

    test("styles every component when a paragraph is inserted", () {
      final pipeline = _Pipeline(_paragraphs(4));
      pipeline.placeCaret("2", 0);
      pipeline.components;

      pipeline.editor.execute([
        InsertNodeAfterNodeRequest(
          existingNodeId: "2",
          newNode: ParagraphNode(id: "new", text: AttributedText("Inserted")),
        ),
      ]);

      expect(pipeline.components.keys, ["1", "2", "new", "3", "4"]);
      pipeline.expectStyledAsFromScratch();
    });
  });
}

List<DocumentNode> _paragraphs(int count) => [
      for (int i = 1; i <= count; i += 1) ParagraphNode(id: "$i", text: AttributedText("Paragraph $i")),
    ];

/// super_editor's standard style phases over a document that's edited through
/// an [Editor].
class _Pipeline {
  _Pipeline(List<DocumentNode> nodes, {Stylesheet? stylesheet})
      : document = MutableDocument(nodes: nodes),
        composer = MutableDocumentComposer(),
        _stylesheet = stylesheet ?? defaultStylesheet {
    editor = createDefaultDocumentEditor(document: document, composer: composer);
    _stylesheetStyler = SingleColumnStylesheetStyler(stylesheet: _stylesheet);
    _presenter = _createPresenter(_stylesheetStyler);
  }

  final MutableDocument document;
  final MutableDocumentComposer composer;
  late final Editor editor;
  late final SingleColumnStylesheetStyler _stylesheetStyler;
  late final SingleColumnLayoutPresenter _presenter;

  Stylesheet _stylesheet;
  set stylesheet(Stylesheet stylesheet) {
    _stylesheet = stylesheet;
    _stylesheetStyler.stylesheet = stylesheet;
  }

  /// The styled components, by node ID, after the presenter caught up.
  Map<String, SingleColumnLayoutComponentViewModel> get components {
    _presenter.updateViewModel();
    return {
      for (final component in _presenter.viewModel.componentViewModels) component.nodeId: component,
    };
  }

  void placeCaret(String nodeId, int offset) {
    editor.execute([
      ChangeSelectionRequest(
        DocumentSelection.collapsed(
          position: DocumentPosition(nodeId: nodeId, nodePosition: TextNodePosition(offset: offset)),
        ),
        SelectionChangeType.placeCaret,
        SelectionReason.userInteraction,
      ),
    ]);
  }

  void type(String text, String nodeId, int offset) {
    editor.execute([
      InsertTextRequest(
        documentPosition: DocumentPosition(nodeId: nodeId, nodePosition: TextNodePosition(offset: offset)),
        textToInsert: text,
        attributions: {},
      ),
    ]);
  }

  /// Puts the composing region on the first 4 characters of [nodeId].
  void composeIn(String nodeId) {
    editor.execute([
      ChangeComposingRegionRequest(
        DocumentRange(
          start: DocumentPosition(nodeId: nodeId, nodePosition: const TextNodePosition(offset: 0)),
          end: DocumentPosition(nodeId: nodeId, nodePosition: const TextNodePosition(offset: 4)),
        ),
      ),
    ]);
  }

  /// Expects the components to be what a new presenter makes of the document
  /// as it is now, which styles every component from scratch.
  void expectStyledAsFromScratch() {
    final fromScratch = _createPresenter(SingleColumnStylesheetStyler(stylesheet: _stylesheet));
    final expected = fromScratch.viewModel;
    fromScratch.dispose();

    final actual = components;
    expect(_presenter.viewModel.padding, expected.padding);
    expect(actual.values.toList(), expected.componentViewModels);
    for (final component in expected.componentViewModels) {
      if (component is TextComponentViewModel) {
        // Text styles aren't part of a component's equality.
        expect(
          (actual[component.nodeId] as TextComponentViewModel).textStyleBuilder({}),
          component.textStyleBuilder({}),
          reason: "the text style of ${component.nodeId}",
        );
      }
    }
  }

  SingleColumnLayoutPresenter _createPresenter(SingleColumnStylesheetStyler stylesheetStyler) {
    return SingleColumnLayoutPresenter(
      document: document,
      componentBuilders: defaultComponentBuilders,
      pipeline: [
        stylesheetStyler,
        SingleColumnLayoutCustomComponentStyler(),
        CustomUnderlineStyler(),
        SingleColumnLayoutComposingRegionStyler(
          document: document,
          composingRegion: composer.composingRegion,
          showComposingUnderline: true,
        ),
        SingleColumnLayoutSelectionStyler(
          document: document,
          selection: composer.selectionNotifier,
          selectionStyles: defaultSelectionStyle,
        )..shouldDocumentShowCaret = true,
      ],
    );
  }
}
