import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/default_editor/layout_single_column/composite_nodes.dart';
import 'package:super_editor/src/infrastructure/flutter/geometry.dart';

/// a [CompositeChildComponent] is an object that holds already built
/// component, with component key and nodeId.
/// All possible components
class CompositeChildComponent {
  final String nodeId;
  final GlobalKey<DocumentComponent> componentKey;
  final Widget widget;
  CompositeChildComponent({
    required this.nodeId,
    required this.componentKey,
    required this.widget,
  });

  DocumentComponent get component => componentKey.currentState!;
  RenderBox get renderBox => component.context.findRenderObject() as RenderBox;
}

/// A [DocumentComponent] that presents other components, within a column.
class ColumnDocumentComponent extends StatefulWidget {
  const ColumnDocumentComponent({
    super.key,
    required this.children,
  });

  final List<CompositeChildComponent> children;

  @override
  State<ColumnDocumentComponent> createState() => _ColumnDocumentComponentState();
}

class _ColumnDocumentComponentState extends State<ColumnDocumentComponent>
    with DocumentComponent<ColumnDocumentComponent>
    implements CompositeComponent {
  CompositeChildComponent? childByNodeId(String nodeId) {
    return widget.children.firstWhereOrNull((c) => c.nodeId == nodeId);
  }

  @override
  NodePosition getBeginningPosition() {
    final child = widget.children.first;
    return CompositeNodePosition(child.nodeId, child.component.getBeginningPosition());
  }

  @override
  NodePosition getBeginningPositionNearX(double x) {
    final child = widget.children.first;
    return CompositeNodePosition(child.nodeId, child.component.getBeginningPositionNearX(x));
  }

  @override
  NodePosition getEndPosition() {
    final child = widget.children.last;
    return CompositeNodePosition(child.nodeId, child.component.getEndPosition());
  }

  @override
  NodePosition getEndPositionNearX(double x) {
    final child = widget.children.last;
    return CompositeNodePosition(child.nodeId, child.component.getEndPositionNearX(x));
  }

  @override
  MouseCursor? getDesiredCursorAtOffset(Offset localOffset) {
    final childIndexNearestToOffset = _getIndexOfChildNearestTo(localOffset);
    final childOffset = _projectColumnOffsetToChildSpace(localOffset, childIndexNearestToOffset);

    return _getChildComponentAtIndex(childIndexNearestToOffset).getDesiredCursorAtOffset(childOffset);
  }

  @override
  NodePosition? getPositionAtOffset(Offset localOffset) {
    // TODO: Change all implementations of getPositionAtOffset to be exact, not nearest - but this first
    //       requires updating the gesture offset lookups.
    if (localOffset.dy < 0) {
      final child = widget.children.first;
      return CompositeNodePosition(child.nodeId, child.component.getBeginningPosition());
    }

    final columnBox = _columnBox;
    if (localOffset.dy > columnBox.size.height) {
      final child = widget.children.last;
      return CompositeNodePosition(child.nodeId, child.component.getEndPosition());
    }

    final childIndex = _getIndexOfChildNearestTo(localOffset);
    final childOffset = _projectColumnOffsetToChildSpace(localOffset, childIndex);
    final child = widget.children[childIndex];

    return CompositeNodePosition(child.nodeId, child.component.getPositionAtOffset(childOffset)!);
  }

  @override
  Rect getEdgeForPosition(NodePosition nodePosition) {
    if (nodePosition is! CompositeNodePosition) {
      throw Exception(
          "Tried get edge near position within a ColumnDocumentComponent with invalid type of node position: $nodePosition");
    }

    final rectInChild = _getChildComponentAtPosition(nodePosition).getEdgeForPosition(nodePosition.childNodePosition);
    final childIndex = _findChildIndexForPosition(nodePosition);

    final rectInColumn = Rect.fromPoints(
      _projectChildOffsetToColumnSpace(rectInChild.topLeft, childIndex),
      _projectChildOffsetToColumnSpace(rectInChild.bottomRight, childIndex),
    );

    return rectInColumn;
  }

  @override
  Offset getOffsetForPosition(NodePosition nodePosition) {
    if (nodePosition is! CompositeNodePosition) {
      throw Exception(
          "Tried get offset for position within a ColumnDocumentComponent with invalid type of node position: $nodePosition");
    }

    final childIndex = _findChildIndexForPosition(nodePosition);
    final child = widget.children[childIndex];
    return child.component.getOffsetForPosition(nodePosition.childNodePosition);
  }

  @override
  Rect getRectForPosition(NodePosition nodePosition) {
    if (nodePosition is! CompositeNodePosition) {
      throw Exception(
          "Tried get bounding rectangle for position within a ColumnDocumentComponent with invalid type of node position: $nodePosition");
    }

    final childIndex = _findChildIndexForPosition(nodePosition);
    final child = widget.children[childIndex];

    final rectInChild = child.component.getRectForPosition(nodePosition.childNodePosition);
    final childOffsetInColumn = child.renderBox.localToGlobal(Offset.zero, ancestor: _columnBox);

    final rectInColumn = rectInChild.translateByOffset(childOffsetInColumn);

    return rectInColumn;
  }

  @override
  Rect getRectForSelection(NodePosition baseNodePosition, NodePosition extentNodePosition) {
    if (baseNodePosition is! CompositeNodePosition || extentNodePosition is! CompositeNodePosition) {
      throw Exception(
          "Tried to select within a ColumnDocumentComponent with invalid position types - base: $baseNodePosition, extent: $extentNodePosition");
    }

    final baseIndex = widget.children.indexWhere((c) => c.nodeId == baseNodePosition.childNodeId);
    final extentIndex = widget.children.indexWhere((c) => c.nodeId == extentNodePosition.childNodeId);

    final componentBoundingBoxes = <Rect>[];

    // Collect bounding boxes for all selected components.
    final columnComponentBox = context.findRenderObject() as RenderBox;
    if (baseNodePosition.childNodeId == extentNodePosition.childNodeId) {
      // Selection within a single node.
      final selectedChild = childByNodeId(baseNodePosition.childNodeId)!;
      final childOffset = _getChildOffset(selectedChild);

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
        final child = widget.children[i];

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

    final childIndex = _findChildIndexForPosition(currentPosition);
    final child = _getChildComponentAtIndex(childIndex);
    final upWithinChild = child.movePositionUp(currentPosition.childNodePosition);
    if (upWithinChild != null) {
      return currentPosition.moveWithinChild(upWithinChild);
    }

    if (childIndex == 0) {
      // Nothing above this child.
      return null;
    }

    final previousChild = widget.children[childIndex - 1];
    // The next position up must be the ending position of the previous component.
    return CompositeNodePosition(previousChild.nodeId, previousChild.component.getEndPosition());
  }

  @override
  NodePosition? movePositionDown(NodePosition currentPosition) {
    if (currentPosition is! CompositeNodePosition) {
      return null;
    }

    final childIndex = _findChildIndexForPosition(currentPosition);
    final child = _getChildComponentAtIndex(childIndex);
    final downWithinChild = child.movePositionDown(currentPosition.childNodePosition);
    if (downWithinChild != null) {
      return currentPosition.moveWithinChild(downWithinChild);
    }

    if (childIndex == widget.children.length - 1) {
      // Nothing below this child.
      return null;
    }
    final nextChild = widget.children[childIndex + 1];
    // The next position down must be the beginning position of the next component.
    return CompositeNodePosition(nextChild.nodeId, nextChild.component.getBeginningPosition());
  }

  @override
  NodePosition? movePositionLeft(NodePosition currentPosition, [MovementModifier? movementModifier]) {
    if (currentPosition is! CompositeNodePosition) {
      return null;
    }

    final childIndex = _findChildIndexForPosition(currentPosition);
    final child = _getChildComponentAtIndex(childIndex);
    final leftWithinChild = child.movePositionLeft(currentPosition.childNodePosition, movementModifier);
    if (leftWithinChild != null) {
      return currentPosition.moveWithinChild(leftWithinChild);
    }

    if (childIndex == 0) {
      // Nothing above this child.
      return null;
    }

    final previousChild = widget.children[childIndex - 1];
    // The next position left must be the ending position of the previous component.
    // TODO: This assumes left-to-right content ordering, which isn't true for some
    //       languages. Revisit this when/if we need RTL support for this behavior.
    return CompositeNodePosition(previousChild.nodeId, previousChild.component.getEndPosition());
  }

  @override
  NodePosition? movePositionRight(NodePosition currentPosition, [MovementModifier? movementModifier]) {
    if (currentPosition is! CompositeNodePosition) {
      return null;
    }

    final childIndex = _findChildIndexForPosition(currentPosition);
    final child = _getChildComponentAtIndex(childIndex);
    final rightWithinChild = child.movePositionRight(currentPosition.childNodePosition, movementModifier);
    if (rightWithinChild != null) {
      return currentPosition.moveWithinChild(rightWithinChild);
    }

    if (childIndex == widget.children.length - 1) {
      // Nothing below this child.
      return null;
    }

    final nextChild = widget.children[childIndex - 1];
    // The next position right must be the beginning position of the next component.
    // TODO: This assumes left-to-right content ordering, which isn't true for some
    //       languages. Revisit this when/if we need RTL support for this behavior.
    return CompositeNodePosition(nextChild.nodeId, nextChild.component.getBeginningPosition());
  }

  DocumentComponent _getChildComponentAtPosition(CompositeNodePosition columnPosition) {
    return childByNodeId(columnPosition.childNodeId)!.component;
  }

  DocumentComponent _getChildComponentAtIndex(int childIndex) {
    return widget.children[childIndex].component;
  }

  int _findChildIndexForPosition(CompositeNodePosition position) {
    for (int i = 0; i < widget.children.length; i += 1) {
      final child = widget.children[i];
      if (child.nodeId == position.childNodeId) {
        return i;
      }
    }

    return -1;
  }

  int _getIndexOfChildNearestTo(Offset componentOffset) {
    if (componentOffset.dy < 0) {
      // Offset is above this component. Return the first item in the column.
      return 0;
    }

    final columnBox = context.findRenderObject() as RenderBox;
    final componentHeight = columnBox.size.height;
    if (componentOffset.dy > componentHeight) {
      // The offset is below this component. Return the last item in the column.
      return widget.children.length - 1;
    }

    // The offset is vertically somewhere within this column. Return the child
    // whose y-bounds contain this offset's y-value.
    for (int i = 0; i < widget.children.length; i += 1) {
      final childBox = widget.children[i].renderBox;
      final childBottomY = childBox.localToGlobal(Offset.zero, ancestor: columnBox).dy + childBox.size.height;
      if (childBottomY >= componentOffset.dy) {
        // Found the child that vertically contains the offset. Horizontal offset
        // doesn't matter because we're looking for "nearest".
        return i;
      }
    }

    throw Exception("Tried to find the child nearest to component offset ($componentOffset) but couldn't find one.");
  }

  /// Given an offset that's relative to this column, finds where that same point sits
  /// within the given child, and returns that offset local to the child coordinate system.
  Offset _projectColumnOffsetToChildSpace(Offset columnOffset, int childIndex) {
    return widget.children[childIndex].renderBox.globalToLocal(columnOffset, ancestor: _columnBox);
  }

  /// Given an offset that's relative to a child in this column, finds and returns where that
  /// same point sits relative to the column origin.
  Offset _projectChildOffsetToColumnSpace(Offset childOffset, int childIndex) {
    final childComponent = _getChildComponentAtIndex(childIndex);
    final childRenderBox = childComponent.context.findRenderObject() as RenderBox;
    final childOffsetInColumn = childRenderBox.localToGlobal(childOffset, ancestor: _columnBox);

    return childOffsetInColumn;
  }

  RenderBox get _columnBox => context.findRenderObject() as RenderBox;

  Offset _getChildOffset(CompositeChildComponent child) {
    return child.renderBox.localToGlobal(Offset.zero, ancestor: _columnBox);
  }

  @override
  Widget build(BuildContext context) {
    // print("Composite component children: ${widget.children}");
    // print("Child component keys: ${widget.childComponentKeys}");

    return IgnorePointer(
      child: Column(
        children: widget.children.map((c) => c.widget).toList(),
      ),
    );
  }

  @override
  DocumentComponent<StatefulWidget>? getLeafComponentByNodePosition(NodePosition position) {
    if (position is CompositeNodePosition) {
      final child = childByNodeId(position.childNodeId)!;
      if (child.component is CompositeComponent) {
        return (child.component as CompositeComponent).getLeafComponentByNodePosition(position.childNodePosition);
      }
      assert(position.childNodePosition is! CompositeNodePosition);
      return child.component;
    }
    return this;
  }
}
