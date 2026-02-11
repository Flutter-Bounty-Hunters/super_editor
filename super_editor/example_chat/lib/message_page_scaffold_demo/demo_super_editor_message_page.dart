import 'dart:math';

import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_keyboard/super_keyboard.dart';

/// A chat experience, which includes a simulated list of comments, as well as
/// a bottom-mounted message editor, which uses `SuperEditor` for writing messages.
class SuperEditorMessagePageDemo extends StatefulWidget {
  const SuperEditorMessagePageDemo({super.key});

  @override
  State<SuperEditorMessagePageDemo> createState() => _SuperEditorMessagePageDemoState();
}

class _SuperEditorMessagePageDemoState extends State<SuperEditorMessagePageDemo> {
  @override
  void initState() {
    super.initState();

    SKLog.startLogging();
  }

  @override
  void dispose() {
    SKLog.stopLogging();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ChatPage(
      inputRole: "Home",
    );
  }
}

class _ChatPage extends StatefulWidget {
  const _ChatPage({
    required this.inputRole,
  });

  final String inputRole;

  @override
  State<_ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<_ChatPage> {
  final _messagePageController = MessagePageController();

  @override
  void dispose() {
    _messagePageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MessagePageScaffold(
      controller: _messagePageController,
      bottomSheetMinimumTopGap: 150,
      bottomSheetMinimumHeight: 148,
      contentBuilder: (contentContext, bottomSpacing) {
        return MediaQuery.removePadding(
          context: contentContext,
          removeBottom: true,
          // ^ Remove bottom padding because if we don't, when the keyboard
          //   opens to edit the bottom sheet, this content behind the bottom
          //   sheet adds some phantom space at the bottom, slightly pushing
          //   it up for no reason.
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(color: Colors.purpleAccent.shade100),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: bottomSpacing,
                child: _ChatThread(),
              ),
            ],
          ),
        );
      },
      bottomSheetBuilder: (messageContext) {
        return _EditorBottomSheet(
          messagePageController: _messagePageController,
          inputRole: widget.inputRole,
        );
      },
    );
  }
}

/// A simulated chat conversation thread, which is simulated as a bottom-aligned
/// list of tiles.
class _ChatThread extends StatelessWidget {
  const _ChatThread();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      reverse: true,
      // ^ The list starts at the bottom and grows upward. This is how
      //   we should layout chat conversations where the most recent
      //   message appears at the bottom, and you want to retain the
      //   scroll offset near the newest messages, not the oldest.
      itemBuilder: (context, index) {
        if (index == 8) {
          // Arbitrarily placed text field to test moving focus between a non-editor
          // and the editor.
          return TextField(
            decoration: InputDecoration(
              hintText: "Content text field...",
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Material(
            color: Colors.white.withValues(alpha: 0.5),
            child: ListTile(
              title: Text("Item $index"),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) {
                      return Scaffold(
                        resizeToAvoidBottomInset: false,
                        body: _ChatPage(
                          inputRole: "Subpage-${Random().nextInt(1000)}",
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// Bottom sheet, which includes a message editor.
class _EditorBottomSheet extends StatefulWidget {
  const _EditorBottomSheet({
    required this.messagePageController,
    required this.inputRole,
  });

  final MessagePageController messagePageController;
  final String inputRole;

  @override
  State<_EditorBottomSheet> createState() => _EditorBottomSheetState();
}

class _EditorBottomSheetState extends State<_EditorBottomSheet> {
  final _dragIndicatorKey = GlobalKey();

  final _scrollController = ScrollController();

  final _editorSheetKey = GlobalKey();
  late final Editor _editor;

  final _hasSelection = ValueNotifier(false);

  @override
  void initState() {
    super.initState();

    _editor = createDefaultDocumentEditor(
      document: MutableDocument(
        nodes: [
          ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText("This is a pre-existing"),
          ),
          ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText("message"),
          ),
          ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText("It's tall for quick"),
          ),
          ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText("testing of"),
          ),
          ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText("intrinsic height that"),
          ),
          ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText("exceeds available space"),
          ),
        ],
      ),
      composer: MutableDocumentComposer(),
    );
    _editor.composer.selectionNotifier.addListener(_onSelectionChange);
  }

  @override
  void dispose() {
    _editor.composer.selectionNotifier.removeListener(_onSelectionChange);
    _editor.dispose();

    _scrollController.dispose();

    super.dispose();
  }

  void _onSelectionChange() {
    _hasSelection.value = _editor.composer.selection != null;

    // If the editor doesn't have a selection then when it's collapsed it
    // should be in preview mode. If the editor does have a selection, then
    // when it's collapsed, it should be in intrinsic height mode.
    widget.messagePageController.collapsedMode =
        _hasSelection.value ? MessagePageSheetCollapsedMode.intrinsic : MessagePageSheetCollapsedMode.preview;
  }

  double _dragTouchOffsetFromIndicator = 0;

  void _onVerticalDragStart(DragStartDetails details) {
    _dragTouchOffsetFromIndicator = _dragFingerOffsetFromIndicator(details.globalPosition);

    widget.messagePageController.onDragStart(
      details.globalPosition.dy - _dragIndicatorOffsetFromTop + _dragTouchOffsetFromIndicator,
    );
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    widget.messagePageController.onDragUpdate(
      details.globalPosition.dy - _dragIndicatorOffsetFromTop + _dragTouchOffsetFromIndicator,
    );
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    widget.messagePageController.onDragEnd();
  }

  void _onVerticalDragCancel() {
    widget.messagePageController.onDragEnd();
  }

  double get _dragIndicatorOffsetFromTop {
    final editorSheetBox = _editorSheetKey.currentContext!.findRenderObject();
    final dragIndicatorBox = _dragIndicatorKey.currentContext!.findRenderObject()! as RenderBox;

    return dragIndicatorBox.localToGlobal(Offset.zero, ancestor: editorSheetBox).dy;
  }

  double _dragFingerOffsetFromIndicator(Offset globalDragOffset) {
    final dragIndicatorBox = _dragIndicatorKey.currentContext!.findRenderObject()! as RenderBox;

    return dragIndicatorBox.localToGlobal(Offset.zero).dy - globalDragOffset.dy;
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: _editorSheetKey,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        border: Border(top: BorderSide(color: Colors.grey)),
      ),
      child: KeyboardScaffoldSafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDragHandle(),
            Flexible(
              child: _buildSheetContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetContent() {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom,
        // ^ Avoid the bottom notch when the keyboard is closed.
      ),
      child: BottomSheetEditorHeight(
        previewHeight: 72,
        child: _ChatEditor(
          key: _editorKey,
          editor: _editor,
          inputRole: widget.inputRole,
          messagePageController: widget.messagePageController,
          scrollController: _scrollController,
        ),
      ),
    );
  }

  // FIXME: Keyboard keeps closing without a bunch of global keys. Either
  //        document why, or figure out how to operate without all the keys.
  final _editorKey = GlobalKey();

  Widget _buildDragHandle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onVerticalDragStart: _onVerticalDragStart,
          onVerticalDragUpdate: _onVerticalDragUpdate,
          onVerticalDragEnd: _onVerticalDragEnd,
          onVerticalDragCancel: _onVerticalDragCancel,
          behavior: HitTestBehavior.opaque,
          // ^ Opaque to handle tough events in our invisible padding.
          child: Padding(
            padding: const EdgeInsets.all(18),
            // ^ Expand the hit area with invisible padding.
            child: Container(
              key: _dragIndicatorKey,
              width: 32,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// An editor for composing chat messages.
class _ChatEditor extends StatefulWidget {
  const _ChatEditor({
    super.key,
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
                icon: Icon(Icons.add),
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
              child: IconButton(onPressed: () {}, icon: Icon(Icons.multitrack_audio)),
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
                child: Icon(Icons.add),
              ),
              Spacer(),
              GestureDetector(
                onTap: () {
                  _softwareKeyboardController.close();
                },
                child: Icon(Icons.keyboard_hide_outlined),
              ),
            ],
          ),
        );
      },
      keyboardPanelBuilder: (BuildContext context, _Panel? openPanel) {
        if (openPanel == null) {
          return SizedBox();
        }

        return Container(width: double.infinity, height: 300, color: Colors.red);
      },
    );
  }

  Widget _buildEditor() {
    return SuperEditorFocusOnTap(
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
  thePanel;
}
