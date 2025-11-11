import 'package:flutter/material.dart' show EdgeInsets;
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/default_editor/document_ime/ime_node_serialization.dart';
import 'package:super_editor/src/default_editor/layout_single_column/layout_single_column.dart';

/// A view model for a [CompositeNode], which is a node that contains other nodes.
class CompositeNodeViewModel extends SingleColumnLayoutComponentViewModel {
  CompositeNodeViewModel({
    required super.nodeId,
    super.createdAt,
    super.padding = EdgeInsets.zero,
    super.maxWidth,
    required this.children,
  });

  final List<SingleColumnLayoutComponentViewModel> children;

  @override
  SingleColumnLayoutComponentViewModel copy() {
    return CompositeNodeViewModel(
      nodeId: nodeId,
      createdAt: createdAt,
      padding: padding,
      maxWidth: maxWidth,
      children: List.from(children),
    );
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
abstract class CompositeNode extends DocumentNode implements ImeNodeSerialization {
  CompositeNode({
    required this.id,
    super.metadata,
  });

  @override
  final String id;

  Iterable<DocumentNode> get children;

  DocumentNode getChildAt(int index) => children.elementAt(index);

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

  static const _imeChildrenSeparator = '\n';
  static const _imeNonSerializableChildChar = '~';

  @override
  int imeOffsetFromNodePosition(CompositeNodePosition position) {
    assert(position is CompositeNodePosition,
        'Expected a _CompositeNodePosition for imeOffsetFromPosition but received a ${position.runtimeType}');

    var offsetBeforeChild = 0;
    for (final child in children) {
      if (position.childNodeId == child.id) {
        if (child is ImeNodeSerialization) {
          return offsetBeforeChild +
              (child as ImeNodeSerialization).imeOffsetFromNodePosition(position.childNodePosition);
        } else if (position.childNodePosition == child.beginningPosition) {
          return offsetBeforeChild;
        } else {
          return offsetBeforeChild + _imeNonSerializableChildChar.length;
        }
      }
      offsetBeforeChild += _imeTextFromNode(child).length + _imeChildrenSeparator.length;
    }

    throw Exception(
      'Failed to convert position ${position.childNodePosition} into IME-compatible offset. '
      'CompositeNode could not find a child by id "${position.childNodeId}". '
      'Available ids:\n${children.map((c) => '- "${c.id}"').join(',\n')}',
    );
  }

  @override
  NodePosition nodePositionFromImeOffset(int imeOffset) {
    var offsetBeforeChild = 0;
    for (final child in children) {
      final childImeTextLength = _imeTextFromNode(child).length;
      // Looking for a child where imeOffset position is
      if (imeOffset >= offsetBeforeChild && imeOffset <= offsetBeforeChild + childImeTextLength) {
        final offsetInsideChild = imeOffset - offsetBeforeChild;
        NodePosition childPosition;
        if (child is ImeNodeSerialization) {
          childPosition = (child as ImeNodeSerialization).nodePositionFromImeOffset(offsetInsideChild);
        } else if (offsetInsideChild == 0) {
          childPosition = child.beginningPosition;
        } else {
          childPosition = child.endPosition;
        }
        return CompositeNodePosition(child.id, childPosition);
      }
      offsetBeforeChild += childImeTextLength + _imeChildrenSeparator.length;
    }
    throw Exception(
        "Unable to find a child of CompositeNode where IME offset is. ImeOffset: $imeOffset. Composite Node range: 0..${toImeText().length}");
  }

  @override
  String toImeText() {
    return children.map((c) => _imeTextFromNode(c)).join(_imeChildrenSeparator);
  }

  String _imeTextFromNode(DocumentNode node) {
    return node is ImeNodeSerialization ? (node as ImeNodeSerialization).toImeText() : _imeNonSerializableChildChar;
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
