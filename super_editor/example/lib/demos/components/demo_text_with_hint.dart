import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

/// Example of various [TextWithHintComponent] visual configurations.
///
/// To replicate behavior like this in your own code, ensure that you
/// do the following:
///
///  * Specify how headers should be styled by defining a style
///    builder function.
///  * Define a custom [ComponentBuilder] that builds a widget capable
///    of rendering hint text and add it to the builders passed to
///    [SuperEditor]. Consider using [TextWithHintComponent].
///
/// Each of the above steps are demonstrated in this example.
class TextWithHintDemo extends StatefulWidget {
  @override
  State<TextWithHintDemo> createState() => _TextWithHintDemoState();
}

class _TextWithHintDemoState extends State<TextWithHintDemo> {
  late MutableDocument _doc;
  late MutableDocumentComposer _composer;
  late Editor _docEditor;
  _HintDemoMode _demoMode = _HintDemoMode.header1;

  @override
  void initState() {
    super.initState();
    _doc = _createDocument();
    _composer = MutableDocumentComposer();
    _docEditor = createDefaultDocumentEditor(document: _doc, composer: _composer);
  }

  @override
  void dispose() {
    _doc.dispose();
    super.dispose();
  }

  void _resetDocument() {
    setState(() {
      _doc = _createDocument();
      _composer = MutableDocumentComposer();
      _docEditor = createDefaultDocumentEditor(document: _doc, composer: _composer);
    });
  }

  MutableDocument _createDocument() {
    return switch (_demoMode) {
      _HintDemoMode.header1 => _createH1Document(),
      _HintDemoMode.header2 => _createH2Document(),
      _HintDemoMode.header3 => _createH3Document(),
      _HintDemoMode.paragraph => _createParagraphDocument(),
    };
  }

  MutableDocument _createH1Document() {
    return MutableDocument(
      nodes: [
        ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText(),
          metadata: {'blockType': header1Attribution},
        ),
        ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText(
            'Nam hendrerit vitae elit ut placerat. Maecenas nec congue neque. Fusce eget tortor pulvinar, cursus neque vitae, sagittis lectus. Duis mollis libero eu scelerisque ullamcorper. Pellentesque eleifend arcu nec augue molestie, at iaculis dui rutrum. Etiam lobortis magna at magna pellentesque ornare. Sed accumsan, libero vel porta molestie, tortor lorem eleifend ante, at egestas leo felis sed nunc. Quisque mi neque, molestie vel dolor a, eleifend tempor odio.',
          ),
        ),
      ],
    );
  }

  MutableDocument _createH2Document() {
    return MutableDocument(
      nodes: [
        ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText(),
          metadata: {'blockType': header2Attribution},
        ),
        ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText(
            'Nam hendrerit vitae elit ut placerat. Maecenas nec congue neque. Fusce eget tortor pulvinar, cursus neque vitae, sagittis lectus. Duis mollis libero eu scelerisque ullamcorper. Pellentesque eleifend arcu nec augue molestie, at iaculis dui rutrum. Etiam lobortis magna at magna pellentesque ornare. Sed accumsan, libero vel porta molestie, tortor lorem eleifend ante, at egestas leo felis sed nunc. Quisque mi neque, molestie vel dolor a, eleifend tempor odio.',
          ),
        ),
      ],
    );
  }

  MutableDocument _createH3Document() {
    return MutableDocument(
      nodes: [
        ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText(),
          metadata: {'blockType': header3Attribution},
        ),
        ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText(
            'Nam hendrerit vitae elit ut placerat. Maecenas nec congue neque. Fusce eget tortor pulvinar, cursus neque vitae, sagittis lectus. Duis mollis libero eu scelerisque ullamcorper. Pellentesque eleifend arcu nec augue molestie, at iaculis dui rutrum. Etiam lobortis magna at magna pellentesque ornare. Sed accumsan, libero vel porta molestie, tortor lorem eleifend ante, at egestas leo felis sed nunc. Quisque mi neque, molestie vel dolor a, eleifend tempor odio.',
          ),
        ),
      ],
    );
  }

  MutableDocument _createParagraphDocument() {
    return MutableDocument(
      nodes: [
        ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText(),
        ),
        ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText(
            'Nam hendrerit vitae elit ut placerat. Maecenas nec congue neque. Fusce eget tortor pulvinar, cursus neque vitae, sagittis lectus. Duis mollis libero eu scelerisque ullamcorper. Pellentesque eleifend arcu nec augue molestie, at iaculis dui rutrum. Etiam lobortis magna at magna pellentesque ornare. Sed accumsan, libero vel porta molestie, tortor lorem eleifend ante, at egestas leo felis sed nunc. Quisque mi neque, molestie vel dolor a, eleifend tempor odio.',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SuperEditor(
        editor: _docEditor,
        stylesheet: Stylesheet(
          documentPadding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
          rules: defaultStylesheet.rules,

          /// Adjust the default styles to style 3 levels of headers
          /// with large font sizes.
          inlineTextStyler: (attributions, style) => style.merge(_textStyleBuilder(attributions)),
        ),

        /// Add a new component builder to the front of the list
        /// that knows how to render header widgets with hint text.
        componentBuilders: [
          HintComponentBuilder.richText(
            AttributedText(
              'Header goes here...',
              AttributedSpans(
                attributions: [
                  const SpanMarker(attribution: italicsAttribution, offset: 12, markerType: SpanMarkerType.start),
                  const SpanMarker(attribution: italicsAttribution, offset: 15, markerType: SpanMarkerType.end),
                ],
              ),
            ),
            hintStyleBuilder: (context, attributions) => _textStyleBuilder(attributions).copyWith(
              color: const Color(0xFFDDDDDD),
            ),
            shouldShowHint: (document, node) => document.getNodeIndexById(node.id) == 0 && node.text.isEmpty,
          ),
          ...defaultComponentBuilders,
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _demoMode.index,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.title),
            label: 'Header 1',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.title),
            label: 'Hearder 2',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.title),
            label: 'Header 3',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.short_text),
            label: 'Paragraph',
          ),
        ],
        onTap: (int newIndex) {
          setState(() {
            _demoMode = _HintDemoMode.values[newIndex];
            _resetDocument();
          });
        },
      ),
    );
  }
}

/// Styles to apply to all the text in the editor.
TextStyle _textStyleBuilder(Set<Attribution> attributions) {
  // We only care about altering a few styles. Start by getting
  // the standard styles for these attributions.
  var newStyle = defaultStyleBuilder(attributions);

  // Style headers
  for (final attribution in attributions) {
    if (attribution == header1Attribution) {
      newStyle = newStyle.copyWith(
        color: const Color(0xFF444444),
        fontSize: 48,
        fontWeight: FontWeight.bold,
      );
    } else if (attribution == header2Attribution) {
      newStyle = newStyle.copyWith(
        color: const Color(0xFF444444),
        fontSize: 30,
        fontWeight: FontWeight.bold,
      );
    } else if (attribution == header3Attribution) {
      newStyle = newStyle.copyWith(
        color: const Color(0xFF444444),
        fontSize: 16,
        fontWeight: FontWeight.bold,
      );
    }
  }

  return newStyle;
}

enum _HintDemoMode {
  header1,
  header2,
  header3,
  paragraph,
}
