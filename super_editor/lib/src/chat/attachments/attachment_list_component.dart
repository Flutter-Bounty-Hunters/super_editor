import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Placeholder;
import 'package:super_editor/super_editor.dart';

class AttachmentListComponentBuilder implements ComponentBuilder {
  const AttachmentListComponentBuilder(this.builder);

  final AttachmentThumbnailBuilder builder;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(
    Document document,
    DocumentNode node,
  ) {
    print("MAYBE BUILD FOR? ${node.runtimeType}");
    if (node is! AttachmentListNode) {
      print(" - NOPE");
      return null;
    }

    print(" - YEP");
    final vm = AttachmentListViewModel(
      nodeId: node.id,
      createdAt: node.metadata[NodeMetadata.createdAt],
      attachments: node.attachments as List<Object>,
      selectionColor: const Color(0x00000000),
    );
    print("   - CREATED: ${vm.runtimeType}");

    return vm;
  }

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    print("MAYBE COMPONENT FOR: ${componentViewModel.runtimeType}");
    if (componentViewModel is! AttachmentListViewModel) {
      print(" - NOPE");
      return null;
    }

    print("BUILDING ATTACHMENT COMPONENT");
    return AttachmentListComponent(
      key: componentContext.componentKey,
      attachments: componentViewModel.attachments,
      selection: componentViewModel.selection?.nodeSelection as AttachmentListNodeSelection?,
      selectionColor: componentViewModel.selectionColor,
      builder: builder,
    );
  }
}

class AttachmentListViewModel extends SingleColumnLayoutComponentViewModel with SelectionAwareViewModelMixin {
  AttachmentListViewModel({
    required super.nodeId,
    required super.createdAt,
    required this.attachments,
    required Color selectionColor,
    super.maxWidth,
    super.padding = EdgeInsets.zero,
    DocumentNodeSelection<NodeSelection>? selection,
  }) {
    super.selection = selection;
    super.selectionColor = selectionColor;
  }

  List<Object> attachments;

  @override
  AttachmentListViewModel copy() {
    return AttachmentListViewModel(
      nodeId: nodeId,
      createdAt: createdAt,
      maxWidth: maxWidth,
      padding: padding,
      attachments: attachments,
      selection: selection,
      selectionColor: selectionColor,
    );
  }

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is AttachmentListViewModel &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          attachments == other.attachments &&
          selection == other.selection &&
          selectionColor == other.selectionColor;

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  int get hashCode =>
      super.hashCode ^ nodeId.hashCode ^ attachments.hashCode ^ selection.hashCode ^ selectionColor.hashCode;
}

class AttachmentListComponent extends StatefulWidget {
  const AttachmentListComponent({
    super.key,
    required this.attachments,
    this.selectionColor = Colors.blue,
    this.selection,
    required this.builder,
  });

  final List<Object> attachments;
  final Color selectionColor;
  final AttachmentListNodeSelection? selection;

  final AttachmentThumbnailBuilder builder;

  @override
  State<AttachmentListComponent> createState() => _AttachmentListComponentState();
}

typedef AttachmentThumbnailBuilder = Widget Function(
  BuildContext context,
  Object attachment,
);

class _AttachmentListComponentState extends State<AttachmentListComponent> with DocumentComponent {
  final _rowWrapKey = GlobalKey(debugLabel: 'attachment-list_row-wrap');
  final _attachmentWidgetKeys = <GlobalKey>[];

  @override
  NodePosition getBeginningPosition() => AttachmentListNodePosition.start;

  @override
  NodePosition getBeginningPositionNearX(double x) {
    if (_attachmentWidgetKeys.isEmpty) {
      return AttachmentListNodePosition.start;
    }

    // We want to return the position in the first row of the list, nearest
    // to the given `x`.
    //
    // We don't know where the row is split, but if we start iterating from
    // the start of the list and find the nearest attachment, then that
    // attachment should naturally be in the first row.
    int nearestIndex = 0;
    double nearestDistance = (_findAttachmentUpstreamX(0) - x).abs();

    for (int i = 1; i < _attachmentWidgetKeys.length; i += 1) {
      final newDistance = (_findAttachmentUpstreamX(i) - x).abs();

      if (newDistance < nearestDistance) {
        // We found a closer attachment to the desired `x`. Record it.
        nearestIndex = i;
        nearestDistance = newDistance;
      } else {
        // We're getting further away from the desired `x`, so we've already
        // found the closest attachment. Break the loop, then return it.
        break;
      }
    }

    return AttachmentListNodePosition(nearestIndex, TextAffinity.upstream);
  }

  @override
  NodePosition getEndPosition() =>
      AttachmentListNodePosition(_attachmentWidgetKeys.length - 1, TextAffinity.downstream);

  @override
  NodePosition getEndPositionNearX(double x) {
    if (_attachmentWidgetKeys.isEmpty) {
      return AttachmentListNodePosition.start;
    }

    // We want to return the position in the last row of the list, nearest
    // to the given `x`.
    //
    // We don't know where the row is split, but if we start iterating from
    // the end of the list and find the nearest attachment, then that
    // attachment should naturally be in the last row.
    int nearestIndex = _attachmentWidgetKeys.length - 1;
    double nearestDistance = (_findAttachmentDownstreamX(0) - x).abs();

    for (int i = _attachmentWidgetKeys.length - 1; i >= 0; i -= 1) {
      final newDistance = (_findAttachmentDownstreamX(i) - x).abs();

      if (newDistance < nearestDistance) {
        // We found a closer attachment to the desired `x`. Record it.
        nearestIndex = i;
        nearestDistance = newDistance;
      } else {
        // We're getting further away from the desired `x`, so we've already
        // found the closest attachment. Break the loop, then return it.
        break;
      }
    }

    return AttachmentListNodePosition(nearestIndex, TextAffinity.upstream);
  }

  @override
  NodeSelection getCollapsedSelectionAt(NodePosition nodePosition) {
    if (nodePosition is! AttachmentListNodePosition) {
      throw Exception(
        "Expected an AttachmentListNodePosition but got: ${nodePosition.runtimeType}",
      );
    }

    return AttachmentListNodeSelection.collapsed(nodePosition);
  }

  @override
  MouseCursor? getDesiredCursorAtOffset(Offset localOffset) {
    return null;
  }

  @override
  Rect getEdgeForPosition(NodePosition nodePosition) {
    if (nodePosition is! AttachmentListNodePosition) {
      throw ArgumentError(
        'Invalid node position type. Expected _AttachmentListNodePosition '
        'but got ${nodePosition.runtimeType}',
      );
    }

    if (nodePosition.attachmentIndex >= _attachmentWidgetKeys.length) {
      if (kDebugMode) {
        throw AssertionError(
          'Was asked to get edge for attachment at index '
          '${nodePosition.attachmentIndex} but we only have '
          '${_attachmentWidgetKeys.length} attachments in this list.',
        );
      }

      return Rect.zero;
    }

    return nodePosition.isUpstream
        ? _rowWrap.getEdgeBefore(nodePosition.attachmentIndex)
        : _rowWrap.getEdgeAfter(nodePosition.attachmentIndex);
  }

  @override
  Offset getOffsetForPosition(NodePosition nodePosition) {
    if (nodePosition is! AttachmentListNodePosition) {
      throw ArgumentError(
          'Invalid node position type. Expected _AttachmentListNodePosition but got ${nodePosition.runtimeType}');
    }

    if (nodePosition.attachmentIndex >= _attachmentWidgetKeys.length) {
      return Offset.zero;
    }

    final attachmentBox = _findLocalRectForAttachment(nodePosition.attachmentIndex);
    return switch (nodePosition.affinity) {
      TextAffinity.upstream => Offset((attachmentBox.center.dx + attachmentBox.left) / 2, attachmentBox.center.dy),
      TextAffinity.downstream => Offset((attachmentBox.right + attachmentBox.center.dx) / 2, attachmentBox.center.dy),
    };
  }

  @override
  AttachmentListNodePosition? getPositionAtOffset(Offset localOffset) {
    print("getPositionAtOffset()");
    if (_doesAttachmentContainOffset(0, localOffset)) {
      // The first attachment contains the offset. Return it.
      print(
          " - first attachment has it. Affinity for offset: ${_chooseHorizontalAffinityForAttachment(0, localOffset.dx)}");
      return AttachmentListNodePosition(
        0,
        _chooseHorizontalAffinityForAttachment(0, localOffset.dx),
      );
    }

    // The first attachment doesn't contain the offset. Start looking for
    // the nearest attachment widget.
    int nearestIndex = 0;
    double nearestDistance = (_findAttachmentCenter(0) - localOffset).distance;

    for (int i = 1; i < _attachmentWidgetKeys.length; i += 1) {
      if (_doesAttachmentContainOffset(i, localOffset)) {
        // This attachment contains the offset. Return it.
        return AttachmentListNodePosition(
          i,
          _chooseHorizontalAffinityForAttachment(i, localOffset.dx),
        );
      }

      final newDistance = (_findAttachmentCenter(i) - localOffset).distance;

      if (newDistance < nearestDistance) {
        // We found a closer attachment to the desired `x`. Record it.
        nearestIndex = i;
        nearestDistance = newDistance;
      }
    }

    return AttachmentListNodePosition(
      nearestIndex,
      _chooseHorizontalAffinityForAttachment(nearestIndex, localOffset.dx),
    );
  }

  @override
  Rect getRectForPosition(NodePosition nodePosition) {
    if (nodePosition is! AttachmentListNodePosition) {
      throw ArgumentError(
          'Invalid node position type. Expected _AttachmentListNodePosition but got ${nodePosition.runtimeType}');
    }

    return _findLocalRectForAttachment(nodePosition.attachmentIndex);
  }

  @override
  Rect getRectForSelection(
    NodePosition baseNodePosition,
    NodePosition extentNodePosition,
  ) {
    if (baseNodePosition is! AttachmentListNodePosition) {
      throw ArgumentError(
          'Invalid base node position type. Expected _AttachmentListNodePosition but got ${baseNodePosition.runtimeType}');
    }
    if (extentNodePosition is! AttachmentListNodePosition) {
      throw ArgumentError(
          'Invalid extent node position type. Expected _AttachmentListNodePosition but got ${extentNodePosition.runtimeType}');
    }

    final start = min(baseNodePosition.attachmentIndex, extentNodePosition.attachmentIndex);
    final end = max(baseNodePosition.attachmentIndex, extentNodePosition.attachmentIndex);
    var boundingRect = _findLocalRectForAttachment(start);
    for (int i = start + 1; i <= end; i += 1) {
      final additionalRect = _findLocalRectForAttachment(i);
      boundingRect = boundingRect.expandToInclude(additionalRect);
    }

    return boundingRect;
  }

  @override
  NodeSelection getSelectionBetween({
    required NodePosition basePosition,
    required NodePosition extentPosition,
  }) {
    if (basePosition is! AttachmentListNodePosition) {
      throw ArgumentError(
          'Invalid base node position type. Expected _AttachmentListNodePosition but got ${basePosition.runtimeType}');
    }
    if (extentPosition is! AttachmentListNodePosition) {
      throw ArgumentError(
          'Invalid extent node position type. Expected _AttachmentListNodePosition but got ${extentPosition.runtimeType}');
    }

    return AttachmentListNodeSelection(
      base: AttachmentListNodePosition.start,
      extent: AttachmentListNodePosition(
        _attachmentWidgetKeys.length - 1,
        TextAffinity.downstream,
      ),
    );
  }

  @override
  NodeSelection? getSelectionInRange(
    Offset localBaseOffset,
    Offset localExtentOffset,
  ) {
    if (_attachmentWidgetKeys.isEmpty) {
      return null;
    }

    final basePosition = getPositionAtOffset(localBaseOffset);
    final extentPosition = getPositionAtOffset(localExtentOffset);
    if (basePosition == null || extentPosition == null) {
      // We don't expect this to happen, since we have 1+ attachments,
      // but we're missing one or both positions, so return `null`.
      return null;
    }

    return AttachmentListNodeSelection(
      base: basePosition,
      extent: extentPosition,
    );
  }

  @override
  NodeSelection getSelectionOfEverything() {
    return AttachmentListNodeSelection(
      base: AttachmentListNodePosition.start,
      extent: AttachmentListNodePosition(
        _attachmentWidgetKeys.length - 1,
        TextAffinity.downstream,
      ),
    );
  }

  @override
  NodePosition? movePositionLeft(NodePosition currentPosition, [MovementModifier? movementModifier]) {
    if (currentPosition is! AttachmentListNodePosition) {
      throw ArgumentError(
          'Invalid node position type. Expected _AttachmentListNodePosition but got ${currentPosition.runtimeType}');
    }

    if (currentPosition.attachmentIndex == 0) {
      if (currentPosition.affinity == TextAffinity.upstream) {
        // Nothing to the left.
        return null;
      } else {
        // There are no attachments to the left, but we can move the selection
        // from the right side of the attachment to the left side of it.
        return AttachmentListNodePosition.start;
      }
    }

    final currentRow = _rowWrap.getRowIndexForChildAt(
      currentPosition.attachmentIndex,
    );
    final nextRow = _rowWrap.getRowIndexForChildAt(
      currentPosition.attachmentIndex - 1,
    );
    if (currentRow == nextRow) {
      // Move left in the same row.
      return AttachmentListNodePosition(
        currentPosition.attachmentIndex - 1,
        currentPosition.affinity,
      );
    } else if (currentPosition.isDownstream) {
      // We're on the downstream edge of the first attachment in this row.
      // Flip to the upstream side, rather than jump up a row.
      return AttachmentListNodePosition(
        currentPosition.attachmentIndex,
        TextAffinity.upstream,
      );
    } else {
      // We're moving up a row, which means we want to retain the
      // same logical position, but we want to switch from the
      // left side of the current attachment to the right side of
      // the next attachment.
      return AttachmentListNodePosition(
        currentPosition.attachmentIndex - 1,
        TextAffinity.downstream,
      );
    }
  }

  @override
  NodePosition? movePositionRight(NodePosition currentPosition, [MovementModifier? movementModifier]) {
    if (currentPosition is! AttachmentListNodePosition) {
      throw ArgumentError(
          'Invalid node position type. Expected _AttachmentListNodePosition but got ${currentPosition.runtimeType}');
    }

    if (currentPosition.attachmentIndex >= _attachmentWidgetKeys.length - 1) {
      if (currentPosition.affinity == TextAffinity.downstream) {
        // Nothing to the right.
        return null;
      } else {
        // There are no attachments to the right, but we can move the selection
        // from the left side of the attachment to the right side of it.
        return AttachmentListNodePosition(
          _attachmentWidgetKeys.length - 1,
          TextAffinity.downstream,
        );
      }
    }

    final currentRow = _rowWrap.getRowIndexForChildAt(
      currentPosition.attachmentIndex,
    );
    final nextRow = _rowWrap.getRowIndexForChildAt(
      currentPosition.attachmentIndex + 1,
    );
    if (currentRow == nextRow) {
      // Move right in the same row.
      return AttachmentListNodePosition(
        currentPosition.attachmentIndex + 1,
        currentPosition.affinity,
      );
    } else if (currentPosition.isUpstream) {
      // We're on the upstream side of the last attachment in the row.
      // Flip to the downstream side.
      return AttachmentListNodePosition(
        currentPosition.attachmentIndex,
        TextAffinity.downstream,
      );
    } else {
      // We're moving down a row, which means we want to retain the
      // same logical position, but we want to switch from the
      // right side of the current attachment to the left side of
      // the next attachment.
      return AttachmentListNodePosition(
        currentPosition.attachmentIndex + 1,
        TextAffinity.upstream,
      );
    }
  }

  @override
  NodePosition? movePositionUp(NodePosition currentPosition) {
    if (currentPosition is! AttachmentListNodePosition) {
      throw ArgumentError(
          'Invalid node position type. Expected _AttachmentListNodePosition but got ${currentPosition.runtimeType}');
    }

    // final attachmentIndex = currentPosition.isUpstream
    //     ? currentPosition.attachmentIndex
    //     : currentPosition.attachmentIndex - 1;
    // final row = _rowWrap.getRowIndexForChildAt(attachmentIndex);

    final row = _rowWrap.getRowIndexForChildAt(currentPosition.attachmentIndex);
    if (row == 0) {
      // This position is in the first row. There's no content above it.
      return null;
    }

    final centerOfSelectedAttachment = _findAttachmentCenter(
      currentPosition.attachmentIndex,
    );
    final attachmentInRowAbove = _findNearestAttachmentInRow(
      row - 1,
      centerOfSelectedAttachment.dx,
    );

    return AttachmentListNodePosition(
      attachmentInRowAbove,
      currentPosition.affinity,
    );
  }

  @override
  NodePosition? movePositionDown(NodePosition currentPosition) {
    if (currentPosition is! AttachmentListNodePosition) {
      throw ArgumentError(
          'Invalid node position type. Expected _AttachmentListNodePosition but got ${currentPosition.runtimeType}');
    }

    final attachmentIndex =
        currentPosition.isUpstream ? currentPosition.attachmentIndex : currentPosition.attachmentIndex - 1;
    final row = _rowWrap.getRowIndexForChildAt(attachmentIndex);
    if (row == _rowWrap.wrapRowCount - 1) {
      // This position is in the last row. There's no content below it.
      return null;
    }

    final centerOfSelectedAttachment = _findAttachmentCenter(attachmentIndex);
    final attachmentInRowAbove = _findNearestAttachmentInRow(
      row + 1,
      centerOfSelectedAttachment.dx,
    );

    return AttachmentListNodePosition(
      attachmentInRowAbove,
      currentPosition.affinity,
    );
  }

  bool _doesAttachmentContainOffset(int index, Offset localOffset) {
    return _findLocalRectForAttachment(index).contains(localOffset);
  }

  TextAffinity _chooseHorizontalAffinityForAttachment(int index, double x) {
    return _findAttachmentCenter(index).dx > x ? TextAffinity.upstream : TextAffinity.downstream;
  }

  int _findNearestAttachmentInRow(int row, double x) {
    final (first, last) = _rowWrap.getChildRangeForRow(row);
    var nearestIndex = first;
    var nearestDistance = (x - _findAttachmentCenter(first).dx).abs();

    for (int i = first + 1; i <= last; i += 1) {
      final newDistance = (x - _findAttachmentCenter(i).dx).abs();
      if (newDistance < nearestDistance) {
        nearestIndex = i;
        nearestDistance = newDistance;
      }
    }

    return nearestIndex;
  }

  double _findAttachmentUpstreamX(int index) {
    return _findLocalRectForAttachment(index).left;
  }

  double _findAttachmentDownstreamX(int index) {
    return _findLocalRectForAttachment(index).right;
  }

  /// Returns the offset of the center of the given attachment, within this
  /// widget's coordinate space.
  Offset _findAttachmentCenter(int index) {
    return _findLocalRectForAttachment(index).center;
  }

  Rect _findLocalRectForAttachment(int index) {
    return _rowWrap.getBoundingBoxForChildAt(index);
  }

  RenderRowWrap get _rowWrap => _rowWrapKey.currentContext!.findRenderObject() as RenderRowWrap;

  @override
  Widget build(BuildContext context) {
    // Add/remove keys to match our number of children.
    if (_attachmentWidgetKeys.length > widget.attachments.length) {
      // Remove extra keys.
      final extraCount = _attachmentWidgetKeys.length - widget.attachments.length;
      _attachmentWidgetKeys.removeRange(
        _attachmentWidgetKeys.length - extraCount,
        _attachmentWidgetKeys.length,
      );
    } else {
      // Add needed keys.
      final neededCount = widget.attachments.length - _attachmentWidgetKeys.length;
      _attachmentWidgetKeys.addAll(
        List.generate(neededCount, (i) => GlobalKey()),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: BoxContentLayers(
        content: (void Function() onBuildScheduled) {
          return RowWrap(
            key: _rowWrapKey,
            spacing: 8,
            rowSpacing: 4,
            children: [
              for (var i = 0; i < widget.attachments.length; i += 1) //
                KeyedSubtree(
                  key: _attachmentWidgetKeys[i],
                  child: IgnorePointer(
                    // ^ Ignore the pointer because the component handles all tap
                    //   and gesture decisions, e.g., placing the caret.
                    child: widget.builder(
                      context,
                      widget.attachments[i],
                    ),
                  ),
                ),
            ],
          );
        },
        underlays: [
          _buildSelectionBox,
        ],
      ),
    );
  }

  ContentLayerWidget _buildSelectionBox(BuildContext context) {
    return _AttachmentListSelectionLayer(
      selection: widget.selection,
      selectionColor: widget.selectionColor,
    );
  }
}

class _AttachmentListSelectionLayer extends ContentLayerStatelessWidget {
  const _AttachmentListSelectionLayer({
    this.selection,
    required this.selectionColor,
  });

  final AttachmentListNodeSelection? selection;
  final Color selectionColor;

  @override
  Widget doBuild(
    BuildContext context,
    Element? contentElement,
    RenderObject? contentLayout,
  ) {
    if (contentLayout == null || contentLayout is! RenderRowWrap) {
      return const EmptyContentLayer();
    }

    final selection = this.selection;
    if (selection == null || selection.isCollapsed) {
      return const EmptyContentLayer();
    }

    final firstSelectedChild =
        selection.start.isUpstream ? selection.start.attachmentIndex : selection.start.attachmentIndex + 1;
    final lastSelectedChild =
        selection.end.isUpstream ? selection.end.attachmentIndex - 1 : selection.end.attachmentIndex;

    final selectionBoxes = contentLayout.getBoundingBoxesForRange(
      firstSelectedChild,
      lastSelectedChild,
    );

    return ContentLayerProxyWidget(
      child: Stack(
        children: [
          for (final box in selectionBoxes) //
            Positioned.fromRect(
              rect: box,
              child: ColoredBox(color: selectionColor),
            ),
        ],
      ),
    );
  }
}
