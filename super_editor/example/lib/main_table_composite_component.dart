import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  runApp(
    MaterialApp(
      home: _ComponentsInComponentsDemoScreen(),
    ),
  );
}

class _ComponentsInComponentsDemoScreen extends StatefulWidget {
  const _ComponentsInComponentsDemoScreen();

  @override
  State<_ComponentsInComponentsDemoScreen> createState() => _ComponentsInComponentsDemoScreenState();
}

class _ComponentsInComponentsDemoScreenState extends State<_ComponentsInComponentsDemoScreen> {
  late final Editor _editor;

  @override
  void initState() {
    super.initState();

    _editor = createDefaultDocumentEditor(
      isHistoryEnabled: true,
      document: MutableDocument(
        nodes: [
          ParagraphNode(
            id: "header",
            text: AttributedText("Table"),
            metadata: {
              NodeMetadata.blockType: header1Attribution,
            },
          ),
          ParagraphNode(
            id: "table title",
            text: AttributedText("Table 1. The is a demo table with primitive implementation"),
          ),
          _DemoTableNode.withRows("table", [
            [
              _DemoTableCellNode(id: 'cell[0, 0]', children: [
                ParagraphNode(
                  id: Editor.createNodeId(),
                  text: AttributedText("First cell"),
                ),
                HorizontalRuleNode(id: Editor.createNodeId()),
                ParagraphNode(
                  id: Editor.createNodeId(),
                  text: AttributedText("New Paragraph"),
                ),
              ]),
              _DemoTableCellNode(id: 'cell[1, 0]', children: [
                ParagraphNode(
                  id: Editor.createNodeId(),
                  text: AttributedText("Top"),
                ),
              ]),
              _DemoTableCellNode(id: 'cell[2, 0]', children: [
                ParagraphNode(
                  id: Editor.createNodeId(),
                  text: AttributedText("Third column"),
                ),
                ImageNode(
                  id: "main-banner-image",
                  imageUrl:
                      "https://www.thedroidsonroids.com/wp-content/uploads/2023/08/flutter_blog_series_What-is-Flutter-app-development-.png",
                ),
              ]),
              _DemoTableCellNode(id: 'cell[3, 0]', children: [
                ParagraphNode(
                  id: Editor.createNodeId(),
                  text: AttributedText("Top"),
                ),
              ]),
            ],
            [
              _DemoTableCellNode(id: 'cell[0, 1]', children: [
                ParagraphNode(
                  id: Editor.createNodeId(),
                  text: AttributedText("Center - Left\nNew Line"),
                ),
              ]),
              _DemoTableCellNode(id: 'cell[1, 1]', children: [
                ParagraphNode(
                  id: Editor.createNodeId(),
                  text: AttributedText("Center"),
                ),
              ]),
              _DemoTableCellNode(id: 'cell[2, 1]', children: [
                ParagraphNode(
                  id: Editor.createNodeId(),
                  text: AttributedText("Center Right"),
                ),
              ]),
              _DemoTableCellNode(id: 'cell[3, 1]', children: [
                ParagraphNode(
                  id: Editor.createNodeId(),
                  text: AttributedText("Center Right"),
                ),
              ])
            ],
            [
              _DemoTableCellNode(id: 'cell[0, 2]', children: [
                ParagraphNode(
                  id: Editor.createNodeId(),
                  text: AttributedText("Last row cell has options:"),
                ),
                ListItemNode.unordered(id: Editor.createNodeId(), text: AttributedText("Option 1")),
                ListItemNode.unordered(id: Editor.createNodeId(), text: AttributedText("Option 2"))
              ]),
              _DemoTableCellNode(id: 'cell[1, 2]', children: [
                ParagraphNode(
                  id: Editor.createNodeId(),
                  text: AttributedText("Example text"),
                ),
              ]),
              _DemoTableCellNode(id: 'cell[2, 2]', children: [
                ParagraphNode(
                  id: Editor.createNodeId(),
                  text: AttributedText("Last cell"),
                ),
              ]),
              _DemoTableCellNode(id: 'cell[3, 2]', children: [
                ParagraphNode(
                  id: Editor.createNodeId(),
                  text: AttributedText("Last cell"),
                ),
              ])
            ]
          ]),
          ParagraphNode(
            id: "footer text",
            text: AttributedText("This is after the table component."),
          ),
        ],
      ),
      composer: MutableDocumentComposer(),
    );
  }

  @override
  void dispose() {
    _editor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SuperEditor(
        editor: _editor,
        stylesheet: defaultStylesheet.copyWith(
          addRulesAfter: [
            StyleRule(
              BlockSelector.all.childOf("demoTable"),
              (doc, docNode) {
                return {
                  Styles.padding: CascadingPadding.symmetric(vertical: 5, horizontal: 15),
                };
              },
            ),
            StyleRule(
              BlockSelector.all.childOf('demoTableCell'),
              (doc, docNode) {
                return {
                  // Styles.textStyle: const TextStyle(color: Colors.black54),
                  Styles.padding: CascadingPadding.symmetric(vertical: 0, horizontal: 0),
                };
              },
            ),
            StyleRule(
              BlockSelector(horizontalRuleBlockType.name).childOf("banner"),
              (doc, docNode) {
                return {
                  Styles.backgroundColor: Colors.white.withValues(alpha: 0.25),
                };
              },
            ),
          ],
        ),
        componentBuilders: [
          _DemoTableComponentBuilder(),
          ...defaultComponentBuilders,
        ],
        keyboardActions: [
          tabToNextCell,
          shiftPlusArrowToSelectCellsInsideOrGoOutside,
          shiftPlusArrowThroughTableToSelectByRow,
          ...defaultImeKeyboardActions,
        ],
      ),
    );
  }
}

bool get isMobilePlatform =>
    (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

/// In mobile platforms we need a special touch-based UI to do cell-based selection (and somehow hide
/// existing overlay)
bool get useCellBasedSelection => !isMobilePlatform;

const demoTableBlockType = NamedAttribution("demoTable");
const demoTableCellBlockType = NamedAttribution("demoTableCell");

class _DemoTableComponentBuilder implements ComponentBuilder {
  @override
  SingleColumnLayoutComponentViewModel? createViewModel(
    PresenterContext presenterContext,
    Document document,
    DocumentNode node,
  ) {
    if (node is _DemoTableCellNode) {
      return _DemoTableCellViewModel(
        nodeId: node.id,
        children: node.children.map((childNode) => presenterContext.createViewModel(childNode)!),
      );
    } else if (node is _DemoTableNode) {
      return _DemoTableViewModel(
        nodeId: node.id,
        children: node.children.map((childNode) => presenterContext.createViewModel(childNode)!),
        columnsCount: node.columnCount,
      );
    }
    return null;
  }

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is _DemoTableViewModel) {
      return _DemoTableComponent(
        key: componentContext.componentKey,
        backgroundColor: componentViewModel.backgroundColor,
        columnsCount: componentViewModel.columnsCount,
        selection: componentViewModel.selection?.nodeSelection as _MultipleCellsSelection?,
        selectionColor: componentViewModel.selectionColor,
        children: componentViewModel.children.map((childViewModel) {
          final (componentKey, component) = componentContext.buildChildComponent(childViewModel);
          return CompositeComponentChild(
            nodeId: childViewModel.nodeId,
            componentKey: componentKey,
            widget: component,
          );
        }).toList(),
      );
    }
    if (componentViewModel is _DemoTableCellViewModel) {
      return ColumnDocumentComponent(
        key: componentContext.componentKey,
        children: componentViewModel.children.map((childViewModel) {
          final (componentKey, component) = componentContext.buildChildComponent(childViewModel);
          return CompositeComponentChild(
            nodeId: childViewModel.nodeId,
            componentKey: componentKey,
            widget: component,
          );
        }).toList(),
      );
    }
    return null;
  }
}

class _DemoTableViewModel extends CompositeNodeViewModel with SelectionAwareViewModelMixin {
  Color? backgroundColor;

  DocumentNodeSelection? selection;
  Color selectionColor;

  int columnsCount;

  _DemoTableViewModel({
    required super.nodeId,
    required super.children,
    required this.columnsCount,
    this.selectionColor = Colors.transparent,
  });

  @override
  SingleColumnLayoutComponentViewModel copy() {
    return internalCopy(
      _DemoTableViewModel(
        nodeId: nodeId,
        children: children,
        columnsCount: columnsCount,
      ),
    );
  }

  @override
  CompositeNodeViewModel internalCopy(_DemoTableViewModel viewModel) {
    final copy = super.internalCopy(viewModel) as _DemoTableViewModel;
    copy.backgroundColor = backgroundColor;
    copy.selection = selection;
    return copy;
  }

  @override
  void applyStyles(Map<String, dynamic> styles) {
    backgroundColor = styles[Styles.backgroundColor];
    super.applyStyles(styles);
  }

  bool shouldApplySelectionToChildren() {
    final nodeSelection = selection?.nodeSelection;
    if (nodeSelection is _MultipleCellsSelection) {
      return true; //!nodeSelection.filled;
    }
    return true;
  }
}

class _MultipleCellsSelection extends CompositeNodeSelection {
  final bool filled;
  final List<String> selectedCells;
  _MultipleCellsSelection({
    required super.base,
    required super.extent,
    required this.selectedCells,
    required this.filled,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _MultipleCellsSelection &&
          runtimeType == other.runtimeType &&
          filled == other.filled &&
          selectedCells == other.selectedCells;

  @override
  int get hashCode => Object.hash(filled, selectedCells);
}

class _DemoTableNode extends CompositeNode {
  _DemoTableNode({
    required super.id,
    required this.children,
    required this.columnCount,
    Map<String, dynamic>? metadata,
  }) : super(
          metadata: {
            if (metadata != null) //
              ...metadata,
            NodeMetadata.blockType: demoTableBlockType,
          },
        );

  factory _DemoTableNode.withRows(String id, List<List<_DemoTableCellNode>> rows) {
    return _DemoTableNode(
      id: id,
      children: rows.fold([], (res, row) {
        res.addAll(row);
        return res;
      }),
      columnCount: rows.first.length,
    );
  }

  final List<DocumentNode> children;

  final int columnCount;

  int get rowsCount => (children.length / columnCount).floor();

  @override
  NodeSelection computeSelection({required NodePosition base, required NodePosition extent}) {
    assert(base is CompositeNodePosition);
    assert(extent is CompositeNodePosition);

    return _MultipleCellsSelection(
      base: base as CompositeNodePosition,
      extent: extent as CompositeNodePosition,
      selectedCells: getSelectedChildrenBetween(
        base.childNodeId,
        extent.childNodeId,
      ),
      filled: base.childNodeId != extent.childNodeId,
    );
  }

  List<String> getSelectedChildrenBetween(String upstreamChildId, String downstreamChildId) {
    final baseIndex = getChildTableIndex(upstreamChildId);
    final extentIndex = getChildTableIndex(downstreamChildId);

    final minX = min(baseIndex.x, extentIndex.x);
    final maxX = max(baseIndex.x, extentIndex.x);
    final minY = min(baseIndex.y, extentIndex.y);
    final maxY = max(baseIndex.y, extentIndex.y);

    final result = <String>[];

    for (var y = minY; y <= maxY; y += 1) {
      for (var x = minX; x <= maxX; x += 1) {
        result.add(getChildAtIndex(_DemoTableIndex(x, y)).id);
      }
    }

    return result;
  }

  CompositeNodePosition? adjustUpstreamPosition({
    required CompositeNodePosition upstreamPosition,
    CompositeNodePosition? downstreamPosition,
  }) {
    if (!useCellBasedSelection) {
      return null;
    }
    // When both positions within the table, but different cells
    if (downstreamPosition != null && downstreamPosition.childNodeId != upstreamPosition.childNodeId) {
      final selection = getSelectedChildrenBetween(upstreamPosition.childNodeId, downstreamPosition.childNodeId);
      final firstChild = getChildByNodeId(selection.first)!;
      return CompositeNodePosition(firstChild.id, firstChild.beginningPosition);
    }

    if (downstreamPosition == null) {
      // When selection starts in the table, but goes outside - start it with beginning of the row
      final tableIndex = getChildTableIndex(upstreamPosition.childNodeId);
      final child = getChildAtIndex(_DemoTableIndex(0, tableIndex.y));

      return CompositeNodePosition(child.id, child.beginningPosition);
    }

    return null;
  }

  CompositeNodePosition? adjustDownstreamPosition({
    required CompositeNodePosition downstreamPosition,
    CompositeNodePosition? upstreamPosition,
  }) {
    if (!useCellBasedSelection) {
      return null;
    }
    // When both positions within the table, but different cells
    if (upstreamPosition != null && downstreamPosition.childNodeId != upstreamPosition.childNodeId) {
      final selection = getSelectedChildrenBetween(upstreamPosition.childNodeId, downstreamPosition.childNodeId);
      final firstChild = getChildByNodeId(selection.last)!;
      return CompositeNodePosition(firstChild.id, firstChild.endPosition);
    }

    if (upstreamPosition == null) {
      // When selection starts outside table, but ends in the table - round to last node of the row
      final tableIndex = getChildTableIndex(downstreamPosition.childNodeId);
      final child = getChildAtIndex(_DemoTableIndex(columnCount - 1, tableIndex.y));
      return CompositeNodePosition(child.id, child.endPosition);
    }

    return null;
  }

  CompositeNode? resolveWhenChildrenAffected({
    required List<String> removedChildIds,
    required List<String> emptiedChildIds,
    required bool selectionFlowedThrough,
  }) {
    if (emptiedChildIds.length == children.length) {
      // When selected through whole table and pressed delete - delete it completely
      return null;
    }
    return this;
  }

  @override
  DocumentNode copyWithAddedMetadata(Map<String, dynamic> newProperties) {
    return _DemoTableNode(id: id, children: children, columnCount: columnCount, metadata: {
      ...metadata,
      ...newProperties,
    });
  }

  @override
  DocumentNode copyAndReplaceMetadata(Map<String, dynamic> newMetadata) {
    return _DemoTableNode(id: id, children: children, columnCount: columnCount, metadata: newMetadata);
  }

  CompositeNode copyWithChildren(List<DocumentNode> newChildren) {
    return _DemoTableNode(
      id: id,
      metadata: metadata,
      children: newChildren,
      columnCount: columnCount,
    );
  }

  _DemoTableIndex getChildTableIndex(String childId) {
    final index = children.indexWhere((c) => c.id == childId);
    if (index == -1) {
      throw Exception('Unable to find child by id ${childId}');
    }
    return _DemoTableIndex.fromListIndex(index, columnCount);
  }

  DocumentNode getChildAtIndex(_DemoTableIndex index) {
    final listIndex = index.y * columnCount + index.x;
    if (listIndex < 0 || listIndex >= children.length) {
      throw Exception('Unable to find child for cell at index [${index.x}, ${index.y}]');
    }
    return children[listIndex];
  }
}

class _DemoTableIndex {
  final int x;
  final int y;
  _DemoTableIndex(this.x, this.y);

  factory _DemoTableIndex.fromListIndex(int index, int columnCount) {
    final y = (index / columnCount).floor();
    final x = index % columnCount;
    return _DemoTableIndex(x, y);
  }

  int toListIndex(int columnCount) {
    return y * columnCount + x;
  }

  @override
  String toString() {
    return 'TableIndex[$x, $y]';
  }
}

class _DemoTableCellNode extends CompositeNode {
  _DemoTableCellNode({
    required super.id,
    required this.children,
    Map<String, dynamic>? metadata,
  }) : super(
          metadata: {
            if (metadata != null) //
              ...metadata,
            NodeMetadata.blockType: demoTableCellBlockType,
          },
        );

  final List<DocumentNode> children;

  CompositeNode copyWithChildren(List<DocumentNode> newChildren) {
    return _DemoTableCellNode(id: id, metadata: metadata, children: newChildren);
  }

  @override
  DocumentNode copyAndReplaceMetadata(Map<String, dynamic> newMetadata) {
    return _DemoTableCellNode(id: id, children: children, metadata: newMetadata);
  }

  @override
  DocumentNode copyWithAddedMetadata(Map<String, dynamic> newProperties) {
    return _DemoTableCellNode(id: id, children: children, metadata: {...metadata, ...newProperties});
  }

  CompositeNode? resolveWhenChildrenAffected({
    required List<String> removedChildIds,
    required List<String> emptiedChildIds,
    required bool selectionFlowedThrough,
  }) {
    if (children.isEmpty) {
      return copyWithChildren([ParagraphNode(id: removedChildIds.last, text: AttributedText())]);
    }
    return this;
  }

  @override
  bool get isIsolating => true;
}

class _DemoTableCellViewModel extends CompositeNodeViewModel {
  _DemoTableCellViewModel({
    required super.nodeId,
    required super.children,
  });

  @override
  SingleColumnLayoutComponentViewModel copy() {
    return internalCopy(
      _DemoTableCellViewModel(
        nodeId: nodeId,
        children: children,
      ),
    );
  }
}

//////////////// COMPONENTS //////////////

class _DemoTableComponent extends StatefulWidget {
  final _MultipleCellsSelection? selection;
  final Color selectionColor;
  final Color? backgroundColor;
  const _DemoTableComponent({
    super.key,
    this.backgroundColor,
    this.selection,
    required this.selectionColor,
    required this.children,
    required this.columnsCount,
  });

  final List<CompositeComponentChild> children;
  final int columnsCount;

  @override
  State<_DemoTableComponent> createState() => _DemoTableComponentState();
}

class _DemoTableComponentState extends State<_DemoTableComponent> with CompositeComponent<_DemoTableComponent> {
  final _tableKey = GlobalKey();

  Rect? _selectionRect;
  BoxConstraints? _previousConstraints;

  @override
  void initState() {
    super.initState();
    updateSelectionRectAfterLayout();
  }

  @override
  void didUpdateWidget(covariant _DemoTableComponent oldWidget) {
    super.didUpdateWidget(oldWidget);
    updateSelectionRectAfterLayout();
  }

  void updateSelectionRectAfterLayout() {
    if (!useCellBasedSelection) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final newSelectionRect = _calcSelectionRect();
      if (_selectionRect != newSelectionRect) {
        setState(() {
          _selectionRect = newSelectionRect;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const selectionBorderWidth = 4.0;
    final selectionRect = this._selectionRect;
    return IgnorePointer(
      child: LayoutBuilder(builder: (context, constraints) {
        if (_previousConstraints != constraints) {
          _previousConstraints = constraints;
          updateSelectionRectAfterLayout();
        }
        return Stack(
          children: [
            if (selectionRect != null && widget.selection?.filled == true)
              Positioned.fromRect(
                rect: selectionRect.inflate(selectionBorderWidth / 2.0),
                child: ColoredBox(
                  color: widget.selectionColor.withAlpha(80),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(selectionBorderWidth / 2.0),
              child: Table(
                key: _tableKey,
                border: TableBorder.all(),
                children: _buildRows(),
              ),
            ),
            if (selectionRect != null)
              Positioned.fromRect(
                rect: selectionRect.inflate(selectionBorderWidth / 2.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(selectionBorderWidth)),
                    border: BoxBorder.fromBorderSide(
                      BorderSide(color: widget.selectionColor, width: selectionBorderWidth),
                    ),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  List<TableRow> _buildRows() {
    final result = <TableRow>[];
    final childIterator = widget.children.iterator;
    var hasNext = childIterator.moveNext();
    while (hasNext) {
      final rowWidgets = <Widget>[];
      for (var col = 0; col < widget.columnsCount; col += 1) {
        rowWidgets.add(
          TableCell(
            verticalAlignment: TableCellVerticalAlignment.top,
            child: childIterator.current.widget,
          ),
        );
        hasNext = childIterator.moveNext();
      }
      result.add(TableRow(children: rowWidgets));
    }
    return result;
  }

  Rect? _calcSelectionRect() {
    if (widget.selection == null) {
      return null;
    }
    final renderTable = _tableKey.currentContext?.findRenderObject() as RenderTable?;
    if (renderTable == null || renderTable.hasSize != true) {
      return null;
    }
    final rect = context.findRenderObject() as RenderBox;

    Rect? result;
    for (final nodeId in widget.selection!.selectedCells) {
      final index = widget.children.indexWhere((c) => c.nodeId == nodeId);
      final cellIndex = _DemoTableIndex.fromListIndex(index, widget.columnsCount);
      final cell = renderTable.row(cellIndex.y).elementAt(cellIndex.x);
      final rowHeight = renderTable.getRowBox(cellIndex.y).height;

      final origin = cell.localToGlobal(Offset.zero, ancestor: rect);
      final cellRect = Rect.fromLTWH(origin.dx, origin.dy, cell.size.width, rowHeight);

      if (result == null) {
        result = cellRect;
      } else {
        result = result.expandToInclude(cellRect);
      }
    }
    return result;
  }

  @override
  List<CompositeComponentChild> getChildren() {
    return widget.children;
  }

  bool displayCaretWithExpandedSelection(CompositeNodePosition position) {
    if (widget.selection?.filled == true) {
      return false;
    }
    return true;
  }

  CompositeComponentChild? getNextChildInDirection(String sinceChildId, DocumentNodeLookupDirection direction) {
    final children = getChildren();
    final index = children.indexWhere((c) => c.nodeId == sinceChildId);

    final cellIndex = _DemoTableIndex.fromListIndex(index, widget.columnsCount);

    _DemoTableIndex nextCellIndex;

    switch (direction) {
      case DocumentNodeLookupDirection.up:
        nextCellIndex = _DemoTableIndex(cellIndex.x, cellIndex.y - 1);
      case DocumentNodeLookupDirection.down:
        nextCellIndex = _DemoTableIndex(cellIndex.x, cellIndex.y + 1);
      case DocumentNodeLookupDirection.left:
        nextCellIndex = cellIndex.x > 0
            ? _DemoTableIndex(cellIndex.x - 1, cellIndex.y)
            : _DemoTableIndex(widget.columnsCount - 1, cellIndex.y - 1);
      case DocumentNodeLookupDirection.right:
        nextCellIndex = cellIndex.x < widget.columnsCount - 1
            ? _DemoTableIndex(cellIndex.x + 1, cellIndex.y)
            : _DemoTableIndex(0, cellIndex.y + 1);
    }

    final listIndex = nextCellIndex.toListIndex(widget.columnsCount);
    if (listIndex >= 0 && listIndex < children.length) {
      return children[listIndex];
    } else {
      return null;
    }
  }

  CompositeComponentChild getFirstChildInDirection(DocumentNodeLookupDirection direction, {double? nearX}) {
    _DemoTableIndex index;
    if (direction == DocumentNodeLookupDirection.up || direction == DocumentNodeLookupDirection.down) {
      final targetColumn = nearX != null ? getColumnIndexForX(nearX) : 0;
      if (direction == DocumentNodeLookupDirection.up) {
        index = _DemoTableIndex(targetColumn, rowsCount - 1);
      } else {
        index = _DemoTableIndex(targetColumn, 0);
      }
    } else {
      if (direction == DocumentNodeLookupDirection.left) {
        index = _DemoTableIndex(columnsCount - 1, rowsCount - 1);
      } else {
        index = _DemoTableIndex(0, 0);
      }
    }

    return getChildren()[index.toListIndex(columnsCount)];
  }

  @override
  CompositeComponentChild getChildForOffset(Offset componentOffset) {
    final renderObject = _tableKey.currentContext!.findRenderObject() as RenderTable;
    final rect = context.findRenderObject() as RenderBox;

    int rowIndex = 1;
    for (; rowIndex < renderObject.rows; rowIndex += 1) {
      final rowHeight = renderObject.getRowBox(rowIndex).height;
      final row = renderObject.row(rowIndex).first;
      final rowOffset = row.localToGlobal(Offset.zero, ancestor: rect);
      if (rowOffset.dy >= componentOffset.dy && componentOffset.dy < rowOffset.dy + rowHeight) {
        break;
      }
    }
    int columnIndex = 1;
    for (; columnIndex < renderObject.columns; columnIndex += 1) {
      final column = renderObject.column(columnIndex).first;
      final columnOffset = column.localToGlobal(Offset.zero, ancestor: rect);
      if (columnOffset.dx >= componentOffset.dx && componentOffset.dx < columnOffset.dx + column.size.width) {
        break;
      }
    }
    final listIndex = _DemoTableIndex(columnIndex - 1, rowIndex - 1).toListIndex(widget.columnsCount);
    return widget.children[listIndex];
  }

  int getColumnIndexForX(double x) {
    final renderTable = _tableKey.currentContext?.findRenderObject() as RenderTable?;
    if (renderTable != null && renderTable.rows > 0) {
      final firstRow = renderTable.row(0);
      var column = 0;
      var width = 0.0;
      for (final cell in firstRow) {
        width += cell.size.width;
        if (width > x) {
          return column;
        }
        column += 1;
      }
    }
    return 0;
  }

  int get columnsCount => widget.columnsCount;
  int get rowsCount => (getChildren().length / widget.columnsCount).floor();
}

(_DemoTableNode, _DemoTableCellNode)? _getTableNode(Document doc, String nodeId) {
  final path = doc.getNodePathById(nodeId)!;

  _DemoTableNode? table;
  _DemoTableCellNode? cell;
  for (final nodeId in path.reversed) {
    final node = doc.getNodeById(nodeId);
    if (node is _DemoTableCellNode) {
      cell = node;
    } else if (node is _DemoTableNode) {
      table = node;
    }
    if (cell != null && table != null) {
      return (table, cell);
    }
  }
  return null;
}

ExecutionInstruction tabToNextCell({
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
}) {
  if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) {
    return ExecutionInstruction.continueExecution;
  }

  if (keyEvent.logicalKey != LogicalKeyboardKey.tab) {
    return ExecutionInstruction.continueExecution;
  }
  final selection = editContext.composer.selection;
  if (selection == null) {
    return ExecutionInstruction.continueExecution;
  }
  if (selection.base.nodeId != selection.extent.nodeId) {
    return ExecutionInstruction.continueExecution;
  }

  final resolvedTable = _getTableNode(editContext.document, selection.base.nodeId);
  if (resolvedTable == null) {
    return ExecutionInstruction.continueExecution;
  }
  final (table, cell) = resolvedTable;

  final direction =
      HardwareKeyboard.instance.isShiftPressed ? DocumentNodeLookupDirection.left : DocumentNodeLookupDirection.right;

  DocumentNode? nextChild;

  final tableComponent = editContext.documentLayout.getComponentByNodeId(table.id) as CompositeComponent;
  final nextChildId = tableComponent.getNextChildInDirection(cell.id, direction)?.nodeId;
  if (nextChildId != null) {
    nextChild = editContext.document.getNodeById(nextChildId);
  }

  if (nextChild == null) {
    // We are in the first or last cell - interrupt execution
    return ExecutionInstruction.haltExecution;
  }

  editContext.editor.execute([
    ChangeSelectionRequest(
      DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: nextChild.id,
          nodePosition:
              direction == DocumentNodeLookupDirection.left ? nextChild.endPosition : nextChild.beginningPosition,
        ).toLeafPosition(),
      ),
      SelectionChangeType.pushCaret,
      SelectionReason.userInteraction,
    ),
  ]);

  return ExecutionInstruction.haltExecution;
}

/// This instruction does following:
/// if base and extent are inside table cell, and user press shift + arrow, and there
/// nothing to go inside Cell node, then it select next cell in desired direction (adjusting both base and extent
/// positions).
/// Also, if base is inside table and next extent position is outside table - adjusts base to rows and allows jumping outside
ExecutionInstruction shiftPlusArrowToSelectCellsInsideOrGoOutside({
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
}) {
  if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) {
    return ExecutionInstruction.continueExecution;
  }

  final arrows = {
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight
  };
  if (!arrows.contains(keyEvent.logicalKey)) {
    return ExecutionInstruction.continueExecution;
  }
  var selection = editContext.composer.selection;
  if (selection == null) {
    return ExecutionInstruction.continueExecution;
  }
  if (selection is AdjustedDocumentSelection) {
    selection = selection.original;
  }
  if (!HardwareKeyboard.instance.isShiftPressed) {
    return ExecutionInstruction.continueExecution;
  }

  final resolvedBaseTable = _getTableNode(editContext.document, selection.base.nodeId);
  final resolvedExtentTable = _getTableNode(editContext.document, selection.extent.nodeId);
  if (resolvedBaseTable == null) {
    return ExecutionInstruction.continueExecution;
  }

  final (table, baseCell) = resolvedBaseTable;
  var multiCellSelection = true;

  _DemoTableIndex extentIndex;
  DocumentComponent extentComponent;
  NodePosition extentPosition;
  if (resolvedExtentTable != null) {
    final (extentTable, extentCell) = resolvedExtentTable;
    multiCellSelection = baseCell.id != extentCell.id;
    extentIndex = table.getChildTableIndex(extentCell.id);
    extentComponent = editContext.documentLayout.getComponentByNodeId(extentCell.id)!;
    extentPosition = CompositeNodePosition.projectPositionIntoParent(
      extentCell.id,
      editContext.document.getNodePathById(selection.extent.nodeId)!,
      selection.extent.nodePosition,
    );
    if (extentTable.id != table.id) {
      return ExecutionInstruction.continueExecution;
    }
  } else {
    final isUpstream = editContext.document.getAffinityForSelection(selection) == TextAffinity.upstream;
    extentIndex = !isUpstream ? _DemoTableIndex(0, table.rowsCount) : _DemoTableIndex(0, -1);
    extentComponent = editContext.documentLayout.getComponentByNodeId(selection.extent.nodeId)!;
    extentPosition = selection.extent.nodePosition;
  }

  _DemoTableIndex? nextCellIndex;
  DocumentNodeLookupDirection? goOutsideTableDirection;

  if (keyEvent.logicalKey == LogicalKeyboardKey.arrowRight &&
      (extentComponent.movePositionRight(extentPosition) == null || multiCellSelection)) {
    if (extentIndex.x + 1 < table.columnCount) {
      nextCellIndex = _DemoTableIndex(extentIndex.x + 1, extentIndex.y);
    }
  }
  if (keyEvent.logicalKey == LogicalKeyboardKey.arrowLeft &&
      (extentComponent.movePositionLeft(extentPosition) == null || multiCellSelection)) {
    if (extentIndex.x - 1 >= 0) {
      nextCellIndex = _DemoTableIndex(extentIndex.x - 1, extentIndex.y);
    }
  }
  if (keyEvent.logicalKey == LogicalKeyboardKey.arrowDown &&
      (extentComponent.movePositionDown(extentPosition) == null || multiCellSelection)) {
    if (extentIndex.y + 1 < table.rowsCount) {
      nextCellIndex = _DemoTableIndex(extentIndex.x, extentIndex.y + 1);
    }
    goOutsideTableDirection = DocumentNodeLookupDirection.down;
  }
  if (keyEvent.logicalKey == LogicalKeyboardKey.arrowUp &&
      (extentComponent.movePositionUp(extentPosition) == null || multiCellSelection)) {
    if (extentIndex.y - 1 >= 0) {
      nextCellIndex = _DemoTableIndex(extentIndex.x, extentIndex.y - 1);
    }
    goOutsideTableDirection = DocumentNodeLookupDirection.up;
  }

  if (resolvedExtentTable == null) {
    // extent is outside table
    if (goOutsideTableDirection != null) {
      final nextNode = editContext.document.getNextSelectableNode(
        startingNode: editContext.document.getNodeById(selection.extent.nodeId)!,
        documentLayoutResolver: () => editContext.documentLayout,
        direction: goOutsideTableDirection,
      );
      // and next node is also outside table - continue execution
      if (nextNode == null || !editContext.document.getNodePathById(nextNode.id)!.contains(table.id)) {
        return ExecutionInstruction.continueExecution;
      }
    } else {
      // and user pressed left or right - continue
      return ExecutionInstruction.continueExecution;
    }
  }

  // Select multiple cells inside Table
  if (nextCellIndex != null) {
    var nextCell = table.getChildAtIndex(nextCellIndex);

    final adjustedCells = table.getSelectedChildrenBetween(baseCell.id, nextCell.id);
    final firstCell = table.getChildByNodeId(adjustedCells.first)!;
    final lastCell = table.getChildByNodeId(adjustedCells.last)!;

    final newSelection = DocumentSelection(
      base: DocumentPosition(
        nodeId: baseCell.id,
        nodePosition: baseCell.beginningPosition,
      ).toLeafPosition(),
      extent: DocumentPosition(
        nodeId: nextCell.id,
        nodePosition: nextCell.endPosition,
      ).toLeafPosition(),
    );

    final adjusted = AdjustedDocumentSelection(
      base: DocumentPosition(
        nodeId: firstCell.id,
        nodePosition: firstCell.beginningPosition,
      ).toLeafPosition(),
      extent: DocumentPosition(
        nodeId: lastCell.id,
        nodePosition: lastCell.endPosition,
      ).toLeafPosition(),
      original: newSelection,
    );

    editContext.editor.execute([
      ChangeSelectionRequest(
        adjusted,
        SelectionChangeType.pushCaret,
        SelectionReason.userInteraction,
      ),
    ]);
    return ExecutionInstruction.haltExecution;
  }

  // Next cell is out of bounds, so let's go outside table
  if (goOutsideTableDirection != null && resolvedExtentTable != null) {
    final goDown = goOutsideTableDirection == DocumentNodeLookupDirection.down;
    final nextNode = editContext.document.getNextSelectableNode(
      startingNode: table,
      documentLayoutResolver: () => editContext.documentLayout,
      direction: goOutsideTableDirection,
    );
    if (nextNode != null) {
      final newSelection = DocumentSelection(
        base: DocumentPosition(
          nodeId: baseCell.id,
          nodePosition: baseCell.beginningPosition,
        ).toLeafPosition(),
        extent: DocumentPosition(
          nodeId: nextNode.id,
          nodePosition: goDown ? nextNode.endPosition : nextNode.beginningPosition,
        ).toLeafPosition(),
      );
      final baseCellIndex = table.getChildTableIndex(baseCell.id);
      final firstCellIndex = _DemoTableIndex(goDown ? 0 : table.columnCount - 1, baseCellIndex.y);
      final firstCell = table.getChildAtIndex(firstCellIndex);
      final adjusted = AdjustedDocumentSelection(
        base: DocumentPosition(
          nodeId: firstCell.id,
          nodePosition: goDown ? firstCell.beginningPosition : firstCell.endPosition,
        ).toLeafPosition(),
        extent: newSelection.extent,
        original: newSelection,
      );
      editContext.editor.execute([
        ChangeSelectionRequest(
          adjusted,
          SelectionChangeType.pushCaret,
          SelectionReason.userInteraction,
        ),
      ]);
    }
    return ExecutionInstruction.haltExecution;
  }

  // Multiple cells selected inside table, and there is nowhere to go (for example
  // when user press left on first column) - stop execution to not corrupt selection inside cell.
  if (multiCellSelection) {
    return ExecutionInstruction.haltExecution;
  }

  return ExecutionInstruction.continueExecution;
}

/// If base is outside table and next node is inside table - adjust extent, so it rounded to rows
ExecutionInstruction shiftPlusArrowThroughTableToSelectByRow({
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
}) {
  if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) {
    return ExecutionInstruction.continueExecution;
  }

  final arrows = {
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight
  };
  if (!arrows.contains(keyEvent.logicalKey)) {
    return ExecutionInstruction.continueExecution;
  }
  var selection = editContext.composer.selection;
  if (selection == null) {
    return ExecutionInstruction.continueExecution;
  }
  if (selection is AdjustedDocumentSelection) {
    selection = selection.original;
  }
  if (!HardwareKeyboard.instance.isShiftPressed) {
    return ExecutionInstruction.continueExecution;
  }

  final resolvedBaseTable = _getTableNode(editContext.document, selection.base.nodeId);
  final extentTable = _getTableNode(editContext.document, selection.extent.nodeId);

  if (resolvedBaseTable != null) {
    // we are inside table - continue
    return ExecutionInstruction.continueExecution;
  }

  final baseNode = editContext.document.getNodeById(selection.base.nodeId)!;
  final extentNode = editContext.document.getNodeById(selection.extent.nodeId)!;
  final extentComponent = editContext.documentLayout.getComponentByNodeId(selection.extent.nodeId)!;

  final selectionThroughTable = extentTable != null;

  if ({LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.arrowRight}.contains(keyEvent.logicalKey)) {
    if (selectionThroughTable) {
      return ExecutionInstruction.haltExecution;
    }
    return ExecutionInstruction.continueExecution;
  }

  // Arrow down, but can go within leaf node (and no selection between table and non table)
  if (keyEvent.logicalKey == LogicalKeyboardKey.arrowDown &&
      (extentComponent.movePositionDown(selection.extent.nodePosition) != null) &&
      !selectionThroughTable) {
    return ExecutionInstruction.continueExecution;
  }

  // Arrow up, but can go within leaf node (and no selection between table and non table)
  if (keyEvent.logicalKey == LogicalKeyboardKey.arrowUp &&
      (extentComponent.movePositionUp(selection.extent.nodePosition) != null) &&
      !selectionThroughTable) {
    return ExecutionInstruction.continueExecution;
  }

  final goUp = keyEvent.logicalKey == LogicalKeyboardKey.arrowUp;

  DocumentNode? newExtentNode;
  bool? isUpstream;

  if (extentTable != null) {
    // When selection starts before or after table and ends inside table, then user press shift+arrow
    final (table, extentCell) = extentTable;
    isUpstream = editContext.document.getAffinityBetweenNodes(baseNode, extentCell) != TextAffinity.downstream;

    final cellIndex = table.getChildTableIndex(extentCell.id);
    final nextCellIndex = _DemoTableIndex(isUpstream ? 0 : table.columnCount - 1, cellIndex.y + (goUp ? -1 : 1));

    if (nextCellIndex.y >= table.rowsCount || nextCellIndex.y < 0) {
      newExtentNode = editContext.document.getNextSelectableNode(
        startingNode: table,
        documentLayoutResolver: () => editContext.documentLayout,
        direction: goUp ? DocumentNodeLookupDirection.up : DocumentNodeLookupDirection.down,
      );
    } else {
      if (resolvedBaseTable == null) {
        newExtentNode = table.getChildAtIndex(nextCellIndex);
      }
    }
    if (newExtentNode == null) {
      // The extent is inside table
      return ExecutionInstruction.haltExecution;
    }
  } else {
    final nodeAfterExtent = editContext.document.getNextSelectableNode(
      startingNode: extentNode,
      documentLayoutResolver: () => editContext.documentLayout,
      direction: goUp ? DocumentNodeLookupDirection.up : DocumentNodeLookupDirection.down,
    );
    if (nodeAfterExtent != null) {
      isUpstream = editContext.document.getAffinityBetweenNodes(baseNode, nodeAfterExtent) != TextAffinity.downstream;
      final nodeAfterExtentTable = _getTableNode(editContext.document, nodeAfterExtent.id);
      if (nodeAfterExtentTable != null && resolvedBaseTable == null) {
        final (table, cell) = nodeAfterExtentTable;
        final cellIndex = table.getChildTableIndex(cell.id);
        final nextCellIndex = _DemoTableIndex(isUpstream ? 0 : table.columnCount - 1, cellIndex.y);
        newExtentNode = table.getChildAtIndex(nextCellIndex);
      }
    }
  }

  if (newExtentNode != null) {
    final nextExtent = DocumentPosition(
      nodeId: newExtentNode.id,
      nodePosition: isUpstream! ? newExtentNode.beginningPosition : newExtentNode.endPosition,
    ).toLeafPosition();
    editContext.editor.execute([
      ChangeSelectionRequest(
        DocumentSelection(base: selection.base, extent: nextExtent),
        SelectionChangeType.pushCaret,
        SelectionReason.userInteraction,
      ),
    ]);
    return ExecutionInstruction.haltExecution;
  }

  return ExecutionInstruction.continueExecution;
}
