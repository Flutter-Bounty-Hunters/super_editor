import 'package:example_chat/floating_chat_editor_demo/floating_chat_editor_demo.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  initLoggers(Level.ALL, {
    // messagePageLayoutLog,
    // messageEditorHeightLog,
  });

  runApp(
    MaterialApp(
      home: FloatingChatEditorDemo(),
    ),
  );
}
