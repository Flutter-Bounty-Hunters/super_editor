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
    this.sheetKey,
    required this.editorSheet,
    this.shadowSheetBanner,
    this.style = const FloatingEditorStyle(),
  });

  final MessagePageController? messagePageController;
  final MessagePageScaffoldContentBuilder pageBuilder;

  /// A key that's bound to the outermost widget of the bottom sheet, which can be used to inspect
  /// the size and location of the bottom sheet.
  ///
  /// This is useful, for example, so that an editor sheet can implement drag to expand/contract the
  /// sheet. In that case, the caller should provide a [sheetKey] to this widget, AND also provide
  /// that same `sheetKey` to the editor sheet where the dragging is implemented.
  final GlobalKey? sheetKey;
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
    // SuperKeyboard.startLogging();

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

    // SuperKeyboard.stopLogging();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildMessagePageScaffold();
    // return Stack(
    //   children: [
    //     widget.pageContent,
    //     Positioned.fill(child: _buildMessagePageScaffold()),
    //   ],
    // );
  }

  Widget _buildMessagePageScaffold() {
    return MessagePageScaffold(
      controller: _messagePageController,
      bottomSheetMinimumTopGap: MediaQuery.viewPaddingOf(context).top,
      bottomSheetMinimumHeight: 148,
      bottomSheetCollapsedMaximumHeight: 650,
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
              child: KeyedSubtree(
                key: widget.sheetKey,
                child: BottomFloatingChatSheet(
                  messagePageController: _messagePageController,
                  editor: widget.editorSheet,
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
