import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

import '../../core/document.dart';
import '_presenter.dart';

/// [SingleColumnLayoutStylePhase] that draws an underline beneath the text in the IME's
/// composing region.
class SingleColumnLayoutComposingRegionStyler extends SingleColumnLayoutStylePhase {
  SingleColumnLayoutComposingRegionStyler({
    required Document document,
    required ValueListenable<DocumentRange?> composingRegion,
    required bool showComposingUnderline,
  })  : _document = document,
        _composingRegion = composingRegion,
        _showComposingRegionUnderline = showComposingUnderline {
    // Our styles need to be re-applied whenever the composing region changes.
    _composingRegion.addListener(markDirty);
  }

  @override
  void dispose() {
    _composingRegion.removeListener(markDirty);
    super.dispose();
  }

  final Document _document;
  final ValueListenable<DocumentRange?> _composingRegion;
  final bool _showComposingRegionUnderline;

  @override
  SingleColumnLayoutViewModel style(Document document, SingleColumnLayoutViewModel viewModel) {
    editorStyleLog.info("(Re)calculating composing region view model for document layout");
    final documentComposingRegion = _composingRegion.value;
    if (documentComposingRegion == null) {
      // There's nothing for us to style if there's no composing region. Return the
      // view model as-is.
      return viewModel;
    }
    if (!_showComposingRegionUnderline) {
      // No underline is desired for the composing region. Return the view model as-is.
      return viewModel;
    }

    return SingleColumnLayoutViewModel(
      padding: viewModel.padding,
      componentViewModels: [
        for (final previousViewModel in viewModel.componentViewModels) //
          _applyComposingRegion(previousViewModel, documentComposingRegion),
      ],
    );
  }

  SingleColumnLayoutComponentViewModel _applyComposingRegion(
    SingleColumnLayoutComponentViewModel viewModel,
    DocumentRange documentComposingRegion,
  ) {
    final node = _document.getNodeById(viewModel.nodeId)!;
    if (node is! TextNode) {
      // An IME composing region is only relevant for text nodes. Do nothing to this component's viewmodel.
      return viewModel;
    }
    if (viewModel is! TextComponentViewModel) {
      // All components for TextNode's should be of type TextComponentViewModel, but we check
      // just to be sure. In this case, it's not, for some reason. We can only style
      // TextComponentViewModel's. Do nothing to this view model.
      return viewModel;
    }

    TextRange? textComposingRegion;
    if (documentComposingRegion.start.nodeId == documentComposingRegion.end.nodeId &&
        documentComposingRegion.start.nodeId == node.id) {
      // There's a composing region and it's entirely within this text node.
      // TODO: handle the possibility of a composing region extending across multiple nodes.
      final startPosition = documentComposingRegion.start.nodePosition as TextNodePosition;
      final endPosition = documentComposingRegion.end.nodePosition as TextNodePosition;
      textComposingRegion = TextRange(start: startPosition.offset, end: endPosition.offset);
    }

    if (textComposingRegion == null) {
      // The composing region isn't in this node, so there's nothing to underline. Return the
      // view model as-is, so that it stays equal to its last one, and the layout doesn't
      // rebuild this component when a composing region starts or ends somewhere else.
      return viewModel;
    }

    editorStyleLog.fine("Applying composing region styles to node: ${node.id}");

    return (viewModel.copy() as TextComponentViewModel)
      ..composingRegion = textComposingRegion
      ..showComposingRegionUnderline = true;
  }
}
