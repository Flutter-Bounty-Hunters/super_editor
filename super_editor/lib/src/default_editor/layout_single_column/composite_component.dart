import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/default_editor/layout_single_column/composite_nodes.dart';
import 'package:super_editor/src/infrastructure/flutter/geometry.dart';

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

  CompositeComponentChild? getChildAboveChild(String nodeId) {
    final children = getChildren();
    final index = children.indexWhere((c) => c.nodeId == nodeId);
    if (index > 0) {
      return children[index - 1];
    }
    return null;
  }

  CompositeComponentChild? getChildBelowChild(String nodeId) {
    final children = getChildren();
    final index = children.indexWhere((c) => c.nodeId == nodeId);
    if (index == -1 || index == children.length - 1) {
      // Nothing below this child.
      return null;
    }
    return children[index + 1];
  }

  CompositeComponentChild? getChildLeftToChild(String nodeId) {
    // The next position left must be the ending position of the previous component.
    // TODO: This assumes left-to-right content ordering, which isn't true for some
    //       languages. Revisit this when/if we need RTL support for this behavior.
    return getChildAboveChild(nodeId);
  }

  CompositeComponentChild? getChildRightToChild(String nodeId) {
    // The next position right must be the beginning position of the next component.
    // TODO: This assumes left-to-right content ordering, which isn't true for some
    //       languages. Revisit this when/if we need RTL support for this behavior.
    return getChildRightToChild(nodeId);
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

  @override
  NodePosition getEndPositionNearX(double x) {
    final child = getChildren().last;
    return CompositeNodePosition(child.nodeId, child.component.getEndPositionNearX(x));
  }

  @override
  Rect getEdgeForPosition(NodePosition nodePosition) {
    if (nodePosition is! CompositeNodePosition) {
      throw Exception(
          "Tried get edge near position within a ColumnDocumentComponent with invalid type of node position: $nodePosition");
    }

    final child = getChildByNodeId(nodePosition.childNodeId)!;
    final rectInChild = child.component.getEdgeForPosition(nodePosition.childNodePosition);

    final rectInColumn = Rect.fromPoints(
      _projectOffsetToChildSpace(child, rectInChild.topLeft),
      _projectOffsetToChildSpace(child, rectInChild.bottomRight),
    );

    return rectInColumn;
  }

  @override
  Offset getOffsetForPosition(NodePosition nodePosition) {
    if (nodePosition is! CompositeNodePosition) {
      throw Exception(
          "Tried get offset for position within a ColumnDocumentComponent with invalid type of node position: $nodePosition");
    }
    final child = getChildByNodeId(nodePosition.childNodeId)!;
    return child.component.getOffsetForPosition(nodePosition.childNodePosition);
  }

  @override
  Rect getRectForPosition(NodePosition nodePosition) {
    if (nodePosition is! CompositeNodePosition) {
      throw Exception(
          "Tried get bounding rectangle for position within a ColumnDocumentComponent with invalid type of node position: $nodePosition");
    }

    final child = getChildByNodeId(nodePosition.childNodeId)!;

    final rectInChild = child.component.getRectForPosition(nodePosition.childNodePosition);
    final childOffsetInColumn = child.renderBox.localToGlobal(Offset.zero, ancestor: _selfBox);

    final rectInColumn = rectInChild.translateByOffset(childOffsetInColumn);

    return rectInColumn;
  }

  // TODO: Review if this method (and other that relies on CompositePosition/CompositeSelection) needed at all
  @override
  Rect getRectForSelection(NodePosition baseNodePosition, NodePosition extentNodePosition) {
    if (baseNodePosition is! CompositeNodePosition || extentNodePosition is! CompositeNodePosition) {
      throw Exception(
          "Tried to select within a ColumnDocumentComponent with invalid position types - base: $baseNodePosition, extent: $extentNodePosition");
    }
    print('getRectForSelection called!');

    final children = getChildren();
    final baseIndex = children.indexWhere((c) => c.nodeId == baseNodePosition.childNodeId);
    final extentIndex = children.indexWhere((c) => c.nodeId == extentNodePosition.childNodeId);
    assert(baseIndex != -1, 'Unable to find base child node with id "${baseNodePosition.childNodeId}"');
    assert(extentIndex != -1, 'Unable to find extent child node with id "${extentNodePosition.childNodeId}"');

    final componentBoundingBoxes = <Rect>[];

    // Collect bounding boxes for all selected components.
    final columnComponentBox = context.findRenderObject() as RenderBox;
    if (baseNodePosition.childNodeId == extentNodePosition.childNodeId) {
      // Selection within a single node.
      final selectedChild = getChildByNodeId(baseNodePosition.childNodeId)!;
      final childOffset = selectedChild.renderBox.localToGlobal(Offset.zero, ancestor: _selfBox);

      final componentBoundingBox = selectedChild.component
          .getRectForSelection(
            baseNodePosition.childNodePosition,
            extentNodePosition.childNodePosition,
          )
          .translateByOffset(childOffset);

      componentBoundingBoxes.add(componentBoundingBox);
    } else {
      // Selection across nodes.
      final topNodeIndex = min(baseIndex, extentIndex);
      final topColumnPosition = baseIndex < extentIndex ? baseNodePosition : extentNodePosition;

      final bottomNodeIndex = max(baseIndex, extentIndex);
      final bottomColumnPosition = baseIndex < extentIndex ? extentNodePosition : baseNodePosition;

      for (int i = topNodeIndex; i <= bottomNodeIndex; ++i) {
        final child = children[i];

        // final component = widget.childComponentKeys[i].currentState!;
        final childOffset = child.renderBox.localToGlobal(Offset.zero, ancestor: columnComponentBox);

        if (i == topNodeIndex) {
          // This is the first node. The selection goes from
          // startPosition to the end of the node.
          final firstNodeEndPosition = child.component.getEndPosition();
          final componentRectInColumnLayout = child.component
              .getRectForSelection(
                topColumnPosition.childNodePosition,
                firstNodeEndPosition,
              )
              .translateByOffset(childOffset);

          componentBoundingBoxes.add(componentRectInColumnLayout);
        } else if (i == bottomNodeIndex) {
          // This is the last node. The selection goes from
          // the beginning of the node to endPosition.
          final lastNodeStartPosition = child.component.getBeginningPosition();
          final componentRectInColumnLayout = child.component
              .getRectForSelection(
                lastNodeStartPosition,
                bottomColumnPosition.childNodePosition,
              )
              .translateByOffset(childOffset);

          componentBoundingBoxes.add(componentRectInColumnLayout);
        } else {
          // This node sits between start and end. All content
          // is selected.
          final componentRectInColumnLayout = child.component
              .getRectForSelection(
                child.component.getBeginningPosition(),
                child.component.getEndPosition(),
              )
              .translateByOffset(childOffset);

          componentBoundingBoxes.add(componentRectInColumnLayout);
        }
      }
    }

    // Combine all component boxes into one big bounding box.
    Rect boundingBox = componentBoundingBoxes.first;
    for (int i = 1; i < componentBoundingBoxes.length; ++i) {
      boundingBox = boundingBox.expandToInclude(componentBoundingBoxes[i]);
    }

    return boundingBox;
  }

  @override
  NodeSelection getCollapsedSelectionAt(NodePosition nodePosition) {
    if (nodePosition is! CompositeNodePosition) {
      throw Exception(
          "Tried get position within a ColumnDocumentComponent with invalid type of node position: $nodePosition");
    }

    // TODO: implement getCollapsedSelectionAt
    throw UnimplementedError();
  }

  @override
  NodeSelection getSelectionBetween({required NodePosition basePosition, required NodePosition extentPosition}) {
    if (basePosition is! CompositeNodePosition || extentPosition is! CompositeNodePosition) {
      throw Exception(
          "Tried to select within a ColumnDocumentComponent with invalid position types - base: $basePosition, extent: $extentPosition");
    }

    // TODO: implement getSelectionBetween
    throw UnimplementedError();
  }

  @override
  NodeSelection? getSelectionInRange(Offset localBaseOffset, Offset localExtentOffset) {
    // TODO: implement getSelectionInRange
    throw UnimplementedError();
  }

  @override
  NodeSelection getSelectionOfEverything() {
    // TODO: implement getSelectionOfEverything
    throw UnimplementedError();
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

    final previousChild = getChildAboveChild(currentPosition.childNodeId);
    if (previousChild == null) {
      return null;
    }
    // The next position up must be the ending position of the previous component.
    return CompositeNodePosition(previousChild.nodeId, previousChild.component.getEndPosition());
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

    final nextChild = getChildBelowChild(currentPosition.childNodeId);
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
    final leftWithinChild = child.component.movePositionLeft(currentPosition.childNodePosition, movementModifier);
    if (leftWithinChild != null) {
      return currentPosition.moveWithinChild(leftWithinChild);
    }

    final previousChild = getChildLeftToChild(currentPosition.childNodeId);
    if (previousChild == null) {
      return null;
    }

    return CompositeNodePosition(previousChild.nodeId, previousChild.component.getEndPosition());
  }

  @override
  NodePosition? movePositionRight(NodePosition currentPosition, [MovementModifier? movementModifier]) {
    if (currentPosition is! CompositeNodePosition) {
      return null;
    }

    final child = getChildByNodeId(currentPosition.childNodeId)!;
    final rightWithinChild = child.component.movePositionRight(currentPosition.childNodePosition, movementModifier);
    if (rightWithinChild != null) {
      return currentPosition.moveWithinChild(rightWithinChild);
    }

    final nextChild = getChildRightToChild(currentPosition.childNodeId);
    if (nextChild == null) {
      return null;
    }

    return CompositeNodePosition(nextChild.nodeId, nextChild.component.getBeginningPosition());
  }

  @override
  bool isVisualSelectionSupported() {
    return true;
  }

  // FIXME: Delete default implementation - let other classes implement it efficiently
  CompositeComponentChild getChildForOffset(Offset componentOffset) {
    if (componentOffset.dy < 0) {
      // Offset is above this component. Return the first item
      return getChildren().first;
    }

    final rect = context.findRenderObject() as RenderBox;

    final componentHeight = rect.size.height;
    if (componentOffset.dy > componentHeight) {
      // The offset is below this component. Return the last item in the column.
      return getChildren().last;
    }

    CompositeComponentChild? closestChild;
    double? minDistance;
    for (final child in getChildren()) {
      final childBox = child.renderBox;
      final childOrigin = childBox.localToGlobal(Offset.zero, ancestor: rect);
      final childRect = Rect.fromLTWH(childOrigin.dx, childOrigin.dy, childBox.size.width, childBox.size.height);

      final distance = _distance(childRect, componentOffset);

      if (distance == 0) {
        return child;
      }
      if (minDistance == null || distance < minDistance) {
        minDistance = distance;
        closestChild = child;
      }
    }

    return closestChild!;
  }

  Offset _projectOffsetToChildSpace(CompositeComponentChild child, Offset offset) {
    return child.renderBox.globalToLocal(offset, ancestor: _selfBox);
  }

  RenderBox get _selfBox => context.findRenderObject() as RenderBox;
}

/// Returns the shortest distance from [point] to the nearest edge of [rect].
///
/// If the [point] is inside or on the boundary of the [rect], returns 0.0.
double _distance(Rect rect, Offset point) {
  // inside or on an edge
  if (point.dx >= rect.left && point.dx <= rect.right && point.dy >= rect.top && point.dy <= rect.bottom) {
    return 0.0;
  }

  double nearestX, nearestY;
  if (point.dx < rect.left) {
    nearestX = rect.left;
  } else if (point.dx > rect.right) {
    nearestX = rect.right;
  } else {
    nearestX = point.dx;
  }
  if (point.dy < rect.top) {
    nearestY = rect.top;
  } else if (point.dy > rect.bottom) {
    nearestY = rect.bottom;
  } else {
    nearestY = point.dy;
  }

  return sqrt(pow(point.dx - nearestX, 2) + pow(point.dy - nearestY, 2));
}
