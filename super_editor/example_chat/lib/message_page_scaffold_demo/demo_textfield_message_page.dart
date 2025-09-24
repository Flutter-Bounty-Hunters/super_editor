import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

/// A chat experience, which includes a simulated list of comments, as well as
/// a bottom-mounted message editor, which uses a standard Flutter `TextField` for
/// writing messages.
class TextFieldMessagePageDemo extends StatefulWidget {
  const TextFieldMessagePageDemo({super.key});

  @override
  State<TextFieldMessagePageDemo> createState() => _TextFieldMessagePageDemoState();
}

class _TextFieldMessagePageDemoState extends State<TextFieldMessagePageDemo> {
  final _messagePageController = MessagePageController();

  @override
  void dispose() {
    _messagePageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MessagePageScaffold(
      controller: _messagePageController,
      bottomSheetMinimumTopGap: 150,
      bottomSheetMinimumHeight: 148,
      contentBuilder: (contentContext, bottomSpacing) {
        return MediaQuery.removePadding(
          context: contentContext,
          removeBottom: true,
          // ^ Remove bottom padding because if we don't, when the keyboard
          //   opens to edit the bottom sheet, this content behind the bottom
          //   sheet adds some phantom space at the bottom, slightly pushing
          //   it up for no reason.
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(color: Colors.purpleAccent.shade100),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: bottomSpacing,
                child: _ChatThread(),
              ),
            ],
          ),
        );
      },
      bottomSheetBuilder: (messageContext) {
        return _EditorBottomSheet(
          messagePageController: _messagePageController,
        );
      },
    );
  }
}

/// A simulated chat conversation thread, which is simulated as a bottom-aligned
/// list of tiles.
class _ChatThread extends StatelessWidget {
  const _ChatThread();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      reverse: true,
      // ^ The list starts at the bottom and grows upward. This is how
      //   we should layout chat conversations where the most recent
      //   message appears at the bottom, and you want to retain the
      //   scroll offset near the newest messages, not the oldest.
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Material(
            color: Colors.white.withValues(alpha: 0.5),
            child: ListTile(
              title: Text("Item $index"),
            ),
          ),
        );
      },
    );
  }
}

/// Bottom sheet, which includes a message editor.
class _EditorBottomSheet extends StatefulWidget {
  const _EditorBottomSheet({
    required this.messagePageController,
  });

  final MessagePageController messagePageController;

  @override
  State<_EditorBottomSheet> createState() => _EditorBottomSheetState();
}

class _EditorBottomSheetState extends State<_EditorBottomSheet> {
  final _dragIndicatorKey = GlobalKey();

  final _scrollController = ScrollController();

  final _editorSheetKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();

    super.dispose();
  }

  double _dragTouchOffsetFromIndicator = 0;

  void _onVerticalDragStart(DragStartDetails details) {
    _dragTouchOffsetFromIndicator = _dragFingerOffsetFromIndicator(details.globalPosition);

    widget.messagePageController.onDragStart(
      details.globalPosition.dy - _dragIndicatorOffsetFromTop + _dragTouchOffsetFromIndicator,
    );
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    widget.messagePageController.onDragUpdate(
      details.globalPosition.dy - _dragIndicatorOffsetFromTop + _dragTouchOffsetFromIndicator,
    );
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    widget.messagePageController.onDragEnd();
  }

  void _onVerticalDragCancel() {
    widget.messagePageController.onDragEnd();
  }

  double get _dragIndicatorOffsetFromTop {
    final editorSheetBox = _editorSheetKey.currentContext!.findRenderObject();
    final dragIndicatorBox = _dragIndicatorKey.currentContext!.findRenderObject()! as RenderBox;

    return dragIndicatorBox.localToGlobal(Offset.zero, ancestor: editorSheetBox).dy;
  }

  double _dragFingerOffsetFromIndicator(Offset globalDragOffset) {
    final dragIndicatorBox = _dragIndicatorKey.currentContext!.findRenderObject()! as RenderBox;

    return dragIndicatorBox.localToGlobal(Offset.zero).dy - globalDragOffset.dy;
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: _editorSheetKey,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        border: Border(top: BorderSide(color: Colors.grey)),
      ),
      child: KeyboardScaffoldSafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDragHandle(),
            Flexible(
              child: _buildSheetContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetContent() {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom,
        // ^ Avoid the bottom notch when the keyboard is closed.
      ),
      child: BottomSheetEditorHeight(
        previewHeight: 72,
        child: _ChatEditor(
          key: _editorKey,
          messagePageController: widget.messagePageController,
        ),
      ),
    );
  }

  // FIXME: Keyboard keeps closing without a bunch of global keys. Either
  //        document why, or figure out how to operate without all the keys.
  final _editorKey = GlobalKey();

  Widget _buildDragHandle() {
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
            padding: const EdgeInsets.all(18),
            // ^ Expand the hit area with invisible padding.
            child: Container(
              key: _dragIndicatorKey,
              width: 32,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// An editor for composing chat messages.
class _ChatEditor extends StatefulWidget {
  const _ChatEditor({
    super.key,
    required this.messagePageController,
  });

  final MessagePageController messagePageController;

  @override
  State<_ChatEditor> createState() => _ChatEditorState();
}

class _ChatEditorState extends State<_ChatEditor> implements SoftwareKeyboardControllerDelegate {
  final _textFieldFocusNode = FocusNode();

  final _scrollController = ScrollController();

  late final KeyboardPanelController<_Panel> _keyboardPanelController;
  late final SoftwareKeyboardController _softwareKeyboardController;
  final _isImeConnected = ValueNotifier(false);

  @override
  void initState() {
    super.initState();

    _softwareKeyboardController = SoftwareKeyboardController();
    _keyboardPanelController = KeyboardPanelController(
      _softwareKeyboardController,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keyboardPanelController.toolbarVisibility = KeyboardToolbarVisibility.auto;
    });

    widget.messagePageController.addListener(_onMessagePageControllerChange);

    _textFieldFocusNode.addListener(_onFocusChange);

    _isImeConnected.value = _textFieldFocusNode.hasFocus;
    _isImeConnected.addListener(_onImeConnectionChange);

    _softwareKeyboardController.attach(this);
  }

  @override
  void didUpdateWidget(_ChatEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.messagePageController != oldWidget.messagePageController) {
      oldWidget.messagePageController.removeListener(_onMessagePageControllerChange);
      widget.messagePageController.addListener(_onMessagePageControllerChange);
    }
  }

  @override
  void dispose() {
    _softwareKeyboardController.detach();

    widget.messagePageController.removeListener(_onMessagePageControllerChange);

    _scrollController.dispose();

    _keyboardPanelController.dispose();
    _isImeConnected.dispose();

    _textFieldFocusNode.dispose();

    super.dispose();
  }

  void _onFocusChange() {
    // Flutter doesn't report actual IME connection status. For simplicity,
    // assume focus means IME connection is open.
    _isImeConnected.value = _textFieldFocusNode.hasFocus;
  }

  void _onImeConnectionChange() {
    widget.messagePageController.collapsedMode =
        _isImeConnected.value ? MessagePageSheetCollapsedMode.intrinsic : MessagePageSheetCollapsedMode.preview;
  }

  void _onMessagePageControllerChange() {
    if (widget.messagePageController.isPreview) {
      // Always scroll the editor to the top when in preview mode.
      _scrollController.position.jumpTo(0);
    }
  }

  @override
  bool get isConnectedToIme => _textFieldFocusNode.hasFocus;

  @override
  void open({
    required int viewId,
  }) {
    _textFieldFocusNode.requestFocus();
  }

  @override
  void hide() {
    // Can't hide without deeper IME integration.
  }

  @override
  void close() {
    _textFieldFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardPanelScaffold(
      controller: _keyboardPanelController,
      isImeConnected: _isImeConnected,
      toolbarBuilder: (BuildContext context, _Panel? openPanel) {
        return Container(
          width: double.infinity,
          height: 54,
          color: Colors.white.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Spacer(),
              GestureDetector(
                onTap: () {
                  _softwareKeyboardController.close();
                },
                child: Icon(Icons.keyboard_hide_outlined),
              ),
            ],
          ),
        );
      },
      keyboardPanelBuilder: (BuildContext context, _Panel? openPanel) {
        return SizedBox();
      },
      contentBuilder: (BuildContext context, _Panel? openPanel) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: IntrinsicHeight(
            child: TextField(
              key: _editorKey,
              focusNode: _textFieldFocusNode,
              scrollController: _scrollController,
              decoration: InputDecoration(
                hintText: "Write message...",
              ),
              maxLines: null,
            ),
          ),
        );
      },
    );
  }

  final _editorKey = GlobalKey();
}

enum _Panel {
  thePanel;
}
