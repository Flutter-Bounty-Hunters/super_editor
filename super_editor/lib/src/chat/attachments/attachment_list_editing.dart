import 'package:attributed_text/attributed_text.dart';
import 'package:super_editor/src/chat/attachments/attachment_list_node.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/default_editor/multi_node_editing.dart';
import 'package:super_editor/src/default_editor/paragraph.dart';
import 'package:super_editor/src/default_editor/text.dart';

/// Inserts the given [attachments]s as a list of attachments at the current
/// caret position.
///
/// If no selection is present, or if the selection is expanded, the attachments
/// are inserted a new [AttachmentListNode] at the end of the document.
///
/// If the caret sits in an existing [AttachmentListNode], the [attachments] are inserted
/// within the existing node.
///
/// If the caret sits in a splittable node, such as a `ParagraphNode`, the node is
/// split in two, and a new [AttachmentListNode] is inserted between them.
///
/// If the caret sits in a non-splittable node, a new [AttachmentListNode] is inserted
/// after that node, and the caret is placed at the end of the list.
class InsertAttachmentListRequest<AttachmentType> implements EditRequest {
  const InsertAttachmentListRequest(
    this.attachments, {
    required this.newNodeId,
    required this.splitNodeId,
  });

  /// ID given to the new attachment list node.
  final String newNodeId;

  /// ID given, when necessary, to the second part when the currently selected
  /// node is split into two, such as splitting a paragraph at the caret.
  final String splitNodeId;

  final List<Object> attachments;
}

class InsertAttachmentListCommand extends EditCommand {
  const InsertAttachmentListCommand(
    this.attachments, {
    required this.newNodeId,
    required this.splitNodeId,
  });

  final String newNodeId;

  final String splitNodeId;

  final List<Object> attachments;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final selection = context.composer.selection;
    if (selection == null || !selection.isCollapsed) {
      // Insert the attachments at the end of the document, and don't
      // touch the selection.
      executor.executeCommand(
        InsertNodeAtIndexCommand(
          nodeIndex: context.document.length,
          newNode: AttachmentListNode(id: newNodeId, attachments: attachments),
        ),
      );

      return;
    }

    // Selection is collapsed. Decide whether to split a node, or whether
    // to insert after the node, and place the caret at the end of the list.
    final nodeWithCaret = context.document.getNodeById(selection.extent.nodeId)!;
    if (nodeWithCaret is AttachmentListNode && selection.extent.nodePosition is AttachmentListNodePosition) {
      final positionInExistingList = selection.extent.nodePosition as AttachmentListNodePosition;
      final (updatedNode, updatedPosition) = nodeWithCaret.insertAttachmentsAt(
        attachments,
        positionInExistingList.gapIndex,
      );

      executor
        ..executeCommand(
          ReplaceNodeCommand(
            existingNodeId: nodeWithCaret.id,
            newNode: updatedNode,
          ),
        )
        ..executeCommand(
          ChangeSelectionCommand(
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: nodeWithCaret.id,
                nodePosition: updatedPosition,
              ),
            ),
            SelectionChangeType.insertContent,
            SelectionReason.userInteraction,
          ),
        )
        ..executeCommand(ChangeComposingRegionCommand(null));
    } else if (nodeWithCaret.endPosition.isEquivalentTo(selection.extent.nodePosition)) {
      // Caret is at end of node. Rather than split it, just insert a new attachment list
      // after this node.
      executor
        ..executeCommand(
          InsertNodeAfterNodeCommand(
            existingNodeId: nodeWithCaret.id,
            newNode: AttachmentListNode(id: newNodeId, attachments: attachments),
          ),
        )
        ..executeCommand(
          ChangeSelectionCommand(
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: newNodeId,
                nodePosition: AttachmentListNodePosition(attachments.length),
              ),
            ),
            SelectionChangeType.insertContent,
            SelectionReason.userInteraction,
          ),
        )
        ..executeCommand(ChangeComposingRegionCommand(null));
    } else if (nodeWithCaret.beginningPosition.isEquivalentTo(selection.extent.nodePosition)) {
      // Caret is at beginning of node. Rather than split it, just insert a new attachment
      // list before this node.
      executor
        ..executeCommand(
          InsertNodeBeforeNodeCommand(
            existingNodeId: nodeWithCaret.id,
            newNode: AttachmentListNode(id: newNodeId, attachments: attachments),
          ),
        )
        ..executeCommand(
          ChangeSelectionCommand(
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: newNodeId,
                nodePosition: AttachmentListNodePosition(attachments.length),
              ),
            ),
            SelectionChangeType.insertContent,
            SelectionReason.userInteraction,
          ),
        )
        ..executeCommand(ChangeComposingRegionCommand(null));
    } else if (nodeWithCaret is EditableDocumentNode && nodeWithCaret.canSplitAt(selection.extent.nodePosition)) {
      final (firstPart, secondPart) = nodeWithCaret.splitAt(selection.extent.nodePosition, newId: splitNodeId);
      final attachmentsNode = AttachmentListNode(id: newNodeId, attachments: attachments);

      executor
        ..executeCommand(ReplaceNodeCommand(existingNodeId: firstPart.id, newNode: firstPart))
        ..executeCommand(InsertNodeAfterNodeCommand(existingNodeId: firstPart.id, newNode: secondPart))
        ..executeCommand(InsertNodeAfterNodeCommand(existingNodeId: firstPart.id, newNode: attachmentsNode))
        ..executeCommand(
          ChangeSelectionCommand(
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: newNodeId,
                nodePosition: AttachmentListNodePosition(attachments.length),
              ),
            ),
            SelectionChangeType.insertContent,
            SelectionReason.userInteraction,
          ),
        )
        ..executeCommand(ChangeComposingRegionCommand(null));
    } else if (nodeWithCaret is ParagraphNode && selection.extent.nodePosition is TextNodePosition) {
      final (firstPart, secondPart) = nodeWithCaret.splitAt(selection.extent.nodePosition, newId: splitNodeId);
      final attachmentsNode = AttachmentListNode(id: newNodeId, attachments: attachments);

      executor
        ..executeCommand(ReplaceNodeCommand(existingNodeId: firstPart.id, newNode: firstPart))
        ..executeCommand(InsertNodeAfterNodeCommand(existingNodeId: firstPart.id, newNode: secondPart))
        ..executeCommand(InsertNodeAfterNodeCommand(existingNodeId: firstPart.id, newNode: attachmentsNode))
        ..executeCommand(
          ChangeSelectionCommand(
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: newNodeId,
                nodePosition: AttachmentListNodePosition(attachments.length),
              ),
            ),
            SelectionChangeType.insertContent,
            SelectionReason.userInteraction,
          ),
        )
        ..executeCommand(ChangeComposingRegionCommand(null));
    } else {
      executor
        ..executeCommand(
          InsertNodeAfterNodeCommand(
            existingNodeId: nodeWithCaret.id,
            newNode: AttachmentListNode(id: newNodeId, attachments: attachments),
          ),
        )
        ..executeCommand(
          ChangeSelectionCommand(
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: newNodeId,
                nodePosition: AttachmentListNodePosition(attachments.length),
              ),
            ),
            SelectionChangeType.insertContent,
            SelectionReason.userInteraction,
          ),
        )
        ..executeCommand(ChangeComposingRegionCommand(null));
    }
  }
}

class DeleteAttachmentFromListRequest implements EditRequest {
  const DeleteAttachmentFromListRequest({
    required this.nodeId,
    required this.attachmentIndex,
  });

  final String nodeId;
  final int attachmentIndex;
}

class DeleteAttachmentFromListCommand extends EditCommand {
  const DeleteAttachmentFromListCommand({
    required this.nodeId,
    required this.attachmentIndex,
  });

  final String nodeId;
  final int attachmentIndex;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final node = context.document.getNodeById(nodeId);

    assert(node is AttachmentListNode,
        "Tried to delete an attachment from a non-attachment node (node: ${node.runtimeType})");
    if (node is! AttachmentListNode) {
      return;
    }

    assert(attachmentIndex >= 0, "Tried to delete an attachment at a negative index: $attachmentIndex");
    assert(attachmentIndex < node.attachments.length,
        "Tried to delete attachment at index that's too high (index: $attachmentIndex, available attachments: ${node.attachments.length})");
    if (attachmentIndex < 0 || attachmentIndex >= node.attachments.length) {
      return;
    }

    if (node.attachments.length == 1) {
      // We're deleting the only attachment. Replace the attachment list
      // with a paragraph.

      // Since we're replacing the attachment list node, any selection position
      // inside that node needs to also be replaced with a text node position.
      final selection = context.composer.selection;
      final needToAdjustSelectionBase = selection != null && selection.base.nodeId == nodeId;
      final needToAdjustSelectionExtent = selection != null && selection.extent.nodeId == nodeId;

      executor.executeCommand(
        ReplaceNodeCommand(
          existingNodeId: nodeId,
          newNode: ParagraphNode(
            id: nodeId,
            text: AttributedText(),
          ),
        ),
      );

      if (needToAdjustSelectionBase || needToAdjustSelectionExtent) {
        executor
          ..executeCommand(
            ChangeSelectionCommand(
              DocumentSelection(
                base: needToAdjustSelectionBase
                    ? DocumentPosition(nodeId: nodeId, nodePosition: const TextNodePosition(offset: 0))
                    : selection.base,
                extent: needToAdjustSelectionExtent
                    ? DocumentPosition(nodeId: nodeId, nodePosition: const TextNodePosition(offset: 0))
                    : selection.extent,
              ),
              SelectionChangeType.deleteContent,
              SelectionReason.userInteraction,
            ),
          )
          ..executeCommand(ChangeComposingRegionCommand(null));
      }

      return;
    }

    // Replace the attachment list with a new list that doesn't include the
    // specified attachment.
    final updatedNode = node.deleteAttachmentAt(attachmentIndex);
    executor.executeCommand(
      ReplaceNodeCommand(existingNodeId: nodeId, newNode: updatedNode),
    );

    // Update the document selection to ensure that a base or extent position
    // inside of this node pushes one position upstream, if they appeared beyond
    // the deleted attachment.
    final selection = context.composer.selection;
    if (selection == null) {
      // No selection, so we don't need to adjust it. We're done.
      return;
    }

    late final DocumentPosition newBase;
    late final DocumentPosition newExtent;

    if (selection.base.nodeId == nodeId && node.containsPosition(selection.base.nodePosition)) {
      final baseNodePosition = selection.base.nodePosition as AttachmentListNodePosition;
      if (baseNodePosition.gapIndex > attachmentIndex) {
        // The base position sits within this node, and it's downstream from the
        // deleted attachment, which means we need to push it upstream by one.
        newBase = selection.base.copyWith(nodePosition: baseNodePosition.moveUpstream());
      } else {
        // Base isn't beyond the removed attachment. We don't need to mess with it.
        newBase = selection.base;
      }
    } else {
      // Base isn't in the node. We don't need to mess with it.
      newBase = selection.base;
    }

    if (selection.extent.nodeId == nodeId && node.containsPosition(selection.extent.nodePosition)) {
      final extentNodePosition = selection.extent.nodePosition as AttachmentListNodePosition;
      if (extentNodePosition.gapIndex > attachmentIndex) {
        // The extent position sits within this node, and it's downstream from the
        // deleted attachment, which means we need to push it upstream by one.
        newExtent = selection.extent.copyWith(nodePosition: extentNodePosition.moveUpstream());
      } else {
        // Extent isn't beyond the removed attachment. We don't need to mess with it.
        newExtent = selection.extent;
      }
    } else {
      // Extent isn't in the node. We don't need to mess with it.
      newExtent = selection.extent;
    }

    final newSelection = DocumentSelection(base: newBase, extent: newExtent);
    if (newSelection == selection) {
      // Selection didn't change. We don't need to update it. We're done.
      return;
    }

    executor.executeCommand(
      ChangeSelectionCommand(
        newSelection,
        SelectionChangeType.deleteContent,
        SelectionReason.userInteraction,
      ),
    );
  }
}
