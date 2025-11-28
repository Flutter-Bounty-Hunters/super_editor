import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show EdgeInsets;
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/default_editor/layout_single_column/layout_single_column.dart';

/// A view model for a [CompositeNode], which is a node that contains other nodes.
class CompositeNodeViewModel extends SingleColumnLayoutComponentViewModel {
  CompositeNodeViewModel({
    required super.nodeId,
    super.createdAt,
    super.padding = EdgeInsets.zero,
    super.maxWidth,
    required Iterable<SingleColumnLayoutComponentViewModel> children,
  }) : children = children.map((c) => c.copy()).toList();

  final List<SingleColumnLayoutComponentViewModel> children;

  @override
  SingleColumnLayoutComponentViewModel copy() {
    return internalCopy(
      CompositeNodeViewModel(nodeId: nodeId, children: children),
    );
  }

  CompositeNodeViewModel internalCopy(covariant CompositeNodeViewModel viewModel) {
    // [nodeId] and [children] are required to set in the constructor
    // SingleColumnLayoutComponentViewModel properties:
    viewModel.createdAt = createdAt;
    viewModel.maxWidth = maxWidth;
    viewModel.padding = padding;
    viewModel.opacity = opacity;

    return viewModel;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (super != other || other is! CompositeNodeViewModel || other.runtimeType != runtimeType) {
      return false;
    }
    return hasSameChildren(other);
  }

  @override
  int get hashCode => Object.hash(super.hashCode, Object.hashAll(children));

  /// Returns true only when [other] have same children count
  /// and children runtimeTypes are matches accordingly.
  /// Checks recursively
  bool hasSameChildrenStructure(CompositeNodeViewModel other) {
    if (other.children.length != children.length) {
      return false;
    }
    for (var i = 0; i < children.length; i += 1) {
      final child = children[i];
      final otherChild = other.children[i];
      if (child.runtimeType != otherChild.runtimeType) {
        return false;
      }
      if (child is CompositeNodeViewModel && !child.hasSameChildrenStructure(otherChild as CompositeNodeViewModel)) {
        return false;
      }
    }
    return true;
  }

  bool hasSameChildren(CompositeNodeViewModel other) {
    return listEquals(children, other.children);
  }

  /// Controls whether selection is automatically applied to selectable child viewModels.
  ///
  /// Return `true` to enable the default behavior (children show their own selection visuals).
  /// Return `false` to suppress child selection and implement custom selection logic
  /// (e.g., selecting a whole table cell without highlighting its inner text).
  bool shouldApplySelectionToChildren() {
    return true;
  }
}

/// A [DocumentNode] that contains other [DocumentNode]s.
///
/// A [CompositeNode] includes an iterable, content-order list of [children], however,
/// it has no knowledge about the visual orientation of those children. They might flow
/// in a column, row, table, or anything else. The only requirement is that all children
/// are iterable in a consistent content order, and that the first child is considered
/// the beginning of the content, and the last child is considered the end of the content.
///
/// This node includes sane default implementations for reporting beginning, ending, upstream,
/// and downstream positions within the [CompositeNode].
abstract class CompositeNode extends DocumentNode {
  CompositeNode({
    required this.id,
    super.metadata,
  }) {
    validateChildrenNodeIds();
  }

  @override
  final String id;

  Iterable<DocumentNode> get children;

  DocumentNode getChildAt(int index) => children.elementAt(index);

  DocumentNode getChild(CompositeNodePosition position) {
    final child = getChildByNodeId(position.childNodeId)!;
    if (child is CompositeNode && position.childNodePosition is CompositeNodePosition) {
      return child.getChild(position.childNodePosition as CompositeNodePosition);
    }
    return child;
  }

  DocumentNode? getChildByNodeId(String nodeId) {
    return children.firstWhereOrNull((c) => c.id == nodeId);
  }

  int getChildIndexByNodeId(String nodeId) {
    var index = 0;
    for (final child in children) {
      if (child.id == nodeId) {
        return index;
      }
      index += 1;
    }
    return -1;
  }

  void validateChildrenNodeIds() {
    assert(
      children.map((c) => c.id).toSet().length == children.length,
      'Duplicated id within composite $runtimeType node detected. nodeId=$id, '
      'children=[${children.map((c) => c.id).join(', ')}]',
    );
  }

  CompositeNode copyWithChildren(List<DocumentNode> children);

  /// Find a [CompositeNode] specified by [nodePath] and replace it's children using [childrenReplacer] function,
  /// then returns a new root [CompositeNode]
  CompositeNode copyAndReplaceLeafChildren({
    required NodePath nodePath,
    required List<DocumentNode> Function(CompositeNode parent, List<DocumentNode> children) childrenReplacer,
  }) {
    assert(
      nodePath.rootNodeId == id,
      'Invalid NodePathIterator state. `current` should point to children of current CompositeNode',
    );

    // If CompositeNode is just the root node, replace its children directly
    if (nodePath.isRoot) {
      return copyWithChildren(childrenReplacer(this, children.toList()));
    }

    // Traverse down: root -> ... -> parent of leaf
    var current = this;
    final parents = <CompositeNode>[];

    for (final childId in nodePath.skip(1)) {
      final child = current.getChildByNodeId(childId);
      if (child is! CompositeNode) {
        throw Exception(
          'Expected CompositeNode at path $nodePath, but "$childId" is ${child.runtimeType}',
        );
      }
      parents.add(current);
      current = child;
    }

    // Replace children in the target node (leaf parent)
    var updated = current.copyWithChildren(
      childrenReplacer(current, current.children.toList()),
    );

    // Rebuild up the tree: replace child in each parent
    for (final parent in parents.reversed) {
      updated = parent.copyWithChildren(
        parent.children.map((c) => c.id == updated.id ? updated : c).toList(),
      );
    }

    return updated;
  }

  @override
  NodePosition get beginningPosition => CompositeNodePosition(
        children.first.id,
        children.first.beginningPosition,
      );

  @override
  NodePosition get endPosition => CompositeNodePosition(
        children.last.id,
        children.last.endPosition,
      );

  @override
  bool containsPosition(Object position) {
    if (position is! CompositeNodePosition) {
      return false;
    }

    for (final child in children) {
      if (child.id == position.childNodeId) {
        return child.containsPosition(position.childNodePosition);
      }
    }

    return false;
  }

  @override
  NodePosition selectUpstreamPosition(NodePosition position1, NodePosition position2) {
    if (position1 is! CompositeNodePosition) {
      throw Exception('Expected a _CompositeNodePosition for position1 but received a ${position1.runtimeType}');
    }
    if (position2 is! CompositeNodePosition) {
      throw Exception('Expected a _CompositeNodePosition for position2 but received a ${position2.runtimeType}');
    }

    final index1 = getChildIndexByNodeId(position1.childNodeId);
    final index2 = getChildIndexByNodeId(position2.childNodeId);

    if (index1 == index2) {
      return position1.childNodePosition ==
              getChildAt(index1).selectUpstreamPosition(position1.childNodePosition, position2.childNodePosition)
          ? position1
          : position2;
    }

    return index1 < index2 ? position1 : position2;
  }

  @override
  NodePosition selectDownstreamPosition(NodePosition position1, NodePosition position2) {
    final upstream = selectUpstreamPosition(position1, position2);
    return upstream == position1 ? position2 : position1;
  }

  @override
  NodeSelection computeSelection({required NodePosition base, required NodePosition extent}) {
    assert(base is CompositeNodePosition);
    assert(extent is CompositeNodePosition);

    return CompositeNodeSelection(
      base: base as CompositeNodePosition,
      extent: extent as CompositeNodePosition,
    );
  }

  /// If true — this node is "isolating":
  /// - Cursor cannot escape it on Backspace/Delete at edges
  /// - Content cannot merge with previous/next nodes
  /// - When emptied, cursor stays inside (usually with a placeholder)
  bool get isIsolating => false;

  List<String>? getSelectedChildrenBetween(String upstreamChildId, String downstreamChildId) {
    return null;
  }

  CompositeNodePosition? adjustUpstreamPosition({
    required CompositeNodePosition upstreamPosition,
    CompositeNodePosition? downstreamPosition,
  }) {
    return null;
  }

  CompositeNodePosition? adjustDownstreamPosition({
    required CompositeNodePosition downstreamPosition,
    CompositeNodePosition? upstreamPosition,
  }) {
    return null;
  }

  /// Called after a deletion operation when one or more of this node’s children
  /// were either removed completely or became empty (i.e. a child CompositeNode
  /// returned a placeholder because its own content was deleted).
  ///
  /// This is the single hook that allows a composite node to react to structural
  /// degradation of its subtree (e.g. an empty table cell, an empty table, etc.).
  ///
  /// Parameters:
  /// - [removedChildIds] – IDs of children that were fully removed
  /// - [emptiedChildIds] – IDs of children that still exist but became empty (and then copied with a placeholder)
  /// - [selectionFlowedThrough] – true if the deleted selection started before this
  ///                               node and ended after it (the node was completely
  ///                               inside a larger text selection). false if the
  ///                               selection was isolated to this node or partial.
  /// Returns:
  /// - `this`          – keep this node unchanged
  /// - `null`          – remove this node entirely
  /// - `this.copyWith(…)` – replace this node with a modified version
  CompositeNode? resolveWhenChildrenAffected({
    required List<String> removedChildIds,
    required List<String> emptiedChildIds,
    required bool selectionFlowedThrough,
  }) {
    if (children.isEmpty) {
      return null;
    }
    return this;
  }
}

class CompositeNodeSelection implements NodeSelection {
  const CompositeNodeSelection.collapsed(CompositeNodePosition position)
      : base = position,
        extent = position;

  const CompositeNodeSelection({
    required this.base,
    required this.extent,
  });

  final CompositeNodePosition base;

  final CompositeNodePosition extent;
}

class CompositeNodePosition implements NodePosition {
  const CompositeNodePosition(this.childNodeId, this.childNodePosition);

  final String childNodeId;
  final NodePosition childNodePosition;

  CompositeNodePosition moveWithinChild(NodePosition newPosition) {
    return CompositeNodePosition(childNodeId, newPosition);
  }

  /// Projects a leaf [NodePosition] up into the [CompositeNodePosition] of the ancestor
  /// [CompositeNode] identified by [parentId]
  static CompositeNodePosition projectPositionIntoParent(
    String parentId,
    NodePath leafPath,
    NodePosition leafPosition,
  ) {
    assert(leafPath.nodeId != parentId, 'Path should be to child node, not parent');
    final indexInBasePath = leafPath.indexOfNodeId(parentId);
    if (indexInBasePath == -1) {
      throw Exception(
        'Cannot project position: parentId "$parentId" is not an ancestor of the leaf '
        'at path $leafPath',
      );
    }
    if (indexInBasePath == leafPath.length - 1) {
      throw Exception(
        'Cannot project position to itself: parentId "$parentId" is the leaf node. '
        'Use the leafPosition directly.',
      );
    }
    var result = leafPosition;
    for (var i = leafPath.length - 1; i > indexInBasePath; i -= 1) {
      result = CompositeNodePosition(leafPath[i], result);
    }
    return result as CompositeNodePosition;
  }

  @override
  bool isEquivalentTo(NodePosition other) {
    return this == other;
  }

  @override
  String toString() => "[CompositeNodePosition] - $childNodeId -> $childNodePosition";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompositeNodePosition &&
          runtimeType == other.runtimeType &&
          childNodeId == other.childNodeId &&
          childNodePosition == other.childNodePosition;

  @override
  int get hashCode => childNodeId.hashCode ^ childNodePosition.hashCode;
}

extension DocumentPositionCompositeEx on DocumentPosition {
  DocumentPosition toLeafPosition() {
    final (nodeId, position) = _resolveLeaf();
    return DocumentPosition(
      nodeId: nodeId,
      nodePosition: position,
    );
  }

  (String, NodePosition) _resolveLeaf() {
    var id = nodeId;
    var currentNodePosition = nodePosition;
    while (currentNodePosition is CompositeNodePosition) {
      id = currentNodePosition.childNodeId;
      currentNodePosition = currentNodePosition.childNodePosition;
    }
    return (id, currentNodePosition);
  }
}
