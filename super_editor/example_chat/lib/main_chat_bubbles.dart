import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  initLoggers(Level.FINE, {
    // contentLayersLog,
  });

  runApp(_ChatBubbleApp());
}

class _ChatBubbleApp extends StatelessWidget {
  const _ChatBubbleApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: _ChatBubblePage(),
      ),
    );
  }
}

class _ChatBubblePage extends StatefulWidget {
  const _ChatBubblePage();

  @override
  State<_ChatBubblePage> createState() => _ChatBubblePageState();
}

class _ChatBubblePageState extends State<_ChatBubblePage> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 56),
      children: [
        _ChatBubble(
          conversationRole: _ConversationRole.me,
          message: "Does Super Editor support chat use-cases?",
        ),
        _ChatBubble(
          conversationRole: _ConversationRole.other,
          message: "Yep",
        ),
        _ChatBubble(
          conversationRole: _ConversationRole.me,
          message: "How so?",
        ),
        _ChatBubble(
          conversationRole: _ConversationRole.other,
          message:
              "Super Editor displays rich text messages with a SuperMessage widget. Those can be displayed in a conversation list, and styled to look like chat bubbles.",
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.conversationRole,
    required this.message,
  });

  final _ConversationRole conversationRole;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: LayoutBuilder(builder: (context, constraints) {
        return Align(
          alignment: switch (conversationRole) {
            _ConversationRole.me => Alignment.centerRight,
            _ConversationRole.other => Alignment.centerLeft,
          },
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.8),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: switch (conversationRole) {
                  _ConversationRole.me => Colors.blue,
                  _ConversationRole.other => Colors.blueGrey,
                },
              ),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: SuperMessage(
                editor: createDefaultDocumentEditor(
                  document: MutableDocument(nodes: [ParagraphNode(id: "1", text: AttributedText(message))]),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

enum _ConversationRole {
  me,
  other;
}
