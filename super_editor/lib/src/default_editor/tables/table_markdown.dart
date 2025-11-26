import 'package:attributed_text/attributed_text.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/styles.dart';
import 'package:super_editor/src/default_editor/box_component.dart';
import 'package:super_editor/src/default_editor/layout_single_column/layout_single_column.dart';
import 'package:super_editor/src/default_editor/layout_single_column/selection_aware_viewmodel.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';
import 'package:super_editor/src/default_editor/tables/table_block.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/attributed_text_styles.dart';
import 'package:super_editor/src/infrastructure/scrolling/desktop_mouse_wheel_and_trackpad_scrolling.dart';
import 'package:super_text_layout/super_text_layout.dart';

/// Builds [MarkdownTableViewModel]s and [MarkdownTableComponent]s for every [TableBlockNode]
/// in a document.
///
/// The [MarkdownTableComponent] uses block level selection, which means that the table is either
/// fully selected or not selected at all, i.e., there is no selection of individual cells.
///
/// See [TableStyles] for the styles that can be applied to the table through a [Stylesheet].
class MarkdownTableComponentBuilder implements ComponentBuilder {
  const MarkdownTableComponentBuilder({
    this.columnWidth = const IntrinsicColumnWidth(),
    this.fit = TableComponentFit.scale,
  });

  final TableColumnWidth columnWidth;
  final TableComponentFit fit;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! TableBlockNode) {
      return null;
    }

    return MarkdownTableViewModel(
      nodeId: node.id,
      createdAt: node.metadata[NodeMetadata.createdAt],
      padding: EdgeInsets.zero,
      columnWidth: columnWidth,
      fit: fit,
      cells: [
        for (int i = 0; i < node.rowCount; i += 1) //
          [
            for (final cell in node.getRow(i))
              MarkdownTableCellViewModel(
                nodeId: cell.id,
                createdAt: cell.metadata[NodeMetadata.createdAt],
                text: cell.text,
                textAlign: cell.getMetadataValue(TextNodeMetadata.textAlign) ?? TextAlign.left,
                textStyleBuilder: noStyleBuilder,
                padding: const EdgeInsets.all(8.0),
                //       ^ Default padding, can be overridden through the stylesheet.
                metadata: cell.metadata,
              )
          ],
      ],
      selectionColor: const Color(0x00000000),
      caretColor: const Color(0x00000000),
    );
  }

  @override
  Widget? createComponent(
      SingleColumnDocumentComponentContext componentContext, SingleColumnLayoutComponentViewModel componentViewModel) {
    if (componentViewModel is! MarkdownTableViewModel) {
      return null;
    }

    return MarkdownTableComponent(
      componentKey: componentContext.componentKey,
      viewModel: componentViewModel,
      // selection: componentViewModel.selection?.nodeSelection as UpstreamDownstreamNodeSelection?,
      // selectionColor: componentViewModel.selectionColor,
      // showCaret: componentViewModel.selection != null,
      // caretColor: componentViewModel.caretColor,
      // opacity: componentViewModel.opacity,
    );
  }
}

/// View model that configures the appearance of a [MarkdownTableComponent].
///
/// View models move through various style phases, which fill out
/// various properties in the view model. For example, one phase applies
/// all [StyleRule]s, and another phase configures content selection
/// and caret appearance.
class MarkdownTableViewModel extends SingleColumnLayoutComponentViewModel with SelectionAwareViewModelMixin {
  MarkdownTableViewModel({
    required super.nodeId,
    required super.createdAt,
    super.maxWidth,
    required super.padding,
    super.opacity,
    required this.cells,
    this.border,
    this.columnWidth = const IntrinsicColumnWidth(),
    this.fit = TableComponentFit.scale,
    this.inlineWidgetBuilders = const [],
    required this.caretColor,
    DocumentNodeSelection? selection,
    Color selectionColor = Colors.transparent,
  }) {
    super.selection = selection;
    super.selectionColor = selectionColor;
  }

  /// The cells of the table, indexed as `[rowIndex][columnIndex]`.
  ///
  /// The first row is considered the header row.
  ///
  /// The remaining rows are considered to be data rows.
  final List<List<MarkdownTableCellViewModel>> cells;

  /// The border to draw around the table and its cells.
  ///
  /// Configurable through [TableStyles.border].
  TableBorder? border;

  /// The policy that sizes the width of each column in the table.
  TableColumnWidth columnWidth;

  /// How the table responds when it wants to be wider than the available width.
  TableComponentFit fit;

  /// A chain of builders that create inline widgets that can be embedded
  /// inside the table's cells.
  InlineWidgetBuilderChain inlineWidgetBuilders;

  /// The color to use when painting the caret.
  Color caretColor;

  @override
  SingleColumnLayoutComponentViewModel copy() {
    return MarkdownTableViewModel(
      nodeId: nodeId,
      createdAt: createdAt,
      maxWidth: maxWidth,
      padding: padding,
      opacity: opacity,
      cells: [
        for (final row in cells) //
          row.map((e) => e.copy()).toList(),
      ],
      border: border,
      columnWidth: columnWidth,
      fit: fit,
      inlineWidgetBuilders: inlineWidgetBuilders,
      caretColor: caretColor,
      selection: selection,
      selectionColor: selectionColor,
    );
  }

  @override
  void applyStyles(Map<String, dynamic> styles) {
    super.applyStyles(styles);

    if (cells.isEmpty) {
      // There is no cell, so we're not rendering anything. Fizzle.
      return;
    }

    border = styles[TableStyles.border] as TableBorder? ?? border;
    inlineWidgetBuilders = styles[Styles.inlineWidgetBuilders] ?? inlineWidgetBuilders;
    final inlineTextStyler = styles[Styles.inlineTextStyler] as AttributionStyleAdjuster;

    final baseTextStyle = (styles[Styles.textStyle] ?? noStyleBuilder({})) as TextStyle;
    final headerTextStyles = styles[TableStyles.headerTextStyle] as TextStyle?;
    final cellDecorator = styles[TableStyles.cellDecorator] as TableCellDecorator?;

    EdgeInsets cellPadding = const EdgeInsets.all(0);
    final cascadingPadding = styles[TableStyles.cellPadding] as CascadingPadding?;
    if (cascadingPadding != null) {
      cellPadding = cascadingPadding.toEdgeInsets();
    }

    // Apply the styles to the header.
    final headerRow = cells[0];
    for (int i = 0; i < headerRow.length; i += 1) {
      final headerCell = headerRow[i];
      // Applies the header text style on top of the base style.
      headerCell.textStyleBuilder = (attributions) {
        return inlineTextStyler(
          attributions,
          headerTextStyles != null //
              ? baseTextStyle.merge(headerTextStyles)
              : baseTextStyle,
        );
      };
      headerCell.padding = cellPadding;
      headerCell.decoration = cellDecorator?.call(
            rowIndex: 0,
            columnIndex: i,
            cellText: headerCell.text,
            cellMetadata: headerCell.metadata,
          ) ??
          const BoxDecoration();
    }

    // Apply the styles to the data rows.
    for (int i = 1; i < cells.length; i += 1) {
      final dataRow = cells[i];
      for (int j = 0; j < dataRow.length; j += 1) {
        final dataCell = dataRow[j];
        dataCell.textStyleBuilder = (attributions) {
          return inlineTextStyler(attributions, baseTextStyle);
        };
        dataCell.padding = cellPadding;
        dataCell.decoration = cellDecorator?.call(
              rowIndex: i,
              columnIndex: j,
              cellText: dataCell.text,
              cellMetadata: dataCell.metadata,
            ) ??
            const BoxDecoration();
      }
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarkdownTableViewModel &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          createdAt == other.createdAt &&
          maxWidth == other.maxWidth &&
          padding == other.padding &&
          opacity == other.opacity &&
          caretColor == other.caretColor &&
          selection == other.selection &&
          selectionColor == other.selectionColor &&
          border == other.border &&
          columnWidth == other.columnWidth &&
          fit == other.fit &&
          const DeepCollectionEquality().equals(cells, other.cells);

  @override
  int get hashCode =>
      nodeId.hashCode ^
      createdAt.hashCode ^
      maxWidth.hashCode ^
      padding.hashCode ^
      opacity.hashCode ^
      caretColor.hashCode ^
      selection.hashCode ^
      selectionColor.hashCode ^
      border.hashCode ^
      columnWidth.hashCode ^
      fit.hashCode ^
      cells.hashCode;
}

enum TableComponentFit {
  scroll,
  scale;
}

/// View model that configures the appearance of a [MarkdownTableComponent]'s cell.
class MarkdownTableCellViewModel extends SingleColumnLayoutComponentViewModel {
  MarkdownTableCellViewModel({
    required super.nodeId,
    required this.text,
    this.textAlign = TextAlign.left,
    this.textStyleBuilder = noStyleBuilder,
    required super.padding,
    this.decoration,
    required this.metadata,
    required super.createdAt,
  });

  final AttributedText text;
  TextAlign textAlign;
  AttributionStyleBuilder textStyleBuilder;
  BoxDecoration? decoration;
  Map<String, dynamic> metadata;

  @override
  MarkdownTableCellViewModel copy() {
    return MarkdownTableCellViewModel(
      nodeId: nodeId,
      createdAt: createdAt,
      text: text,
      textAlign: textAlign,
      textStyleBuilder: textStyleBuilder,
      padding: padding,
      decoration: decoration,
      metadata: Map<String, dynamic>.from(metadata),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarkdownTableCellViewModel &&
          runtimeType == other.runtimeType &&
          super == other &&
          text == other.text &&
          textAlign == other.textAlign &&
          padding == other.padding &&
          decoration == other.decoration &&
          const DeepCollectionEquality().equals(metadata, other.metadata);

  @override
  int get hashCode =>
      super.hashCode ^ //
      text.hashCode ^
      textAlign.hashCode ^
      padding.hashCode ^
      decoration.hashCode ^
      metadata.hashCode;
}

/// A component that displays a read-only table with block level selection.
///
/// A block level selection means that the table is either fully selected or not selected at all,
/// i.e., there is no selection of individual cells.
///
/// Table components support two sizing properties:
///  * [viewModel.columnWidth]: How to size every column, using the standard Flutter `Table` property.
///  * [viewModel.fit]: Whether to shrink the table to fit the width, or to scroll horizontally
///
/// It is the responsibility of the user to ensure that `columnWidth` and `fit` do not conflict with
/// each other, such as a column width that takes up a percentage space, while setting the fit to scroll,
/// which would be a layout error.
class MarkdownTableComponent extends StatefulWidget {
  const MarkdownTableComponent({
    super.key,
    required this.componentKey,
    required this.viewModel,
  });

  final GlobalKey componentKey;
  final MarkdownTableViewModel viewModel;

  @override
  State<MarkdownTableComponent> createState() => _MarkdownTableComponentState();
}

class _MarkdownTableComponentState extends State<MarkdownTableComponent> {
  final _scrollController = ScrollController();

  @override
  dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.viewModel.fit) {
      TableComponentFit.scroll => SingleAxisTrackpadAndWheelScroller(
          axis: Axis.horizontal,
          controller: _scrollController,
          child: Center(
            child: _ScrollbarWithoutGap(
              scrollController: _scrollController,
              scrollbarOrientation: ScrollbarOrientation.bottom,
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: _buildTableComponent(
                  table: _buildTable(context),
                ),
              ),
            ),
          ),
        ),
      TableComponentFit.scale => _buildTableComponent(
          table: _buildTableToScaleDown(
            table: _buildTable(context),
          ),
        ),
    };
  }

  Widget _buildTableComponent({
    required Widget table,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      hitTestBehavior: HitTestBehavior.translucent,
      //               ^ Without `HitTestBehavior.translucent` the `MouseRegion` seems to be stealing
      //                 the pointer events, making it impossible to place the caret.
      child: IgnorePointer(
        //   ^ Without `IgnorePointer` gestures like taping to place the caret or double tapping
        //     to select the whole table don't work. The `SelectableBox` seems to be stealing
        //     the pointer events.
        child: SelectableBox(
          selection: widget.viewModel.selection?.nodeSelection is UpstreamDownstreamNodeSelection
              ? widget.viewModel.selection?.nodeSelection as UpstreamDownstreamNodeSelection
              : null,
          selectionColor: widget.viewModel.selectionColor,
          child: BoxComponent(
            key: widget.componentKey,
            opacity: widget.viewModel.opacity,
            child: table,
          ),
        ),
      ),
    );
  }

  Widget _buildTableToScaleDown({
    required Widget table,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return FittedBox(
          fit: BoxFit.scaleDown,
          //  ^ Shrink to fit when the table is wider than the viewport.
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth,
              // ^ Expand to fill when the table is narrower than the viewport.
            ),
            child: _buildTable(context),
          ),
        );
      },
    );
  }

  Widget _buildTable(BuildContext context) {
    return Table(
      border: widget.viewModel.border ?? TableBorder.all(),
      defaultColumnWidth: widget.viewModel.columnWidth,
      children: [
        for (int i = 0; i < widget.viewModel.cells.length; i += 1) //
          _buildRow(context, widget.viewModel.cells[i], i),
      ],
    );
  }

  TableRow _buildRow(BuildContext context, List<MarkdownTableCellViewModel> row, int rowIndex) {
    return TableRow(
      children: [
        for (final cell in row) //
          _buildCell(context, cell),
      ],
    );
  }

  Widget _buildCell(
    BuildContext context,
    MarkdownTableCellViewModel cell,
  ) {
    return DecoratedBox(
      decoration: cell.decoration ?? const BoxDecoration(),
      child: Padding(
        padding: cell.padding,
        child: SuperText(
          richText: cell.text.computeInlineSpan(
            context,
            cell.textStyleBuilder,
            widget.viewModel.inlineWidgetBuilders,
          ),
          textAlign: cell.textAlign,
        ),
      ),
    );
  }
}

/// Scrollbar that internally fixes a dumb Flutter gap bug.
///
/// Some Flutter genius thought it was a good idea for all scrollbars in all locations to
/// inset themselves by the `MediaQuery` padding. This adds gaps between scrollbars and their
/// viewport in almost every location because most uses aren't full-screen.
///
/// Issue ticket: https://github.com/flutter/flutter/issues/150544
class _ScrollbarWithoutGap extends StatelessWidget {
  const _ScrollbarWithoutGap({
    required this.scrollController,
    required this.scrollbarOrientation,
    required this.child,
  });

  final ScrollController scrollController;
  final ScrollbarOrientation scrollbarOrientation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      removeBottom: true,
      removeLeft: true,
      removeRight: true,
      child: Scrollbar(
        controller: scrollController,
        scrollbarOrientation: scrollbarOrientation,
        child: MediaQuery(
          data: MediaQuery.of(context),
          child: child,
        ),
      ),
    );
  }
}

/// A function that decorates a table row.
///
/// Can be used, for example, to apply alternating background colors to rows.
///
/// The header row has [rowIndex] 0, the first data row has [rowIndex] 1, and so on.
///
/// Returning `null` means that no decoration is applied to the row.
typedef TableRowDecorator = BoxDecoration? Function({
  required int rowIndex,
});

/// A function that decorates a table cell.
///
/// The header row has [rowIndex] 0, the first data row has [rowIndex] 1, and so on.
///
/// Returning `null` means that no decoration is applied to the cell, which means
/// the decoration of the row is applied, if any.
typedef TableCellDecorator = BoxDecoration? Function({
  required int rowIndex,
  required int columnIndex,
  required AttributedText cellText,
  required Map<String, dynamic> cellMetadata,
});

/// The default styles that are applied to a table through a [Stylesheet].
///
/// Applies a border around the entire table and each cell, a bold text style to the header row,
/// and padding to each cell.
final markdownTableStyles = StyleRule(
  BlockSelector(tableBlockAttribution.name),
  (document, node) {
    if (node is! TableBlockNode) {
      return {};
    }

    return {
      Styles.padding: const CascadingPadding.only(top: 24),
      TableStyles.headerTextStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        color: Colors.black,
      ),
      TableStyles.cellPadding: const CascadingPadding.all(4.0),
      TableStyles.border: TableBorder.all(color: Colors.grey, width: 1),
    };
  },
);

/// The keys to the style metadata used to style a table.
class TableStyles {
  /// Applies a [TextStyle] to the cells of the header row.
  static const String headerTextStyle = 'tableHeaderTextStyle';

  /// Applies a [TableBorder] to the table.
  static const String border = 'tableBorder';

  /// Applies a [TableCellDecorator] to each cell in the table.
  ///
  /// A [TableCellDecorator] is applied after the [TableStyles.rowDecorator],
  /// which means that the cell decorator can paint the cell with a different
  /// background color than its parent row.
  static const String cellDecorator = 'tableCellDecorator';

  /// Applies padding to each cell in the table.
  static const String cellPadding = 'tableCellPadding';
}
