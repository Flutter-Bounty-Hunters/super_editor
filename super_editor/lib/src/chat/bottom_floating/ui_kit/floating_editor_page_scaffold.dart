import 'dart:math';

import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

/// A page scaffold that displays page content in a [child], with a floating editor sitting above and at
/// the bottom of the [child].
class FloatingEditorPageScaffold extends StatefulWidget {
  const FloatingEditorPageScaffold({
    super.key,
    this.messagePageController,
    required this.pageBuilder,
    required this.editorSheet,
    this.shadowSheetBanner,
    this.style = const FloatingEditorStyle(),
  });

  final MessagePageController? messagePageController;
  final MessagePageScaffoldContentBuilder pageBuilder;

  final Widget? shadowSheetBanner;
  final Widget editorSheet;

  final FloatingEditorStyle style;

  @override
  State<FloatingEditorPageScaffold> createState() => _FloatingEditorPageScaffoldState();
}

class _FloatingEditorPageScaffoldState extends State<FloatingEditorPageScaffold> {
  late MessagePageController _messagePageController;

  @override
  void initState() {
    super.initState();
    _messagePageController = widget.messagePageController ?? MessagePageController();
  }

  @override
  void didUpdateWidget(covariant FloatingEditorPageScaffold oldWidget) {
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
    return MessagePageScaffold(
      controller: _messagePageController,
      bottomSheetMinimumTopGap: MediaQuery.viewPaddingOf(context).top,
      bottomSheetMinimumHeight: widget.style.margin.top,
      bottomSheetCollapsedMaximumHeight: widget.style.collapsedMaximumHeight,
      contentBuilder: (contentContext, bottomSpacing) {
        return MediaQuery.removePadding(
          context: contentContext,
          removeBottom: true,
          // ^ Remove bottom padding because if we don't, when the keyboard
          //   opens to edit the bottom sheet, this content behind the bottom
          //   sheet adds some phantom space at the bottom, slightly pushing
          //   it up for no reason.
          child: widget.pageBuilder(contentContext, bottomSpacing),
        );
      },
      bottomSheetBuilder: (messageContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: FloatingChatBottomSheet(
                child: BottomFloatingChatSheet(
                  messagePageController: _messagePageController,
                  editorSheet: widget.editorSheet,
                  shadowSheetBanner: widget.shadowSheetBanner,
                  style: widget.style,
                ),
              ),
            ),
            // Push the sheet up above the keyboard.
            KeyboardHeightBuilder(
              builder: (context, keyboardHeight) {
                return SizedBox(height: max(keyboardHeight, MediaQuery.viewPaddingOf(context).bottom));
              },
            ),
          ],
        );
      },
    );
  }
}

/// A marker widget that wraps the outermost boundary of the bottom sheet in a
/// [FloatingEditorPageScaffold].
///
/// This widget can be accessed by descendants for the purpose of querying the size
/// and global position of the floating sheet. This is useful, for example, when
/// implementing drag behaviors to expand/collapse the bottom sheet. The part of the
/// widget tree that contains the drag handle may not have access to the overall sheet.
class FloatingChatBottomSheet extends StatefulWidget {
  static BuildContext of(BuildContext context) =>
      context.findAncestorStateOfType<_FloatingChatBottomSheetState>()!._sheetKey.currentContext!;

  static BuildContext? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<_FloatingChatBottomSheetState>()?._sheetKey.currentContext;

  const FloatingChatBottomSheet({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<FloatingChatBottomSheet> createState() => _FloatingChatBottomSheetState();
}

class _FloatingChatBottomSheetState extends State<FloatingChatBottomSheet> {
  final _sheetKey = GlobalKey(debugLabel: "FloatingChatBottomSheet");

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _sheetKey, child: widget.child);
  }
}
