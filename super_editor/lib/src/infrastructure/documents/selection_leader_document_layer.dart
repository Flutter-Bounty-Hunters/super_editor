import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/infrastructure/content_layers.dart';
import 'package:super_editor/src/infrastructure/documents/document_layers.dart';

/// A document layer that positions leader widgets at the user's selection bounds.
///
/// A collapsed selection has a single leader where the caret should appear. An expanded
/// selection has a leader at both sides of the selection, as well as a leader that spans
/// the entire expanded selection. Leader width is always `1` and leader height is based
/// on the document's self-reported caret height for the given document position.
///
/// When no selection exists, no leaders are built in the layer's widget tree.
class SelectionLeadersDocumentLayer extends DocumentLayoutLayerStatefulWidget {
  const SelectionLeadersDocumentLayer({
    Key? key,
    required this.document,
    required this.selection,
    required this.links,
    this.showDebugLeaderBounds = false,
  }) : super(key: key);

  /// The editor's [Document], which is used to find the start and end of
  /// the user's expanded selection.
  final Document document;

  /// The current user's selection within a document.
  final ValueListenable<DocumentSelection?> selection;

  /// Collections of [LayerLink]s, which are given to leader widgets that are
  /// positioned at the selection bounds, and around the full selection.
  final SelectionLayerLinks links;

  /// Whether to paint colorful bounds around the leader widgets, for debugging purposes.
  final bool showDebugLeaderBounds;

  @override
  DocumentLayoutLayerState<ContentLayerStatefulWidget, DocumentSelectionLayout> createState() =>
      _SelectionLeadersDocumentLayerState();
}

class _SelectionLeadersDocumentLayerState
    extends DocumentLayoutLayerState<SelectionLeadersDocumentLayer, DocumentSelectionLayout>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();

    widget.selection.addListener(_onSelectionChange);
  }

  @override
  void didUpdateWidget(SelectionLeadersDocumentLayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.selection != oldWidget.selection) {
      oldWidget.selection.removeListener(_onSelectionChange);
      widget.selection.addListener(_onSelectionChange);
    }
  }

  @override
  void dispose() {
    widget.selection.removeListener(_onSelectionChange);

    super.dispose();
  }

  void _onSelectionChange() {
    if (mounted && SchedulerBinding.instance.schedulerPhase != SchedulerPhase.persistentCallbacks) {
      // The Flutter pipeline isn't running. Schedule a re-build and re-position the caret.
      setState(() {
        // The leaders are positioned in the build() call.
      });
    }
  }

  /// Updates the caret rect, immediately, without scheduling a rebuild.
  @override
  DocumentSelectionLayout? computeLayoutDataWithDocumentLayout(
      BuildContext contentLayersContext, BuildContext documentContext, DocumentLayout documentLayout) {
    final documentSelection = widget.selection.value;
    if (documentSelection == null) {
      return null;
    }

    final selectedComponent = documentLayout.getComponentByNodeId(widget.selection.value!.extent.nodeId);
    if (selectedComponent == null) {
      // Assume that we're in a momentary transitive state where the document layout
      // just gained or lost a component. We expect this method ot run again in a moment
      // to correct for this.
      return null;
    }

    if (documentSelection.isCollapsed) {
      return DocumentSelectionLayout(
        caret: documentLayout.getRectForPosition(documentSelection.extent)!,
      );
    } else {
      return DocumentSelectionLayout(
        upstream: documentLayout.getRectForPosition(
          widget.document.selectUpstreamPosition(documentSelection.base, documentSelection.extent),
        )!,
        downstream: documentLayout.getRectForPosition(
          widget.document.selectDownstreamPosition(documentSelection.base, documentSelection.extent),
        )!,
        expandedSelectionBounds: documentLayout.getRectForSelection(
          documentSelection.base,
          documentSelection.extent,
        ),
      );
    }
  }

  @override
  Widget doBuild(BuildContext context, DocumentSelectionLayout? selectionLayout) {
    if (selectionLayout == null) {
      return const SizedBox();
    }

    return IgnorePointer(
      child: Stack(
        children: [
          if (selectionLayout.caret != null)
            Positioned(
              top: selectionLayout.caret!.top,
              left: selectionLayout.caret!.left,
              width: 1,
              height: selectionLayout.caret!.height,
              child: Leader(
                link: widget.links.caretLink,
                child: widget.showDebugLeaderBounds
                    ? DecoratedBox(
                        decoration: BoxDecoration(border: Border.all(width: 4, color: const Color(0xFFFF0000))),
                      )
                    : null,
              ),
            ),
          if (selectionLayout.upstream != null)
            Positioned(
              top: selectionLayout.upstream!.top,
              left: selectionLayout.upstream!.left,
              width: 1,
              height: selectionLayout.upstream!.height,
              child: Leader(
                link: widget.links.upstreamLink,
                child: widget.showDebugLeaderBounds
                    ? DecoratedBox(
                        decoration: BoxDecoration(border: Border.all(width: 4, color: const Color(0xFF00FF00))),
                      )
                    : null,
              ),
            ),
          if (selectionLayout.downstream != null)
            Positioned(
              top: selectionLayout.downstream!.top,
              left: selectionLayout.downstream!.left,
              width: 1,
              height: selectionLayout.downstream!.height,
              child: Leader(
                link: widget.links.downstreamLink,
                child: widget.showDebugLeaderBounds
                    ? DecoratedBox(
                        decoration: BoxDecoration(border: Border.all(width: 4, color: const Color(0xFF0000FF))),
                      )
                    : null,
              ),
            ),
          if (selectionLayout.expandedSelectionBounds != null)
            Positioned.fromRect(
              rect: selectionLayout.expandedSelectionBounds!,
              child: Leader(
                link: widget.links.expandedSelectionBoundsLink,
                child: widget.showDebugLeaderBounds
                    ? DecoratedBox(
                        decoration: BoxDecoration(border: Border.all(width: 4, color: const Color(0xFFFF00FF))),
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

/// Visual layout bounds related to a user selection in a document, such as the
/// caret rect, a bounding box around all selected content, etc.
class DocumentSelectionLayout {
  DocumentSelectionLayout({
    this.caret,
    this.upstream,
    this.downstream,
    this.expandedSelectionBounds,
  });

  final Rect? caret;
  final Rect? upstream;
  final Rect? downstream;
  final Rect? expandedSelectionBounds;
}

/// A collection of [LayerLink]s that should be positioned near important
/// visual selection locations, such as at the caret position.
class SelectionLayerLinks {
  SelectionLayerLinks({
    LeaderLink? caretLink,
    LeaderLink? upstreamLink,
    LeaderLink? downstreamLink,
    LeaderLink? expandedSelectionBoundsLink,
  }) {
    this.caretLink = caretLink ?? LeaderLink();
    this.upstreamLink = upstreamLink ?? LeaderLink();
    this.downstreamLink = downstreamLink ?? LeaderLink();
    this.expandedSelectionBoundsLink = expandedSelectionBoundsLink ?? LeaderLink();
  }

  /// [LayerLink] that's connected to a rectangle at the collapsed selection caret
  /// position.
  late final LeaderLink caretLink;

  /// [LayerLink] that's connected to a rectangle at the expanded selection upstream
  /// position.
  late final LeaderLink upstreamLink;

  /// [LayerLink] that's connected to a rectangle at the expanded selection downstream
  /// position.
  late final LeaderLink downstreamLink;

  /// [LayerLink] that's connected to a rectangle that bounds the entire expanded
  /// selection, from the top of upstream to the bottom of downstream.
  late final LeaderLink expandedSelectionBoundsLink;
}
