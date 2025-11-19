import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/default_editor/paragraph.dart';
import 'package:super_editor/src/infrastructure/serialization/quill/serializing/serializers.dart';

/// Extensions on [MutableDocument] for serializing a [MutableDocument]
/// to a Quill Delta document.
extension QuillDelta on MutableDocument {
  /// Serializes this [MutableDocument] to a Quill [Delta] document.
  ///
  /// The [MutableDocument] is converted to deltas, node-by-node. For
  /// each type of [DocumentNode] there is a [DeltaSerializer]. The
  /// serializers that are used to convert [DocumentNode]s into deltas
  /// can be configured by providing a custom list of [serializers].
  Delta toQuillDeltas({
    List<DeltaSerializer> serializers = defaultDeltaSerializers,
  }) {
    final deltaDocument = Delta();

    for (final node in this) {
      if (node is ParagraphNode && node == last && node.text.isEmpty && nodeCount > 1) {
        // This final, empty paragraph in the document represents the final
        // newline "\n" in the Delta document. But, due to how we serialize
        // deltas, the node/delta before this one already inserted a newline,
        // so we don't need to do anything with this empty node. Ignore it.
        continue;
      }

      // Try out each serializer until we find one that successfully serializes
      // this document node.
      bool didSerialize = false;
      for (int i = 0; i < serializers.length; i += 1) {
        didSerialize = serializers[i].serialize(node, deltaDocument);
        if (didSerialize) {
          // Go to next Super Editor document node.
          break;
        }
      }

      if (!didSerialize) {
        throw Exception("Failed to serialize Document to Quill Deltas. Couldn't find a serializer for node: $node");
      }
    }

    return deltaDocument;
  }
}

/// The serializers the are used by default to convert a Super Editor [Document] to a
/// Quill [Delta] document.
const defaultDeltaSerializers = [
  paragraphDeltaSerializer,
  listItemDeltaSerializer,
  taskDeltaSerializer,
  imageDeltaSerializer,
  videoDeltaSerializer,
  audioDeltaSerializer,
  fileDeltaSerializer,
];
