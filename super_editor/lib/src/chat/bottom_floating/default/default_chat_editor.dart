import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/default_editor/default_document_editor.dart';

/// Creates an [Editor] that's configured for a nominal chat use-case.
///
/// Additional request handlers can be prepended with [prependedRequestHandlers] and appended
/// with [appendedRequestHandlers] (order determines priority).
///
/// Additional edit reactions can be prepended with [prependedReactions] and appended with
/// [appendedReactions] (order determines priority).
Editor createDefaultChatEditor({
  MutableDocument? document,
  MutableDocumentComposer? composer,
  List<EditRequestHandler> prependedRequestHandlers = const [],
  List<EditRequestHandler> appendedRequestHandlers = const [],
  List<EditReaction> prependedReactions = const [],
  List<EditReaction> appendedReactions = const [],
  HistoryGroupingPolicy historyGroupingPolicy = defaultMergePolicy,
  bool isHistoryEnabled = false,
}) {
  final editor = Editor(
    editables: {
      Editor.documentKey: document ?? MutableDocument.empty(),
      Editor.composerKey: composer ?? MutableDocumentComposer(),
    },
    requestHandlers: [
      ...prependedRequestHandlers,
      ...defaultChatRequestHandlers,
      ...appendedRequestHandlers,
    ],
    reactionPipeline: [
      ...prependedReactions,
      ...defaultChatEditorReactions,
      ...appendedReactions,
    ],
    historyGroupingPolicy: historyGroupingPolicy,
    isHistoryEnabled: isHistoryEnabled,
  );

  return editor;
}

final defaultChatRequestHandlers = [
  ...defaultRequestHandlers,
];

final defaultChatEditorReactions = [
  ...defaultEditorReactions,
];
