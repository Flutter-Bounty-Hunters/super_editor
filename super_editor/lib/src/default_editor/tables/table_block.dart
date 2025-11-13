import 'package:attributed_text/attributed_text.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/default_editor/box_component.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';
import 'package:super_editor/src/default_editor/text.dart';

/// A [DocumentNode] that represents a read-only block table.
///
/// Being a block node means that the table is either fully selected or not selected at all,
/// i.e., there is no selection of individual cells.
@immutable
class TableBlockNode extends BlockNode {
  /// Creates a [TableBlockNode] with the given [cells].
  ///
  /// The [cells] grid is indexed as `cells[row][column]`.
  TableBlockNode({
    required this.id,
    required List<List<TextNode>> cells,
    super.metadata,
  }) : _cells = List.from(cells.map((row) => List<TextNode>.from(row))) {
    initAddToMetadata({NodeMetadata.blockType: tableBlockAttribution});
  }

  @override
  final String id;

  final List<List<TextNode>> _cells;

  int get rowCount => _cells.length;
  int get columnCount => _cells.isEmpty ? 0 : _cells[0].length;

  List<TextNode> getRow(int index) {
    if (index < 0 || index >= _cells.length) {
      throw RangeError.range(index, 0, _cells.length - 1, 'index');
    }
    return UnmodifiableListView(_cells[index]);
  }

  List<TextNode> getColumn(int index) {
    if (_cells.isEmpty || index < 0 || index >= _cells[0].length) {
      throw RangeError.range(index, 0, _cells[0].length - 1, 'index');
    }
    return UnmodifiableListView(_cells.map((row) => row[index]));
  }

  TextNode getCell({
    required int rowIndex,
    required int columnIndex,
  }) {
    if (rowIndex < 0 || rowIndex >= _cells.length) {
      throw RangeError.range(rowIndex, 0, _cells.length - 1, 'rowIndex');
    }
    final row = _cells[rowIndex];
    if (columnIndex < 0 || columnIndex >= row.length) {
      throw RangeError.range(columnIndex, 0, row.length - 1, 'cellIndex');
    }
    return row[columnIndex];
  }

  @override
  DocumentNode copyAndReplaceMetadata(Map<String, dynamic> newMetadata) {
    return TableBlockNode(
      id: id,
      metadata: newMetadata,
      cells: _cells,
    );
  }

  @override
  DocumentNode copyWithAddedMetadata(Map<String, dynamic> newProperties) {
    return TableBlockNode(
      id: id,
      cells: _cells,
      metadata: {
        ...metadata,
        ...newProperties,
      },
    );
  }

  @override
  String? copyContent(NodeSelection selection) {
    if (selection is! UpstreamDownstreamNodeSelection) {
      // We don't know how to handle this selection type.
      return null;
    }
    if (selection.isCollapsed) {
      // This selection doesn't include the table - it's a collapsed selection
      // either on the upstream or downstream edge.
      return null;
    }

    final buffer = StringBuffer();
    for (int i = 0; i < _cells.length; i++) {
      final row = _cells[i];
      if (i > 0) {
        // Separate rows with a newline.
        buffer.writeln('');
      }

      for (int j = 0; j < row.length; j++) {
        final cell = row[j];
        if (j > 0) {
          // Separate cells with a tab.
          buffer.write('\t');
        }

        buffer.write(cell.text.toPlainText(includePlaceholders: false));
      }
    }
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TableBlockNode &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          metadata == other.metadata &&
          const DeepCollectionEquality().equals(_cells, other._cells);

  @override
  int get hashCode => id.hashCode ^ _cells.hashCode ^ metadata.hashCode;
}

const tableBlockAttribution = NamedAttribution("tableBlock");
const tableHeaderAttribution = NamedAttribution("tableHeader");
