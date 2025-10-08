import 'dart:math';

import 'package:example_chat/floating_chat_editor_demo/fake_chat_thread.dart';
import 'package:example_chat/floating_chat_editor_demo/floating_editor_sheet.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_keyboard/super_keyboard.dart';

/// A page with a bottom mounted floating editor, similar to an iOS glass
/// concept.
class FloatingEditorPage extends StatefulWidget {
  const FloatingEditorPage({super.key});

  @override
  State<FloatingEditorPage> createState() => _FloatingEditorPageState();
}

class _FloatingEditorPageState extends State<FloatingEditorPage> {
  final _messagePageController = MessagePageController();

  @override
  void initState() {
    super.initState();
    // SuperKeyboard.startLogging();
  }

  @override
  void dispose() {
    // SuperKeyboard.stopLogging();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MessagePageScaffold(
      controller: _messagePageController,
      bottomSheetMinimumTopGap: 100,
      bottomSheetMinimumHeight: 148,
      contentBuilder: (contentContext, bottomSpacing) {
        return MediaQuery.removePadding(
          context: contentContext,
          removeBottom: true,
          // ^ Remove bottom padding because if we don't, when the keyboard
          //   opens to edit the bottom sheet, this content behind the bottom
          //   sheet adds some phantom space at the bottom, slightly pushing
          //   it up for no reason.
          child: ColoredBox(
            color: Colors.white,
            child: FakeChatThread(),
          ),
        );
      },
      bottomSheetBuilder: (messageContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                child: FloatingEditorBottomSheet(
                  messagePageController: _messagePageController,
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
