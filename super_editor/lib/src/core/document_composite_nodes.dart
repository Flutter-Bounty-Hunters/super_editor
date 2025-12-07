import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/default_editor/layout_single_column/composite_nodes.dart';

extension DocumentCompositeNodes on MutableDocument {
  /// Recursively normalizes composite nodes after a deletion operation.
  ///
  /// When content is deleted, child composite nodes may become empty or be removed.
  /// This triggers a bottom-up normalization wave: each affected parent gets a chance
  /// to react via [CompositeNode.resolveWhenChildrenAffected] — it can:
  /// - Return `this` → keep unchanged
  /// - Return `null` → remove itself
  /// - Return `this.copyWith(...)` → transform (e.g. remove a row/column)
  ///
  /// The process repeats with newly generated events until no more structural
  /// changes occur (e.g. cell → table → document section).
  ///
  /// This ensures correct cleanup of empty tables, rows, etc.,
  /// while respecting selection flow and user intent.
  ///
  /// Returns all additional [EditEvent]s produced during normalization.
  List<EditEvent> postProcessCompositeNodesAfterDeletion({
    required List<EditEvent> changes,
    NodePath? startPath,
    NodePath? endPath,
  }) {
    if (changes.isEmpty) {
      return [];
    }

    /// 1. Go through changes and aggregate per parent changes:
    ///   - collect all nodes that were removed per parent
    ///   - collect all CompositeNodes that were changed (replaced) per parent
    final deletedNodesPerParent = <String, List<String>>{};
    final emptiedNodesPerParent = <String, List<String>>{};
    for (final changeEvent in changes) {
      if (changeEvent is! DocumentEdit) {
        continue;
      }
      final change = changeEvent.change;
      if (change is NodeRemovedEvent && change.parentNodeId != null) {
        deletedNodesPerParent[change.parentNodeId!] ??= [];
        deletedNodesPerParent[change.parentNodeId!]!.add(change.nodeId);
      }
      if (change is NodeChangeEvent) {
        final parentNodeId = getNodePathById(change.nodeId)?.parent?.nodeId;
        final changedNode = getNodeById(change.nodeId);
        // If CompositeNode was changed during the deletion - that means it became empty
        // and returned a replacement in reaction to that. Tracking as emptied
        if (parentNodeId != null && changedNode is CompositeNode) {
          emptiedNodesPerParent[parentNodeId] ??= [];
          emptiedNodesPerParent[parentNodeId]!.add(changedNode.id);
        }
      }
    }

    /// 2. Call [resolveWhenChildrenAffected] on each CompositeNode and:
    ///   - replace it, if method returns a new instance (create new Event)
    ///   - delete it, if method returns null (create new Event)
    ///   - keep as is, do nothing, if method returns same instance
    final compositeNodeIds = Set.from(deletedNodesPerParent.keys);
    compositeNodeIds.addAll(emptiedNodesPerParent.keys);

    final newChanges = <EditEvent>[];

    for (final nodeId in compositeNodeIds) {
      // Selected through only when selection defined and does not contain this node (so it's inside selection)
      final selectedThrough =
          startPath != null && endPath != null && !startPath.contains(nodeId) && !endPath.contains(nodeId);
      final node = getNodeById(nodeId) as CompositeNode;
      final replacement = node.resolveWhenChildrenAffected(
        removedChildIds: deletedNodesPerParent[nodeId] ?? [],
        emptiedChildIds: emptiedNodesPerParent[nodeId] ?? [],
        selectionFlowedThrough: selectedThrough,
      );
      if (identical(replacement, node)) {
        // method just returned "this" - ignoring, as nodes are immutable, nothing was changed
        continue;
      }
      if (replacement == null) {
        final parentId = getNodePathById(nodeId)?.parent?.nodeId;
        deleteNode(node.id);
        newChanges.add(
          DocumentEdit(
            NodeRemovedEvent(node.id, node, parentNodeId: parentId),
          ),
        );
      } else {
        replaceNodeById(nodeId, replacement);
        newChanges.add(
          DocumentEdit(
            NodeChangeEvent(node.id),
          ),
        );
      }
    }

    /// 3. Call [postProcessCompositeNodesAfterDeletion] again, but with events produced on step 2
    /// and return together with newChanges
    return [
      ...newChanges,
      ...postProcessCompositeNodesAfterDeletion(startPath: startPath, endPath: endPath, changes: newChanges),
    ];
  }
}
