import 'package:attributed_text/attributed_text.dart' show AttributedText;
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/default_editor/box_component.dart';
import 'package:super_editor/src/default_editor/composer/composer_reactions.dart';
import 'package:super_editor/src/default_editor/list_items.dart';
import 'package:super_editor/src/default_editor/multi_node_editing.dart';
import 'package:super_editor/src/default_editor/paragraph.dart';
import 'package:super_editor/src/default_editor/tasks.dart';
import 'package:super_editor/src/default_editor/text.dart';

import 'common_editor_operations.dart';
import 'default_document_editor_reactions.dart';

Editor createDefaultDocumentEditor({
  MutableDocument? document,
  MutableDocumentComposer? composer,
  HistoryGroupingPolicy historyGroupingPolicy = defaultMergePolicy,
  bool isHistoryEnabled = false,
}) {
  final editor = Editor(
    editables: {
      Editor.documentKey: document ?? MutableDocument.empty(),
      Editor.composerKey: composer ?? MutableDocumentComposer(),
    },
    requestHandlers: List.from(defaultRequestHandlers),
    historyGroupingPolicy: historyGroupingPolicy,
    reactionPipeline: List.from(defaultEditorReactions),
    isHistoryEnabled: isHistoryEnabled,
  );

  return editor;
}

final defaultRequestHandlers = List.unmodifiable(<EditRequestHandler>[
  (editor, request) => request is ChangeSelectionRequest
      ? ChangeSelectionCommand(
          request.newSelection,
          request.changeType,
          request.reason,
          notifyListeners: request.notifyListeners,
        )
      : null,
  (editor, request) => request is ClearSelectionRequest
      ? const ChangeSelectionCommand(
          null,
          SelectionChangeType.clearSelection,
          SelectionReason.userInteraction,
        )
      : null,
  (editor, request) => request is ChangeComposingRegionRequest //
      ? ChangeComposingRegionCommand(request.composingRegion)
      : null,
  (editor, request) => request is ClearComposingRegionRequest //
      ? ChangeComposingRegionCommand(null)
      : null,
  (editor, request) => request is ChangeInteractionModeRequest //
      ? ChangeInteractionModeCommand(isInteractionModeDesired: request.isInteractionModeDesired)
      : null,
  (editor, request) => request is RemoveComposerPreferenceStylesRequest //
      ? RemoveComposerPreferenceStylesCommand(request.stylesToRemove)
      : null,

  //--- Start text insertion ---
  (editor, request) => request is InsertStyledTextAtCaretRequest //
      ? InsertStyledTextAtCaretCommand(request.text, createdAt: request.createdAt)
      : null,
  (editor, request) => request is InsertInlinePlaceholderAtCaretRequest //
      ? InsertInlinePlaceholderAtCaretCommand(request.placeholder, createdAt: request.createdAt)
      : null,
  (editor, request) => request is InsertPlainTextAtEndOfDocumentRequest //
      ? InsertStyledTextAtEndOfDocumentCommand(
          AttributedText(request.text),
          newNodeId: request.newNodeId,
          createdAt: request.createdAt,
        )
      : null,
  (editor, request) => request is InsertStyledTextAtEndOfDocumentRequest //
      ? InsertStyledTextAtEndOfDocumentCommand(request.text, newNodeId: request.newNodeId, createdAt: request.createdAt)
      : null,
  (editor, request) => request is InsertTextRequest
      ? InsertTextCommand(
          documentPosition: request.documentPosition,
          textToInsert: request.textToInsert,
          attributions: request.attributions,
          createdAt: request.createdAt,
        )
      : null,
  (editor, request) => request is InsertAttributedTextRequest
      ? InsertAttributedTextCommand(
          documentPosition: request.documentPosition,
          textToInsert: request.textToInsert,
          createdAt: request.createdAt,
        )
      : null,
  (editor, request) => request is InsertSoftNewlineAtCaretRequest //
      ? const InsertSoftNewlineCommand()
      : null,
  (editor, request) {
    if (request is! InsertNewlineAtCaretRequest) {
      return null;
    }

    final selection = editor.composer.selection;
    if (selection == null) {
      return null;
    }

    final base = selection.base;
    if (editor.document.getNodeById(base.nodeId) is! ListItemNode) {
      return null;
    }

    return InsertNewlineInListItemAtCaretCommand(request.newNodeId);
  },
  (editor, request) {
    if (request is! InsertNewlineAtCaretRequest) {
      return null;
    }

    final selection = editor.composer.selection;
    if (selection == null) {
      return null;
    }

    final base = selection.base;
    final node = editor.document.getNodeById(base.nodeId);
    if (node is! ParagraphNode) {
      return null;
    }
    if (node.metadata[NodeMetadata.blockType] != codeAttribution) {
      return null;
    }

    return InsertNewlineInCodeBlockAtCaretCommand(request.newNodeId);
  },
  (editor, request) {
    if (request is! InsertNewlineAtCaretRequest) {
      return null;
    }

    final selection = editor.composer.selection;
    if (selection == null) {
      return null;
    }

    final base = selection.base;
    if (editor.document.getNodeById(base.nodeId) is! TaskNode) {
      return null;
    }

    return InsertNewlineInTaskAtCaretCommand(request.newNodeId);
  },
  (editor, request) => request is InsertNewlineAtCaretRequest //
      ? DefaultInsertNewlineAtCaretCommand(request.newNodeId)
      : null,
  //---- End text insertion ----

  (editor, request) => request is PasteStructuredContentEditorRequest
      ? PasteStructuredContentEditorCommand(
          content: request.content,
          pastePosition: request.pastePosition,
        )
      : null,
  (editor, request) => request is InsertNodeAtEndOfDocumentRequest
      ? InsertNodeAtIndexCommand(nodeIndex: editor.document.length, newNode: request.newNode)
      : null,
  (editor, request) => request is InsertNodeAtIndexRequest
      ? InsertNodeAtIndexCommand(nodeIndex: request.nodeIndex, newNode: request.newNode)
      : null,
  (editor, request) => request is InsertNodeBeforeNodeRequest
      ? InsertNodeBeforeNodeCommand(existingNodeId: request.existingNodeId, newNode: request.newNode)
      : null,
  (editor, request) => request is InsertNodeAfterNodeRequest
      ? InsertNodeAfterNodeCommand(existingNodeId: request.existingNodeId, newNode: request.newNode)
      : null,
  (editor, request) => request is InsertNodeAtCaretRequest //
      ? InsertNodeAtCaretCommand(newNode: request.node)
      : null,
  (editor, request) => request is MoveNodeRequest //
      ? MoveNodeCommand(nodeId: request.nodeId, newIndex: request.newIndex)
      : null,
  (editor, request) => request is CombineParagraphsRequest
      ? CombineParagraphsCommand(firstNodeId: request.firstNodeId, secondNodeId: request.secondNodeId)
      : null,
  (editor, request) => request is ReplaceNodeRequest
      ? ReplaceNodeCommand(existingNodeId: request.existingNodeId, newNode: request.newNode)
      : null,
  (editor, request) => request is ReplaceNodeWithEmptyParagraphWithCaretRequest
      ? ReplaceNodeWithEmptyParagraphWithCaretCommand(nodeId: request.nodeId)
      : null,
  (editor, request) => request is DeleteContentRequest //
      ? DeleteContentCommand(documentRange: request.documentRange)
      : null,
  (editor, request) => request is DeleteSelectionRequest //
      ? DeleteSelectionCommand(affinity: request.affinity)
      : null,
  (editor, request) => request is DeleteUpstreamAtBeginningOfNodeRequest && request.node is ListItemNode
      ? ConvertListItemToParagraphCommand(nodeId: request.node.id, paragraphMetadata: request.node.metadata)
      : null,
  (editor, request) => request is DeleteUpstreamAtBeginningOfNodeRequest && request.node is ParagraphNode
      ? DeleteUpstreamAtBeginningOfParagraphCommand(request.node)
      : null,
  (editor, request) => request is DeleteUpstreamAtBeginningOfNodeRequest && request.node is BlockNode
      ? DeleteUpstreamAtBeginningOfBlockNodeCommand(request.node)
      : null,
  (editor, request) => request is DeleteNodeRequest //
      ? DeleteNodeCommand(nodeId: request.nodeId)
      : null,
  (editor, request) => request is ClearDocumentRequest //
      ? ClearDocumentCommand()
      : null,
  (editor, request) => request is DeleteUpstreamCharacterRequest //
      ? const DeleteUpstreamCharacterCommand()
      : null,
  (editor, request) => request is DeleteDownstreamCharacterRequest //
      ? const DeleteDownstreamCharacterCommand()
      : null,
  (editor, request) => request is InsertCharacterAtCaretRequest
      ? InsertCharacterAtCaretCommand(
          character: request.character,
          ignoreComposerAttributions: request.ignoreComposerAttributions,
          newNodeId: request.newNodeId,
        )
      : null,
  (editor, request) => request is InsertPlainTextAtCaretRequest //
      ? InsertPlainTextAtCaretCommand(
          request.plainText,
          attributions: editor.composer.preferences.currentAttributions,
          createdAt: request.createdAt,
        )
      : null,
  (editor, request) => request is InsertTextRequest
      ? InsertTextCommand(
          documentPosition: request.documentPosition,
          textToInsert: request.textToInsert,
          attributions: request.attributions)
      : null,
  (editor, request) => request is ChangeParagraphAlignmentRequest
      ? ChangeParagraphAlignmentCommand(
          nodeId: request.nodeId,
          alignment: request.alignment,
        )
      : null,
  (editor, request) => request is IndentParagraphRequest
      ? IndentParagraphCommand(
          request.nodeId,
        )
      : null,
  (editor, request) => request is UnIndentParagraphRequest
      ? UnIndentParagraphCommand(
          request.nodeId,
        )
      : null,
  (editor, request) => request is SetParagraphIndentRequest
      ? SetParagraphIndentCommand(
          request.nodeId,
          level: request.level,
        )
      : null,
  (editor, request) => request is ChangeParagraphBlockTypeRequest
      ? ChangeParagraphBlockTypeCommand(
          nodeId: request.nodeId,
          blockType: request.blockType,
        )
      : null,
  (editor, request) => request is SplitParagraphRequest
      ? SplitParagraphCommand(
          nodeId: request.nodeId,
          splitPosition: request.splitPosition,
          newNodeId: request.newNodeId,
          replicateExistingMetadata: request.replicateExistingMetadata,
          attributionsToExtendToNewParagraph: request.attributionsToExtendToNewParagraph,
        )
      : null,
  (editor, request) => request is ConvertParagraphToTaskRequest
      ? ConvertParagraphToTaskCommand(
          nodeId: request.nodeId,
          isComplete: request.isComplete,
        )
      : null,
  (editor, request) => request is ConvertTaskToParagraphRequest
      ? ConvertTaskToParagraphCommand(
          nodeId: request.nodeId,
          paragraphMetadata: request.paragraphMetadata,
        )
      : null,
  (editor, request) => request is DeleteUpstreamAtBeginningOfNodeRequest && request.node is TaskNode
      ? ConvertTaskToParagraphCommand(nodeId: request.node.id, paragraphMetadata: request.node.metadata)
      : null,
  (editor, request) => request is ChangeTaskCompletionRequest
      ? ChangeTaskCompletionCommand(
          nodeId: request.nodeId,
          isComplete: request.isComplete,
        )
      : null,
  (editor, request) => request is IndentTaskRequest //
      ? IndentTaskCommand(request.nodeId)
      : null,
  (editor, request) => request is UnIndentTaskRequest //
      ? UnIndentTaskCommand(request.nodeId)
      : null,
  (editor, request) => request is SetTaskIndentRequest //
      ? SetTaskIndentCommand(request.nodeId, request.indent)
      : null,
  (editor, request) => request is SplitExistingTaskRequest
      ? SplitExistingTaskCommand(
          nodeId: request.existingNodeId,
          splitOffset: request.splitOffset,
          newNodeId: request.newNodeId,
        )
      : null,
  (editor, request) => request is SplitListItemRequest
      ? SplitListItemCommand(
          nodeId: request.nodeId,
          splitPosition: request.splitPosition,
          newNodeId: request.newNodeId,
        )
      : null,
  (editor, request) => request is IndentListItemRequest //
      ? IndentListItemCommand(nodeId: request.nodeId)
      : null,
  (editor, request) => request is UnIndentListItemRequest //
      ? UnIndentListItemCommand(nodeId: request.nodeId)
      : null,
  (editor, request) => request is ChangeListItemTypeRequest
      ? ChangeListItemTypeCommand(nodeId: request.nodeId, newType: request.newType)
      : null,
  (editor, request) => request is ConvertListItemToParagraphRequest //
      ? ConvertListItemToParagraphCommand(nodeId: request.nodeId, paragraphMetadata: request.paragraphMetadata)
      : null,
  (editor, request) => request is ConvertParagraphToListItemRequest
      ? ConvertParagraphToListItemCommand(nodeId: request.nodeId, type: request.type)
      : null,
  (editor, request) => request is AddTextAttributionsRequest
      ? AddTextAttributionsCommand(
          documentRange: request.documentRange,
          attributions: request.attributions,
          autoMerge: request.autoMerge,
        )
      : null,
  (editor, request) => request is ToggleTextAttributionsRequest
      ? ToggleTextAttributionsCommand(documentRange: request.documentRange, attributions: request.attributions)
      : null,
  (editor, request) => request is RemoveTextAttributionsRequest
      ? RemoveTextAttributionsCommand(documentRange: request.documentRange, attributions: request.attributions)
      : null,
  (editor, request) => request is ChangeSingleColumnLayoutComponentStylesRequest
      ? ChangeSingleColumnLayoutComponentStylesCommand(nodeId: request.nodeId, styles: request.styles) //
      : null,
  (editor, request) => request is ConvertTextNodeToParagraphRequest
      ? ConvertTextNodeToParagraphCommand(nodeId: request.nodeId, newMetadata: request.newMetadata)
      : null,
  (editor, request) => request is PasteEditorRequest
      ? PasteEditorCommand(
          content: request.content,
          pastePosition: request.pastePosition,
        )
      : null,
]);

final defaultEditorReactions = List.unmodifiable([
  UpdateComposerTextStylesReaction(),
  const LinkifyReaction(),

  //---- Start Content Conversions ----
  HeaderConversionReaction(),
  const UnorderedListItemConversionReaction(),
  const OrderedListItemConversionReaction(),
  const BlockquoteConversionReaction(),
  const HorizontalRuleConversionReaction(),
  const ImageUrlConversionReaction(),
  const DashConversionReaction(),
  //---- End Content Conversions ---

  UpdateSubTaskIndentAfterTaskDeletionReaction(),
]);
