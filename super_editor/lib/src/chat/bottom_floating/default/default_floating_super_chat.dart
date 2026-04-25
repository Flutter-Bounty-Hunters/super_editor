import 'package:flutter/material.dart';
import 'package:super_editor/src/chat/bottom_floating/default/default_editor_sheet.dart';
import 'package:super_editor/src/chat/bottom_floating/ui_kit/floating_editor_page_scaffold.dart';
import 'package:super_editor/src/chat/bottom_floating/ui_kit/floating_editor_sheet.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/default_editor/document_ime/document_input_ime.dart';

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
    this.editorSheetStyle = const EditorSheetStyle(),
    this.editorSheetMargin = const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    this.collapsedMinimumHeight = 0,
    // TODO: Remove keyboard height from any of our calculations, which should reduce this number to something closer to 250 or 300.
    this.collapsedMaximumHeight = 650,
  });

  final FloatingEditorContentBuilder pageBuilder;

  final Editor editor;

  final Widget? shadowSheetBanner;

  final EditorSheetStyle editorSheetStyle;

  final EdgeInsets editorSheetMargin;

  /// The shortest that the sheet can be, even if the intrinsic height of the content
  /// within the sheet is shorter than this.
  final double collapsedMinimumHeight;

  /// The maximum height the bottom sheet can grow, as the user enters more lines of content,
  /// before it stops growing and starts scrolling.
  ///
  /// This height applies to the sheet when its "collapsed", i.e., when it's not "expanded". The
  /// sheet includes an "expanded" mode, which is typically triggered by the user dragging the
  /// sheet up. When expanded, the sheet always takes up all available vertical space. When
  /// not expanded, this height is as tall as the sheet can grow.
  final double collapsedMaximumHeight;

  @override
  State<DefaultFloatingSuperChatPage> createState() => _DefaultFloatingSuperChatPageState();
}

class _DefaultFloatingSuperChatPageState extends State<DefaultFloatingSuperChatPage> {
  final _softwareKeyboardController = SoftwareKeyboardController();
  late final FloatingEditorPageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = FloatingEditorPageController(_softwareKeyboardController);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FloatingEditorPageScaffold(
      pageController: _pageController,
      pageBuilder: widget.pageBuilder,
      editorSheet: DefaultFloatingEditorSheet(
        editor: widget.editor,
        messagePageController: _pageController,
        style: widget.editorSheetStyle,
      ),
      editorSheetMargin: widget.editorSheetMargin,
      collapsedMinimumHeight: widget.collapsedMinimumHeight,
      collapsedMaximumHeight: widget.collapsedMaximumHeight,
    );
  }
}
