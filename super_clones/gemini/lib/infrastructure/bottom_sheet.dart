import 'dart:math';

import 'package:flutter/material.dart';
import 'package:gemini/infrastructure/theme.dart';
import 'package:super_editor/super_editor.dart';

class ChatEditorBottomSheet extends StatefulWidget {
  const ChatEditorBottomSheet({super.key, this.editorFocusNode});

  final FocusNode? editorFocusNode;

  @override
  State<ChatEditorBottomSheet> createState() => _ChatEditorBottomSheetState();
}

class _ChatEditorBottomSheetState extends State<ChatEditorBottomSheet> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: windowBackgroundColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24), //
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.15), //
            blurRadius: 20,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.05), //
            blurRadius: 40,
          ),
        ],
      ),
      child: KeyboardScaffoldSafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Editor(focusNode: widget.editorFocusNode),
            _Toolbar(),
            // Push above bottom notch when keyboard closed, and create a small
            // bottom gap when keyboard is open.
            SizedBox(height: max(MediaQuery.paddingOf(context).bottom, 12)),
          ],
        ),
      ),
    );
  }
}

class _Editor extends StatefulWidget {
  const _Editor({this.focusNode});

  final FocusNode? focusNode;

  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  late FocusNode _focusNode;
  late final Editor _editor;

  @override
  void initState() {
    super.initState();

    _focusNode = widget.focusNode ?? FocusNode(debugLabel: "editor");

    _editor = createDefaultDocumentEditor(document: MutableDocument.empty(), composer: MutableDocumentComposer());
  }

  @override
  void didUpdateWidget(covariant _Editor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.focusNode != oldWidget.focusNode) {
      if (oldWidget.focusNode == null) {
        _focusNode.dispose();
      }
      _focusNode = widget.focusNode ?? FocusNode(debugLabel: "editor");
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: SuperEditorDryLayout(
        superEditor: SuperEditor(
          focusNode: _focusNode,
          editor: _editor, //
          stylesheet: _chatStylesheet,
          imePolicies: SuperEditorImePolicies(closeKeyboardOnLosePrimaryFocus: true),
          componentBuilders: [
            HintComponentBuilder("Ask Gemini", (attributions) {
              return TextStyle(color: const Color(0xFF9a9b9c));
            }),
            ...defaultComponentBuilders,
          ],
        ),
      ),
    );
  }
}

final _chatStylesheet = Stylesheet(
  rules: [
    StyleRule(BlockSelector.all, (doc, docNode) {
      return {
        Styles.padding: const CascadingPadding.symmetric(horizontal: 24),
        Styles.textStyle: const TextStyle(color: Colors.black, fontSize: 18, height: 1.4),
      };
    }),
    StyleRule(const BlockSelector("header1"), (doc, docNode) {
      return {Styles.textStyle: const TextStyle(color: Color(0xFF333333), fontSize: 38, fontWeight: FontWeight.bold)};
    }),
    StyleRule(const BlockSelector("header2"), (doc, docNode) {
      return {Styles.textStyle: const TextStyle(color: Color(0xFF333333), fontSize: 26, fontWeight: FontWeight.bold)};
    }),
    StyleRule(const BlockSelector("header3"), (doc, docNode) {
      return {Styles.textStyle: const TextStyle(color: Color(0xFF333333), fontSize: 22, fontWeight: FontWeight.bold)};
    }),
    StyleRule(const BlockSelector("paragraph"), (doc, docNode) {
      return {Styles.padding: const CascadingPadding.only(bottom: 12)};
    }),
    StyleRule(const BlockSelector("blockquote"), (doc, docNode) {
      return {
        Styles.textStyle: const TextStyle(color: Colors.grey, fontSize: 20, fontWeight: FontWeight.bold, height: 1.4),
      };
    }),
    StyleRule(BlockSelector.all.first(), (doc, docNode) {
      return {Styles.padding: const CascadingPadding.only(top: 24)};
    }),
    StyleRule(BlockSelector.all.last(), (doc, docNode) {
      return {Styles.padding: const CascadingPadding.only(bottom: 24)};
    }),
  ],
  inlineTextStyler: defaultInlineTextStyler,
  inlineWidgetBuilders: defaultInlineWidgetBuilderChain,
);

class _Toolbar extends StatelessWidget {
  const _Toolbar();

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 8,
      children: [
        SizedBox(width: 0),
        _ToolbarIconButton(Icons.add, _IconButtonMode.floating),
        _ToolbarIconButton(Icons.settings, _IconButtonMode.floating),
        Spacer(),
        _ToolbarTextButton("2.5 Flash"),
        _ToolbarIconButton(Icons.mic, _IconButtonMode.border),
        _ToolbarIconButton(Icons.multitrack_audio, _IconButtonMode.filled),
        SizedBox(width: 4),
      ],
    );
  }
}

class _ToolbarTextButton extends StatelessWidget {
  const _ToolbarTextButton(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: ShapeDecoration(
        shape: StadiumBorder(side: BorderSide(color: _toolbarButtonBorderColor)),
        color: windowBackgroundColor,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Center(child: Text(label, style: TextStyle(fontSize: 13))),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton(this.icon, this.mode);

  final IconData icon;
  final _IconButtonMode mode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(shape: BoxShape.circle, color: _background, border: _border),
      child: Center(
        child: Icon(icon, size: _iconSize, color: windowForegroundColor),
      ),
    );
  }

  double get _iconSize => switch (mode) {
    _IconButtonMode.floating => 28,
    _IconButtonMode.border => 20,
    _IconButtonMode.filled => 20,
  };

  Color get _background => switch (mode) {
    _IconButtonMode.floating => Colors.transparent,
    _IconButtonMode.border => Colors.transparent,
    _IconButtonMode.filled => _toolbarFeaturedCircleButtonBackgroundColor,
  };

  Border? get _border => switch (mode) {
    _IconButtonMode.floating => null,
    _IconButtonMode.border => Border.all(color: _toolbarButtonBorderColor),
    _IconButtonMode.filled => null,
  };
}

enum _IconButtonMode { floating, border, filled }

const _toolbarButtonBorderColor = Color(0xFF2f3031);
const _toolbarFeaturedCircleButtonBackgroundColor = Color(0xFF282a2c);
