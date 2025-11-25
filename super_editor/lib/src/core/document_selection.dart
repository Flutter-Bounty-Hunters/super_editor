import 'dart:math';
import 'dart:ui';

import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/super_editor.dart';

import 'document.dart';

/// A selection within a [Document].
///
/// A [DocumentSelection] spans from a [base] position to an
/// [extent] position, and includes all content in between.
///
/// [base] and [extent] are instances of [DocumentPosition],
/// which represents a single position within a [Document].
///
/// A [DocumentSelection] does not hold a reference to a
/// [Document], it only represents a directional selection
/// within a [Document]. The [base] and [extent] positions must
/// be interpreted within the context of a specific [Document]
/// to locate nodes between [base] and [extent], and to identify
/// partial content that is selected within the [base] and [extent]
/// nodes within the document.
class DocumentSelection extends DocumentRange {
  /// Creates a collapsed selection at the given [position] within the document.
  ///
  /// See also:
  ///
  ///  * [isCollapsed], which determines whether a selection is collapsed or
  ///    not.
  const DocumentSelection.collapsed({
    required DocumentPosition position,
  })  : base = position,
        extent = position,
        super(start: position, end: position);

  /// Creates a selection from the [base] position to the [extent] position
  /// within the document.
  const DocumentSelection({
    required this.base,
    required this.extent,
  }) : super(start: base, end: extent);

  /// The base position of the selection within the document.
  ///
  /// If [base] equals [extent], the selection is collapsed.
  ///
  /// If [base] comes before [extent], the selection is expanded in the
  /// downstream direction.
  ///
  /// If [base] comes after [extent], the selection is expanded in the upstream
  /// direction.
  final DocumentPosition base;

  /// The extent position of the selection within the document.
  ///
  /// If [extent] equals [base], the selection is collapsed.
  ///
  /// If [extent] comes after [base], the selection is expanded in the
  /// downstream direction.
  ///
  /// If [extent] comes before [base], the selection is expanded in the upstream
  /// direction.
  final DocumentPosition extent;

  /// Returns `true` if this selection is collapsed, or `false` if this
  /// selection is expanded.
  ///
  /// A [DocumentSelection] is "collapsed" when its [base] and [extent] are
  /// equivalent. Otherwise, the [DocumentSelection] is "expanded".
  bool get isCollapsed => base.nodeId == extent.nodeId && base.nodePosition.isEquivalentTo(extent.nodePosition);

  /// Returns the affinity (direction) for this selection - downstream refers to a selection
  /// that starts at earlier content and ends at later content, upstream refers to a selection
  /// that starts at later content and ends at earlier content.
  ///
  /// Calculating the selection affinity requires a [Document] because only the [Document] knows the
  /// relative position of various [DocumentPosition]s.
  TextAffinity calculateAffinity(Document document) => document.getAffinityBetween(base: base, extent: extent);

  /// Returns `true` if this selection has an affinity of [TextAffinity.downstream].
  ///
  /// See [calculateAffinity] for more info.
  bool hasDownstreamAffinity(Document document) => calculateAffinity(document) == TextAffinity.downstream;

  /// Returns `true` if this selection has an affinity of [TextAffinity.upstream].
  ///
  /// See [calculateAffinity] for more info.
  bool hasUpstreamAffinity(Document document) => calculateAffinity(document) == TextAffinity.upstream;

  @override
  String toString() {
    if (base.nodeId == extent.nodeId) {
      final basePosition = base.nodePosition;
      final extentPosition = extent.nodePosition;
      if (basePosition is TextNodePosition && extentPosition is TextNodePosition) {
        if (basePosition.offset == extentPosition.offset) {
          return "[Selection] - ${base.nodeId}: ${extentPosition.offset}";
        }

        return "[Selection] - ${base.nodeId}: [${basePosition.offset}, ${extentPosition.offset}]";
      }

      return "[Selection] - ${base.nodeId}: [${base.nodePosition}, ${extent.nodePosition}]";
    }

    return '[DocumentSelection] - \n  base: ($base),\n  extent: ($extent)';
  }

  /// Returns a version of this that is collapsed at the [extent] position.
  ///
  /// Note, the returned [DocumentSelection] is collapsed at this selection's
  /// [extent], regardless of whether this selection's [extent] comes before or
  /// after its [base].
  ///
  /// See also:
  ///
  ///  * [isCollapsed], which determines whether a selection is collapsed or
  ///    not.
  ///  * [collapseUpstream], which collapses the selection in the upstream
  ///    direction relative to the document.
  ///  * [collapseDownstream], which collapses the selection in the downstream
  ///    direction relative to the document.
  DocumentSelection collapse() {
    if (isCollapsed) {
      return this;
    } else {
      return DocumentSelection(
        base: extent,
        extent: extent,
      );
    }
  }

  /// Returns a version of this [DocumentSelection] that is collapsed
  /// in the upstream (start) direction.
  ///
  /// The source [Document] is required so that the upstream [DocumentPosition]
  /// can be selected from [base] and [extent].
  ///
  /// See also:
  ///
  ///  * [isCollapsed], which determines whether a selection is collapsed or
  ///    not.
  ///  * [collapseDownstream], which collapses the selection in the downstream
  ///    direction relative to the document.
  ///  * [collapse], which collapses the selection to the extent position.
  DocumentSelection collapseUpstream(Document document) {
    if (isCollapsed) {
      // The selection is already collapsed. Therefore, the collapsed
      // version of this selection is the same as this selection.
      return this;
    }

    final selectionAffinity = document.getAffinityForSelection(this);
    return selectionAffinity == TextAffinity.downstream //
        ? DocumentSelection.collapsed(position: base)
        : DocumentSelection.collapsed(position: extent);
  }

  /// Returns a version of this [DocumentSelection] that is collapsed
  /// in the downstream (end) direction.
  ///
  /// The source [Document] is required so that the downstream [DocumentPosition]
  /// can be selected from [base] and [extent].
  ///
  /// See also:
  ///
  ///  * [isCollapsed], which determines whether a selection is collapsed or
  ///    not.
  ///  * [collapseUpstream], which collapses the selection in the upstream
  ///    direction relative to the document.
  ///  * [collapse], which collapses the selection to the extent position.
  DocumentSelection collapseDownstream(Document document) {
    if (isCollapsed) {
      // The selection is already collapsed. Therefore, the collapsed
      // version of this selection is the same as this selection.
      return this;
    }

    final selectionAffinity = document.getAffinityForSelection(this);
    return selectionAffinity == TextAffinity.downstream //
        ? DocumentSelection.collapsed(position: extent)
        : DocumentSelection.collapsed(position: base);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentSelection && runtimeType == other.runtimeType && base == other.base && extent == other.extent;

  @override
  int get hashCode => base.hashCode ^ extent.hashCode;

  /// Creates a new [DocumentSelection] based on the current selection, with the
  /// provided parameters overridden.
  DocumentSelection copyWith({
    DocumentPosition? base,
    DocumentPosition? extent,
  }) {
    return DocumentSelection(
      base: base ?? this.base,
      extent: extent ?? this.extent,
    );
  }

  /// Creates a copy of this selection but with the [extent] expanded to the
  /// given new extent.
  ///
  /// This is like calling [copyWith] with the [newExtent] as the new value for
  /// the extent.
  DocumentSelection expandTo(DocumentPosition newExtent) {
    return copyWith(
      extent: newExtent,
    );
  }
}

/// A span within a [Document] with one side bounded at [start] and the other
/// side bounded at [end].
///
/// A [DocumentRange] is considered "normalized" if [start] comes before [end].
/// A [DocumentRange] is NOT "normalized" if [end] comes before [start].
///
/// To check if a [DocumentRange] is normalized, call [isNormalized] with
/// a [Document].
///
/// Use [normalize] to create a version of this [DocumentRange] that's guaranteed
/// to be normalized for the given [Document].
///
/// Determining normalization requires a [Document] because a [Document] is the
/// source of truth for [DocumentNode] content order.
class DocumentRange {
  /// Creates a document range between [start] and [end].
  const DocumentRange({
    required this.start,
    required this.end,
  });

  /// The bounding position of one side of a [DocumentRange].
  ///
  /// {@template start_and_end}
  /// If this [DocumentRange] is normalized then [start] comes before [end], otherwise
  /// [end] comes before [start].
  /// {@endtemplate}
  final DocumentPosition start;

  /// The bounding position of the other side of a [DocumentRange].
  ///
  /// {@macro start_and_end}
  final DocumentPosition end;

  /// Returns `true` if this range is collapsed, e.g., it starts and ends
  /// at the sample place.
  bool get isCollapsed => start == end;

  /// Returns `true` if [start] appears at, or before [end], or `false` otherwise.
  bool isNormalized(Document document) => document.getAffinityForRange(this) == TextAffinity.downstream;

  /// Returns a version of this [DocumentRange] that's normalized.
  ///
  /// See [isNormalized] for a definition of normalized.
  DocumentRange normalize(Document document) {
    if (isNormalized(document)) {
      return this;
    }

    // We're not normalized. To return a normalized version, reverse our bounds.
    return DocumentRange(start: end, end: start);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentRange && runtimeType == other.runtimeType && start == other.start && end == other.end;

  @override
  int get hashCode => start.hashCode ^ end.hashCode;

  @override
  String toString() {
    if (start.nodeId == end.nodeId) {
      final startPosition = start.nodePosition;
      final endPosition = end.nodePosition;
      if (startPosition is TextNodePosition && endPosition is TextNodePosition) {
        if (startPosition.offset == endPosition.offset) {
          return "[Range] - ${start.nodeId}: ${endPosition.offset}";
        }

        return "[Range] - ${start.nodeId}: [${startPosition.offset}, ${endPosition.offset}]";
      }

      return "[Range] - ${start.nodeId}: [${start.nodePosition}, ${end.nodePosition}]";
    }

    return '[Range] - \n  start: ($start),\n  end: ($end)';
  }
}

extension InspectDocumentAffinity on Document {
  TextAffinity getAffinityForSelection(DocumentSelection selection) {
    return getAffinityBetween(base: selection.base, extent: selection.extent);
  }

  TextAffinity getAffinityForRange(DocumentRange range) {
    return getAffinityBetween(base: range.start, extent: range.end);
  }

  TextAffinity getAffinityBetweenNodes(DocumentNode base, DocumentNode extent) {
    return getAffinityForSelection(
      DocumentSelection(
        base: DocumentPosition(
          nodeId: base.id,
          nodePosition: base.beginningPosition,
        ),
        extent: DocumentPosition(
          nodeId: extent.id,
          nodePosition: extent.beginningPosition,
        ),
      ),
    );
  }

  /// Returns the affinity direction implied by the given [base] and [extent].
  // TODO: Replace TextAffinity with a DocumentAffinity to avoid confusion.
  TextAffinity getAffinityBetween({
    required DocumentPosition base,
    required DocumentPosition extent,
  }) {
    late TextAffinity affinity;
    if (base.nodeId != extent.nodeId) {
      final basePath = getNodePathById(base.nodeId);
      if (basePath == null) {
        throw Exception('No such position in document: $base');
      }
      final extentPath = getNodePathById(extent.nodeId);
      if (extentPath == null) {
        throw Exception('No such position in document: $extent');
      }

      return getAffinityBetweenPaths(basePath, extentPath);
    } else {
      final extentNode = getNode(extent);
      if (extentNode == null) {
        throw Exception('No such position in document: $extent');
      }
      // The selection is within the same node. Ask the node which position
      // comes first.
      affinity = extentNode.getAffinityBetween(base: base.nodePosition, extent: extent.nodePosition);
    }

    return affinity;
  }

  TextAffinity getAffinityBetweenPaths(NodePath basePath, NodePath extentPath) {
    final (baseDivergingChild, extentDivergingChild) = basePath.divergingChildrenWith(extentPath);

    return getNodeIndexInParentByPath(baseDivergingChild) < getNodeIndexInParentByPath(extentDivergingChild)
        ? TextAffinity.downstream
        : TextAffinity.upstream;
  }
}

extension InspectDocumentRange on Document {
  /// Returns a [DocumentRange] that ranges from [position1] to [position2],
  /// including [position1] and [position2].
  DocumentRange getRangeBetween(DocumentPosition position1, DocumentPosition position2) {
    late TextAffinity affinity = getAffinityBetween(base: position1, extent: position2);
    return DocumentRange(
      start: affinity == TextAffinity.downstream ? position1 : position2,
      end: affinity == TextAffinity.downstream ? position2 : position1,
    );
  }
}

extension InspectDocumentSelection on Document {
  /// Returns a list of all the `DocumentNodes` within the given [selection], ordered
  /// from upstream to downstream.
  List<DocumentNode> getNodesInContentOrder(DocumentSelection selection) {
    final upstreamPosition = selectUpstreamPosition(selection.base, selection.extent);
    final downstreamPosition = selectDownstreamPosition(selection.base, selection.extent);

    return getNodesInside(upstreamPosition, downstreamPosition);
  }

  /// Given [docPosition1] and [docPosition2], returns the `DocumentPosition` that
  /// appears first in the document.
  DocumentPosition selectUpstreamPosition(DocumentPosition docPosition1, DocumentPosition docPosition2) {
    if (docPosition1.nodeId != docPosition2.nodeId) {
      final affinity = getAffinityBetween(base: docPosition1, extent: docPosition2);
      return affinity == TextAffinity.downstream //
          ? docPosition1
          : docPosition2;
    }

    // Both document positions are in the same node. Figure out which
    // node position comes first.
    final theNode = getNodeById(docPosition1.nodeId)!;
    return theNode.selectUpstreamPosition(docPosition1.nodePosition, docPosition2.nodePosition) ==
            docPosition1.nodePosition
        ? docPosition1
        : docPosition2;
  }

  /// Given [docPosition1] and [docPosition2], returns the `DocumentPosition` that
  /// appears last in the document.
  DocumentPosition selectDownstreamPosition(DocumentPosition docPosition1, DocumentPosition docPosition2) {
    final upstreamPosition = selectUpstreamPosition(docPosition1, docPosition2);
    return upstreamPosition == docPosition1 ? docPosition2 : docPosition1;
  }

  /// Returns `true` if, and only if, the given [position] sits within the
  /// given [selection] in this `Document`.
  bool doesSelectionContainPosition(DocumentSelection selection, DocumentPosition position) {
    if (selection.isCollapsed) {
      return false;
    }

    final selectionAffinity = getAffinityForSelection(selection);
    final upstreamPosition = selectionAffinity == TextAffinity.downstream ? selection.base : selection.extent;
    final downstreamPosition = selectionAffinity == TextAffinity.downstream ? selection.extent : selection.base;

    // The selection contains the position if the ordering is as follows:
    //
    //   selection start <= position <= selection end
    //
    // Another way of stating this relationship is that there's a downstream
    // affinity from selection start to the position, and from the position to
    // the selection end.
    return getAffinityBetween(base: upstreamPosition, extent: position) == TextAffinity.downstream &&
        getAffinityBetween(base: position, extent: downstreamPosition) == TextAffinity.downstream;
  }
}

extension ExpandDocumentSelection on Document {
  DocumentSelection expandSelection(DocumentSelection selection, DocumentPosition extentPosition) {
    if (selection is AdjustedDocumentSelection) {
      return DocumentSelection(
        base: selection.original.base,
        extent: extentPosition,
      );
    } else {
      return DocumentSelection(
        base: selection.base,
        extent: extentPosition,
      );
    }
  }

  /// Applies [CompositeNode]-specific adjustments to a leaf-based selection.
  ///
  /// Walks bottom-up from both anchors, lifting positions level by level into
  /// [CompositeNodePosition]. At each level, the corresponding [CompositeNode]
  /// may adjust the upstream boundary ([adjustUpstreamPosition]) and/or downstream
  /// boundary ([adjustDownstreamPosition]). If both anchors are inside the same
  /// composite node, it sees the opposing boundary and can make coordinated changes.
  ///
  /// This enables "smart" selection snapping in complex blocks like tables, banners, etc
  ///
  /// Returns an [AdjustedDocumentSelection] with possibly modified base/extent
  /// (but preserving the original for correct shift-click behavior) if any
  /// composite node performed an adjustment. Otherwise returns the input [selection]
  /// unchanged.
  ///
  /// Requires that both base and extent refer to leaf nodes with leaf positions.
  DocumentSelection refineSelectionWithCompositeNodeAdjustments(DocumentSelection selection) {
    if (selection.base.nodePosition is CompositeNodePosition ||
        selection.extent.nodePosition is CompositeNodePosition) {
      throw Exception('Both base and extent positions must be leaf positions before they can be adjusted');
    }

    final basePath = getNodePathById(selection.base.nodeId)!;
    final extentPath = getNodePathById(selection.extent.nodeId)!;
    if (basePath.isRoot && extentPath.isRoot) {
      // as both paths are for root nodes, no CompositeNode was involved
      return selection;
    }

    final isDownstream = getAffinityBetweenPaths(basePath, extentPath) == TextAffinity.downstream;

    final upstream = isDownstream ? selection.base : selection.extent;
    final downstream = isDownstream ? selection.extent : selection.base;
    final upstreamPath = isDownstream ? basePath : extentPath;
    final downstreamPath = isDownstream ? extentPath : basePath;

    final (upstreamPosition, downstreamPosition, adjusted) = _liftAndAdjustPositions(
      upstreamPath: upstreamPath,
      downstreamPath: downstreamPath,
      upstreamPosition: upstream.nodePosition,
      downstreamPosition: downstream.nodePosition,
    );

    if (adjusted) {
      return AdjustedDocumentSelection(
        base: DocumentPosition(
          nodeId: isDownstream ? upstreamPath.rootNodeId : downstreamPath.rootNodeId,
          nodePosition: isDownstream ? upstreamPosition : downstreamPosition,
        ).toLeafPosition(),
        extent: DocumentPosition(
          nodeId: isDownstream ? downstreamPath.rootNodeId : upstreamPath.rootNodeId,
          nodePosition: isDownstream ? downstreamPosition : upstreamPosition,
        ).toLeafPosition(),
        original: selection,
      );
    } else {
      return selection;
    }
  }

  /// Bottom-up lift + adjustment of both positions across shared ancestor levels.
  (NodePosition, NodePosition, bool) _liftAndAdjustPositions({
    required NodePosition upstreamPosition,
    required NodePosition downstreamPosition,
    required NodePath upstreamPath,
    required NodePath downstreamPath,
  }) {
    var adjusted = false;

    // Go bottom-up by both paths, and preprocess selection by each CompositeNode
    for (var i = max(upstreamPath.length, downstreamPath.length) - 1; i > 0; i -= 1) {
      final upstreamParentId = upstreamPath.length > i ? upstreamPath[i - 1] : null;
      final downstreamParentId = downstreamPath.length > i ? downstreamPath[i - 1] : null;

      if (upstreamParentId != null) {
        upstreamPosition = CompositeNodePosition(upstreamPath[i], upstreamPosition);
      }
      if (downstreamParentId != null) {
        downstreamPosition = CompositeNodePosition(downstreamPath[i], downstreamPosition);
      }
      CompositeNodePosition? adjustedUpstreamPosition;
      CompositeNodePosition? adjustedDownstreamPosition;

      if (upstreamParentId != null) {
        final upstreamParent = getNodeById(upstreamParentId) as CompositeNode;
        adjustedUpstreamPosition = upstreamParent.adjustUpstreamPosition(
          upstreamPosition: upstreamPosition as CompositeNodePosition,
          downstreamPosition:
              upstreamParentId == downstreamParentId ? downstreamPosition as CompositeNodePosition : null,
        );
      }

      if (downstreamParentId != null) {
        final downstreamParent = getNodeById(downstreamParentId) as CompositeNode;
        adjustedDownstreamPosition = downstreamParent.adjustDownstreamPosition(
          downstreamPosition: downstreamPosition as CompositeNodePosition,
          upstreamPosition: upstreamParentId == downstreamParentId ? upstreamPosition as CompositeNodePosition : null,
        );
      }
      // Writing adjusted positions after getting both upstream/downstream from CompositeNode, so
      // both adjust upstream/downstream methods takes original ones as input
      if (adjustedUpstreamPosition != null) {
        upstreamPosition = adjustedUpstreamPosition;
        adjusted = true;
      }
      if (adjustedDownstreamPosition != null) {
        downstreamPosition = adjustedDownstreamPosition;
        adjusted = true;
      }
    }

    return (upstreamPosition, downstreamPosition, adjusted);
  }
}

/// A [DocumentSelection] that preserves the **original** user-intended
/// selection alongside a possibly **adjusted** (snapped, refined) version.
///
/// This is critical for correct **Shift+Click** behavior:
/// - When extending selection with Shift, the editor must use the **original** base
///   (where the user first clicked), not the one that was silently moved by a
///   [CompositeNode] (e.g. table snapping the cursor to the start of a cell).
/// - But visually and for operations, we want to use the **adjusted** positions.
///
/// Without this distinction, Shift+Click selection grows unpredictably.
///
/// Use [original] when computing new selection range on Shift+Click.
/// Use [base]/[extent] (inherited) for rendering and actual operations.
class AdjustedDocumentSelection extends DocumentSelection {
  AdjustedDocumentSelection({
    required super.base,
    required super.extent,
    required this.original,
  });

  final DocumentSelection original;
}
