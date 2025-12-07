import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';

import 'example_document.dart';

class SuperReaderDemo extends StatefulWidget {
  const SuperReaderDemo({Key? key}) : super(key: key);

  @override
  State<SuperReaderDemo> createState() => _SuperReaderDemoState();
}

class _SuperReaderDemoState extends State<SuperReaderDemo> {
  late final Editor _editor;
  final _selectionLayerLinks = SelectionLayerLinks();
  late MagnifierAndToolbarController _overlayController;
  late final SuperReaderIosControlsController _iosReaderControlsController;

  @override
  void initState() {
    super.initState();

    _editor = createDefaultDocumentEditor(
      document: createInitialDocument(),
      composer: MutableDocumentComposer(),
    );

    _overlayController = MagnifierAndToolbarController();
    _iosReaderControlsController = SuperReaderIosControlsController(
      toolbarBuilder: _buildToolbar,
    );
  }

  @override
  void dispose() {
    _iosReaderControlsController.dispose();
    _editor.dispose();

    super.dispose();
  }

  void _copy() {
    if (_editor.composer.selection == null) {
      return;
    }

    final textToCopy = extractTextFromSelection(
      document: _editor.document,
      documentSelection: _editor.composer.selection!,
    );
    // TODO: figure out a general approach for asynchronous behaviors that
    //       need to be carried out in response to user input.
    _saveToClipboard(textToCopy);
  }

  Future<void> _saveToClipboard(String text) {
    return Clipboard.setData(ClipboardData(text: text));
  }

  void _selectAll() {
    if (_editor.document.isEmpty) {
      return;
    }

    _editor.execute([
      ChangeSelectionRequest(
        DocumentSelection(
          base: DocumentPosition(
            nodeId: _editor.document.first.id,
            nodePosition: _editor.document.first.beginningPosition,
          ),
          extent: DocumentPosition(
            nodeId: _editor.document.last.id,
            nodePosition: _editor.document.last.endPosition,
          ),
        ),
        SelectionChangeType.expandSelection,
        SelectionReason.userInteraction,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return SuperReaderIosControlsScope(
      controller: _iosReaderControlsController,
      child: SuperReader(
        editor: _editor,
        overlayController: _overlayController,
        selectionLayerLinks: _selectionLayerLinks,
        stylesheet: defaultStylesheet.copyWith(
          addRulesAfter: [
            taskStyles,
          ],
        ),
        androidToolbarBuilder: (_) => AndroidTextEditingFloatingToolbar(
          onCopyPressed: _copy,
          onSelectAllPressed: _selectAll,
        ),
      ),
    );
  }

  Widget _buildToolbar(context, mobileToolbarKey, focalPoint) {
    return IOSTextEditingFloatingToolbar(
      key: mobileToolbarKey,
      focalPoint: focalPoint,
      onCopyPressed: _copy,
    );
  }
}
