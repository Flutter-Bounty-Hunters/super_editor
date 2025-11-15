import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/default_editor/layout_single_column/_presenter.dart';
import 'package:super_editor/src/default_editor/layout_single_column/column_component.dart';

class TableNode extends DocumentNode {
  TableNode({
    required this.id,
    this.flowDirection = TableFlowDirection.horizontalThenVertical,
    required this.cells,
  });

  @override
  final String id;

  final TableFlowDirection flowDirection;

  /// All cells in this table, keyed by row -> column -> cell index
  final List<List<List<DocumentNode>>> cells;

  int get rowCount => cells.length;

  int get columnCount => cells.first.length;

  @override
  NodePosition get beginningPosition => TableNodePosition(
        row: 0,
        column: 0,
        nodeId: cells[0][0][0].id,
        nodePosition: cells[0][0][0].beginningPosition,
      );

  @override
  NodePosition get endPosition => TableNodePosition(
        row: cells.length - 1,
        column: cells.last.length - 1,
        nodeId: cells.last.last.last.id,
        nodePosition: cells.last.last.last.endPosition,
      );

  @override
  bool containsPosition(Object position) {
    if (position is! TableNodePosition) {
      return false;
    }

    if (position.row < 0 || position.row >= rowCount) {
      return false;
    }

    if (position.column < 0 || position.column >= columnCount) {
      return false;
    }

    return true;
  }

  @override
  NodePosition selectUpstreamPosition(NodePosition position1, NodePosition position2) {
    if (position1 is! TableNodePosition) {
      throw Exception('Expected a TableNodePosition for position1 but received a ${position1.runtimeType}');
    }
    if (position2 is! TableNodePosition) {
      throw Exception('Expected a TableNodePosition for position2 but received a ${position2.runtimeType}');
    }

    if (position1.row != position2.row) {
      return position1.row < position2.row ? position1 : position2;
    }

    if (position1.column != position2.column) {
      return position1.column < position2.column ? position1 : position2;
    }

    // Both positions sit in the same cell. Report order based on position in child list.
    final cellNodes = cells[position1.row][position1.column];

    final position1Node = cellNodes.firstWhereOrNull((node) => node.id == position1.nodeId);
    final position1Index = position1Node != null ? cellNodes.indexOf(position1Node) : -1;

    final position2Node = cellNodes.firstWhereOrNull((node) => node.id == position2.nodeId);
    final position2Index = position2Node != null ? cellNodes.indexOf(position2Node) : -1;

    return position1Index <= position2Index ? position1 : position2;
  }

  @override
  NodePosition selectDownstreamPosition(NodePosition position1, NodePosition position2) {
    final upstream = selectUpstreamPosition(position1, position2);
    return upstream == position1 ? position2 : position1;
  }

  @override
  NodeSelection computeSelection({required NodePosition base, required NodePosition extent}) {
    // TODO: implement computeSelection
    throw UnimplementedError();
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
    // TODO: implement copyContent
    throw UnimplementedError();
  }
}

enum TableFlowDirection {
  verticalThenHorizontal,
  horizontalThenVertical;
}

class TableNodeSelection implements NodeSelection {
  const TableNodeSelection.collapsed(TableNodePosition position)
      : base = position,
        extent = position;

  factory TableNodeSelection.inCell({
    required int row,
    required int column,
    required String baseNodeId,
    required NodePosition baseNodePosition,
    required String extentNodeId,
    required NodePosition extentNodePosition,
  }) {
    return TableNodeSelection(
      base: TableNodePosition(
        row: row,
        column: column,
        nodeId: baseNodeId,
        nodePosition: baseNodePosition,
      ),
      extent: TableNodePosition(
        row: row,
        column: column,
        nodeId: extentNodeId,
        nodePosition: extentNodePosition,
      ),
    );
  }

  const TableNodeSelection({
    required this.base,
    required this.extent,
  });

  final TableNodePosition base;

  final TableNodePosition extent;
}

class TableNodePosition implements NodePosition {
  const TableNodePosition({
    required this.row,
    required this.column,
    required this.nodeId,
    required this.nodePosition,
  });

  final int row;
  final int column;
  final String nodeId;
  final NodePosition nodePosition;

  @override
  bool isEquivalentTo(NodePosition other) {
    if (other is! TableNodePosition) {
      return false;
    }

    return row == other.row && //
        column == other.column &&
        nodeId == other.nodeId &&
        nodePosition == other.nodePosition;
  }
}

class TableComponentBuilder implements ComponentBuilder {
  @override
  SingleColumnLayoutComponentViewModel? createViewModel(
    PresenterContext context,
    Document document,
    DocumentNode node,
  ) {
    if (node is! TableNode) {
      return null;
    }

    return TableComponentViewModel(
        nodeId: node.id,
        createdAt: node.metadata[NodeMetadata.createdAt],
        // Create view models for every node within every cell in the table.
        cells: node.cells
            // For each row.
            .map((row) => row
                // For each column.
                .map((column) => column
                    // For each node in the cell.
                    .map(
                      // Create a View Model for the node.
                      (node) => context.createViewModel(node),
                    )
                    .nonNulls
                    .toList(growable: false))
                .toList(growable: false))
            .toList(growable: false));
  }

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! TableComponentViewModel) {
      return null;
    }

    return TableDocumentComponent(
      viewModel: componentViewModel,
      componentBuilder: componentContext.buildChildComponent,
    );
  }
}

class TableComponentViewModel extends SingleColumnLayoutComponentViewModel {
  TableComponentViewModel({
    required super.nodeId,
    required super.createdAt,
    super.padding = EdgeInsets.zero,
    required this.cells,
  });

  // Keyed as cells[row][col].
  final List<List<List<SingleColumnLayoutComponentViewModel>>> cells;

  @override
  SingleColumnLayoutComponentViewModel copy() {
    // TODO: implement copy
    throw UnimplementedError();
  }
}

class TableDocumentComponent extends StatefulWidget {
  const TableDocumentComponent({
    super.key,
    required this.viewModel,
    required this.componentBuilder,
  });

  final TableComponentViewModel viewModel;

  // TODO: Consider moving this behavior into an InheritedWidget that we place in the document layout
  final Widget? Function(SingleColumnLayoutComponentViewModel viewModel) componentBuilder;

  @override
  State<TableDocumentComponent> createState() => _TableDocumentComponentState();
}

class _TableDocumentComponentState extends State<TableDocumentComponent> {
  @override
  Widget build(BuildContext context) {
    return Table(
      children: [
        for (int row = 0; row < widget.viewModel.cells.length; row += 1) //
          TableRow(
            children: _buildRow(row),
          ),
      ],
    );
  }

  List<Widget> _buildRow(int rowIndex) {
    return widget //
        .viewModel
        .cells[rowIndex]
        .map((cell) => _buildCell(cell))
        .toList(growable: false);
  }

  Widget _buildCell(List<SingleColumnLayoutComponentViewModel> cell) {
    // TODO: pass needed stuff to the column component.
    return ColumnDocumentComponent();
  }
}
