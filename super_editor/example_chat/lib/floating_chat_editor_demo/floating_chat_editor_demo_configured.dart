import 'package:example_chat/floating_chat_editor_demo/fake_chat_thread.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

/// A floating chat page demo, which uses custom a custom editor sheet material, a custom
/// visual editor, and a custom editor toolbar.
class FloatingChatEditorBuilderDemo extends StatefulWidget {
  const FloatingChatEditorBuilderDemo({super.key});

  @override
  State<FloatingChatEditorBuilderDemo> createState() => _FloatingChatEditorBuilderDemoState();
}

class _FloatingChatEditorBuilderDemoState extends State<FloatingChatEditorBuilderDemo> {
  final _messagePageController = MessagePageController();
  final _sheetKey = GlobalKey(debugLabel: "bottom sheet boundary");

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
  void dispose() {
    _messagePageController.dispose();

    _editor.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: FloatingSuperChatPageBuilder(
        messagePageController: _messagePageController,
        pageBuilder: (context, bottomSpacing) => _ChatPage(appBar: _buildAppBar()),
        sheetKey: _sheetKey,
        editorSheet: _buildEditorSheet(),
        shadowSheetBanner: _showShadowSheetBanner ? _buildBanner() : null,
      ),
    );
  }

  Widget _buildEditorSheet() {
    return DefaultFloatingEditorSheet(
      messagePageController: _messagePageController,
      sheetKey: _sheetKey,
      editor: _editor,
    );

    // return Container(
    //   height: 100,
    //   decoration: ShapeDecoration(
    //     shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(28)),
    //     color: Colors.red.withValues(alpha: 0.5),
    //   ),
    // );
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

// /// A demo of the floating chat page that adjusts available configurations, including a
// /// custom editor widget and a custom toolbar widget.
// class FloatingChatEditorConfiguredDemo extends StatefulWidget {
//   const FloatingChatEditorConfiguredDemo({super.key});
//
//   @override
//   State<FloatingChatEditorConfiguredDemo> createState() => _FloatingChatEditorConfiguredDemoState();
// }
//
// class _FloatingChatEditorConfiguredDemoState extends State<FloatingChatEditorConfiguredDemo> {
//   late final Editor _editor;
//   final _softwareKeyboardController = SoftwareKeyboardController();
//
//   @override
//   void initState() {
//     super.initState();
//
//     _editor = createDefaultDocumentEditor(
//       document: MutableDocument.empty(),
//       composer: MutableDocumentComposer(),
//     );
//   }
//
//   @override
//   void dispose() {
//     _editor.dispose();
//
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Material(
//       child: SuperChatPage.floating(
//         pageBuilder: (context, bottomSpacing) => _ChatPage(),
//         editor: _editor,
//         softwareKeyboardController: _softwareKeyboardController,
//         editorBuilder: (context, editor) {
//           return _CustomEditor(
//             editor: _editor,
//           );
//         },
//         toolbarBuilder: (context, editor) {
//           return _CustomToolbar(
//             editor: _editor,
//             softwareKeyboardController: _softwareKeyboardController,
//           );
//         },
//       ),
//     );
//   }
// }
//
// class _CustomEditor extends StatefulWidget {
//   const _CustomEditor({
//     required this.editor,
//   });
//
//   final Editor editor;
//
//   @override
//   State<_CustomEditor> createState() => _CustomEditorState();
// }
//
// class _CustomEditorState extends State<_CustomEditor> {
//   @override
//   Widget build(BuildContext context) {
//     return const Placeholder();
//   }
// }
//
// class _CustomToolbar extends StatefulWidget {
//   const _CustomToolbar({
//     required this.editor,
//     required this.softwareKeyboardController,
//   });
//
//   final Editor editor;
//   final SoftwareKeyboardController softwareKeyboardController;
//
//   @override
//   State<_CustomToolbar> createState() => _CustomToolbarState();
// }
//
// class _CustomToolbarState extends State<_CustomToolbar> {
//   @override
//   Widget build(BuildContext context) {
//     return const Placeholder();
//   }
// }
//
// class _ChatPage extends StatelessWidget {
//   const _ChatPage();
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text("Floating Editor"),
//         backgroundColor: Colors.white,
//         elevation: 16,
//       ),
//       extendBodyBehindAppBar: true,
//       resizeToAvoidBottomInset: false,
//       backgroundColor: Colors.white,
//       body: ColoredBox(
//         color: Colors.white,
//         child: FakeChatThread(),
//       ),
//     );
//   }
// }
