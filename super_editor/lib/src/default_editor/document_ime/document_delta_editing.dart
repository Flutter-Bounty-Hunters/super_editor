import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/default_editor/common_editor_operations.dart';
import 'package:super_editor/src/default_editor/document_ime/document_serialization.dart';
import 'package:super_editor/src/default_editor/multi_node_editing.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/platforms/platform.dart';

/// Applies software keyboard text deltas to a document.
class TextDeltasDocumentEditor {
  TextDeltasDocumentEditor({
    required this.editor,
    required this.document,
    required this.documentLayoutResolver,
    required this.selection,
    required this.composerPreferences,
    required this.composingRegion,
    required this.commonOps,
    required this.onPerformAction,
    this.log,
  });

  final Editor editor;
  final Document document;
  final DocumentLayoutResolver documentLayoutResolver;
  final ValueListenable<DocumentSelection?> selection;
  final ValueListenable<DocumentRange?> composingRegion;
  final ComposerPreferences composerPreferences;
  final CommonEditorOperations commonOps;

  /// Handles newlines that are inserted as text, e.g., "\n" in deltas.
  final void Function(TextInputAction) onPerformAction;

  /// A logger that is notified of events specifically to [TextDeltasDocumentEditor],
  /// which lets apps report those specific events to their own issue tracker.
  final TextDeltasDocumentEditorLog? log;

  late DocumentImeSerializer _serializedDoc;
  late TextEditingValue _previousImeValue;
  TextEditingValue? _nextImeValue;

  /// Applies the given [textEditingDeltas] to the [Document].
  void applyDeltas(List<TextEditingDelta> textEditingDeltas) {
    // Check for GBoard aggressive trailing space deletion, which prevents
    // inserting a paragraph after an empty paragraph.
    final isGBoardNewlineSpaceRemoval = _isGBoardTrailingSpaceRemoval(textEditingDeltas);
    if (isGBoardNewlineSpaceRemoval) {
      log?.onGBoardNewlineTrailingSpaceRemoval(textEditingDeltas);
      return;
    }

    editorImeLog.info("Applying ${textEditingDeltas.length} IME deltas to document");
    editorImeDeltasLog.fine("Incoming deltas:");
    for (final delta in textEditingDeltas) {
      editorImeDeltasLog.fine(delta);
    }

    // Apply deltas to the document.
    editorImeLog.fine("Serializing document to perform IME operations");
    _serializedDoc = DocumentImeSerializer(
      document,
      selection.value!,
      composingRegion.value,
    );

    _previousImeValue = TextEditingValue(
      text: _serializedDoc.imeText,
      selection: selection.value != null
          ? _serializedDoc.documentToImeSelection(selection.value!)
          : const TextSelection.collapsed(offset: -1),
      composing: _serializedDoc.documentToImeRange(_serializedDoc.composingRegion),
    );

    // Start an editor transaction so that all changes made during this delta
    // application is considered a single undo-able change.
    editor.startTransaction();

    try {
      for (final delta in textEditingDeltas) {
        editorImeLog.info("---------------------------------------------------");

        editorImeLog.info("Applying delta: $delta");

        _nextImeValue = delta.apply(_previousImeValue);
        if (delta is TextEditingDeltaInsertion) {
          _applyInsertion(delta);
        } else if (delta is TextEditingDeltaReplacement) {
          _applyReplacement(delta);
        } else if (delta is TextEditingDeltaDeletion) {
          _applyDeletion(delta);
        } else if (delta is TextEditingDeltaNonTextUpdate) {
          _applyNonTextChange(delta);
        } else {
          editorImeLog.shout("Unknown IME delta type: ${delta.runtimeType}");
        }

        editorImeLog.info("---------------------------------------------------");
      }
    } on FailedToMapImePositionToDocumentPositionException catch (exception, stacktrace) {
      // We fail silently on this error due to a Samsung delta ordering issue. When the user
      // presses `newline` button, we receive 2 events, but in the wrong order. We *should*
      // receive:
      //
      //  1. Text replacement for upstream word auto-correction
      //  2. `ENTER` key pressed
      //
      // But what we get is:
      //
      //  1. `ENTER` key pressed
      //  2. Text replacement for upstream word auto-correction (which is now in previous paragraph)
      //
      // The best we can do is stop the delta applications right now, serialize what we've got
      // and send our current state to the IME to get us back in sync. This might still erase
      // some changes that the user applied, but hopefully the editor will continue to respond
      // to future input.
      //
      // Note: We added this specifically to get around a Samsung bug (https://github.com/Flutter-Bounty-Hunters/super_editor/issues/2979)
      // but this error could appear for any number of reasons, and so there may be situations in which
      // we shouldn't swallow this error. If we find those, update this logic accordingly.
      log?.onFailedToMapImePositionToDocumentPosition(exception, stacktrace);
    } on FailedToMapDocumentPositionToImePositionException catch (exception, stacktrace) {
      // We added this catch at the same time as `FailedToMapImePositionToDocumentPositionException`.
      // The other catch was added for a specific Samsung bug. That bug doesn't trigger this
      // exception, nor have we seen this exception elsewhere, but I thought that if we're going
      // to swallow and short-circuit deltas when the mapping fails one direction, then we should
      // do the same thing in the other direction.
      //
      // The hope is that if we ever fail to map from the document to the IME, we short-circuit
      // here and immediately send our current document to the IME, thus returning the IME to a
      // valid state for future editing. Similar to the other error that we swallow, by swallowing
      // this one, there might be missed content changes from the user's perspective. However, it's
      // more important that we keep a working editor than that we avoid the appearance of buggy input.
      log?.onFailedToMapDocumentPositionToImePosition(exception, stacktrace);
    } catch (exception, stacktrace) {
      // This is an unknown error, and therefore it would be dangerous to swallow it. Rethrow it
      // so that apps can catch this issue, and also maybe report it to their issue tracker.
      log?.onFailedToApplyDeltasForUnknownReason(exception, stacktrace);
      rethrow;
    } finally {
      // We must always end the transaction, even if an error occurred. Otherwise, we'll get
      // stuck with an open transaction and the editor will never stabilize.
      //
      // End the editor transaction for all deltas in this call.
      editorImeLog.info("Done with deltas. Ending transaction.");
      editor.endTransaction();
    }

    // Re-serialize document after end of transaction because reactions may have
    // run and further changed it.
    _serializedDoc = DocumentImeSerializer(
      document,
      selection.value!,
      composingRegion.value,
    );

    // Update the editor's IME composing region based on the composing region
    // for the last delta. If the version of our document serialized hidden
    // characters in the IME, adjust for those hidden characters before setting
    // the IME composing region.
    editorImeLog.fine("After applying all deltas, converting the final composing region to a document range.");
    editorImeLog.fine("Raw IME delta composing region: ${textEditingDeltas.last.composing}");

    DocumentRange? docComposingRegion = _calculateNewComposingRegion(textEditingDeltas);

    if (docComposingRegion != composingRegion.value) {
      editor.execute([
        ChangeComposingRegionRequest(
          docComposingRegion,
        ),
      ]);
    }
    editorImeLog.fine("Document composing region: ${composingRegion.value}");

    _nextImeValue = null;
  }

  /// Returns `true` if we believe the given batch of [deltas] represent a GBoard
  /// automatically deleting the trailing space of an empty paragraph when the user
  /// presses "newline".
  ///
  /// ## Explanation of Problem
  /// We encode empty paragraphs as ". ". We do this for two reasons:
  ///
  ///  1. We need some non-empty content so we can detect a "backspace" at the beginning
  ///     of a paragraph.
  ///  2. We need to trick the IME into giving us auto-capitalization, which happens
  ///     naturally after the end of a sentence, hence the ". ".
  ///
  /// Our hidden ". " encoding works fine almost everywhere, and it almost call cases.
  /// The except is when the user tries press "newline" on a GBoard. the GBoard interprets
  /// this situation as the user going to a new line while leaving a dangling space after
  /// the end of a sentence, and therefore the GBoard tries to remove that space.
  ///
  /// Example of deltas in a real interaction:
  ///
  /// ```
  /// TextEditingDeltaNonTextUpdate - old text: '. ', offset: 2
  /// TextEditingDeltaNonTextUpdate - old text: '. ', offset: 2
  /// TextEditingDeltaNonTextUpdate - old text: '. ', offset: 2
  /// TextEditingDeltaNonTextUpdate - old text: '. ', offset: 2
  /// TextEditingDeltaNonTextUpdate - old text: '. ', offset: 2
  /// TextEditingDeltaNonTextUpdate - old text: '. ', offset: 2
  /// TextEditingDeltaDeletion - old text: '. ', offset: 1
  /// ```
  ///
  /// We don't know for sure why there are so many repeat non-text updates. This might be
  /// a consequence of how the GBoard IME reporting implementation works with Flutter's
  /// batching system.
  bool _isGBoardTrailingSpaceRemoval(List<TextEditingDelta> deltas) {
    if (deltas.length < 2) {
      // We expect at least 2 deltas when the GBoard tries to remove a trailing space.
      return false;
    }

    final lastDelta = deltas.last;
    if (lastDelta is! TextEditingDeltaDeletion) {
      // We expect the last delta to be a trailing space deletion, but this one isn't
      // a deletion at all.
      return false;
    }

    final deltasBeforeDeletion = deltas.sublist(0, deltas.length - 1);
    if (deltasBeforeDeletion.firstWhereOrNull((delta) => delta is! TextEditingDeltaNonTextUpdate) != null) {
      // We expect all deltas before the deletion to be repeated composing region changes.
      // But in this case, there are some mutating deltas (insert, replace, delete) before the
      // final deletion. So this isn't an automatic GBoard space removal in an empty paragraph.
      return false;
    }

    for (final nonTextDelta in deltasBeforeDeletion) {
      // We expect the reported text in every non-text delta to be an empty paragraph encoding.
      if (nonTextDelta.oldText != ". ") {
        // This delta has a text value that isn't an empty paragraph, so this looks like
        // some other kind of delta batch.
        return false;
      }
    }

    // We believe that this situation represents the GBoard auto-deleting the trailing
    // space in an empty paragraph, because we encode an empty paragraph as ". ".
    return true;
  }

  void _applyInsertion(TextEditingDeltaInsertion delta) {
    editorImeLog.fine('Inserted text: "${delta.textInserted}"');
    editorImeLog.fine("Insertion offset: ${delta.insertionOffset}");
    editorImeLog.fine("Selection: ${delta.selection}");
    editorImeLog.fine("Composing: ${delta.composing}");
    editorImeLog.fine('Old text: "${delta.oldText}"');

    if (delta.textInserted == "\n") {
      // On iOS native and Android Web, newlines are reported here and also to performAction().
      // On Android native, newlines are only reported here. So, on Android native,
      // we forward the newline action to performAction.
      if (defaultTargetPlatform == TargetPlatform.android && !CurrentPlatform.isWeb) {
        editorImeLog.fine("Received a newline insertion on Android. Forwarding to newline input action.");
        onPerformAction(TextInputAction.newline);
      } else {
        editorImeLog.fine("Skipping insertion delta because its a newline");
      }

      // Update the local IME value that changes with each delta.
      _previousImeValue = delta.apply(_previousImeValue);

      return;
    }

    if (delta.textInserted == "\t" && (defaultTargetPlatform == TargetPlatform.iOS)) {
      // On iOS, tabs pressed at the the software keyboard are reported here.
      commonOps.indentListItem();

      // Update the local IME value that changes with each delta.
      _previousImeValue = delta.apply(_previousImeValue);

      return;
    }

    editorImeLog.fine(
        "Inserting text: '${delta.textInserted}', at insertion offset: ${delta.insertionOffset}, with ime selection: ${delta.selection}");

    final insertionPosition = TextPosition(
      offset: delta.insertionOffset,
      affinity: delta.selection.affinity,
    );

    if (delta.textInserted == ' ' && _serializedDoc.isPositionInsidePlaceholder(insertionPosition)) {
      // The IME is trying to insert a space inside the invisible range. This is a situation that happens
      // on iOS when the user is composing a character at the beginning of a node using a korean keyboard.
      // The IME deletes the first visible character and the space from the invisible characters,
      // them it inserts the space back. We already adjust the deletion to avoid deleting the invisible space,
      // so we should ignore this insertion.
      //
      // For more information, see #1828.
      return;
    }

    editorImeLog.fine("Converting IME insertion offset into a DocumentSelection");
    final insertionSelection = _serializedDoc.imeToDocumentSelection(
      TextSelection.fromPosition(insertionPosition),
    )!;
    // FIXME: ClickUp is getting NPE's on this line ^ (from Sentry error reports)

    // Update the local IME value that changes with each delta.
    _previousImeValue = delta.apply(_previousImeValue);

    insert(insertionSelection, delta.textInserted);

    // Update the IME to document serialization based on the insertion changes.
    _serializedDoc = DocumentImeSerializer(
      document,
      selection.value!,
      composingRegion.value,
      _serializedDoc.didPrependPlaceholder ? PrependedCharacterPolicy.include : PrependedCharacterPolicy.exclude,
    );
  }

  void _applyReplacement(TextEditingDeltaReplacement delta) {
    editorImeLog.fine("Text replaced: '${delta.textReplaced}'");
    editorImeLog.fine("Replacement text: '${delta.replacementText}'");
    editorImeLog.fine("Replaced range: ${delta.replacedRange}");
    editorImeLog.fine("Selection: ${delta.selection}");
    editorImeLog.fine("Composing: ${delta.composing}");
    editorImeLog.fine('Old text: "${delta.oldText}"');

    if (delta.replacementText == "\n") {
      // On iOS native and Android Web, newlines are reported here and also to performAction().
      // On Android native, newlines are only reported here. So, on Android native,
      // we forward the newline action to performAction.
      if (defaultTargetPlatform == TargetPlatform.android && !CurrentPlatform.isWeb) {
        editorImeLog.fine("Received a newline replacement on Android. Forwarding to newline input action.");
        onPerformAction(TextInputAction.newline);
      } else {
        editorImeLog.fine("Skipping replacement delta because its a newline");
      }
      return;
    }

    if (delta.replacementText == "\t" && (defaultTargetPlatform == TargetPlatform.iOS)) {
      // On iOS, tabs pressed at the the software keyboard are reported here.
      commonOps.indentListItem();
      return;
    }

    replace(delta.replacedRange, delta.replacementText);

    // Update the local IME value that changes with each delta.
    _previousImeValue = delta.apply(_previousImeValue);

    // Update the IME to document serialization based on the replacement changes.
    // It's possible that the replacement text have a different length from the replaced text.
    // Therefore, we need to update our mapping from the IME positions to document positions.
    _serializedDoc = DocumentImeSerializer(
      document,
      selection.value!,
      composingRegion.value,
      _serializedDoc.didPrependPlaceholder ? PrependedCharacterPolicy.include : PrependedCharacterPolicy.exclude,
    );
  }

  void _applyDeletion(TextEditingDeltaDeletion delta) {
    editorImeLog.fine("Delete delta:\n"
        "Text deleted: '${delta.textDeleted}'\n"
        "Deleted Range: ${delta.deletedRange}\n"
        "Selection: ${delta.selection}\n"
        "Composing: ${delta.composing}\n"
        "Old text: '${delta.oldText}'");

    delete(delta.deletedRange);

    // Update the local IME value that changes with each delta.
    _previousImeValue = delta.apply(_previousImeValue);

    editorImeLog.fine("Deletion operation complete");
  }

  void _applyNonTextChange(TextEditingDeltaNonTextUpdate delta) {
    editorImeLog.fine("Non-text change:");
    editorImeLog.fine("OS-side selection - ${delta.selection}");
    editorImeLog.fine("OS-side composing - ${delta.composing}");

    var docSelection = _calculateNewDocumentSelection(delta);
    DocumentRange? docComposingRegion = _calculateNewComposingRegion([delta]);

    if (docSelection != null) {
      // We got a selection from the platform.
      // This could happen in some software keyboards, like GBoard,
      // where the user can swipe over the spacebar to change the selection. This also happens
      // when the app uses the native iOS text selection toolbar and the user presses "Select all".

      docSelection = _maybeSelectAllOnIos(docSelection);

      editor.execute([
        ChangeSelectionRequest(
          docSelection,
          docSelection.isCollapsed ? SelectionChangeType.placeCaret : SelectionChangeType.expandSelection,
          SelectionReason.userInteraction,
        ),
        ChangeComposingRegionRequest(docComposingRegion),
      ]);
    }

    // Update the local IME value that changes with each delta.
    _previousImeValue = delta.apply(_previousImeValue);
  }

  /// Performs a workaround to select all text in the document on iOS when the user presses "Select all".
  ///
  /// On iOS, when the app uses the native text selection toolbar and the user presses "Select all",
  /// Flutter sends us a non-text delta with the selection change. However, since we only send to the IME the text
  /// of the currently selected nodes, the delta reports the node being selected, not the entire
  /// document.
  ///
  /// To workaroud this, whenever iOS reports a selection change that selects an entire node,
  /// we select the entire document instead.
  DocumentSelection _maybeSelectAllOnIos(DocumentSelection documentSelection) {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return documentSelection;
    }

    final extentNode = document.getNodeById(documentSelection.extent.nodeId)!;
    final isWholeNodeSelected = documentSelection.start.nodeId == documentSelection.end.nodeId &&
        documentSelection.start.nodePosition == extentNode.beginningPosition &&
        documentSelection.end.nodePosition == extentNode.endPosition;

    if (!isWholeNodeSelected) {
      // The selection is either across multiple nodes or not the entire node.
      // The user didn't press "Select all".
      return documentSelection;
    }

    // The IME reported a selection that selects an entire node. Select the entire document instead.
    return DocumentSelection(
      base: DocumentPosition(
        nodeId: document.first.id,
        nodePosition: document.first.beginningPosition,
      ),
      extent: DocumentPosition(
        nodeId: document.last.id,
        nodePosition: document.last.endPosition,
      ),
    );
  }

  void insert(DocumentSelection insertionSelection, String textInserted) {
    editorImeLog.fine('Inserting "$textInserted" at position "$insertionSelection"');
    editorImeLog
        .fine("Updating the Document Composer's selection to place caret at insertion offset:\n$insertionSelection");
    final selectionBeforeInsertion = selection.value;

    editorImeLog.fine("Inserting the text at the Document Composer's selection");
    final didInsert = _insertPlainText(
      insertionSelection.extent,
      textInserted,
    );
    editorImeLog.fine("Insertion successful? $didInsert");

    if (!didInsert) {
      editorImeLog.fine("Failed to insert characters. Restoring previous selection.");
      editor.execute([
        ChangeSelectionRequest(
          selectionBeforeInsertion,
          SelectionChangeType.placeCaret,
          SelectionReason.contentChange,
        ),
      ]);
    }
  }

  bool _insertPlainText(
    DocumentPosition insertionPosition,
    String text,
  ) {
    editorOpsLog.fine('Attempting to insert "$text" at position: $insertionPosition');

    DocumentNode? insertionNode = document.getNodeById(insertionPosition.nodeId);
    if (insertionNode == null) {
      editorOpsLog.warning('Attempted to insert text using a non-existing node');
      return false;
    }

    if (insertionPosition.nodePosition is UpstreamDownstreamNodePosition) {
      editorOpsLog.fine("The selected position is an UpstreamDownstreamPosition. Inserting new paragraph first.");
      editor.execute([InsertNewlineAtCaretRequest()]);

      // After inserting a block level new line, the selection changes to another node.
      // Therefore, we need to update the insertion position.
      insertionNode = document.getNodeById(selection.value!.extent.nodeId)!;
      insertionPosition = DocumentPosition(nodeId: insertionNode.id, nodePosition: insertionNode.endPosition);
    }

    if (insertionNode is! TextNode || insertionPosition.nodePosition is! TextNodePosition) {
      editorOpsLog.fine(
          "Couldn't insert text because Super Editor doesn't know how to handle a node of type: $insertionNode, with position: ${insertionPosition.nodePosition}");
      return false;
    }

    editorOpsLog.fine("Executing text insertion command.");
    editorOpsLog.finer("Text before insertion: '${insertionNode.text.toPlainText()}'");
    editor.execute([
      if (selection.value != DocumentSelection.collapsed(position: insertionPosition))
        ChangeSelectionRequest(
          DocumentSelection.collapsed(position: insertionPosition),
          SelectionChangeType.placeCaret,
          SelectionReason.userInteraction,
        ),
      InsertTextRequest(
        documentPosition: insertionPosition,
        textToInsert: text,
        attributions: composerPreferences.currentAttributions,
      ),
    ]);
    editorOpsLog.finer("Text after insertion: '${insertionNode.text.toPlainText()}'");

    return true;
  }

  void replace(TextRange replacedRange, String replacementText) {
    editorImeLog.fine("Replacing content in IME range: $replacedRange, with new text: '$replacementText'");
    final replacementSelection = _serializedDoc.imeToDocumentSelection(TextSelection(
      baseOffset: replacedRange.start,
      // TODO: the delta API is wrong for TextRange.end, it should be exclusive,
      //       but it's implemented as inclusive. Change this code when Flutter
      //       fixes the problem.
      extentOffset: replacedRange.end,
    ));

    if (replacementSelection != null) {
      editor.execute([
        ChangeSelectionRequest(
          replacementSelection,
          SelectionChangeType.expandSelection,
          SelectionReason.contentChange,
        ),
      ]);
    }
    editorImeLog.fine("Replacing selection: $replacementSelection");
    editorImeLog.fine('With text: "$replacementText"');

    if (replacementText == "\n") {
      onPerformAction(TextInputAction.newline);
      return;
    }

    editor.execute([
      // This request automatically deletes the currently selected text.
      InsertPlainTextAtCaretRequest(replacementText),
    ]);
  }

  void delete(TextRange deletedRange) {
    final rangeToDelete = deletedRange;
    final docSelectionToDelete = _serializedDoc.imeToDocumentSelection(TextSelection(
      baseOffset: rangeToDelete.start,
      extentOffset: rangeToDelete.end,
    ));
    editorImeLog.fine("Doc selection to delete: $docSelectionToDelete");

    if (docSelectionToDelete == null) {
      // The user is trying to delete upstream at the start of a node.
      // This action requires intervention because the IME doesn't know
      // that there's more content before this node. Instruct the editor
      // to run a delete action upstream, which will take the desired
      // "backspace" behavior at the start of this node.
      editor.execute([
        DeleteUpstreamAtBeginningOfNodeRequest(
          document.getNodeById(selection.value!.extent.nodeId)!,
        ),
      ]);
      return;
    }

    editorImeLog.fine("Running selection deletion operation");
    editor.execute([
      ChangeSelectionRequest(
        docSelectionToDelete,
        docSelectionToDelete.isCollapsed ? SelectionChangeType.collapseSelection : SelectionChangeType.expandSelection,
        SelectionReason.contentChange,
      ),
      const DeleteSelectionRequest(TextAffinity.upstream),
    ]);
  }

  void insertNewline() {
    if (!_isCurrentlyApplyingDeltas) {
      // This newline came from a hardware key, or somewhere other than
      // IME deltas. We can safely run a regular newline insertion.
      editor.execute([
        InsertNewlineAtCaretRequest(Editor.createNodeId()),
      ]);
      return;
    }

    // We received a newline in the middle of IME deltas. Due to the two-way
    // communication between the IME and the app text editing state, we have
    // to handle the update with a bit of extra tracking. See below...
    editorOpsLog.fine("Inserting block-level newline");
    assert(selection.value != null && selection.value!.isCollapsed);

    // Log the node that will receive the newline. We only care about node
    // splits, which only happens with text nodes.
    final selectedNode = document.getNodeById(selection.value!.base.nodeId)!;
    final isSplittingText = selectedNode is TextNode;

    // Run the newline insertion.
    editor.execute([
      InsertNewlineAtCaretRequest(Editor.createNodeId()),
    ]);

    // If the newline split a text node, find the newly insert node and update
    // the IME <-> Document mapping for those two nodes. This is the special
    // accounting that's required to prevent us from trying to send invalid selection
    // or composing regions to the IME. See `supereditor_input_ime_test.dart` for
    // a couple of examples of IME deltas that demonstrate this issue.
    if (isSplittingText) {
      final nextNode = document.getNodeAfterById(selectedNode.id);
      if (nextNode != null) {
        _updateImeRangeMappingAfterNodeSplit(originNode: selectedNode, newNode: nextNode);
      }
    }
  }

  bool get _isCurrentlyApplyingDeltas => _nextImeValue != null;

  /// Updates mappings from Document nodes to IME ranges and IME ranges to Document nodes,
  /// after splitting an [originNode] text node, and inserting [newNode].
  void _updateImeRangeMappingAfterNodeSplit({
    required DocumentNode originNode,
    required DocumentNode newNode,
  }) {
    final newImeValue = _nextImeValue!;
    final imeNewlineIndex = newImeValue.text.indexOf("\n");
    final topImeToDocTextRange = TextRange(start: 0, end: imeNewlineIndex);
    final bottomImeToDocTextRange = TextRange(start: imeNewlineIndex + 1, end: newImeValue.text.length);

    // Update mapping from Document nodes to IME ranges.
    _serializedDoc.docTextNodesToImeRanges[originNode.id] = topImeToDocTextRange;
    _serializedDoc.docTextNodesToImeRanges[newNode.id] = bottomImeToDocTextRange;

    // Remove old mapping from IME TextRange to Document node.
    late final MapEntry<TextRange, String> oldImeToDoc;
    for (final entry in _serializedDoc.imeRangesToDocTextNodes.entries) {
      if (entry.value != originNode.id) {
        continue;
      }

      oldImeToDoc = entry;
      break;
    }
    _serializedDoc.imeRangesToDocTextNodes.remove(oldImeToDoc.key);

    // Update and add mapping from IME TextRanges to Document nodes.
    _serializedDoc.imeRangesToDocTextNodes[topImeToDocTextRange] = originNode.id;
    _serializedDoc.imeRangesToDocTextNodes[bottomImeToDocTextRange] = newNode.id;
  }

  DocumentSelection? _calculateNewDocumentSelection(TextEditingDelta delta) {
    if (CurrentPlatform.isWeb &&
        delta.selection.isCollapsed &&
        _serializedDoc.isPositionInsidePlaceholder(delta.selection.extent)) {
      // On web, pressing CMD + LEFT ARROW generates a non-text delta moving
      // the selection to the first character. However, the first character is in a region
      // invisible to the user. Adjust the document selection to be the first visible character.
      // Expanded selection are already adjusted by the serializer.
      return _serializedDoc.imeToDocumentSelection(
        TextSelection.collapsed(
          offset: _serializedDoc.firstVisiblePosition.offset,
        ),
      );
    }
    return _serializedDoc.imeToDocumentSelection(delta.selection);
  }

  DocumentRange? _calculateNewComposingRegion(List<TextEditingDelta> deltas) {
    final lastDelta = deltas.last;
    if (CurrentPlatform.isWeb &&
        lastDelta.composing.isCollapsed &&
        _serializedDoc.isPositionInsidePlaceholder(TextPosition(offset: lastDelta.composing.end))) {
      // On web, pressing CMD + LEFT ARROW generates a non-text delta moving
      // the selection, and possibly the composing region to the first character. However, the first character
      // is in a region invisible to the user. Adjust the document composing region to be the first visible character.
      // Expanded regions are already adjusted by the serializer.
      return _serializedDoc.imeToDocumentRange(
        TextRange.collapsed(
          _serializedDoc.firstVisiblePosition.offset,
        ),
      );
    }

    if (_serializedDoc.imeText.length < lastDelta.composing.end) {
      // The IME is composing, but the composing region is out of our text bounds. This can happen if the delta
      // handling causes our text to be smaller than the IME's text.
      //
      // For example, when using the markdown plugin, typing "~b~" causes the text to be converted to "b"
      // with strikethrough. The ~ character triggers a composition start, but the IME's composing region is still
      // at the end of "~b~", which is out of our text bounds. This out of bounds index causes our IME range
      // mapping to fail.
      //
      // Clear the composing region.
      return null;
    }

    return _serializedDoc.imeToDocumentRange(lastDelta.composing);
  }
}

abstract class TextDeltasDocumentEditorLog {
  void onGBoardNewlineTrailingSpaceRemoval(List<TextEditingDelta> textEditingDeltas);

  void onFailedToMapImePositionToDocumentPosition(
    FailedToMapImePositionToDocumentPositionException exception,
    StackTrace stacktrace,
  );

  void onFailedToMapDocumentPositionToImePosition(
    FailedToMapDocumentPositionToImePositionException exception,
    StackTrace stacktrace,
  );

  void onFailedToApplyDeltasForUnknownReason(Object exception, StackTrace stacktrace);
}

class ConsolePrintTextDeltasDocumentEditorLog implements TextDeltasDocumentEditorLog {
  const ConsolePrintTextDeltasDocumentEditorLog();

  @override
  void onGBoardNewlineTrailingSpaceRemoval(List<TextEditingDelta> textEditingDeltas) {
    editorImeLog.fine("Detected a GBoard newline trailing space removal. Deltas:");
    for (final delta in textEditingDeltas) {
      editorImeLog
          .fine(" > ${delta.runtimeType} - old text: ${delta.oldText}, selection: ${delta.selection.extentOffset}");
    }
  }

  @override
  void onFailedToMapImePositionToDocumentPosition(
    FailedToMapImePositionToDocumentPositionException exception,
    StackTrace stacktrace,
  ) {
    editorImeLog.warning("Failed to apply some deltas due to bad IME-to-document mapping.");
    editorImeLog.warning(exception);
    editorImeLog.warning("$stacktrace");
  }

  @override
  void onFailedToMapDocumentPositionToImePosition(
    FailedToMapDocumentPositionToImePositionException exception,
    StackTrace stacktrace,
  ) {
    editorImeLog.warning("Failed to apply some deltas due to bad document-to-IME mapping.");
    editorImeLog.warning(exception);
    editorImeLog.warning("$stacktrace");
  }

  @override
  void onFailedToApplyDeltasForUnknownReason(Object exception, StackTrace stacktrace) {
    editorImeLog.shout("Unknown exception while applying deltas:");
    editorImeLog.shout(exception);
    editorImeLog.shout(stacktrace);
  }
}
