import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/src/core/styles.dart';
import 'package:super_editor/src/default_editor/layout_single_column/selection_aware_viewmodel.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';

import '../core/document.dart';
import 'box_component.dart';
import 'layout_single_column/layout_single_column.dart';

/// [DocumentNode] for a horizontal rule, which represents a full-width
/// horizontal separation in a document.
@immutable
class HorizontalRuleNode extends BlockNode {
  HorizontalRuleNode({
    required this.id,
    super.metadata,
  }) {
    initAddToMetadata({"blockType": horizontalRuleBlockType});
  }

  @override
  final String id;

  @override
  String? copyContent(dynamic selection) {
    if (selection is! UpstreamDownstreamNodeSelection) {
      throw Exception('HorizontalRuleNode can only copy content from a UpstreamDownstreamNodeSelection.');
    }

    return !selection.isCollapsed ? '---' : null;
  }

  @override
  bool hasEquivalentContent(DocumentNode other) {
    return other is HorizontalRuleNode;
  }

  @override
  DocumentNode copyWithAddedMetadata(Map<String, dynamic> newProperties) {
    return HorizontalRuleNode(
      id: id,
      metadata: {
        ...metadata,
        ...newProperties,
      },
    );
  }

  @override
  DocumentNode copyAndReplaceMetadata(Map<String, dynamic> newMetadata) {
    return HorizontalRuleNode(id: id, metadata: newMetadata);
  }

  @override
  HorizontalRuleNode copy() {
    return HorizontalRuleNode(id: id);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is HorizontalRuleNode && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

const horizontalRuleBlockType = NamedAttribution("horizontalRule");

class HorizontalRuleComponentBuilder implements ComponentBuilder {
  const HorizontalRuleComponentBuilder();

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(
      PresenterContext context, Document document, DocumentNode node) {
    if (node is! HorizontalRuleNode) {
      return null;
    }

    return HorizontalRuleComponentViewModel(
      nodeId: node.id,
      createdAt: node.metadata[NodeMetadata.createdAt],
      selectionColor: const Color(0x00000000),
      caretColor: const Color(0x00000000),
    );
  }

  @override
  Widget? createComponent(
      SingleColumnDocumentComponentContext componentContext, SingleColumnLayoutComponentViewModel componentViewModel) {
    if (componentViewModel is! HorizontalRuleComponentViewModel) {
      return null;
    }

    return HorizontalRuleComponent(
      componentKey: componentContext.componentKey,
      color: componentViewModel.color,
      selection: componentViewModel.selection?.nodeSelection as UpstreamDownstreamNodeSelection?,
      selectionColor: componentViewModel.selectionColor,
      showCaret: componentViewModel.caret != null,
      caretColor: componentViewModel.caretColor,
      opacity: componentViewModel.opacity,
    );
  }
}

class HorizontalRuleComponentViewModel extends SingleColumnLayoutComponentViewModel with SelectionAwareViewModelMixin {
  HorizontalRuleComponentViewModel({
    required super.nodeId,
    super.createdAt,
    super.maxWidth,
    super.padding = EdgeInsets.zero,
    super.opacity = 1.0,
    this.color = Colors.grey,
    DocumentNodeSelection? selection,
    Color selectionColor = Colors.transparent,
    this.caret,
    required this.caretColor,
  }) {
    super.selection = selection;
    super.selectionColor = selectionColor;
  }

  Color color;

  UpstreamDownstreamNodePosition? caret;
  Color caretColor;

  @override
  void applyStyles(Map<String, dynamic> styles) {
    super.applyStyles(styles);

    color = styles[Styles.backgroundColor] ?? Colors.grey;
  }

  @override
  HorizontalRuleComponentViewModel copy() {
    return HorizontalRuleComponentViewModel(
      nodeId: nodeId,
      createdAt: createdAt,
      maxWidth: maxWidth,
      padding: padding,
      opacity: opacity,
      color: color,
      selection: selection,
      selectionColor: selectionColor,
      caret: caret,
      caretColor: caretColor,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is HorizontalRuleComponentViewModel &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          createdAt == other.createdAt &&
          color == other.color &&
          selection == other.selection &&
          selectionColor == other.selectionColor &&
          caret == other.caret &&
          caretColor == other.caretColor;

  @override
  int get hashCode =>
      super.hashCode ^
      nodeId.hashCode ^
      createdAt.hashCode ^
      color.hashCode ^
      selection.hashCode ^
      selectionColor.hashCode ^
      caret.hashCode ^
      caretColor.hashCode;
}

/// Displays a horizontal rule in a document.
class HorizontalRuleComponent extends StatelessWidget {
  const HorizontalRuleComponent({
    Key? key,
    required this.componentKey,
    required this.color,
    this.thickness = 1,
    this.selectionColor = Colors.blue,
    this.selection,
    required this.caretColor,
    this.showCaret = false,
    this.opacity = 1.0,
  }) : super(key: key);

  final GlobalKey componentKey;
  final Color color;
  final double thickness;
  final Color selectionColor;
  final UpstreamDownstreamNodeSelection? selection;
  final Color caretColor;
  final bool showCaret;

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SelectableBox(
        selection: selection,
        selectionColor: selectionColor,
        child: BoxComponent(
          key: componentKey,
          opacity: opacity,
          child: Divider(
            color: color,
            thickness: thickness,
          ),
        ),
      ),
    );
  }
}
