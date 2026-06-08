import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A custom version of a [Wrap], which only supports row-based layout, and exposes
/// a number of render object queries to inspect child positions within rows.
///
/// See [RenderRowWrap] for the layout queries.
class RowWrap extends MultiChildRenderObjectWidget {
  const RowWrap({
    super.key,
    this.spacing = 0.0,
    this.rowSpacing = 0.0,
    super.children,
  });

  /// Spacing between each child in a row.
  final double spacing;

  /// Spacing between each row.
  final double rowSpacing;

  @override
  RenderRowWrap createRenderObject(BuildContext context) {
    return RenderRowWrap(
      spacing: spacing,
      rowSpacing: rowSpacing,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderRowWrap renderObject) {
    renderObject
      ..spacing = spacing
      ..rowSpacing = rowSpacing;
  }
}

class RenderRowWrap extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, RowWrapParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, RowWrapParentData> {
  RenderRowWrap({
    double spacing = 0.0,
    double rowSpacing = 0.0,
    List<RenderBox>? children,
  })  : _spacing = spacing,
        _rowSpacing = rowSpacing {
    addAll(children);
  }

  /// The number of rows of children within the current layout.
  int get rowCount => _rows.length;

  double get spacing => _spacing;
  double _spacing;
  set spacing(double value) {
    if (_spacing == value) return;
    _spacing = value;
    markNeedsLayout();
  }

  double get rowSpacing => _rowSpacing;
  double _rowSpacing;
  set rowSpacing(double value) {
    if (_rowSpacing == value) return;
    _rowSpacing = value;
    markNeedsLayout();
  }

  final List<List<RenderBox>> _rows = [];
  final List<int> _childRowIndices = [];
  final List<RenderBox> _orderedChildren = [];
  final List<double> _rowTops = [];
  final List<double> _rowHeights = [];

  int findNearestRowForY(double y) {
    for (int i = 0; i < _rowTops.length; i += 1) {
      if (y <= _rowTops[i] + _rowHeights[i]) {
        return i;
      }
    }

    // Wasn't above, or within, any row. Must be below the bottom row.
    // Return the bottom row.
    return _rowTops.length - 1;
  }

  /// Returns the index of the [first] and [last] children in the given [row].
  (int first, int last) findChildRangeForRow(int row) {
    if (row < 0 || row >= rowCount) {
      throw Exception(
        "Tried to get RowWrap child range for a row that doesn't exist: "
        "$row (out of $rowCount rows)",
      );
    }

    int countBeforeRow = 0;
    for (int i = 0; i < row; i += 1) {
      countBeforeRow += _rows[i].length;
    }

    return (countBeforeRow, countBeforeRow + _rows[row].length - 1);
  }

  int findRowIndexForChildAt(int childIndex) {
    if (childIndex < 0 || childIndex >= _childRowIndices.length) {
      return -1;
    }
    return _childRowIndices[childIndex];
  }

  /// Returns a list of [Rect]s which bound the children between [start] and [end],
  /// inclusive.
  ///
  /// These bounding boxes combine child bounds within a row, but separate rectangles
  /// are returned from separate rows. This way, these boxes can be used to paint selection
  /// boxes, i.e., the boxes a user sees when dragging a selection in a document.
  List<Rect> findBoundingBoxesForRange(int start, int end) {
    final List<Rect> boxes = [];
    if (childCount == 0 || start < 0 || end >= childCount || start > end) {
      return boxes;
    }

    int currentRow = -1;
    int firstInRow = -1;
    int lastInRow = -1;

    for (int i = start; i <= end; i++) {
      final int rowIndex = findRowIndexForChildAt(i);
      if (rowIndex != currentRow) {
        if (currentRow != -1) {
          boxes.add(_calculateBoxForRowSegment(firstInRow, lastInRow, currentRow));
        }
        currentRow = rowIndex;
        firstInRow = i;
      }
      lastInRow = i;
    }

    if (currentRow != -1) {
      boxes.add(_calculateBoxForRowSegment(firstInRow, lastInRow, currentRow));
    }

    return boxes;
  }

  Rect findBoundingBoxForChildAt(int index) {
    final boxes = findBoundingBoxesForRange(index, index);
    if (boxes.isEmpty) {
      throw Exception(
        "Tried to get bounding box for non-existent child index: $index",
      );
    }

    return boxes.first;
  }

  /// Finds and returns a zero-width [Rect] that matches the upstream edge
  /// of the child box at the given [childIndex].
  Rect findEdgeBefore(int childIndex) {
    if (childIndex < 0 || childIndex >= childCount) {
      return Rect.zero;
    }

    final int rowIndex = findRowIndexForChildAt(childIndex);
    final RenderBox child = _orderedChildren[childIndex];
    final RowWrapParentData parentData = child.parentData as RowWrapParentData;

    final double left = parentData.offset.dx - (_spacing / 2);

    return Rect.fromLTWH(left, _rowTops[rowIndex], 0, _rowHeights[rowIndex]);
  }

  /// Finds and returns a zero-width [Rect] that matches the downstream edge
  /// of the child box at the given [childIndex].
  Rect findEdgeAfter(int childIndex) {
    if (childIndex < 0 || childIndex >= childCount) {
      return Rect.zero;
    }

    final int rowIndex = findRowIndexForChildAt(childIndex);
    final RenderBox child = _orderedChildren[childIndex];
    final RowWrapParentData parentData = child.parentData as RowWrapParentData;

    final double right = parentData.offset.dx + child.size.width + (_spacing / 2);

    return Rect.fromLTWH(right, _rowTops[rowIndex], 0, _rowHeights[rowIndex]);
  }

  /// Finds and returns the x-offset at the horizontal center of the gap between
  /// two attachments, at the given [gapIndex].
  ///
  /// If the gap sits before the first child, or after the last child, then the
  /// x-offset of the relevant edge has half the child spacing added to it and is
  /// then returned.
  double findXForGap(int gapIndex, TextAffinity affinity) {
    if (gapIndex == 0) {
      // This gap sits on the leading edge of the first child.
      return findEdgeBefore(0).left - (spacing / 2);
    }
    if (gapIndex >= childCount) {
      // This gap sits on the trailing edge of the last child.
      return findEdgeAfter(childCount - 1).right + (spacing / 2);
    }
    if (isGapAtRowSplit(gapIndex)) {
      // This gap is at a row split. Based on the affinity, either return
      // the trailing edge of the row above, or the leading edge of the row
      // below.
      return affinity == TextAffinity.downstream
          ? findEdgeBefore(gapIndex).left - (spacing / 2)
          : findEdgeAfter(gapIndex - 1).right + (spacing / 2);
    }

    // This gap sits between two attachments.
    final leftEdge = findEdgeAfter(gapIndex - 1);
    final rightEdge = findEdgeBefore(gapIndex);
    return (leftEdge.right + rightEdge.left) / 2;
  }

  /// Finds the gap in the given [row], which is nearest to the given [x]-offset.
  (int, TextAffinity) findNearestGapInRow(int row, {required double x}) {
    final rowRange = findGapRangeForRow(row);
    int nearestGapIndex = rowRange.$1;
    double nearestDistance = double.infinity;
    TextAffinity nearestAffinity = TextAffinity.downstream;

    for (var i = nearestGapIndex; i <= rowRange.$2; i += 1) {
      final affinity = i == rowRange.$1 ? TextAffinity.downstream : TextAffinity.upstream;
      final distance = (findXForGap(i, affinity) - x).abs();
      if (distance < nearestDistance) {
        nearestGapIndex = i;
        nearestDistance = distance;
        nearestAffinity = affinity;
      }
    }

    return (nearestGapIndex, nearestAffinity);
  }

  /// Returns `true` if the given gap (which includes the affinity) appears at
  /// the start of a row.
  bool isGapAtRowStart(int gapIndex, TextAffinity affinity) {
    if (!isGapAtRowSplit(gapIndex)) {
      return false;
    }

    return affinity == TextAffinity.downstream;
  }

  /// Returns `true` if the given gap (which includes the affinity) appears at
  /// the end of a row.
  bool isGapAtRowEnd(int gapIndex, TextAffinity affinity) {
    if (!isGapAtRowSplit(gapIndex)) {
      return false;
    }

    return affinity == TextAffinity.upstream;
  }

  /// Returns `true` if the given [gapIndex] points to a split between rows in
  /// the current layout.
  ///
  /// No affinity is required for this query because we consider the start or
  /// end of a row to both be "row splits".
  bool isGapAtRowSplit(int gapIndex) {
    if (gapIndex == 0) {
      return false;
    }

    final rowUpstream = findRowForGap(gapIndex, TextAffinity.upstream);
    final rowDownstream = findRowForGap(gapIndex, TextAffinity.downstream);
    return rowUpstream != rowDownstream;
  }

  /// Returns the index of the row that contains the given [gapIndex].
  ///
  /// This query requires an [affinity] because the same [gapIndex] can point
  /// to the end of one row, or the beginning of another row, based on that
  /// [affinity].
  int findRowForGap(int gapIndex, TextAffinity affinity) {
    if (gapIndex >= childCount) {
      return rowCount - 1;
    }
    if (gapIndex == 0) {
      return 0;
    }
    if (gapIndex == childCount - 1) {
      return rowCount - 1;
    }

    // This isn't the first or last gap, so we know there's at least
    // one gap to the left and right of this.
    final rowForAttachmentToTheLeft = _childRowIndices[gapIndex - 1];
    final rowForAttachmentToTheRight = _childRowIndices[gapIndex];

    if (rowForAttachmentToTheLeft != rowForAttachmentToTheRight) {
      return switch (affinity) {
        TextAffinity.upstream => findRowIndexForChildAt(gapIndex - 1),
        TextAffinity.downstream => findRowIndexForChildAt(gapIndex)
      };
    }

    return rowForAttachmentToTheRight;
  }

  /// Returns the y-offset of the top of the row at the given [rowIndex],
  /// in this render object's coordinate space.
  double findRowTop(int rowIndex) {
    return _rowTops[rowIndex];
  }

  /// Returns the y-offset of the bottom of the row at the given [rowIndex],
  /// in this render object's coordinate space.
  double findRowBottom(int rowIndex) {
    return _rowTops[rowIndex] + _rowHeights[rowIndex];
  }

  /// Returns the index of the first and last gap in the given [row].
  (int first, int last) findGapRangeForRow(int row) {
    final childRange = findChildRangeForRow(row);
    return (childRange.$1, childRange.$2 + 1); // +1 for gap at end of row.
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! RowWrapParentData) {
      child.parentData = RowWrapParentData();
    }
  }

  @override
  void performLayout() {
    _rows.clear();
    _childRowIndices.clear();
    _orderedChildren.clear();
    _rowTops.clear();
    _rowHeights.clear();

    if (childCount == 0) {
      size = constraints.smallest;
      return;
    }

    List<RenderBox> currentRun = [];
    double currentX = _spacing / 2;
    double currentY = _rowSpacing;
    double maxRunHeight = 0.0;
    double maxRowWidth = 0.0;
    int currentRowIndex = 0;

    RenderBox? child = firstChild;
    while (child != null) {
      final RowWrapParentData childParentData = child.parentData as RowWrapParentData;

      child.layout(const BoxConstraints(), parentUsesSize: true);

      if (currentRun.isNotEmpty && currentX + child.size.width + (_spacing / 2) > constraints.maxWidth) {
        _rows.add(currentRun);
        _rowTops.add(currentY);
        _rowHeights.add(maxRunHeight);

        currentRun = [];
        currentX = _spacing / 2;
        currentY += maxRunHeight + _rowSpacing;
        maxRunHeight = 0.0;
        currentRowIndex++;
      }

      childParentData.offset = Offset(currentX, currentY);
      currentRun.add(child);
      _childRowIndices.add(currentRowIndex);
      _orderedChildren.add(child);

      currentX += child.size.width + _spacing;
      if (child.size.height > maxRunHeight) {
        maxRunHeight = child.size.height;
      }

      final double rowEnd = currentX - (_spacing / 2);
      if (rowEnd > maxRowWidth) {
        maxRowWidth = rowEnd;
      }

      child = childParentData.nextSibling;
    }

    if (currentRun.isNotEmpty) {
      _rows.add(currentRun);
      _rowTops.add(currentY);
      _rowHeights.add(maxRunHeight);
    }

    final double finalWidth = constraints.hasBoundedWidth ? constraints.maxWidth : maxRowWidth;
    final double finalHeight = currentY + maxRunHeight + _rowSpacing;
    size = constraints.constrain(Size(finalWidth, finalHeight));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  Rect _calculateBoxForRowSegment(int startChildIndex, int endChildIndex, int rowIndex) {
    final RenderBox firstChild = _orderedChildren[startChildIndex];
    final RenderBox lastChild = _orderedChildren[endChildIndex];

    final RowWrapParentData firstParentData = firstChild.parentData as RowWrapParentData;
    final RowWrapParentData lastParentData = lastChild.parentData as RowWrapParentData;

    final double left = firstParentData.offset.dx - (_spacing / 2);
    final double right = lastParentData.offset.dx + lastChild.size.width + (_spacing / 2);
    final double top = _rowTops[rowIndex] - (_rowSpacing / 2);
    final double bottom = _rowTops[rowIndex] + _rowHeights[rowIndex] + (_rowSpacing / 2);

    return Rect.fromLTRB(left, top, right, bottom);
  }
}

class RowWrapParentData extends ContainerBoxParentData<RenderBox> {}
