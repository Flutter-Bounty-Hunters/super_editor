import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/src/chat/chat_editor.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/default_editor/document_ime/document_input_ime.dart';

class SuperChatFloatingSheetToolbar extends StatefulWidget {
  const SuperChatFloatingSheetToolbar({
    super.key,
    required this.editor,
    this.softwareKeyboardController,
    this.onAttachPressed,
    this.onSendPressed,
    this.toolbarOptions,
  });

  final Editor editor;

  final SoftwareKeyboardController? softwareKeyboardController;

  final VoidCallback? onAttachPressed;
  final VoidCallback? onSendPressed;

  final Set<SimpleSuperChatToolbarOptions>? toolbarOptions;

  @override
  State<SuperChatFloatingSheetToolbar> createState() => _SuperChatFloatingSheetToolbarState();
}

class _SuperChatFloatingSheetToolbarState extends State<SuperChatFloatingSheetToolbar> {
  var _toolbarOptions = <SimpleSuperChatToolbarOptions>{};

  @override
  void initState() {
    super.initState();

    _toolbarOptions = Set.from(widget.toolbarOptions ?? SimpleSuperChatToolbarOptions.values);

    _doSanityChecks();
  }

  void _doSanityChecks() {
    assert(
      widget.softwareKeyboardController != null ||
          !_toolbarOptions.contains(SimpleSuperChatToolbarOptions.closeKeyboard),
      "If you want a button to close the keyboard, you must provide a SoftwareKeyboardController",
    );
    if (widget.softwareKeyboardController == null) {
      // In case we're in release mode, and the assert didn't trigger, remove the close-keyboard
      // button from the options.
      _toolbarOptions.remove(SimpleSuperChatToolbarOptions.closeKeyboard);
    }

    assert(
      widget.onAttachPressed != null || !_toolbarOptions.contains(SimpleSuperChatToolbarOptions.attach),
      "If you want a button to attach media, you must provide an onAttachPressed callback",
    );
    if (widget.onAttachPressed == null) {
      // In case we're in release mode, and the assert didn't trigger, remove the "attach"
      // button from the options.
      _toolbarOptions.remove(SimpleSuperChatToolbarOptions.attach);
    }

    assert(
      widget.onSendPressed != null || !_toolbarOptions.contains(SimpleSuperChatToolbarOptions.send),
      "If you want a button to send messages, you must provide an onSendPressed callback",
    );
    if (widget.onSendPressed == null) {
      // In case we're in release mode, and the assert didn't trigger, remove the "send"
      // button from the options.
      _toolbarOptions.remove(SimpleSuperChatToolbarOptions.send);
    }
  }

  @override
  void didUpdateWidget(covariant SuperChatFloatingSheetToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!const DeepCollectionEquality().equals(widget.toolbarOptions, oldWidget.toolbarOptions)) {
      _toolbarOptions = Set.from(widget.toolbarOptions ?? SimpleSuperChatToolbarOptions.values);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 14, right: 14, top: 8, bottom: 14),
      child: Row(
        children: [
          if (_toolbarOptions.contains(SimpleSuperChatToolbarOptions.attach)) //
            _AttachmentButton(
              onPressed: () {},
            ),
          const Expanded(
            child: SingleChildScrollView(
              child: Row(
                children: [
                  //
                ],
              ),
            ),
          ),
          if (_toolbarOptions.contains(SimpleSuperChatToolbarOptions.closeKeyboard)) ...[
            const _Divider(),
            _CloseKeyboardButton(softwareKeyboardController: widget.softwareKeyboardController!),
          ],
          if (_toolbarOptions.contains(SimpleSuperChatToolbarOptions.send)) ...[
            const _Divider(),
            _SendButton(onPressed: () {}),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildTopLevelButtons() {
    if (!_hasBlockTypes) {
      // There are no block types, so instead of placing text formatting in a sub-menu
      // we'll put them at the top level.
      return [
        for (final option in _selectTextFormattingOptions()) //
          _buildOptionButton(option),
        if (_toolbarOptions.contains(SimpleSuperChatToolbarOptions.clearStyles)) //
          const _ClearTextFormattingButton(),
      ];
    }

    return [
      if (_hasTextFormatting) //
        const _OpenTextFormattingButton(),
      for (final option in _selectBlockTypeOptions()) //
        _buildOptionButton(option),
    ];
  }

  /// Whether this toolbar includes any options for converting types.
  bool get _hasBlockTypes {
    for (final blockType in _blockTypes) {
      if (_toolbarOptions.contains(blockType)) {
        return true;
      }
    }

    return false;
  }

  List<SimpleSuperChatToolbarOptions> _selectBlockTypeOptions() {
    final blockTypeOptions = <SimpleSuperChatToolbarOptions>[];
    for (final blockType in _blockTypes) {
      if (_toolbarOptions.contains(blockType)) {
        blockTypeOptions.add(blockType);
      }
    }
    return blockTypeOptions;
  }

  bool get _hasTextFormatting {
    for (final textFormat in _textFormats) {
      if (_toolbarOptions.contains(textFormat)) {
        return true;
      }
    }

    return false;
  }

  List<SimpleSuperChatToolbarOptions> _selectTextFormattingOptions() {
    final textFormattingOptions = <SimpleSuperChatToolbarOptions>[];
    for (final textFormat in _textFormats) {
      if (_toolbarOptions.contains(textFormat)) {
        textFormattingOptions.add(textFormat);
      }
    }
    return textFormattingOptions;
  }

  Widget _buildOptionButton(SimpleSuperChatToolbarOptions option) {
    return switch (option) {
      // Text formatting.
      SimpleSuperChatToolbarOptions.bold => throw UnimplementedError(),
      SimpleSuperChatToolbarOptions.italics => throw UnimplementedError(),
      SimpleSuperChatToolbarOptions.underline => throw UnimplementedError(),
      SimpleSuperChatToolbarOptions.strikethrough => throw UnimplementedError(),
      SimpleSuperChatToolbarOptions.code => throw UnimplementedError(),
      SimpleSuperChatToolbarOptions.textColor => throw UnimplementedError(),
      SimpleSuperChatToolbarOptions.backgroundColor => throw UnimplementedError(),
      SimpleSuperChatToolbarOptions.indent => throw UnimplementedError(),
      SimpleSuperChatToolbarOptions.clearStyles => throw UnimplementedError(),

      // Blocks.
      SimpleSuperChatToolbarOptions.orderedListItem => throw UnimplementedError(),
      SimpleSuperChatToolbarOptions.unorderedListItem => throw UnimplementedError(),
      SimpleSuperChatToolbarOptions.blockquote => throw UnimplementedError(),
      SimpleSuperChatToolbarOptions.codeBlock => throw UnimplementedError(),

      // Media.
      SimpleSuperChatToolbarOptions.attach => _AttachmentButton(
          onPressed: widget.onAttachPressed!,
        ),

      // Control.
      SimpleSuperChatToolbarOptions.dictation => const _DictationButton(),
      SimpleSuperChatToolbarOptions.closeKeyboard => _CloseKeyboardButton(
          softwareKeyboardController: widget.softwareKeyboardController!,
        ),
      SimpleSuperChatToolbarOptions.send => _SendButton(
          onPressed: widget.onSendPressed!,
        ),
    };
  }
}

const _blockTypes = [
  SimpleSuperChatToolbarOptions.blockquote,
  SimpleSuperChatToolbarOptions.unorderedListItem,
  SimpleSuperChatToolbarOptions.orderedListItem,
  SimpleSuperChatToolbarOptions.codeBlock,
];

const _textFormats = [
  SimpleSuperChatToolbarOptions.bold,
  SimpleSuperChatToolbarOptions.italics,
  SimpleSuperChatToolbarOptions.underline,
  SimpleSuperChatToolbarOptions.strikethrough,
  SimpleSuperChatToolbarOptions.textColor,
  SimpleSuperChatToolbarOptions.backgroundColor,
];

class _OpenTextFormattingButton extends StatelessWidget {
  const _OpenTextFormattingButton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class _BoldButton extends StatefulWidget {
  const _BoldButton({super.key});

  @override
  State<_BoldButton> createState() => _BoldButtonState();
}

class _BoldButtonState extends State<_BoldButton> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class _ItalicsButton extends StatefulWidget {
  const _ItalicsButton({super.key});

  @override
  State<_ItalicsButton> createState() => _ItalicsButtonState();
}

class _ItalicsButtonState extends State<_ItalicsButton> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class _UnderlineButton extends StatefulWidget {
  const _UnderlineButton({super.key});

  @override
  State<_UnderlineButton> createState() => _UnderlineButtonState();
}

class _UnderlineButtonState extends State<_UnderlineButton> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class _StrikethroughButton extends StatefulWidget {
  const _StrikethroughButton({super.key});

  @override
  State<_StrikethroughButton> createState() => _StrikethroughButtonState();
}

class _StrikethroughButtonState extends State<_StrikethroughButton> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class _TextColorButton extends StatefulWidget {
  const _TextColorButton({super.key});

  @override
  State<_TextColorButton> createState() => _TextColorButtonState();
}

class _TextColorButtonState extends State<_TextColorButton> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class _BackgroundColorButton extends StatefulWidget {
  const _BackgroundColorButton({super.key});

  @override
  State<_BackgroundColorButton> createState() => _BackgroundColorButtonState();
}

class _BackgroundColorButtonState extends State<_BackgroundColorButton> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class _ClearTextFormattingButton extends StatelessWidget {
  const _ClearTextFormattingButton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class _ParagraphBlockButton extends StatefulWidget {
  const _ParagraphBlockButton({super.key});

  @override
  State<_ParagraphBlockButton> createState() => _ParagraphBlockButtonState();
}

class _ParagraphBlockButtonState extends State<_ParagraphBlockButton> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class _BlockquoteButton extends StatefulWidget {
  const _BlockquoteButton({super.key});

  @override
  State<_BlockquoteButton> createState() => _BlockquoteButtonState();
}

class _BlockquoteButtonState extends State<_BlockquoteButton> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class _UnorderedListItemButton extends StatefulWidget {
  const _UnorderedListItemButton({super.key});

  @override
  State<_UnorderedListItemButton> createState() => _UnorderedListItemButtonState();
}

class _UnorderedListItemButtonState extends State<_UnorderedListItemButton> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class _OrderedListItemButton extends StatefulWidget {
  const _OrderedListItemButton({super.key});

  @override
  State<_OrderedListItemButton> createState() => _OrderedListItemButtonState();
}

class _OrderedListItemButtonState extends State<_OrderedListItemButton> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class _CodeBlockButton extends StatefulWidget {
  const _CodeBlockButton({super.key});

  @override
  State<_CodeBlockButton> createState() => _CodeBlockButtonState();
}

class _CodeBlockButtonState extends State<_CodeBlockButton> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class _AttachmentButton extends StatelessWidget {
  const _AttachmentButton({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey.shade200),
      child: _IconButton(
        icon: Icons.add,
        onPressed: onPressed,
      ),
    );
  }
}

class _DictationButton extends StatelessWidget {
  const _DictationButton({super.key});

  @override
  Widget build(BuildContext context) {
    return const _IconButton(icon: Icons.multitrack_audio);
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
  const _SendButton({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _IconButton(
      icon: Icons.send,
      onPressed: onPressed,
    );
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

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Colors.grey.shade300,
    );
  }
}
