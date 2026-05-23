import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class RowWrap extends MultiChildRenderObjectWidget {
  const RowWrap({
    super.key,
    this.spacing = 0.0,
    this.rowSpacing = 0.0,
    super.children,
  });

  final double spacing;
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

  int get wrapRowCount => _runs.length;

  double get spacing => _spacing;
  set spacing(double value) {
    if (_spacing == value) return;
    _spacing = value;
    markNeedsLayout();
  }

  double get rowSpacing => _rowSpacing;
  set rowSpacing(double value) {
    if (_rowSpacing == value) return;
    _rowSpacing = value;
    markNeedsLayout();
  }

  double _spacing;
  double _rowSpacing;
  final List<List<RenderBox>> _runs = [];
  final List<int> _childRowIndices = [];
  final List<RenderBox> _orderedChildren = [];
  final List<double> _rowTops = [];
  final List<double> _rowHeights = [];

  /// Returns the index of the [first] and [last] children in the given [row].
  (int first, int last) getChildRangeForRow(int row) {
    if (row < 0 || row >= wrapRowCount) {
      throw Exception(
        "Tried to get RowWrap child range for a row that doesn't exist: "
        "$row (out of $wrapRowCount rows)",
      );
    }

    int countBeforeRow = 0;
    for (int i = 0; i < row; i += 1) {
      countBeforeRow += _runs[i].length;
    }

    return (countBeforeRow, countBeforeRow + _runs[row].length - 1);
  }

  int getRowIndexForChildAt(int index) {
    if (index < 0 || index >= _childRowIndices.length) {
      return -1;
    }
    return _childRowIndices[index];
  }

  List<Rect> getBoundingBoxesForRange(int start, int end) {
    final List<Rect> boxes = [];
    if (childCount == 0 || start < 0 || end >= childCount || start > end) {
      return boxes;
    }

    int currentRow = -1;
    int firstInRow = -1;
    int lastInRow = -1;

    for (int i = start; i <= end; i++) {
      final int rowIndex = getRowIndexForChildAt(i);
      if (rowIndex != currentRow) {
        if (currentRow != -1) {
          boxes.add(
              _calculateBoxForRowSegment(firstInRow, lastInRow, currentRow));
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

  Rect getBoundingBoxForChildAt(int index) {
    final boxes = getBoundingBoxesForRange(index, index);
    if (boxes.isEmpty) {
      throw Exception(
        "Tried to get bounding box for non-existent child index: $index",
      );
    }

    return boxes.first;
  }

  Rect getEdgeBefore(int index) {
    if (index < 0 || index >= childCount) {
      return Rect.zero;
    }

    final int rowIndex = getRowIndexForChildAt(index);
    final RenderBox child = _orderedChildren[index];
    final RowWrapParentData parentData = child.parentData as RowWrapParentData;

    final double left = parentData.offset.dx - (_spacing / 2);
    final double top = _rowTops[rowIndex] - (_rowSpacing / 2);
    final double bottom =
        _rowTops[rowIndex] + _rowHeights[rowIndex] + (_rowSpacing / 2);

    return Rect.fromLTRB(left, top, left, bottom);
  }

  Rect getEdgeAfter(int index) {
    if (index < 0 || index >= childCount) {
      return Rect.zero;
    }

    final int rowIndex = getRowIndexForChildAt(index);
    final RenderBox child = _orderedChildren[index];
    final RowWrapParentData parentData = child.parentData as RowWrapParentData;

    final double right =
        parentData.offset.dx + child.size.width + (_spacing / 2);
    final double top = _rowTops[rowIndex] - (_rowSpacing / 2);
    final double bottom =
        _rowTops[rowIndex] + _rowHeights[rowIndex] + (_rowSpacing / 2);

    return Rect.fromLTRB(right, top, right, bottom);
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! RowWrapParentData) {
      child.parentData = RowWrapParentData();
    }
  }

  @override
  void performLayout() {
    _runs.clear();
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
      final RowWrapParentData childParentData =
          child.parentData as RowWrapParentData;

      child.layout(const BoxConstraints(), parentUsesSize: true);

      if (currentRun.isNotEmpty &&
          currentX + child.size.width + (_spacing / 2) > constraints.maxWidth) {
        _runs.add(currentRun);
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
      _runs.add(currentRun);
      _rowTops.add(currentY);
      _rowHeights.add(maxRunHeight);
    }

    final double finalWidth =
        constraints.hasBoundedWidth ? constraints.maxWidth : maxRowWidth;
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

  Rect _calculateBoxForRowSegment(
      int startChildIndex, int endChildIndex, int rowIndex) {
    final RenderBox firstChild = _orderedChildren[startChildIndex];
    final RenderBox lastChild = _orderedChildren[endChildIndex];

    final RowWrapParentData firstParentData =
        firstChild.parentData as RowWrapParentData;
    final RowWrapParentData lastParentData =
        lastChild.parentData as RowWrapParentData;

    final double left = firstParentData.offset.dx - (_spacing / 2);
    final double right =
        lastParentData.offset.dx + lastChild.size.width + (_spacing / 2);
    final double top = _rowTops[rowIndex] - (_rowSpacing / 2);
    final double bottom =
        _rowTops[rowIndex] + _rowHeights[rowIndex] + (_rowSpacing / 2);

    return Rect.fromLTRB(left, top, right, bottom);
  }
}

class RowWrapParentData extends ContainerBoxParentData<RenderBox> {}
