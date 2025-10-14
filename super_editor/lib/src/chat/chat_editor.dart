import 'package:flutter/material.dart';
import 'package:super_editor/src/chat/message_page_scaffold.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/core/styles.dart';
import 'package:super_editor/src/default_editor/document_ime/document_input_ime.dart';
import 'package:super_editor/src/default_editor/layout_single_column/super_editor_dry_layout.dart';
import 'package:super_editor/src/default_editor/paragraph.dart';
import 'package:super_editor/src/default_editor/super_editor.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/keyboard_panel_scaffold.dart';
import 'package:super_keyboard/super_keyboard.dart';

/// An editor for composing chat messages.
///
/// This widget is a composition around a [SuperEditor], which is configured for typical
/// chat use-cases, such as smaller text, and less padding between blocks.
// TODO: This widget probably shouldn't include the keyboard panel scaffold - that's a separate decision.
// TODO: This widget probably shouldn't require a messagePageController - maybe wrap this widget in another widget for that.
//       Maybe:
//         - BottomMountedEditorFrame(
//             messagePageController: //...
//             scrollController: //...
//             child: KeyboardPanelsEditorFrame(
//               softwareKeyboardController: //...
//               child: SuperChatEditor(
//                 scrollController: //...
//                 softwareKeyboardController: //...
//               ),
//             ),
//           );
class SuperChatEditor<PanelType> extends StatefulWidget {
  const SuperChatEditor({
    super.key,
    this.editorFocusNode,
    required this.editor,
    required this.messagePageController,
    this.scrollController,
    this.softwareKeyboardController,
  });

  /// Optional [FocusNode], which is attached to the internal [SuperEditor].
  final FocusNode? editorFocusNode;

  /// The logical [Editor] for the user's message.
  ///
  /// As the user types text and styles it, that message is updated within this [Editor]. To access
  /// the user's message outside of this widget, query [editor.document].
  final Editor editor;

  /// The [MessagePageController] that controls the message page scaffold around this editor and its
  /// bottom sheet.
  ///
  /// [SuperChatEditor] requires a [MessagePageController] to monitor when the message page scaffold goes into
  /// and out of "preview" mode. For example, whenever we're in "preview" mode, the internal [SuperEditor] is
  /// forced to scroll to the top and stay there.
  final MessagePageController messagePageController;

  /// The scroll controller attached to the internal [SuperEditor].
  ///
  /// When provided, this [scrollController] is given to the [SuperEditor], to share
  /// control inside and outside of this widget.
  ///
  /// When not provided, a [ScrollController] is created internally and given to the [SuperEditor].
  final ScrollController? scrollController;

  /// The [SoftwareKeyboardController] used by the [SuperEditor] to interact with the
  /// operating system's IME.
  ///
  /// When provided, this [softwareKeyboardController] is given to the [SuperEditor], to
  /// share control inside and outside of this widget.
  ///
  /// When not provided, a [SoftwareKeyboardController] is created internally and given to the [SuperEditor].
  final SoftwareKeyboardController? softwareKeyboardController;

  @override
  State<SuperChatEditor<PanelType>> createState() => _SuperChatEditorState<PanelType>();
}

class _SuperChatEditorState<PanelType> extends State<SuperChatEditor<PanelType>> {
  final _editorKey = GlobalKey();
  late FocusNode _editorFocusNode;

  late ScrollController _scrollController;
  late KeyboardPanelController<PanelType> _keyboardPanelController;
  final _isImeConnected = ValueNotifier(false);

  @override
  void initState() {
    super.initState();

    _editorFocusNode = widget.editorFocusNode ?? FocusNode();

    _scrollController = widget.scrollController ?? ScrollController();

    _keyboardPanelController = KeyboardPanelController(
      widget.softwareKeyboardController ?? SoftwareKeyboardController(),
    );

    widget.messagePageController.addListener(_onMessagePageControllerChange);

    _isImeConnected.addListener(_onImeConnectionChange);

    SuperKeyboard.instance.mobileGeometry.addListener(_onKeyboardChange);
  }

  @override
  void didUpdateWidget(SuperChatEditor<PanelType> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.editorFocusNode != oldWidget.editorFocusNode) {
      if (oldWidget.editorFocusNode == null) {
        _editorFocusNode.dispose();
      }

      _editorFocusNode = widget.editorFocusNode ?? FocusNode();
    }

    if (widget.scrollController != oldWidget.scrollController) {
      if (oldWidget.scrollController == null) {
        _scrollController.dispose();
      }
      _scrollController = widget.scrollController ?? ScrollController();
    }

    if (widget.messagePageController != oldWidget.messagePageController) {
      oldWidget.messagePageController.removeListener(_onMessagePageControllerChange);
      widget.messagePageController.addListener(_onMessagePageControllerChange);
    }

    if (widget.softwareKeyboardController != oldWidget.softwareKeyboardController) {
      _keyboardPanelController.dispose();
      _keyboardPanelController = KeyboardPanelController(
        widget.softwareKeyboardController ?? SoftwareKeyboardController(),
      );
    }
  }

  @override
  void dispose() {
    SuperKeyboard.instance.mobileGeometry.removeListener(_onKeyboardChange);

    if (widget.scrollController == null) {
      _scrollController.dispose();
    }

    widget.messagePageController.removeListener(_onMessagePageControllerChange);

    _keyboardPanelController.dispose();
    _isImeConnected.dispose();

    if (widget.editorFocusNode == null) {
      _editorFocusNode.dispose();
    }

    super.dispose();
  }

  void _onKeyboardChange() {
    // On Android, we've found that when swiping to go back, the keyboard often
    // closes without Flutter reporting the closure of the IME connection.
    // Therefore, the keyboard closes, but editors and text fields retain focus,
    // selection, and a supposedly open IME connection.
    //
    // Flutter issue: https://github.com/flutter/flutter/issues/165734
    //
    // To hack around this bug in Flutter, when super_keyboard reports keyboard
    // closure, and this controller thinks the keyboard is open, we give up
    // focus so that our app state synchronizes with the closed IME connection.
    final keyboardState = SuperKeyboard.instance.mobileGeometry.value.keyboardState;
    if (_isImeConnected.value && (keyboardState == KeyboardState.closing || keyboardState == KeyboardState.closed)) {
      _editorFocusNode.unfocus();
    }
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
  Widget build(BuildContext context) {
    return KeyboardPanelScaffold(
      controller: _keyboardPanelController,
      isImeConnected: _isImeConnected,
      toolbarBuilder: (BuildContext context, PanelType? openPanel) {
        return const SizedBox();
      },
      keyboardPanelBuilder: (BuildContext context, PanelType? openPanel) {
        return const SizedBox();
      },
      contentBuilder: (BuildContext context, PanelType? openPanel) {
        return SuperEditorFocusOnTap(
          editorFocusNode: _editorFocusNode,
          editor: widget.editor,
          child: SuperEditorDryLayout(
            controller: widget.scrollController,
            superEditor: SuperEditor(
              key: _editorKey,
              focusNode: _editorFocusNode,
              editor: widget.editor,
              softwareKeyboardController: widget.softwareKeyboardController,
              isImeConnected: _isImeConnected,
              imePolicies: const SuperEditorImePolicies(),
              selectionPolicies: const SuperEditorSelectionPolicies(),
              shrinkWrap: false,
              stylesheet: _chatStylesheet,
              componentBuilders: const [
                HintComponentBuilder("Send a message...", _hintTextStyleBuilder),
                ...defaultComponentBuilders,
              ],
            ),
          ),
        );
      },
    );
  }
}

final _chatStylesheet = Stylesheet(
  rules: [
    StyleRule(
      BlockSelector.all,
      (doc, docNode) {
        return {
          Styles.padding: const CascadingPadding.symmetric(horizontal: 12),
          Styles.textStyle: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            height: 1.4,
          ),
        };
      },
    ),
    StyleRule(
      const BlockSelector("header1"),
      (doc, docNode) {
        return {
          Styles.textStyle: const TextStyle(
            color: Color(0xFF333333),
            fontSize: 38,
            fontWeight: FontWeight.bold,
          ),
        };
      },
    ),
    StyleRule(
      const BlockSelector("header2"),
      (doc, docNode) {
        return {
          Styles.textStyle: const TextStyle(
            color: Color(0xFF333333),
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        };
      },
    ),
    StyleRule(
      const BlockSelector("header3"),
      (doc, docNode) {
        return {
          Styles.textStyle: const TextStyle(
            color: Color(0xFF333333),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        };
      },
    ),
    StyleRule(
      const BlockSelector("paragraph"),
      (doc, docNode) {
        return {
          Styles.padding: const CascadingPadding.only(bottom: 12),
        };
      },
    ),
    StyleRule(
      const BlockSelector("blockquote"),
      (doc, docNode) {
        return {
          Styles.textStyle: const TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
            height: 1.4,
          ),
        };
      },
    ),
  ],
  inlineTextStyler: defaultInlineTextStyler,
  inlineWidgetBuilders: defaultInlineWidgetBuilderChain,
);

TextStyle _hintTextStyleBuilder(context) => const TextStyle(
      color: Colors.grey,
    );

// FIXME: This widget is required because of the current shrink wrap behavior
//        of Super Editor. If we set `shrinkWrap` to `false` then the bottom
//        sheet always expands to max height. But if we set `shrinkWrap` to
//        `true`, when we manually expand the bottom sheet, the only
//        tappable area is wherever the document components actually appear.
//        In the average case, that means only the top area of the bottom
//        sheet can be tapped to place the caret.
//
//        This widget should wrap Super Editor and make the whole area tappable.
/// A widget, that when pressed, gives focus to the [editorFocusNode], and places
/// the caret at the end of the content within an [editor].
///
/// It's expected that the [child] subtree contains the associated `SuperEditor`,
/// which owns the [editor] and [editorFocusNode].
class SuperEditorFocusOnTap extends StatelessWidget {
  const SuperEditorFocusOnTap({
    super.key,
    required this.editorFocusNode,
    required this.editor,
    required this.child,
  });

  final FocusNode editorFocusNode;

  final Editor editor;

  /// The SuperEditor that we're wrapping with this tap behavior.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: editorFocusNode,
      builder: (context, child) {
        return ListenableBuilder(
          listenable: editor.composer.selectionNotifier,
          builder: (context, child) {
            final shouldControlTap = editor.composer.selection == null || !editorFocusNode.hasFocus;
            return GestureDetector(
              onTap: editor.composer.selection == null || !editorFocusNode.hasFocus ? _selectEditor : null,
              behavior: HitTestBehavior.opaque,
              child: IgnorePointer(
                ignoring: shouldControlTap,
                // ^ Prevent the Super Editor from aggressively responding to
                //   taps, so that we can respond.
                child: child,
              ),
            );
          },
          child: child,
        );
      },
      child: child,
    );
  }

  void _selectEditor() {
    editorFocusNode.requestFocus();

    final endNode = editor.document.last;
    editor.execute([
      ChangeSelectionRequest(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: endNode.id,
            nodePosition: endNode.endPosition,
          ),
        ),
        SelectionChangeType.placeCaret,
        SelectionReason.userInteraction,
      ),
    ]);
  }
}

/// The available options to choose from when using the built-in editing toolbar in
/// a floating editor page or a mounted editor page.
enum SimpleSuperChatToolbarOptions {
  // Text.
  bold,
  italics,
  underline,
  strikethrough,
  code,
  textColor,
  backgroundColor,
  indent,
  clearStyles,

  // Blocks.
  orderedListItem,
  unorderedListItem,
  blockquote,
  codeBlock,

  // Media.
  attach,

  // Control.
  dictation,
  closeKeyboard,
  send;
}
