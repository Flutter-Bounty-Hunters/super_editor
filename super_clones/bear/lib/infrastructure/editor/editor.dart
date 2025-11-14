import 'package:bear/infrastructure/editor/components.dart';
import 'package:bear/infrastructure/editor/stylesheet.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

class TextEditor extends StatefulWidget {
  const TextEditor({super.key});

  @override
  State<TextEditor> createState() => _TextEditorState();
}

class _TextEditorState extends State<TextEditor> {
  late final MutableDocument _document;
  final _composer = MutableDocumentComposer();
  late final Editor _editor;

  bool _isTopToolbarVisible = true;
  bool _isFormattingToolbarVisible = false;

  @override
  void initState() {
    super.initState();

    _document = deserializeMarkdownToDocument(_testDocumentContent);
    _editor = createDefaultDocumentEditor(document: _document, composer: _composer)
      ..addListener(
        FunctionalEditListener(_hideTopToolbarOnContentChange),
      );
  }

  /// Inspects every editor change and hides the top toolbar whenever the user makes
  /// a content change, e.g., types some text, deletes some text.
  void _hideTopToolbarOnContentChange(changeList) {
    for (final change in changeList) {
      if (change is! SelectionChangeEvent && change is! ComposingRegionChangeEvent) {
        // We assume any non-selection and non-composing event is a content change.
        // Hide the toolbar.
        _hideTopToolbar();
        return;
      }
    }
  }

  void _showTopToolbar() {
    if (_isTopToolbarVisible) {
      return;
    }

    setState(() {
      _isTopToolbarVisible = true;
    });
  }

  void _hideTopToolbar() {
    if (!_isTopToolbarVisible) {
      return;
    }

    setState(() {
      _isTopToolbarVisible = false;
    });
  }

  void _toggleFormattingToolbar() {
    if (_isFormattingToolbarVisible) {
      _hideFormattingToolbar();
    } else {
      _showFormattingToolbar();
    }
  }

  void _showFormattingToolbar() {
    if (_isFormattingToolbarVisible) {
      return;
    }

    setState(() {
      _isFormattingToolbarVisible = true;
    });
  }

  void _hideFormattingToolbar() {
    if (!_isFormattingToolbarVisible) {
      return;
    }

    setState(() {
      _isFormattingToolbarVisible = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerHover: (_) => _showTopToolbar(),
      behavior: HitTestBehavior.opaque,
      child: ColoredBox(
        color: Colors.white,
        child: Stack(
          children: [
            Positioned.fill(
              child: SuperEditor(
                editor: _editor,
                document: _document,
                composer: _composer,
                componentBuilders: dashComponentBuilders,
                stylesheet: dashStylesheet,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: _buildTopToolbar(),
            ),
            AnimatedPositioned(
              left: 0,
              right: 0,
              bottom: _isFormattingToolbarVisible ? 24 : -50,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOutCirc,
              child: _buildFormattingToolbar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopToolbar() {
    return AbsorbPointer(
      // ^ Absorb pointer so that when the user hovers over this bar, the user can drag the
      // window around, instead of tapping through to the document and placing moving the caret.
      child: AnimatedOpacity(
        opacity: _isTopToolbarVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        child: SizedBox(
          height: 54,
          child: Row(
            children: [
              const Spacer(),
              IconButton(
                onPressed: _toggleFormattingToolbar,
                icon: const Icon(
                  Icons.format_bold,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.info_outline,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.more_vert,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormattingToolbar() {
    return Center(
      child: IconTheme(
        data: IconThemeData(
          size: 18,
          color: Color(0xFF777777),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFDDDDDD),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.text_fields),
              ),
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.list),
              ),
              const SizedBox(width: 24),
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.format_bold),
              ),
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.format_italic),
              ),
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.highlight),
              ),
              const SizedBox(width: 24),
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.link),
              ),
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.image_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _testDocumentContent = '''# Editor Decorations
## Padding
* There's about 150px of padding on top.
* ~600px padding on the bottom
* Horizontally centered with a max document width

## Top Bar
* Shows itself when the mouse moves
* Disappears when the user starts typing
* Bottom border has nuanced appearance rules
  * If the top bar is currently visible, but the bottom border isn't
    * Any scrolling will cause the bottom bar to fade in
''';
