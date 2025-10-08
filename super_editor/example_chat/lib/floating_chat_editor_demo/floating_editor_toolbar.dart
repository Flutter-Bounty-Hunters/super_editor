import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

class FloatingEditorToolbar extends StatelessWidget {
  const FloatingEditorToolbar({
    super.key,
    required this.softwareKeyboardController,
  });

  final SoftwareKeyboardController softwareKeyboardController;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: 4,
              children: [
                AttachmentButton(),
                _IconButton(icon: Icons.format_bold),
                _IconButton(icon: Icons.format_italic),
                _IconButton(icon: Icons.format_underline),
                _IconButton(icon: Icons.format_strikethrough),
                _IconButton(icon: Icons.format_color_fill),
                _IconButton(icon: Icons.format_quote),
                _IconButton(icon: Icons.format_align_left),
                _IconButton(icon: Icons.format_align_center),
                _IconButton(icon: Icons.format_align_right),
                _IconButton(icon: Icons.format_align_justify),
              ],
            ),
          ),
        ),
        _buildDivider(),
        _CloseKeyboardButton(
          softwareKeyboardController: softwareKeyboardController,
        ),
        _buildDivider(),
        _SendButton(),
      ],
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
  const AttachmentButton({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey.shade200),
      child: _IconButton(
        icon: Icons.add,
      ),
    );
  }
}

class DictationButton extends StatelessWidget {
  const DictationButton({super.key});

  @override
  Widget build(BuildContext context) {
    return _IconButton(icon: Icons.multitrack_audio);
  }
}

class _CloseKeyboardButton extends StatelessWidget {
  const _CloseKeyboardButton({
    required this.softwareKeyboardController,
  });

  final SoftwareKeyboardController softwareKeyboardController;

  @override
  Widget build(BuildContext context) {
    return _IconButton(
      icon: Icons.keyboard_hide,
      onPressed: _closeKeyboard,
    );
  }

  void _closeKeyboard() {
    softwareKeyboardController.close();
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton();

  @override
  Widget build(BuildContext context) {
    return _IconButton(icon: Icons.send);
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    this.onPressed,
  });

  final IconData icon;

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: Icon(
            icon,
            size: 20,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}
