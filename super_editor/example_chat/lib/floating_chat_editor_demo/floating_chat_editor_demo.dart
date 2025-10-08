import 'package:example_chat/floating_chat_editor_demo/floating_editor_page.dart';
import 'package:example_chat/message_page_scaffold_demo/demo_super_editor_message_page.dart';
import 'package:flutter/material.dart';

class FloatingChatEditorDemo extends StatefulWidget {
  const FloatingChatEditorDemo({super.key});

  @override
  State<FloatingChatEditorDemo> createState() => _FloatingChatEditorDemoState();
}

class _FloatingChatEditorDemoState extends State<FloatingChatEditorDemo> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Floating Editor"),
        backgroundColor: Colors.white,
        elevation: 16,
      ),
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth / constraints.maxHeight <= 1) {
            // Show phone experience.
            return FloatingEditorPage();
          }

          // Show the tablet experience.
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 64,
              ),
              Container(
                width: 1,
                color: Colors.black.withValues(alpha: 0.1),
              ),
              Spacer(),
              Container(
                width: 1,
                color: Colors.black.withValues(alpha: 0.1),
              ),
              SizedBox(
                width: 450,
                child: FloatingEditorPage(),
              ),
            ],
          );
        },
      ),
    );
  }
}
