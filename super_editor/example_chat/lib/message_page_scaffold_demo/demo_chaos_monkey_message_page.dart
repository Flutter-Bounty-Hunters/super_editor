import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';

/// A chat experience, which includes a simulated list of comments, as well as
/// a bottom-mounted message editor.
///
/// In the case of this chaos monkey demo, instead of including a message editor,
/// this demo includes a colorful rectangle that constantly changes its height,
/// which helps to verify a variety of layout situations.
class ChaosMonkeyMessagePageDemo extends StatefulWidget {
  const ChaosMonkeyMessagePageDemo({super.key});

  @override
  State<ChaosMonkeyMessagePageDemo> createState() => _ChaosMonkeyMessagePageDemoState();
}

class _ChaosMonkeyMessagePageDemoState extends State<ChaosMonkeyMessagePageDemo> {
  final _messagePageController = MessagePageController();

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

/// Bottom sheet that represents where a message editor would usually appear,
/// but in this case it has a constantly animating content rectangle.
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
  void initState() {
    super.initState();
  }

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
          messagePageController: widget.messagePageController,
        ),
      ),
    );
  }

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
    required this.messagePageController,
  });

  final MessagePageController messagePageController;

  @override
  State<_ChatEditor> createState() => _ChatEditorState();
}

class _ChatEditorState extends State<_ChatEditor> with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();

  late final KeyboardPanelController<_Panel> _keyboardPanelController;
  late final SoftwareKeyboardController _softwareKeyboardController;
  final _isImeConnected = ValueNotifier(false);

  late final AnimationController _chaosMonkeyAnimation;
  Timer? _chaosPauseTimer;

  @override
  void initState() {
    super.initState();

    _softwareKeyboardController = SoftwareKeyboardController() //
      ..attach(_DoNothingSoftwareKeyboardControllerDelegate());
    _keyboardPanelController = KeyboardPanelController(
      _softwareKeyboardController,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // FIXME: We have to run this in a post frame callback because it requires an attached
      //        delegate, which isn't available until the next frame. We should create a
      //        setting for what's desired and let the delegate deal with it.
      _keyboardPanelController.toolbarVisibility = KeyboardToolbarVisibility.visible;
    });

    widget.messagePageController.addListener(_onMessagePageControllerChange);

    _chaosMonkeyAnimation = AnimationController(
      vsync: this,
      lowerBound: 75,
      upperBound: 750,
      duration: const Duration(seconds: 3),
    )
      ..addStatusListener(_onAnimationStatusChange)
      ..forward();

    _onImeConnectionChange();
    _isImeConnected.addListener(_onImeConnectionChange);
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
    _chaosMonkeyAnimation.dispose();
    _chaosPauseTimer?.cancel();

    widget.messagePageController.removeListener(_onMessagePageControllerChange);

    _scrollController.dispose();

    _keyboardPanelController.dispose();
    _isImeConnected.dispose();

    super.dispose();
  }

  void _onImeConnectionChange() {
    widget.messagePageController.collapsedMode =
        _isImeConnected.value ? MessagePageSheetCollapsedMode.intrinsic : MessagePageSheetCollapsedMode.preview;
  }

  void _onAnimationStatusChange(AnimationStatus status) {
    const pauseDuration = Duration(seconds: 3);
    _chaosPauseTimer?.cancel();

    switch (status) {
      case AnimationStatus.dismissed:
        _chaosPauseTimer = Timer(pauseDuration, _startAfterPause);
      case AnimationStatus.completed:
        _chaosPauseTimer = Timer(pauseDuration, _reverseAfterPause);
      case AnimationStatus.forward:
      case AnimationStatus.reverse:
      // Don't care.
    }
  }

  void _startAfterPause() {
    _chaosMonkeyAnimation.forward();
  }

  void _reverseAfterPause() {
    _chaosMonkeyAnimation.reverse();
  }

  void _onMessagePageControllerChange() {
    if (widget.messagePageController.isPreview) {
      // Always scroll the editor to the top when in preview mode.
      _scrollController.position.jumpTo(0);
    }
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
                  _softwareKeyboardController.open(viewId: View.of(context).viewId);
                  _isImeConnected.value = true;
                },
                child: Icon(Icons.keyboard_alt_rounded),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () {
                  _softwareKeyboardController.close();
                  _isImeConnected.value = false;
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
        return AnimatedBuilder(
          animation: _chaosMonkeyAnimation,
          builder: (context, snapshot) {
            return CupertinoScrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              thickness: 10,
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Container(
                  height: _chaosMonkeyAnimation.value,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purpleAccent, Colors.deepPurple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

enum _Panel {
  thePanel;
}

class _DoNothingSoftwareKeyboardControllerDelegate implements SoftwareKeyboardControllerDelegate {
  TextInputConnection? _textInputConnection;

  @override
  bool get isConnectedToIme => _textInputConnection != null;

  @override
  void open({
    required int viewId,
  }) {
    print("ATTACHING TO TEXT INPUT CLIENT");
    _textInputConnection = TextInput.attach(
      _InvisibleTextInputClient(),
      TextInputConfiguration(viewId: viewId),
    )..show();
  }

  @override
  void hide() {
    SystemChannels.textInput.invokeListMethod("TextInput.hide");
  }

  @override
  void close() {
    _textInputConnection?.close();
    _textInputConnection = null;
  }
}

class _InvisibleTextInputClient implements TextInputClient {
  @override
  void connectionClosed() {
    // TODO: implement connectionClosed
  }

  @override
  // TODO: implement currentAutofillScope
  AutofillScope? get currentAutofillScope => throw UnimplementedError();

  @override
  TextEditingValue? get currentTextEditingValue => TextEditingValue();

  @override
  void didChangeInputControl(TextInputControl? oldControl, TextInputControl? newControl) {
    // TODO: implement didChangeInputControl
  }

  @override
  void insertContent(KeyboardInsertedContent content) {
    // TODO: implement insertContent
  }

  @override
  void insertTextPlaceholder(Size size) {
    // TODO: implement insertTextPlaceholder
  }

  @override
  void performAction(TextInputAction action) {
    // TODO: implement performAction
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {
    // TODO: implement performPrivateCommand
  }

  @override
  void performSelector(String selectorName) {
    // TODO: implement performSelector
  }

  @override
  void removeTextPlaceholder() {
    // TODO: implement removeTextPlaceholder
  }

  @override
  void showAutocorrectionPromptRect(int start, int end) {
    // TODO: implement showAutocorrectionPromptRect
  }

  @override
  void showToolbar() {
    // TODO: implement showToolbar
  }

  @override
  void updateEditingValue(TextEditingValue value) {
    // TODO: implement updateEditingValue
  }

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {
    // TODO: implement updateFloatingCursor
  }

  @override
  bool onFocusReceived() {
    // TODO: implement onFocusReceived
    throw UnimplementedError();
  }
}
