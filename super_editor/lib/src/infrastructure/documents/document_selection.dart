import 'dart:ui';

import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/layout_single_column/composite_nodes.dart';

/// Given a [DocumentSelection], which might span text and non-text content, extracts
/// all text from that selection as an un-styled `String`.
String extractTextFromSelection({
  required Document document,
  required DocumentSelection documentSelection,
}) {
  final basePath = document.getNodePathById(documentSelection.base.nodeId)!;
  final extentPath = document.getNodePathById(documentSelection.extent.nodeId)!;
  final basePosition = _projectToParentIfNeeded(
    basePath.rootNodeId,
    basePath,
    documentSelection.base.nodePosition,
  );
  final extentPosition = _projectToParentIfNeeded(
    extentPath.rootNodeId,
    extentPath,
    documentSelection.extent.nodePosition,
  );
  final selectedNodes = _getRootNodes(document, documentSelection);

  final buffer = StringBuffer();
  for (int i = 0; i < selectedNodes.length; ++i) {
    final selectedNode = selectedNodes[i];
    dynamic nodeSelection;

    if (i == 0) {
      // This is the first node and it may be partially selected.
      final baseSelectionPosition = selectedNode.id == basePath.rootNodeId ? basePosition : extentPosition;

      final extentSelectionPosition = selectedNodes.length > 1 ? selectedNode.endPosition : extentPosition;

      nodeSelection = selectedNode.computeSelection(
        base: baseSelectionPosition,
        extent: extentSelectionPosition,
      );
    } else if (i == selectedNodes.length - 1) {
      // This is the last node and it may be partially selected.
      final nodePosition = selectedNode.id == basePath.rootNodeId ? basePosition : extentPosition;

      nodeSelection = selectedNode.computeSelection(
        base: selectedNode.beginningPosition,
        extent: nodePosition,
      );
    } else {
      // This node is fully selected. Copy the whole thing.
      nodeSelection = selectedNode.computeSelection(
        base: selectedNode.beginningPosition,
        extent: selectedNode.endPosition,
      );
    }

    final nodeContent = selectedNode.copyContent(nodeSelection);
    if (nodeContent != null) {
      buffer.write(nodeContent);
      if (i < selectedNodes.length - 1) {
        buffer.writeln();
      }
    }
  }
  return buffer.toString();
}

NodePosition _projectToParentIfNeeded(String rootNodeId, NodePath path, NodePosition position) {
  if (path.nodeId == rootNodeId) {
    return position;
  } else {
    return CompositeNodePosition.projectPositionIntoParent(rootNodeId, path, position);
  }
}

List<DocumentNode> _getRootNodes(Document doc, DocumentSelection selection) {
  final basePath = doc.getNodePathById(selection.base.nodeId)!;
  final extentPath = doc.getNodePathById(selection.extent.nodeId)!;

  final result = <DocumentNode>[];
  final isDownstream = doc.getAffinityBetweenPaths(basePath, extentPath) == TextAffinity.downstream;
  String? nodeId = isDownstream ? basePath.rootNodeId : extentPath.rootNodeId;
  final untilNodeId = isDownstream ? extentPath.rootNodeId : basePath.rootNodeId;

  result.add(doc.getNodeById(nodeId)!);

  while (nodeId != null && nodeId != untilNodeId) {
    final node = doc.getNodeAfterById(nodeId, mode: NodeTraverseMode.sameParent);
    if (node != null) {
      result.add(node);
    }
    nodeId = node?.id;
  }

  return result;
}
