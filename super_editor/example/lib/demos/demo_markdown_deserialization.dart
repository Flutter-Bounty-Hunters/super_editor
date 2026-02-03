import 'dart:async';

import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

/// Markdown deserialization demo.
///
/// A markdown text field is shown next to a SuperEditor. The editor
/// content is updated in near-real-time to reflect the parsed markdown.
class MarkdownDeserializationDemo extends StatefulWidget {
  @override
  State<MarkdownDeserializationDemo> createState() => _MarkdownDeserializationDemoState();
}

class _MarkdownDeserializationDemoState extends State<MarkdownDeserializationDemo> {
  final _docKey = GlobalKey();
  late MutableDocument _doc;
  late MutableDocumentComposer _composer;
  late Editor _docEditor;

  final _markdownController = TextEditingController();

  Timer? _updateTimer;
  final _updateWaitTime = const Duration(milliseconds: 250);

  @override
  void initState() {
    super.initState();
    _markdownController.text = _initialMarkdown;
    _doc = deserializeMarkdownToDocument(_markdownController.text);
    _composer = MutableDocumentComposer();
    _docEditor = createDefaultDocumentEditor(document: _doc, composer: _composer);
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _markdownController.dispose();
    super.dispose();
  }

  void _onMarkdownChange() {
    _updateTimer?.cancel();
    _updateTimer = Timer(_updateWaitTime, _updateDocument);
  }

  void _updateDocument() {
    setState(() {
      _doc = deserializeMarkdownToDocument(_markdownController.text);
      _composer = MutableDocumentComposer();
      _docEditor = createDefaultDocumentEditor(document: _doc, composer: _composer);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: double.infinity,
            color: const Color(0xFF222222),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: TextField(
                controller: _markdownController,
                onChanged: (_) => _onMarkdownChange(),
                maxLines: null,
                expands: true,
                style: const TextStyle(
                  color: Color(0xFFEEEEEE),
                  fontFamily: 'monospace',
                  height: 1.4,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Enter markdown here...',
                  hintStyle: TextStyle(color: Color(0xFF888888)),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SuperEditor(
              key: _docKey,
              editor: _docEditor,
              componentBuilders: [
                TaskComponentBuilder(_docEditor),
                ...defaultComponentBuilders,
              ],
              stylesheet: defaultStylesheet.copyWith(
                documentPadding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

const _initialMarkdown = '''# Mixed Lists Demo

This demonstrates list items mixed with tasks:

* First item
- [ ] Review document
* Second item

## Another example

- [ ] Send email
* Meeting notes
- [x] Complete report

Regular paragraph after the list.
''';
