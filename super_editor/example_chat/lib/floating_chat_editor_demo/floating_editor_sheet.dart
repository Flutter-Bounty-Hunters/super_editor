import 'dart:ui';

import 'package:example_chat/floating_chat_editor_demo/floating_editor_toolbar.dart';
import 'package:example_chat/floating_chat_editor_demo/press_to_inflate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_keyboard/super_keyboard.dart';

/// The whole bottom sheet for the floating editor demo, which includes a [ShadowSheet] with
/// a banner, which then contains an [EditorBottomSheet], which has a drag handle, an
/// editor, and a toolbar.
class FloatingEditorBottomSheet extends StatefulWidget {
  const FloatingEditorBottomSheet({
    super.key,
    required this.messagePageController,
  });

  final MessagePageController messagePageController;

  @override
  State<FloatingEditorBottomSheet> createState() => _FloatingEditorBottomSheetState();
}

class _FloatingEditorBottomSheetState extends State<FloatingEditorBottomSheet> {
  final _sheetKey = GlobalKey(debugLabel: 'floating-editor-sheet-boundary');

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _sheetKey,
      child: PressToInflate(
        child: ShadowSheet(
          banner: _buildBanner(),
          editorSheet: EditorBottomSheet(
            sheetKey: _sheetKey,
            messagePageController: widget.messagePageController,
          ),
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 8),
      child: Text.rich(
        TextSpan(
          children: [
            WidgetSpan(
              child: Padding(
                padding: const EdgeInsets.only(right: 4, bottom: 1),
                child: Icon(Icons.supervised_user_circle_rounded, size: 13),
              ),
            ),
            TextSpan(
              text: "Ella Martinez",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: " is from Acme"),
          ],
          style: TextStyle(
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

/// A superellipse sheet which has a [banner] at the top and an [editorSheet] below that.
///
/// This widget paints a superellipse background around the [banner] and the [editorSheet], but
/// it then cuts out another superellipse around the [editorSheet]. The final effect is as if the
/// [banner] is popping up from behind the [editorSheet], but in such a way that the [editorSheet]
/// can be translucent, showing what's behind it.
class ShadowSheet extends SlottedMultiChildRenderObjectWidget<ShadowSheetSlot, RenderBox> {
  const ShadowSheet({
    super.key,
    this.banner,
    required this.editorSheet,
  });

  final Widget? banner;
  final Widget editorSheet;

  @override
  Iterable<ShadowSheetSlot> get slots => ShadowSheetSlot.values;

  @override
  Widget? childForSlot(ShadowSheetSlot slot) {
    switch (slot) {
      case ShadowSheetSlot.banner:
        return banner;
      case ShadowSheetSlot.editorSheet:
        return editorSheet;
    }
  }

  @override
  SlottedContainerRenderObjectMixin<ShadowSheetSlot, RenderBox> createRenderObject(BuildContext context) {
    return RenderShadowSheet();
  }
}

enum ShadowSheetSlot {
  banner,
  editorSheet;
}

class RenderShadowSheet extends RenderBox with SlottedContainerRenderObjectMixin<ShadowSheetSlot, RenderBox> {
  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final editorSheet = childForSlot(ShadowSheetSlot.editorSheet)!;
    final editorSheetSize = editorSheet.computeDryLayout(constraints);

    final banner = childForSlot(ShadowSheetSlot.banner);
    final bannerSize = banner?.computeDryLayout(
          // We force the banner to be the same width as the editor sheet.
          constraints.copyWith(minWidth: editorSheetSize.width, maxWidth: editorSheetSize.width),
        ) ??
        Size.zero;

    return Size(editorSheetSize.width, bannerSize.height + editorSheetSize.height);
  }

  @override
  bool hitTestSelf(Offset position) => false;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final slot in ShadowSheetSlot.values) {
      final child = childForSlot(slot);
      if (child == null) {
        continue;
      }

      final childParentData = child.parentData as BoxParentData;
      final isHit = result.addWithPaintOffset(
        offset: childParentData.offset,
        position: position,
        hitTest: (BoxHitTestResult result, Offset transformed) {
          return child.hitTest(result, position: transformed);
        },
      );

      if (isHit) {
        return true; // stop if a child was hit
      }
    }

    return false;
  }

  @override
  void performLayout() {
    final editorSheet = childForSlot(ShadowSheetSlot.editorSheet)!;
    editorSheet.layout(constraints, parentUsesSize: true);
    var editorSheetSize = editorSheet.size;

    final banner = childForSlot(ShadowSheetSlot.banner);
    banner?.layout(
      // We force the banner to be the same width as the editor sheet.
      constraints.copyWith(minWidth: editorSheetSize.width, maxWidth: editorSheetSize.width),
      parentUsesSize: true,
    );
    final bannerSize = banner?.size ?? Size.zero;

    // If the banner + editor ended up being taller than allowed, re-layout the
    // editor, forcing it to be shorter.
    if (bannerSize.height + editorSheetSize.height > constraints.maxHeight) {
      editorSheet.layout(
        constraints.copyWith(maxHeight: constraints.maxHeight - bannerSize.height),
        parentUsesSize: true,
      );
      editorSheetSize = editorSheet.size;
    }

    // Show the banner at the top, with the editor sheet below it.
    banner?.parentData = BoxParentData()..offset = Offset.zero;
    editorSheet.parentData = BoxParentData()..offset = Offset(0, bannerSize.height);

    // The editor sheet determines our width - we don't want to expand the editor
    // sheet to fit a wide banner width.
    size = Size(editorSheetSize.width, bannerSize.height + editorSheetSize.height);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final banner = childForSlot(ShadowSheetSlot.banner);
    final editorSheet = childForSlot(ShadowSheetSlot.editorSheet)!;

    final bannerAndEditorBoundary = RSuperellipse.fromLTRBR(
      offset.dx,
      offset.dy,
      offset.dx + size.width,
      offset.dy + size.height,
      Radius.circular(28),
    );
    final bannerAndEditorSheetBoundaryPath = Path()
      ..addRSuperellipse(
        RSuperellipse.fromLTRBR(
          offset.dx,
          offset.dy,
          offset.dx + size.width,
          offset.dy + size.height,
          Radius.circular(28),
        ),
      );

    // Paint the shadow for the entire shadow sheet.
    // context.canvas.drawShadow(
    //   bannerAndEditorSheetBoundaryPath,
    //   Colors.black,
    //   12,
    //   true, // our content is translucent.
    // );

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12);

    // draw blurred path offset from original position
    context.canvas.saveLayer(null, Paint());

    context.canvas
      ..save()
      ..translate(0, 0)
      ..drawPath(bannerAndEditorSheetBoundaryPath, shadowPaint)
      ..restore();

    final clearPaint = Paint()..blendMode = BlendMode.dstOut; // removes painted pixels from layer
    context.canvas.drawPath(bannerAndEditorSheetBoundaryPath, clearPaint);

    // Merge the shadow layer back into the main canvas
    context.canvas.restore();

    // Paint the banner background and banner.
    if (banner != null) {
      final editorSheetBoundary = Path()
        ..addRSuperellipse(
          RSuperellipse.fromLTRBR(
            offset.dx,
            offset.dy + banner.size.height,
            offset.dx + size.width,
            offset.dy + banner.size.height + editorSheet.size.height,
            Radius.circular(28),
          ),
        );

      final bannerBackground = Path.combine(PathOperation.xor, bannerAndEditorSheetBoundaryPath, editorSheetBoundary);

      context.canvas.drawPath(bannerBackground, Paint()..color = const Color(0xFFFFF7C2));

      // Clip the banner at the shadow sheet boundary.
      context.canvas
        ..save()
        ..clipRSuperellipse(bannerAndEditorBoundary);

      banner.paint(context, offset);

      // Get rid of the banner clip.
      context.canvas.restore();
    }

    editorSheet.paint(context, offset + (editorSheet.parentData as BoxParentData).offset);
  }
}

/// A super ellipse sheet, which contains a drag handle, editor, and toolbar.
class EditorBottomSheet extends StatefulWidget {
  const EditorBottomSheet({
    super.key,
    this.sheetKey,
    required this.messagePageController,
  });

  /// A [GlobalKey] that's attached to the outermost boundary of the sheet that
  /// contains this [EditorBottomSheet].
  ///
  /// In the typical case, [EditorBottomSheet] is the outermost boundary, in which case
  /// no key needs to be provided. This widget will create a key internally.
  ///
  /// However, if additional content is added above or below this [EditorBottomSheet] then
  /// we need to be able to account for the global offset of that content. To make layout
  /// decisions based on the entire sheet, clients must wrap the whole sheet with a [GlobalKey]
  /// and provide that key as [sheetKey].
  final GlobalKey? sheetKey;

  final MessagePageController messagePageController;

  @override
  State<EditorBottomSheet> createState() => _EditorBottomSheetState();
}

class _EditorBottomSheetState extends State<EditorBottomSheet> {
  final _dragIndicatorKey = GlobalKey();

  final _scrollController = ScrollController();

  final _editorFocusNode = FocusNode();
  late GlobalKey _editorSheetKey;
  late final Editor _editor;
  late final SoftwareKeyboardController _softwareKeyboardController;

  final _hasSelection = ValueNotifier(false);

  bool _isUserPressingDown = false;

  @override
  void initState() {
    super.initState();

    _softwareKeyboardController = SoftwareKeyboardController();

    _editorSheetKey = widget.sheetKey ?? GlobalKey();

    _editor = createDefaultDocumentEditor(
      document: MutableDocument.empty(),
      composer: MutableDocumentComposer(),
    );
    _editor.composer.selectionNotifier.addListener(_onSelectionChange);
  }

  @override
  void didUpdateWidget(EditorBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.sheetKey != _editorSheetKey) {
      _editorSheetKey = widget.sheetKey ?? GlobalKey();
    }
  }

  @override
  void dispose() {
    _editor.composer.selectionNotifier.removeListener(_onSelectionChange);
    _editor.dispose();

    _editorFocusNode.dispose();

    _scrollController.dispose();

    super.dispose();
  }

  void _onSelectionChange() {
    _hasSelection.value = _editor.composer.selection != null;

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
    return KeyedSubtree(
      // If we're provided with a [widget.sheetKey] it means the full sheet boundary
      // expands beyond just us, and that key is attached to that outer boundary.
      // If we're not provided with a [widget.sheetKey], it's because we are the outer
      // boundary, so we need to key our subtree for layout calculations.
      key: widget.sheetKey == null ? _editorSheetKey : null,
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
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4, tileMode: TileMode.decal),
            child: Container(
              decoration: ShapeDecoration(
                color: Colors.white.withValues(alpha: _isUserPressingDown ? 1.0 : 0.8),
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: KeyboardScaffoldSafeArea(
                child: Column(
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

                              return Padding(
                                padding: const EdgeInsets.only(left: 12, bottom: 12),
                                child: AttachmentButton(),
                              );
                            },
                          ),
                          Spacer(),
                          // Expanded(
                          //   child: Padding(
                          //     padding: const EdgeInsets.only(top: 4),
                          //     child: _buildSheetContent(),
                          //   ),
                          // ),
                          ListenableBuilder(
                            listenable: _editorFocusNode,
                            builder: (context, child) {
                              if (_editorFocusNode.hasFocus) {
                                return const SizedBox();
                              }

                              return Padding(
                                padding: const EdgeInsets.only(right: 12, bottom: 12),
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
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSheetContent() {
    return BottomSheetEditorHeight(
      previewHeight: 32,
      child: _ChatEditor(
        key: _editorKey,
        editorFocusNode: _editorFocusNode,
        editor: _editor,
        messagePageController: widget.messagePageController,
        scrollController: _scrollController,
        softwareKeyboardController: _softwareKeyboardController,
      ),
    );
  }

  // FIXME: Keyboard keeps closing without a bunch of global keys. Either
  //        document why, or figure out how to operate without all the keys.
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
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
      child: FloatingEditorToolbar(
        softwareKeyboardController: _softwareKeyboardController,
      ),
    );
  }
}

/// An editor for composing chat messages.
class _ChatEditor extends StatefulWidget {
  const _ChatEditor({
    super.key,
    this.editorFocusNode,
    required this.editor,
    required this.messagePageController,
    required this.scrollController,
    required this.softwareKeyboardController,
  });

  final FocusNode? editorFocusNode;

  final Editor editor;
  final MessagePageController messagePageController;
  final ScrollController scrollController;
  final SoftwareKeyboardController softwareKeyboardController;

  @override
  State<_ChatEditor> createState() => _ChatEditorState();
}

class _ChatEditorState extends State<_ChatEditor> {
  final _editorKey = GlobalKey();
  late FocusNode _editorFocusNode;

  late KeyboardPanelController<_Panel> _keyboardPanelController;
  final _isImeConnected = ValueNotifier(false);

  @override
  void initState() {
    super.initState();

    _editorFocusNode = widget.editorFocusNode ?? FocusNode();

    _keyboardPanelController = KeyboardPanelController(
      widget.softwareKeyboardController,
    );

    widget.messagePageController.addListener(_onMessagePageControllerChange);

    _isImeConnected.addListener(_onImeConnectionChange);

    SuperKeyboard.instance.mobileGeometry.addListener(_onKeyboardChange);
  }

  @override
  void didUpdateWidget(_ChatEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.editorFocusNode != oldWidget.editorFocusNode) {
      if (oldWidget.editorFocusNode == null) {
        _editorFocusNode.dispose();
      }

      _editorFocusNode = widget.editorFocusNode ?? FocusNode();
    }

    if (widget.messagePageController != oldWidget.messagePageController) {
      oldWidget.messagePageController.removeListener(_onMessagePageControllerChange);
      widget.messagePageController.addListener(_onMessagePageControllerChange);
    }

    if (widget.softwareKeyboardController != oldWidget.softwareKeyboardController) {
      _keyboardPanelController.dispose();
      _keyboardPanelController = KeyboardPanelController(widget.softwareKeyboardController);
    }
  }

  @override
  void dispose() {
    SuperKeyboard.instance.mobileGeometry.removeListener(_onKeyboardChange);

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
      widget.scrollController.position.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardPanelScaffold(
      controller: _keyboardPanelController,
      isImeConnected: _isImeConnected,
      toolbarBuilder: (BuildContext context, _Panel? openPanel) {
        return SizedBox();
      },
      keyboardPanelBuilder: (BuildContext context, _Panel? openPanel) {
        return SizedBox();
      },
      contentBuilder: (BuildContext context, _Panel? openPanel) {
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
              imePolicies: SuperEditorImePolicies(),
              selectionPolicies: SuperEditorSelectionPolicies(),
              shrinkWrap: false,
              stylesheet: _chatStylesheet,
              componentBuilders: [
                const HintComponentBuilder("Send a message...", _hintTextStyleBuilder),
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

TextStyle _hintTextStyleBuilder(context) => TextStyle(
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

enum _Panel {
  thePanel;
}
