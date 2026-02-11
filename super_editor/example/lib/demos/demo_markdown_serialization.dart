import 'dart:async';

import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

/// Markdown serialization demo.
///
/// An editor is shown next to corresponding markdown text. The
/// markdown text is updated in near-real-time to reflect the
/// current structure of the document in the editor.
class MarkdownSerializationDemo extends StatefulWidget {
  @override
  State<MarkdownSerializationDemo> createState() => _MarkdownSerializationDemoState();
}

class _MarkdownSerializationDemoState extends State<MarkdownSerializationDemo> {
  final _docKey = GlobalKey();
  late MutableDocument _doc;
  late MutableDocumentComposer _composer;
  late Editor _docEditor;

  String _markdown = '';

  Timer? _updateTimer;
  final _markdownUpdateWaitTime = const Duration(milliseconds: 250);

  @override
  void initState() {
    super.initState();
    _doc = _createInitialDocument()..addListener(_onDocumentChange);
    _composer = MutableDocumentComposer();
    _docEditor = createDefaultDocumentEditor(document: _doc, composer: _composer);

    _updateMarkdown();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  void _onDocumentChange(_) {
    _updateTimer?.cancel();
    _updateTimer = Timer(_markdownUpdateWaitTime, _updateMarkdownAndRebuild);
  }

  void _updateMarkdownAndRebuild() {
    setState(() {
      _updateMarkdown();
    });
  }

  void _updateMarkdown() {
    _markdown = serializeDocumentToMarkdown(_doc);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
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
        Expanded(
          child: Container(
            height: double.infinity,
            color: const Color(0xFF222222),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Text(
                  _markdown,
                  style: const TextStyle(
                    color: Color(0xFFEEEEEE),
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

MutableDocument _createInitialDocument() {
  return MutableDocument(
    nodes: [
      ImageNode(
        id: Editor.createNodeId(),
        imageUrl: 'https://i.imgur.com/fSZwM7G.jpg',
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText('Example Document'),
        metadata: {
          'blockType': header1Attribution,
        },
      ),
      HorizontalRuleNode(id: Editor.createNodeId()),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus sed sagittis urna. Aenean mattis ante justo, quis sollicitudin metus interdum id. Aenean ornare urna ac enim consequat mollis. In aliquet convallis efficitur. Phasellus convallis purus in fringilla scelerisque. Ut ac orci a turpis egestas lobortis. Morbi aliquam dapibus sem, vitae sodales arcu ultrices eu. Duis vulputate mauris quam, eleifend pulvinar quam blandit eget.',
        ),
      ),
      ListItemNode.unordered(
        id: Editor.createNodeId(),
        text: AttributedText('This is an unordered list item'),
      ),
      ListItemNode.unordered(
        id: Editor.createNodeId(),
        text: AttributedText('This is another list item'),
      ),
      ListItemNode.unordered(
        id: Editor.createNodeId(),
        text: AttributedText(
            'This is a 3rd list item, with a link',
            AttributedSpans(
              attributions: [
                SpanMarker(
                    attribution: LinkAttribution.fromUri(Uri.https('example.org', '')),
                    offset: 30,
                    markerType: SpanMarkerType.start),
                SpanMarker(
                    attribution: LinkAttribution.fromUri(Uri.https('example.org', '')),
                    offset: 35,
                    markerType: SpanMarkerType.end),
              ],
            )),
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
          'Cras vitae sodales nisi. Vivamus dignissim vel purus vel aliquet. Sed viverra diam vel nisi rhoncus pharetra. Donec gravida ut ligula euismod pharetra. Etiam sed urna scelerisque, efficitur mauris vel, semper arcu. Nullam sed vehicula sapien. Donec id tellus volutpat, eleifend nulla eget, rutrum mauris.',
        ),
      ),
      ListItemNode.ordered(
        id: Editor.createNodeId(),
        text: AttributedText('First thing to do'),
      ),
      ListItemNode.ordered(
        id: Editor.createNodeId(),
        text: AttributedText('Second thing to do'),
      ),
      ListItemNode.ordered(
        id: Editor.createNodeId(),
        text: AttributedText('Third thing to do'),
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
          'Nam hendrerit vitae elit ut placerat. Maecenas nec congue neque. Fusce eget tortor pulvinar, cursus neque vitae, sagittis lectus. Duis mollis libero eu scelerisque ullamcorper. Pellentesque eleifend arcu nec augue molestie, at iaculis dui rutrum. Etiam lobortis magna at magna pellentesque ornare. Sed accumsan, libero vel porta molestie, tortor lorem eleifend ante, at egestas leo felis sed nunc. Quisque mi neque, molestie vel dolor a, eleifend tempor odio.',
        ),
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
          'Etiam id lacus interdum, efficitur ex convallis, accumsan ipsum. Integer faucibus mollis mauris, a suscipit ante mollis vitae. Fusce justo metus, congue non lectus ac, luctus rhoncus tellus. Phasellus vitae fermentum orci, sit amet sodales orci. Fusce at ante iaculis nunc aliquet pharetra. Nam placerat, nisl in gravida lacinia, nisl nibh feugiat nunc, in sagittis nisl sapien nec arcu. Nunc gravida faucibus massa, sit amet accumsan dolor feugiat in. Mauris ut elementum leo.',
        ),
      ),
      TaskNode(
        id: Editor.createNodeId(),
        isComplete: false,
        text: AttributedText(
          'This is an incomplete task',
        ),
      ),
      TaskNode(
        id: Editor.createNodeId(),
        isComplete: true,
        text: AttributedText(
          'This is a completed task',
        ),
      ),
    ],
  );
}
