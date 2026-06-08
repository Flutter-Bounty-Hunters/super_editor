import 'package:collection/collection.dart';
import 'package:flutter/material.dart' hide Placeholder;
import 'package:super_editor/super_editor.dart';

/// A Super Editor [DocumentNode], which represents a list of attachments.
class AttachmentListNode extends EditableDocumentNode {
  AttachmentListNode({
    required this.id,
    required this.attachments,
    Map<String, dynamic>? metadata,
  }) {
    initAddToMetadata({
      if (metadata != null) //
        ...metadata,
      'blockType': attachmentListBlockAttribution,
    });
  }

  @override
  final String id;

  final List<Object> attachments;

  @override
  AttachmentListNodePosition get beginningPosition => AttachmentListNodePosition.start;

  @override
  AttachmentListNodePosition get endPosition => AttachmentListNodePosition(
        attachments.length,
        TextAffinity.downstream,
      );

  @override
  bool isPositionCloserToStart(NodePosition position) {
    if (position is! AttachmentListNodePosition) {
      throw Exception('Expected a AttachmentListNodePosition for position but received a ${position.runtimeType}');
    }

    return position.gapIndex < attachments.length / 2;
  }

  @override
  bool containsPosition(Object position) =>
      position is AttachmentListNodePosition && position.gapIndex <= attachments.length;

  @override
  AttachmentListNodePosition selectUpstreamPosition(
    NodePosition position1,
    NodePosition position2,
  ) {
    if (position1 is! AttachmentListNodePosition) {
      throw Exception('Expected a AttachmentListNodePosition for position1 but received a ${position1.runtimeType}');
    }
    if (position2 is! AttachmentListNodePosition) {
      throw Exception('Expected a AttachmentListNodePosition for position2 but received a ${position2.runtimeType}');
    }

    if (position1.gapIndex < position2.gapIndex) {
      return position1;
    } else if (position2.gapIndex < position1.gapIndex) {
      return position2;
    } else {
      return (position1.affinity == TextAffinity.upstream && position2.affinity == TextAffinity.downstream)
          ? position1
          : position2;
    }
  }

  @override
  AttachmentListNodePosition selectDownstreamPosition(
    NodePosition position1,
    NodePosition position2,
  ) {
    final upstream = selectUpstreamPosition(position1, position2);
    return (upstream == position1 ? position2 : position1) as AttachmentListNodePosition;
  }

  @override
  AttachmentListNodeSelection computeSelection({
    required NodePosition base,
    required NodePosition extent,
  }) {
    if (base is! AttachmentListNodePosition) {
      throw Exception('Expected a AttachmentListNodePosition for base but received a ${base.runtimeType}');
    }
    if (extent is! AttachmentListNodePosition) {
      throw Exception('Expected a AttachmentListNodePosition for extent but received a ${extent.runtimeType}');
    }

    return AttachmentListNodeSelection(base: base, extent: extent);
  }

  @override
  String serializeForIme() {
    final buffer = StringBuffer();
    for (int i = 0; i < attachments.length; i += 1) {
      buffer.write('~');
    }
    return buffer.toString();
  }

  @override
  int nodePositionToImePosition(NodePosition position) {
    if (position is! AttachmentListNodePosition) {
      throw Exception("Expected an AttachmentListNodePosition but was given: ${position.runtimeType}");
    }

    return position.gapIndex;
  }

  @override
  AttachmentListNodePosition imePositionToNodePosition(int imePosition, [TextAffinity? expandedSelectionEdge]) {
    return switch (expandedSelectionEdge) {
      // This position is part of a collapsed selection. In this case we always use an
      // upstream affinity because in both of the situations below, which are the only two
      // situations we know of where this matters, we want the caret in the top row, not
      // the bottom row.
      //
      // Backspacing:
      //
      //  [][][][]
      //  []|[][][]
      //
      //  [][][][]|
      //  [][][]
      //
      // Deleting:
      //
      //  [][][][]|
      //  [][][][]
      //
      //  [][][][]|
      //  [][][]
      null => AttachmentListNodePosition(imePosition, TextAffinity.upstream),
      // This position sits on the upstream side of an expanded selection. We use a downstream
      // affinity so that we get this result:
      //
      //   [][][][]
      //   <[][]>[][]
      //
      // and NOT this:
      //
      //   [][][][]<
      //   [][]>[][]
      TextAffinity.upstream => AttachmentListNodePosition(imePosition, TextAffinity.downstream),
      // This position sits on the downstream side of an expanded selection. We use an upstream
      // affinity so that we get this result:
      //
      //   [][]<[][]>
      //   [][][][]
      //
      // and NOT this:
      //
      //   [][]<[][]
      //   >[][][][]
      TextAffinity.downstream => AttachmentListNodePosition(imePosition, TextAffinity.upstream),
    };
  }

  @override
  bool canSplitAt(NodePosition position) {
    return position is AttachmentListNodePosition;
  }

  @override
  (DocumentNode firstPart, DocumentNode secondPart) splitAt(nodePosition, {required String newId}) {
    if (nodePosition is! AttachmentListNodePosition) {
      throw Exception('Expected a AttachmentListNodePosition node position but received a ${nodePosition.runtimeType}');
    }

    if (nodePosition.isEquivalentTo(beginningPosition)) {
      return (
        ParagraphNode(id: newId, text: AttributedText()),
        this,
      );
    }

    if (nodePosition.isEquivalentTo(endPosition)) {
      return (
        this,
        ParagraphNode(id: newId, text: AttributedText()),
      );
    }

    final startOfSecondList = nodePosition.gapIndex;

    return (
      AttachmentListNode(
        id: id,
        attachments: attachments.sublist(0, startOfSecondList),
      ),
      AttachmentListNode(
        id: newId,
        attachments: attachments.sublist(startOfSecondList),
      ),
    );
  }

  @override
  bool canMergeWithEndOf(DocumentNode nodeBefore) {
    return nodeBefore is AttachmentListNode;
  }

  @override
  (DocumentNode mergedNode, NodePosition mergedNodePosition) mergeWithEndOf(DocumentNode nodeBefore) {
    if (nodeBefore is! AttachmentListNode) {
      throw Exception(
          "Tried to merge an AttachmentListNode with an incompatible earlier node: ${nodeBefore.runtimeType}");
    }

    return (
      AttachmentListNode(
        id: nodeBefore.id,
        attachments: [
          ...nodeBefore.attachments,
          ...attachments,
        ],
      ),
      AttachmentListNodePosition(nodeBefore.attachments.length, TextAffinity.downstream),
    );
  }

  @override
  bool canMergeWithStartOf(DocumentNode nodeAfter) {
    return nodeAfter is AttachmentListNode;
  }

  @override
  (DocumentNode mergedNode, NodePosition mergedNodePosition) mergeWithStartOf(DocumentNode nodeAfter) {
    if (nodeAfter is! AttachmentListNode) {
      throw Exception("Tried to merge an AttachmentListNode with an incompatible later node: ${nodeAfter.runtimeType}");
    }

    return (
      AttachmentListNode(
        id: id,
        attachments: [
          ...attachments,
          ...nodeAfter.attachments,
        ],
      ),
      AttachmentListNodePosition(attachments.length, TextAffinity.upstream),
    );
  }

  (DocumentNode, NodePosition) insertAttachmentsAt(List<Object> newAttachments, int insertionIndex) {
    return (
      AttachmentListNode(
        id: id,
        attachments: List.from(attachments)..insertAll(insertionIndex, newAttachments),
        metadata: copyMetadata(),
      ),
      AttachmentListNodePosition(insertionIndex + newAttachments.length),
    );
  }

  @override
  (DocumentNode, NodePosition) deleteFromStartToPosition(NodePosition position) {
    if (position is! AttachmentListNodePosition) {
      throw Exception('Expected a AttachmentListNodePosition node position but received a ${position.runtimeType}');
    }

    return deleteSelection(beginningPosition, position);
  }

  @override
  (DocumentNode, NodePosition) deleteFromPositionToEnd(NodePosition position) {
    if (position is! AttachmentListNodePosition) {
      throw Exception('Expected a AttachmentListNodePosition node position but received a ${position.runtimeType}');
    }

    return deleteSelection(position, endPosition);
  }

  @override
  (DocumentNode updatedNode, NodePosition newPosition) deleteSelection(
    NodePosition base,
    NodePosition extent,
  ) {
    if (base is! AttachmentListNodePosition) {
      throw Exception('Expected a AttachmentListNodePosition for the base position but received a ${base.runtimeType}');
    }
    if (extent is! AttachmentListNodePosition) {
      throw Exception(
        'Expected a AttachmentListNodePosition for the extent position but received a ${extent.runtimeType}',
      );
    }
    if (base.isEquivalentTo(extent)) {
      // Nothing is selected. Nothing to delete.
      return (this, base);
    }

    final start = base < extent ? base : extent;
    final end = base < extent ? extent : base;

    if (start.gapIndex == 0 && end.gapIndex == attachments.length) {
      // We're deleting everything, which will leave us empty. Replace
      // ourselves with a paragraph node.
      return (
        ParagraphNode(id: id, text: AttributedText()),
        const TextNodePosition(offset: 0),
      );
    }

    return (
      AttachmentListNode(
        id: id,
        attachments: List.from(attachments) //
          ..removeRange(start.gapIndex, end.gapIndex),
        metadata: Map.from(metadata),
      ),
      AttachmentListNodePosition(
        start.gapIndex,
        // We always use an upstream affinity because we want to support the following
        // two deletion scenarios, and we're not aware of any other contrary scenarios.
        //
        // Backspacing:
        //
        //    [][][][]
        //    []|[][][]
        //
        //    [][][][]|
        //    [][][]
        //
        // Deleting:
        //
        //    [][][][]|
        //    [][][][]
        //
        //    [][][][]|
        //    [][][]
        TextAffinity.upstream,
      ),
    );
  }

  @override
  (DocumentNode updatedNode, NodePosition newPosition)? deleteUpstream(NodePosition position) {
    if (position is! AttachmentListNodePosition) {
      throw Exception('Expected a AttachmentListNodePosition node position but received a ${position.runtimeType}');
    }

    if (position.isEquivalentTo(beginningPosition)) {
      // Nothing to delete upstream before the beginning of the node.
      return null;
    }

    if (attachments.length == 1) {
      // We're deleting everything, which will leave us empty. Replace
      // ourselves with a paragraph node.
      return (
        ParagraphNode(id: id, text: AttributedText()),
        const TextNodePosition(offset: 0),
      );
    }

    return (
      AttachmentListNode(
        id: id,
        attachments: List.from(attachments)..removeAt(position.gapIndex - 1),
        metadata: Map.from(metadata),
      ),
      // When deleting upstream, make hte position "upstream". The only situation
      // where this matters is near the start of a row, in which case we want the
      // following to happen:
      //
      //  [][][][]
      //  []|[][][]
      //
      //  [][][][]|
      //  [][][]
      position.moveUpstream(TextAffinity.upstream)!,
    );
  }

  @override
  (EditableDocumentNode, NodePosition)? deleteDownstream(NodePosition position) {
    if (position is! AttachmentListNodePosition) {
      throw Exception('Expected a AttachmentListNodePosition node position but received a ${position.runtimeType}');
    }

    if (position.isEquivalentTo(endPosition)) {
      // Nothing to delete downstream after the end of the node.
      return null;
    }

    return (
      AttachmentListNode(
        id: id,
        attachments: List.from(attachments)..removeAt(position.gapIndex),
        metadata: Map.from(metadata),
      ),
      position,
    );
  }

  /// Returns a new [AttachmentListNode] that's the same as this one, except the
  /// attachment at the given [index] has been removed.
  EditableDocumentNode deleteAttachmentAt(int index) {
    assert(0 <= index && index < attachments.length,
        "Invalid attachment index ($index) in node with ${attachments.length}");
    if (index < 0 || index >= attachments.length) {
      return this;
    }

    return AttachmentListNode(
      id: id,
      attachments: List.from(attachments)..removeAt(index),
    );
  }

  @override
  String? copyContent(dynamic selection) {
    if (selection is! AttachmentListNodeSelection) {
      throw Exception('MaxAttachmentNode can only copy content from a '
          '_AttachmentListNodeSelection.');
    }

    return !selection.isCollapsed
        ? attachments.sublist(selection.start.gapIndex, selection.end.gapIndex + 1).join(', ')
        : null;
  }

  AttachmentListNode copy() {
    return AttachmentListNode(
      id: id,
      attachments: List.from(attachments),
      metadata: Map.from(metadata),
    );
  }

  @override
  DocumentNode copyAndReplaceMetadata(Map<String, dynamic> newMetadata) {
    return AttachmentListNode(
      id: id,
      attachments: List.from(attachments),
      metadata: Map.from(metadata),
    );
  }

  @override
  DocumentNode copyWithAddedMetadata(Map<String, dynamic> newProperties) {
    return AttachmentListNode(
      id: id,
      attachments: List.from(attachments),
      metadata: {
        ...metadata,
        ...newProperties,
      },
    );
  }

  @override
  bool hasEquivalentContent(DocumentNode other) {
    return other is AttachmentListNode && const DeepCollectionEquality().equals(attachments, other.attachments);
  }

  @override
  String toString() => "[AttachmentListNode] - $attachments";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttachmentListNode &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          const DeepCollectionEquality().equals(attachments, other.attachments);

  @override
  int get hashCode => id.hashCode ^ attachments.hashCode;
}

const attachmentListBlockAttribution = NamedAttribution('attachment-list-block');

/// A selection within an [AttachmentListNode] - this selection might represent a
/// caret positioned between attachments, or an expanded selection that includes one
/// or more attachments.
class AttachmentListNodeSelection extends NodeSelection {
  AttachmentListNodeSelection.collapsed(
    AttachmentListNodePosition position,
  )   : base = position,
        extent = position;

  AttachmentListNodeSelection({
    required this.base,
    required this.extent,
  });

  final AttachmentListNodePosition base;
  final AttachmentListNodePosition extent;

  AttachmentListNodePosition get start => base < extent ? base : extent;
  AttachmentListNodePosition get end => base < extent ? extent : base;

  bool get isCollapsed => base.isEquivalentTo(extent);

  bool get isExpanded => !isCollapsed;

  @override
  String toString() => "[AttachmentListNodeSelection] - base: $base, extent: $extent";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttachmentListNodeSelection &&
          runtimeType == other.runtimeType &&
          base == other.base &&
          extent == other.extent;

  @override
  int get hashCode => Object.hash(base, extent);
}

/// A position within an [AttachmentListNode].
///
/// An [AttachmentListNodePosition] targets a [gapIndex] in between two attachments, or before the
/// first attachment, or after the last attachment.
///
/// Each [AttachmentListNodePosition] also has an [affinity]. This [affinity] is only relevant when
/// working with a layout where attachments span more than one row. In such cases, the position at the
/// end of a row is the same as the position at the start of the next row. But a caret needs to be
/// able to sit at either location in the layout. The [affinity] points to one of these two locations
/// for the same [gapIndex].
class AttachmentListNodePosition implements NodePosition {
  /// The position that sits at the beginning of an [AttachmentListNode].
  static const start = AttachmentListNodePosition(0, TextAffinity.downstream);

  const AttachmentListNodePosition(this.gapIndex, [this.affinity = TextAffinity.downstream]);

  /// The index of the gap before or after an attachment where this position
  /// sits.
  final int gapIndex;

  /// Whether this position points to the end of a row (upstream) or the beginning
  /// of a row (downstream), when a [gapIndex] sits at the breakpoint of a row.
  ///
  /// This property has no effect when the [gapIndex] doesn't sit at a row
  /// split.
  final TextAffinity affinity;

  /// Returns `true` if this position wants to sit at the end of the row above, when
  /// the gap appears at a row split.
  bool get isUpstream => affinity == TextAffinity.upstream;

  /// Returns `true` if this position wants to sit at the beginning of the row below,
  /// when the gap appears at a row split.
  bool get isDownstream => affinity == TextAffinity.downstream;

  AttachmentListNodePosition? moveUpstream([TextAffinity? newAffinity]) =>
      isEquivalentTo(start) ? null : AttachmentListNodePosition(gapIndex - 1, newAffinity ?? affinity);

  AttachmentListNodePosition? moveDownstream(int attachmentCount, [TextAffinity? newAffinity]) => isEquivalentTo(
        AttachmentListNodePosition(attachmentCount - 1),
      )
          ? null
          : AttachmentListNodePosition(gapIndex + 1, newAffinity ?? TextAffinity.downstream);

  bool operator <(Object other) => other is! AttachmentListNodePosition
      ? false
      : gapIndex < other.gapIndex
          ? true
          : gapIndex == other.gapIndex && affinity == TextAffinity.upstream && other.affinity == TextAffinity.downstream
              ? true
              : false;

  bool operator >(Object other) => other is! AttachmentListNodePosition ? false : !(this < other);

  AttachmentListNodePosition copyWith({
    int? gapIndex,
    TextAffinity? affinity,
  }) {
    return AttachmentListNodePosition(gapIndex ?? this.gapIndex, affinity ?? this.affinity);
  }

  AttachmentListNodePosition copy() => AttachmentListNodePosition(
        gapIndex,
        affinity,
      );

  @override
  bool isEquivalentTo(NodePosition other) {
    if (other is! AttachmentListNodePosition) {
      return false;
    }

    // We ignore affinity when comparing equivalency.
    return gapIndex == other.gapIndex;
  }

  @override
  String toString() => "Attachment $gapIndex ($affinity)";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttachmentListNodePosition &&
          runtimeType == other.runtimeType &&
          gapIndex == other.gapIndex &&
          affinity == other.affinity;

  @override
  int get hashCode => Object.hash(gapIndex, affinity);
}
