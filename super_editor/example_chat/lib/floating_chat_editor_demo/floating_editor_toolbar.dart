import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

class FloatingEditorToolbar extends StatelessWidget {
  const FloatingEditorToolbar({
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    this.onAttachPressed,
    this.isTextColorActivated = false,
    this.onTextColorPressed,
    this.isBackgroundColorActivated = false,
    this.onBackgroundColorPressed,
    this.onCloseKeyboardPressed,
  });

  final EdgeInsets padding;

  final VoidCallback? onAttachPressed;

  final bool isTextColorActivated;
  final VoidCallback? onTextColorPressed;

  final bool isBackgroundColorActivated;
  final VoidCallback? onBackgroundColorPressed;

  final VoidCallback? onCloseKeyboardPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Padding for the non-scrolling right-end of the toolbar.
      padding: EdgeInsets.only(right: padding.right),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: padding,
              scrollDirection: Axis.horizontal,
              child: Row(
                spacing: 4,
                children: [
                  if (onAttachPressed != null) //
                    AttachmentButton(
                      onPressed: onAttachPressed!,
                    ),
                  FloatingToolbarIconButton(icon: Icons.format_bold),
                  FloatingToolbarIconButton(icon: Icons.format_italic),
                  FloatingToolbarIconButton(icon: Icons.format_underline),
                  FloatingToolbarIconButton(icon: Icons.format_strikethrough),
                  if (onTextColorPressed != null) //
                    FloatingToolbarIconButton(
                      icon: Icons.format_color_text,
                      isActivated: isTextColorActivated,
                      onPressed: onTextColorPressed,
                    ),
                  if (onBackgroundColorPressed != null) //
                    FloatingToolbarIconButton(
                      icon: Icons.format_color_fill,
                      isActivated: isBackgroundColorActivated,
                      onPressed: onBackgroundColorPressed,
                    ),
                ],
              ),
            ),
          ),
          if (onCloseKeyboardPressed != null) ...[
            //
            _buildDivider(),
            _CloseKeyboardButton(onPressed: onCloseKeyboardPressed!),
          ],
          _buildDivider(),
          _SendButton(),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 16,
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Colors.grey.shade300,
    );
  }
}

class AttachmentButton extends StatelessWidget {
  const AttachmentButton({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey.shade200),
      child: FloatingToolbarIconButton(
        icon: Icons.add,
        onPressed: onPressed,
      ),
    );
  }
}

class DictationButton extends StatelessWidget {
  const DictationButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingToolbarIconButton(icon: Icons.multitrack_audio);
  }
}

class _CloseKeyboardButton extends StatelessWidget {
  const _CloseKeyboardButton({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingToolbarIconButton(
      icon: Icons.keyboard_hide,
      onPressed: onPressed,
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton();

  @override
  Widget build(BuildContext context) {
    return FloatingToolbarIconButton(icon: Icons.send);
  }
}

class FloatingToolbarIconButton extends StatelessWidget {
  const FloatingToolbarIconButton({
    required this.icon,
    this.isActivated = false,
    this.onPressed,
  });

  final IconData icon;

  final bool isActivated;

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: isActivated ? Colors.grey : Colors.transparent,
        ),
        child: Center(
          child: Icon(
            icon,
            size: 20,
            color: isActivated ? Colors.grey.shade300 : Colors.grey,
          ),
        ),
      ),
    );
  }
}
