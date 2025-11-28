import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/foundation.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/default_editor/box_component.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';

/// [DocumentNode] that represents a video at a URL.
@immutable
class VideoNode extends UrlMediaNode {
  static const videoAttribution = NamedAttribution("video");

  VideoNode({
    required super.id,
    required super.url,
    super.altText = '',
    super.blockAttribution = videoAttribution,
  });

  @override
  DocumentNode copy() {
    return VideoNode(id: id, url: url, altText: altText, blockAttribution: blockquoteAttribution);
  }
}

/// [DocumentNode] that represents an audio source at a URL.
@immutable
class AudioNode extends UrlMediaNode {
  static const audioAttribution = NamedAttribution("audio");

  AudioNode({
    required super.id,
    required super.url,
    super.altText = '',
    super.blockAttribution = audioAttribution,
  });

  @override
  DocumentNode copy() {
    return AudioNode(id: id, url: url, altText: altText, blockAttribution: blockquoteAttribution);
  }
}

/// [DocumentNode] that represents a file at a URL.
@immutable
class FileNode extends UrlMediaNode {
  static const fileAttribution = NamedAttribution("file");

  FileNode({
    required super.id,
    required super.url,
    super.altText = '',
    super.blockAttribution = fileAttribution,
  });

  @override
  DocumentNode copy() {
    return FileNode(id: id, url: url, altText: altText, blockAttribution: blockquoteAttribution);
  }
}

/// [DocumentNode] that represents a media source that exists a given [url].
@immutable
class UrlMediaNode extends BlockNode {
  UrlMediaNode({
    required this.id,
    required this.url,
    this.altText = '',
    required Attribution blockAttribution,
    super.metadata,
  }) {
    initAddToMetadata({
      "blockType": blockAttribution,
    });
  }

  @override
  final String id;

  final String url;

  final String altText;

  @override
  String? copyContent(dynamic selection) {
    if (selection is! UpstreamDownstreamNodeSelection) {
      throw Exception('ImageNode can only copy content from a UpstreamDownstreamNodeSelection.');
    }

    return !selection.isCollapsed ? url : null;
  }

  @override
  bool hasEquivalentContent(DocumentNode other) {
    return other is UrlMediaNode && url == other.url && altText == other.altText;
  }

  @override
  UrlMediaNode copyAndReplaceMetadata(Map<String, dynamic> newMetadata) {
    return copyUrlMediaWith(
      metadata: newMetadata,
    );
  }

  @override
  UrlMediaNode copyWithAddedMetadata(Map<String, dynamic> newProperties) {
    return copyUrlMediaWith(metadata: {
      ...metadata,
      ...newProperties,
    });
  }

  UrlMediaNode copyUrlMediaWith({
    String? id,
    String? url,
    String? altText,
    Attribution? blockAttribution,
    Map<String, dynamic>? metadata,
  }) {
    return UrlMediaNode(
      id: id ?? this.id,
      url: url ?? this.url,
      blockAttribution: blockAttribution ?? this.metadata[NodeMetadata.blockType],
      metadata: metadata ?? this.metadata,
    );
  }

  DocumentNode copy() {
    return UrlMediaNode(
      id: id,
      url: url,
      altText: altText,
      blockAttribution: getMetadataValue("blockType"),
      metadata: metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UrlMediaNode &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          url == other.url &&
          altText == other.altText;

  @override
  int get hashCode => id.hashCode ^ url.hashCode ^ altText.hashCode;
}
