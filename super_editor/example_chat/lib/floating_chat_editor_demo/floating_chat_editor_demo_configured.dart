import 'package:example_chat/floating_chat_editor_demo/fake_chat_thread.dart';
import 'package:example_chat/floating_chat_editor_demo/floating_editor_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart' hide AttachmentButton;

/// A floating chat page demo, which uses custom a custom editor sheet material, a custom
/// visual editor, and a custom editor toolbar.
class FloatingChatEditorBuilderDemo extends StatefulWidget {
  const FloatingChatEditorBuilderDemo({super.key});

  @override
  State<FloatingChatEditorBuilderDemo> createState() => _FloatingChatEditorBuilderDemoState();
}

class _FloatingChatEditorBuilderDemoState extends State<FloatingChatEditorBuilderDemo> {
  late final FloatingEditorPageController<_MessageEditingPanels> _pageController;

  final _editorFocusNode = FocusNode(debugLabel: "chat editor");
  late final Editor _editor;
  final _softwareKeyboardController = SoftwareKeyboardController();

  final _isImeConnected = ValueNotifier(false);

  var _showShadowSheetBanner = false;

  @override
  void initState() {
    super.initState();

    _editor = createDefaultDocumentEditor(
      // document: MutableDocument.empty(),
      document: MutableDocument(nodes: [
        ParagraphNode(
          id: "1",
          text: AttributedText(
            "This is a draft that already exists in the editor and it's used to test preview mode.",
          ),
        ),
        ParagraphNode(
          id: "2",
          text: AttributedText(
            "This is a 2nd paragraph which should not be visible in preview mode.",
          ),
        ),
      ]),
      composer: MutableDocumentComposer(),
    );

    _pageController = FloatingEditorPageController(_softwareKeyboardController);
  }

  @override
  void dispose() {
    _isImeConnected.dispose();

    _pageController.dispose();

    _editorFocusNode.dispose();
    _editor.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: FloatingEditorPageScaffold<_MessageEditingPanels>(
        pageController: _pageController,
        pageBuilder: (context, pageGeometry) {
          return _ChatPage(
            appBar: _buildAppBar(),
            scrollPadding: EdgeInsets.only(bottom: pageGeometry.bottomSafeArea),
          );
        },
        editorSheet: _buildEditorSheet(),
        keyboardPanelBuilder: _buildKeyboardPanel,
        style: FloatingEditorStyle(
          margin: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 16),
        ),
      ),
    );
  }

  Widget _buildEditorSheet() {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBanner(),
          _buildEditor(),
          _maybeBuildToolbar(),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      margin: const EdgeInsets.only(left: 14, right: 14, top: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade300,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text.rich(
        TextSpan(
          children: [
            WidgetSpan(
              child: Padding(
                padding: const EdgeInsets.only(right: 4, bottom: 1),
                child: Icon(Icons.supervised_user_circle_rounded, size: 13),
              ),
            ),
            TextSpan(
              text: "Ella Martinez",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: " is from Acme"),
          ],
          style: TextStyle(
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _maybeBuildPreviewAttachmentButton(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: SuperChatEditor(
                editorFocusNode: _editorFocusNode,
                editor: _editor,
                pageController: _pageController,
                softwareKeyboardController: _softwareKeyboardController,
                isImeConnected: _isImeConnected,
              ),
            ),
          ),
          _maybeBuildPreviewDictationButton(),
        ],
      ),
    );
  }

  Widget _maybeBuildPreviewAttachmentButton() {
    return ListenableBuilder(
      listenable: _editorFocusNode,
      builder: (context, child) {
        if (_editorFocusNode.hasFocus) {
          return SizedBox();
        }

        return AttachmentButton(
          onPressed: () {
            _editorFocusNode.requestFocus();

            WidgetsBinding.instance.addPostFrameCallback((_) {
              _pageController.showKeyboardPanel(_MessageEditingPanels.slashCommandPanel);
            });
          },
        );
      },
    );
  }

  Widget _maybeBuildPreviewDictationButton() {
    return ListenableBuilder(
      listenable: _editorFocusNode,
      builder: (context, child) {
        if (_editorFocusNode.hasFocus) {
          return SizedBox();
        }

        return FloatingToolbarIconButton(
          icon: Icons.multitrack_audio,
          onPressed: () {},
        );
      },
    );
  }

  Widget _maybeBuildToolbar() {
    return ListenableBuilder(
      listenable: Listenable.merge([_editorFocusNode, _pageController]),
      builder: (context, child) {
        if (!_editorFocusNode.hasFocus) {
          return const SizedBox();
        }

        print("Building FloatingEditorToolbar - open panel: ${_pageController.openPanel}");
        return FloatingEditorToolbar(
          onAttachPressed: () {
            _pageController.toggleKeyboardPanel(_MessageEditingPanels.slashCommandPanel);
          },
          isTextColorActivated: _pageController.openPanel == _MessageEditingPanels.textColorPanel,
          onTextColorPressed: () {
            _pageController.toggleKeyboardPanel(_MessageEditingPanels.textColorPanel);
          },
          isBackgroundColorActivated: _pageController.openPanel == _MessageEditingPanels.backgroundColorPanel,
          onBackgroundColorPressed: () {
            _pageController.toggleKeyboardPanel(_MessageEditingPanels.backgroundColorPanel);
          },
          onCloseKeyboardPressed: () {
            _pageController.closeKeyboardAndPanel();
          },
        );
      },
    );
  }

  Widget _buildKeyboardPanel(BuildContext context, _MessageEditingPanels openPanel) {
    switch (openPanel) {
      case _MessageEditingPanels.slashCommandPanel:
        return _SlashCommandPanel();
      case _MessageEditingPanels.textColorPanel:
        return _TextColorPanel();
      case _MessageEditingPanels.backgroundColorPanel:
        return _BackgroundColorPanel();
    }
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text("Floating Editor"),
      backgroundColor: Colors.white,
      elevation: 16,
      actions: [
        IconButton(
          onPressed: () {
            setState(() {
              _showShadowSheetBanner = !_showShadowSheetBanner;
            });
          },
          icon: Icon(Icons.warning),
        ),
      ],
    );
  }
}

class _ChatPage extends StatelessWidget {
  const _ChatPage({
    this.appBar,
    this.scrollPadding = EdgeInsets.zero,
  });

  final PreferredSizeWidget? appBar;
  final EdgeInsets scrollPadding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar ??
          AppBar(
            title: Text("Floating Editor"),
            backgroundColor: Colors.white,
            elevation: 16,
          ),
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      body: ColoredBox(
        color: Colors.white,
        child: FakeChatThread(
          scrollPadding: scrollPadding,
        ),
      ),
    );
  }
}

enum _MessageEditingPanels {
  slashCommandPanel,
  textColorPanel,
  backgroundColorPanel;
}

class _SlashCommandPanel extends StatelessWidget {
  const _SlashCommandPanel();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: Colors.blue);
  }
}

class _TextColorPanel extends StatelessWidget {
  const _TextColorPanel();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: Colors.red);
  }
}

class _BackgroundColorPanel extends StatelessWidget {
  const _BackgroundColorPanel();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: Colors.green);
  }
}
