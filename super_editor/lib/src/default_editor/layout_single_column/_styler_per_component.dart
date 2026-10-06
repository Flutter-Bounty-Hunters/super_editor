import 'package:flutter/painting.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

import '../../core/document.dart';
import '_presenter.dart';

/// [SingleColumnLayoutStylePhase] that applies custom styling to specific
/// components.
///
/// Each per-component style should be defined within a [SingleColumnLayoutComponentStyles]
/// and then stored within the given [DocumentNode]'s metadata.
///
/// Every time a [DocumentNode]'s metadata changes, this phase needs to re-run so
/// that it picks up any style related changes. Given that the entire style pipeline
/// re-runs every time the document changes, this phase automatically runs at the
/// appropriate time.
class SingleColumnLayoutCustomComponentStyler extends SingleColumnLayoutStylePhase {
  SingleColumnLayoutCustomComponentStyler();

  /// Restyles the changed components: each one's styles come from its node.
  @override
  SingleColumnLayoutViewModel styleChanges(
    Document document,
    SingleColumnLayoutViewModel viewModel, {
    required SingleColumnLayoutViewModel previousOutput,
    required Set<String> changedNodeIds,
  }) {
    return restyleOnly(
      viewModel,
      nodeIds: changedNodeIds,
      previousOutput: previousOutput,
      styleComponent: (component) => _applyLayoutStyles(
        document.getNodeById(component.nodeId)!,
        component.copy(),
      ),
    );
  }

  @override
  SingleColumnLayoutViewModel style(Document document, SingleColumnLayoutViewModel viewModel) {
    editorStyleLog.info("(Re)calculating custom component styles view model for document layout");
    return SingleColumnLayoutViewModel(
      padding: viewModel.padding,
      componentViewModels: [
        for (final previousViewModel in viewModel.componentViewModels)
          _applyLayoutStyles(
            document.getNodeById(previousViewModel.nodeId)!,
            previousViewModel.copy(),
          ),
      ],
    );
  }

  SingleColumnLayoutComponentViewModel _applyLayoutStyles(
    DocumentNode node,
    SingleColumnLayoutComponentViewModel viewModel,
  ) {
    final componentStyles = SingleColumnLayoutComponentStyles.fromMetadata(node);

    viewModel
      ..maxWidth = componentStyles.width ?? viewModel.maxWidth
      ..padding = componentStyles.padding ?? viewModel.padding;

    return viewModel;
  }
}

class SingleColumnLayoutComponentStyles {
  static const _metadataKey = "singleColumnLayout";
  static const _widthKey = "width";
  static const _paddingKey = "padding";

  factory SingleColumnLayoutComponentStyles.fromMetadata(DocumentNode node) {
    return SingleColumnLayoutComponentStyles(
      width: node.metadata[_metadataKey]?[_widthKey],
      padding: node.metadata[_metadataKey]?[_paddingKey],
    );
  }

  const SingleColumnLayoutComponentStyles({
    this.width,
    this.padding,
  });

  final double? width;
  final EdgeInsetsGeometry? padding;

  Map<String, dynamic> toMetadata() => {
        _metadataKey: {
          _widthKey: width,
          _paddingKey: padding,
        },
      };

  SingleColumnLayoutComponentStyles copyWith({
    double? width,
    EdgeInsetsGeometry? padding,
  }) {
    return SingleColumnLayoutComponentStyles(
      width: width ?? this.width,
      padding: padding ?? this.padding,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SingleColumnLayoutComponentStyles &&
          runtimeType == other.runtimeType &&
          width == other.width &&
          padding == other.padding;

  @override
  int get hashCode => width.hashCode ^ padding.hashCode;
}
