import 'dart:ui' show Offset;

import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/editor.dart';

/// Given a [DocumentSelection], which might span text and non-text content, extracts
/// all text from that selection as an un-styled `String`.
String extractTextFromSelection({
  required Document document,
  required DocumentSelection documentSelection,
}) {
  final selectedNodes = document.getNodesInside(
    documentSelection.base,
    documentSelection.extent,
  );

  final buffer = StringBuffer();
  for (int i = 0; i < selectedNodes.length; ++i) {
    final selectedNode = selectedNodes[i];
    dynamic nodeSelection;

    if (i == 0) {
      // This is the first node and it may be partially selected.
      final baseSelectionPosition = selectedNode.id == documentSelection.base.nodeId
          ? documentSelection.base.nodePosition
          : documentSelection.extent.nodePosition;

      final extentSelectionPosition =
          selectedNodes.length > 1 ? selectedNode.endPosition : documentSelection.extent.nodePosition;

      nodeSelection = selectedNode.computeSelection(
        base: baseSelectionPosition,
        extent: extentSelectionPosition,
      );
    } else if (i == selectedNodes.length - 1) {
      // This is the last node and it may be partially selected.
      final nodePosition = selectedNode.id == documentSelection.base.nodeId
          ? documentSelection.base.nodePosition
          : documentSelection.extent.nodePosition;

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

/// Places an expanded selection around the unit of content that occupies the
/// given [documentOffset].
///
/// A content unit is, e.g., a character, an attachment, an image - it's something
/// that appears between sequential caret positions.
bool selectContentUnitAt(Editor editor, DocumentLayout documentLayout, Offset documentOffset) {
  final position = documentLayout.getDocumentPositionAtOffset(documentOffset);
  if (position == null) {
    return false;
  }

  final component = documentLayout.getComponentByNodeId(position.nodeId);
  if (component == null) {
    return false;
  }

  final startPosition = position.nodePosition;
  final positionToTheLeft = component.movePositionLeft(startPosition);
  final positionToTheRight = component.movePositionRight(startPosition);
  if (positionToTheLeft == null && positionToTheRight == null) {
    // Nothing to select beyond the single position.
    return false;
  }

  final caretInDocument = documentLayout.getCaretForPosition(position);

  late final NodePosition base;
  late final NodePosition extent;
  if (caretInDocument.x < documentOffset.dx && positionToTheRight != null) {
    // Caret is to the left of the tapped offset. Select the content unit
    // to the right.
    base = position.nodePosition;
    extent = positionToTheRight;
  } else if (positionToTheLeft != null) {
    // Caret is to the right of the tapped offset. Select the content unit
    // to the left.
    base = positionToTheLeft;
    extent = position.nodePosition;
  } else {
    // User may have tapped to the left of the whole component, or to the
    // right of the whole component.
    return false;
  }

  editor.execute([
    ChangeSelectionRequest(
      DocumentSelection(
        base: DocumentPosition(
          nodeId: position.nodeId,
          nodePosition: base,
        ),
        extent: DocumentPosition(
          nodeId: position.nodeId,
          nodePosition: extent,
        ),
      ),
      SelectionChangeType.expandSelection,
      SelectionReason.userInteraction,
    ),
  ]);

  return true;
}

/// Selects the entire component that contains the given [documentPosition], such as when
/// a user triple taps.
bool selectComponentAt(
  Editor editor, {
  required DocumentPosition documentPosition,
  required DocumentLayout documentLayout,
}) {
  final component = documentLayout.getComponentByNodeId(documentPosition.nodeId);
  if (component == null) {
    return false;
  }

  final nodeSelection = component.getSelectionOfEverything();
  editor.execute([
    ChangeSelectionRequest(
      DocumentSelection(
        base: DocumentPosition(nodeId: documentPosition.nodeId, nodePosition: nodeSelection.base),
        extent: DocumentPosition(nodeId: documentPosition.nodeId, nodePosition: nodeSelection.extent),
      ),
      SelectionChangeType.expandSelection,
      SelectionReason.userInteraction,
    ),
  ]);

  return true;
}
