import 'package:flutter/material.dart';
import 'package:gemini/infrastructure/bottom_sheet.dart';
import 'package:super_editor/super_editor.dart';

class BottomSheetChatScaffold extends StatefulWidget {
  const BottomSheetChatScaffold({super.key, required this.contentBuilder});

  final MessagePageScaffoldContentBuilder contentBuilder;

  @override
  State<BottomSheetChatScaffold> createState() => _BottomSheetChatScaffoldState();
}

class _BottomSheetChatScaffoldState extends State<BottomSheetChatScaffold> {
  @override
  Widget build(BuildContext context) {
    return MessagePageScaffold(
      contentBuilder: widget.contentBuilder,
      bottomSheetBuilder: (context) {
        return ChatEditorBottomSheet();
      },
    );
  }
}
