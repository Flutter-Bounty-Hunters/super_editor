import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

class KeyboardPanelScaffoldDemo extends StatefulWidget {
  const KeyboardPanelScaffoldDemo({super.key});

  @override
  State<KeyboardPanelScaffoldDemo> createState() => _KeyboardPanelScaffoldDemoState();
}

class _KeyboardPanelScaffoldDemoState extends State<KeyboardPanelScaffoldDemo> {
  final _editorFocusNode = FocusNode(debugLabel: "bottom-mounted-editor");
  late final Editor _editor;

  late final KeyboardPanelController<_Panel> _panelController;
  final _softwareKeyboardController = SoftwareKeyboardController();
  final _isImeConnected = ValueNotifier(false);

  @override
  void initState() {
    super.initState();

    // initLoggers(Level.ALL, {keyboardPanelLog});

    _editor = createDefaultDocumentEditor(
      document: MutableDocument.empty(),
      composer: MutableDocumentComposer(),
    );

    _panelController = KeyboardPanelController(_softwareKeyboardController);
  }

  @override
  void dispose() {
    _softwareKeyboardController.detach();

    _panelController.dispose();
    _isImeConnected.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardScaffoldSafeArea(
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: KeyboardPanelScaffold<_Panel>(
          controller: _panelController,
          isImeConnected: _isImeConnected,
          contentBuilder: _buildContent,
          toolbarBuilder: _buildToolbar,
          keyboardPanelBuilder: _buildKeyboardPanel,
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, _Panel? openPanel) {
    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned.fill(child: Placeholder()),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Material(
                borderRadius: BorderRadius.circular(16),
                elevation: 10,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: SuperEditorFocusOnTap(
                    editorFocusNode: _editorFocusNode,
                    editor: _editor,
                    child: SuperEditorDryLayout(
                      superEditor: SuperEditor(
                        focusNode: _editorFocusNode,
                        editor: _editor,
                        softwareKeyboardController: _softwareKeyboardController,
                        isImeConnected: _isImeConnected,
                        imePolicies: SuperEditorImePolicies(),
                        selectionPolicies: SuperEditorSelectionPolicies(),
                        shrinkWrap: false,
                        stylesheet: _chatStylesheet,
                        componentBuilders: [
                          const HintComponentBuilder("Send a message...", _hintTextStyleBuilder),
                          ...defaultComponentBuilders,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context, _Panel? openPanel) {
    return Container(
      width: double.infinity,
      height: 54,
      color: Colors.grey,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            onPressed: () {
              _panelController.showKeyboardPanel(_Panel.one);
            },
            icon: Text("1"),
          ),
          IconButton(
            onPressed: () {
              _panelController.showKeyboardPanel(_Panel.two);
            },
            icon: Text("2"),
          ),
          IconButton(
            onPressed: () {
              _panelController.showKeyboardPanel(_Panel.three);
            },
            icon: Text("3"),
          ),
          IconButton(
            onPressed: () {
              _panelController.showSoftwareKeyboard();
            },
            icon: Icon(Icons.keyboard_rounded),
          ),
          IconButton(
            onPressed: () {
              _panelController.closeKeyboardAndPanel();
            },
            icon: Icon(Icons.keyboard_hide),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyboardPanel(BuildContext context, _Panel? openPanel) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.red,
    );
  }
}

final _chatStylesheet = Stylesheet(
  rules: [
    StyleRule(
      BlockSelector.all,
      (doc, docNode) {
        return {
          Styles.padding: const CascadingPadding.symmetric(horizontal: 24),
          Styles.textStyle: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            height: 1.4,
          ),
        };
      },
    ),
    StyleRule(
      const BlockSelector("header1"),
      (doc, docNode) {
        return {
          Styles.textStyle: const TextStyle(
            color: Color(0xFF333333),
            fontSize: 38,
            fontWeight: FontWeight.bold,
          ),
        };
      },
    ),
    StyleRule(
      const BlockSelector("header2"),
      (doc, docNode) {
        return {
          Styles.textStyle: const TextStyle(
            color: Color(0xFF333333),
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        };
      },
    ),
    StyleRule(
      const BlockSelector("header3"),
      (doc, docNode) {
        return {
          Styles.textStyle: const TextStyle(
            color: Color(0xFF333333),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        };
      },
    ),
    StyleRule(
      const BlockSelector("paragraph"),
      (doc, docNode) {
        return {
          Styles.padding: const CascadingPadding.only(bottom: 12),
        };
      },
    ),
    StyleRule(
      const BlockSelector("blockquote"),
      (doc, docNode) {
        return {
          Styles.textStyle: const TextStyle(
            color: Colors.grey,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            height: 1.4,
          ),
        };
      },
    ),
    StyleRule(
      BlockSelector.all.last(),
      (doc, docNode) {
        return {
          Styles.padding: const CascadingPadding.only(bottom: 48),
        };
      },
    ),
  ],
  inlineTextStyler: defaultInlineTextStyler,
  inlineWidgetBuilders: defaultInlineWidgetBuilderChain,
);

TextStyle _hintTextStyleBuilder(context) => TextStyle(
      color: Colors.grey,
    );

// FIXME: This widget is required because of the current shrink wrap behavior
//        of Super Editor. If we set `shrinkWrap` to `false` then the bottom
//        sheet always expands to max height. But if we set `shrinkWrap` to
//        `true`, when we manually expand the bottom sheet, the only
//        tappable area is wherever the document components actually appear.
//        In the average case, that means only the top area of the bottom
//        sheet can be tapped to place the caret.
//
//        This widget should wrap Super Editor and make the whole area tappable.
/// A widget, that when pressed, gives focus to the [editorFocusNode], and places
/// the caret at the end of the content within an [editor].
///
/// It's expected that the [child] subtree contains the associated `SuperEditor`,
/// which owns the [editor] and [editorFocusNode].
class SuperEditorFocusOnTap extends StatelessWidget {
  const SuperEditorFocusOnTap({
    super.key,
    required this.editorFocusNode,
    required this.editor,
    required this.child,
  });

  final FocusNode editorFocusNode;

  final Editor editor;

  /// The SuperEditor that we're wrapping with this tap behavior.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: editorFocusNode,
      builder: (context, child) {
        return ListenableBuilder(
          listenable: editor.composer.selectionNotifier,
          builder: (context, child) {
            final shouldControlTap = editor.composer.selection == null || !editorFocusNode.hasFocus;
            return GestureDetector(
              onTap: editor.composer.selection == null || !editorFocusNode.hasFocus ? _selectEditor : null,
              behavior: HitTestBehavior.opaque,
              child: IgnorePointer(
                ignoring: shouldControlTap,
                // ^ Prevent the Super Editor from aggressively responding to
                //   taps, so that we can respond.
                child: child,
              ),
            );
          },
          child: child,
        );
      },
      child: child,
    );
  }

  void _selectEditor() {
    editorFocusNode.requestFocus();

    final endNode = editor.document.last;
    editor.execute([
      ChangeSelectionRequest(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: endNode.id,
            nodePosition: endNode.endPosition,
          ),
        ),
        SelectionChangeType.placeCaret,
        SelectionReason.userInteraction,
      )
    ]);
  }
}

enum _Panel {
  one,
  two,
  three;
}
