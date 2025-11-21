import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/default_editor/layout_single_column/composite_component.dart';
import 'package:super_editor/src/default_editor/layout_single_column/composite_nodes.dart';
import 'package:super_editor/src/infrastructure/flutter/geometry.dart';

/// A [DocumentComponent] that presents other components, within a column.
class ColumnDocumentComponent extends StatefulWidget {
  ColumnDocumentComponent({
    super.key,
    required this.children,
  }) {
    // As return type of methods like [getBeginningPositionNearX] is not nullable,
    // we cannot handle case of empty children inside a Component. It should be handled at
    // the component builder/parser level
    assert(children.isNotEmpty, 'Unable to create ColumnColumnComponent with empty children');
  }

  final List<CompositeComponentChild> children;

  @override
  State<ColumnDocumentComponent> createState() => _ColumnDocumentComponentState();
}

class _ColumnDocumentComponentState extends State<ColumnDocumentComponent>
    with CompositeComponent<ColumnDocumentComponent> {
  @override
  CompositeComponentChild? getChildByNodeId(String nodeId) {
    return widget.children.firstWhereOrNull((c) => c.nodeId == nodeId);
  }

  @override
  List<CompositeComponentChild> getChildren() => widget.children;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Column(
        children: widget.children.map((c) => c.widget).toList(),
      ),
    );
  }

  @override
  CompositeComponentChild getChildForOffset(Offset componentOffset) {
    if (componentOffset.dy < 0) {
      // Offset is above this component. Return the first item in the column.
      return widget.children.first;
    }

    final columnBox = context.findRenderObject() as RenderBox;
    final componentHeight = columnBox.size.height;
    if (componentOffset.dy > componentHeight) {
      // The offset is below this component. Return the last item in the column.
      return widget.children.last;
    }

    // The offset is vertically somewhere within this column. Return the child
    // whose y-bounds contain this offset's y-value.
    for (int i = 0; i < widget.children.length; i += 1) {
      final child = widget.children[i];
      final childBox = child.renderBox;
      final childBottomY = childBox.localToGlobal(Offset.zero, ancestor: columnBox).dy + childBox.size.height;
      if (childBottomY >= componentOffset.dy) {
        // Found the child that vertically contains the offset. Horizontal offset
        // doesn't matter because we're looking for "nearest".
        return child;
      }
    }

    throw Exception("Tried to find the child nearest to component offset ($componentOffset) but couldn't find one.");
  }

  @override
  bool isVisualSelectionSupported() {
    return true;
  }
}
