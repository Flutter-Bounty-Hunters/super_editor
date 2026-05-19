import 'package:collection/collection.dart';
import 'package:flutter/material.dart' hide Placeholder;
import 'package:super_editor/super_editor.dart';

/// A Super Editor [DocumentNode], which represents a list of message attachments.
class AttachmentListNode<AttachmentType> extends DocumentNode {
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
        attachments.length,
        TextAffinity.downstream,
      );

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
    if (base is! AttachmentListNodePosition) {
      throw Exception('Expected a AttachmentListNodePosition for base but received a ${base.runtimeType}');
    }
    if (extent is! AttachmentListNodePosition) {
      throw Exception('Expected a AttachmentListNodePosition for extent but received a ${extent.runtimeType}');
    }

    return AttachmentListNodeSelection(base: base, extent: extent);
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

  bool get isCollapsed => base == extent;

  bool get isExpanded => base != extent;

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
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttachmentListNodePosition &&
          runtimeType == other.runtimeType &&
          attachmentIndex == other.attachmentIndex &&
          affinity == other.affinity;

  @override
  int get hashCode => Object.hash(attachmentIndex, affinity);
}
