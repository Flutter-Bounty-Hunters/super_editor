import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/editor.dart';

/// Collection of core artifacts used to create various read-only document
/// use-cases.
///
/// While [ReadOnlyContext] includes an [editor], it's expected that clients
/// of a [ReadOnlyContext] do not allow users to alter [Document] within
/// the [editor]. Instead, the [editor] provides access to a [Document], a
/// [DocumentComposer] to display and alter selections, and the ability for
/// code to alter the [Document], such as an AI GPT system.
class ReadOnlyContext {
  ReadOnlyContext({
    required this.editor,
    required DocumentLayout Function() getDocumentLayout,
  }) : _getDocumentLayout = getDocumentLayout;

  final Editor editor;

  /// The [Document] that's currently being displayed.
  Document get document => editor.document;

  /// The current selection within the displayed document.
  DocumentComposer get composer => editor.composer;

  /// The document layout that is a visual representation of the document.
  ///
  /// This member might change over time.
  DocumentLayout get documentLayout => _getDocumentLayout();
  final DocumentLayout Function() _getDocumentLayout;
}
