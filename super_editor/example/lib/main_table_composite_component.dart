import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
              ])
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
      ),
    );
  }
}

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

  @override
  DocumentNode copyWithAddedMetadata(Map<String, dynamic> newProperties) {
    // TODO: implement copyWithAddedMetadata
    throw UnimplementedError();
  }

  @override
  DocumentNode copyAndReplaceMetadata(Map<String, dynamic> newMetadata) {
    // TODO: implement copyAndReplaceMetadata
    throw UnimplementedError();
  }

  @override
  String? copyContent(NodeSelection selection) {
    final compositeSelection = selection;
    if (compositeSelection is! CompositeNodeSelection) {
      throw Exception('Unexpected selection type ${compositeSelection.runtimeType}');
    }
    // Maybe this should go to base class, so we only have to override the case when more than one
    // child node in the selection?
    if (compositeSelection.extent.childNodeId == compositeSelection.base.childNodeId) {
      final child = getChildByNodeId(compositeSelection.extent.childNodeId)!;
      final childSelection = child.computeSelection(
        base: compositeSelection.base.childNodePosition,
        extent: compositeSelection.extent.childNodePosition,
      );
      return child.copyContent(childSelection);
    }
    throw UnimplementedError('Copy more than one child node is not yet implemented');
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
    // TODO: implement copyAndReplaceMetadata
    throw UnimplementedError();
  }

  @override
  String? copyContent(NodeSelection selection) {
    // TODO: implement copyContent
    throw UnimplementedError();
  }

  @override
  DocumentNode copyWithAddedMetadata(Map<String, dynamic> newProperties) {
    // TODO: implement copyWithAddedMetadata
    throw UnimplementedError();
  }
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
    return getChildForCell(columnIndex - 1, rowIndex - 1);
  }

  CompositeComponentChild getChildForCell(int col, int row) {
    return widget.children[row * widget.columnsCount + col];
  }
}
