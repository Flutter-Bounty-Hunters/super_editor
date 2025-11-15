import 'dart:math';

import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/box_component.dart';
import 'package:super_editor/src/default_editor/common_editor_operations.dart';
import 'package:super_editor/src/default_editor/layout_single_column/composite_nodes.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

import 'paragraph.dart';

final _log = Logger(scope: 'multi_node_editing.dart');

/// Request to paste the given structured [content] in the document at the
/// given [pastePosition].
class PasteStructuredContentEditorRequest implements EditRequest {
  PasteStructuredContentEditorRequest({
    required this.content,
    required this.pastePosition,
  });

  final Document content;
  final DocumentPosition pastePosition;
}

/// Inserts given structured content, in the form of a `List` of [DocumentNode]s at a
/// given paste position within the document.
class PasteStructuredContentEditorCommand extends EditCommand {
  PasteStructuredContentEditorCommand({
    required Document content,
    required DocumentPosition pastePosition,
  })  : _content = content,
        _pastePosition = pastePosition;

  final Document _content;
  final DocumentPosition _pastePosition;

  @override
  HistoryBehavior get historyBehavior => HistoryBehavior.undoable;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    if (_content.isEmpty) {
      // Nothing to paste. Return.
      return;
    }

    final document = context.document;
    final composer = context.find<MutableDocumentComposer>(Editor.composerKey);
    final currentNodeWithSelection = document.getNodeById(_pastePosition.nodeId);
    if (currentNodeWithSelection is! TextNode) {
      throw Exception('Can\'t handle pasting text within node of type: $currentNodeWithSelection');
    }

    editorOpsLog.info("Pasting clipboard content as Markdown in document.");

    if (_content.length == 1) {
      _pasteSingleNode(executor, document, _content.first, _pastePosition, currentNodeWithSelection);
    } else {
      _pasteMultipleNodes(executor, document, _content, currentNodeWithSelection);
    }

    editorOpsLog.fine('New selection after paste operation: ${composer.selection}');
    editorOpsLog.fine('Done with paste command.');
  }

  void _pasteSingleNode(CommandExecutor executor, MutableDocument document, DocumentNode pastedNode,
      DocumentPosition pastePosition, TextNode currentNodeWithSelection) {
    if (_canMergeNodes(currentNodeWithSelection, pastedNode)) {
      executor.executeCommand(
        InsertAttributedTextCommand(
          documentPosition: pastePosition,
          // Only text nodes are merge-able, therefore we know that the first pasted node
          // is a TextNode.
          textToInsert: (pastedNode as TextNode).text,
        ),
      );
      executor.executeCommand(
        ChangeSelectionCommand(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: pastePosition.nodeId,
              nodePosition: TextNodePosition(
                  offset: (pastePosition.nodePosition as TextNodePosition).offset + pastedNode.text.length),
            ),
          ),
          SelectionChangeType.insertContent,
          SelectionReason.userInteraction,
        ),
      );

      return;
    }

    final (upstreamNodeId, _) = _splitPasteParagraph(
        executor, currentNodeWithSelection.id, (pastePosition.nodePosition as TextNodePosition).offset);

    // Insert the pasted node after the split upstream node.
    document.insertNodeAfter(
      existingNodeId: upstreamNodeId,
      newNode: pastedNode,
    );
    executor.logChanges([
      DocumentEdit(
        NodeInsertedEvent(NodePath.withNodeId(pastedNode.id), document.getNodeIndexById(pastedNode.id)),
      )
    ]);

    // Place the caret at the end of the pasted content.
    executor.executeCommand(
      ChangeSelectionCommand(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: pastedNode.id,
            nodePosition: pastedNode.endPosition,
          ),
        ),
        SelectionChangeType.insertContent,
        SelectionReason.userInteraction,
      ),
    );
  }

  void _pasteMultipleNodes(
    CommandExecutor executor,
    MutableDocument document,
    Document pastedNodes,
    TextNode currentNodeWithSelection,
  ) {
    final textNode = document.getNode(_pastePosition) as TextNode;
    final pasteTextOffset = (_pastePosition.nodePosition as TextPosition).offset;
    final nodesToInsert = List.from(_content);

    // Split the original node in two, around the caret.
    TextNode? downstreamSplitNode;
    if (pasteTextOffset < textNode.endPosition.offset) {
      // The caret sits somewhere in the middle of an existing text node. Split the
      // node at the caret so we can paste structured content in between.
      final (_, downstreamSplitNodeId) = _splitPasteParagraph(executor, currentNodeWithSelection.id, pasteTextOffset);
      downstreamSplitNode = document.getNodeById(downstreamSplitNodeId) as TextNode;
    }

    // (Possibly) merge or delete the upstream split node.
    bool deleteInitiallySelectedNode = false;
    final firstPastedNode = nodesToInsert.first;
    if (_canMergeNodes(currentNodeWithSelection, firstPastedNode)) {
      // The text in the first pasted node is stylistically compatible with the
      // existing text in the node where the paste was triggered. Therefore, instead
      // inserting the first pasted node, merge its content with the existing node.
      executor.executeCommand(
        InsertAttributedTextCommand(
          documentPosition: _pastePosition,
          // Only text nodes are merge-able, therefore we know that the first pasted node
          // is a TextNode.
          textToInsert: (firstPastedNode as TextNode).text,
        ),
      );

      // We've pasted the first new node. Remove it from the nodes to insert.
      nodesToInsert.removeAt(0);
    }
    if (currentNodeWithSelection.text.length == 0) {
      // The node with the selection is an empty text node. After we use that node's
      // position to insert other nodes, we want to delete that first node, as if the
      // pasted content replaced it.
      deleteInitiallySelectedNode = true;
    }

    // (Possibly) merge or delete the downstream split node.
    if (nodesToInsert.isNotEmpty) {
      final lastPastedNode = nodesToInsert.last;
      if (downstreamSplitNode != null && _canMergeNodes(lastPastedNode, downstreamSplitNode)) {
        // The text in the last pasted node is stylistically compatible with the
        // existing text in the node that was split after the caret. Therefore, instead
        // of inserting the last pasted node, merge its content with the existing split
        // node.
        executor.executeCommand(
          InsertAttributedTextCommand(
            documentPosition: DocumentPosition(
              nodeId: downstreamSplitNode.id,
              nodePosition: const TextNodePosition(offset: 0),
            ),
            // Only text nodes are merge-able, therefore we know that the last pasted node
            // is a TextNode.
            textToInsert: (lastPastedNode as TextNode).text,
          ),
        );

        // We've pasted the last new node. Remove it from the nodes to insert.
        nodesToInsert.removeLast();
      }
    }

    // Now that the first and last pasted nodes have been merged with existing content
    // (or not), insert all remaining pasted nodes into the document.
    DocumentNode previousNode = currentNodeWithSelection;
    for (final pastedNode in nodesToInsert) {
      document.insertNodeAfter(
        existingNodeId: previousNode.id,
        newNode: pastedNode,
      );
      previousNode = pastedNode;

      executor.logChanges([
        DocumentEdit(
          NodeInsertedEvent(pastedNode.id, document.getNodeIndexById(pastedNode.id)),
        )
      ]);
    }

    if (deleteInitiallySelectedNode) {
      document.deleteNode(currentNodeWithSelection.id);
      executor.logChanges([
        DocumentEdit(
          NodeRemovedEvent(NodePath.withNodeId(currentNodeWithSelection.id), currentNodeWithSelection),
        )
      ]);
    }

    // Place the caret at the end of the pasted content.
    executor.executeCommand(
      ChangeSelectionCommand(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: previousNode.id,
            nodePosition: previousNode.endPosition,
          ),
        ),
        SelectionChangeType.insertContent,
        SelectionReason.userInteraction,
      ),
    );
  }

  (String upstreamNode, String downstreamNode) _splitPasteParagraph(
    CommandExecutor executor,
    String currentNodeWithSelectionId,
    int pasteTextOffset,
  ) {
    final newNodeId = Editor.createNodeId();
    executor.executeCommand(
      SplitParagraphCommand(
        nodePath: NodePath.withNodeId(currentNodeWithSelectionId),
        splitPosition: TextPosition(offset: pasteTextOffset),
        newNodeId: newNodeId,
        replicateExistingMetadata: true,
      ),
    );

    return (currentNodeWithSelectionId, newNodeId);
  }

  bool _canMergeNodes(DocumentNode existingNode, DocumentNode newNode) {
    if (existingNode is! TextNode || newNode is! TextNode) {
      // We can only merge text nodes.
      return false;
    }

    if (existingNode.metadata['blockType'] != newNode.metadata['blockType']) {
      // Text nodes with different block types cannot be merged, e.g., "Header 1" with a "Blockquote".
      return false;
    }

    return true;
  }
}

/// Inserts the [newNode] at the end of the document.
class InsertNodeAtEndOfDocumentRequest implements EditRequest {
  InsertNodeAtEndOfDocumentRequest(this.newNode);

  final DocumentNode newNode;
}

class InsertNodeAtIndexRequest implements EditRequest {
  InsertNodeAtIndexRequest({
    this.parentPath,
    required this.nodeIndex,
    required this.newNode,
  });

  final NodePath? parentPath;
  final int nodeIndex;
  final DocumentNode newNode;
}

class InsertNodeAtIndexCommand extends EditCommand {
  InsertNodeAtIndexCommand({
    this.parentPath,
    required this.nodeIndex,
    required this.newNode,
  });

  final NodePath? parentPath;
  final int nodeIndex;
  final DocumentNode newNode;

  @override
  String describe() => "Insert node at index $nodeIndex: $newNode";

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.document;
    NodePath insertedNodePath;
    if (parentPath != null) {
      final parent = document.getNodeAtPath(parentPath!) as CompositeNode;
      final childNode = parent.getChildAt(nodeIndex);
      document.insertNodeAfterPath(
        existingNodePath: parentPath!.child(childNode.id),
        newNode: newNode,
      );
      insertedNodePath = parentPath!.child(newNode.id);
    } else {
      document.insertNodeAt(nodeIndex, newNode);
      insertedNodePath = NodePath.withNodeId(newNode.id);
    }
    executor.logChanges([
      DocumentEdit(
        NodeInsertedEvent(insertedNodePath, nodeIndex),
      )
    ]);
  }
}

class InsertNodeBeforeNodeRequest implements EditRequest {
  const InsertNodeBeforeNodeRequest({
    required this.existingNodePath,
    required this.newNode,
  });

  final NodePath existingNodePath;
  final DocumentNode newNode;
}

class InsertNodeBeforeNodeCommand extends EditCommand {
  InsertNodeBeforeNodeCommand({
    required this.existingNodePath,
    required this.newNode,
  });

  final NodePath existingNodePath;
  final DocumentNode newNode;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.document;

    document.insertNodeBeforePath(existingNodePath: existingNodePath, newNode: newNode);

    final newNodePath = existingNodePath.replaceLeaf(newNode.id);

    executor.logChanges([
      DocumentEdit(
        NodeInsertedEvent(newNodePath, document.getNodeIndexInParent(newNodePath)),
      )
    ]);
  }
}

class InsertNodeAfterNodeRequest implements EditRequest {
  const InsertNodeAfterNodeRequest({
    required this.existingNodePath,
    required this.newNode,
  });

  final NodePath existingNodePath;
  final DocumentNode newNode;
}

class InsertNodeAfterNodeCommand extends EditCommand {
  InsertNodeAfterNodeCommand({
    required this.existingNodePath,
    required this.newNode,
  });

  final NodePath existingNodePath;
  final DocumentNode newNode;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.document;

    document.insertNodeAfterPath(existingNodePath: existingNodePath, newNode: newNode);
    final newNodePath = existingNodePath.replaceLeaf(newNode.id);

    executor.logChanges([
      DocumentEdit(
        NodeInsertedEvent(newNodePath, document.getNodeIndexInParent(newNodePath)),
      )
    ]);
  }
}

class InsertNodeAtCaretRequest implements EditRequest {
  InsertNodeAtCaretRequest({
    required this.node,
  });

  final DocumentNode node;
}

class InsertNodeAtCaretCommand extends EditCommand {
  InsertNodeAtCaretCommand({
    required this.newNode,
  });

  final DocumentNode newNode;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.document;
    final composer = context.find<MutableDocumentComposer>(Editor.composerKey);

    if (composer.selection == null) {
      return;
    }
    if (composer.selection!.base.nodeId != composer.selection!.extent.nodeId) {
      return;
    }

    final selectedNodeId = composer.selection!.base.nodeId;
    final selectedNode = document.getNodeById(selectedNodeId);
    if (selectedNode is! ParagraphNode) {
      return;
    }

    final paragraphPosition = composer.selection!.extent.nodePosition as TextNodePosition;
    final beginningOfParagraph = selectedNode.beginningPosition;
    final endOfParagraph = selectedNode.endPosition;

    DocumentSelection newSelection;
    if (selectedNode.text.isEmpty) {
      // Insert new block node above selected paragraph.
      document.insertNodeBefore(existingNodeId: selectedNode.id, newNode: newNode);
      executor.logChanges([
        DocumentEdit(
          NodeInsertedEvent(NodePath.withNodeId(newNode.id), document.getNodeIndexById(newNode.id)),
        ),
      ]);

      newSelection = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: selectedNodeId,
          nodePosition: selectedNode.beginningPosition,
        ),
      );
    } else if (paragraphPosition.offset == beginningOfParagraph.offset) {
      // Insert block item after the paragraph.
      document.insertNodeAt(document.getNodeIndexById(selectedNode.id), newNode);
      executor.logChanges([
        DocumentEdit(
          NodeInsertedEvent(NodePath.withNodeId(newNode.id), document.getNodeIndexById(newNode.id)),
        )
      ]);

      newSelection = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: selectedNode.id,
          nodePosition: selectedNode.beginningPosition,
        ),
      );
    } else if (paragraphPosition.offset == endOfParagraph.offset) {
      final emptyParagraph = ParagraphNode(id: Editor.createNodeId(), text: AttributedText());

      // Insert block item after the paragraph and insert a new empty paragraph.
      document
        ..insertNodeAfter(existingNodeId: selectedNode.id, newNode: newNode)
        ..insertNodeAfter(existingNodeId: newNode.id, newNode: emptyParagraph);
      executor.logChanges([
        DocumentEdit(
          NodeInsertedEvent(NodePath.withNodeId(newNode.id), document.getNodeIndexById(newNode.id)),
        ),
        DocumentEdit(
          NodeInsertedEvent(NodePath.withNodeId(emptyParagraph.id), document.getNodeIndexById(emptyParagraph.id)),
        ),
      ]);

      newSelection = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: emptyParagraph.id,
          nodePosition: emptyParagraph.endPosition,
        ),
      );
    } else {
      // Split the paragraph and inset image in between.
      final textBefore = selectedNode.text.copyText(0, paragraphPosition.offset);
      final textAfter = selectedNode.text.copyText(paragraphPosition.offset);

      final newParagraph = ParagraphNode(id: Editor.createNodeId(), text: textAfter);

      final updatedSelectedNode = selectedNode.copyParagraphWith(text: textBefore);
      document
        ..replaceNodeById(selectedNode.id, updatedSelectedNode)
        ..insertNodeAfter(existingNodeId: updatedSelectedNode.id, newNode: newNode)
        ..insertNodeAfter(existingNodeId: newNode.id, newNode: newParagraph);
      executor.logChanges([
        DocumentEdit(
          NodeChangeEvent(NodePath.withNodeId(selectedNodeId)),
        ),
        DocumentEdit(
          NodeInsertedEvent(NodePath.withNodeId(newNode.id), document.getNodeIndexById(newNode.id)),
        ),
        DocumentEdit(
          NodeInsertedEvent(NodePath.withNodeId(newParagraph.id), document.getNodeIndexById(newParagraph.id)),
        ),
      ]);

      newSelection = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: newParagraph.id,
          nodePosition: newParagraph.beginningPosition,
        ),
      );
    }

    executor.executeCommand(ChangeSelectionCommand(
      newSelection,
      SelectionChangeType.insertContent,
      SelectionReason.userInteraction,
    ));
  }
}

class MoveNodeRequest implements EditRequest {
  const MoveNodeRequest({
    required this.nodeId,
    required this.newIndex,
  });

  final String nodeId;
  final int newIndex;
}

class MoveNodeCommand extends EditCommand {
  MoveNodeCommand({
    required this.nodeId,
    required this.newIndex,
  });

  final String nodeId;
  final int newIndex;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.document;

    // Log all the move changes that will happen when we move the target node
    // elsewhere in the document.
    final nodeMoveEvents = <DocumentEdit>[];

    final targetNodeIndex = document.getNodeIndexById(nodeId);
    final startIndex = min(targetNodeIndex, newIndex);
    final endIndex = max(targetNodeIndex, newIndex);

    // When moving one node to another index, all nodes between those indices
    // are pushed up, or down, depending on whether the new node index is
    // higher or lower than the existing node index. This direction tells us
    // which way the other nodes will move.
    final otherNodeMovementDirection = newIndex > targetNodeIndex ? 1 : -1;

    // Collect change events for everything that will happen when we tell the
    // MutableDocument to move the desired node to its new index.
    for (int i = startIndex; i <= endIndex; i += 1) {
      if (i == targetNodeIndex) {
        // This is the node that we care about moving. Report its move to the
        // new index.
        nodeMoveEvents.add(
          DocumentEdit(
            NodeMovedEvent(nodePath: NodePath.withNodeId(nodeId), from: targetNodeIndex, to: newIndex),
          ),
        );
        continue;
      }

      // This is a node that got moved up/down by one spot, as a consequence of moving
      // the target node. Report its change of index.
      nodeMoveEvents.add(
        DocumentEdit(
          NodeMovedEvent(
            nodePath: NodePath.withNodeId(document.getNodeAt(i)!.id),
            from: i,
            to: i - otherNodeMovementDirection,
          ),
        ),
      );
    }

    // Move the target node to its destination index.
    document.moveNode(nodeId: nodeId, targetIndex: newIndex);

    // Report all the node movements.
    executor.logChanges(nodeMoveEvents);
  }
}

class ReplaceNodeRequest implements EditRequest {
  ReplaceNodeRequest({
    required this.existingNodeId,
    required this.newNode,
  });

  final String existingNodeId;
  final DocumentNode newNode;
}

class ReplaceNodeCommand extends EditCommand {
  ReplaceNodeCommand({
    required this.existingNodeId,
    required this.newNode,
  });

  final String existingNodeId;
  final DocumentNode newNode;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.document;
    final oldNode = document.getNodeById(existingNodeId)!;
    document.replaceNodeById(oldNode.id, newNode);

    executor.logChanges([
      DocumentEdit(
        NodeRemovedEvent(NodePath.withNodeId(existingNodeId), oldNode),
      ),
      DocumentEdit(
        NodeInsertedEvent(NodePath.withNodeId(newNode.id), document.getNodeIndexById(newNode.id)),
      ),
    ]);
  }
}

class ReplaceNodeWithEmptyParagraphWithCaretRequest implements EditRequest {
  const ReplaceNodeWithEmptyParagraphWithCaretRequest({
    required this.nodePath,
  });

  final NodePath nodePath;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReplaceNodeWithEmptyParagraphWithCaretRequest &&
          runtimeType == other.runtimeType &&
          nodePath == other.nodePath;

  @override
  int get hashCode => nodePath.hashCode;
}

class ReplaceNodeWithEmptyParagraphWithCaretCommand extends EditCommand {
  ReplaceNodeWithEmptyParagraphWithCaretCommand({
    required this.nodePath,
  });

  final NodePath nodePath;

  @override
  HistoryBehavior get historyBehavior => HistoryBehavior.undoable;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.document;

    final oldNode = document.getNodeAtPath(nodePath);
    if (oldNode == null) {
      return;
    }

    final newNode = ParagraphNode(
      id: oldNode.id,
      text: AttributedText(),
    );
    document.replaceNodeByPath(nodePath, newNode);

    executor.logChanges([
      DocumentEdit(
        NodeRemovedEvent(nodePath, oldNode),
      ),
      DocumentEdit(
        NodeInsertedEvent(nodePath, document.getNodeIndexInParent(nodePath)),
      ),
    ]);

    executor.executeCommand(ChangeSelectionCommand(
      DocumentSelection.collapsed(
        position: DocumentPosition.withPath(
          nodePath: nodePath,
          nodePosition: newNode.beginningPosition,
        ),
      ),
      SelectionChangeType.placeCaret,
      SelectionReason.userInteraction,
      notifyListeners: false,
    ));
  }
}

class DeleteContentRequest implements EditRequest {
  DeleteContentRequest({
    required this.documentRange,
  });

  final DocumentRange documentRange;
}

class DeleteContentCommand extends EditCommand {
  DeleteContentCommand({
    required this.documentRange,
  });

  final DocumentRange documentRange;

  @override
  HistoryBehavior get historyBehavior => HistoryBehavior.undoable;

  @override
  String describe() => "Delete content within range: $documentRange";

  @override
  void execute(EditContext context, CommandExecutor executor) {
    _log.log('DeleteSelectionCommand', 'DocumentEditor: deleting selection: $documentRange');
    final document = context.document;
    final selection = context.composer.selection;
    final normalizedRange = documentRange.normalize(document);
    final nodes = document.getLeafNodesInside(normalizedRange.start, normalizedRange.end);

    if (nodes.length == 1) {
      // This is a selection within a single node.
      final (path, node) = nodes.first;
      if (!node.isDeletable) {
        // The node is not deletable. Abort the deletion.
        if (node is BlockNode && selection?.isCollapsed == false) {
          // On iOS, pressing backspace generates a non-text delta expanding the selection
          // prior to its deletion. Since we can't delete the block, we'll just collapse the
          // selection to the end of the block.
          executor.executeCommand(
            ChangeSelectionCommand(
              DocumentSelection.collapsed(
                position: DocumentPosition.withPath(
                  nodePath: path,
                  nodePosition: node.endPosition,
                ),
              ),
              SelectionChangeType.placeCaret,
              SelectionReason.contentChange,
            ),
          );
        }
        return;
      }
      final changeList = _deleteSelectionWithinSingleNode(
        document: document,
        normalizedRange: normalizedRange,
      );

      executor.logChanges(changeList);

      return;
    }

    final (startNodePath, startNode) = nodes.first;

    // if (startNode == null) {
    //   throw Exception('Could not locate start node for DeleteSelectionCommand: ${normalizedRange.start}');
    // }

    final startNodeIndex = document.getNodeIndexInParent(startNodePath);

    final (endNodePath, endNode) = nodes.last;
    // final endNode = document.getNode(normalizedRange.end);
    // if (endNode == null) {
    //   throw Exception('Could not locate end node for DeleteSelectionCommand: ${normalizedRange.end}');
    // }

    executor.logChanges(
      _deleteNodesBetweenFirstAndLast(document: document, nodes: nodes),
    );

    if (startNode.isDeletable) {
      _log.log('DeleteSelectionCommand', ' - deleting partial selection within the starting node.');
      executor.logChanges(
        _deleteRangeWithinNodeFromPositionToEnd(
          document: document,
          path: startNodePath,
          node: startNode,
          nodePosition: normalizedRange.start.leafNodePosition,
          replaceWithParagraph: false,
        ),
      );
    }

    if (endNode.isDeletable) {
      _log.log('DeleteSelectionCommand', ' - deleting partial selection within ending node.');
      executor.logChanges(
        _deleteRangeWithinNodeFromStartToPosition(
          document: document,
          path: endNodePath,
          node: endNode,
          nodePosition: normalizedRange.end.leafNodePosition,
        ),
      );
    }

    final wereAllDeletableNodesInRangeDeleted = nodes.every(
      (node) => document.getNodeAtPath(node.$1) == null || !node.$2.isDeletable,
    );
    final hasNonDeletableNodesInRange = nodes.any((node) => !node.$2.isDeletable);

    // If all selected nodes were deleted, e.g., the user selected from
    // the beginning of the first node to the end of the last node, then
    // we need insert an empty paragraph node so that there's a place
    // to position the caret.
    if (wereAllDeletableNodesInRangeDeleted) {
      // If there are any non-deletable nodes in the range, insert the new node
      // after the last non-deletable node. Otherwise, insert the new node at
      // the position where the first selected node was.
      final insertIndex = hasNonDeletableNodesInRange //
          ? document.getNodeIndexInParent(nodes.lastWhere((node) => !node.$2.isDeletable).$1) + 1
          : startNodeIndex;

      // We expect that this command will only be called when the delete range
      // contains at least one deletable node.
      final firstDeletableNodePath = nodes.firstWhere((item) => item.$2.isDeletable).$1;

      // If one of the edge nodes is deletable, we can use it as the ID for the
      // new empty paragraph. Otherwise, use the ID of the first deletable node in the range.
      // We expect that this method is never called when there are no deletable nodes
      // in the range.
      final emptyParagraphPath = startNode.isDeletable
          ? startNodePath
          : endNode.isDeletable
              ? endNodePath
              : firstDeletableNodePath;

      // TODO: Fix case when all CompositeNodes are deleted, but selection!.extent.nodePath.parent
      // still points to it. It would crash, as there is no more path to insert
      document.insertNodeAtPath(
        parent: selection!.extent.nodePath.parent,
        newNode: ParagraphNode(id: emptyParagraphPath.leafNodeId, text: AttributedText()),
        index: insertIndex,
      );
      executor.logChanges([
        DocumentEdit(
          NodeChangeEvent(emptyParagraphPath),
        )
      ]);
    }

    // The start/end nodes may have been deleted due to empty content.
    // Refresh our references so that we can decide if we need to merge
    // the nodes.
    final startNodeAfterDeletion = document.getNodeById(startNode.id);
    final endNodeAfterDeletion = document.getNodeById(endNode.id);

    // If the start node and end nodes are both `TextNode`s
    // then we need to consider merging them if one or both are
    // empty.
    if (startNodeAfterDeletion is! TextNode || endNodeAfterDeletion is! TextNode) {
      // Neither of the end nodes are `TextNode`s, so there's nothing
      // for us to merge. We're done.
      return;
    }

    _log.log('DeleteSelectionCommand', ' - combining last node text with first node text');
    executor.logChanges([
      DocumentEdit(
        TextInsertionEvent(
          nodePath: NodePath.withNodeId(startNodeAfterDeletion.id),
          offset: startNodeAfterDeletion.text.length,
          text: endNodeAfterDeletion.text,
        ),
      ),
    ]);

    document.replaceNodeById(
      startNodeAfterDeletion.id,
      startNodeAfterDeletion.copyTextNodeWith(
        text: startNodeAfterDeletion.text.copyAndAppend(endNodeAfterDeletion.text),
      ),
    );

    _log.log('DeleteSelectionCommand', ' - deleting last node');
    document.deleteNode(endNodeAfterDeletion.id);
    executor.logChanges([
      DocumentEdit(
        NodeRemovedEvent(NodePath.withNodeId(endNodeAfterDeletion.id), endNodeAfterDeletion),
      )
    ]);
    _log.log('DeleteSelectionCommand', ' - done with selection deletion');
  }

  List<EditEvent> _deleteSelectionWithinSingleNode({
    required MutableDocument document,
    required DocumentRange normalizedRange,
  }) {
    _log.log('_deleteSelectionWithinSingleNode', ' - deleting selection within single node');
    final startPosition = normalizedRange.start.leafNodePosition;
    final endPosition = normalizedRange.end.leafNodePosition;
    final nodePath = normalizedRange.start.nodePath;
    final node = document.getNodeAtPath(nodePath)!;

    if (startPosition is UpstreamDownstreamNodePosition) {
      if (startPosition == endPosition) {
        // The selection is collapsed. Nothing to delete.
        return [];
      }

      // The range is expanded within a block-level node. The only
      // possibility is that the entire node is selected. Delete the node
      // and replace it with an empty paragraph.
      document.replaceNodeByPath(
        nodePath,
        ParagraphNode(id: node.id, text: AttributedText()),
      );

      return [DocumentEdit(NodeChangeEvent(nodePath))];
    } else if (node is TextNode) {
      _log.log('_deleteSelectionWithinSingleNode', ' - its a TextNode');
      final startOffset = (startPosition as TextPosition).offset;
      final endOffset = (endPosition as TextPosition).offset;
      _log.log('_deleteSelectionWithinSingleNode', ' - deleting from $startOffset to $endOffset');

      final deletedText = node.text.copyText(startOffset, endOffset);
      document.replaceNodeByPath(
        nodePath,
        node.copyTextNodeWith(
          text: node.text.removeRegion(
            startOffset: startOffset,
            endOffset: endOffset,
          ),
        ),
      );

      return [
        DocumentEdit(
          TextDeletedEvent(
            nodePath,
            deletedText: deletedText,
            offset: startOffset,
          ),
        ),
      ];
    }

    return [];
  }

  List<EditEvent> _deleteNodesBetweenFirstAndLast({
    required MutableDocument document,
    required List<(NodePath, DocumentNode)> nodes,
  }) {
    if (nodes.first.$1 == nodes.last.$1) {
      // The start and end nodes are the same. Nothing to delete.
      return [];
    }

    _log.log('_deleteNodesBetweenFirstAndLast', ' - start node: ${nodes.first.$1}');
    _log.log('_deleteNodesBetweenFirstAndLast', ' - end node: ${nodes.last.$1}');
    _log.log('_deleteNodesBetweenFirstAndLast', ' - initially ${document.nodeCount} nodes');

    // Remove nodes from last to first so that indices don't get
    // screwed up during removal.
    final changes = <EditEvent>[];
    for (final (path, _) in nodes.reversed.skip(1).take(nodes.length - 2)) {
      _log.log('_deleteNodesBetweenFirstAndLast', ' - deleting node: $path');
      if (document.canDeleteNode(path)) {
        // This node is deletable, so delete it.
        final deleted = document.deleteNodeAtPath(path);
        if (deleted != null) {
          changes.add(DocumentEdit(
            NodeRemovedEvent(deleted.$1, deleted.$2),
          ));
        }
      }
    }
    return changes;
  }

  List<EditEvent> _deleteRangeWithinNodeFromPositionToEnd({
    required MutableDocument document,
    required NodePath path,
    required DocumentNode node,
    required NodePosition nodePosition,
    required bool replaceWithParagraph,
  }) {
    if (nodePosition is UpstreamDownstreamNodePosition) {
      if (nodePosition.affinity == TextAffinity.downstream) {
        // The position is already at the end of the node. Nothing to do.
        return [];
      }

      // The position is on the upstream side of block-level content.
      // Delete the whole block.
      return _deleteBlockLevelNode(
        document: document,
        path: path,
        node: node,
        replaceWithParagraph: replaceWithParagraph,
      );
    } else if (nodePosition is TextPosition && node is TextNode) {
      if (nodePosition == node.beginningPosition) {
        // All text is selected. Delete the node.
        document.deleteNodeAtPath(path);

        return [
          DocumentEdit(
            NodeRemovedEvent(path, node),
          )
        ];
      } else {
        final textNodePosition = nodePosition as TextNodePosition;

        // Delete part of the text.
        final deletedText = node.text.copyText(textNodePosition.offset);

        document.replaceNodeByPath(
          path,
          node.copyTextNodeWith(
            text: node.text.removeRegion(
              startOffset: textNodePosition.offset,
              endOffset: node.text.length,
            ),
          ),
        );

        return [
          DocumentEdit(
            TextDeletedEvent(
              path,
              offset: textNodePosition.offset,
              deletedText: deletedText,
            ),
          )
        ];
      }
    } else {
      throw Exception('Unknown node position type: $nodePosition, for node: $node');
    }
  }

  List<EditEvent> _deleteRangeWithinNodeFromStartToPosition({
    required MutableDocument document,
    required NodePath path,
    required DocumentNode node,
    required NodePosition nodePosition,
  }) {
    if (nodePosition is UpstreamDownstreamNodePosition) {
      if (nodePosition.affinity == TextAffinity.upstream) {
        // The position is already at the beginning of the node. Nothing to do.
        return [];
      }

      // The position is on the downstream side of block-level content.
      // Delete the whole block.
      return _deleteBlockLevelNode(
        document: document,
        path: path,
        node: node,
        replaceWithParagraph: false,
      );
    } else if (nodePosition is TextPosition && node is TextNode) {
      if (nodePosition == node.endPosition) {
        // All text is selected. Delete the node.
        document.deleteNodeAtPath(path);

        return [
          DocumentEdit(
            NodeRemovedEvent(path, node),
          )
        ];
      } else {
        final textNodePosition = nodePosition as TextNodePosition;

        // Delete part of the text.
        final deletedText = node.text.copyText(0, textNodePosition.offset);

        document.replaceNodeByPath(
          path,
          node.copyTextNodeWith(
            text: node.text.removeRegion(
              startOffset: 0,
              endOffset: textNodePosition.offset,
            ),
          ),
        );

        return [
          DocumentEdit(
            TextDeletedEvent(
              path,
              offset: 0,
              deletedText: deletedText,
            ),
          ),
        ];
      }
    } else {
      throw Exception('Unknown node position type: $nodePosition, for node: $node');
    }
  }

  List<EditEvent> _deleteBlockLevelNode({
    required MutableDocument document,
    required NodePath path,
    required DocumentNode node,
    required bool replaceWithParagraph,
  }) {
    if (replaceWithParagraph) {
      // TODO: for now deleting a block-level node simply means replacing
      //       it with an empty ParagraphNode because after doing that,
      //       the general deletion logic that called this function will
      //       collapse empty paragraphs together, which gives the
      //       result we want.
      //
      //       We avoid deleting the node because the composer is
      //       depending on the first node still existing at the end of
      //       the deletion. This is a fragile relationship between the
      //       composer and the editor and needs to be addressed.
      _log.log('_deleteBlockNode', ' - replacing block-level node with a ParagraphNode: ${node.id}');

      final newNode = ParagraphNode(id: node.id, text: AttributedText());
      document.replaceNodeByPath(path, newNode);

      return [
        DocumentEdit(
          NodeRemovedEvent(path, node),
        ),
        DocumentEdit(
          NodeInsertedEvent(path, document.getNodeIndexInParent(path)),
        ),
      ];
    } else {
      _log.log('_deleteBlockNode', ' - deleting block level node');
      document.deleteNodeAtPath(path);

      return [
        DocumentEdit(
          NodeRemovedEvent(path, node),
        )
      ];
    }
  }
}

/// Deletes the selected content within the document.
///
/// Any selected, non-deletable nodes are retained without removal.
///
/// The [affinity] defines the direction to where the user is trying to
/// delete. For example, if the users presses the backspace key, the
/// [affinity] should be [TextAffinity.upstream]. If the user presses the
/// delete key, the [affinity] should be [TextAffinity.downstream]. The
/// [affinity] influences the new selection after the deletion when the
/// dowstream of upstream node is non-deletable. For example, pressing
/// backspace when the upstream node is not deletable doesn't change
/// the selection, but pressing delete does.
class DeleteSelectionRequest implements EditRequest {
  const DeleteSelectionRequest(this.affinity);

  final TextAffinity affinity;
}

class DeleteSelectionCommand extends EditCommand {
  DeleteSelectionCommand({
    required this.affinity,
  });

  final TextAffinity affinity;

  @override
  HistoryBehavior get historyBehavior => HistoryBehavior.undoable;

  @override
  String describe() => "Delete selected content";

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.document;
    final composer = context.composer;

    final selection = composer.selection;
    if (selection == null) {
      return;
    }

    print('delete selection happened');
    // TODO: Revisit for CompositeNode case -aleksey

    if (selection.base.nodeId == selection.extent.nodeId) {
      // The selection is contained within a single node. Prevent the deletion
      // if the node is non-deletable. When there are multiple nodes selected,
      // non-deletable nodes are ignored inside DeleteContentCommand.
      final node = document.getNodeById(selection.base.nodeId)!;
      if (!node.isDeletable) {
        if (node is BlockNode && !selection.isCollapsed) {
          // On iOS, pressing backspace generates a non-text delta expanding the selection
          // prior to its deletion. Since we can't delete the block, we'll just collapse the
          // selection to the end of the block.
          executor.executeCommand(
            ChangeSelectionCommand(
              DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: node.id,
                  nodePosition: node.endPosition,
                ),
              ),
              SelectionChangeType.placeCaret,
              SelectionReason.contentChange,
            ),
          );
        }
        return;
      }
    }

    final nodes = document.getNodesInside(selection.start, selection.end);
    if (nodes.every((node) => !node.isDeletable)) {
      // All selected nodes are non-deletable. Do nothing.
      return;
    }

    if (nodes.length == 2) {
      final normalizedSelection = selection.normalize(document);
      final nodeAbove = document.getNode(normalizedSelection.start)!;
      final nodeBelow = document.getNode(normalizedSelection.end)!;

      if (nodeAbove is BlockNode &&
          !nodeAbove.isDeletable &&
          normalizedSelection.end.nodePosition.isEquivalentTo(nodeBelow.beginningPosition)) {
        // We have the following scenario, where |> and <| represent the selection:
        //
        // <non-deletable node>|>
        // <|text

        if (affinity == TextAffinity.upstream) {
          // The user is trying to delete using backspace (we assume this because the deletion is in
          // upstream direction). Do nothing.
          return;
        }

        // The user is trying to delete using the delete key (we assume this because the deletion is in
        // upstream direction). Move the selection to the node below.
        executor.executeCommand(
          ChangeSelectionCommand(
            DocumentSelection.collapsed(position: normalizedSelection.end),
            SelectionChangeType.deleteContent,
            SelectionReason.userInteraction,
          ),
        );
        return;
      }

      if (nodeBelow is BlockNode &&
          !nodeBelow.isDeletable &&
          normalizedSelection.start.nodePosition.isEquivalentTo(nodeAbove.endPosition)) {
        // We have the following scenario, where |> and <| represent the selection:
        //
        // text|>
        // <|<non-deletable node>

        if (affinity == TextAffinity.downstream) {
          // The user is trying to delete using the delete key (we assume this because the deletion is in
          // downstream direction). Do nothing.
          return;
        }
      }
    }

    final newSelectionPosition = CommonEditorOperations.getDocumentPositionAfterExpandedDeletion(
      document: document,
      selection: selection,
    );

    executor.executeCommand(
      DeleteContentCommand(
        documentRange: selection,
      ),
    );

    if (newSelectionPosition != null) {
      executor.executeCommand(
        ChangeSelectionCommand(
          DocumentSelection.collapsed(position: newSelectionPosition),
          SelectionChangeType.deleteContent,
          SelectionReason.userInteraction,
        ),
      );
    }
  }
}

/// Request to handle a collapsed selection upstream deletion at the
/// beginning of a [node].
///
/// When this request is submitted, the caret should be at the beginning of
/// the given [node].
///
/// This request is likely to be handled differently based on the type of
/// [node] where this upstream deletion takes place. For example, a paragraph
/// might combine with the paragraph above it. A list item might convert
/// to a regular paragraph.
class DeleteUpstreamAtBeginningOfNodeRequest implements EditRequest {
  DeleteUpstreamAtBeginningOfNodeRequest(this.node);

  /// The [DocumentNode] where an upstream deletion should take
  /// place at the beginning end of the node.
  final DocumentNode node;
}

class DeleteNodeRequest implements EditRequest {
  DeleteNodeRequest({
    required this.nodePath,
  });

  final NodePath nodePath;
}

class DeleteNodeCommand extends EditCommand {
  DeleteNodeCommand({
    required this.nodePath,
  });

  final NodePath nodePath;

  @override
  HistoryBehavior get historyBehavior => HistoryBehavior.undoable;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    _log.log('DeleteNodeCommand', 'DocumentEditor: deleting node: $nodePath');

    final document = context.document;
    final node = document.getNodeAtPath(nodePath);
    if (node == null) {
      _log.log('DeleteNodeCommand', 'No such node. Returning.');
      return;
    }

    _log.log('DeleteNodeCommand', ' - deleting node');
    document.deleteNodeAtPath(nodePath);
    _log.log('DeleteNodeCommand', ' - done with node deletion');
    executor.logChanges([
      DocumentEdit(
        NodeRemovedEvent(nodePath, node),
      )
    ]);
  }
}

/// An [EditRequest] to clear the document's content.
///
/// This request:
///
/// - Removes all nodes from the document.
/// - Adds a new empty paragraph.
/// - Places the caret at the beginning of the new paragraph.
/// - Clears the composing region.
class ClearDocumentRequest implements EditRequest {
  const ClearDocumentRequest();
}

class ClearDocumentCommand extends EditCommand {
  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.document;

    for (final node in document) {
      executor.logChanges([
        DocumentEdit(
          NodeRemovedEvent(NodePath.withNodeId(node.id), node),
        )
      ]);
    }

    document.clear();

    final newNodeId = Editor.createNodeId();
    executor
      ..executeCommand(
        InsertNodeAtIndexCommand(
          nodeIndex: 0,
          newNode: ParagraphNode(
            id: newNodeId,
            text: AttributedText(),
          ),
        ),
      )
      ..executeCommand(
        ChangeSelectionCommand(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: newNodeId,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
          SelectionChangeType.insertContent,
          SelectionReason.userInteraction,
        ),
      )
      ..executeCommand(ChangeComposingRegionCommand(null));
  }
}
