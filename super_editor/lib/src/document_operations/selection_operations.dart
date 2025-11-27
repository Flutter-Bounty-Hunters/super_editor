import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';
import 'package:super_editor/src/default_editor/text_tools.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

import '../core/document.dart';
import '../core/document_selection.dart';

/// Moves the [DocumentComposer]'s selection to the nearest node to [startingNode],
/// whose [DocumentComponent] is visually selectable.
///
/// Expands the selection if [expand] is `true`, otherwise collapses the selection.
///
/// If a downstream selectable node if found, it will be used, otherwise,
/// a upstream selectable node will be searched.
///
/// If a selectable node is found, the selection will move to its beginning.
/// If no selectable node is found, the selection will remain unchanged.
///
/// Returns `true` if the selection is moved and `false` otherwise, e.g., there
/// are no selectable nodes in the document.
bool moveSelectionToNearestSelectableNode({
  required Editor editor,
  required Document document,
  required DocumentLayoutResolver documentLayoutResolver,
  required DocumentSelection? currentSelection,
  required DocumentNode startingNode,
  bool expand = false,
}) {
  String? newNodeId;
  NodePosition? newPosition;

  // Try to find a new selection downstream.
  final downstreamNode = editor.document.getNextSelectableNode(
    startingNode: startingNode,
    documentLayoutResolver: documentLayoutResolver,
    direction: DocumentNodeLookupDirection.right,
  );
  if (downstreamNode != null) {
    newNodeId = downstreamNode.id;
    final nextComponent = documentLayoutResolver().getComponentByNodeId(newNodeId);
    newPosition = nextComponent?.getBeginningPosition();
  }

  // Try to find a new selection upstream.
  if (newPosition == null) {
    final upstreamNode = editor.document.getNextSelectableNode(
      startingNode: startingNode,
      documentLayoutResolver: documentLayoutResolver,
      direction: DocumentNodeLookupDirection.left,
    );
    if (upstreamNode != null) {
      newNodeId = upstreamNode.id;
      final previousComponent = documentLayoutResolver().getComponentByNodeId(newNodeId);
      newPosition = previousComponent?.getBeginningPosition();
    }
  }

  if (newNodeId == null || newPosition == null) {
    return false;
  }

  final newExtent = DocumentPosition(
    nodeId: newNodeId,
    nodePosition: newPosition,
  );

  if (expand) {
    // Selection should be expanded.
    editor.execute([
      ChangeSelectionRequest(
        currentSelection!.expandTo(newExtent),
        SelectionChangeType.expandSelection,
        SelectionReason.userInteraction,
      ),
      const ClearComposingRegionRequest(),
    ]);
  } else {
    // Selection should be replaced by new collapsed position.
    editor.execute([
      ChangeSelectionRequest(
        DocumentSelection.collapsed(position: newExtent),
        SelectionChangeType.placeCaret,
        SelectionReason.userInteraction,
      ),
      const ClearComposingRegionRequest(),
    ]);
  }

  return true;
}

/// Returns the first [DocumentNode] after [startingNode] whose
/// [DocumentComponent] is visually selectable.
DocumentNode? getDownstreamSelectableNodeAfter(
  Document document,
  DocumentLayoutResolver documentLayoutResolver,
  DocumentNode startingNode,
) {
  bool foundSelectableNode = false;
  DocumentNode prevNode = startingNode;
  DocumentNode? selectableNode;
  do {
    selectableNode = document.getNodeAfter(prevNode);

    if (selectableNode != null) {
      final nextComponent = documentLayoutResolver().getComponentByNodeId(selectableNode.id);
      if (nextComponent != null) {
        foundSelectableNode = nextComponent.isVisualSelectionSupported();
      }
      prevNode = selectableNode;
    }
  } while (!foundSelectableNode && selectableNode != null);

  return selectableNode;
}

enum SelectionType {
  position,
  word,
  paragraph,
}

bool selectWordAt({
  required DocumentPosition docPosition,
  required DocumentLayout docLayout,
  required ValueNotifier<DocumentSelection?> selection,
}) {
  final newSelection = getWordSelection(docPosition: docPosition, docLayout: docLayout);
  if (newSelection != null) {
    selection.value = newSelection;
    return true;
  } else {
    return false;
  }
}

bool selectBlockAt(DocumentPosition position, ValueNotifier<DocumentSelection?> selection) {
  if (position.nodePosition is! UpstreamDownstreamNodePosition) {
    return false;
  }

  selection.value = DocumentSelection(
    base: DocumentPosition(
      nodeId: position.nodeId,
      nodePosition: const UpstreamDownstreamNodePosition.upstream(),
    ),
    extent: DocumentPosition(
      nodeId: position.nodeId,
      nodePosition: const UpstreamDownstreamNodePosition.downstream(),
    ),
  );

  return true;
}

DocumentSelection? getBlockSelection(DocumentPosition caretPosition) {
  if (caretPosition.nodePosition is! UpstreamDownstreamNodePosition) {
    return null;
  }

  return DocumentSelection(
    base: DocumentPosition(
      nodeId: caretPosition.nodeId,
      nodePosition: const UpstreamDownstreamNodePosition.upstream(),
    ),
    extent: DocumentPosition(
      nodeId: caretPosition.nodeId,
      nodePosition: const UpstreamDownstreamNodePosition.downstream(),
    ),
  );
}

bool moveCaretUpstream({
  required Editor editor,
  required DocumentLayout documentLayout,
  MovementModifier? movementModifier,
  required bool retainCollapsedSelection,
}) {
  final selection = editor.composer.selection;
  if (selection == null) {
    return false;
  }

  final currentExtent = selection.extent;
  final nodeId = currentExtent.nodeId;
  final node = editor.document.getNodeById(nodeId);
  if (node == null) {
    return false;
  }
  final extentComponent = documentLayout.getComponentByNodeId(nodeId);
  if (extentComponent == null) {
    return false;
  }

  String newExtentNodeId = nodeId;
  NodePosition? newExtentNodePosition = extentComponent.movePositionLeft(currentExtent.nodePosition, movementModifier);

  if (newExtentNodePosition == null) {
    // Move to next node
    final nextNode = editor.document.getNextSelectableNode(
      startingNode: node,
      documentLayoutResolver: () => documentLayout,
      direction: DocumentNodeLookupDirection.left,
    );

    if (nextNode == null) {
      // We're at the beginning of the document and can't go anywhere.
      return false;
    }

    newExtentNodeId = nextNode.id;
    final nextComponent = documentLayout.getComponentByNodeId(nextNode.id);
    if (nextComponent == null) {
      throw Exception('Could not find component in document layout for the upstream node with ID: ${nextNode.id}');
    }
    newExtentNodePosition = nextComponent.getEndPosition();
  }

  final newExtent = DocumentPosition(
    nodeId: newExtentNodeId,
    nodePosition: newExtentNodePosition,
  );

  DocumentSelection? newSelection = selection.expandTo(newExtent);
  if (newSelection.isCollapsed && !retainCollapsedSelection) {
    newSelection = null;
  }
  editor.execute([
    ChangeSelectionRequest(
      newSelection,
      SelectionChangeType.pushCaret,
      SelectionReason.userInteraction,
    ),
  ]);

  return true;
}

/// Moves the [DocumentComposer]'s selection extent position in the
/// downstream direction (to the right for left-to-right languages).
///
/// {@macro skip_unselectable_components}
///
/// Expands/contracts the selection if [expand] is [true], otherwise
/// collapses the selection or keeps it collapsed.
///
/// By default, moves one character at a time when the extent sits in
/// a [TextNode]. To move word-by-word, pass [MovementModifier.word]
/// in [movementModifier]. To move to the end of a line, pass
/// [MovementModifier.line] in [movementModifier].
///
/// Returns [true] if the extent moved, or the selection changed, e.g., the
/// selection collapsed but the extent stayed in the same place. Returns
/// [false] if the extent did not move and the selection did not change.
bool moveCaretDownstream({
  required Editor editor,
  required DocumentLayout documentLayout,
  MovementModifier? movementModifier,
  required bool retainCollapsedSelection,
}) {
  final selection = editor.composer.selection;
  if (selection == null) {
    return false;
  }

  final currentExtent = selection.extent;
  final nodeId = currentExtent.nodeId;
  final node = editor.document.getNodeById(nodeId);
  if (node == null) {
    return false;
  }
  final extentComponent = documentLayout.getComponentByNodeId(nodeId);
  if (extentComponent == null) {
    return false;
  }

  String newExtentNodeId = nodeId;
  NodePosition? newExtentNodePosition = extentComponent.movePositionRight(currentExtent.nodePosition, movementModifier);

  if (newExtentNodePosition == null) {
    // Move to next node
    final nextNode = editor.document.getNextSelectableNode(
      startingNode: node,
      documentLayoutResolver: () => documentLayout,
      direction: DocumentNodeLookupDirection.right,
    );

    if (nextNode == null) {
      // We're at the beginning/end of the document and can't go
      // anywhere.
      return false;
    }

    newExtentNodeId = nextNode.id;
    final nextComponent = documentLayout.getComponentByNodeId(nextNode.id);
    if (nextComponent == null) {
      throw Exception('Could not find component in document layout for the downstream node with ID: ${nextNode.id}');
    }
    newExtentNodePosition = nextComponent.getBeginningPosition();
  }

  final newExtent = DocumentPosition(
    nodeId: newExtentNodeId,
    nodePosition: newExtentNodePosition,
  );

  DocumentSelection? newSelection = selection.expandTo(newExtent);
  if (newSelection.isCollapsed && !retainCollapsedSelection) {
    newSelection = null;
  }
  editor.execute([
    ChangeSelectionRequest(
      newSelection,
      SelectionChangeType.pushCaret,
      SelectionReason.userInteraction,
    ),
  ]);

  return true;
}

/// Moves the [DocumentComposer]'s selection extent position up,
/// vertically, either by moving the selection extent up one line of
/// text, or by moving the selection extent up to the node above the
/// current extent.
///
/// If the current selection extent wants to move to the node above,
/// but there is no node above the current extent, the extent is moved
/// to the "start" position of the current node. For example: the extent
/// moves from the middle of the first line of text in a paragraph to
/// the beginning of the paragraph.
///
/// {@macro skip_unselectable_components}
///
/// Expands/contracts the selection if [expand] is [true], otherwise
/// collapses the selection or keeps it collapsed.
///
/// Returns [true] if the extent moved, or the selection changed, e.g., the
/// selection collapsed but the extent stayed in the same place. Returns
/// [false] if the extent did not move and the selection did not change.
bool moveCaretUp({
  required Editor editor,
  required DocumentLayout documentLayout,
  required bool retainCollapsedSelection,
}) {
  final selection = editor.composer.selection;
  if (selection == null) {
    return false;
  }

  final currentExtent = selection.extent;
  final nodeId = currentExtent.nodeId;
  final node = editor.document.getNodeById(nodeId);
  if (node == null) {
    return false;
  }
  final extentComponent = documentLayout.getComponentByNodeId(nodeId);
  if (extentComponent == null) {
    return false;
  }

  String newExtentNodeId = nodeId;
  NodePosition? newExtentNodePosition = extentComponent.movePositionUp(currentExtent.nodePosition);

  if (newExtentNodePosition == null) {
    // Move to next node
    final offsetInExtent = extentComponent.getOffsetForPosition(currentExtent.nodePosition);
    final offsetToMatch = documentLayout.getDocumentOffsetFromAncestorOffset(
      offsetInExtent,
      extentComponent.context.findRenderObject(),
    );
    final nextNode = editor.document.getNextSelectableNode(
      startingNode: node,
      documentLayoutResolver: () => documentLayout,
      direction: DocumentNodeLookupDirection.up,
      nearX: offsetToMatch.dx,
    );
    if (nextNode != null) {
      newExtentNodeId = nextNode.id;
      final nextComponent = documentLayout.getComponentByNodeId(nextNode.id);
      if (nextComponent == null) {
        editorOpsLog.shout("Tried to obtain non-existent component by node id: $newExtentNodeId");
        return false;
      }
      final offsetInNextComponent = documentLayout.getAncestorOffsetFromDocumentOffset(
        offsetToMatch,
        nextComponent.context.findRenderObject(),
      );
      newExtentNodePosition = nextComponent.getEndPositionNearX(offsetInNextComponent.dx);
    } else {
      // We're at the top of the document. Move the cursor to the
      // beginning of the current node.
      newExtentNodePosition = extentComponent.getBeginningPosition();
    }
  }

  final newExtent = DocumentPosition(
    nodeId: newExtentNodeId,
    nodePosition: newExtentNodePosition,
  );

  DocumentSelection? newSelection = selection.expandTo(newExtent);
  if (newSelection.isCollapsed && !retainCollapsedSelection) {
    newSelection = null;
  }

  editor.execute([
    ChangeSelectionRequest(
      newSelection,
      SelectionChangeType.pushCaret,
      SelectionReason.userInteraction,
    ),
  ]);

  return true;
}

/// Moves the [DocumentComposer]'s selection extent position down,
/// vertically, either by moving the selection extent down one line of
/// text, or by moving the selection extent down to the node below the
/// current extent.
///
/// If the current selection extent wants to move to the node below,
/// but there is no node below the current extent, the extent is moved
/// to the "end" position of the current node. For example: the extent
/// moves from the middle of the last line of text in a paragraph to
/// the end of the paragraph.
///
/// {@macro skip_unselectable_components}
///
/// Expands/contracts the selection if [expand] is [true], otherwise
/// collapses the selection or keeps it collapsed.
///
/// Returns [true] if the extent moved, or the selection changed, e.g., the
/// selection collapsed but the extent stayed in the same place. Returns
/// [false] if the extent did not move and the selection did not change.
bool moveCaretDown({
  required Editor editor,
  required DocumentLayout documentLayout,
  required bool retainCollapsedSelection,
}) {
  final selection = editor.composer.selection;
  if (selection == null) {
    return false;
  }

  final currentExtent = selection.extent;
  final nodeId = currentExtent.nodeId;
  final node = editor.document.getNodeById(nodeId);
  if (node == null) {
    return false;
  }
  final extentComponent = documentLayout.getComponentByNodeId(nodeId);
  if (extentComponent == null) {
    return false;
  }

  String newExtentNodeId = nodeId;
  NodePosition? newExtentNodePosition = extentComponent.movePositionDown(currentExtent.nodePosition);

  if (newExtentNodePosition == null) {
    // Move to next node
    final offsetInExtent = extentComponent.getOffsetForPosition(currentExtent.nodePosition);
    final offsetToMatch = documentLayout.getDocumentOffsetFromAncestorOffset(
      offsetInExtent,
      extentComponent.context.findRenderObject(),
    );
    final nextNode = editor.document.getNextSelectableNode(
      startingNode: node,
      documentLayoutResolver: () => documentLayout,
      direction: DocumentNodeLookupDirection.down,
      nearX: offsetToMatch.dx,
    );
    if (nextNode != null) {
      newExtentNodeId = nextNode.id;
      final nextComponent = documentLayout.getComponentByNodeId(nextNode.id);
      if (nextComponent == null) {
        editorOpsLog.shout("Tried to obtain non-existent component by node id: $newExtentNodeId");
        return false;
      }
      final offsetInNextComponent = documentLayout.getAncestorOffsetFromDocumentOffset(
        offsetToMatch,
        nextComponent.context.findRenderObject(),
      );
      newExtentNodePosition = nextComponent.getBeginningPositionNearX(offsetInNextComponent.dx);
    } else {
      // We're at the bottom of the document. Move the cursor to the
      // end of the current node.
      newExtentNodePosition = extentComponent.getEndPosition();
    }
  }

  final newExtent = DocumentPosition(
    nodeId: newExtentNodeId,
    nodePosition: newExtentNodePosition,
  );

  DocumentSelection? newSelection = selection.expandTo(newExtent);
  if (newSelection.isCollapsed && !retainCollapsedSelection) {
    newSelection = null;
  }
  editor.execute([
    ChangeSelectionRequest(
      newSelection,
      SelectionChangeType.pushCaret,
      SelectionReason.userInteraction,
    ),
  ]);

  return true;
}

/// Sets the [selection]'s value to include the entire [Document].
///
/// Returns `true` if any content was selected, or `false` if the document
/// is empty.
bool selectAll(Editor editor) {
  if (editor.document.isEmpty) {
    return false;
  }

  editor.execute([
    ChangeSelectionRequest(
      DocumentSelection(
        base: DocumentPosition(
          nodeId: editor.document.first.id,
          nodePosition: editor.document.first.beginningPosition,
        ),
        extent: DocumentPosition(
          nodeId: editor.document.last.id,
          nodePosition: editor.document.last.endPosition,
        ),
      ),
      SelectionChangeType.expandSelection,
      SelectionReason.userInteraction,
    ),
  ]);

  return true;
}

/// Serializes the current selection to plain text, and adds it to the
/// clipboard.
void copy({
  required Document document,
  required DocumentSelection selection,
}) {
  final textToCopy = _textInSelection(
    document: document,
    documentSelection: selection,
  );
  // TODO: figure out a general approach for asynchronous behaviors that
  //       need to be carried out in response to user input.
  _saveToClipboard(textToCopy);
}

String _textInSelection({
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

Future<void> _saveToClipboard(String text) {
  return Clipboard.setData(ClipboardData(text: text));
}
