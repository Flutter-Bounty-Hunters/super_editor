import 'package:attributed_text/attributed_text.dart';
import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/default_editor/default_document_editor.dart';
import 'package:super_editor/src/default_editor/multi_node_editing.dart';
import 'package:super_editor/src/default_editor/paragraph.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/serialization/quill/parsing/block_formats.dart';
import 'package:super_editor/src/infrastructure/serialization/quill/parsing/inline_formats.dart';

/// Parses a fully formed Quill Delta document (as JSON) into a [MutableDocument].
///
/// The format of a Delta document looks like:
///
///     {
///       "ops": [
///         ...
///       ]
///     }
///
/// {@template parse_deltas_custom_editor}
/// An [Editor] is used to insert content in the final document. For typical Delta
/// formats, the default configuration for an [Editor] should work fine, and that's
/// what this method uses. However, some apps need to run custom commands, especially
/// for custom inline embeds. In that case, you can provide a [customEditor], which
/// is configured however you'd like. The [customEditor] must contain a [MutableDocument]
/// and a [MutableComposer]. The document must be empty.
/// {@endtemplate}
///
/// {@template merge_consecutive_blocks}
/// ### Merging consecutive blocks
///
/// The Delta format creates some ambiguity around when multiple lines should
/// be combined into a single block vs one block per line. E.g., a code block
/// with multiple lines of code vs a series of independent code blocks.
///
/// [blockMergeRules] explicitly tells the parser which consecutive
/// [DocumentNode]s should be merged together when not separated by an unstyled
/// newline in the given deltas.
///
/// Example of consecutive code blocks that would be merged (if requested):
///
///     [
///       { "insert": "Code line one" },
///       { "insert": "\n", "attributed": { "code-block": "plain"} },
///       { "insert": "Code line two" },
///       { "insert": "\n", "attributed": { "code-block": "plain"} },
///     ]
///
/// Example of code blocks, separated by an unstyled newline, that wouldn't be merged:
///
///     [
///       { "insert": "Code line one" },
///       { "insert": "\n", "attributed": { "code-block": "plain"} },
///       { "insert": "\n" },
///       { "insert": "Code line two" },
///       { "insert": "\n", "attributed": { "code-block": "plain"} },
///     ]
///
/// {@endtemplate}
///
/// For more information about the Quill Delta format, see the official
/// documentation: https://quilljs.com/docs/delta/
MutableDocument parseQuillDeltaDocument(
  Map<String, dynamic> deltaDocument, {
  Editor? customEditor,
  List<BlockDeltaFormat> blockFormats = defaultBlockFormats,
  List<DeltaBlockMergeRule> blockMergeRules = defaultBlockMergeRules,
  List<InlineDeltaFormat> inlineFormats = defaultInlineFormats,
  List<InlineEmbedFormat> inlineEmbedFormats = const [],
  List<BlockDeltaFormat> embedBlockFormats = defaultEmbedBockFormats,
}) {
  return parseQuillDeltaOps(
    deltaDocument["ops"],
    customEditor: customEditor,
    blockMergeRules: blockMergeRules,
    blockFormats: blockFormats,
    inlineFormats: inlineFormats,
    inlineEmbedFormats: inlineEmbedFormats,
    embedBlockFormats: embedBlockFormats,
  );
}

/// Parses a list of Quill Delta operations (as JSON) into a [MutableDocument].
///
/// This parser is the same as [parseQuillDeltaDocument] except that this method
/// directly accepts the operations list instead of the whole document map. This
/// method is provided for convenience because in some situations only the
/// operations are exchanged, rather than the whole document object.
///
/// {@macro parse_deltas_custom_editor}
///
/// {@macro merge_consecutive_blocks}
MutableDocument parseQuillDeltaOps(
  List<dynamic> deltaOps, {
  Editor? customEditor,
  List<BlockDeltaFormat> blockFormats = defaultBlockFormats,
  List<DeltaBlockMergeRule> blockMergeRules = defaultBlockMergeRules,
  List<InlineDeltaFormat> inlineFormats = defaultInlineFormats,
  List<InlineEmbedFormat> inlineEmbedFormats = const [],
  List<BlockDeltaFormat> embedBlockFormats = defaultEmbedBockFormats,
}) {
  // Deserialize the delta operations JSON into a Dart data structure.
  final deltaDocument = Delta.fromJson(deltaOps);

  late final MutableDocument document;
  late final MutableDocumentComposer composer;
  late final Editor editor;
  if (customEditor != null) {
    // Use the provided custom editor.
    if (customEditor.context.maybeDocument == null) {
      throw Exception("The provided customEditor must contain a MutableDocument in its editables.");
    }
    if (customEditor.context.maybeComposer == null) {
      throw Exception("The provided customEditor must contain a MutableDocumentComposer in its editables.");
    }

    editor = customEditor;
    document = editor.context.document;
    composer = editor.context.composer;

    if (document.nodeCount > 1 ||
        document.first is! ParagraphNode ||
        (document.first as ParagraphNode).text.length > 0) {
      throw Exception("The customEditor document must be empty (contain a single, empty ParagraphNode).");
    }
  } else {
    // Create a new, empty Super Editor document.
    document = MutableDocument.empty();
    composer = MutableDocumentComposer();
    editor = Editor(
      editables: {
        Editor.documentKey: document,
        Editor.composerKey: composer,
      },
      requestHandlers: List.from(defaultRequestHandlers),
      // No reactions. Follow the delta operations exactly.
      reactionPipeline: [],
    );
  }

  // Place the caret in the (only) empty paragraph so we can begin applying
  // deltas to the document.
  final firstParagraph = document.first as ParagraphNode;
  composer.setSelectionWithReason(
    DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: firstParagraph.id,
        nodePosition: const TextNodePosition(offset: 0),
      ),
    ),
    SelectionReason.contentChange,
  );

  // Run every Quill Delta operation on the empty document. At the end of this
  // process the Super Editor document will reflect the desired Quill Delta
  // document state.
  for (final delta in deltaDocument.operations) {
    delta.applyToDocument(
      editor,
      blockFormats: blockFormats,
      blockMergeRules: blockMergeRules,
      inlineFormats: inlineFormats,
      inlineEmbedFormats: inlineEmbedFormats,
      embedBlockFormats: embedBlockFormats,
    );
  }

  return document;
}

/// The standard block-level text formats that are parsed from Quill Deltas,
/// e.g., headers, blockquotes, list items.
const defaultBlockFormats = [
  HeaderDeltaFormat(),
  BlockquoteDeltaFormat(),
  CodeBlockDeltaFormat(),
  ListDeltaFormat(),
  AlignDeltaFormat(),
  IndentParagraphDeltaFormat(),
];

/// The standard inline text formats that are parsed from Quill Deltas, e.g.,
/// bold, italics, underline, links.
const defaultInlineFormats = [
  // Named inline attributes (no parsing).
  NamedInlineDeltaFormat("bold", boldAttribution),
  NamedInlineDeltaFormat("italic", italicsAttribution),
  NamedInlineDeltaFormat("underline", underlineAttribution),
  NamedInlineDeltaFormat("strike", strikethroughAttribution),
  NamedInlineDeltaFormat("code", codeAttribution),

  // Inline attributes with parsed values.
  ColorDeltaFormat(),
  BackgroundColorDeltaFormat(),
  ScriptDeltaFormat(),
  FontFamilyDeltaFormat(),
  SizeDeltaFormat(),
  LinkDeltaFormat(),
];

/// The standard block-level embed formats that are parsed from Quill Deltas,
/// e.g., images, audio, video.
const defaultEmbedBockFormats = [
  ImageEmbedBlockDeltaFormat(),
  VideoEmbedBlockDeltaFormat(),
  AudioEmbedBlockDeltaFormat(),
  FileEmbedBlockDeltaFormat(),
];

/// An extension on Quill Delta [Operation]s that adds the ability for an operation to
/// apply itself to a Super Editor document through an [Editor].
extension OperationParser on Operation {
  /// Applies this operation to a Super Editor document by sending requests
  /// through the given [editor].
  ///
  /// To configure how a given Quill Delta attribute impacts text blocks and text spans,
  /// provide the desired [blockFormats] and [inlineFormats]. For example, the recognition
  /// of an attribute called "bold", and the application of a [boldAttribution] to the
  /// Super Editor document, is implemented by the [BlockDeltaFormat], which should be
  /// included in [inlineFormats].
  void applyToDocument(
    Editor editor, {
    required List<BlockDeltaFormat> blockFormats,
    List<DeltaBlockMergeRule> blockMergeRules = defaultBlockMergeRules,
    required List<InlineDeltaFormat> inlineFormats,
    required List<InlineEmbedFormat> inlineEmbedFormats,
    required List<BlockDeltaFormat> embedBlockFormats,
  }) {
    final document = editor.context.find<MutableDocument>(Editor.documentKey);
    final composer = editor.context.find<MutableDocumentComposer>(Editor.composerKey);

    switch (type) {
      case DeltaOperationType.insert:
        if (data is String) {
          // This is a text insertion delta.
          _doInsertText(editor, composer, blockFormats, inlineFormats);
        }
        if (data is Object) {
          // This is an embed insertion delta.
          _doInsertMedia(editor, composer, inlineEmbedFormats, embedBlockFormats);
        }

        // Merge consecutive blocks as desired by the given node types.
        final document = editor.context.find<MutableDocument>(Editor.documentKey);
        if (document.nodeCount < 3) {
          // Minimum of 3 nodes: block, block, newline.
          break;
        }

        // Beginning with the last non-empty node, move backwards, collecting all
        // nodes that should be merged into one.
        final nodeBeforeTrailingNewline = document.getNodeBefore(document.last)!;
        final blockTypeToMerge = nodeBeforeTrailingNewline.getMetadataValue(NodeMetadata.blockType);
        var blocksToMerge = <ParagraphNode>[];
        for (int i = document.nodeCount - 2; i >= 0; i -= 1) {
          final node = document.getNodeAt(i)!;
          if (node is! ParagraphNode) {
            break;
          }

          var shouldMerge = false;
          for (final rule in blockMergeRules) {
            final ruleShouldMerge = rule.shouldMerge(blockTypeToMerge, node.getMetadataValue(NodeMetadata.blockType));
            if (ruleShouldMerge == true) {
              // The rule says we definitely want to merge.
              shouldMerge = true;
              break;
            }
            if (ruleShouldMerge == false) {
              // The rule says we definitely don't want to merge.
              shouldMerge = false;
              break;
            }
          }
          if (!shouldMerge) {
            // Our merge rules don't want us to merge this node.
            break;
          }

          blocksToMerge.add(node);
        }

        if (blocksToMerge.length < 2) {
          break;
        }

        blocksToMerge = blocksToMerge.reversed.toList();
        final mergeNode = blocksToMerge.first;
        var nodeContentToMove = blocksToMerge[1].text.insertString(textToInsert: "\n", startOffset: 0);
        for (int i = 2; i < blocksToMerge.length; i += 1) {
          nodeContentToMove =
              nodeContentToMove.copyAndAppend(blocksToMerge[i].text.insertString(textToInsert: "\n", startOffset: 0));
        }

        editor.execute([
          InsertAttributedTextRequest(
            DocumentPosition(nodeId: mergeNode.id, nodePosition: mergeNode.endPosition),
            nodeContentToMove,
          ),
          for (int i = 1; i < blocksToMerge.length; i += 1) //
            DeleteNodeRequest(nodeId: blocksToMerge[i].id),
        ]);

      case DeltaOperationType.retain:
        final count = data as int;
        final newPosition = _findPositionDownstream(document, composer, count);
        editor.execute([
          ChangeSelectionRequest(
            DocumentSelection.collapsed(position: newPosition),
            SelectionChangeType.pushCaret,
            SelectionReason.contentChange,
          ),
        ]);

      case DeltaOperationType.delete:
        final count = data as int;
        final newPosition = _findPositionDownstream(document, composer, count);
        editor.execute([
          DeleteContentRequest(
            documentRange: DocumentRange(
              start: composer.selection!.extent,
              end: newPosition,
            ),
          ),
        ]);
    }
  }

  void _doInsertText(
    Editor editor,
    DocumentComposer composer,
    List<BlockDeltaFormat> blockFormats,
    List<InlineDeltaFormat> inlineFormats,
  ) {
    final changeRequests = <EditRequest>[];

    // Apply block attributes *before* inserting the new delta text.
    //
    // For example, consider the following deltas:
    //
    //     ops: [
    //       { insert: 'Welcome Header' },
    //       { insert: '\n', attributes: { "header": 1 } },
    //       { insert: 'This is the content' }
    //     ]
    //
    // Notice that the "header" attribute is included in the delta that follows
    // the actual header text. That's the behavior we're implementing by applying
    // block formats here *before* inserting any new text.
    for (final blockFormat in blockFormats) {
      final blockChanges = blockFormat.applyTo(this, editor);
      if (blockChanges != null) {
        changeRequests.addAll(blockChanges);

        // We found a format that handled this delta. Ignore the remaining
        // formats.
        //
        // If a situation is found where multiple formats need to act on the same
        // delta, please file an issue with an explanation.
        break;
      }
    }

    // Insert new delta text and apply inline attributes.
    //
    // The process of inserting text also requires that we handle newline characters.
    // Each newline needs to add a new paragraph. Newlines can appear at the beginning,
    // the end, and in the middle of a single text insertion.
    var text = data as String;
    var currentNodeId = composer.selection!.extent.nodeId;
    var currentTextPosition = composer.selection!.extent.nodePosition as TextNodePosition;

    // The included inline attributes apply to all text within this insert operation.
    final inlineAttributions = <Attribution>{};
    for (final inlineFormat in inlineFormats) {
      final attribution = inlineFormat.from(this);
      if (attribution != null) {
        inlineAttributions.add(attribution);
      }
    }

    // Break the insertion text at every newline so we can insert paragraphs.
    final textPerLine = text.split("\n");
    for (int i = 0; i < textPerLine.length; i += 1) {
      final line = textPerLine[i];
      final newNodeId = Editor.createNodeId();

      changeRequests.addAll([
        // Insert a line of text.
        InsertTextRequest(
          documentPosition: DocumentPosition(
            nodeId: currentNodeId,
            nodePosition: currentTextPosition,
          ),
          textToInsert: line,
          attributions: line.isNotEmpty ? inlineAttributions : {},
        ),
        // Every line of text is followed by a newline, except the last
        // line. If this isn't the last line, add a new paragraph.
        if (i < textPerLine.length - 1) ...[
          InsertNodeAfterNodeRequest(
            existingNodeId: currentNodeId,
            newNode: ParagraphNode(
              id: newNodeId,
              text: AttributedText(""),
            ),
          ),
          ChangeSelectionRequest(
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: newNodeId,
                nodePosition: const TextNodePosition(offset: 0),
              ),
            ),
            SelectionChangeType.insertContent,
            SelectionReason.contentChange,
          ),
        ],
      ]);

      if (i < textPerLine.length - 1) {
        // This isn't the last line, so we added a new paragraph. Update the node ID.
        currentNodeId = newNodeId;
        currentTextPosition = const TextNodePosition(offset: 0);
      }
    }

    // Execute the block changes and inline text insertions.
    editor.execute(changeRequests);
  }

  void _doInsertMedia(
    Editor editor,
    DocumentComposer composer,
    List<InlineEmbedFormat> inlineEmbedFormats,
    List<BlockDeltaFormat> embedBlockFormats,
  ) {
    final content = data;
    if (content is! Map<String, dynamic>) {
      // Quill Deltas expect embeds to be a map, but the data isn't a map.
      return;
    }

    // First, try to interpret this operation as an inline embed and insert it.
    final didInlineInsert = _maybeInsertInlineEmbed(editor, composer, inlineEmbedFormats, content);
    if (didInlineInsert) {
      return;
    }

    // This operation wasn't a known inline embed. Try inserting as a block embed.
    _maybeInsertBlockEmbed(editor, composer, embedBlockFormats);
  }

  /// Attempts to interpret this operation as an inline embed and insert it, returning `true`
  /// if successful, or `false` if this operation isn't a known inline embed.
  bool _maybeInsertInlineEmbed(
    Editor editor,
    DocumentComposer composer,
    List<InlineEmbedFormat> inlineEmbedFormats,
    Map<String, dynamic> data,
  ) {
    for (final inlineEmbedFormat in inlineEmbedFormats) {
      final didInsert = inlineEmbedFormat.insert(editor, composer, data);
      if (didInsert) {
        // We found a format that handled this inline embed. Ignore the remaining
        // formats.
        //
        // If a situation is found where multiple formats need to act on the same
        // embed, please file an issue with an explanation.
        return true;
      }
    }

    return false;
  }

  /// Attempts to interpret this operation as a block embed and insert it, returning `true`
  /// if successful, or `false` if this operation isn't a known block embed.
  bool _maybeInsertBlockEmbed(
    Editor editor,
    DocumentComposer composer,
    List<BlockDeltaFormat> embedBlockFormats,
  ) {
    for (final embedBlockFormat in embedBlockFormats) {
      final editorOperations = embedBlockFormat.applyTo(this, editor);
      if (editorOperations == null) {
        // This block format doesn't apply to this operation. Check the next one.
        continue;
      }

      // This block format parsed this operation and gave us a list of editor
      // operations to insert the embed. Execute them and return.
      editor.execute(editorOperations);
      return true;
    }

    // This operation wasn't recognized as a block-level embed and nothing was deserialized.
    return false;
  }

  /// Moves [count] units downstream from the current caret position.
  ///
  /// The distance of each unit in [count] is defined by the Delta spec. In text, a unit
  /// is a character. In media, such as videos or images, a unit is the whole media item.
  DocumentPosition _findPositionDownstream(Document document, DocumentComposer composer, int count) {
    var caretPosition = composer.selection!.extent;
    var selectedNode = document.getNodeById(caretPosition.nodeId)!;
    int unitsToMove = count;

    while (unitsToMove > 0) {
      if (selectedNode is TextNode) {
        final currentPosition = caretPosition.nodePosition as TextNodePosition;

        if (selectedNode.text.length - currentPosition.offset >= unitsToMove) {
          // The caret wants to move somewhere in this paragraph. Return that position.
          return DocumentPosition(
            nodeId: selectedNode.id,
            nodePosition: TextNodePosition(offset: currentPosition.offset + unitsToMove),
          );
        }

        // The caret wants to move beyond this paragraph.
        unitsToMove -= selectedNode.text.length - currentPosition.offset;
        selectedNode = document.getNodeAfterById(selectedNode.id)!;
        caretPosition = DocumentPosition(
          nodeId: selectedNode.id,
          nodePosition: selectedNode.beginningPosition,
        );
      } else {
        // This is a block node. The caret either sits on the upstream side or
        // the downstream side.
        if (unitsToMove == 1) {
          // The deltas want to move across this block to the downstream side.
          // Return that position.
          return DocumentPosition(
            nodeId: selectedNode.id,
            nodePosition: selectedNode.endPosition,
          );
        }

        // The deltas want to retain more beyond this node.
        unitsToMove -= 1;
        selectedNode = document.getNodeAfterById(selectedNode.id)!;
        caretPosition = DocumentPosition(
          nodeId: selectedNode.id,
          nodePosition: selectedNode.beginningPosition,
        );
      }
    }

    return caretPosition;
  }

  /// Returns the [DeltaOperationType] of this operation.
  ///
  /// The [DeltaOperationType] is provided so that developers can use a `switch`
  /// statement to handle all operation types, rather than repeated if-statements
  /// on [isInsert], [isRetain], and [isDelete].
  DeltaOperationType get type {
    if (isInsert) {
      return DeltaOperationType.insert;
    } else if (isRetain) {
      return DeltaOperationType.retain;
    } else if (isDelete) {
      return DeltaOperationType.delete;
    } else {
      throw Exception("Unknown operation type: $this");
    }
  }
}

enum DeltaOperationType {
  insert,
  retain,
  delete,
}

/// The standard set of [DeltaBlockMergeRule]s used when parsing Quill Deltas.
const defaultBlockMergeRules = [
  MergeBlock(blockquoteAttribution),
  MergeBlock(codeAttribution),
];

/// A rule that decides whether a given [DocumentNode] should be merged into
/// the node before it, when creating a [Document] from Quill Deltas.
///
/// This is useful, for example, to place multiple lines of code within a
/// single code block.
abstract interface class DeltaBlockMergeRule {
  /// Returns `true` if two consecutive blocks with the given types should merge,
  /// `false` if they shouldn't, or `null` if this rule has no opinion about the merge.
  bool? shouldMerge(Attribution block1, Attribution block2);
}

/// A [DeltaBlockMergeRule] that chooses to merge blocks whose type `==`
/// the given block type.
class MergeBlock implements DeltaBlockMergeRule {
  const MergeBlock(this._blockType);

  final Attribution _blockType;

  @override
  bool? shouldMerge(Attribution block1, Attribution block2) {
    if (block1 == _blockType && block2 == _blockType) {
      // Yes, try to merge them.
      return true;
    }

    // This isn't our block type. We don't have an opinion.
    return null;
  }
}
