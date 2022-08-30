import 'package:collection/collection.dart';
import 'package:flutter/painting.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/styles.dart';
import 'package:super_editor/src/default_editor/horizontal_rule.dart';
import 'package:super_editor/src/default_editor/image.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

import '../../core/document.dart';
import '_presenter.dart';

/// [SingleColumnLayoutStylePhase] that applies visual selections to each component,
/// e.g., text selections, image selections, caret positioning.
class SingleColumnLayoutSelectionStyler extends SingleColumnLayoutStylePhase implements NonPrimarySelectionListener {
  SingleColumnLayoutSelectionStyler({
    required Document document,
    required DocumentComposer composer,
    required SelectionStyles primaryUserSelectionStyles,
    NonPrimarySelectionStyler? nonPrimarySelectionStyler,
  })  : _document = document,
        _composer = composer,
        _selectionStyles = primaryUserSelectionStyles,
        _nonPrimarySelectionStyler = nonPrimarySelectionStyler {
    // Our styles need to be re-applied whenever the document selection changes.
    _composer.selectionNotifier.addListener(markDirty);
    _composer.addNonPrimarySelectionListener(this);
  }

  @override
  void dispose() {
    _composer.selectionNotifier.removeListener(markDirty);
    _composer.removeNonPrimarySelectionListener(this);
    super.dispose();
  }

  final Document _document;
  final DocumentComposer _composer;
  final NonPrimarySelectionStyler? _nonPrimarySelectionStyler;

  SelectionStyles _selectionStyles;
  set selectionStyles(SelectionStyles selectionStyles) {
    if (selectionStyles == _selectionStyles) {
      return;
    }

    _selectionStyles = selectionStyles;
    markDirty();
  }

  bool _shouldDocumentShowCaret = false;
  set shouldDocumentShowCaret(bool newValue) {
    if (newValue == _shouldDocumentShowCaret) {
      return;
    }

    _shouldDocumentShowCaret = newValue;
    editorStyleLog.fine("Change to 'document should show caret': $_shouldDocumentShowCaret");
    markDirty();
  }

  @override
  void onSelectionAdded(NonPrimarySelection selection) => markDirty();
  @override
  void onSelectionChanged(NonPrimarySelection selection) => markDirty();
  @override
  void onSelectionRemoved(String id) => markDirty();

  @override
  SingleColumnLayoutViewModel style(Document document, SingleColumnLayoutViewModel viewModel) {
    editorStyleLog.info("(Re)calculating selection view model for document layout");
    editorStyleLog.fine("Applying selection to components: ${_composer.selection}");
    return SingleColumnLayoutViewModel(
      padding: viewModel.padding,
      componentViewModels: [
        for (final previousViewModel in viewModel.componentViewModels) //
          _applySelection(previousViewModel.copy()),
      ],
    );
  }

  SingleColumnLayoutComponentViewModel _applySelection(SingleColumnLayoutComponentViewModel viewModel) {
    final documentSelection = _composer.selection;
    final node = _document.getNodeById(viewModel.nodeId)!;

    DocumentNodeSelection? nodeSelection;
    if (documentSelection != null) {
      late List<DocumentNode> selectedNodes;
      try {
        selectedNodes = _document.getNodesInside(
          documentSelection.base,
          documentSelection.extent,
        );
      } catch (exception) {
        // This situation can happen in the moment between a document change and
        // a corresponding selection change. For example: deleting an image and
        // replacing it with an empty paragraph. Between the doc change and the
        // selection change, the old image selection is applied to the new paragraph.
        // This results in an exception.
        //
        // TODO: introduce a unified event ledger that combines related behaviors
        //       into atomic transactions (#423)
        selectedNodes = [];
      }
      nodeSelection =
          _computeNodeSelection(documentSelection: documentSelection, selectedNodes: selectedNodes, node: node);
    }

    editorStyleLog.fine("Node selection (${node.id}): $nodeSelection");
    if (node is TextNode) {
      final styledSelections = _computeStyledSelectionsForText(
        composer: _composer,
        node: node,
      );

      final textSelection = nodeSelection == null || nodeSelection.nodeSelection is! TextSelection
          ? null
          : nodeSelection.nodeSelection as TextSelection;
      if (nodeSelection != null && nodeSelection.nodeSelection is! TextSelection) {
        editorStyleLog.shout(
            'ERROR: Building a paragraph component but the selection is not a TextSelection. Node: ${node.id}, Selection: ${nodeSelection.nodeSelection}');
      }
      final showCaret = _shouldDocumentShowCaret && nodeSelection != null ? nodeSelection.isExtent : false;

      editorStyleLog.finer(' - ${node.id}: $nodeSelection');
      if (showCaret) {
        editorStyleLog.finer('   - ^ showing caret');
      }

      editorStyleLog.finer(' - building a paragraph with selection:');
      editorStyleLog.finer('   - base: ${textSelection?.base}');
      editorStyleLog.finer('   - extent: ${textSelection?.extent}');

      if (viewModel is TextComponentViewModel) {
        viewModel.styledSelections = styledSelections;
      }
    }
    if (viewModel is ImageComponentViewModel) {
      viewModel.styledSelections = _computeStyledSelectionsForUpstreamDownstreamNodes(composer: _composer, node: node);
    }
    if (viewModel is HorizontalRuleComponentViewModel) {
      viewModel.styledSelections = _computeStyledSelectionsForUpstreamDownstreamNodes(composer: _composer, node: node);
    }

    return viewModel;
  }

  List<StyledSelection<TextSelection>> _computeStyledSelectionsForText({
    required DocumentComposer composer,
    required DocumentNode node,
  }) {
    final styledSelections = <StyledSelection<TextSelection>>[];

    for (final nonPrimarySelection in _composer.getAllNonPrimarySelections()) {
      late List<DocumentNode> selectedNodes;
      try {
        selectedNodes = _document.getNodesInside(
          nonPrimarySelection.selection.base,
          nonPrimarySelection.selection.extent,
        );
      } catch (exception) {
        // This situation can happen in the moment between a document change and
        // a corresponding selection change. For example: deleting an image and
        // replacing it with an empty paragraph. Between the doc change and the
        // selection change, the old image selection is applied to the new paragraph.
        // This results in an exception.
        //
        // TODO: introduce a unified event ledger that combines related behaviors
        //       into atomic transactions (#423)
        selectedNodes = [];
      }

      final nodeSelection = _computeNodeSelection(
        documentSelection: nonPrimarySelection.selection,
        selectedNodes: selectedNodes,
        node: node,
      );

      if (nodeSelection?.nodeSelection is TextNodeSelection) {
        final textNodeSelection = nodeSelection!.nodeSelection as TextNodeSelection;
        final textSelection =
            TextSelection(baseOffset: textNodeSelection.baseOffset, extentOffset: textNodeSelection.extentOffset);

        styledSelections.add(StyledSelection(
          selection: textSelection,
          hasCaret: false, // non-primary selections never have a caret
          styles: _nonPrimarySelectionStyler!(nonPrimarySelection)!,
        ));
      }
    }

    final documentSelection = _composer.selection;
    if (documentSelection != null) {
      late List<DocumentNode> selectedNodes;
      try {
        selectedNodes = _document.getNodesInside(
          documentSelection.base,
          documentSelection.extent,
        );
      } catch (exception) {
        // This situation can happen in the moment between a document change and
        // a corresponding selection change. For example: deleting an image and
        // replacing it with an empty paragraph. Between the doc change and the
        // selection change, the old image selection is applied to the new paragraph.
        // This results in an exception.
        //
        // TODO: introduce a unified event ledger that combines related behaviors
        //       into atomic transactions (#423)
        selectedNodes = [];
      }

      final nodeSelection =
          _computeNodeSelection(documentSelection: documentSelection, selectedNodes: selectedNodes, node: node);

      if (nodeSelection?.nodeSelection is TextNodeSelection) {
        final textNodeSelection = nodeSelection!.nodeSelection as TextNodeSelection;
        final textSelection =
            TextSelection(baseOffset: textNodeSelection.baseOffset, extentOffset: textNodeSelection.extentOffset);

        styledSelections.add(StyledSelection(
          selection: textSelection,
          hasCaret: composer.selection!.extent.nodeId == node.id,
          styles: SelectionStyles(
            selectionColor: _selectionStyles.selectionColor,
            highlightEmptyTextBlocks: nodeSelection.highlightWhenEmpty,
          ),
        ));
      }
    }

    return styledSelections;
  }

  List<StyledSelection<UpstreamDownstreamNodeSelection>> _computeStyledSelectionsForUpstreamDownstreamNodes({
    required DocumentComposer composer,
    required DocumentNode node,
  }) {
    final styledSelections = <StyledSelection<UpstreamDownstreamNodeSelection>>[];

    for (final nonPrimarySelection in _composer.getAllNonPrimarySelections()) {
      late List<DocumentNode> selectedNodes;
      try {
        selectedNodes = _document.getNodesInside(
          nonPrimarySelection.selection.base,
          nonPrimarySelection.selection.extent,
        );
      } catch (exception) {
        // This situation can happen in the moment between a document change and
        // a corresponding selection change. For example: deleting an image and
        // replacing it with an empty paragraph. Between the doc change and the
        // selection change, the old image selection is applied to the new paragraph.
        // This results in an exception.
        //
        // TODO: introduce a unified event ledger that combines related behaviors
        //       into atomic transactions (#423)
        selectedNodes = [];
      }

      final nodeSelection = _computeNodeSelection(
        documentSelection: nonPrimarySelection.selection,
        selectedNodes: selectedNodes,
        node: node,
      );

      if (nodeSelection?.nodeSelection is UpstreamDownstreamNodeSelection) {
        final upstreamDownstreamSelection = nodeSelection!.nodeSelection as UpstreamDownstreamNodeSelection;

        styledSelections.add(StyledSelection(
          selection: upstreamDownstreamSelection,
          // TODO: the styler decides whether to highlight an empty block, but it shouldn't.
          // That decision needs to be made based on whether the user is selecting multiple
          // blocks.
          styles: _nonPrimarySelectionStyler!(nonPrimarySelection)!,
        ));
      }
    }

    final documentSelection = _composer.selection;
    if (documentSelection != null) {
      late List<DocumentNode> selectedNodes;
      try {
        selectedNodes = _document.getNodesInside(
          documentSelection.base,
          documentSelection.extent,
        );
      } catch (exception) {
        // This situation can happen in the moment between a document change and
        // a corresponding selection change. For example: deleting an image and
        // replacing it with an empty paragraph. Between the doc change and the
        // selection change, the old image selection is applied to the new paragraph.
        // This results in an exception.
        //
        // TODO: introduce a unified event ledger that combines related behaviors
        //       into atomic transactions (#423)
        selectedNodes = [];
      }

      final nodeSelection =
          _computeNodeSelection(documentSelection: documentSelection, selectedNodes: selectedNodes, node: node);

      if (nodeSelection?.nodeSelection is UpstreamDownstreamNodeSelection) {
        final upstreamDownstreamSelection = nodeSelection!.nodeSelection as UpstreamDownstreamNodeSelection;

        styledSelections.add(StyledSelection(
          selection: upstreamDownstreamSelection,
          styles: SelectionStyles(
            selectionColor: _selectionStyles.selectionColor,
            highlightEmptyTextBlocks: nodeSelection.highlightWhenEmpty,
          ),
        ));
      }
    }

    return styledSelections;
  }

  /// Computes the [DocumentNodeSelection] for the individual `nodeId` based on
  /// the total list of selected nodes.
  DocumentNodeSelection? _computeNodeSelection({
    required DocumentSelection? documentSelection,
    required List<DocumentNode> selectedNodes,
    required DocumentNode node,
  }) {
    if (documentSelection == null) {
      return null;
    }

    editorStyleLog.finer('_computeNodeSelection(): ${node.id}');
    editorStyleLog.finer(' - base: ${documentSelection.base.nodeId}');
    editorStyleLog.finer(' - extent: ${documentSelection.extent.nodeId}');

    if (documentSelection.base.nodeId == documentSelection.extent.nodeId) {
      editorStyleLog.finer(' - selection is within 1 node.');
      if (documentSelection.base.nodeId != node.id) {
        // Only 1 node is selected and its not the node we're interested in. Return.
        editorStyleLog.finer(' - this node is not selected. Returning null.');
        return null;
      }

      editorStyleLog.finer(' - this node has the selection');
      final baseNodePosition = documentSelection.base.nodePosition;
      final extentNodePosition = documentSelection.extent.nodePosition;
      late NodeSelection? nodeSelection;
      try {
        nodeSelection = node.computeSelection(base: baseNodePosition, extent: extentNodePosition);
      } catch (exception) {
        // This situation can happen in the moment between a document change and
        // a corresponding selection change. For example: deleting an image and
        // replacing it with an empty paragraph. Between the doc change and the
        // selection change, the old image selection is applied to the new paragraph.
        // This results in an exception.
        //
        // TODO: introduce a unified event ledger that combines related behaviors
        //       into atomic transactions (#423)
        return null;
      }
      editorStyleLog.finer(' - node selection: $nodeSelection');

      return DocumentNodeSelection(
        nodeId: node.id,
        nodeSelection: nodeSelection,
        isBase: true,
        isExtent: true,
      );
    } else {
      // Log all the selected nodes.
      editorStyleLog.finer(' - selection contains multiple nodes:');
      for (final node in selectedNodes) {
        editorStyleLog.finer('   - ${node.id}');
      }

      if (selectedNodes.firstWhereOrNull((selectedNode) => selectedNode.id == node.id) == null) {
        // The document selection does not contain the node we're interested in. Return.
        editorStyleLog.finer(' - this node is not in the selection');
        return null;
      }

      if (selectedNodes.first.id == node.id) {
        editorStyleLog.finer(' - this is the first node in the selection');
        // Multiple nodes are selected and the node that we're interested in
        // is the top node in that selection. Therefore, this node is
        // selected from a position down to its bottom.
        final isBase = node.id == documentSelection.base.nodeId;
        return DocumentNodeSelection(
          nodeId: node.id,
          nodeSelection: node.computeSelection(
            base: isBase ? documentSelection.base.nodePosition : node.endPosition,
            extent: isBase ? node.endPosition : documentSelection.extent.nodePosition,
          ),
          isBase: isBase,
          isExtent: !isBase,
          highlightWhenEmpty: isBase,
        );
      } else if (selectedNodes.last.id == node.id) {
        editorStyleLog.finer(' - this is the last node in the selection');
        // Multiple nodes are selected and the node that we're interested in
        // is the bottom node in that selection. Therefore, this node is
        // selected from the beginning down to some position.
        final isBase = node.id == documentSelection.base.nodeId;
        return DocumentNodeSelection(
          nodeId: node.id,
          nodeSelection: node.computeSelection(
            base: isBase ? node.beginningPosition : node.beginningPosition,
            extent: isBase ? documentSelection.base.nodePosition : documentSelection.extent.nodePosition,
          ),
          isBase: isBase,
          isExtent: !isBase,
          highlightWhenEmpty: isBase,
        );
      } else {
        editorStyleLog.finer(' - this node is fully selected within the selection');
        // Multiple nodes are selected and this node is neither the top
        // or the bottom node, therefore this entire node is selected.
        return DocumentNodeSelection(
          nodeId: node.id,
          nodeSelection: node.computeSelection(
            base: node.beginningPosition,
            extent: node.endPosition,
          ),
          highlightWhenEmpty: true,
        );
      }
    }
  }
}

/// Function called to configure [SelectionStyles] for a given [nonPrimarySelection].
///
/// If you don't want to display anything for this selection, return `null`.
typedef NonPrimarySelectionStyler = SelectionStyles? Function(NonPrimarySelection nonPrimarySelection);

/// Description of a selection within a specific node in a document.
///
/// The [nodeSelection] only describes the selection in the particular node
/// that [nodeId] points to. The document might have a selection that spans
/// multiple nodes but this only regards the part of that total selection that
/// affects the single node.
///
/// The [SelectionType] is a generic subtype of [NodeSelection], e.g., a
/// [TextNodeSelection] that describes which characters of text are
/// selected within the text node.
class DocumentNodeSelection<SelectionType extends NodeSelection> {
  DocumentNodeSelection({
    required this.nodeId,
    required this.nodeSelection,
    this.isBase = false,
    this.isExtent = false,
    this.highlightWhenEmpty = false,
  });

  /// The ID of the node that's selected.
  final String nodeId;

  /// The selection within the given node.
  final SelectionType? nodeSelection;

  /// Whether this [DocumentNodeSelection] forms the base position of a larger
  /// document selection, `false` otherwise.
  ///
  /// [isBase] is `true` iff [nodeId] is the same as [DocumentSelection.base.nodeId].
  final bool isBase;

  /// Whether this [DocumentNodeSelection] forms the extent position of a
  /// larger document selection, `false` otherwise.
  ///
  /// [isExtent] is `true` iff [nodeId] is the same as [DocumentSelection.extent.nodeId].
  final bool isExtent;

  /// Whether the component rendering this [DocumentNodeSelection] should
  /// paint a highlight even when the given node has no content, `false`
  /// otherwise.
  ///
  /// For example: the user selects across multiple paragraphs. One of those
  /// inner paragraphs is empty. We want to paint a small highlight where that
  /// empty paragraph sits.
  final bool highlightWhenEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentNodeSelection &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          nodeSelection == other.nodeSelection;

  @override
  int get hashCode => nodeId.hashCode ^ nodeSelection.hashCode;

  @override
  String toString() {
    return '[DocumentNodeSelection] - node: "$nodeId", selection: ($nodeSelection)';
  }
}
