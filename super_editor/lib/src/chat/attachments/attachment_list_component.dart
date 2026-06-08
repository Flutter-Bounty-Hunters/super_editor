import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Placeholder;
import 'package:super_editor/super_editor.dart';

/// A [ComponentBuilder] that creates and configures components that display
/// a list of attachment thumbnails.
class AttachmentListComponentBuilder implements ComponentBuilder {
  const AttachmentListComponentBuilder(this.builder);

  final AttachmentThumbnailBuilder builder;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(
    Document document,
    DocumentNode node,
  ) {
    if (node is! AttachmentListNode) {
      return null;
    }

    return AttachmentListViewModel(
      nodeId: node.id,
      createdAt: node.metadata[NodeMetadata.createdAt],
      attachments: List.from(node.attachments),
      selectionColor: const Color(0x00000000),
    );
  }

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! AttachmentListViewModel) {
      return null;
    }

    return AttachmentListComponent(
      key: componentContext.componentKey,
      attachments: List.from(componentViewModel.attachments),
      selection: componentViewModel.selection?.nodeSelection as AttachmentListNodeSelection?,
      selectionColor: componentViewModel.selectionColor,
      builder: builder,
    );
  }
}

class AttachmentListViewModel extends SingleColumnLayoutComponentViewModel with SelectionAwareViewModelMixin {
  /// Stylesheet style property name to set the spacing between attachments.
  static const styleAttachmentSpacing = "attachmentSpacing";

  /// Stylesheet style property name to set the spacing between rows of attachments.
  static const styleRowSpacing = "rowSpacing";

  AttachmentListViewModel({
    required super.nodeId,
    required super.createdAt,
    required this.attachments,
    this.attachmentSpacing,
    this.rowSpacing,
    required Color selectionColor,
    super.maxWidth,
    super.padding = EdgeInsets.zero,
    DocumentNodeSelection<NodeSelection>? selection,
  }) {
    super.selection = selection;
    super.selectionColor = selectionColor;
  }

  List<Object> attachments;
  double? attachmentSpacing;
  double? rowSpacing;

  @override
  void applyStyles(Map<String, dynamic> styles) {
    super.applyStyles(styles);
    attachmentSpacing = styles[styleAttachmentSpacing];
    rowSpacing = styles[styleRowSpacing];
  }

  @override
  AttachmentListViewModel copy() {
    return AttachmentListViewModel(
      nodeId: nodeId,
      createdAt: createdAt,
      maxWidth: maxWidth,
      padding: padding,
      attachments: List.from(attachments),
      attachmentSpacing: attachmentSpacing,
      rowSpacing: rowSpacing,
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
          attachmentSpacing == other.attachmentSpacing &&
          rowSpacing == other.rowSpacing &&
          selection == other.selection &&
          selectionColor == other.selectionColor &&
          const DeepCollectionEquality().equals(attachments, other.attachments);

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  int get hashCode =>
      super.hashCode ^
      nodeId.hashCode ^
      attachments.hashCode ^
      attachmentSpacing.hashCode ^
      rowSpacing.hashCode ^
      selection.hashCode ^
      selectionColor.hashCode;
}

/// A document component that displays a list of attachment thumbnails.
class AttachmentListComponent extends StatefulWidget {
  const AttachmentListComponent({
    super.key,
    required this.attachments,
    this.attachmentSpacing = 8,
    this.rowSpacing = 4,
    this.selectionColor = Colors.blue,
    this.selection,
    this.ignorePointer = true,
    required this.builder,
  });

  /// A list of attachments whose thumbnail will be displayed in this
  /// component, row-by-row.
  final List<Object> attachments;

  /// The space between two sequential attachments.
  final double attachmentSpacing;

  /// The space between rows of attachments.
  final double rowSpacing;

  final Color selectionColor;
  final AttachmentListNodeSelection? selection;

  /// Whether to ignore the pointer when its over this component.
  ///
  /// This should almost always be `true`, because the editor/document
  /// layout wants to handle all gesture interactions. However, if a
  /// thumbnail might include a tappable region, such as a small "x" to
  /// delete an attachment, then this should be set to `false` and the
  /// thumbnail [builder] needs to ignore the pointer everywhere except
  /// that small "x" tap area.
  final bool ignorePointer;

  /// Builder that builds thumbnail widgets for each attachment in the list.
  final AttachmentThumbnailBuilder builder;

  @override
  State<AttachmentListComponent> createState() => _AttachmentListComponentState();
}

/// Builds an attachment thumbnail widget for an [AttachmentListComponent].
///
/// The [attachmentIndex] is provided so that a thumbnail widget can be used
/// to delete the associated attachment, if desired. However, any use-case that
/// does that must also pipe in the `Editor` to execute that request.
typedef AttachmentThumbnailBuilder = Widget Function(
  BuildContext context,
  int attachmentIndex,
  Object attachment,
);

class _AttachmentListComponentState extends State<AttachmentListComponent> with DocumentComponent {
  final _rowWrapKey = GlobalKey(debugLabel: 'attachment-list_row-wrap');

  @override
  NodePosition getBeginningPosition() => AttachmentListNodePosition.start;

  @override
  NodePosition getBeginningPositionNearX(double x) {
    if (widget.attachments.isEmpty) {
      // We should never be empty, but this is a reasonable fallback.
      return AttachmentListNodePosition.start;
    }

    // We want to return the position in the first row of the list, nearest
    // to the given `x`.
    final rowRange = _rowWrap.findChildRangeForRow(0);

    int nearestIndex = rowRange.$1;
    double nearestDistance = (_findAttachmentUpstreamX(rowRange.$1) - x).abs();

    for (int i = rowRange.$1 + 1; i <= rowRange.$2; i += 1) {
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

    return AttachmentListNodePosition(nearestIndex);
  }

  @override
  NodePosition getEndPosition() => AttachmentListNodePosition(widget.attachments.length, TextAffinity.downstream);

  @override
  NodePosition getEndPositionNearX(double x) {
    if (widget.attachments.isEmpty) {
      // We should never be empty, but this is a reasonable fallback.
      return AttachmentListNodePosition.start;
    }

    // We want to return the position in the last row of the list, nearest
    // to the given `x`.
    final rowIndex = _rowWrap.rowCount - 1;
    final rowRange = _rowWrap.findChildRangeForRow(rowIndex);

    int nearestIndex = rowRange.$1;
    double nearestDistance = (_findAttachmentDownstreamX(nearestIndex) - x).abs();

    for (int i = rowRange.$1 + 1; i <= rowRange.$2; i += 1) {
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

    return AttachmentListNodePosition(nearestIndex);
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

    if (nodePosition.gapIndex > widget.attachments.length) {
      if (kDebugMode) {
        throw AssertionError(
          'Was asked to get edge for position before attachment at index '
          '${nodePosition.gapIndex} but we only have '
          '${widget.attachments.length} attachments in this list.',
        );
      }

      return Rect.zero;
    }

    if (nodePosition.gapIndex == widget.attachments.length) {
      return _rowWrap.findEdgeAfter(nodePosition.gapIndex - 1);
    }

    if (_isRowSplit(nodePosition)) {
      // This position points to a gap where we move from one row to another.
      // Choose the row based on the position affinity.
      switch (nodePosition.affinity) {
        case TextAffinity.upstream:
          // Trailing edge of last attachment in row.
          return _rowWrap.findEdgeAfter(nodePosition.gapIndex - 1);
        case TextAffinity.downstream:
          // Leading edge of first attachment in row.
          return _rowWrap.findEdgeBefore(nodePosition.gapIndex);
      }
    }

    return _rowWrap.findEdgeBefore(nodePosition.gapIndex);
  }

  @override
  Offset getOffsetForPosition(NodePosition nodePosition) {
    if (nodePosition is! AttachmentListNodePosition) {
      throw ArgumentError(
          'Invalid node position type. Expected _AttachmentListNodePosition but got ${nodePosition.runtimeType}');
    }

    if (nodePosition.gapIndex > widget.attachments.length) {
      return Offset.zero;
    }

    if (nodePosition.gapIndex == widget.attachments.length) {
      // The position sits after the last attachment. Return the right side
      // of the last attachment.
      final lastAttachmentBox = _findLocalRectForAttachment(widget.attachments.length - 1);
      return Offset(lastAttachmentBox.right, lastAttachmentBox.center.dy);
    }

    if (_isRowSplit(nodePosition)) {
      // This position points to a gap where we move from one row to another.
      // Choose the row based on the position affinity.
      switch (nodePosition.affinity) {
        case TextAffinity.upstream:
          final attachmentBox = _findLocalRectForAttachment(nodePosition.gapIndex - 1);
          return Offset(attachmentBox.right, attachmentBox.center.dy);
        case TextAffinity.downstream:
          final attachmentBox = _findLocalRectForAttachment(nodePosition.gapIndex);
          return Offset(attachmentBox.left, attachmentBox.center.dy);
      }
    } else {
      // This is a position in a row, which isn't the first position or last position.
      final attachmentBox = _findLocalRectForAttachment(nodePosition.gapIndex);
      return Offset(attachmentBox.left, attachmentBox.center.dy);
    }
  }

  @override
  CaretGeometry getCaretForPosition(NodePosition nodePosition) {
    if (nodePosition is! AttachmentListNodePosition) {
      throw ArgumentError(
          'Invalid node position type. Expected _AttachmentListNodePosition but got ${nodePosition.runtimeType}');
    }

    if (nodePosition.gapIndex > widget.attachments.length) {
      throw Exception(
          'Invalid AttachmentListNodePosition. Requested position at gap ${nodePosition.gapIndex} in a node that only has ${widget.attachments.length} attachments.');
    }

    final rowIndex = _rowWrap.findRowForGap(nodePosition.gapIndex, nodePosition.affinity);
    final rowTop = _rowWrap.findRowTop(rowIndex);
    final rowBottom = _rowWrap.findRowBottom(rowIndex);

    if (nodePosition.gapIndex == 0) {
      // The caret sits before the first attachment.
      return CaretGeometry(x: 0, top: rowTop, bottom: rowBottom);
    }
    if (nodePosition.gapIndex == widget.attachments.length) {
      // The caret sits after the last attachment. Return the right side
      // of the last attachment.
      final lastAttachmentBox = _findLocalRectForAttachment(widget.attachments.length - 1);
      return CaretGeometry(x: lastAttachmentBox.right, top: rowTop, bottom: rowBottom);
    }

    if (_isRowSplit(nodePosition)) {
      // This position points to a gap where we move from one row to another.
      // Choose the row based on the position affinity.
      switch (nodePosition.affinity) {
        case TextAffinity.upstream:
          final attachmentBox = _findLocalRectForAttachment(nodePosition.gapIndex - 1);
          return CaretGeometry(x: attachmentBox.right, top: rowTop, bottom: rowBottom);
        case TextAffinity.downstream:
          final attachmentBox = _findLocalRectForAttachment(nodePosition.gapIndex);
          return CaretGeometry(x: attachmentBox.left, top: rowTop, bottom: rowBottom);
      }
    } else {
      // This is a position in a row, which isn't the first position or last position.
      final attachmentBoxBefore = _findLocalRectForAttachment(nodePosition.gapIndex - 1);
      final attachmentBoxAfter = _findLocalRectForAttachment(nodePosition.gapIndex);
      return CaretGeometry(
        x: (attachmentBoxBefore.right + attachmentBoxAfter.left) / 2,
        top: rowTop,
        bottom: rowBottom,
      );
    }
  }

  @override
  AttachmentListNodePosition? getPositionAtOffset(Offset localOffset) {
    // Find the nearest attachment. We want to confine our search to
    // the row of attachments that contain the y-offset of the cursor.
    // So, first, find the row we want to search.
    final rowIndex = _rowWrap.findNearestRowForY(localOffset.dy);

    // Find the nearest attachment in the row.
    final rowRange = _rowWrap.findChildRangeForRow(rowIndex);
    int nearestIndex = rowRange.$1;
    double nearestDistance = double.infinity;

    for (int i = rowRange.$1; i <= rowRange.$2; i += 1) {
      if (_doesAttachmentContainOffset(i, localOffset)) {
        // This attachment contains the offset. Return it.
        final gapIndex = _chooseGapForAttachment(i, localOffset.dx);
        return AttachmentListNodePosition(gapIndex, _chooseAffinityForGap(gapIndex, localOffset.dy));
      }

      final newDistance = (_findAttachmentCenter(i) - localOffset).distance;

      if (newDistance < nearestDistance) {
        // We found a closer attachment to the desired `x`. Record it.
        nearestIndex = i;
        nearestDistance = newDistance;
      }
    }

    final gapIndex = _chooseGapForAttachment(nearestIndex, localOffset.dx);
    return AttachmentListNodePosition(gapIndex, _chooseAffinityForGap(gapIndex, localOffset.dy));
  }

  @override
  Rect getRectForPosition(NodePosition nodePosition) {
    if (nodePosition is! AttachmentListNodePosition) {
      throw ArgumentError(
          'Invalid node position type. Expected _AttachmentListNodePosition but got ${nodePosition.runtimeType}');
    }

    if (nodePosition.gapIndex > widget.attachments.length) {
      if (kDebugMode) {
        debugPrint(
          "WARNING: Tried to getRectForPosition() in AttachmentListComponent for position beyond "
          "last attachment. Gap index: ${nodePosition.gapIndex}. Attachment count: ${widget.attachments.length}",
        );
      }
      return Rect.zero;
    }

    if (nodePosition.gapIndex == widget.attachments.length) {
      return _findLocalRectForAttachment(widget.attachments.length - 1);
    }

    if (_rowWrap.isGapAtRowSplit(nodePosition.gapIndex)) {
      // This position points to a row split. We need to select the
      // attachment based on the position affinity.
      return switch (nodePosition.affinity) {
        TextAffinity.upstream => _findLocalRectForAttachment(nodePosition.gapIndex - 1),
        TextAffinity.downstream => _findLocalRectForAttachment(nodePosition.gapIndex),
      };
    }

    return _findLocalRectForAttachment(nodePosition.gapIndex);
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
    if (baseNodePosition.isEquivalentTo(extentNodePosition)) {
      return Rect.zero;
    }

    final startGap = baseNodePosition.gapIndex < extentNodePosition.gapIndex ? baseNodePosition : extentNodePosition;
    final endGap = baseNodePosition.gapIndex > extentNodePosition.gapIndex ? extentNodePosition : baseNodePosition;

    var boundingRect = _findLocalRectForAttachment(startGap.gapIndex);
    for (int i = startGap.gapIndex + 1; i <= endGap.gapIndex; i += 1) {
      if (i >= widget.attachments.length) {
        // This is probably the gap after the last attachment. It contributes
        // nothing to the selection bounds. Ignore it.
        continue;
      }

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
      base: basePosition,
      extent: extentPosition,
    );
  }

  @override
  NodeSelection? getSelectionInRange(
    Offset localBaseOffset,
    Offset localExtentOffset,
  ) {
    if (widget.attachments.isEmpty) {
      // We don't expect to ever be empty, but this is a reasonable fallback.
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
      extent: AttachmentListNodePosition(widget.attachments.length),
    );
  }

  @override
  NodePosition? movePositionLeft(NodePosition currentPosition, [MovementModifier? movementModifier]) {
    if (currentPosition is! AttachmentListNodePosition) {
      throw ArgumentError(
          'Invalid node position type. Expected _AttachmentListNodePosition but got ${currentPosition.runtimeType}');
    }

    if (currentPosition.gapIndex == 0) {
      // Nothing to the left.
      return null;
    }

    if (!_isRowSplit(currentPosition)) {
      // Move left in the same row.
      return AttachmentListNodePosition(
        currentPosition.gapIndex - 1,
        // We use downstream affinity to ensure that we remain on this same row
        // if the user gets to the end of it.
        TextAffinity.downstream,
      );
    } else {
      if (currentPosition.isDownstream) {
        // Move up a row.
        return AttachmentListNodePosition(
          currentPosition.gapIndex,
          TextAffinity.upstream,
        );
      } else {
        // We already moved up a row. Keep moving left.
        return AttachmentListNodePosition(
          currentPosition.gapIndex - 1,
          TextAffinity.downstream,
        );
      }
    }
  }

  @override
  NodePosition? movePositionRight(NodePosition currentPosition, [MovementModifier? movementModifier]) {
    if (currentPosition is! AttachmentListNodePosition) {
      throw ArgumentError(
          'Invalid node position type. Expected _AttachmentListNodePosition but got ${currentPosition.runtimeType}');
    }

    if (currentPosition.gapIndex >= widget.attachments.length) {
      // Nothing to the right.
      return null;
    }

    if (!_isRowSplit(currentPosition)) {
      // Move right in the same row.
      return AttachmentListNodePosition(
        currentPosition.gapIndex + 1,
        // We use upstream affinity to ensure that we remain on this same row
        // if the user gets to the end of it.
        TextAffinity.upstream,
      );
    } else {
      if (currentPosition.isUpstream) {
        // Move down a row.
        return AttachmentListNodePosition(
          currentPosition.gapIndex,
          TextAffinity.downstream,
        );
      } else {
        // We already moved down a row. Keep moving to the right.
        return AttachmentListNodePosition(
          currentPosition.gapIndex + 1,
          TextAffinity.upstream,
        );
      }
    }
  }

  @override
  NodePosition? movePositionUp(NodePosition currentPosition) {
    if (currentPosition is! AttachmentListNodePosition) {
      throw ArgumentError(
          'Invalid node position type. Expected _AttachmentListNodePosition but got ${currentPosition.runtimeType}');
    }

    final attachmentRow = _rowWrap.findRowForGap(currentPosition.gapIndex, currentPosition.affinity);

    if (attachmentRow == 0) {
      // We're in the first row. Move to the start of the list.
      return null;
    }

    // We're not in the first row. Move up a row.
    final currentGapAffinity = _rowWrap.isGapAtRowEnd(currentPosition.gapIndex, currentPosition.affinity)
        ? TextAffinity.upstream
        : TextAffinity.downstream;
    final currentGapX = _rowWrap.findXForGap(currentPosition.gapIndex, currentGapAffinity);
    final nearestGapInRowAbove = _rowWrap.findNearestGapInRow(attachmentRow - 1, x: currentGapX);

    return AttachmentListNodePosition(
      nearestGapInRowAbove.$1,
      nearestGapInRowAbove.$2,
    );
  }

  @override
  NodePosition? movePositionDown(NodePosition currentPosition) {
    if (currentPosition is! AttachmentListNodePosition) {
      throw ArgumentError(
          'Invalid node position type. Expected _AttachmentListNodePosition but got ${currentPosition.runtimeType}');
    }

    final attachmentRow = _rowWrap.findRowForGap(currentPosition.gapIndex, currentPosition.affinity);

    if (attachmentRow == _rowWrap.rowCount - 1) {
      // We're in the last row. Move to the end of the list.
      return null;
    }

    // We're not in the last row. Move down a row.
    final currentGapAffinity = _rowWrap.isGapAtRowEnd(currentPosition.gapIndex, currentPosition.affinity)
        ? TextAffinity.upstream
        : TextAffinity.downstream;
    final currentGapX = _rowWrap.findXForGap(currentPosition.gapIndex, currentGapAffinity);
    final nearestGapInRowBelow = _rowWrap.findNearestGapInRow(attachmentRow + 1, x: currentGapX);

    return AttachmentListNodePosition(
      nearestGapInRowBelow.$1,
      nearestGapInRowBelow.$2,
    );
  }

  bool _doesAttachmentContainOffset(int index, Offset localOffset) {
    return _findLocalRectForAttachment(index).contains(localOffset);
  }

  int _chooseGapForAttachment(int attachmentIndex, double x) {
    return x > _findAttachmentCenter(attachmentIndex).dx ? attachmentIndex + 1 : attachmentIndex;
  }

  TextAffinity _chooseAffinityForGap(int gapIndex, double y) {
    if (!_isRowSplit(AttachmentListNodePosition(gapIndex))) {
      // This isn't a row split, so affinity doesn't matter. Default to
      // downstream.
      return TextAffinity.downstream;
    }

    final nearestRow = _rowWrap.findNearestRowForY(y);
    final nextAttachmentRow = _rowWrap.findRowIndexForChildAt(gapIndex);
    if (nextAttachmentRow > nearestRow) {
      // The y-value is in the row above. This is the upstream side.
      return TextAffinity.upstream;
    } else {
      // The y-value is in the row below. This is the downstream side.
      return TextAffinity.downstream;
    }
  }

  bool _isRowSplit(AttachmentListNodePosition position) {
    if (position.gapIndex == 0 || position.gapIndex == widget.attachments.length) {
      return false;
    }

    final isRowSplit =
        _rowWrap.findRowIndexForChildAt(position.gapIndex - 1) != _rowWrap.findRowIndexForChildAt(position.gapIndex);
    return isRowSplit;
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
    return _rowWrap.findBoundingBoxForChildAt(index);
  }

  RenderRowWrap get _rowWrap => _rowWrapKey.currentContext!.findRenderObject() as RenderRowWrap;

  @override
  Widget build(BuildContext context) {
    return BoxContentLayers(
      content: (void Function() onBuildScheduled) {
        return RowWrap(
          key: _rowWrapKey,
          spacing: widget.attachmentSpacing,
          rowSpacing: widget.rowSpacing,
          children: [
            for (var i = 0; i < widget.attachments.length; i += 1) //
              IgnorePointer(
                // ^ Ignore the pointer because the component handles all tap
                //   and gesture decisions, e.g., placing the caret.
                ignoring: widget.ignorePointer,
                child: widget.builder(
                  context,
                  i,
                  widget.attachments[i],
                ),
              ),
          ],
        );
      },
      underlays: [
        _buildSelectionBox,
      ],
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

    final selectionBoxes = contentLayout.findBoundingBoxesForRange(
      selection.start.gapIndex,
      selection.end.gapIndex - 1, // -1 because this position sits after last selected attachment.
    );

    return ContentLayerProxyWidget(
      child: IgnorePointer(
        child: Stack(
          children: [
            for (final box in selectionBoxes) //
              Positioned.fromRect(
                rect: box,
                child: ColoredBox(color: selectionColor),
              ),
          ],
        ),
      ),
    );
  }
}
