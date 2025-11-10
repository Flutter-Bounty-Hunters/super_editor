import 'package:flutter/material.dart';
import 'package:slack/styles.dart';
import 'package:super_editor/super_editor.dart';

/// An input field where users can compose rich text messages.
class MobileMessageEditor extends StatefulWidget {
  const MobileMessageEditor({
    super.key,
    required this.hintText,
    required this.messagePageController,
    required this.onSendMessage,
  });

  final String hintText;
  final MessagePageController messagePageController;
  final OnSendMessage onSendMessage;

  @override
  State<MobileMessageEditor> createState() => _MobileMessageEditorState();
}

class _MobileMessageEditorState extends State<MobileMessageEditor> {
  final _dragIndicatorKey = GlobalKey();
  final _panelFocusNode = FocusNode();
  final _editorFocusNode = FocusNode();

  final _scrollController = ScrollController();

  final _editorSheetKey = GlobalKey();
  late Editor _editor;

  /// The message being composed.
  late MutableDocument _document;

  double _dragTouchOffsetFromIndicator = 0;

  // FIXME: Keyboard keeps closing without a bunch of global keys. Either
  //        document why, or figure out how to operate without all the keys.
  final _editorKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _panelFocusNode.addListener(_onFocusChange);
    _createDocument();
  }

  @override
  void dispose() {
    _panelFocusNode.removeListener(_onFocusChange);
    _panelFocusNode.dispose();

    _editorFocusNode.dispose();

    _document.removeListener(_onDocumentChange);
    super.dispose();
  }

  void _onDocumentChange(DocumentChangeLog changeLog) {
    setState(() {});
  }

  void _onFocusChange() {
    // Reflow the layout to show the editor when the panel is focused.
    setState(() {});

    // Request focus on the editor when the panel is focused.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_panelFocusNode.hasFocus) {
        _editorFocusNode.requestFocus();
      }
    });
  }

  /// Create a document with an empty paragraph.
  ///
  /// If [withSelection] is `true`, selection is placed at the beginning of the document,
  /// and the caret is displayed.
  void _createDocument({bool withSelection = false}) {
    _document = MutableDocument(
      nodes: [
        ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText(''),
        ),
      ],
    );

    _document.addListener(_onDocumentChange);

    final composer = MutableDocumentComposer(
      initialSelection: withSelection
          ? DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: _document.first.id,
                nodePosition: const TextNodePosition(offset: 0),
              ),
            )
          : null,
    );

    _editor = Editor(
      editables: {Editor.documentKey: _document, Editor.composerKey: composer},
      requestHandlers: [...defaultRequestHandlers],
      reactionPipeline: List.from(defaultEditorReactions),
    );
  }

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

  void _sendMessage() {
    widget.onSendMessage(_document);

    // Reset the editor to an empty state.
    _createDocument(withSelection: true);
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: _editorSheetKey,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        border: Border(
          top: BorderSide(width: 1, color: borderColor),
        ),
      ),
      child: KeyboardScaffoldSafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom,
            // ^ Avoid the bottom notch when the keyboard is closed.
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_panelFocusNode.hasFocus) //
                _buildDragHandle()
              else
                const SizedBox(height: 10),
              Flexible(
                child: _buildSheetContent(),
              ),
              if (_panelFocusNode.hasFocus)
                _SlackMobileEditorToolbar(
                  onSendMessage: _document.isEmpty ||
                          (_document.nodeCount == 1 &&
                              _document.first is TextNode &&
                              (_document.first as TextNode).text.isEmpty)
                      ? null
                      : _sendMessage,
                ),
            ],
          ),
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
          // ^ Opaque to handle touch events in our invisible padding.
          child: Padding(
            padding: const EdgeInsets.all(18),
            // ^ Expand the hit area with invisible padding.
            child: Container(
              key: _dragIndicatorKey,
              width: 48,
              height: 3,
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

  Widget _buildSheetContent() {
    return Focus(
      focusNode: _panelFocusNode,
      child: BottomSheetEditorHeight(
        previewHeight: 42,
        child: _panelFocusNode.hasFocus //
            ? _buildChatEditor()
            : _buildNonFocusedBottomPanel(),
      ),
    );
  }

  Widget _buildChatEditor() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: _ChatEditor(
        key: _editorKey,
        editor: _editor,
        editorFocusNode: _editorFocusNode,
        hintText: widget.hintText,
        messagePageController: widget.messagePageController,
        scrollController: _scrollController,
        onSendMessage: _sendMessage,
      ),
    );
  }

  /// A bottom panel that is shown when the editor is not focused.
  ///
  /// This panel contains a hint text, an add button and the microphone button.
  Widget _buildNonFocusedBottomPanel() {
    return GestureDetector(
      onTap: () => _panelFocusNode.requestFocus(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5.0),
        child: Row(
          children: [
            _AddButton(),
            Expanded(
              child: Text(
                widget.hintText,
                style: _hintTextStyleBuilder(context, {}),
              ),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(
                Icons.mic_none_outlined,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An editor for composing chat messages.
class _ChatEditor extends StatefulWidget {
  const _ChatEditor({
    super.key,
    required this.editor,
    required this.hintText,
    required this.editorFocusNode,
    required this.messagePageController,
    required this.scrollController,
    required this.onSendMessage,
  });

  final Editor editor;
  final String hintText;
  final FocusNode editorFocusNode;
  final MessagePageController messagePageController;
  final ScrollController scrollController;
  final VoidCallback onSendMessage;

  @override
  State<_ChatEditor> createState() => _ChatEditorState();
}

class _ChatEditorState extends State<_ChatEditor> {
  final _editorKey = GlobalKey();

  final _isImeConnected = ValueNotifier(false);

  @override
  void initState() {
    super.initState();

    widget.messagePageController.addListener(_onMessagePageControllerChange);
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
    widget.messagePageController.removeListener(_onMessagePageControllerChange);
    widget.scrollController.dispose();
    _isImeConnected.dispose();

    super.dispose();
  }

  void _onImeConnectionChange() {
    widget.messagePageController.collapsedMode = _isImeConnected.value //
        ? MessagePageSheetCollapsedMode.intrinsic
        : MessagePageSheetCollapsedMode.preview;
  }

  void _onMessagePageControllerChange() {
    if (widget.messagePageController.isPreview) {
      // Always scroll the editor to the top when in preview mode.
      widget.scrollController.position.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SuperEditorDryLayout(
      controller: widget.scrollController,
      superEditor: SuperEditor(
        key: _editorKey,
        focusNode: widget.editorFocusNode,
        editor: widget.editor,
        isImeConnected: _isImeConnected,
        imePolicies: SuperEditorImePolicies(),
        selectionPolicies: SuperEditorSelectionPolicies(),
        shrinkWrap: false,
        stylesheet: messageEditorStylesheet,
        componentBuilders: [
          HintComponentBuilder.basic(
            widget.hintText,
            hintStyleBuilder: _hintTextStyleBuilder,
          ),
          ...defaultComponentBuilders,
        ],
      ),
    );
  }
}

TextStyle _hintTextStyleBuilder(BuildContext context, Set<Attribution> attributions) => TextStyle(
      fontSize: 14,
      color: Colors.grey,
    );

class _SlackMobileEditorToolbar extends StatefulWidget {
  const _SlackMobileEditorToolbar({
    required this.onSendMessage,
  });

  final VoidCallback? onSendMessage;

  @override
  State<_SlackMobileEditorToolbar> createState() => _SlackMobileEditorToolbarState();
}

class _SlackMobileEditorToolbarState extends State<_SlackMobileEditorToolbar> {
  @override
  Widget build(BuildContext context) {
    return IconButtonTheme(
      data: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
        ),
      ),
      child: Material(
        child: Container(
          width: double.infinity,
          color: backgroundColor,
          child: Row(
            children: [
              _AddButton(),
              IconButton(onPressed: () {}, icon: const Icon(Icons.format_size)),
              IconButton(onPressed: () {}, icon: const Icon(Icons.emoji_emotions_outlined)),
              IconButton(onPressed: () {}, icon: const Icon(Icons.alternate_email)),
              Spacer(),
              widget.onSendMessage != null
                  ? CircleAvatar(
                      backgroundColor: Colors.green,
                      child: IconButton(
                        onPressed: widget.onSendMessage,
                        icon: const Icon(Icons.send),
                      ),
                    )
                  : IconButton(
                      onPressed: null,
                      icon: const Icon(Icons.send),
                    ),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton();

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        shape: CircleBorder(),
        padding: EdgeInsets.all(6),
        backgroundColor: Color(0xFF22242A),
      ),
      child: Icon(
        Icons.add,
        size: 24,
        color: Colors.white.withValues(alpha: 0.5),
      ),
    );
  }
}

typedef OnSendMessage = void Function(Document document);
