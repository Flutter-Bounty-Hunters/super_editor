import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart' hide Placeholder;
import 'package:super_editor/super_editor.dart';

/// A Super Editor [DocumentNode], which represents a list of message attachments.
class AttachmentListNode<AttachmentType> extends EditableDocumentNode {
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

  final List<AttachmentType> attachments;

  @override
  AttachmentListNodePosition get beginningPosition => AttachmentListNodePosition.start;

  @override
  AttachmentListNodePosition get endPosition => AttachmentListNodePosition(
        attachments.length - 1,
        TextAffinity.downstream,
      );

  @override
  bool isPositionCloserToStart(NodePosition position) {
    if (position is! AttachmentListNodePosition) {
      throw Exception('Expected a AttachmentListNodePosition for position but received a ${position.runtimeType}');
    }

    return position.attachmentIndex < attachments.length / 2;
  }

  @override
  bool containsPosition(Object position) =>
      position is AttachmentListNodePosition && position.attachmentIndex < attachments.length;

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

    if (position1.attachmentIndex < position2.attachmentIndex) {
      return position1;
    } else if (position2.attachmentIndex < position1.attachmentIndex) {
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
    print("AttachmentListNode - computeSelection(), base: $base, extent: $extent");
    if (base is! AttachmentListNodePosition) {
      throw Exception('Expected a AttachmentListNodePosition for base but received a ${base.runtimeType}');
    }
    if (extent is! AttachmentListNodePosition) {
      throw Exception('Expected a AttachmentListNodePosition for extent but received a ${extent.runtimeType}');
    }

    return AttachmentListNodeSelection(base: base, extent: extent);
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
      print("SPLITTING AT END OF ATTACHMENT LIST");
      return (
        this,
        ParagraphNode(id: newId, text: AttributedText()),
      );
    }

    print("SPLITTING IN MIDDLE OF ATTACHMENT LIST");
    print(" - $nodePosition");
    final startOfSecondList = nodePosition.isUpstream ? nodePosition.attachmentIndex : nodePosition.attachmentIndex + 1;

    return (
      AttachmentListNode<AttachmentType>(
        id: id,
        attachments: attachments.sublist(0, startOfSecondList),
      ),
      AttachmentListNode<AttachmentType>(
        id: newId,
        attachments: attachments.sublist(startOfSecondList),
      ),
    );
  }

  @override
  (DocumentNode, NodePosition) deleteFromStartToPosition(NodePosition position) {
    if (position is! AttachmentListNodePosition) {
      throw Exception('Expected a AttachmentListNodePosition node position but received a ${position.runtimeType}');
    }

    if (position.isEquivalentTo(endPosition)) {
      // We're deleting everything, which will leave us empty. Replace
      // ourselves with a paragraph node.
      return (
        ParagraphNode(id: id, text: AttributedText()),
        const TextNodePosition(offset: 0),
      );
    }

    final deletionEnd = min(
      position.affinity == TextAffinity.upstream ? position.attachmentIndex : position.attachmentIndex + 1,
      attachments.length - 1,
    );

    return (
      AttachmentListNode<AttachmentType>(
        id: id,
        attachments: List.from(attachments)..removeRange(0, deletionEnd),
        metadata: Map.from(metadata),
      ),
      AttachmentListNodePosition.start
    );
  }

  @override
  (DocumentNode, NodePosition) deleteFromPositionToEnd(NodePosition position) {
    if (position is! AttachmentListNodePosition) {
      throw Exception('Expected a AttachmentListNodePosition node position but received a ${position.runtimeType}');
    }

    if (position.isEquivalentTo(AttachmentListNodePosition.start)) {
      // We're deleting everything, which will leave us empty. Replace
      // ourselves with a paragraph node.
      return (
        ParagraphNode(id: id, text: AttributedText()),
        const TextNodePosition(offset: 0),
      );
    }

    final deletionStart = min(
      position.affinity == TextAffinity.upstream ? position.attachmentIndex : position.attachmentIndex + 1,
      attachments.length - 1,
    );

    return (
      AttachmentListNode<AttachmentType>(
        id: id,
        attachments: List.from(attachments)..removeRange(deletionStart, attachments.length - 1),
        metadata: Map.from(metadata),
      ),
      position,
    );
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

    final start = base < extent ? base : extent;
    final end = base < extent ? extent : base;

    final deletionStart = min(
      start.affinity == TextAffinity.upstream ? start.attachmentIndex : start.attachmentIndex + 1,
      attachments.length - 1,
    );
    final deletionEnd = min(
      end.affinity == TextAffinity.upstream ? end.attachmentIndex : end.attachmentIndex + 1,
      attachments.length - 1,
    );

    print("Deleting attachments from $deletionStart to $deletionEnd (out of ${attachments.length})");

    if (deletionStart == 0 && deletionEnd == attachments.length - 1) {
      // We're deleting everything, which will leave us empty. Replace
      // ourselves with a paragraph node.
      print("We're deleting all attachments. Converting to paragraph.");
      return (
        ParagraphNode(id: id, text: AttributedText()),
        const TextNodePosition(offset: 0),
      );
    }

    print("We're deleting some but not all attachments.");
    return (
      AttachmentListNode<AttachmentType>(
        id: id,
        attachments: List.from(attachments) //
          ..removeRange(deletionStart, deletionEnd + 1), // +1 for exclusive
        metadata: Map.from(metadata),
      ),
      deletionStart == 0
          ? AttachmentListNodePosition.start
          : AttachmentListNodePosition(deletionStart - 1, TextAffinity.downstream),
    );
  }

  @override
  (DocumentNode updatedNode, NodePosition newPosition) deleteUpstream(NodePosition position) {
    if (position is! AttachmentListNodePosition) {
      throw Exception('Expected a AttachmentListNodePosition node position but received a ${position.runtimeType}');
    }

    if (position.isEquivalentTo(beginningPosition)) {
      // Nothing to delete upstream before the beginning of the node.
      return (this, beginningPosition);
    }

    if (attachments.length == 1) {
      // There's only one attachment. Deleting it will leave us empty. Replace
      // ourselves with a paragraph node.
      return (
        ParagraphNode(id: id, text: AttributedText()),
        const TextNodePosition(offset: 0),
      );
    }

    return (
      AttachmentListNode<AttachmentType>(
        id: id,
        attachments: List.from(attachments)
          ..removeAt(
            position.affinity == TextAffinity.upstream ? position.attachmentIndex - 1 : position.attachmentIndex,
          ),
        metadata: Map.from(metadata),
      ),
      position.moveUpstream()!,
    );
  }

  @override
  (EditableDocumentNode, NodePosition) deleteDownstream(NodePosition position) {
    if (position is! AttachmentListNodePosition) {
      throw Exception('Expected a AttachmentListNodePosition node position but received a ${position.runtimeType}');
    }

    if (position.isEquivalentTo(endPosition)) {
      // Nothing to delete downstream after the end of the node.
      return (this, position);
    }

    return (
      AttachmentListNode<AttachmentType>(
        id: id,
        attachments: List.from(attachments)
          ..removeAt(
            position.affinity == TextAffinity.upstream ? position.attachmentIndex : position.attachmentIndex + 1,
          ),
        metadata: Map.from(metadata),
      ),
      position,
    );
  }

  @override
  String? copyContent(dynamic selection) {
    if (selection is! AttachmentListNodeSelection) {
      throw Exception('MaxAttachmentNode can only copy content from a '
          '_AttachmentListNodeSelection.');
    }

    return !selection.isCollapsed
        ? attachments.sublist(selection.start.attachmentIndex, selection.end.attachmentIndex + 1).join(', ')
        : null;
  }

  AttachmentListNode copy() {
    return AttachmentListNode<AttachmentType>(
      id: id,
      attachments: List.from(attachments),
      metadata: Map.from(metadata),
    );
  }

  @override
  DocumentNode copyAndReplaceMetadata(Map<String, dynamic> newMetadata) {
    return AttachmentListNode<AttachmentType>(
      id: id,
      attachments: List.from(attachments),
      metadata: Map.from(metadata),
    );
  }

  @override
  DocumentNode copyWithAddedMetadata(Map<String, dynamic> newProperties) {
    return AttachmentListNode<AttachmentType>(
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
/// An [AttachmentListNodePosition] targets an attachment at a given [attachmentIndex]
/// and then positions itself either on the "upstream" side (usually left side), or the
/// "downstream" side (usually right side).
///
/// Due to the affinity, there are typically two different positions objects that represent the
/// same logical position. The exception to this is the starting position and the ending position,
/// for which there is only one possible [AttachmentListNodePosition] representation.
class AttachmentListNodePosition implements NodePosition {
  /// The position that sits at the beginning of an [AttachmentListNode].
  static const start = AttachmentListNodePosition(0, TextAffinity.upstream);

  const AttachmentListNodePosition(this.attachmentIndex, this.affinity);

  /// The index of the attachment within the attachment list where this
  /// position is based.
  final int attachmentIndex;

  /// Whether this position is on the upstream or downstream side of
  /// the attachment.
  final TextAffinity affinity;

  /// Returns `true` if this position sits on the upstream side of the attachment
  /// at [attachmentIndex].
  bool get isUpstream => affinity == TextAffinity.upstream;

  /// Returns `true` if this position sits on the downstream side of the attachment
  /// at [attachmentIndex].
  bool get isDownstream => affinity == TextAffinity.downstream;

  AttachmentListNodePosition? moveUpstream() => isEquivalentTo(start)
      ? null
      : attachmentIndex == 0
          ? start
          : AttachmentListNodePosition(attachmentIndex - 1, affinity);

  AttachmentListNodePosition? moveDownstream(int attachmentCount) => isEquivalentTo(
        AttachmentListNodePosition(attachmentCount - 1, TextAffinity.downstream),
      )
          ? null
          : attachmentIndex == attachmentCount - 1
              ? AttachmentListNodePosition(attachmentIndex, TextAffinity.downstream)
              : AttachmentListNodePosition(attachmentIndex + 1, TextAffinity.downstream);

  bool operator <(Object other) => other is! AttachmentListNodePosition
      ? false
      : attachmentIndex < other.attachmentIndex
          ? true
          : attachmentIndex == other.attachmentIndex &&
                  affinity == TextAffinity.upstream &&
                  other.affinity == TextAffinity.downstream
              ? true
              : false;

  bool operator >(Object other) => other is! AttachmentListNodePosition ? false : !(this < other);

  AttachmentListNodePosition copy() => AttachmentListNodePosition(
        attachmentIndex,
        affinity,
      );

  @override
  bool isEquivalentTo(NodePosition other) {
    if (other is! AttachmentListNodePosition) {
      return false;
    }

    // This position is equivalent to another position when they're identical,
    // but also when they're not identical and they point to the same divider
    // between attachments (i.e., one position points downstream and the other
    // points upstream).
    return other == this ||
        (attachmentIndex == other.attachmentIndex - 1 &&
            affinity == TextAffinity.downstream &&
            other.affinity == TextAffinity.upstream) ||
        (attachmentIndex == other.attachmentIndex + 1 &&
            affinity == TextAffinity.upstream &&
            other.affinity == TextAffinity.downstream);
  }

  @override
  String toString() => "Attachment $attachmentIndex ($affinity)";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttachmentListNodePosition &&
          runtimeType == other.runtimeType &&
          attachmentIndex == other.attachmentIndex &&
          affinity == other.affinity;

  @override
  int get hashCode => Object.hash(attachmentIndex, affinity);
}
