import 'package:flutter/material.dart';
import 'package:super_editor/src/chat/bottom_floating/default/default_editor_sheet.dart';
import 'package:super_editor/src/chat/bottom_floating/ui_kit/floating_editor_page_scaffold.dart';
import 'package:super_editor/src/chat/bottom_floating/ui_kit/floating_editor_sheet.dart';
import 'package:super_editor/src/chat/message_page_scaffold.dart';
import 'package:super_editor/src/core/editor.dart';

/// The standard/default floating chat page.
///
/// This widget is meant to be a quick and easy drop-in floating chat solution. It
/// includes a specific configuration of [SuperEditor], a reasonable editor toolbar,
/// a drag handle to expand/collapse the bottom sheet, and it supports an optional shadow
/// sheet, which shows messages just above the editor sheet.
class DefaultFloatingSuperChatPage extends StatefulWidget {
  const DefaultFloatingSuperChatPage({
    super.key,
    required this.pageBuilder,
    required this.editor,
    this.shadowSheetBanner,
    this.style = const FloatingEditorStyle(),
  });

  final MessagePageScaffoldContentBuilder pageBuilder;

  final Editor editor;

  final Widget? shadowSheetBanner;

  final FloatingEditorStyle style;

  @override
  State<DefaultFloatingSuperChatPage> createState() => _DefaultFloatingSuperChatPageState();
}

class _DefaultFloatingSuperChatPageState extends State<DefaultFloatingSuperChatPage> {
  final _messagePageController = MessagePageController();

  @override
  void dispose() {
    _messagePageController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FloatingEditorPageScaffold(
      messagePageController: _messagePageController,
      pageBuilder: widget.pageBuilder,
      editorSheet: DefaultFloatingEditorSheet(
        editor: widget.editor,
        messagePageController: _messagePageController,
        style: widget.style.editorSheet,
      ),
      shadowSheetBanner: widget.shadowSheetBanner,
      style: widget.style,
    );
  }
}
