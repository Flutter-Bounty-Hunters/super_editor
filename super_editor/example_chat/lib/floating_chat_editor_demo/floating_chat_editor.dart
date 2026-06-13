// import 'package:example_chat/floating_chat_editor_demo/floating_editor_toolbar.dart';
// import 'package:flutter/material.dart';
// import 'package:super_editor/super_editor.dart';
// import 'package:super_keyboard/super_keyboard.dart';
//
// class FloatingEditorSheetContent extends StatefulWidget {
//   const FloatingEditorSheetContent({super.key,
//     required this.messagePageController,
//   });
//
//   final MessagePageController messagePageController;
//
//   @override
//   State<FloatingEditorSheetContent> createState() => _FloatingEditorSheetContentState();
// }
//
// class _FloatingEditorSheetContentState extends State<FloatingEditorSheetContent> {
//   final _dragIndicatorKey = GlobalKey();
//
//   final _scrollController = ScrollController();
//
//   final _editorFocusNode = FocusNode();
//   late GlobalKey _sheetKey;
//   late final Editor _editor;
//   late final SoftwareKeyboardController _softwareKeyboardController;
//
//   final _hasSelection = ValueNotifier(false);
//
//   @override
//   void initState() {
//     super.initState();
//
//     _softwareKeyboardController = SoftwareKeyboardController();
//
//     _sheetKey = widget.sheetKey ?? GlobalKey();
//
//     _editor = createDefaultDocumentEditor(
//       document: MutableDocument.empty(),
//       composer: MutableDocumentComposer(),
//     );
//     _editor.composer.selectionNotifier.addListener(_onSelectionChange);
//   }
//
//   @override
//   void didUpdateWidget(FloatingEditorSheetContent oldWidget) {
//     super.didUpdateWidget(oldWidget);
//
//     if (widget.sheetKey != _sheetKey) {
//       _sheetKey = widget.sheetKey ?? GlobalKey();
//     }
//   }
//
//   @override
//   void dispose() {
//     _editor.composer.selectionNotifier.removeListener(_onSelectionChange);
//     _editor.dispose();
//
//     _editorFocusNode.dispose();
//
//     _scrollController.dispose();
//
//     super.dispose();
//   }
//
//   void _onSelectionChange() {
//     _hasSelection.value = _editor.composer.selection != null;
//
//     // If the editor doesn't have a selection then when it's collapsed it
//     // should be in preview mode. If the editor does have a selection, then
//     // when it's collapsed, it should be in intrinsic height mode.
//     widget.messagePageController.collapsedMode =
//     _hasSelection.value ? MessagePageSheetCollapsedMode.intrinsic : MessagePageSheetCollapsedMode.preview;
//   }
//
//   double _dragTouchOffsetFromIndicator = 0;
//
//   void _onVerticalDragStart(DragStartDetails details) {
//     _dragTouchOffsetFromIndicator = _dragFingerOffsetFromIndicator(details.globalPosition);
//
//     widget.messagePageController.onDragStart(
//       details.globalPosition.dy - _dragIndicatorOffsetFromTop - _dragTouchOffsetFromIndicator,
//     );
//   }
//
//   void _onVerticalDragUpdate(DragUpdateDetails details) {
//     widget.messagePageController.onDragUpdate(
//       details.globalPosition.dy - _dragIndicatorOffsetFromTop - _dragTouchOffsetFromIndicator,
//     );
//   }
//
//   void _onVerticalDragEnd(DragEndDetails details) {
//     widget.messagePageController.onDragEnd();
//   }
//
//   void _onVerticalDragCancel() {
//     widget.messagePageController.onDragEnd();
//   }
//
//   double get _dragIndicatorOffsetFromTop {
//     final bottomSheetBox = _sheetKey.currentContext!.findRenderObject();
//     final dragIndicatorBox = _dragIndicatorKey.currentContext!.findRenderObject()! as RenderBox;
//
//     return dragIndicatorBox.localToGlobal(Offset.zero, ancestor: bottomSheetBox).dy;
//   }
//
//   double _dragFingerOffsetFromIndicator(Offset globalDragOffset) {
//     final dragIndicatorBox = _dragIndicatorKey.currentContext!.findRenderObject()! as RenderBox;
//
//     return globalDragOffset.dy - dragIndicatorBox.localToGlobal(Offset.zero).dy;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       crossAxisAlignment: CrossAxisAlignment.stretch,
//       children: [
//         _buildDragHandle(),
//         Flexible(
//           child: Row(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               ListenableBuilder(
//                 listenable: _editorFocusNode,
//                 builder: (context, child) {
//                   if (_editorFocusNode.hasFocus) {
//                     return const SizedBox();
//                   }
//
//                   return Padding(
//                     padding: const EdgeInsets.only(left: 12, bottom: 12),
//                     child: AttachmentButton(),
//                   );
//                 },
//               ),
//               Expanded(
//                 child: Padding(
//                   padding: const EdgeInsets.only(top: 4),
//                   child: _buildSheetContent(),
//                 ),
//               ),
//               ListenableBuilder(
//                 listenable: _editorFocusNode,
//                 builder: (context, child) {
//                   if (_editorFocusNode.hasFocus) {
//                     return const SizedBox();
//                   }
//
//                   return Padding(
//                     padding: const EdgeInsets.only(right: 12, bottom: 12),
//                     child: DictationButton(),
//                   );
//                 },
//               ),
//             ],
//           ),
//         ),
//         ListenableBuilder(
//           listenable: _editorFocusNode,
//           builder: (context, child) {
//             if (!_editorFocusNode.hasFocus) {
//               return const SizedBox();
//             }
//
//             return _buildToolbar();
//           },
//         )
//       ],
//     );
//   }
//
//   Widget _buildSheetContent() {
//     return BottomSheetEditorHeight(
//       previewHeight: 32,
//       child: _ChatEditor(
//         key: _editorKey,
//         editorFocusNode: _editorFocusNode,
//         editor: _editor,
//         messagePageController: widget.messagePageController,
//         scrollController: _scrollController,
//         softwareKeyboardController: _softwareKeyboardController,
//       ),
//     );
//   }
//
//   // FIXME: Keyboard keeps closing without a bunch of global keys. Either
//   final _editorKey = GlobalKey();
//
//   Widget _buildDragHandle() {
//     return ListenableBuilder(
//       listenable: _editorFocusNode,
//       builder: (context, child) {
//         if (!_editorFocusNode.hasFocus) {
//           return const SizedBox(height: 12);
//         }
//
//         return Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             GestureDetector(
//               onVerticalDragStart: _onVerticalDragStart,
//               onVerticalDragUpdate: _onVerticalDragUpdate,
//               onVerticalDragEnd: _onVerticalDragEnd,
//               onVerticalDragCancel: _onVerticalDragCancel,
//               behavior: HitTestBehavior.opaque,
//               // ^ Opaque to handle tough events in our invisible padding.
//               child: Padding(
//                 padding: const EdgeInsets.all(8),
//                 // ^ Expand the hit area with invisible padding.
//                 child: Container(
//                   key: _dragIndicatorKey,
//                   width: 48,
//                   height: 5,
//                   decoration: BoxDecoration(
//                     color: Colors.grey.shade300,
//                     borderRadius: BorderRadius.circular(3),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         );
//       },
//     );
//   }
//
//   Widget _buildToolbar() {
//     return Padding(
//       padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
//       child: FloatingEditorToolbar(
//         softwareKeyboardController: _softwareKeyboardController,
//       ),
//     );
//   }
// }
//
// /// An editor for composing chat messages.
// class _ChatEditor extends StatefulWidget {
//   const _ChatEditor({
//     super.key,
//     this.editorFocusNode,
//     required this.editor,
//     required this.messagePageController,
//     required this.scrollController,
//     required this.softwareKeyboardController,
//   });
//
//   final FocusNode? editorFocusNode;
//
//   final Editor editor;
//   final MessagePageController messagePageController;
//   final ScrollController scrollController;
//   final SoftwareKeyboardController softwareKeyboardController;
//
//   @override
//   State<_ChatEditor> createState() => _ChatEditorState();
// }
//
// class _ChatEditorState extends State<_ChatEditor> {
//   final _editorKey = GlobalKey();
//   late FocusNode _editorFocusNode;
//
//   late KeyboardPanelController<_Panel> _keyboardPanelController;
//   final _isImeConnected = ValueNotifier(false);
//
//   @override
//   void initState() {
//     super.initState();
//
//     _editorFocusNode = widget.editorFocusNode ?? FocusNode();
//
//     _keyboardPanelController = KeyboardPanelController(
//       widget.softwareKeyboardController,
//     );
//
//     widget.messagePageController.addListener(_onMessagePageControllerChange);
//
//     _isImeConnected.addListener(_onImeConnectionChange);
//
//     SuperKeyboard.instance.mobileGeometry.addListener(_onKeyboardChange);
//   }
//
//   @override
//   void didUpdateWidget(_ChatEditor oldWidget) {
//     super.didUpdateWidget(oldWidget);
//
//     if (widget.editorFocusNode != oldWidget.editorFocusNode) {
//       if (oldWidget.editorFocusNode == null) {
//         _editorFocusNode.dispose();
//       }
//
//       _editorFocusNode = widget.editorFocusNode ?? FocusNode();
//     }
//
//     if (widget.messagePageController != oldWidget.messagePageController) {
//       oldWidget.messagePageController.removeListener(_onMessagePageControllerChange);
//       widget.messagePageController.addListener(_onMessagePageControllerChange);
//     }
//
//     if (widget.softwareKeyboardController != oldWidget.softwareKeyboardController) {
//       _keyboardPanelController.dispose();
//       _keyboardPanelController = KeyboardPanelController(widget.softwareKeyboardController);
//     }
//   }
//
//   @override
//   void dispose() {
//     SuperKeyboard.instance.mobileGeometry.removeListener(_onKeyboardChange);
//
//     widget.messagePageController.removeListener(_onMessagePageControllerChange);
//
//     _keyboardPanelController.dispose();
//     _isImeConnected.dispose();
//
//     if (widget.editorFocusNode == null) {
//       _editorFocusNode.dispose();
//     }
//
//     super.dispose();
//   }
//
//   void _onKeyboardChange() {
//     // On Android, we've found that when swiping to go back, the keyboard often
//     // closes without Flutter reporting the closure of the IME connection.
//     // Therefore, the keyboard closes, but editors and text fields retain focus,
//     // selection, and a supposedly open IME connection.
//     //
//     // Flutter issue: https://github.com/flutter/flutter/issues/165734
//     //
//     // To hack around this bug in Flutter, when super_keyboard reports keyboard
//     // closure, and this controller thinks the keyboard is open, we give up
//     // focus so that our app state synchronizes with the closed IME connection.
//     final keyboardState = SuperKeyboard.instance.mobileGeometry.value.keyboardState;
//     if (_isImeConnected.value && (keyboardState == KeyboardState.closing || keyboardState == KeyboardState.closed)) {
//       _editorFocusNode.unfocus();
//     }
//   }
//
//   void _onImeConnectionChange() {
//     widget.messagePageController.collapsedMode =
//     _isImeConnected.value ? MessagePageSheetCollapsedMode.intrinsic : MessagePageSheetCollapsedMode.preview;
//   }
//
//   void _onMessagePageControllerChange() {
//     if (widget.messagePageController.isPreview) {
//       // Always scroll the editor to the top when in preview mode.
//       widget.scrollController.position.jumpTo(0);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return KeyboardPanelScaffold(
//       controller: _keyboardPanelController,
//       isImeConnected: _isImeConnected,
//       toolbarBuilder: (BuildContext context, _Panel? openPanel) {
//         return SizedBox();
//       },
//       keyboardPanelBuilder: (BuildContext context, _Panel? openPanel) {
//         return SizedBox();
//       },
//       contentBuilder: (BuildContext context, _Panel? openPanel) {
//         return SuperEditorFocusOnTap(
//           editorFocusNode: _editorFocusNode,
//           editor: widget.editor,
//           child: SuperEditorDryLayout(
//             controller: widget.scrollController,
//             superEditor: SuperEditor(
//               key: _editorKey,
//               focusNode: _editorFocusNode,
//               editor: widget.editor,
//               softwareKeyboardController: widget.softwareKeyboardController,
//               isImeConnected: _isImeConnected,
//               imePolicies: SuperEditorImePolicies(),
//               selectionPolicies: SuperEditorSelectionPolicies(),
//               shrinkWrap: false,
//               stylesheet: _chatStylesheet,
//               componentBuilders: [
//                 const HintComponentBuilder("Send a message...", _hintTextStyleBuilder),
//                 ...defaultComponentBuilders,
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
// }
//
// final _chatStylesheet = Stylesheet(
//   rules: [
//     StyleRule(
//       BlockSelector.all,
//           (doc, docNode) {
//         return {
//           Styles.padding: const CascadingPadding.symmetric(horizontal: 12),
//           Styles.textStyle: const TextStyle(
//             color: Colors.black,
//             fontSize: 16,
//             height: 1.4,
//           ),
//         };
//       },
//     ),
//     StyleRule(
//       const BlockSelector("header1"),
//           (doc, docNode) {
//         return {
//           Styles.textStyle: const TextStyle(
//             color: Color(0xFF333333),
//             fontSize: 38,
//             fontWeight: FontWeight.bold,
//           ),
//         };
//       },
//     ),
//     StyleRule(
//       const BlockSelector("header2"),
//           (doc, docNode) {
//         return {
//           Styles.textStyle: const TextStyle(
//             color: Color(0xFF333333),
//             fontSize: 26,
//             fontWeight: FontWeight.bold,
//           ),
//         };
//       },
//     ),
//     StyleRule(
//       const BlockSelector("header3"),
//           (doc, docNode) {
//         return {
//           Styles.textStyle: const TextStyle(
//             color: Color(0xFF333333),
//             fontSize: 22,
//             fontWeight: FontWeight.bold,
//           ),
//         };
//       },
//     ),
//     StyleRule(
//       const BlockSelector("paragraph"),
//           (doc, docNode) {
//         return {
//           Styles.padding: const CascadingPadding.only(bottom: 12),
//         };
//       },
//     ),
//     StyleRule(
//       const BlockSelector("blockquote"),
//           (doc, docNode) {
//         return {
//           Styles.textStyle: const TextStyle(
//             color: Colors.grey,
//             fontWeight: FontWeight.bold,
//             height: 1.4,
//           ),
//         };
//       },
//     ),
//   ],
//   inlineTextStyler: defaultInlineTextStyler,
//   inlineWidgetBuilders: defaultInlineWidgetBuilderChain,
// );
//
// TextStyle _hintTextStyleBuilder(context) => TextStyle(
//   color: Colors.grey,
// );
//
// // FIXME: This widget is required because of the current shrink wrap behavior
// //        of Super Editor. If we set `shrinkWrap` to `false` then the bottom
// //        sheet always expands to max height. But if we set `shrinkWrap` to
// //        `true`, when we manually expand the bottom sheet, the only
// //        tappable area is wherever the document components actually appear.
// //        In the average case, that means only the top area of the bottom
// //        sheet can be tapped to place the caret.
// //
// //        This widget should wrap Super Editor and make the whole area tappable.
// /// A widget, that when pressed, gives focus to the [editorFocusNode], and places
// /// the caret at the end of the content within an [editor].
// ///
// /// It's expected that the [child] subtree contains the associated `SuperEditor`,
// /// which owns the [editor] and [editorFocusNode].
// class SuperEditorFocusOnTap extends StatelessWidget {
//   const SuperEditorFocusOnTap({
//     super.key,
//     required this.editorFocusNode,
//     required this.editor,
//     required this.child,
//   });
//
//   final FocusNode editorFocusNode;
//
//   final Editor editor;
//
//   /// The SuperEditor that we're wrapping with this tap behavior.
//   final Widget child;
//
//   @override
//   Widget build(BuildContext context) {
//     return ListenableBuilder(
//       listenable: editorFocusNode,
//       builder: (context, child) {
//         return ListenableBuilder(
//           listenable: editor.composer.selectionNotifier,
//           builder: (context, child) {
//             final shouldControlTap = editor.composer.selection == null || !editorFocusNode.hasFocus;
//             return GestureDetector(
//               onTap: editor.composer.selection == null || !editorFocusNode.hasFocus ? _selectEditor : null,
//               behavior: HitTestBehavior.opaque,
//               child: IgnorePointer(
//                 ignoring: shouldControlTap,
//                 // ^ Prevent the Super Editor from aggressively responding to
//                 //   taps, so that we can respond.
//                 child: child,
//               ),
//             );
//           },
//           child: child,
//         );
//       },
//       child: child,
//     );
//   }
//
//   void _selectEditor() {
//     editorFocusNode.requestFocus();
//
//     final endNode = editor.document.last;
//     editor.execute([
//       ChangeSelectionRequest(
//         DocumentSelection.collapsed(
//           position: DocumentPosition(
//             nodeId: endNode.id,
//             nodePosition: endNode.endPosition,
//           ),
//         ),
//         SelectionChangeType.placeCaret,
//         SelectionReason.userInteraction,
//       ),
//     ]);
//   }
// }
//
// enum _Panel {
//   thePanel;
// }
