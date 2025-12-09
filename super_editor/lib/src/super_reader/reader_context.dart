import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/infrastructure/documents/document_scroller.dart';
import 'package:super_editor/src/infrastructure/document_context.dart';

/// Collection of core artifacts used to display a read-only document.
///
/// While [SuperReaderContext] includes an [editor], it's expected that clients
/// of a [SuperReaderContext] do not allow users to alter [Document] within
/// the [editor]. Instead, the [editor] provides access to a [Document], a
/// [DocumentComposer] to display and alter selections, and the ability for
/// code to alter the [Document], such as an AI GPT system.
class SuperReaderContext extends DocumentContext {
  SuperReaderContext({
    required super.editor,
    required super.getDocumentLayout,
    required this.scroller,
  });

  /// The [DocumentScroller] that provides status and control over [SuperReader]
  /// scrolling.
  final DocumentScroller scroller;
}
