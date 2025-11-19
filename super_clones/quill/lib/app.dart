import 'package:feather/deltas/deltas_display.dart';
import 'package:feather/editor/editor.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

class FeatherApp extends StatelessWidget {
  const FeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Feather',
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Editor _editor;
  late final MutableDocument _document;
  late final MutableDocumentComposer _composer;

  bool _showDeltas = true;

  @override
  void initState() {
    super.initState();

    _document = createDocumentWithVaryingStyles();
    _composer = MutableDocumentComposer();
    _editor = Editor(
      editables: {
        Editor.documentKey: _document,
        Editor.composerKey: _composer,
      },
      requestHandlers: [
        (editor, request) => request is ConvertTextBlockToFormatRequest //
            ? ConvertTextBlockToFormatCommand(request.blockFormat)
            : null,
        (editor, request) => request is ToggleInlineFormatRequest //
            ? ToggleInlineFormatCommand(request.inlineFormat)
            : null,
        (editor, request) => request is ToggleTextBlockFormatRequest //
            ? ToggleTextBlockFormatCommand(request.blockFormat)
            : null,
        (editor, request) => request is ClearSelectedStylesRequest //
            ? const ClearSelectedStylesCommand()
            : null,
        ...defaultRequestHandlers,
      ],
      reactionPipeline: [
        ...defaultEditorReactions,
        _AlwaysTrailingParagraphReaction(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Row(
          children: [
            Expanded(
              child: FeatherEditor(
                  editor: _editor,
                  isShowingDeltas: _showDeltas,
                  onShowDeltasChange: (bool showDeltas) {
                    setState(() {
                      _showDeltas = showDeltas;
                    });
                  }),
            ),
            if (_showDeltas) //
              SizedBox(
                width: 400,
                child: DeltasDisplay(editor: _editor),
              ),
          ],
        ),
      ),
    );
  }
}

MutableDocument createDocumentWithVaryingStyles() {
  return deserializeMarkdownToDocument('''# Header 1
This is regular text right below header 1.
## Header 2
This is regular text right below header 2.
### Header 3
#### Header 4
##### Header 5
###### Header 6
Some **bold** text.

> This is a blockquote.
> It can span multiple lines.

* This is a bulleted list item.

1. This is a numerical list item.

```
This is a code block.
It can span multiple lines.
```

The end.
''');
}

/// [EditReaction] that inserts an empty paragraph at the end of the document if ever one
/// isn't present.
///
/// This reaction ensures that there's always a place for the caret to move below the
/// current block. This is especially important for a code block, in which pressing
/// Enter inserts a newline inside the code block - it doesn't insert a new paragraph
/// below the code block.
class _AlwaysTrailingParagraphReaction extends EditReaction {
  @override
  void modifyContent(EditContext editorContext, RequestDispatcher requestDispatcher, List<EditEvent> changeList) {
    final document = editorContext.find<MutableDocument>(Editor.documentKey);
    final lastNode = document.lastOrNull;

    if (lastNode != null &&
        lastNode is ParagraphNode &&
        (lastNode.getMetadataValue("blockType") == paragraphAttribution ||
            lastNode.getMetadataValue("blockType") == null) &&
        lastNode.text.text.isEmpty) {
      // Already have a trailing empty paragraph. Fizzle.
      return;
    }

    // We need to insert a trailing empty paragraph.
    requestDispatcher.execute([
      InsertNodeAtIndexRequest(
        nodeIndex: document.nodeCount,
        newNode: ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText(""),
        ),
      ),
    ]);
  }
}
