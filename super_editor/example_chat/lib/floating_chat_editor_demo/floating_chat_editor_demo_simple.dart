import 'package:example_chat/floating_chat_editor_demo/fake_chat_thread.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

/// A demo of the floating chat page in its simplest possible form, with minimal
/// configuration.
class FloatingChatEditorSimpleDemo extends StatefulWidget {
  const FloatingChatEditorSimpleDemo({super.key});

  @override
  State<FloatingChatEditorSimpleDemo> createState() => _FloatingChatEditorSimpleDemoState();
}

class _FloatingChatEditorSimpleDemoState extends State<FloatingChatEditorSimpleDemo> {
  late final Editor _editor;

  var _showShadowSheetBanner = false;

  @override
  void initState() {
    super.initState();

    _editor = createDefaultDocumentEditor(
      document: MutableDocument.empty(),
      composer: MutableDocumentComposer(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: DefaultFloatingSuperChatPage(
        pageBuilder: (context, bottomSpacing) => _ChatPage(appBar: _buildAppBar()),
        editor: _editor,
        shadowSheetBanner: _showShadowSheetBanner ? _buildBanner() : null,
      ),
    );
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

  Widget _buildBanner() {
    return Text.rich(
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
    );
  }
}

class _ChatPage extends StatelessWidget {
  const _ChatPage({
    this.appBar,
  });

  final PreferredSizeWidget? appBar;

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
        child: FakeChatThread(),
      ),
    );
  }
}
