import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

import '../../core/document.dart';
import '_presenter.dart';

/// [SingleColumnLayoutStylePhase] that draws an underline beneath the text in the IME's
/// composing region.
class SingleColumnLayoutComposingRegionStyler extends SingleColumnLayoutStylePhase {
  SingleColumnLayoutComposingRegionStyler({
    required Document document,
    required ValueListenable<DocumentRange?> composingRegion,
    required bool showComposingUnderline,
  })  : _document = document,
        _composingRegion = composingRegion,
        _showComposingRegionUnderline = showComposingUnderline {
    // Our styles need to be re-applied whenever the composing region changes.
    _composingRegion.addListener(markDirty);
  }

  @override
  void dispose() {
    _composingRegion.removeListener(markDirty);
    super.dispose();
  }

  final Document _document;
  final ValueListenable<DocumentRange?> _composingRegion;
  final bool _showComposingRegionUnderline;

  /// The composing region as this phase last styled it.
  DocumentRange? _styledComposingRegion;

  /// Restyles the changed components and the ones the composing region was or
  /// is in.
  ///
  /// When there was no composing region, the last styling left every component
  /// as it came, so all of them are styled again.
  @override
  SingleColumnLayoutViewModel styleChanges(
    Document document,
    SingleColumnLayoutViewModel viewModel, {
    required SingleColumnLayoutViewModel previousOutput,
    required Set<String> changedNodeIds,
  }) {
    final documentComposingRegion = _composingRegion.value;
    final previousComposingRegion = _styledComposingRegion;
    if (documentComposingRegion == null || !_showComposingRegionUnderline || previousComposingRegion == null) {
      return style(document, viewModel);
    }

    final nodesWithComposingRegion = _nodesInside(documentComposingRegion);
    final nodesWithPreviousComposingRegion = _nodesInside(previousComposingRegion);
    if (nodesWithComposingRegion == null || nodesWithPreviousComposingRegion == null) {
      return style(document, viewModel);
    }
    _styledComposingRegion = documentComposingRegion;

    return restyleOnly(
      viewModel,
      nodeIds: {
        ...changedNodeIds,
        for (final node in nodesWithPreviousComposingRegion) node.id,
        for (final node in nodesWithComposingRegion) node.id,
      },
      previousOutput: previousOutput,
      styleComponent: (component) =>
          _applyComposingRegion(component.copy(), documentComposingRegion, nodesWithComposingRegion),
    );
  }

  @override
  SingleColumnLayoutViewModel style(Document document, SingleColumnLayoutViewModel viewModel) {
    editorStyleLog.info("(Re)calculating composing region view model for document layout");
    final documentComposingRegion = _composingRegion.value;
    _styledComposingRegion = null;
    if (documentComposingRegion == null) {
      // There's nothing for us to style if there's no composing region. Return the
      // view model as-is.
      return viewModel;
    }
    if (!_showComposingRegionUnderline) {
      // No underline is desired for the composing region. Return the view model as-is.
      return viewModel;
    }

    final nodesWithComposingRegion = _document.getNodesInside(
      documentComposingRegion.start,
      documentComposingRegion.end,
    );
    _styledComposingRegion = documentComposingRegion;

    return SingleColumnLayoutViewModel(
      padding: viewModel.padding,
      componentViewModels: [
        for (final previousViewModel in viewModel.componentViewModels) //
          _applyComposingRegion(previousViewModel.copy(), documentComposingRegion, nodesWithComposingRegion),
      ],
    );
  }

  /// The nodes [range] spans, or `null` when it doesn't fit the document.
  List<DocumentNode>? _nodesInside(DocumentRange range) {
    try {
      return _document.getNodesInside(range.start, range.end);
    } catch (exception) {
      return null;
    }
  }

  SingleColumnLayoutComponentViewModel _applyComposingRegion(
    SingleColumnLayoutComponentViewModel viewModel,
    DocumentRange documentComposingRegion,
    List<DocumentNode> nodesWithComposingRegion,
  ) {
    final node = _document.getNodeById(viewModel.nodeId)!;
    if (node is! TextNode) {
      // An IME composing region is only relevant for text nodes. Do nothing to this component's viewmodel.
      return viewModel;
    }
    if (viewModel is! TextComponentViewModel) {
      // All components for TextNode's should be of type TextComponentViewModel, but we check
      // just to be sure. In this case, it's not, for some reason. We can only style
      // TextComponentViewModel's. Do nothing to this view model.
      return viewModel;
    }

    editorStyleLog.fine("Applying composing region styles to node: ${node.id}");

    _DocumentNodeSelection? nodeSelection;
    nodeSelection = _computeNodeSelection(
      documentRange: documentComposingRegion,
      selectedNodes: nodesWithComposingRegion,
      node: node,
    );

    editorStyleLog.fine("Node selection (${node.id}): $nodeSelection");

    TextRange? textComposingRegion;
    if (documentComposingRegion.start.nodeId == documentComposingRegion.end.nodeId &&
        documentComposingRegion.start.nodeId == node.id) {
      // There's a composing region and it's entirely within this text node.
      // TODO: handle the possibility of a composing region extending across multiple nodes.
      final startPosition = documentComposingRegion.start.nodePosition as TextNodePosition;
      final endPosition = documentComposingRegion.end.nodePosition as TextNodePosition;
      textComposingRegion = TextRange(start: startPosition.offset, end: endPosition.offset);
    }

    viewModel
      ..composingRegion = textComposingRegion
      ..showComposingRegionUnderline = true;

    return viewModel;
  }

  /// Computes the [_DocumentNodeSelection] for the individual `nodeId` based on
  /// the total list of selected nodes.
  _DocumentNodeSelection? _computeNodeSelection({
    required DocumentRange? documentRange,
    required List<DocumentNode> selectedNodes,
    required DocumentNode node,
  }) {
    if (documentRange == null) {
      return null;
    }

    editorStyleLog.finer('_computeNodeSelection(): ${node.id}');
    editorStyleLog.finer(' - start: ${documentRange.start.nodeId}');
    editorStyleLog.finer(' - end: ${documentRange.end.nodeId}');

    if (documentRange.start.nodeId == documentRange.end.nodeId) {
      editorStyleLog.finer(' - selection is within 1 node.');
      if (documentRange.start.nodeId != node.id) {
        // Only 1 node is selected and its not the node we're interested in. Return.
        editorStyleLog.finer(' - this node is not selected. Returning null.');
        return null;
      }

      editorStyleLog.finer(' - this node has the selection');
      final baseNodePosition = documentRange.start.nodePosition;
      final extentNodePosition = documentRange.end.nodePosition;
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

      return _DocumentNodeSelection(
        nodeId: node.id,
        nodeSelection: nodeSelection,
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
        final isBase = node.id == documentRange.start.nodeId;
        return _DocumentNodeSelection(
          nodeId: node.id,
          nodeSelection: node.computeSelection(
            base: isBase ? documentRange.start.nodePosition : node.endPosition,
            extent: isBase ? node.endPosition : documentRange.end.nodePosition,
          ),
        );
      } else if (selectedNodes.last.id == node.id) {
        editorStyleLog.finer(' - this is the last node in the selection');
        // Multiple nodes are selected and the node that we're interested in
        // is the bottom node in that selection. Therefore, this node is
        // selected from the beginning down to some position.
        final isBase = node.id == documentRange.start.nodeId;
        return _DocumentNodeSelection(
          nodeId: node.id,
          nodeSelection: node.computeSelection(
            base: isBase ? node.beginningPosition : node.beginningPosition,
            extent: isBase ? documentRange.start.nodePosition : documentRange.end.nodePosition,
          ),
        );
      } else {
        editorStyleLog.finer(' - this node is fully selected within the selection');
        // Multiple nodes are selected and this node is neither the top
        // or the bottom node, therefore this entire node is selected.
        return _DocumentNodeSelection(
          nodeId: node.id,
          nodeSelection: node.computeSelection(
            base: node.beginningPosition,
            extent: node.endPosition,
          ),
        );
      }
    }
  }
}

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
class _DocumentNodeSelection<SelectionType extends NodeSelection> {
  _DocumentNodeSelection({
    required this.nodeId,
    required this.nodeSelection,
  });

  /// The ID of the node that's selected.
  final String nodeId;

  /// The selection within the given node.
  final SelectionType? nodeSelection;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _DocumentNodeSelection &&
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
