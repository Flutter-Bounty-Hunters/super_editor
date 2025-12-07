import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/layout_single_column/composite_nodes.dart';

/// a [CompositeComponentChild] is an object that holds already built
/// component, with component key and nodeId.
class CompositeComponentChild {
  final String nodeId;
  final GlobalKey<DocumentComponent> componentKey;
  final Widget widget;
  CompositeComponentChild({
    required this.nodeId,
    required this.componentKey,
    required this.widget,
  });

  DocumentComponent get component => componentKey.currentState!;
  RenderBox get renderBox => component.context.findRenderObject() as RenderBox;

  CompositeComponentChild copyWithWidget(Widget widget) {
    return CompositeComponentChild(
      nodeId: nodeId,
      componentKey: componentKey,
      widget: widget,
    );
  }
}

mixin CompositeComponent<T extends StatefulWidget> on State<T> implements DocumentComponent<T> {
  List<CompositeComponentChild> getChildren();

  CompositeComponentChild? getChildByNodeId(String nodeId) {
    return getChildren().firstWhereOrNull((c) => c.nodeId == nodeId);
  }

  CompositeComponentChild? getNextChildInDirection(String sinceChildId, DocumentNodeLookupDirection direction) {
    final children = getChildren();
    final index = children.indexWhere((c) => c.nodeId == sinceChildId);
    if (index == -1) {
      return null;
    }

    final backward = direction == DocumentNodeLookupDirection.up || direction == DocumentNodeLookupDirection.left;
    final nextIndex = backward ? index - 1 : index + 1;

    if (nextIndex >= 0 && nextIndex < children.length) {
      return children[nextIndex];
    } else {
      return null;
    }
  }

  CompositeComponentChild getFirstChildInDirection(DocumentNodeLookupDirection direction, {double? nearX}) {
    if (direction == DocumentNodeLookupDirection.up || direction == DocumentNodeLookupDirection.left) {
      return getChildren().last;
    } else {
      return getChildren().first;
    }
  }

  bool displayCaretWithExpandedSelection(CompositeNodePosition position) {
    return true;
  }

  DocumentComponent? getChildComponentById(String childId) {
    return getChildByNodeId(childId)!.component;
  }

  @override
  NodePosition getBeginningPosition() {
    final child = getChildren().first;
    return CompositeNodePosition(child.nodeId, child.component.getBeginningPosition());
  }

  @override
  NodePosition getBeginningPositionNearX(double x) {
    final child = getChildren().first;
    return CompositeNodePosition(child.nodeId, child.component.getBeginningPositionNearX(x));
  }

  @override
  NodePosition getEndPosition() {
    final child = getChildren().last;
    return CompositeNodePosition(child.nodeId, child.component.getEndPosition());
  }

  @override
  MouseCursor? getDesiredCursorAtOffset(Offset localOffset) {
    final child = getChildForOffset(localOffset);
    final childOffset = _projectOffsetToChildSpace(child, localOffset);
    return child.component.getDesiredCursorAtOffset(childOffset);
  }

  @override
  NodePosition? getPositionAtOffset(Offset localOffset) {
    // final superPosition = super.
    // TODO: Change all implementations of getPositionAtOffset to be exact, not nearest - but this first
    //       requires updating the gesture offset lookups.
    if (localOffset.dy < 0) {
      return getBeginningPosition();
    }

    final rect = _selfBox;
    if (localOffset.dy > rect.size.height) {
      return getEndPosition();
    }

    final child = getChildForOffset(localOffset);
    final childOffset = _projectOffsetToChildSpace(child, localOffset);

    return CompositeNodePosition(child.nodeId, child.component.getPositionAtOffset(childOffset)!);
  }

  CompositeComponentChild getChildForOffset(Offset componentOffset);

  @override
  NodePosition getEndPositionNearX(double x) {
    throw CompositePositionUsageException();
  }

  @override
  Rect getEdgeForPosition(NodePosition nodePosition) {
    throw CompositePositionUsageException();
  }

  @override
  Offset getOffsetForPosition(NodePosition nodePosition) {
    throw CompositePositionUsageException();
  }

  @override
  Rect getRectForPosition(NodePosition nodePosition) {
    throw CompositePositionUsageException();
  }

  @override
  Rect getRectForSelection(NodePosition baseNodePosition, NodePosition extentNodePosition) {
    throw CompositePositionUsageException();
  }

  @override
  NodeSelection getCollapsedSelectionAt(NodePosition nodePosition) {
    throw CompositePositionUsageException();
  }

  @override
  NodeSelection getSelectionBetween({required NodePosition basePosition, required NodePosition extentPosition}) {
    throw CompositePositionUsageException();
  }

  @override
  NodeSelection? getSelectionInRange(Offset localBaseOffset, Offset localExtentOffset) {
    throw CompositePositionUsageException();
  }

  @override
  NodeSelection getSelectionOfEverything() {
    throw CompositePositionUsageException();
  }

  @override
  NodePosition? movePositionUp(NodePosition currentPosition) {
    if (currentPosition is! CompositeNodePosition) {
      return null;
    }

    final child = getChildByNodeId(currentPosition.childNodeId)!;
    final upWithinChild = child.component.movePositionUp(currentPosition.childNodePosition);
    if (upWithinChild != null) {
      return currentPosition.moveWithinChild(upWithinChild);
    }
    final nextChild = getNextChildInDirection(currentPosition.childNodeId, DocumentNodeLookupDirection.up);
    if (nextChild == null) {
      return null;
    }
    return CompositeNodePosition(nextChild.nodeId, nextChild.component.getEndPosition());
  }

  @override
  NodePosition? movePositionDown(NodePosition currentPosition) {
    if (currentPosition is! CompositeNodePosition) {
      return null;
    }

    final child = getChildByNodeId(currentPosition.childNodeId)!;
    final downWithinChild = child.component.movePositionDown(currentPosition.childNodePosition);
    if (downWithinChild != null) {
      return currentPosition.moveWithinChild(downWithinChild);
    }
    final nextChild = getNextChildInDirection(currentPosition.childNodeId, DocumentNodeLookupDirection.down);
    if (nextChild == null) {
      return null;
    }
    // The next position down must be the beginning position of the next component.
    return CompositeNodePosition(nextChild.nodeId, nextChild.component.getBeginningPosition());
  }

  @override
  NodePosition? movePositionLeft(NodePosition currentPosition, [MovementModifier? movementModifier]) {
    if (currentPosition is! CompositeNodePosition) {
      return null;
    }

    final child = getChildByNodeId(currentPosition.childNodeId)!;
    final childPosition = child.component.movePositionLeft(currentPosition.childNodePosition, movementModifier);
    if (childPosition != null) {
      return currentPosition.moveWithinChild(childPosition);
    }
    final nextChild = getNextChildInDirection(currentPosition.childNodeId, DocumentNodeLookupDirection.left);
    if (nextChild == null) {
      return null;
    }
    return CompositeNodePosition(nextChild.nodeId, nextChild.component.getEndPosition());
  }

  @override
  NodePosition? movePositionRight(NodePosition currentPosition, [MovementModifier? movementModifier]) {
    if (currentPosition is! CompositeNodePosition) {
      return null;
    }

    final child = getChildByNodeId(currentPosition.childNodeId)!;
    final childPosition = child.component.movePositionRight(currentPosition.childNodePosition, movementModifier);
    if (childPosition != null) {
      return currentPosition.moveWithinChild(childPosition);
    }
    final nextChild = getNextChildInDirection(currentPosition.childNodeId, DocumentNodeLookupDirection.right);
    if (nextChild == null) {
      return null;
    }
    return CompositeNodePosition(nextChild.nodeId, nextChild.component.getBeginningPosition());
  }

  @override
  bool isVisualSelectionSupported() {
    return true;
  }

  Offset _projectOffsetToChildSpace(CompositeComponentChild child, Offset offset) {
    return child.renderBox.globalToLocal(offset, ancestor: _selfBox);
  }

  RenderBox get _selfBox => context.findRenderObject() as RenderBox;
}

/// This exception thrown when NodePosition-based method was called on CompositeNode.
/// That's unexpected behavior, as CompositeNodePosition should only be used once, to find a
/// leaf node at given Offset. After CompositeNodePosition received, it should be converted to leaf node position
/// immediately, so all subsequent NodePosition-based method must be called on leaf node component.
class CompositePositionUsageException implements Exception {
  late String? methodName;
  CompositePositionUsageException() {
    final match = RegExp(r'^\#\d+\s+([.\w\W]*?)\s+\(package').firstMatch(StackTrace.current.toString().split('\n')[1]);
    methodName = match?.group(1);
  }

  @override
  String toString() {
    if (methodName != null) {
      return 'Exception: Invalid call "$methodName" on CompositeNodes. Use leaf node positions';
    }
    return 'Exception: Invalid call on CompositeNodes. Use leaf node positions';
  }
}
