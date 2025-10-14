import 'package:flutter/material.dart';
import 'package:super_editor/src/chat/bottom_floating/ui_kit/floating_editor_page_scaffold.dart';
import 'package:super_editor/src/chat/bottom_floating/ui_kit/floating_editor_sheet.dart';
import 'package:super_editor/src/chat/message_page_scaffold.dart';

class FloatingSuperChatPageBuilder extends StatefulWidget {
  const FloatingSuperChatPageBuilder({
    super.key,
    this.messagePageController,
    required this.pageBuilder,
    this.sheetKey,
    required this.editorSheet,
    this.shadowSheetBanner,
    this.style = const FloatingEditorStyle(),
  });

  final MessagePageController? messagePageController;

  final MessagePageScaffoldContentBuilder pageBuilder;

  final GlobalKey? sheetKey;
  final Widget editorSheet;
  final Widget? shadowSheetBanner;

  final FloatingEditorStyle style;

  @override
  State<FloatingSuperChatPageBuilder> createState() => _FloatingSuperChatPageBuilderState();
}

class _FloatingSuperChatPageBuilderState extends State<FloatingSuperChatPageBuilder> {
  late MessagePageController _messagePageController;

  @override
  void initState() {
    super.initState();

    _messagePageController = widget.messagePageController ?? MessagePageController();
  }

  @override
  void didUpdateWidget(covariant FloatingSuperChatPageBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.messagePageController != oldWidget.messagePageController) {
      if (oldWidget.messagePageController == null) {
        _messagePageController.dispose();
      }
      _messagePageController = widget.messagePageController ?? MessagePageController();
    }
  }

  @override
  void dispose() {
    if (widget.messagePageController == null) {
      _messagePageController.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FloatingEditorPageScaffold(
      messagePageController: _messagePageController,
      pageBuilder: widget.pageBuilder,
      sheetKey: widget.sheetKey,
      editorSheet: widget.editorSheet,
      shadowSheetBanner: widget.shadowSheetBanner,
      style: widget.style,
    );
  }
}
