import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:super_editor/src/chat/bottom_floating/default/default_editor_toolbar.dart';
import 'package:super_editor/src/chat/bottom_floating/ui_kit/floating_editor_sheet.dart';
import 'package:super_editor/src/chat/chat_editor.dart';
import 'package:super_editor/src/chat/message_page_scaffold.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/default_editor/document_ime/document_input_ime.dart';
import 'package:super_editor/src/infrastructure/keyboard_panel_scaffold.dart';

/// A super ellipse sheet, which contains a drag handle, editor, and toolbar.
///
/// This sheet can optionally be composed into a larger sheet, which includes a shadow
/// sheet. In that case, a [sheetKey] must be provided which is attached to the outermost
/// boundary of the whole sheet. The whole sheet boundary is used to enforce a max and min
/// height for the sheet as the user drags it.
class DefaultFloatingEditorSheet extends StatefulWidget {
  const DefaultFloatingEditorSheet({
    super.key,
    required this.editor,
    this.sheetKey,
    required this.messagePageController,
    this.visualEditor,
    this.style = const EditorSheetStyle(),
  });

  final Editor editor;

  /// A [GlobalKey] that's attached to the outermost boundary of the sheet that
  /// contains this [DefaultFloatingEditorSheet].
  ///
  /// In the typical case, [DefaultFloatingEditorSheet] is the outermost boundary, in which case
  /// no key needs to be provided. This widget will create a key internally.
  ///
  /// However, if additional content is added above or below this [DefaultFloatingEditorSheet] then
  /// we need to be able to account for the global offset of that content. To make layout
  /// decisions based on the entire sheet, clients must wrap the whole sheet with a [GlobalKey]
  /// and provide that key as [sheetKey].
  final GlobalKey? sheetKey;

  final MessagePageController messagePageController;

  final Widget? visualEditor;

  final EditorSheetStyle style;

  @override
  State<DefaultFloatingEditorSheet> createState() => _DefaultFloatingEditorSheetState();
}

class _DefaultFloatingEditorSheetState extends State<DefaultFloatingEditorSheet> {
  final _dragIndicatorKey = GlobalKey();

  final _scrollController = ScrollController();

  final _editorFocusNode = FocusNode();
  late GlobalKey _sheetKey;
  final _editorSheetKey = GlobalKey(debugLabel: "editor-sheet-within-bigger-sheet");
  late final SoftwareKeyboardController _softwareKeyboardController;

  final _hasSelection = ValueNotifier(false);

  bool _isUserPressingDown = false;

  @override
  void initState() {
    super.initState();

    _softwareKeyboardController = SoftwareKeyboardController();

    _sheetKey = widget.sheetKey ?? GlobalKey();

    widget.editor.composer.selectionNotifier.addListener(_onSelectionChange);
  }

  @override
  void didUpdateWidget(DefaultFloatingEditorSheet oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.editor != oldWidget.editor) {
      oldWidget.editor.composer.selectionNotifier.removeListener(_onSelectionChange);
      widget.editor.composer.selectionNotifier.addListener(_onSelectionChange);
    }

    if (widget.sheetKey != _sheetKey) {
      _sheetKey = widget.sheetKey ?? GlobalKey();
    }
  }

  @override
  void dispose() {
    widget.editor.composer.selectionNotifier.removeListener(_onSelectionChange);

    _editorFocusNode.dispose();

    _scrollController.dispose();

    super.dispose();
  }

  void _onSelectionChange() {
    _hasSelection.value = widget.editor.composer.selection != null;

    // If the editor doesn't have a selection then when it's collapsed it
    // should be in preview mode. If the editor does have a selection, then
    // when it's collapsed, it should be in intrinsic height mode.
    widget.messagePageController.collapsedMode =
        _hasSelection.value ? MessagePageSheetCollapsedMode.intrinsic : MessagePageSheetCollapsedMode.preview;
  }

  double _dragTouchOffsetFromIndicator = 0;

  void _onVerticalDragStart(DragStartDetails details) {
    _dragTouchOffsetFromIndicator = _dragFingerOffsetFromIndicator(details.globalPosition);

    widget.messagePageController.onDragStart(
      details.globalPosition.dy - _dragIndicatorOffsetFromTop - _dragTouchOffsetFromIndicator,
    );
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    widget.messagePageController.onDragUpdate(
      details.globalPosition.dy - _dragIndicatorOffsetFromTop - _dragTouchOffsetFromIndicator,
    );
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    widget.messagePageController.onDragEnd();
  }

  void _onVerticalDragCancel() {
    widget.messagePageController.onDragEnd();
  }

  double get _dragIndicatorOffsetFromTop {
    final bottomSheetBox = _sheetKey.currentContext!.findRenderObject();
    final dragIndicatorBox = _dragIndicatorKey.currentContext!.findRenderObject()! as RenderBox;

    return dragIndicatorBox.localToGlobal(Offset.zero, ancestor: bottomSheetBox).dy;
  }

  double _dragFingerOffsetFromIndicator(Offset globalDragOffset) {
    final dragIndicatorBox = _dragIndicatorKey.currentContext!.findRenderObject()! as RenderBox;

    return globalDragOffset.dy - dragIndicatorBox.localToGlobal(Offset.zero).dy;
  }

  @override
  Widget build(BuildContext context) {
    return _buildSheet(
      child: _buildSheetContent(),
    );
  }

  Widget _buildSheet({
    required Widget child,
  }) {
    return KeyedSubtree(
      // If we're provided with a [widget.sheetKey] it means the full sheet boundary
      // expands beyond this widget, and that key is attached to that outer boundary.
      // If we're not provided with a [widget.sheetKey], it's because we are the outer
      // boundary, so we need to key our subtree for layout calculations.
      key: widget.sheetKey == null ? _sheetKey : _editorSheetKey,
      child: Listener(
        onPointerDown: (_) => setState(() {
          _isUserPressingDown = true;
        }),
        onPointerUp: (_) => setState(() {
          _isUserPressingDown = false;
        }),
        onPointerCancel: (_) => setState(() {
          _isUserPressingDown = false;
        }),
        child: ClipRSuperellipse(
          borderRadius: BorderRadius.all(widget.style.borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4, tileMode: TileMode.decal),
            child: Container(
              decoration: ShapeDecoration(
                color: widget.style.background.withValues(alpha: _isUserPressingDown ? 1.0 : 0.8),
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.all(widget.style.borderRadius),
                ),
              ),
              child: KeyboardScaffoldSafeArea(
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSheetContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDragHandle(),
        Flexible(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListenableBuilder(
                listenable: _editorFocusNode,
                builder: (context, child) {
                  if (_editorFocusNode.hasFocus) {
                    return const SizedBox();
                  }

                  return const Padding(
                    padding: EdgeInsets.only(left: 12, bottom: 12),
                    child: AttachmentButton(),
                  );
                },
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _buildVisualEditor(),
                ),
              ),
              ListenableBuilder(
                listenable: _editorFocusNode,
                builder: (context, child) {
                  if (_editorFocusNode.hasFocus) {
                    return const SizedBox();
                  }

                  return const Padding(
                    padding: EdgeInsets.only(right: 12, bottom: 12),
                    child: DictationButton(),
                  );
                },
              ),
            ],
          ),
        ),
        ListenableBuilder(
          listenable: _editorFocusNode,
          builder: (context, child) {
            if (!_editorFocusNode.hasFocus) {
              return const SizedBox();
            }

            return _buildToolbar();
          },
        )
      ],
    );
  }

  Widget _buildVisualEditor() {
    return BottomSheetEditorHeight(
      previewHeight: 32,
      child: widget.visualEditor ??
          SuperChatEditor(
            key: _editorKey,
            editorFocusNode: _editorFocusNode,
            editor: widget.editor,
            messagePageController: widget.messagePageController,
            scrollController: _scrollController,
            softwareKeyboardController: _softwareKeyboardController,
          ),
    );
  }

  // FIXME: Keyboard keeps closing without a bunch of global keys. Either
  final _editorKey = GlobalKey();

  Widget _buildDragHandle() {
    return ListenableBuilder(
      listenable: _editorFocusNode,
      builder: (context, child) {
        if (!_editorFocusNode.hasFocus) {
          return const SizedBox(height: 12);
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onVerticalDragStart: _onVerticalDragStart,
              onVerticalDragUpdate: _onVerticalDragUpdate,
              onVerticalDragEnd: _onVerticalDragEnd,
              onVerticalDragCancel: _onVerticalDragCancel,
              behavior: HitTestBehavior.opaque,
              // ^ Opaque to handle tough events in our invisible padding.
              child: Padding(
                padding: const EdgeInsets.all(8),
                // ^ Expand the hit area with invisible padding.
                child: Container(
                  key: _dragIndicatorKey,
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildToolbar() {
    return SuperChatFloatingSheetToolbar(
      editor: widget.editor,
      softwareKeyboardController: _softwareKeyboardController,
      onAttachPressed: () {},
      onSendPressed: () {},
    );

    // return Padding(
    //   padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
    //   child: FloatingEditorToolbar(
    //     softwareKeyboardController: _softwareKeyboardController,
    //   ),
    // );
  }
}

// // TODO: Delete the following fake toolbar in favor of a configurable real one
// class FloatingEditorToolbar extends StatelessWidget {
//   const FloatingEditorToolbar({
//     super.key,
//     required this.softwareKeyboardController,
//   });
//
//   final SoftwareKeyboardController softwareKeyboardController;
//
//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         const Expanded(
//           child: SingleChildScrollView(
//             scrollDirection: Axis.horizontal,
//             child: Row(
//               spacing: 4,
//               children: [
//                 AttachmentButton(),
//                 _IconButton(icon: Icons.format_bold),
//                 _IconButton(icon: Icons.format_italic),
//                 _IconButton(icon: Icons.format_underline),
//                 _IconButton(icon: Icons.format_strikethrough),
//                 _IconButton(icon: Icons.format_color_fill),
//                 _IconButton(icon: Icons.format_quote),
//                 _IconButton(icon: Icons.format_align_left),
//                 _IconButton(icon: Icons.format_align_center),
//                 _IconButton(icon: Icons.format_align_right),
//                 _IconButton(icon: Icons.format_align_justify),
//               ],
//             ),
//           ),
//         ),
//         _buildDivider(),
//         _CloseKeyboardButton(
//           softwareKeyboardController: softwareKeyboardController,
//         ),
//         _buildDivider(),
//         const _SendButton(),
//       ],
//     );
//   }
//
//   Widget _buildDivider() {
//     return Container(
//       width: 1,
//       height: 16,
//       margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
//       color: Colors.grey.shade300,
//     );
//   }
// }
//
class AttachmentButton extends StatelessWidget {
  const AttachmentButton({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey.shade200),
      child: const _IconButton(
        icon: Icons.add,
      ),
    );
  }
}

class DictationButton extends StatelessWidget {
  const DictationButton({super.key});

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
  const _SendButton();

  @override
  Widget build(BuildContext context) {
    return const _IconButton(icon: Icons.send);
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
