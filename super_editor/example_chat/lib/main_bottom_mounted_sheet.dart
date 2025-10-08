import 'package:example_chat/message_page_scaffold_demo/message_page_scaffold_demo.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  initLoggers(Level.ALL, {
    // messagePageLayoutLog,
    // messageEditorHeightLog,
  });

  runApp(
    MaterialApp(
      home: MessagePageScaffoldDemo(),
    ),
  );
}
