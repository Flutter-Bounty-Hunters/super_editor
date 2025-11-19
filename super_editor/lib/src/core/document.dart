import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/default_editor/layout_single_column/composite_nodes.dart';
import 'package:super_editor/src/default_editor/text_ai.dart';

/// A read-only document with styled text and multimedia elements.
///
/// A [Document] is comprised of a list of [DocumentNode]s,
/// which describe the type and substance of a piece of content
/// within the document. For example, a [ParagraphNode] holds a
/// single paragraph of text within the document.
///
/// New types of content can be added by subclassing [DocumentNode].
///
/// To represent a specific location within a [Document],
/// see [DocumentPosition].
///
/// A [Document] has no opinion on the visual presentation of its
/// content.
///
/// To edit the content of a document, see [DocumentEditor].
abstract class Document implements Iterable<DocumentNode> {
  /// The number of [DocumentNode]s in this [Document].
  int get nodeCount;

  /// Returns `true` if this [Document] has zero nodes, or `false` if it
  /// has `1+ nodes.
  @override
  bool get isEmpty;

  /// Returns the first [DocumentNode] in this [Document], or `null` if this
  /// [Document] is empty.
  DocumentNode? get firstOrNull;

  /// Returns the last [DocumentNode] in this [Document], or `null` if this
  /// [Document] is empty.
  DocumentNode? get lastOrNull;

  /// Returns the [DocumentNode] with the given [nodeId], or [null]
  /// if no such node exists.
  DocumentNode? getNodeById(String nodeId);

  /// Returns the [DocumentNode] at the given [index], or [null]
  /// if no such node exists.
  DocumentNode? getNodeAt(int index);

  /// Returns the index of the given [node], or [-1] if the [node]
  /// does not exist within this [Document].
  @Deprecated("Use getNodeIndexById() instead")
  int getNodeIndex(DocumentNode node);

  /// Returns the index of the `DocumentNode` in this `Document` that
  /// has the given [nodeId], or `-1` if the node does not exist.
  int getNodeIndexById(String nodeId);

  /// Returns the index of the `DocumentNode` in parent node. If this
  /// is a root node, then returns the index in this `Document`.
  int getNodeIndexInParent(NodePath path);

  /// Returns the [DocumentNode] that appears immediately before the
  /// given [node] in this [Document], or null if the given [node]
  /// is the first node, or the given [node] does not exist in this
  /// [Document].
  @Deprecated("Use getNodeBeforeById() instead")
  DocumentNode? getNodeBefore(DocumentNode node);

  /// Returns the [DocumentNode] that appears immediately before the
  /// node with the given [nodeId] in this [Document], or `null` if
  /// the matching node is the first node in the document, or no such
  /// node exists.
  DocumentNode? getNodeBeforeById(String nodeId);

  /// Returns the [DocumentNode] that appears immediately after the
  /// given [node] in this [Document], or null if the given [node]
  /// is the last node, or the given [node] does not exist in this
  /// [Document].
  @Deprecated("Use getNodeAfterById() instead")
  DocumentNode? getNodeAfter(DocumentNode node);

  /// Returns the [DocumentNode] that appears immediately after the
  /// node with the given [nodeId] in this [Document], or `null` if
  /// the matching node is the last node in the document, or no such
  /// node exists.
  DocumentNode? getNodeAfterById(String nodeId);

  /// Returns the [DocumentNode] at the given [position], or [null] if
  /// no such node exists in this [Document].
  DocumentNode? getNode(DocumentPosition position);

  /// Returns the [DocumentNode] at the give [path] or [null] if
  /// no such node exists
  DocumentNode? getNodeAtPath(NodePath path);

  /// Returns full path to the node by id. Path is a list of parent nodeId, starting from root node
  NodePath? getNodePathById(String nodeId);

  /// Iterates all leaf nodes of the document.
  Iterable<(NodePath, DocumentNode)> getLeafNodes({bool? reversed, NodePath? since});

  /// Returns all [DocumentNode]s from [position1] to [position2], including
  /// the nodes at [position1] and [position2].
  List<DocumentNode> getNodesInside(DocumentPosition position1, DocumentPosition position2);

  /// Returns [true] if the content in the [other] document is equivalent to
  /// the content in this document, ignoring any details that are unrelated
  /// to content, such as individual node IDs.
  ///
  /// To compare [Document] equality, use the standard [==] operator.
  bool hasEquivalentContent(Document other);

  void addListener(DocumentChangeListener listener);

  void removeListener(DocumentChangeListener listener);

  /// Returns [true] if document can delete specified leaf node (based on [isDeletable] and [canDeleteChild] methods).
  bool canDeleteNode(NodePath path);
}

/// A path of node ids that can identify a specific node in a document
/// An alternative to `nodeId` for hierarchy structure
class NodePath with IterableMixin<String> {
  /// List of nodeIds
  final List<String> _segments;

  NodePath(Iterable<String> segments) : _segments = List.unmodifiable(segments) {
    assert(!_segments.any((s) => s.isEmpty), 'All segments of NodePath must be non-empty string');
  }

  factory NodePath.withNodeId(String nodeId) {
    return NodePath([nodeId]);
  }

  /// Creates NodePath from root-level DocumentPosition
  factory NodePath.withDocumentPosition(DocumentPosition position) {
    return NodePath.withNodePosition(position.nodeId, position.nodePosition);
  }

  /// Creates NodePath from root-level [nodeId] and [nodePosition]
  factory NodePath.withNodePosition(String nodeId, NodePosition nodePosition) {
    final ids = [nodeId];
    var currentNodePosition = nodePosition;
    while (currentNodePosition is CompositeNodePosition) {
      ids.add(currentNodePosition.childNodeId);
      currentNodePosition = currentNodePosition.childNodePosition;
    }
    return NodePath(ids);
  }

  @override
  Iterator<String> get iterator => _segments.iterator;

  String operator [](int index) => _segments[index];

  @override
  String get first => _segments.first;

  @override
  String get last => _segments.last;

  @override
  bool get isEmpty => _segments.isEmpty;

  @override
  bool get isNotEmpty => _segments.isNotEmpty;

  @override
  int get length => _segments.length;

  bool get isRoot => length == 1;

  String get rootNodeId => first;

  /// Returns leaf node id
  String get nodeId => last;

  /// Returns leaf parent NodePath. If path is for root node, then returns null
  NodePath? get parent {
    if (isRoot) {
      return null;
    }
    return NodePath(_segments.sublist(0, length - 1));
  }

  NodePath child(String childId) {
    return NodePath([..._segments, childId]);
  }

  NodePath replaceLeaf(String newNodeId) {
    if (isRoot) {
      return NodePath([newNodeId]);
    } else {
      return NodePath([...parent!, newNodeId]);
    }
  }

  @override
  String toString() {
    return isRoot ? rootNodeId : _segments.join('.');
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is NodePath && runtimeType == other.runtimeType && listEquals(_segments, other._segments));
  }

  @override
  int get hashCode => Object.hashAll(_segments);
}

/// Listener that's notified when a document changes.
///
/// The [changeLog] includes an ordered list of all changes that were applied
/// to the [Document] since the last time this listener was notified.
typedef DocumentChangeListener = void Function(DocumentChangeLog changeLog);

/// One or more document changes that occurred within a single edit transaction.
///
/// A [DocumentChangeLog] can be used to rebuild only the parts of a document that changed.
class DocumentChangeLog {
  DocumentChangeLog(this.changes);

  final List<DocumentChange> changes;

  /// Returns `true` if the [DocumentNode] with the given [nodeId] was altered in any way
  /// by the events in this change log.
  bool wasNodeChanged(String nodeId) {
    for (final event in changes) {
      if (event is NodeDocumentChange && event.nodeId == nodeId) {
        return true;
      }
    }
    return false;
  }
}

/// Marker interface for all document changes.
abstract class DocumentChange {
  const DocumentChange();

  /// Describes this change in a human-readable way.
  String describe() => toString();
}

/// A [DocumentChange] that impacts a single, specified [DocumentNode] with [nodeId].
abstract class NodeDocumentChange extends DocumentChange {
  const NodeDocumentChange();

  String get nodeId;
}

/// A new [DocumentNode] was inserted in the [Document].
class NodeInsertedEvent extends NodeDocumentChange {
  const NodeInsertedEvent(this.nodeId, this.insertionIndex);

  @override
  final String nodeId;

  /// The index inside node parent
  final int insertionIndex;

  @override
  String describe() => "Inserted node: $nodeId";

  @override
  String toString() => "NodeInsertedEvent ($nodeId)";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NodeInsertedEvent &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          insertionIndex == other.insertionIndex;

  @override
  int get hashCode => nodeId.hashCode ^ insertionIndex.hashCode;
}

/// A [DocumentNode] was moved to a new index.
class NodeMovedEvent extends NodeDocumentChange {
  const NodeMovedEvent({
    required this.nodeId,
    required this.from,
    required this.to,
  });

  @override
  final String nodeId;
  final int from;
  final int to;

  @override
  String describe() => "Moved node ($nodeId): $from -> $to";

  @override
  String toString() => "NodeMovedEvent ($nodeId: $from -> $to)";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NodeMovedEvent &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          from == other.from &&
          to == other.to;

  @override
  int get hashCode => nodeId.hashCode ^ from.hashCode ^ to.hashCode;
}

/// A [DocumentNode] was removed from the [Document].
class NodeRemovedEvent extends NodeDocumentChange {
  const NodeRemovedEvent(this.nodeId, this.removedNode);

  @override
  final String nodeId;

  final DocumentNode removedNode;

  @override
  String describe() => "Removed node: $nodeId";

  @override
  String toString() => "NodeRemovedEvent ($nodeId)";

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is NodeRemovedEvent && runtimeType == other.runtimeType && nodeId == other.nodeId;

  @override
  int get hashCode => nodeId.hashCode;
}

/// The content of a [DocumentNode] changed.
///
/// A node change might signify a content change, such as text changing in a paragraph, or
/// it might signify a node changing its type of content, such as converting a paragraph
/// to an image.
class NodeChangeEvent extends NodeDocumentChange {
  const NodeChangeEvent(this.nodeId);

  @override
  final String nodeId;

  @override
  String describe() => "Changed node: $nodeId";

  @override
  String toString() => "NodeChangeEvent ($nodeId)";

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is NodeChangeEvent && runtimeType == other.runtimeType && nodeId == other.nodeId;

  @override
  int get hashCode => nodeId.hashCode;
}

/// A logical position within a [Document].
///
/// A [DocumentPosition] points to a specific node by way of a [nodeId],
/// and points to a specific position within the node by way of a
/// [nodePosition].
///
/// The type of the [nodePosition] depends upon the type of [DocumentNode]
/// that this position points to. For example, a [ParagraphNode]
/// uses a [TextPosition] to represent a [nodePosition].
class DocumentPosition {
  /// Creates a document position from its node ID and node-specific
  /// representation of the position.
  ///
  /// The [nodeId] references a [DocumentNode] within the document and the
  /// [nodePosition] adds node-specific context.
  ///
  /// For example, the following code creates a [DocumentPosition] that points
  /// to a [TextNode] and a text offset of `1` within that text node:
  ///
  /// ```dart
  /// final documentPosition = DocumentPosition(
  ///   nodeId: documentEditor.document.first.id,
  ///   nodePosition: TextNodePosition(offset: 1),
  /// );
  /// ```
  const DocumentPosition({
    required this.nodeId,
    required this.nodePosition,
  });

  factory DocumentPosition.withPath({
    required NodePath nodePath,
    required NodePosition nodePosition,
  }) {
    var resultPosition = nodePosition;
    for (var i = nodePath.length - 1; i > 0; i -= 1) {
      resultPosition = CompositeNodePosition(nodePath[i], resultPosition);
    }
    return DocumentPosition(nodeId: nodePath.rootNodeId, nodePosition: resultPosition);
  }

  /// ID of a [DocumentNode] within a [Document].
  final String nodeId;

  /// Node-specific representation of a position.
  ///
  /// For example: a paragraph node might use a [TextNodePosition].
  final NodePosition nodePosition;

  /// Whether this position within the document is equivalent to the given
  /// [other] [DocumentPosition].
  ///
  /// Equivalency is determined by the [NodePosition]. For example, given two
  /// [TextNodePosition]s, if both of them point to the same character, but one
  /// has an upstream affinity and the other a downstream affinity, the two
  /// [TextNodePosition]s are considered "non-equal", but they're considered
  /// "equivalent" because both [TextNodePosition]s point to the same location
  /// within the document.
  bool isEquivalentTo(DocumentPosition other) =>
      nodeId == other.nodeId && nodePosition.isEquivalentTo(other.nodePosition);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentPosition && nodeId == other.nodeId && nodePosition == other.nodePosition;

  @override
  int get hashCode => nodeId.hashCode ^ nodePosition.hashCode;

  /// Creates a new [DocumentPosition] based on the current position, with the
  /// provided parameters overridden.
  DocumentPosition copyWith({
    String? nodeId,
    NodePosition? nodePosition,
  }) {
    return DocumentPosition(
      nodeId: nodeId ?? this.nodeId,
      nodePosition: nodePosition ?? this.nodePosition,
    );
  }

  @override
  String toString() {
    return '[DocumentPosition] - node: "$nodeId", position: ($nodePosition)';
  }
}

/// A single content node within a [Document].
@immutable
abstract class DocumentNode {
  DocumentNode({
    Map<String, dynamic>? metadata,
  }) {
    // We construct a new map here, instead of directly assigning from the
    // constructor, because we need to make sure that `_metadata` is mutable.
    _metadata = {
      if (metadata != null) //
        ...metadata,
    };
  }

  /// Adds [addedMetadata] to this nodes [metadata].
  ///
  /// This protected method is intended to be used only during constructor
  /// initialization by subclasses, so that subclasses can inject needed metadata
  /// during construction time. This special method is provided because [DocumentNode]s
  /// are otherwise immutable.
  ///
  /// For example, a `ParagraphNode` might need to ensure that its block type
  /// metadata is set to `paragraphAttribution`:
  ///
  ///     ParagraphNode({
  ///       required super.id,
  ///       required super.text,
  ///       this.indent = 0,
  ///       super.metadata,
  ///     }) {
  ///       if (getMetadataValue("blockType") == null) {
  ///         initAddToMetadata({"blockType": paragraphAttribution});
  ///       }
  ///     }
  ///
  @protected
  void initAddToMetadata(Map<String, dynamic> addedMetadata) {
    _metadata.addAll(addedMetadata);
  }

  /// ID that is unique within a [Document].
  String get id;

  bool get isDeletable => _metadata[NodeMetadata.isDeletable] != false;

  /// Returns the [NodePosition] that corresponds to the beginning
  /// of content in this node.
  ///
  /// For example, a [ParagraphNode] would return [TextNodePosition(offset: 0)].
  NodePosition get beginningPosition;

  /// Returns the [NodePosition] that corresponds to the end of the
  /// content in this node.
  ///
  /// For example, a [ParagraphNode] would return [TextNodePosition(offset: text.length)].
  NodePosition get endPosition;

  /// Returns `true` if this [DocumentNode] contains the given [position], or `false`
  /// if the [position] doesn't sit within this node, or if the [position] type doesn't
  /// apply to this [DocumentNode].
  bool containsPosition(Object position);

  /// Inspects [position1] and [position2] and returns the one that's
  /// positioned further upstream in this [DocumentNode].
  ///
  /// For example, in a [TextNode], this returns the [TextPosition]
  /// for the character that appears earlier in the block of text.
  NodePosition selectUpstreamPosition(
    NodePosition position1,
    NodePosition position2,
  );

  /// Inspects [position1] and [position2] and returns the one that's
  /// positioned further downstream in this [DocumentNode].
  ///
  /// For example, in a [TextNode], this returns the [TextPosition]
  /// for the character that appears later in the block of text.
  NodePosition selectDownstreamPosition(
    NodePosition position1,
    NodePosition position2,
  );

  /// Returns a node-specific representation of a selection from
  /// [base] to [extent].
  ///
  /// For example, a [ParagraphNode] would return a [TextNodeSelection].
  NodeSelection computeSelection({
    required NodePosition base,
    required NodePosition extent,
  });

  /// Returns a plain-text version of the content in this node
  /// within [selection], or null if the given selection does
  /// not make sense as plain-text.
  String? copyContent(NodeSelection selection);

  /// Returns true if the [other] node is the same type as this
  /// node, and contains the same content.
  ///
  /// Content equivalency ignores the node ID.
  ///
  /// Content equivalency is used to determine if two documents are
  /// equivalent. Corresponding nodes in each document are compared
  /// with this method.
  bool hasEquivalentContent(DocumentNode other) {
    return const DeepCollectionEquality().equals(_metadata, other._metadata);
  }

  /// Returns all metadata attached to this [DocumentNode].
  Map<String, dynamic> get metadata => Map.from(_metadata);

  late final Map<String, dynamic> _metadata;

  /// Returns `true` if this node has a non-null metadata value for
  /// the given metadata [key], and returns `false`, otherwise.
  bool hasMetadataValue(String key) => _metadata[key] != null;

  /// Returns this node's metadata value for the given [key].
  dynamic getMetadataValue(String key) => _metadata[key];

  /// Returns a copy of this [DocumentNode] with [newProperties] added to
  /// the node's metadata.
  ///
  /// If [newProperties] contains keys that already exist in this node's
  /// metadata, the existing properties are overwritten by [newProperties].
  DocumentNode copyWithAddedMetadata(Map<String, dynamic> newProperties);

  /// Returns a copy of this [DocumentNode], replacing its existing
  /// metadata with [newMetadata].
  DocumentNode copyAndReplaceMetadata(Map<String, dynamic> newMetadata);

  /// Returns a copy of this node's metadata.
  Map<String, dynamic> copyMetadata() => Map.from(_metadata);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentNode &&
          runtimeType == other.runtimeType &&
          const DeepCollectionEquality().equals(_metadata, other._metadata);

  // We return an arbitrary number for the hashCode because the only
  // data we have is metadata, and different instances of metadata can
  // be equivalent. If we returned `_metadata.hashCode`, then two
  // `DocumentNode`s with equivalent metadata would say that they're
  // unequal, because the hashCodes would be different.
  @override
  int get hashCode => 1;
}

extension InspectNodeAffinity on DocumentNode {
  /// Returns the affinity direction implied by the given [base] and [extent].
  TextAffinity getAffinityBetween({
    required NodePosition base,
    required NodePosition extent,
  }) {
    return base == selectUpstreamPosition(base, extent) ? TextAffinity.downstream : TextAffinity.upstream;
  }
}

/// Marker interface for a selection within a [DocumentNode].
abstract class NodeSelection {
  // marker interface
}

/// A logical position within a [DocumentNode], e.g., a [TextNodePosition]
/// within a [ParagraphNode], or a [BinaryNodePosition] within an [ImageNode].
abstract class NodePosition {
  /// Whether this [NodePosition] is equivalent to the [other] [NodePosition].
  ///
  /// Typically, [isEquivalentTo] should return the same value as [==], however,
  /// some [NodePosition]s have properties that don't impact equivalency. For
  /// example, a [TextNodePosition] has a concept of affinity (upstream/downstream),
  /// which are used when making particular selection decisions, but affinity
  /// doesn't impact equivalency. Two [TextNodePosition]s, which refer to the same
  /// text offset, but have different affinities, returns `true` from [isEquivalentTo],
  /// even though [==] returns `false`.
  bool isEquivalentTo(NodePosition other);
}

/// Keys to access metadata on a [DocumentNode].
class NodeMetadata {
  /// The specific type of node, when the node itself isn't self-explanatory.
  ///
  /// For example, a `ParagraphNode` can have a block type for a paragraph,
  /// blockquote, header 1, header 2, etc.
  static const String blockType = 'blockType';

  /// A timestamp for the moment that a given node was created.
  ///
  /// The value should be a [CreatedAtAttribution], which allows the concept
  /// of a timestamp to work at the node level (with this metadata), as well
  /// as the text level (within an `AttributedText`).
  static const String createdAt = 'createdAt';

  /// Whether or not the node is deletable.
  ///
  /// A non-deletable node cannot be removed from the document by user
  /// interaction. For exammple, selecting a non-deletable node and pressing
  /// backspace has no effect.
  ///
  /// Apps can still remove non-deletable nodes by issuing a `DeleteNodeRequest`.
  ///
  /// If the node doesn't have this metadata, it is assumed to be deletable.
  static const String isDeletable = 'isDeletable';
}
