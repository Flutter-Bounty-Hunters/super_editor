import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/infrastructure/content_layers.dart';

/// A [ContentLayerStatelessWidget] that expects a content layer [Element] that
/// implements [DocumentLayout].
///
/// {@template document_layout_layer}
/// When working with documents, there might be any number of layers that need to
/// inspect the document layout. Each layer could manually locate the associated
/// [DocumentLayout], but to remove that repeated effort, this widget finds and
/// provides the [DocumentLayout] to its subclasses, so the subclasses can focus
/// on inspecting that layout.
/// {@endtemplate}
abstract class DocumentLayoutLayerStatelessWidget extends ContentLayerStatelessWidget {
  const DocumentLayoutLayerStatelessWidget({super.key});

  @override
  Widget doBuild(BuildContext context, Element? contentElement, RenderObject? contentLayout) {
    if (contentElement == null || contentElement is! StatefulElement || contentElement.state is! DocumentLayout) {
      return const SizedBox();
    }

    return buildWithDocumentLayout(context, contentElement.state as DocumentLayout);
  }

  @protected
  Widget buildWithDocumentLayout(BuildContext context, DocumentLayout documentLayout);
}

/// A [ContentLayerStatefulWidget] that expects a content layer [Element] that
/// implements [DocumentLayout].
///
/// {@macro document_layout_layer}
abstract class DocumentLayoutLayerStatefulWidget extends ContentLayerStatefulWidget {
  const DocumentLayoutLayerStatefulWidget({super.key});

  @override
  DocumentLayoutLayerState<ContentLayerStatefulWidget, dynamic> createState();
}

abstract class DocumentLayoutLayerState<WidgetType extends ContentLayerStatefulWidget, LayoutDataType>
    extends ContentLayerState<WidgetType, LayoutDataType> {
  @override
  LayoutDataType? computeLayoutData(Element? contentElement, RenderObject? contentLayout) {
    if (contentElement == null || contentElement is! StatefulElement || contentElement.state is! DocumentLayout) {
      return null;
    }

    return computeLayoutDataWithDocumentLayout(context, contentElement, contentElement.state as DocumentLayout);
  }

  @protected
  LayoutDataType? computeLayoutDataWithDocumentLayout(
      BuildContext contentLayersContext, BuildContext documentContext, DocumentLayout documentLayout);
}
