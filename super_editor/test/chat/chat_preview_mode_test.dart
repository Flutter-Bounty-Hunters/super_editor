import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/test/super_editor_test/supereditor_inspector.dart';
import 'package:super_editor/src/test/super_editor_test/supereditor_robot.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_keyboard/super_keyboard.dart';

import '../infrastructure/keyboard_panel_scaffold_test.dart';

void main() {
  group("Chat > preview mode >", () {
    testWidgetsOnMobilePhone("activates and deactivates with focus", (tester) async {
      await _pumpScaffold(tester, _longDocument);

      // Ensure we begin in preview mode, hiding everything after the first
      // component.
      expect(SuperEditorInspector.maybeFindWidgetForComponent("1"), isNotNull);
      expect(SuperEditorInspector.maybeFindWidgetForComponent("2"), isNull);
      expect(SuperEditorInspector.maybeFindWidgetForComponent("3"), isNull);

      // Tap the editor to focus it, and disable preview mode.
      await tester.placeCaretInParagraph("1", 0);

      // Ensure we're now in normal mode, showing the entire document.
      expect(SuperEditorInspector.maybeFindWidgetForComponent("1"), isNotNull);
      expect(SuperEditorInspector.maybeFindWidgetForComponent("2"), isNotNull);
      expect(SuperEditorInspector.maybeFindWidgetForComponent("3"), isNotNull);
    });
  });
}

final _longDocument = MutableDocument(
  nodes: [
    ParagraphNode(
      id: "1",
      text: AttributedText("This is the first paragraph which takes up multiple lines of height."),
    ),
    ParagraphNode(id: "2", text: AttributedText("This is paragraph 2.")),
    ParagraphNode(id: "3", text: AttributedText("This is paragraph 3.")),
  ],
);

Future<void> _pumpScaffold(WidgetTester tester, MutableDocument document) async {
  final editor = createDefaultAiMessageEditor(document: document);
  final messagePageController = MessagePageController();
  final scrollController = ScrollController();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        resizeToAvoidBottomInset: false,
        body: MessagePageScaffold(
          controller: messagePageController,
          contentBuilder: (context, bottomSpacing) {
            return const SizedBox();
          },
          bottomSheetBuilder: (context) {
            return _ChatEditor(
              editor: editor,
              inputRole: 'chat-preview-test-editor',
              messagePageController: messagePageController,
              scrollController: scrollController,
            );
          },
        ),
      ),
    ),
  );
}

// TODO: When we have a good selection of public chat editor APIs, delete all of the
//       following infrastructure and replace it with the standard public versions from
//       the package (at the time of writing, we don't have ready-made public chat APIs yet).
class _ChatEditor extends StatefulWidget {
  const _ChatEditor({
    required this.editor,
    required this.inputRole,
    required this.messagePageController,
    required this.scrollController,
  });

  final Editor editor;
  final String inputRole;
  final MessagePageController messagePageController;
  final ScrollController scrollController;

  @override
  State<_ChatEditor> createState() => _ChatEditorState();
}

class _ChatEditorState extends State<_ChatEditor> {
  final _editorKey = GlobalKey();
  final _editorFocusNode = FocusNode();

  final _previewModePlugin = ChatPreviewModePlugin();

  late final KeyboardPanelController<_Panel> _keyboardPanelController;
  late final SoftwareKeyboardController _softwareKeyboardController;
  final _isImeConnected = ValueNotifier(false);

  @override
  void initState() {
    super.initState();

    _softwareKeyboardController = SoftwareKeyboardController();
    _keyboardPanelController = KeyboardPanelController(
      _softwareKeyboardController,
    );

    widget.messagePageController.addListener(_onMessagePageControllerChange);

    _isImeConnected.addListener(_onImeConnectionChange);

    SuperKeyboard.instance.mobileGeometry.addListener(_onKeyboardChange);
  }

  @override
  void didUpdateWidget(_ChatEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.messagePageController != oldWidget.messagePageController) {
      oldWidget.messagePageController.removeListener(_onMessagePageControllerChange);
      widget.messagePageController.addListener(_onMessagePageControllerChange);
    }
  }

  @override
  void dispose() {
    SuperKeyboard.instance.mobileGeometry.removeListener(_onKeyboardChange);

    widget.messagePageController.removeListener(_onMessagePageControllerChange);

    _keyboardPanelController.dispose();
    _isImeConnected.dispose();

    super.dispose();
  }

  void _onKeyboardChange() {
    // FIXME: I had to comment this out so that panels can open. Otherwise, if we leave
    //        this behavior in, and we try to open a panel, this check triggers and closes
    //        the IME (and therefore the panel) when the panel tries to open.
    // // On Android, we've found that when swiping to go back, the keyboard often
    // // closes without Flutter reporting the closure of the IME connection.
    // // Therefore, the keyboard closes, but editors and text fields retain focus,
    // // selection, and a supposedly open IME connection.
    // //
    // // Flutter issue: https://github.com/flutter/flutter/issues/165734
    // //
    // // To hack around this bug in Flutter, when super_keyboard reports keyboard
    // // closure, and this controller thinks the keyboard is open, we give up
    // // focus so that our app state synchronizes with the closed IME connection.
    // final keyboardState = SuperKeyboard.instance.mobileGeometry.value.keyboardState;
    // if (_isImeConnected.value && (keyboardState == KeyboardState.closing || keyboardState == KeyboardState.closed)) {
    //   _editorFocusNode.unfocus();
    // }
  }

  void _onImeConnectionChange() {
    widget.messagePageController.collapsedMode =
        _isImeConnected.value ? MessagePageSheetCollapsedMode.intrinsic : MessagePageSheetCollapsedMode.preview;
  }

  void _onMessagePageControllerChange() {
    if (widget.messagePageController.isPreview) {
      // Always scroll the editor to the top when in preview mode.
      widget.scrollController.position.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardPanelScaffold(
      controller: _keyboardPanelController,
      isImeConnected: _isImeConnected,
      contentBuilder: (BuildContext context, _Panel? openPanel) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ListenableBuilder(
              listenable: _editorFocusNode,
              builder: (context, child) {
                if (_editorFocusNode.hasFocus) {
                  return const SizedBox();
                }

                return child!;
              },
              child: IconButton(
                onPressed: () {
                  _editorFocusNode.requestFocus();

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    // We wait for the end of the frame to show the panel because giving
                    // focus to the editor will first cause the keyboard to show. If we
                    // opened the panel immediately then it would be covered by the keyboard.
                    _keyboardPanelController.showKeyboardPanel(_Panel.thePanel);
                  });
                },
                icon: const Icon(Icons.add),
              ),
            ),
            Expanded(child: _buildEditor()),
            ListenableBuilder(
              listenable: _editorFocusNode,
              builder: (context, child) {
                if (_editorFocusNode.hasFocus) {
                  return const SizedBox();
                }

                return child!;
              },
              child: IconButton(onPressed: () {}, icon: const Icon(Icons.multitrack_audio)),
            ),
          ],
        );
      },
      toolbarBuilder: (BuildContext context, _Panel? openPanel) {
        return Container(
          width: double.infinity,
          height: 54,
          color: Colors.white.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (!_keyboardPanelController.isKeyboardPanelOpen) {
                    _keyboardPanelController.showKeyboardPanel(_Panel.thePanel);
                  } else {
                    // This line is here to debug an issue in ClickUp
                    _keyboardPanelController.hideKeyboardPanel();
                    _keyboardPanelController.showSoftwareKeyboard();
                  }
                },
                child: const Icon(Icons.add),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  _softwareKeyboardController.close();
                },
                child: const Icon(Icons.keyboard_hide_outlined),
              ),
            ],
          ),
        );
      },
      keyboardPanelBuilder: (BuildContext context, _Panel? openPanel) {
        if (openPanel == null) {
          return const SizedBox();
        }

        return Container(width: double.infinity, height: 300, color: Colors.red);
      },
    );
  }

  Widget _buildEditor() {
    return _SuperEditorFocusOnTap(
      editorFocusNode: _editorFocusNode,
      editor: widget.editor,
      child: SuperEditorDryLayout(
        controller: widget.scrollController,
        superEditor: SuperEditor(
          key: _editorKey,
          focusNode: _editorFocusNode,
          editor: widget.editor,
          inputRole: widget.inputRole,
          softwareKeyboardController: _softwareKeyboardController,
          isImeConnected: _isImeConnected,
          imePolicies: const SuperEditorImePolicies(),
          selectionPolicies: const SuperEditorSelectionPolicies(),
          shrinkWrap: false,
          stylesheet: _chatStylesheet,
          componentBuilders: const [
            HintComponentBuilder("Send a message...", _hintTextStyleBuilder),
            ...defaultComponentBuilders,
          ],
          plugins: {
            _previewModePlugin,
          },
        ),
      ),
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

TextStyle _hintTextStyleBuilder(context) => const TextStyle(
      color: Colors.grey,
    );

enum _Panel {
  thePanel;
}

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
class _SuperEditorFocusOnTap extends StatelessWidget {
  const _SuperEditorFocusOnTap({
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
