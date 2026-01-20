import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_clipboard/super_editor_clipboard.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final Editor _editor;

  final _documentLayoutKey = GlobalKey(debugLabel: 'super-editor_document-layout');
  late final SuperEditorIosControlsController _iosControlsController;

  @override
  void initState() {
    super.initState();

    _editor = createDefaultDocumentEditor();

    _iosControlsController = SuperEditorIosControlsControllerWithNativePaste(
      editor: _editor,
      documentLayoutResolver: () => _documentLayoutKey.currentState! as DocumentLayout,
    );
  }

  @override
  void dispose() {
    _iosControlsController.dispose();

    _editor.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Native paste example app')),
        body: SuperEditorIosControlsScope(
          controller: _iosControlsController,
          child: SuperEditor(editor: _editor, documentLayoutKey: _documentLayoutKey),
        ),
      ),
    );
  }
}
