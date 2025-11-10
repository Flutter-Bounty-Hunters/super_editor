import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide SelectableText;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/default_editor/text_tools.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/actions.dart';
import 'package:super_editor/src/infrastructure/attributed_text_styles.dart';
import 'package:super_editor/src/infrastructure/document_gestures_interaction_overrides.dart';
import 'package:super_editor/src/infrastructure/flutter/build_context.dart';
import 'package:super_editor/src/infrastructure/flutter/flutter_scheduler.dart';
import 'package:super_editor/src/infrastructure/flutter/material_scrollbar.dart';
import 'package:super_editor/src/infrastructure/flutter/text_input_configuration.dart';
import 'package:super_editor/src/infrastructure/ime_input_owner.dart';
import 'package:super_editor/src/infrastructure/keyboard.dart';
import 'package:super_editor/src/infrastructure/multi_listenable_builder.dart';
import 'package:super_editor/src/infrastructure/multi_tap_gesture.dart';
import 'package:super_editor/src/infrastructure/platforms/mac/mac_ime.dart';
import 'package:super_editor/src/infrastructure/platforms/platform.dart';
import 'package:super_editor/src/infrastructure/text_input.dart';
import 'package:super_editor/src/super_textfield/infrastructure/text_field_scroller.dart';
import 'package:super_editor/src/super_textfield/super_textfield.dart';
import 'package:super_text_layout/super_text_layout.dart';

import '../infrastructure/fill_width_if_constrained.dart';

final _log = textFieldLog;

/// Highly configurable text field intended for web and desktop uses.
///
/// [SuperDesktopTextField] provides two advantages over a typical [TextField].
/// First, [SuperDesktopTextField] is based on [AttributedText], which is a far
/// more useful foundation for styled text display than [TextSpan]. Second,
/// [SuperDesktopTextField] provides deeper control over various visual properties
/// including selection painting, caret painting, hint display, and keyboard
/// interaction.
///
/// If [SuperDesktopTextField] does not provide the desired level of configuration,
/// look at its implementation. Unlike Flutter's [TextField], [SuperDesktopTextField]
/// is composed of a few widgets that you can recompose to create your own
/// flavor of a text field.
class SuperDesktopTextField extends StatefulWidget {
  const SuperDesktopTextField({
    Key? key,
    this.focusNode,
    this.tapRegionGroupId,
    this.textController,
    this.textStyleBuilder = defaultTextFieldStyleBuilder,
    this.inlineWidgetBuilders = const [],
    this.inheritDefaultTextStyle = false,
    this.textAlign = TextAlign.left,
    this.hintBehavior = HintBehavior.displayHintUntilFocus,
    this.hintBuilder,
    this.selectionHighlightStyle = const SelectionHighlightStyle(
      color: Color(0xFFACCEF7),
    ),
    this.caretStyle = const CaretStyle(
      color: Colors.black,
      width: 1,
      borderRadius: BorderRadius.zero,
    ),
    this.blinkTimingMode = BlinkTimingMode.ticker,
    this.padding = EdgeInsets.zero,
    this.minLines,
    this.maxLines = 1,
    this.decorationBuilder,
    this.onRightClick,
    this.inputSource = TextInputSource.keyboard,
    this.textInputAction,
    this.imeConfiguration,
    this.showComposingUnderline,
    this.selectorHandlers,
    this.tapHandlers = const [],
    List<TextFieldKeyboardHandler>? keyboardHandlers,
  })  : keyboardHandlers = keyboardHandlers ??
            (inputSource == TextInputSource.keyboard
                ? defaultTextFieldKeyboardHandlers
                : defaultTextFieldImeKeyboardHandlers),
        super(key: key);

  final FocusNode? focusNode;

  /// {@macro super_text_field_tap_region_group_id}
  final String? tapRegionGroupId;

  final AttributedTextEditingController? textController;

  /// Text style factory that creates styles for the content in
  /// [textController] based on the attributions in that content.
  final AttributionStyleBuilder textStyleBuilder;

  /// {@macro super_text_field_inline_widget_builders}
  final InlineWidgetBuilderChain inlineWidgetBuilders;

  /// {@macro super_text_field_inherit_default_text_style}
  final bool inheritDefaultTextStyle;

  /// Policy for when the hint should be displayed.
  final HintBehavior hintBehavior;

  /// Builder that creates the hint widget, when a hint is displayed.
  ///
  /// To easily build a hint with styled text, see [StyledHintBuilder].
  final WidgetBuilder? hintBuilder;

  /// The alignment to use for text in this text field.
  ///
  /// If `null`, the text alignment is determined by the text direction
  /// of the content.
  final TextAlign? textAlign;

  /// The visual representation of the user's selection highlight.
  final SelectionHighlightStyle selectionHighlightStyle;

  /// The visual representation of the caret in this `SelectableText` widget.
  final CaretStyle caretStyle;

  /// The timing mechanism used to blink, e.g., `Ticker` or `Timer`.
  ///
  /// `Timer`s are not expected to work in tests.
  final BlinkTimingMode blinkTimingMode;

  final EdgeInsetsGeometry padding;

  final int? minLines;
  final int? maxLines;

  final DecorationBuilder? decorationBuilder;

  @Deprecated('Use tapHandlers instead')
  final RightClickListener? onRightClick;

  /// The [SuperDesktopTextField] input source, e.g., keyboard or Input Method Engine.
  final TextInputSource inputSource;

  /// Priority list of handlers that process all physical keyboard
  /// key presses, for text input, deletion, caret movement, etc.
  ///
  /// If the [inputSource] is [TextInputSource.ime], text input is already handled
  /// using [TextEditingDelta]s, so this list shouldn't include handlers
  /// that input text based on individual character key presses.
  final List<TextFieldKeyboardHandler> keyboardHandlers;

  /// Handlers for all Mac OS "selectors" reported by the IME.
  ///
  /// The IME reports selectors as unique `String`s, therefore selector handlers are
  /// defined as a mapping from selector names to handler functions.
  final Map<String, SuperTextFieldSelectorHandler>? selectorHandlers;

  /// {@macro super_text_field_tap_handlers}
  final List<SuperTextFieldTapHandler> tapHandlers;

  /// The type of action associated with ENTER key.
  ///
  /// This property is ignored when an [imeConfiguration] is provided.
  @Deprecated('This will be removed in a future release. Use imeConfiguration instead')
  final TextInputAction? textInputAction;

  /// Preferences for how the platform IME should look and behave during editing.
  final TextInputConfiguration? imeConfiguration;

  /// Whether to show an underline beneath the text in the composing region, or `null`
  /// to let [SuperDesktopTextField] decide when to show the underline.
  final bool? showComposingUnderline;

  @override
  SuperDesktopTextFieldState createState() => SuperDesktopTextFieldState();
}

class SuperDesktopTextFieldState extends State<SuperDesktopTextField> implements ProseTextBlock, ImeInputOwner {
  final _textKey = GlobalKey<ProseTextState>();
  final _textScrollKey = GlobalKey<SuperTextFieldScrollviewState>();
  late FocusNode _focusNode;
  bool _hasFocus = false; // cache whether we have focus so we know when it changes

  late SuperTextFieldContext _textFieldContext;
  late ImeAttributedTextEditingController _controller;

  /// The text direction of the first character in the text.
  ///
  /// Used to align and position the caret depending on whether
  /// the text is RTL or LTR.
  TextDirection? _contentTextDirection;

  /// The text direction applied to the inner text.
  TextDirection get _textDirection => _contentTextDirection ?? TextDirection.ltr;

  TextAlign get _textAlign =>
      widget.textAlign ??
      ((_textDirection == TextDirection.ltr) //
          ? TextAlign.left
          : TextAlign.right);

  late ScrollController _scrollController;
  late TextFieldScroller _textFieldScroller;

  double? _viewportHeight;

  final _estimatedLineHeight = _EstimatedLineHeight();

  @override
  void initState() {
    super.initState();

    _focusNode = (widget.focusNode ?? FocusNode())..addListener(_updateSelectionAndComposingRegionOnFocusChange);

    _controller = widget.textController != null
        ? widget.textController is ImeAttributedTextEditingController
            ? (widget.textController as ImeAttributedTextEditingController)
            : ImeAttributedTextEditingController(controller: widget.textController, disposeClientController: false)
        : ImeAttributedTextEditingController();
    _controller.addListener(_onSelectionOrContentChange);

    _scrollController = ScrollController();
    _textFieldScroller = TextFieldScroller() //
      ..attach(_scrollController);

    _createTextFieldContext();

    // Check if we need to update the selection.
    _updateSelectionAndComposingRegionOnFocusChange();

    _contentTextDirection = getParagraphDirection(_controller.text.toPlainText());
  }

  @override
  void didUpdateWidget(SuperDesktopTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode.removeListener(_updateSelectionAndComposingRegionOnFocusChange);
      if (oldWidget.focusNode == null) {
        _focusNode.dispose();
      }
      _focusNode = (widget.focusNode ?? FocusNode())..addListener(_updateSelectionAndComposingRegionOnFocusChange);

      // Check if we need to update the selection.
      _updateSelectionAndComposingRegionOnFocusChange();
    }

    if (widget.textController != oldWidget.textController) {
      _controller.removeListener(_onSelectionOrContentChange);
      // When the given textController isn't an ImeAttributedTextEditingController,
      // we wrap it with one. So we need to dispose it.
      if (oldWidget.textController == null || oldWidget.textController is! ImeAttributedTextEditingController) {
        _controller.dispose();
      }
      _controller = widget.textController != null
          ? widget.textController is ImeAttributedTextEditingController
              ? (widget.textController as ImeAttributedTextEditingController)
              : ImeAttributedTextEditingController(controller: widget.textController, disposeClientController: false)
          : ImeAttributedTextEditingController();

      _controller.addListener(_onSelectionOrContentChange);

      _createTextFieldContext();
    }

    if (widget.padding != oldWidget.padding ||
        widget.minLines != oldWidget.minLines ||
        widget.maxLines != oldWidget.maxLines) {
      _onSelectionOrContentChange();
    }
  }

  @override
  void dispose() {
    _textFieldScroller.detach();
    _scrollController.dispose();
    _focusNode.removeListener(_updateSelectionAndComposingRegionOnFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _controller
      ..removeListener(_onSelectionOrContentChange)
      ..detachFromIme();
    if (widget.textController == null) {
      _controller.dispose();
    }

    super.dispose();
  }

  void _createTextFieldContext() {
    _textFieldContext = SuperTextFieldContext(
      textFieldBuildContext: context,
      focusNode: _focusNode,
      controller: _controller,
      getTextLayout: () => textLayout,
      scroller: _textFieldScroller,
    );
  }

  @visibleForTesting
  ScrollController get scrollController => _scrollController;

  @override
  ProseTextLayout get textLayout => _textKey.currentState!.textLayout;

  /// Calculates and returns the `Offset` from the top-left corner of this text field
  /// to the top-left corner of the [textLayout] within this text field.
  Offset get textLayoutOffsetInField {
    final fieldBox = context.findRenderObject() as RenderBox;
    final textLayoutBox = _textKey.currentContext!.findRenderObject() as RenderBox;
    return textLayoutBox.localToGlobal(Offset.zero, ancestor: fieldBox);
  }

  @override
  @visibleForTesting
  DeltaTextInputClient get imeClient => _controller;

  FocusNode get focusNode => _focusNode;

  TextScaler get _textScaler => MediaQuery.textScalerOf(context);

  void requestFocus() {
    _focusNode.requestFocus();
  }

  void _updateSelectionAndComposingRegionOnFocusChange() {
    // If our FocusNode just received focus, automatically set our
    // controller's text position to the end of the available content.
    //
    // This behavior matches Flutter's standard behavior.
    if (_focusNode.hasFocus && !_hasFocus && _controller.selection.extentOffset == -1) {
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    }
    if (!_focusNode.hasFocus) {
      // We lost focus. Clear the composing region.
      _controller.composingRegion = TextRange.empty;
    }
    _hasFocus = _focusNode.hasFocus;
  }

  AttributedTextEditingController get controller => _controller;

  void _onSelectionOrContentChange() {
    // Use a post-frame callback to "ensure selection extent is visible"
    // so that any pending visual content changes can happen before
    // attempting to calculate the visual position of the selection extent.
    onNextFrame((_) => _updateViewportHeight());

    // Even though we calling `onNextFrame`, it doesn't necessarily mean
    // a new frame will be scheduled. Call setState to ensure the text direction is updated.
    setState(() {
      _contentTextDirection = getParagraphDirection(_controller.text.toPlainText());
    });
  }

  /// Returns true if the viewport height changed, false otherwise.
  bool _updateViewportHeight() {
    final estimatedLineHeight = _getEstimatedLineHeight();
    final estimatedLinesOfText = _getEstimatedLinesOfText();
    final estimatedContentHeight = (estimatedLinesOfText * estimatedLineHeight) + widget.padding.vertical;
    final minHeight = widget.minLines != null ? widget.minLines! * estimatedLineHeight + widget.padding.vertical : null;
    final maxHeight = widget.maxLines != null ? widget.maxLines! * estimatedLineHeight + widget.padding.vertical : null;
    double? viewportHeight;
    if (maxHeight != null && estimatedContentHeight > maxHeight) {
      viewportHeight = maxHeight;
    } else if (minHeight != null && estimatedContentHeight < minHeight) {
      viewportHeight = minHeight;
    }

    if (viewportHeight == _viewportHeight) {
      // The height of the viewport hasn't changed. Return.
      return false;
    }

    setState(() {
      _viewportHeight = viewportHeight;
    });

    return true;
  }

  int _getEstimatedLinesOfText() {
    if (_controller.text.isEmpty) {
      return 0;
    }

    if (_textKey.currentState == null) {
      return 0;
    }

    final offsetAtEndOfText = textLayout.getOffsetAtPosition(TextPosition(offset: _controller.text.length));
    int lineCount = (offsetAtEndOfText.dy / _getEstimatedLineHeight()).ceil();

    if (_controller.text.toPlainText().endsWith('\n')) {
      lineCount += 1;
    }

    return lineCount;
  }

  double _getEstimatedLineHeight() {
    // After hot reloading, the text layout might be null, so we can't
    // directly use _textKey.currentState!.textLayout because using it
    // we can't check for null.
    final textLayout = RenderSuperTextLayout.textLayoutFrom(_textKey);

    // We don't expect getHeightForCaret to ever return null, but since its return type is nullable,
    // we use getLineHeightAtPosition as a backup.
    // More information in https://github.com/flutter/flutter/issues/145507.
    final lineHeight = _controller.text.isEmpty || textLayout == null
        ? 0.0
        : textLayout.getHeightForCaret(const TextPosition(offset: 0)) ??
            textLayout.getLineHeightAtPosition(const TextPosition(offset: 0));
    if (lineHeight > 0) {
      return lineHeight;
    }
    final defaultStyle = widget.textStyleBuilder({});
    return _estimatedLineHeight.calculate(defaultStyle, _textScaler);
  }

  bool get _shouldShowComposingUnderline =>
      widget.showComposingUnderline ?? defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Widget build(BuildContext context) {
    if (_textKey.currentContext == null) {
      // The text hasn't been laid out yet, which means our calculations
      // for text height is probably wrong. Schedule a post frame callback
      // to re-calculate the height after initial layout.
      scheduleBuildAfterBuild(() {
        _updateViewportHeight();
      });
    }

    final isMultiline = widget.minLines != 1 || widget.maxLines != 1;

    return TapRegion(
      groupId: widget.tapRegionGroupId,
      child: _buildTextInputSystem(
        isMultiline: isMultiline,
        // As we handle the scrolling gestures ourselves,
        // we use NeverScrollableScrollPhysics to prevent SingleChildScrollView
        // from scrolling. This also prevents the user from interacting
        // with the scrollbar.
        // We use a modified version of Flutter's Scrollbar that allows
        // configuring it with a different scroll physics.
        //
        // See https://github.com/superlistapp/super_editor/issues/1628 for more details.
        child: ScrollbarWithCustomPhysics(
          controller: _scrollController,
          physics: ScrollConfiguration.of(context).getScrollPhysics(context),
          child: SuperTextFieldGestureInteractor(
            focusNode: _focusNode,
            textController: _controller,
            textKey: _textKey,
            textScrollKey: _textScrollKey,
            isMultiline: isMultiline,
            onRightClick: widget.onRightClick,
            tapHandlers: widget.tapHandlers,
            child: MultiListenableBuilder(
              listenables: {
                _focusNode,
                _controller,
              },
              builder: (context) {
                return _buildDecoration(
                  child: SuperTextFieldScrollview(
                    key: _textScrollKey,
                    textKey: _textKey,
                    textController: _controller,
                    textAlign: _textAlign,
                    scrollController: _scrollController,
                    viewportHeight: _viewportHeight,
                    estimatedLineHeight: _getEstimatedLineHeight(),
                    isMultiline: isMultiline,
                    child: FillWidthIfConstrained(
                      child: Padding(
                        // WARNING: Padding within the text scroll view must be placed here, under
                        // FillWidthIfConstrained, rather than around it, because FillWidthIfConstrained makes
                        // decisions about sizing that expects its child to fill all available space in the
                        // ancestor Scrollable.
                        padding: widget.padding,
                        child: _buildSelectableText(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDecoration({
    required Widget child,
  }) {
    return widget.decorationBuilder != null ? widget.decorationBuilder!(context, child) : child;
  }

  Widget _buildTextInputSystem({
    required bool isMultiline,
    required Widget child,
  }) {
    return IntentBlocker(
      intents: CurrentPlatform.isApple ? appleBlockedIntents : nonAppleBlockedIntents,
      child: SuperTextFieldKeyboardInteractor(
        focusNode: _focusNode,
        textFieldContext: _textFieldContext,
        textKey: _textKey,
        keyboardActions: widget.keyboardHandlers,
        child: widget.inputSource == TextInputSource.ime
            ? SuperTextFieldImeInteractor(
                textKey: _textKey,
                focusNode: _focusNode,
                textFieldContext: _textFieldContext,
                isMultiline: isMultiline,
                selectorHandlers: widget.selectorHandlers ?? defaultTextFieldSelectorHandlers,
                textInputAction: widget.textInputAction,
                imeConfiguration: widget.imeConfiguration,
                textStyleBuilder: widget.textStyleBuilder,
                textAlign: widget.textAlign,
                textDirection: Directionality.of(context),
                child: child,
              )
            : child,
      ),
    );
  }

  Widget _buildSelectableText() {
    return Directionality(
      textDirection: _textDirection,
      child: SuperText(
        key: _textKey,
        richText: _controller.text.computeInlineSpan(
          context,
          widget.textStyleBuilder,
          widget.inlineWidgetBuilders,
          defaultTextStyle: widget.inheritDefaultTextStyle ? DefaultTextStyle.of(context).style : null,
        ),
        textAlign: _textAlign,
        textDirection: _textDirection,
        textScaler: _textScaler,
        layerBeneathBuilder: (context, textLayout) {
          final isTextEmpty = _controller.text.isEmpty;
          final showHint = widget.hintBuilder != null &&
              ((isTextEmpty && widget.hintBehavior == HintBehavior.displayHintUntilTextEntered) ||
                  (isTextEmpty && !_focusNode.hasFocus && widget.hintBehavior == HintBehavior.displayHintUntilFocus));

          return Stack(
            children: [
              if (widget.textController?.selection.isValid == true)
                // Selection highlight beneath the text.
                TextLayoutSelectionHighlight(
                  textLayout: textLayout,
                  style: widget.selectionHighlightStyle,
                  selection: widget.textController?.selection,
                ),
              // Underline beneath the composing region.
              if (widget.textController?.composingRegion.isValid == true && _shouldShowComposingUnderline)
                TextUnderlineLayer(
                  textLayout: textLayout,
                  style: StraightUnderlineStyle(
                    color: widget.textStyleBuilder({}).color ?? //
                        (Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white),
                  ),
                  underlines: [
                    TextLayoutUnderline(
                      range: widget.textController!.composingRegion,
                    ),
                  ],
                ),
              if (showHint) //
                Align(
                  alignment: Alignment.centerLeft,
                  child: widget.hintBuilder!(context),
                ),
            ],
          );
        },
        layerAboveBuilder: (context, textLayout) {
          if (!_focusNode.hasFocus) {
            return const SizedBox();
          }

          return TextLayoutCaret(
            textLayout: textLayout,
            style: widget.caretStyle,
            position: _controller.selection.extent,
            blinkTimingMode: widget.blinkTimingMode,
          );
        },
      ),
    );
  }
}

typedef DecorationBuilder = Widget Function(BuildContext, Widget child);

/// Handles all user gesture interactions for text entry.
///
/// [SuperTextFieldGestureInteractor] is intended to operate as a piece within
/// a larger composition that behaves as a text field. [SuperTextFieldGestureInteractor]
/// is defined on its own so that it can be replaced with a widget that handles
/// gestures differently.
///
/// The gestures are applied to a [SuperSelectableText] widget that is
/// tied to [textKey].
///
/// A [SuperTextFieldScrollview] must sit between this [SuperTextFieldGestureInteractor]
/// and the underlying [SuperSelectableText]. That [SuperTextFieldScrollview] must
/// be tied to [textScrollKey].
class SuperTextFieldGestureInteractor extends StatefulWidget {
  const SuperTextFieldGestureInteractor({
    Key? key,
    required this.focusNode,
    required this.textController,
    required this.textKey,
    required this.textScrollKey,
    required this.isMultiline,
    this.onRightClick,
    this.tapHandlers = const [],
    required this.child,
  }) : super(key: key);

  /// [FocusNode] for this text field.
  final FocusNode focusNode;

  /// [TextController] for the text/selection within this text field.
  final AttributedTextEditingController textController;

  /// [GlobalKey] that links this [SuperTextFieldGestureInteractor] to
  /// the [ProseTextLayout] widget that paints the text for this text field.
  final GlobalKey<ProseTextState> textKey;

  /// [GlobalKey] that links this [SuperTextFieldGestureInteractor] to
  /// the [SuperTextFieldScrollview] that's responsible for scrolling
  /// content that exceeds the available space within this text field.
  final GlobalKey<SuperTextFieldScrollviewState> textScrollKey;

  /// Whether or not this text field supports multiple lines of text.
  final bool isMultiline;

  /// Callback invoked when the user right clicks on this text field.
  @Deprecated('Use tapHandlers instead')
  final RightClickListener? onRightClick;

  /// {@macro super_text_field_tap_handlers}
  final List<SuperTextFieldTapHandler> tapHandlers;

  /// The rest of the subtree for this text field.
  final Widget child;

  @override
  State createState() => _SuperTextFieldGestureInteractorState();
}

class _SuperTextFieldGestureInteractorState extends State<SuperTextFieldGestureInteractor> {
  _SelectionType _selectionType = _SelectionType.position;
  Offset? _dragStartInViewport;
  Offset? _dragStartInText;
  Offset? _dragEndInViewport;
  Offset? _dragEndInText;
  Rect? _dragRectInViewport;

  final _dragGutterExtent = 24;
  final _maxDragSpeed = 20;

  /// Holds which kind of device started a pan gesture, e.g., a mouse or a trackpad.
  PointerDeviceKind? _panGestureDevice;

  ProseTextLayout get _textLayout => widget.textKey.currentState!.textLayout;

  SuperTextFieldScrollviewState get _textScroll => widget.textScrollKey.currentState!;

  final _mouseCursor = ValueNotifier<MouseCursor>(SystemMouseCursors.text);

  void _onMouseMove(PointerHoverEvent event) {
    _updateMouseCursor(event.position);
  }

  void _updateMouseCursor(Offset globalPosition) {
    final localPosition = (context.findRenderObject() as RenderBox).globalToLocal(globalPosition);
    final textOffset = _getTextOffset(localPosition);

    for (final handler in widget.tapHandlers) {
      final cursorForContent = handler.mouseCursorForContentHover(
        SuperTextFieldGestureDetails(
          textController: widget.textController,
          textLayout: _textLayout,
          globalOffset: globalPosition,
          layoutOffset: localPosition,
          textOffset: textOffset,
        ),
      );
      if (cursorForContent != null) {
        _mouseCursor.value = cursorForContent;
        return;
      }
    }

    _mouseCursor.value = SystemMouseCursors.text;
  }

  void _onTapDown(TapDownDetails details) {
    _log.fine('Tap down on SuperTextField');

    final textOffset = _getTextOffset(details.localPosition);

    for (final handler in widget.tapHandlers) {
      final result = handler.onTapDown(
        SuperTextFieldGestureDetails(
          textLayout: _textLayout,
          textController: widget.textController,
          globalOffset: details.globalPosition,
          layoutOffset: details.localPosition,
          textOffset: textOffset,
        ),
      );

      if (result == TapHandlingInstruction.halt) {
        return;
      }
    }

    _selectionType = _SelectionType.position;

    final tapTextPosition = _getPositionNearestToTextOffset(textOffset);
    _log.finer("Tap text position: $tapTextPosition");

    final expandSelection = HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftRight) ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shift);

    setState(() {
      widget.textController.selection = expandSelection
          ? TextSelection(
              baseOffset: widget.textController.selection.baseOffset,
              extentOffset: tapTextPosition.offset,
            )
          : TextSelection.collapsed(offset: tapTextPosition.offset);
      widget.textController.composingRegion = TextRange.empty;

      _log.finer("New text field selection: ${widget.textController.selection}");
    });

    widget.focusNode.requestFocus();
  }

  void _onTapUp(TapUpDetails details) {
    final textOffset = _getTextOffset(details.localPosition);
    for (final handler in widget.tapHandlers) {
      final result = handler.onTapUp(
        SuperTextFieldGestureDetails(
          textLayout: _textLayout,
          textController: widget.textController,
          globalOffset: details.globalPosition,
          layoutOffset: details.localPosition,
          textOffset: textOffset,
        ),
      );

      if (result == TapHandlingInstruction.halt) {
        return;
      }
    }
  }

  void _onTapCancel() {
    for (final handler in widget.tapHandlers) {
      final result = handler.onTapCancel();

      if (result == TapHandlingInstruction.halt) {
        return;
      }
    }
  }

  void _onDoubleTapDown(TapDownDetails details) {
    _log.finer('_onDoubleTapDown - EditableDocument: onDoubleTap()');

    final textOffset = _getTextOffset(details.localPosition);

    for (final handler in widget.tapHandlers) {
      final result = handler.onDoubleTapDown(
        SuperTextFieldGestureDetails(
          textLayout: _textLayout,
          textController: widget.textController,
          globalOffset: details.globalPosition,
          layoutOffset: details.localPosition,
          textOffset: textOffset,
        ),
      );

      if (result == TapHandlingInstruction.halt) {
        return;
      }
    }

    _selectionType = _SelectionType.word;

    final tapTextPosition = _getPositionAtOffset(details.localPosition);

    if (tapTextPosition != null) {
      setState(() {
        widget.textController.selection = _textLayout.getWordSelectionAt(tapTextPosition);
      });
    } else {
      _clearSelection();
    }

    widget.focusNode.requestFocus();
  }

  void _onDoubleTapUp(TapUpDetails details) {
    final textOffset = _getTextOffset(details.localPosition);
    for (final handler in widget.tapHandlers) {
      final result = handler.onDoubleTapUp(
        SuperTextFieldGestureDetails(
          textLayout: _textLayout,
          textController: widget.textController,
          globalOffset: details.globalPosition,
          layoutOffset: details.localPosition,
          textOffset: textOffset,
        ),
      );

      if (result == TapHandlingInstruction.halt) {
        return;
      }
    }
  }

  void _onDoubleTap() {
    _selectionType = _SelectionType.position;
  }

  void _onDoubleTapCancel() {
    for (final handler in widget.tapHandlers) {
      final result = handler.onDoubleTapCancel();

      if (result == TapHandlingInstruction.halt) {
        return;
      }
    }
  }

  void _onTripleTapDown(TapDownDetails details) {
    _log.finer('_onTripleTapDown - EditableDocument: onTripleTapDown()');

    final textOffset = _getTextOffset(details.localPosition);

    for (final handler in widget.tapHandlers) {
      final result = handler.onTripleTapDown(
        SuperTextFieldGestureDetails(
          textLayout: _textLayout,
          textController: widget.textController,
          globalOffset: details.globalPosition,
          layoutOffset: details.localPosition,
          textOffset: textOffset,
        ),
      );

      if (result == TapHandlingInstruction.halt) {
        return;
      }
    }

    _selectionType = _SelectionType.paragraph;

    final tapTextPosition = _getPositionAtOffset(details.localPosition);

    if (tapTextPosition != null) {
      setState(() {
        widget.textController.selection = _getParagraphSelectionAt(tapTextPosition, TextAffinity.downstream);
      });
    } else {
      _clearSelection();
    }

    widget.focusNode.requestFocus();
  }

  void _onTripleTapUp(TapUpDetails details) {
    final textOffset = _getTextOffset(details.localPosition);

    for (final handler in widget.tapHandlers) {
      final result = handler.onTripleTapUp(
        SuperTextFieldGestureDetails(
          textLayout: _textLayout,
          textController: widget.textController,
          globalOffset: details.globalPosition,
          layoutOffset: details.localPosition,
          textOffset: textOffset,
        ),
      );

      if (result == TapHandlingInstruction.halt) {
        return;
      }
    }
  }

  void _onTripleTap() {
    _selectionType = _SelectionType.position;
  }

  void _onTripleTapCancel() {
    for (final handler in widget.tapHandlers) {
      final result = handler.onTripleTapCancel();

      if (result == TapHandlingInstruction.halt) {
        return;
      }
    }
  }

  void _onRightClickDown(TapDownDetails details) {
    final textOffset = _getTextOffset(details.localPosition);

    for (final handler in widget.tapHandlers) {
      final result = handler.onSecondaryTapDown(
        SuperTextFieldGestureDetails(
          textLayout: _textLayout,
          textController: widget.textController,
          globalOffset: details.globalPosition,
          layoutOffset: details.localPosition,
          textOffset: textOffset,
        ),
      );

      if (result == TapHandlingInstruction.halt) {
        return;
      }
    }
  }

  void _onRightClickUp(TapUpDetails details) {
    final textOffset = _getTextOffset(details.localPosition);

    for (final handler in widget.tapHandlers) {
      final result = handler.onSecondaryTapUp(
        SuperTextFieldGestureDetails(
          textLayout: _textLayout,
          textController: widget.textController,
          globalOffset: details.globalPosition,
          layoutOffset: details.localPosition,
          textOffset: textOffset,
        ),
      );

      if (result == TapHandlingInstruction.halt) {
        return;
      }
    }
    widget.onRightClick?.call(context, widget.textController, details.localPosition);
  }

  void _onRightClickCancel() {
    for (final handler in widget.tapHandlers) {
      final result = handler.onSecondaryTapCancel();

      if (result == TapHandlingInstruction.halt) {
        return;
      }
    }
  }

  void _onPanStart(DragStartDetails details) {
    _panGestureDevice = details.kind;

    if (_panGestureDevice == PointerDeviceKind.trackpad) {
      // After flutter 3.3, dragging with two fingers on a trackpad triggers a pan gesture.
      // This gesture should scroll the content and keep the selection unchanged.
      return;
    }

    _log.fine("User started pan");
    _dragStartInViewport = details.localPosition;
    _dragStartInText = _getTextOffset(_dragStartInViewport!);

    _dragRectInViewport = Rect.fromLTWH(_dragStartInViewport!.dx, _dragStartInViewport!.dy, 1, 1);

    widget.focusNode.requestFocus();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _log.finer("User moved during pan");

    if (_panGestureDevice == PointerDeviceKind.trackpad) {
      // The user dragged using two fingers on a trackpad.
      // Scroll the content and keep the selection unchanged.
      // We multiply by -1 because the scroll should be in the opposite
      // direction of the drag, e.g., dragging up on a trackpad scrolls
      // the content to downstream direction.
      _scrollVertically(details.delta.dy * -1);
      return;
    }

    setState(() {
      _dragEndInViewport = details.localPosition;
      _dragEndInText = _getTextOffset(_dragEndInViewport!);
      _dragRectInViewport = Rect.fromPoints(_dragStartInViewport!, _dragEndInViewport!);
      _log.finer('_onPanUpdate - drag rect: $_dragRectInViewport');
      _updateDragSelection();

      _scrollIfNearBoundary();
    });
  }

  void _onPanEnd(DragEndDetails details) {
    _log.finer("User ended a pan");

    if (_panGestureDevice == PointerDeviceKind.trackpad) {
      // The user ended a pan gesture with two fingers on a trackpad.
      // We already scrolled the document.
      _textScroll.goBallistic(-details.velocity.pixelsPerSecond.dy);
      return;
    }

    setState(() {
      _dragStartInText = null;
      _dragEndInText = null;
      _dragRectInViewport = null;
    });

    _textScroll.stopScrollingToStart();
    _textScroll.stopScrollingToEnd();
  }

  void _onPanCancel() {
    _log.finer("User cancelled a pan");
    setState(() {
      _dragStartInText = null;
      _dragEndInText = null;
      _dragRectInViewport = null;
    });

    _textScroll.stopScrollingToStart();
    _textScroll.stopScrollingToEnd();
  }

  void _updateDragSelection() {
    if (_dragStartInText == null || _dragEndInText == null) {
      return;
    }

    setState(() {
      final startDragOffset = _getPositionNearestToTextOffset(_dragStartInText!).offset;
      final endDragOffset = _getPositionNearestToTextOffset(_dragEndInText!).offset;
      final affinity = startDragOffset <= endDragOffset ? TextAffinity.downstream : TextAffinity.upstream;

      if (_selectionType == _SelectionType.paragraph) {
        final baseParagraphSelection = _getParagraphSelectionAt(TextPosition(offset: startDragOffset), affinity);
        final extentParagraphSelection = _getParagraphSelectionAt(TextPosition(offset: endDragOffset), affinity);

        widget.textController.selection = _combineSelections(
          baseParagraphSelection,
          extentParagraphSelection,
          affinity,
        );
      } else if (_selectionType == _SelectionType.word) {
        final baseParagraphSelection = _textLayout.getWordSelectionAt(TextPosition(offset: startDragOffset));
        final extentParagraphSelection = _textLayout.getWordSelectionAt(TextPosition(offset: endDragOffset));

        widget.textController.selection = _combineSelections(
          baseParagraphSelection,
          extentParagraphSelection,
          affinity,
        );
      } else {
        widget.textController.selection = TextSelection(
          baseOffset: startDragOffset,
          extentOffset: endDragOffset,
        );
      }
    });
  }

  TextSelection _combineSelections(
    TextSelection selection1,
    TextSelection selection2,
    TextAffinity affinity,
  ) {
    return affinity == TextAffinity.downstream
        ? TextSelection(
            baseOffset: min(selection1.start, selection2.start),
            extentOffset: max(selection1.end, selection2.end),
          )
        : TextSelection(
            baseOffset: max(selection1.end, selection2.end),
            extentOffset: min(selection1.start, selection2.start),
          );
  }

  void _clearSelection() {
    setState(() {
      widget.textController.selection = const TextSelection.collapsed(offset: -1);
    });
  }

  /// We prevent SingleChildScrollView from processing mouse events because
  /// it scrolls by drag by default, which we don't want. However, we do
  /// still want mouse scrolling. This method re-implements a primitive
  /// form of mouse scrolling.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      _scrollVertically(event.scrollDelta.dy);
    }
  }

  void _scrollIfNearBoundary() {
    if (_dragEndInViewport == null) {
      _log.finer("_scrollIfNearBoundary - Can't scroll near boundary because _dragEndInViewport is null");
      assert(_dragEndInViewport != null);
      return;
    }

    if (!widget.isMultiline) {
      _scrollIfNearHorizontalBoundary();
    } else {
      _scrollIfNearVerticalBoundary();
    }
  }

  void _scrollIfNearHorizontalBoundary() {
    final editorBox = context.findRenderObject() as RenderBox;

    if (_dragEndInViewport!.dx < _dragGutterExtent) {
      _startScrollingToStart();
    } else {
      _stopScrollingToStart();
    }
    if (editorBox.size.width - _dragEndInViewport!.dx < _dragGutterExtent) {
      _startScrollingToEnd();
    } else {
      _stopScrollingToEnd();
    }
  }

  void _scrollIfNearVerticalBoundary() {
    final editorBox = context.findRenderObject() as RenderBox;

    if (_dragEndInViewport!.dy < _dragGutterExtent) {
      _startScrollingToStart();
      return;
    } else {
      _stopScrollingToStart();
    }

    if (editorBox.size.height - _dragEndInViewport!.dy < _dragGutterExtent) {
      _startScrollingToEnd();
      return;
    } else {
      _stopScrollingToEnd();
    }
  }

  void _startScrollingToStart() {
    if (_dragEndInViewport == null) {
      _log.finer("_scrollUp - Can't scroll up because _dragEndInViewport is null");
      assert(_dragEndInViewport != null);
      return;
    }

    final gutterAmount = _dragEndInViewport!.dy.clamp(0.0, _dragGutterExtent);
    final speedPercent = 1.0 - (gutterAmount / _dragGutterExtent);
    final scrollAmount = ui.lerpDouble(0, _maxDragSpeed, speedPercent)!;

    _textScroll.startScrollingToStart(amountPerFrame: scrollAmount);
  }

  void _stopScrollingToStart() {
    _textScroll.stopScrollingToStart();
  }

  void _startScrollingToEnd() {
    if (_dragEndInViewport == null) {
      _log.finer("_scrollDown - Can't scroll down because _dragEndInViewport is null");
      assert(_dragEndInViewport != null);
      return;
    }

    final editorBox = context.findRenderObject() as RenderBox;
    final gutterAmount = (editorBox.size.height - _dragEndInViewport!.dy).clamp(0.0, _dragGutterExtent);
    final speedPercent = 1.0 - (gutterAmount / _dragGutterExtent);
    final scrollAmount = ui.lerpDouble(0, _maxDragSpeed, speedPercent)!;

    _textScroll.startScrollingToEnd(amountPerFrame: scrollAmount);
  }

  void _stopScrollingToEnd() {
    _textScroll.stopScrollingToEnd();
  }

  /// Scrolls the document vertically by [delta] pixels.
  void _scrollVertically(double delta) {
    // TODO: remove access to _textScroll.widget
    final newScrollOffset = (_textScroll.widget.scrollController.offset + delta)
        .clamp(0.0, _textScroll.widget.scrollController.position.maxScrollExtent);
    _textScroll.widget.scrollController.jumpTo(newScrollOffset);
    _updateDragSelection();
  }

  /// Beginning with Flutter 3.3.3, we are responsible for starting and
  /// stopping scroll momentum. This method cancels any scroll momentum
  /// in our scroll controller.
  void _cancelScrollMomentum() {
    _textScroll.goIdle();
  }

  TextPosition? _getPositionAtOffset(Offset textFieldOffset) {
    final textOffset = _getTextOffset(textFieldOffset);
    final textBox = widget.textKey.currentContext!.findRenderObject() as RenderBox;

    return textBox.size.contains(textOffset) ? _textLayout.getPositionAtOffset(textOffset) : null;
  }

  TextSelection _getParagraphSelectionAt(TextPosition textPosition, TextAffinity affinity) {
    return _textLayout.expandSelection(textPosition, paragraphExpansionFilter, affinity);
  }

  TextPosition _getPositionNearestToTextOffset(Offset textOffset) {
    return _textLayout.getPositionNearestToOffset(textOffset);
  }

  Offset _getTextOffset(Offset textFieldOffset) {
    final textFieldBox = context.findRenderObject() as RenderBox;
    final textBox = widget.textKey.currentContext!.findRenderObject() as RenderBox;
    return textBox.globalToLocal(textFieldOffset, ancestor: textFieldBox);
  }

  @override
  Widget build(BuildContext context) {
    final gestureSettings = MediaQuery.maybeOf(context)?.gestureSettings;
    return Listener(
      onPointerSignal: _onPointerSignal,
      onPointerHover: (event) => _cancelScrollMomentum(),
      child: GestureDetector(
        onSecondaryTapDown: _onRightClickDown,
        onSecondaryTapUp: _onRightClickUp,
        onSecondaryTapCancel: _onRightClickCancel,
        child: RawGestureDetector(
          behavior: HitTestBehavior.translucent,
          gestures: <Type, GestureRecognizerFactory>{
            TapSequenceGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapSequenceGestureRecognizer>(
              () => TapSequenceGestureRecognizer(),
              (TapSequenceGestureRecognizer recognizer) {
                recognizer
                  ..onTapDown = _onTapDown
                  ..onTapUp = _onTapUp
                  ..onTapCancel = _onTapCancel
                  ..onDoubleTapDown = _onDoubleTapDown
                  ..onDoubleTapUp = _onDoubleTapUp
                  ..onDoubleTap = _onDoubleTap
                  ..onDoubleTapCancel = _onDoubleTapCancel
                  ..onTripleTapDown = _onTripleTapDown
                  ..onTripleTapUp = _onTripleTapUp
                  ..onTripleTapCancel = _onTripleTapCancel
                  ..onTripleTap = _onTripleTap
                  ..gestureSettings = gestureSettings;
              },
            ),
            PanGestureRecognizer: GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
              () => PanGestureRecognizer(),
              (PanGestureRecognizer recognizer) {
                recognizer
                  ..onStart = _onPanStart
                  ..onUpdate = _onPanUpdate
                  ..onEnd = _onPanEnd
                  ..onCancel = _onPanCancel
                  ..gestureSettings = gestureSettings;
              },
            ),
          },
          child: Listener(
            onPointerHover: _onMouseMove,
            child: ValueListenableBuilder(
              valueListenable: _mouseCursor,
              builder: (context, mouseCursor, child) {
                return MouseRegion(
                  cursor: mouseCursor,
                  child: child,
                );
              },
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Handles all keyboard interactions for text entry in a text field.
///
/// [SuperTextFieldKeyboardInteractor] is intended to operate as a piece within
/// a larger composition that behaves as a text field. [SuperTextFieldKeyboardInteractor]
/// is defined on its own so that it can be replaced with a widget that handles
/// key events differently.
///
/// The key events are passed down the [keyboardActions] Chain of Responsibility.
/// Each handler is given a reference to the [textController], to manipulate the
/// text content, and a [TextLayout] via the [textKey], which can be used to make
/// decisions about manipulations, such as moving the caret to the beginning/end
/// of a line.
class SuperTextFieldKeyboardInteractor extends StatefulWidget {
  const SuperTextFieldKeyboardInteractor({
    Key? key,
    required this.focusNode,
    required this.textFieldContext,
    required this.textKey,
    required this.keyboardActions,
    required this.child,
  }) : super(key: key);

  /// [FocusNode] for this text field.
  final FocusNode focusNode;

  /// Shared control over the text field.
  final SuperTextFieldContext textFieldContext;

  /// [GlobalKey] that links this [SuperTextFieldGestureInteractor] to
  /// the [ProseTextLayout] widget that paints the text for this text field.
  final GlobalKey<ProseTextState> textKey;

  /// Ordered list of actions that correspond to various key events.
  ///
  /// Each handler in the list may be given a key event from the keyboard. That
  /// handler chooses to take an action, or not. A handler must respond with
  /// a [TextFieldKeyboardHandlerResult], which indicates how the key event was handled,
  /// or not.
  ///
  /// When a handler reports [TextFieldKeyboardHandlerResult.notHandled], the key event
  /// is sent to the next handler.
  ///
  /// As soon as a handler reports [TextFieldKeyboardHandlerResult.handled], no other
  /// handler is executed and the key event is prevented from propagating up
  /// the widget tree.
  ///
  /// When a handler reports [TextFieldKeyboardHandlerResult.blocked], no other
  /// handler is executed, but the key event **continues** to propagate up
  /// the widget tree for other listeners to act upon.
  ///
  /// If all handlers report [TextFieldKeyboardHandlerResult.notHandled], the key
  /// event propagates up the widget tree for other listeners to act upon.
  final List<TextFieldKeyboardHandler> keyboardActions;

  /// The rest of the subtree for this text field.
  final Widget child;

  @override
  State createState() => _SuperTextFieldKeyboardInteractorState();
}

class _SuperTextFieldKeyboardInteractorState extends State<SuperTextFieldKeyboardInteractor> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(SuperTextFieldKeyboardInteractor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (widget.focusNode.hasFocus) {
      return;
    }

    _log.fine("Clearing selection because SuperTextField lost focus");
    widget.textFieldContext.controller.selection = const TextSelection.collapsed(offset: -1);
  }

  KeyEventResult _onKeyPressed(FocusNode focusNode, KeyEvent keyEvent) {
    _log.fine('_onKeyPressed - keyEvent: ${keyEvent.logicalKey}, character: ${keyEvent.character}');
    if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) {
      _log.finer('_onKeyPressed - not a "down" event. Ignoring.');
      return KeyEventResult.ignored;
    }

    TextFieldKeyboardHandlerResult result = TextFieldKeyboardHandlerResult.notHandled;
    int index = 0;
    while (result == TextFieldKeyboardHandlerResult.notHandled && index < widget.keyboardActions.length) {
      result = widget.keyboardActions[index](
        textFieldContext: widget.textFieldContext,
        keyEvent: keyEvent,
      );
      index += 1;
    }

    _log.finest("Key handler result: $result");
    switch (result) {
      case TextFieldKeyboardHandlerResult.handled:
        return KeyEventResult.handled;
      case TextFieldKeyboardHandlerResult.sendToOperatingSystem:
        return KeyEventResult.skipRemainingHandlers;
      case TextFieldKeyboardHandlerResult.blocked:
      case TextFieldKeyboardHandlerResult.notHandled:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: _onKeyPressed,
      child: widget.child,
    );
  }
}

/// Opens and closes an IME connection based on changes to focus and selection.
///
/// This widget watches [focusNode] for focus changes, and [textController] for
/// selection changes.
///
/// All IME commands are handled and applied to text field text by the given [textController].
///
/// When [focusNode] gains focus, if the [textController] doesn't have a selection, the caret is
/// placed at the end of the text.
///
/// When [focusNode] loses focus, the [textController]'s selection is cleared.
class SuperTextFieldImeInteractor extends StatefulWidget {
  const SuperTextFieldImeInteractor({
    Key? key,
    required this.textKey,
    required this.focusNode,
    required this.textFieldContext,
    required this.isMultiline,
    required this.selectorHandlers,
    this.textInputAction,
    this.imeConfiguration,
    required this.textStyleBuilder,
    this.textAlign,
    this.textDirection,
    required this.child,
  }) : super(key: key);

  /// [FocusNode] for this text field.
  final FocusNode focusNode;

  final SuperTextFieldContext textFieldContext;

  /// Whether or not this text field supports multiple lines of text.
  final bool isMultiline;

  /// [GlobalKey] that links this [SuperTextFieldGestureInteractor] to
  /// the [ProseTextLayout] widget that paints the text for this text field.
  final GlobalKey<ProseTextState> textKey;

  /// Handlers for all Mac OS "selectors" reported by the IME.
  ///
  /// The IME reports selectors as unique `String`s, therefore selector handlers are
  /// defined as a mapping from selector names to handler functions.
  final Map<String, SuperTextFieldSelectorHandler> selectorHandlers;

  /// The type of action associated with ENTER key.
  final TextInputAction? textInputAction;

  /// Preferences for how the platform IME should look and behave during editing.
  final TextInputConfiguration? imeConfiguration;

  /// Text style factory that creates styles for the content in
  /// [textController] based on the attributions in that content.
  ///
  /// On web, we can't set the position of IME popovers (e.g, emoji picker,
  /// character selection panel) ourselves. Because of that, we need
  /// to report to the IME what is our text style, so the browser can position
  /// the popovers based on text metrics computed for the given style.
  ///
  /// This should be the same [AttributionStyleBuilder] used to
  /// render the text.
  final AttributionStyleBuilder textStyleBuilder;

  final TextAlign? textAlign;

  final TextDirection? textDirection;

  /// The rest of the subtree for this text field.
  final Widget child;

  @override
  State<SuperTextFieldImeInteractor> createState() => _SuperTextFieldImeInteractorState();
}

class _SuperTextFieldImeInteractorState extends State<SuperTextFieldImeInteractor> {
  late ImeAttributedTextEditingController _textController;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_updateSelectionAndImeConnectionOnFocusChange);

    _textController = widget.textFieldContext.imeController!
      ..inputConnectionNotifier.addListener(_onImeConnectionChanged)
      ..onPerformActionPressed ??= _onPerformAction
      ..onPerformSelector ??= _onPerformSelector;

    if (widget.focusNode.hasFocus) {
      // We got an already focused FocusNode, we need to attach to the IME.
      onNextFrame((_) => _updateSelectionAndImeConnectionOnFocusChange());
    }
  }

  @override
  void didUpdateWidget(SuperTextFieldImeInteractor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode.removeListener(_updateSelectionAndImeConnectionOnFocusChange);
      widget.focusNode.addListener(_updateSelectionAndImeConnectionOnFocusChange);

      if (widget.focusNode.hasFocus) {
        // We got an already focused FocusNode, we need to attach to the IME.
        onNextFrame((_) => _updateSelectionAndImeConnectionOnFocusChange());
      }
    }

    if (widget.textFieldContext.imeController != _textController) {
      if (_textController.onPerformActionPressed == _onPerformAction) {
        _textController.onPerformActionPressed = null;
      }
      if (_textController.onPerformSelector == _onPerformSelector) {
        _textController.onPerformSelector = null;
      }
      _textController.inputConnectionNotifier.removeListener(_onImeConnectionChanged);

      _textController = widget.textFieldContext.imeController!
        ..inputConnectionNotifier.addListener(_onImeConnectionChanged)
        ..onPerformActionPressed ??= _onPerformAction
        ..onPerformSelector ??= _onPerformSelector;
    }

    if (widget.imeConfiguration != oldWidget.imeConfiguration &&
        widget.imeConfiguration != null &&
        (oldWidget.imeConfiguration == null || !widget.imeConfiguration!.isEquivalentTo(oldWidget.imeConfiguration!)) &&
        _textController.isAttachedToIme) {
      _textController.updateTextInputConfiguration(
        viewId: View.of(context).viewId,
        textInputAction: widget.imeConfiguration!.inputAction,
        textInputType: widget.imeConfiguration!.inputType,
        autocorrect: widget.imeConfiguration!.autocorrect,
        enableSuggestions: widget.imeConfiguration!.enableSuggestions,
        keyboardAppearance: widget.imeConfiguration!.keyboardAppearance,
        textCapitalization: widget.imeConfiguration!.textCapitalization,
      );
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_updateSelectionAndImeConnectionOnFocusChange);
    _textController.inputConnectionNotifier.removeListener(_onImeConnectionChanged);
    if (_textController.onPerformSelector == _onPerformSelector) {
      _textController.onPerformSelector = null;
    }
    if (_textController.onPerformActionPressed == _onPerformAction) {
      _textController.onPerformActionPressed = null;
    }
    super.dispose();
  }

  void _updateSelectionAndImeConnectionOnFocusChange() {
    if (widget.focusNode.hasFocus) {
      if (!_textController.isAttachedToIme) {
        _log.info('Attaching TextInputClient to TextInput');
        setState(() {
          if (!_textController.selection.isValid) {
            _textController.selection = TextSelection.collapsed(offset: _textController.text.length);
          }

          if (widget.imeConfiguration != null) {
            _textController.attachToImeWithConfig(widget.imeConfiguration!);
          } else {
            _textController.attachToIme(
              viewId: View.of(context).viewId,
              textInputType: widget.isMultiline ? TextInputType.multiline : TextInputType.text,
              textInputAction:
                  widget.textInputAction ?? (widget.isMultiline ? TextInputAction.newline : TextInputAction.done),
            );
          }
        });
      }
    } else {
      _log.info('Lost focus. Detaching TextInputClient from TextInput.');
      setState(() {
        _textController.detachFromIme();
        _textController.selection = const TextSelection.collapsed(offset: -1);
      });
    }
  }

  void _onImeConnectionChanged() {
    if (!_textController.isAttachedToIme) {
      return;
    }

    _reportVisualInformationToIme();
  }

  /// Report our size, transform to the root node coordinates, and caret rect to the IME.
  ///
  /// This is needed to display the OS emoji & symbols panel at the text field selected position.
  ///
  /// This methods is re-scheduled to run at the end of every frame while we are attached to the IME.
  void _reportVisualInformationToIme() {
    if (!_textController.isAttachedToIme) {
      return;
    }

    _reportSizeAndTransformToIme();
    _reportCaretRectToIme();
    _reportTextStyleToIme();

    // Without showing the keyboard, the panel is always positioned at the screen center after the first time.
    // I'm not sure why this is needed in SuperTextField, but not in SuperEditor.
    _textController.showKeyboard();

    // There are some operations that might affect our transform or the caret rect but we can't react to them.
    // For example, the text field might be resized or moved around the screen.
    // Because of this, we update our size, transform and caret rect at every frame.
    onNextFrame((_) => _reportVisualInformationToIme());
  }

  /// Report the global size and transform of the text field to the IME.
  ///
  /// This is needed to display the OS emoji & symbols panel at the selected position.
  void _reportSizeAndTransformToIme() {
    final renderBox = widget.textKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return;
    }

    _textController.inputConnectionNotifier.value!
        .setEditableSizeAndTransform(renderBox.size, renderBox.getTransformTo(null));
  }

  void _reportCaretRectToIme() {
    if (CurrentPlatform.isWeb) {
      // On web, setting the caret rect isn't supported.
      // To position the IME popovers, we report our size, transform and text style
      // and let the browser position the popovers.
      return;
    }

    final caretRect = _computeCaretRectInContentSpace();
    if (caretRect != null) {
      _textController.inputConnectionNotifier.value!.setCaretRect(caretRect);
    }
  }

  /// Report our text style to the IME.
  ///
  /// This is used on web to set the text style of the hidden native input,
  /// to try to match the text size on the browser with our text size.
  ///
  /// As our content can have multiple styles, the sizes won't be 100% in sync.
  void _reportTextStyleToIme() {
    late TextStyle textStyle;

    final selection = _textController.selection;
    if (!selection.isValid) {
      return;
    }

    // We have a selection, compute the style based on the attributions present
    // at the selection extent.
    final text = _textController.text;
    final attributions = text.getAllAttributionsAt(selection.extentOffset);
    textStyle = widget.textStyleBuilder(attributions);

    _textController.inputConnectionNotifier.value!.setStyle(
      fontFamily: textStyle.fontFamily,
      fontSize: textStyle.fontSize,
      fontWeight: textStyle.fontWeight,
      textDirection: widget.textDirection ?? TextDirection.ltr,
      textAlign: widget.textAlign ?? TextAlign.left,
    );
  }

  Rect? _computeCaretRectInContentSpace() {
    final text = widget.textKey.currentState;
    if (text == null) {
      return null;
    }

    final selection = _textController.selection;
    if (!selection.isValid) {
      return null;
    }

    final renderBox = context.findRenderObject() as RenderBox;

    // Compute the caret rect in the text layout space.
    final position = TextPosition(offset: selection.baseOffset);
    final textLayout = text.textLayout;
    final caretOffset = textLayout.getOffsetForCaret(position);
    final caretHeight = textLayout.getHeightForCaret(position) ?? textLayout.estimatedLineHeight;
    final caretRect = caretOffset & Size(1, caretHeight);

    // Convert the coordinates from the text layout space to the text field space.
    final textRenderBox = text.context.findRenderObject() as RenderBox;
    final textOffset = renderBox.globalToLocal(textRenderBox.localToGlobal(Offset.zero));
    final caretOffsetInTextFieldSpace = caretRect.shift(textOffset);

    return caretOffsetInTextFieldSpace;
  }

  void _onPerformSelector(String selectorName) {
    final handler = widget.selectorHandlers[selectorName];
    if (handler == null) {
      editorImeLog.warning("No handler found for $selectorName");
      return;
    }

    handler(textFieldContext: widget.textFieldContext);
  }

  /// Handles actions from the IME.
  void _onPerformAction(TextInputAction action) {
    switch (action) {
      case TextInputAction.newline:
        // Do nothing for IME newline actions.
        //
        // Mac: Key presses flow, unhandled, to the OS and turn into IME selectors. We handle newlines there.
        // Windows/Linux: Key presses flow, unhandled, to the OS and turn into text deltas. We handle newlines there.
        // Android/iOS: This text field implementation is only for desktop, mobile is handled elsewhere.
        break;
      case TextInputAction.done:
        widget.focusNode.unfocus();
        break;
      case TextInputAction.next:
        widget.focusNode.nextFocus();
        break;
      case TextInputAction.previous:
        widget.focusNode.previousFocus();
        break;
      default:
        _log.warning("User pressed unhandled action button: $action");
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Handles all scrolling behavior for a text field.
///
/// [SuperTextFieldScrollview] is intended to operate as a piece within
/// a larger composition that behaves as a text field. [SuperTextFieldScrollview]
/// is defined on its own so that it can be replaced with a widget that handles
/// scrolling differently.
///
/// [SuperTextFieldScrollview] determines when and where to scroll by working
/// with a corresponding [SuperSelectableText] widget that is tied to [textKey].
class SuperTextFieldScrollview extends StatefulWidget {
  const SuperTextFieldScrollview({
    Key? key,
    required this.textKey,
    required this.textController,
    required this.scrollController,
    required this.viewportHeight,
    required this.estimatedLineHeight,
    required this.isMultiline,
    this.textAlign = TextAlign.left,
    required this.child,
  }) : super(key: key);

  /// [TextController] for the text/selection within this text field.
  final AttributedTextEditingController textController;

  /// [GlobalKey] that links this [SuperTextFieldScrollview] to
  /// the [ProseTextLayout] widget that paints the text for this text field.
  final GlobalKey<ProseTextState> textKey;

  /// [ScrollController] that controls the scroll offset of this [SuperTextFieldScrollview].
  final ScrollController scrollController;

  /// The height of the viewport for this text field.
  ///
  /// If [null] then the viewport is permitted to grow/shrink to any desired height.
  final double? viewportHeight;

  /// An estimate for the height in pixels of a single line of text within this
  /// text field.
  final double estimatedLineHeight;

  /// Whether or not this text field allows multiple lines of text.
  final bool isMultiline;

  /// The text alignment within the scrollview.
  final TextAlign textAlign;

  /// The rest of the subtree for this text field.
  final Widget child;

  @override
  SuperTextFieldScrollviewState createState() => SuperTextFieldScrollviewState();
}

class SuperTextFieldScrollviewState extends State<SuperTextFieldScrollview> with SingleTickerProviderStateMixin {
  bool _scrollToStartOnTick = false;
  bool _scrollToEndOnTick = false;
  double _scrollAmountPerFrame = 0;
  late Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);

    widget.textController.addListener(_onSelectionOrContentChange);
  }

  @override
  void didUpdateWidget(SuperTextFieldScrollview oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.textController != oldWidget.textController) {
      oldWidget.textController.removeListener(_onSelectionOrContentChange);
      widget.textController.addListener(_onSelectionOrContentChange);
    }

    if (widget.viewportHeight != oldWidget.viewportHeight) {
      // After the current layout, ensure that the current text
      // selection is visible.
      onNextFrame((_) => _ensureSelectionExtentIsVisible());
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  ProseTextLayout get _textLayout => widget.textKey.currentState!.textLayout;

  void _onSelectionOrContentChange() {
    // Use a post-frame callback to "ensure selection extent is visible"
    // so that any pending visual content changes can happen before
    // attempting to calculate the visual position of the selection extent.
    onNextFrame((_) => _ensureSelectionExtentIsVisible());
  }

  void _ensureSelectionExtentIsVisible() {
    if (!widget.isMultiline) {
      _ensureSelectionExtentIsVisibleInSingleLineTextField();
    } else {
      _ensureSelectionExtentIsVisibleInMultilineTextField();
    }
  }

  void _ensureSelectionExtentIsVisibleInSingleLineTextField() {
    final selection = widget.textController.selection;
    if (selection.extentOffset == -1) {
      return;
    }

    final viewportBox = context.findRenderObject() as RenderBox;
    final textBox = widget.textKey.currentContext!.findRenderObject() as RenderBox;
    // Note: the textBoxOffset will be negative.
    final textBoxOffset = textBox.globalToLocal(Offset.zero, ancestor: viewportBox);

    final selectionExtentOffsetInText = _textLayout.getOffsetAtPosition(selection.extent);

    const gutterExtent = 0; // _dragGutterExtent

    final beyondLeftViewportEdge = min(-textBoxOffset.dx + selectionExtentOffsetInText.dx - gutterExtent, 0).abs();
    final beyondRightViewportEdge =
        max((-textBoxOffset.dx + selectionExtentOffsetInText.dx + gutterExtent) - viewportBox.size.width, 0);

    if (beyondLeftViewportEdge > 0) {
      final newScrollPosition = (widget.scrollController.offset - beyondLeftViewportEdge)
          .clamp(0.0, widget.scrollController.position.maxScrollExtent);

      widget.scrollController.animateTo(
        newScrollPosition,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    } else if (beyondRightViewportEdge > 0) {
      final newScrollPosition = (beyondRightViewportEdge + widget.scrollController.offset)
          .clamp(0.0, widget.scrollController.position.maxScrollExtent);

      widget.scrollController.animateTo(
        newScrollPosition,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  void _ensureSelectionExtentIsVisibleInMultilineTextField() {
    final selection = widget.textController.selection;
    if (selection.extentOffset == -1) {
      return;
    }

    final extentOffset = _textLayout.getOffsetAtPosition(selection.extent);

    const gutterExtent = 0; // _dragGutterExtent
    final extentLineIndex = (extentOffset.dy / widget.estimatedLineHeight).round();

    final firstCharY = _textLayout.getCharacterBox(const TextPosition(offset: 0))?.top ?? 0.0;
    final isAtFirstLine = extentOffset.dy == firstCharY;

    final myBox = context.findRenderObject() as RenderBox;
    final beyondTopExtent = min<double>(
            extentOffset.dy - //
                widget.scrollController.offset -
                gutterExtent -
                (isAtFirstLine ? _textLayout.getLineHeightAtPosition(selection.extent) / 2 : 0),
            0)
        .abs();

    final lastCharY =
        _textLayout.getCharacterBox(TextPosition(offset: widget.textController.text.length - 1))?.top ?? 0.0;
    final isAtLastLine = extentOffset.dy == lastCharY;

    final beyondBottomExtent = max<double>(
        ((extentLineIndex + 1) * widget.estimatedLineHeight) -
            myBox.size.height -
            widget.scrollController.offset +
            gutterExtent +
            (isAtLastLine ? _textLayout.getLineHeightAtPosition(selection.extent) / 2 : 0) +
            (widget.estimatedLineHeight / 2), // manual adjustment to avoid line getting half cut off
        0);

    _log.finer('_ensureSelectionExtentIsVisible - Ensuring extent is visible.');
    _log.finer('_ensureSelectionExtentIsVisible    - interaction size: ${myBox.size}');
    _log.finer('_ensureSelectionExtentIsVisible    - scroll extent: ${widget.scrollController.offset}');
    _log.finer('_ensureSelectionExtentIsVisible    - extent rect: $extentOffset');
    _log.finer('_ensureSelectionExtentIsVisible    - beyond top: $beyondTopExtent');
    _log.finer('_ensureSelectionExtentIsVisible    - beyond bottom: $beyondBottomExtent');

    if (beyondTopExtent > 0) {
      final newScrollPosition = (widget.scrollController.offset - beyondTopExtent)
          .clamp(0.0, widget.scrollController.position.maxScrollExtent);

      widget.scrollController.animateTo(
        newScrollPosition,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    } else if (beyondBottomExtent > 0) {
      final newScrollPosition = (beyondBottomExtent + widget.scrollController.offset)
          .clamp(0.0, widget.scrollController.position.maxScrollExtent);

      widget.scrollController.animateTo(
        newScrollPosition,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  void startScrollingToStart({required double amountPerFrame}) {
    assert(amountPerFrame > 0);

    if (_scrollToStartOnTick) {
      _scrollAmountPerFrame = amountPerFrame;
      return;
    }

    _scrollToStartOnTick = true;
    _log.finer("Starting Ticker to auto-scroll up");
    _ticker.start();
  }

  void stopScrollingToStart() {
    if (!_scrollToStartOnTick) {
      return;
    }

    _scrollToStartOnTick = false;
    _scrollAmountPerFrame = 0;
    _log.finer("Stopping Ticker after auto-scroll up");
    _ticker.stop();
  }

  void scrollToStart() {
    if (widget.scrollController.offset <= 0) {
      return;
    }

    widget.scrollController.position.jumpTo(widget.scrollController.offset - _scrollAmountPerFrame);
  }

  void startScrollingToEnd({required double amountPerFrame}) {
    assert(amountPerFrame > 0);

    if (_scrollToEndOnTick) {
      _scrollAmountPerFrame = amountPerFrame;
      return;
    }

    _scrollToEndOnTick = true;
    _log.finer("Starting Ticker to auto-scroll down");
    _ticker.start();
  }

  void stopScrollingToEnd() {
    if (!_scrollToEndOnTick) {
      return;
    }

    _scrollToEndOnTick = false;
    _scrollAmountPerFrame = 0;
    _log.finer("Stopping Ticker after auto-scroll down");
    _ticker.stop();
  }

  void scrollToEnd() {
    if (widget.scrollController.offset >= widget.scrollController.position.maxScrollExtent) {
      return;
    }

    widget.scrollController.position.jumpTo(widget.scrollController.offset + _scrollAmountPerFrame);
  }

  /// Animates the scroll position like a ballistic particle with friction, beginning
  /// with the given [pixelsPerSecond] velocity.
  void goBallistic(double pixelsPerSecond) {
    final pos = widget.scrollController.position;

    if (pos is ScrollPositionWithSingleContext) {
      if (pos.maxScrollExtent > 0) {
        pos.goBallistic(pixelsPerSecond);
      }
      pos.context.setIgnorePointer(false);
    }
  }

  /// Immediately stops scrolling animation/momentum.
  void goIdle() {
    final pos = widget.scrollController.position;

    if (pos is ScrollPositionWithSingleContext) {
      if (pos.pixels > pos.minScrollExtent && pos.pixels < pos.maxScrollExtent) {
        pos.goIdle();
      }
    }
  }

  void _onTick(elapsedTime) {
    if (_scrollToStartOnTick) {
      scrollToStart();
    }
    if (_scrollToEndOnTick) {
      scrollToEnd();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.viewportHeight,
      // As we handle the scrolling gestures ourselves,
      // we use NeverScrollableScrollPhysics to prevent SingleChildScrollView
      // from scrolling. This also prevents the user from interacting
      // with the scrollbar.
      // We use a modified version of Flutter's Scrollbar that allows
      // configuring it with a different scroll physics.
      //
      // See https://github.com/superlistapp/super_editor/issues/1628 for more details.
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          controller: widget.scrollController,
          physics: const NeverScrollableScrollPhysics(),
          scrollDirection: widget.isMultiline ? Axis.vertical : Axis.horizontal,
          child: widget.child,
        ),
      ),
    );
  }
}

typedef RightClickListener = void Function(
    BuildContext textFieldContext, AttributedTextEditingController textController, Offset textFieldOffset);

enum _SelectionType {
  /// The selection bound is set on a per-character basis.
  ///
  /// This is standard text selection behavior.
  position,

  /// The selection bound expands to include any word that the
  /// cursor touches.
  word,

  /// The selection bound expands to include any paragraph that
  /// the cursor touches.
  paragraph,
}

enum TextFieldKeyboardHandlerResult {
  /// The handler recognized the key event and chose to
  /// take an action.
  ///
  /// No other handler should receive the key event.
  ///
  /// The key event **shouldn't** bubble up the tree.
  handled,

  /// The handler recognized the key event but chose to
  /// take no action.
  ///
  /// No other handler should receive the key event.
  ///
  /// The key event **should** bubble up the tree to
  /// (possibly) be handled by other keyboard/shortcut
  /// listeners.
  blocked,

  /// The handler recognized the key event but chose to
  /// take no action.
  ///
  /// No other handler should receive the key event.
  ///
  /// The key event shouldn't bubble up the Flutter tree,
  /// but it should be sent to the operating system (rather
  /// than being consumed and disposed).
  ///
  /// Use this result, for example, when Mac OS needs to
  /// convert a key event into a selector, and send that
  /// selector through the IME.
  sendToOperatingSystem,

  /// The handler has no relation to the key event and
  /// took no action.
  ///
  /// Other handlers should be given a chance to act on
  /// the key press.
  notHandled,
}

typedef TextFieldKeyboardHandler = TextFieldKeyboardHandlerResult Function({
  required SuperTextFieldContext textFieldContext,
  required KeyEvent keyEvent,
});

/// A [TextFieldKeyboardHandler] that reports [TextFieldKeyboardHandlerResult.blocked]
/// for any key combination that matches one of the given [keys].
TextFieldKeyboardHandler ignoreTextFieldKeyCombos(List<ShortcutActivator> keys) {
  return ({
    required SuperTextFieldContext textFieldContext,
    required KeyEvent keyEvent,
  }) {
    for (final key in keys) {
      if (key.accepts(keyEvent, HardwareKeyboard.instance)) {
        return TextFieldKeyboardHandlerResult.blocked;
      }
    }
    return TextFieldKeyboardHandlerResult.notHandled;
  };
}

/// The keyboard actions that a [SuperTextField] uses by default.
///
/// It's common for developers to want all of these actions, but also
/// want to add more actions that take priority. To achieve that,
/// add the new actions to the front of the list:
///
/// ```
/// SuperTextField(
///   keyboardActions: [
///     myNewAction1,
///     myNewAction2,
///     ...defaultTextfieldKeyboardActions,
///   ],
/// );
/// ```
const defaultTextFieldKeyboardHandlers = <TextFieldKeyboardHandler>[
  DefaultSuperTextFieldKeyboardHandlers.scrollOnPageUp,
  DefaultSuperTextFieldKeyboardHandlers.scrollOnPageDown,
  DefaultSuperTextFieldKeyboardHandlers.scrollToBeginningOfDocumentOnCtrlOrCmdAndHome,
  DefaultSuperTextFieldKeyboardHandlers.scrollToEndOfDocumentOnCtrlOrCmdAndEnd,
  DefaultSuperTextFieldKeyboardHandlers.scrollToBeginningOfDocumentOnHomeOnMacOrWeb,
  DefaultSuperTextFieldKeyboardHandlers.scrollToEndOfDocumentOnEndOnMacOrWeb,
  DefaultSuperTextFieldKeyboardHandlers.copyTextWhenCmdCIsPressed,
  DefaultSuperTextFieldKeyboardHandlers.pasteTextWhenCmdVIsPressed,
  DefaultSuperTextFieldKeyboardHandlers.selectAllTextFieldWhenCmdAIsPressed,
  DefaultSuperTextFieldKeyboardHandlers.moveCaretToStartOrEnd,
  DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys,
  DefaultSuperTextFieldKeyboardHandlers.moveToLineStartWithHome,
  DefaultSuperTextFieldKeyboardHandlers.moveToLineEndWithEnd,
  DefaultSuperTextFieldKeyboardHandlers.deleteWordWhenAltBackSpaceIsPressedOnMac,
  DefaultSuperTextFieldKeyboardHandlers.deleteWordWhenCtlBackSpaceIsPressedOnWindowsAndLinux,
  DefaultSuperTextFieldKeyboardHandlers.deleteTextOnLineBeforeCaretWhenShortcutKeyAndBackspaceIsPressed,
  DefaultSuperTextFieldKeyboardHandlers.deleteTextWhenBackspaceOrDeleteIsPressed,
  DefaultSuperTextFieldKeyboardHandlers.insertNewlineWhenEnterIsPressed,
  DefaultSuperTextFieldKeyboardHandlers.blockControlKeys,
  DefaultSuperTextFieldKeyboardHandlers.insertCharacterWhenKeyIsPressed,
];

/// The keyboard actions that a [SuperTextField] uses by default when using [TextInputSource.ime].
///
/// Using the IME on desktop involves partial input from the IME and partial input from non-content keys,
/// like arrow keys.
///
/// This list has the same handlers as [defaultTextFieldKeyboardHandlers], except the handlers that
/// input text. Text input is handled using [TextEditingDelta]s from the IME.
///
/// It's common for developers to want all of these actions, but also
/// want to add more actions that take priority. To achieve that,
/// add the new actions to the front of the list:
///
/// ```
/// SuperTextField(
///   keyboardActions: [
///     myNewAction1,
///     myNewAction2,
///     ...defaultTextFieldImeKeyboardHandlers,
///   ],
/// );
/// ```
const defaultTextFieldImeKeyboardHandlers = <TextFieldKeyboardHandler>[
  DefaultSuperTextFieldKeyboardHandlers.copyTextWhenCmdCIsPressed,
  DefaultSuperTextFieldKeyboardHandlers.pasteTextWhenCmdVIsPressed,
  DefaultSuperTextFieldKeyboardHandlers.selectAllTextFieldWhenCmdAIsPressed,
  DefaultSuperTextFieldKeyboardHandlers.scrollToBeginningOfDocumentOnCtrlOrCmdAndHome,
  DefaultSuperTextFieldKeyboardHandlers.scrollToEndOfDocumentOnCtrlOrCmdAndEnd,
  // WARNING: No keyboard handlers below this point will run on Mac. On Mac, most
  // common shortcuts are recognized by the OS. This line short circuits SuperTextField
  // handlers, passing the key combo to the OS on Mac. Place all custom Mac key
  // combos above this handler.
  DefaultSuperTextFieldKeyboardHandlers.sendKeyEventToMacOs,
  DefaultSuperTextFieldKeyboardHandlers.scrollOnPageUp,
  DefaultSuperTextFieldKeyboardHandlers.scrollOnPageDown,
  DefaultSuperTextFieldKeyboardHandlers.scrollToBeginningOfDocumentOnHomeOnMacOrWeb,
  DefaultSuperTextFieldKeyboardHandlers.scrollToEndOfDocumentOnEndOnMacOrWeb,
  DefaultSuperTextFieldKeyboardHandlers.moveCaretToStartOrEnd,
  DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys,
  DefaultSuperTextFieldKeyboardHandlers.moveToLineStartWithHome,
  DefaultSuperTextFieldKeyboardHandlers.moveToLineEndWithEnd,
  DefaultSuperTextFieldKeyboardHandlers.deleteWordWhenAltBackSpaceIsPressedOnMac,
  DefaultSuperTextFieldKeyboardHandlers.deleteWordWhenCtlBackSpaceIsPressedOnWindowsAndLinux,
  DefaultSuperTextFieldKeyboardHandlers.deleteTextOnLineBeforeCaretWhenShortcutKeyAndBackspaceIsPressed,
  DefaultSuperTextFieldKeyboardHandlers.deleteTextWhenBackspaceOrDeleteIsPressed,
];

class DefaultSuperTextFieldKeyboardHandlers {
  /// [copyTextWhenCmdCIsPressed] copies text to clipboard when primary shortcut key
  /// (CMD on Mac, CTL on Windows) + C is pressed.
  static TextFieldKeyboardHandlerResult copyTextWhenCmdCIsPressed({
    required SuperTextFieldContext textFieldContext,
    required KeyEvent keyEvent,
  }) {
    if (!keyEvent.isPrimaryShortcutKeyPressed) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }
    if (keyEvent.logicalKey != LogicalKeyboardKey.keyC) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }
    if (textFieldContext.controller.selection.extentOffset == -1) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    textFieldContext.controller.copySelectedTextToClipboard();

    return TextFieldKeyboardHandlerResult.handled;
  }

  /// [pasteTextWhenCmdVIsPressed] pastes text from clipboard to document when primary shortcut key
  /// (CMD on Mac, CTL on Windows) + V is pressed.
  static TextFieldKeyboardHandlerResult pasteTextWhenCmdVIsPressed({
    required SuperTextFieldContext textFieldContext,
    required KeyEvent keyEvent,
  }) {
    if (!keyEvent.isPrimaryShortcutKeyPressed) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }
    if (keyEvent.logicalKey != LogicalKeyboardKey.keyV) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }
    if (textFieldContext.controller.selection.extentOffset == -1) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    if (!textFieldContext.controller.selection.isCollapsed) {
      textFieldContext.controller.deleteSelectedText();
    }

    textFieldContext.controller.pasteClipboard();

    return TextFieldKeyboardHandlerResult.handled;
  }

  /// [selectAllTextFieldWhenCmdAIsPressed] selects all text when primary shortcut key
  /// (CMD on Mac, CTL on Windows) + A is pressed.
  static TextFieldKeyboardHandlerResult selectAllTextFieldWhenCmdAIsPressed({
    required SuperTextFieldContext textFieldContext,
    required KeyEvent keyEvent,
  }) {
    if (!keyEvent.isPrimaryShortcutKeyPressed) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }
    if (keyEvent.logicalKey != LogicalKeyboardKey.keyA) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    textFieldContext.controller.selectAll();

    return TextFieldKeyboardHandlerResult.handled;
  }

  /// [moveCaretToStartOrEnd] moves caret to start (using CTL+A) or end of line (using CTL+E)
  /// on MacOS platforms. This is part of expected behavior on MacOS. Not applicable to Windows.
  static TextFieldKeyboardHandlerResult moveCaretToStartOrEnd({
    required SuperTextFieldContext textFieldContext,
    required KeyEvent keyEvent,
  }) {
    bool moveLeft = false;
    if (!HardwareKeyboard.instance.isControlPressed) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }
    if (keyEvent.logicalKey != LogicalKeyboardKey.keyA && keyEvent.logicalKey != LogicalKeyboardKey.keyE) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }
    if (textFieldContext.controller.selection.extentOffset == -1) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    keyEvent.logicalKey == LogicalKeyboardKey.keyA
        ? moveLeft = true
        : keyEvent.logicalKey == LogicalKeyboardKey.keyE
            ? moveLeft = false
            : null;

    textFieldContext.controller.moveCaretHorizontally(
      textLayout: textFieldContext.getTextLayout(),
      expandSelection: false,
      moveLeft: moveLeft,
      movementModifier: MovementModifier.line,
    );

    return TextFieldKeyboardHandlerResult.handled;
  }

  /// [moveUpDownLeftAndRightWithArrowKeys] moves caret according to the directional key which was pressed.
  /// If there is no caret selection. it does nothing.
  static TextFieldKeyboardHandlerResult moveUpDownLeftAndRightWithArrowKeys({
    required SuperTextFieldContext textFieldContext,
    required KeyEvent keyEvent,
  }) {
    const arrowKeys = [
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
    ];
    if (!arrowKeys.contains(keyEvent.logicalKey)) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    if (CurrentPlatform.isWeb && (textFieldContext.controller.composingRegion.isValid)) {
      // We are composing a character on web. It's possible that a native element is being displayed,
      // like an emoji picker or a character selection panel.
      // We need to let the OS handle the key so the user can navigate
      // on the list of possible characters.
      // TODO: update this after https://github.com/flutter/flutter/issues/134268 is resolved.
      return TextFieldKeyboardHandlerResult.blocked;
    }

    if (textFieldContext.controller.selection.extentOffset == -1) {
      // The result is reported as "handled" because an arrow
      // key was pressed, but we return early because there is
      // nowhere to move without a selection.
      return TextFieldKeyboardHandlerResult.handled;
    }

    if (defaultTargetPlatform == TargetPlatform.windows && HardwareKeyboard.instance.isAltPressed) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    if (defaultTargetPlatform == TargetPlatform.linux &&
        HardwareKeyboard.instance.isAltPressed &&
        (keyEvent.logicalKey == LogicalKeyboardKey.arrowUp || keyEvent.logicalKey == LogicalKeyboardKey.arrowDown)) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    if (keyEvent.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _log.finer('moveUpDownLeftAndRightWithArrowKeys - handling left arrow key');

      MovementModifier? movementModifier;
      if ((defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux) &&
          HardwareKeyboard.instance.isControlPressed) {
        movementModifier = MovementModifier.word;
      } else if (defaultTargetPlatform == TargetPlatform.macOS && HardwareKeyboard.instance.isMetaPressed) {
        movementModifier = MovementModifier.line;
      } else if (defaultTargetPlatform == TargetPlatform.macOS && HardwareKeyboard.instance.isAltPressed) {
        movementModifier = MovementModifier.word;
      }

      textFieldContext.controller.moveCaretHorizontally(
        textLayout: textFieldContext.getTextLayout(),
        expandSelection: HardwareKeyboard.instance.isShiftPressed,
        moveLeft: true,
        movementModifier: movementModifier,
      );
    } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowRight) {
      _log.finer('moveUpDownLeftAndRightWithArrowKeys - handling right arrow key');

      MovementModifier? movementModifier;
      if ((defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux) &&
          HardwareKeyboard.instance.isControlPressed) {
        movementModifier = MovementModifier.word;
      } else if (defaultTargetPlatform == TargetPlatform.macOS && HardwareKeyboard.instance.isMetaPressed) {
        movementModifier = MovementModifier.line;
      } else if (defaultTargetPlatform == TargetPlatform.macOS && HardwareKeyboard.instance.isAltPressed) {
        movementModifier = MovementModifier.word;
      }

      textFieldContext.controller.moveCaretHorizontally(
        textLayout: textFieldContext.getTextLayout(),
        expandSelection: HardwareKeyboard.instance.isShiftPressed,
        moveLeft: false,
        movementModifier: movementModifier,
      );
    } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowUp) {
      _log.finer('moveUpDownLeftAndRightWithArrowKeys - handling up arrow key');
      textFieldContext.controller.moveCaretVertically(
        textLayout: textFieldContext.getTextLayout(),
        expandSelection: HardwareKeyboard.instance.isShiftPressed,
        moveUp: true,
      );
    } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowDown) {
      _log.finer('moveUpDownLeftAndRightWithArrowKeys - handling down arrow key');
      textFieldContext.controller.moveCaretVertically(
        textLayout: textFieldContext.getTextLayout(),
        expandSelection: HardwareKeyboard.instance.isShiftPressed,
        moveUp: false,
      );
    }

    return TextFieldKeyboardHandlerResult.handled;
  }

  static TextFieldKeyboardHandlerResult moveToLineStartWithHome({
    required SuperTextFieldContext textFieldContext,
    required KeyEvent keyEvent,
  }) {
    if (defaultTargetPlatform != TargetPlatform.windows && defaultTargetPlatform != TargetPlatform.linux) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    if (keyEvent.logicalKey == LogicalKeyboardKey.home) {
      textFieldContext.controller.moveCaretHorizontally(
        textLayout: textFieldContext.getTextLayout(),
        expandSelection: HardwareKeyboard.instance.isShiftPressed,
        moveLeft: true,
        movementModifier: MovementModifier.line,
      );
      return TextFieldKeyboardHandlerResult.handled;
    }

    return TextFieldKeyboardHandlerResult.notHandled;
  }

  static TextFieldKeyboardHandlerResult moveToLineEndWithEnd({
    required SuperTextFieldContext textFieldContext,
    required KeyEvent keyEvent,
  }) {
    if (defaultTargetPlatform != TargetPlatform.windows && defaultTargetPlatform != TargetPlatform.linux) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    if (keyEvent.logicalKey == LogicalKeyboardKey.end) {
      textFieldContext.controller.moveCaretHorizontally(
        textLayout: textFieldContext.getTextLayout(),
        expandSelection: HardwareKeyboard.instance.isShiftPressed,
        moveLeft: false,
        movementModifier: MovementModifier.line,
      );
      return TextFieldKeyboardHandlerResult.handled;
    }

    return TextFieldKeyboardHandlerResult.notHandled;
  }

  /// [insertCharacterWhenKeyIsPressed] adds any character when that key is pressed.
  /// Certain keys are currently checked against a blacklist of characters for web
  /// since their behavior is unexpected. Check definition for more details.
  static TextFieldKeyboardHandlerResult insertCharacterWhenKeyIsPressed({
    required SuperTextFieldContext textFieldContext,
    required KeyEvent keyEvent,
  }) {
    if (HardwareKeyboard.instance.isMetaPressed || HardwareKeyboard.instance.isControlPressed) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    if (keyEvent.character == null || keyEvent.character == '') {
      return TextFieldKeyboardHandlerResult.notHandled;
    }
    if (LogicalKeyboardKey.isControlCharacter(keyEvent.character!)) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    // On web, keys like shift and alt are sending their full name
    // as a character, e.g., "Shift" and "Alt". This check prevents
    // those keys from inserting their name into content.
    //
    // This filter is a blacklist, and therefore it will fail to
    // catch any key that isn't explicitly listed. The eventual solution
    // to this is for the web to honor the standard key event contract,
    // but that's out of our control.
    if (isKeyEventCharacterBlacklisted(keyEvent.character)) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    textFieldContext.controller.insertCharacter(keyEvent.character!);

    return TextFieldKeyboardHandlerResult.handled;
  }

  /// Deletes text between the beginning of the line and the caret, when the user
  /// presses CMD + Backspace, or CTL + Backspace.
  static TextFieldKeyboardHandlerResult deleteTextOnLineBeforeCaretWhenShortcutKeyAndBackspaceIsPressed({
    required SuperTextFieldContext textFieldContext,
    required KeyEvent keyEvent,
  }) {
    if (!keyEvent.isPrimaryShortcutKeyPressed || keyEvent.logicalKey != LogicalKeyboardKey.backspace) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }
    if (textFieldContext.controller.selection.extentOffset < 0) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    if (!textFieldContext.controller.selection.isCollapsed) {
      textFieldContext.controller.deleteSelection();
      return TextFieldKeyboardHandlerResult.handled;
    }

    if (textFieldContext
            .getTextLayout()
            .getPositionAtStartOfLine(textFieldContext.controller.selection.extent)
            .offset ==
        textFieldContext.controller.selection.extentOffset) {
      // The caret is sitting at the beginning of a line. There's nothing for us to
      // delete upstream on this line. But we also don't want a regular BACKSPACE to
      // run, either. Report this key combination as handled.
      return TextFieldKeyboardHandlerResult.handled;
    }

    textFieldContext.controller.deleteTextOnLineBeforeCaret(textLayout: textFieldContext.getTextLayout());

    return TextFieldKeyboardHandlerResult.handled;
  }

  /// [deleteTextWhenBackspaceOrDeleteIsPressed] deletes single characters when delete or backspace is pressed.
  static TextFieldKeyboardHandlerResult deleteTextWhenBackspaceOrDeleteIsPressed({
    required SuperTextFieldContext textFieldContext,
    ProseTextLayout? textLayout,
    required KeyEvent keyEvent,
  }) {
    final isBackspace = keyEvent.logicalKey == LogicalKeyboardKey.backspace;
    final isDelete = keyEvent.logicalKey == LogicalKeyboardKey.delete;
    if (!isBackspace && !isDelete) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }
    if (textFieldContext.controller.selection.extentOffset < 0) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    if (textFieldContext.controller.selection.isCollapsed) {
      textFieldContext.controller.deleteCharacter(isBackspace ? TextAffinity.upstream : TextAffinity.downstream);
    } else {
      textFieldContext.controller.deleteSelectedText();
    }

    return TextFieldKeyboardHandlerResult.handled;
  }

  /// [deleteWordWhenAltBackSpaceIsPressedOnMac] deletes single words when Alt+Backspace is pressed on Mac.
  static TextFieldKeyboardHandlerResult deleteWordWhenAltBackSpaceIsPressedOnMac({
    required SuperTextFieldContext textFieldContext,
    required KeyEvent keyEvent,
  }) {
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    if (keyEvent.logicalKey != LogicalKeyboardKey.backspace || !HardwareKeyboard.instance.isAltPressed) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }
    if (textFieldContext.controller.selection.extentOffset < 0) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    _deleteUpstreamWord(textFieldContext.controller, textFieldContext.getTextLayout());

    return TextFieldKeyboardHandlerResult.handled;
  }

  /// [deleteWordWhenAltBackSpaceIsPressedOnMac] deletes single words when Ctl+Backspace is pressed on Windows/Linux.
  static TextFieldKeyboardHandlerResult deleteWordWhenCtlBackSpaceIsPressedOnWindowsAndLinux({
    required SuperTextFieldContext textFieldContext,
    required KeyEvent keyEvent,
  }) {
    if (defaultTargetPlatform != TargetPlatform.windows && defaultTargetPlatform != TargetPlatform.linux) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    if (keyEvent.logicalKey != LogicalKeyboardKey.backspace || !HardwareKeyboard.instance.isControlPressed) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }
    if (textFieldContext.controller.selection.extentOffset < 0) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    _deleteUpstreamWord(textFieldContext.controller, textFieldContext.getTextLayout());

    return TextFieldKeyboardHandlerResult.handled;
  }

  static void _deleteUpstreamWord(AttributedTextEditingController controller, ProseTextLayout textLayout) {
    if (!controller.selection.isCollapsed) {
      controller.deleteSelectedText();
      return;
    }

    controller.moveCaretHorizontally(
      textLayout: textLayout,
      expandSelection: true,
      moveLeft: true,
      movementModifier: MovementModifier.word,
    );
    controller.deleteSelectedText();
  }

  /// [insertNewlineWhenEnterIsPressed] inserts a new line character when the enter key is pressed.
  static TextFieldKeyboardHandlerResult insertNewlineWhenEnterIsPressed({
    required SuperTextFieldContext textFieldContext,
    ProseTextLayout? textLayout,
    required KeyEvent keyEvent,
  }) {
    if (keyEvent.logicalKey != LogicalKeyboardKey.enter && keyEvent.logicalKey != LogicalKeyboardKey.numpadEnter) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }
    if (!textFieldContext.controller.selection.isCollapsed) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    textFieldContext.controller.insertNewline();

    return TextFieldKeyboardHandlerResult.handled;
  }

  static TextFieldKeyboardHandlerResult sendKeyEventToMacOs({
    required SuperTextFieldContext textFieldContext,
    required KeyEvent keyEvent,
  }) {
    if (defaultTargetPlatform == TargetPlatform.macOS && !CurrentPlatform.isWeb) {
      // On macOS, we let the IME handle all key events. Then, the IME might generate
      // selectors which express the user intent, e.g, moveLeftAndModifySelection:.
      //
      // For the full list of selectors handled by SuperEditor, see the MacOsSelectors class.
      //
      // This is needed for the interaction with the accent panel to work.
      return TextFieldKeyboardHandlerResult.sendToOperatingSystem;
    }

    return TextFieldKeyboardHandlerResult.notHandled;
  }

  /// Scrolls up by the viewport height, or as high as possible,
  /// when the user presses the Page Up key.
  ///
  /// Scrolls the text field if it has scrollable content, if not then scrolls the
  /// ancestor scrollable content if one's present.
  static TextFieldKeyboardHandlerResult scrollOnPageUp({
    required SuperTextFieldContext textFieldContext,
    required KeyEvent keyEvent,
  }) {
    if (keyEvent is! KeyDownEvent) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    if (keyEvent.logicalKey != LogicalKeyboardKey.pageUp) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    final bool scrolled = _scrollPageUp(textFieldContext: textFieldContext);

    /// If scrolled, mark the key event as 'handled', otherwise 'notHandled' to give other
    /// key handlers opportunity to handle the key event.
    return scrolled ? TextFieldKeyboardHandlerResult.handled : TextFieldKeyboardHandlerResult.notHandled;
  }

  /// Scrolls down by the viewport height, or as far as possible,
  /// when the user presses the Page Down key.
  ///
  /// Scrolls the text field if it has scrollable content, if not then scrolls the
  /// ancestor scrollable content if one's present.
  static TextFieldKeyboardHandlerResult scrollOnPageDown({
    required SuperTextFieldContext textFieldContext,
    required KeyEvent keyEvent,
  }) {
    if (keyEvent is! KeyDownEvent) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    if (keyEvent.logicalKey != LogicalKeyboardKey.pageDown) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    final bool scrolled = _scrollPageDown(textFieldContext: textFieldContext);

    /// If scrolled, mark the key event as 'handled', otherwise 'notHandled' to give other
    /// key handlers opportunity to handle the key event.
    return scrolled ? TextFieldKeyboardHandlerResult.handled : TextFieldKeyboardHandlerResult.notHandled;
  }

  /// Scrolls the viewport to the top of the content, when the user presses
  /// CMD + HOME on Mac, or CTRL + HOME on all other platforms.
  ///
  /// Scrolls the text field if it has scrollable content, if not then scrolls to the
  /// top of the ancestor scrollable content if one's present.
  static TextFieldKeyboardHandlerResult scrollToBeginningOfDocumentOnCtrlOrCmdAndHome({
    required SuperTextFieldContext textFieldContext,
    required KeyEvent keyEvent,
  }) {
    if (keyEvent is! KeyDownEvent) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    if (keyEvent.logicalKey != LogicalKeyboardKey.home) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    if (CurrentPlatform.isApple && !HardwareKeyboard.instance.isMetaPressed) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    if (!CurrentPlatform.isApple && !HardwareKeyboard.instance.isControlPressed) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    final bool scrolled = _scrollToBeginningOfDocument(textFieldContext: textFieldContext);

    /// If scrolled, mark the key event as 'handled', otherwise 'notHandled' to give other
    /// key handlers opportunity to handle the key event.
    return scrolled ? TextFieldKeyboardHandlerResult.handled : TextFieldKeyboardHandlerResult.notHandled;
  }

  /// Scrolls the viewport to the bottom of the content, when the user presses
  /// CMD + END on Mac, or CTRL + END on all other platforms.
  ///
  /// Scrolls the text field if it has scrollable content, if not then scrolls to the
  /// bottom of the ancestor scrollable content if one's present.
  static TextFieldKeyboardHandlerResult scrollToEndOfDocumentOnCtrlOrCmdAndEnd({
    required SuperTextFieldContext textFieldContext,
    required KeyEvent keyEvent,
  }) {
    if (keyEvent is! KeyDownEvent) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    if (keyEvent.logicalKey != LogicalKeyboardKey.end) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    if (CurrentPlatform.isApple && !HardwareKeyboard.instance.isMetaPressed) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    if (!CurrentPlatform.isApple && !HardwareKeyboard.instance.isControlPressed) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    final bool scrolled = _scrollToEndOfDocument(textFieldContext: textFieldContext);

    /// If scrolled, mark the key event as 'handled', otherwise 'notHandled' to give other
    /// key handlers opportunity to handle the key event.
    return scrolled ? TextFieldKeyboardHandlerResult.handled : TextFieldKeyboardHandlerResult.notHandled;
  }

  /// Scrolls the viewport to the top of the content, when the user presses
  /// HOME on Mac or web.
  ///
  /// Scrolls the text field if it has scrollable content, if not then scrolls to the
  /// top of the ancestor scrollable content if one's present.
  static TextFieldKeyboardHandlerResult scrollToBeginningOfDocumentOnHomeOnMacOrWeb({
    required SuperTextFieldContext textFieldContext,
    required KeyEvent keyEvent,
  }) {
    if (keyEvent is! KeyDownEvent) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    if (keyEvent.logicalKey != LogicalKeyboardKey.home) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    if (defaultTargetPlatform != TargetPlatform.macOS && !CurrentPlatform.isWeb) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    final bool scrolled = _scrollToBeginningOfDocument(textFieldContext: textFieldContext);

    /// If scrolled, mark the key event as 'handled', otherwise 'notHandled' to give other
    /// key handlers opportunity to handle the key event.
    return scrolled ? TextFieldKeyboardHandlerResult.handled : TextFieldKeyboardHandlerResult.notHandled;
  }

  /// Scrolls the viewport to the bottom of the content, when the user presses
  /// END on Mac or web.
  ///
  /// Scrolls the text field if it has scrollable content, if not then scrolls to the
  /// bottom of the ancestor scrollable content if one's present.
  static TextFieldKeyboardHandlerResult scrollToEndOfDocumentOnEndOnMacOrWeb({
    required SuperTextFieldContext textFieldContext,
    required KeyEvent keyEvent,
  }) {
    if (keyEvent is! KeyDownEvent) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    if (keyEvent.logicalKey != LogicalKeyboardKey.end) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    if (defaultTargetPlatform != TargetPlatform.macOS && !CurrentPlatform.isWeb) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    final bool scrolled = _scrollToEndOfDocument(textFieldContext: textFieldContext);

    /// If scrolled, mark the key event as 'handled', otherwise 'notHandled' to give other
    /// key handlers opportunity to handle the key event.
    return scrolled ? TextFieldKeyboardHandlerResult.handled : TextFieldKeyboardHandlerResult.notHandled;
  }

  /// Halt execution of the current key event if the key pressed is one of
  /// the functions keys (F1, F2, F3, etc.), or the Page Up/Down, Home/End key.
  ///
  /// Without this action in place pressing one of the above mentioned keys
  /// would display an unknown '?' character in the textfield.
  static TextFieldKeyboardHandlerResult blockControlKeys({
    required SuperTextFieldContext textFieldContext,
    required KeyEvent keyEvent,
  }) {
    if (keyEvent.logicalKey == LogicalKeyboardKey.escape ||
        keyEvent.logicalKey == LogicalKeyboardKey.pageUp ||
        keyEvent.logicalKey == LogicalKeyboardKey.pageDown ||
        keyEvent.logicalKey == LogicalKeyboardKey.home ||
        keyEvent.logicalKey == LogicalKeyboardKey.end ||
        (keyEvent.logicalKey.keyId >= LogicalKeyboardKey.f1.keyId &&
            keyEvent.logicalKey.keyId <= LogicalKeyboardKey.f23.keyId)) {
      return TextFieldKeyboardHandlerResult.blocked;
    }

    return TextFieldKeyboardHandlerResult.notHandled;
  }

  DefaultSuperTextFieldKeyboardHandlers._();
}

/// Computes the estimated line height of a [TextStyle].
class _EstimatedLineHeight {
  /// Last computed line height.
  double? _lastLineHeight;

  /// TextStyle used to compute [_lastLineHeight].
  TextStyle? _lastComputedStyle;

  /// Text scale policy used to compute [_lastLineHeight].
  TextScaler? _lastTextScaleFactor;

  /// Computes the estimated line height for the given [style].
  ///
  /// The height is computed by laying out a [Paragraph] with an arbitrary
  /// character and inspecting it's height.
  ///
  /// The result is cached for the last [style] and [textScaler] used, so it's not computed
  /// at each call.
  double calculate(TextStyle style, TextScaler textScaler) {
    if (_lastComputedStyle == style &&
        _lastLineHeight != null &&
        _lastTextScaleFactor == textScaler &&
        _lastTextScaleFactor != null) {
      return _lastLineHeight!;
    }

    final builder = ui.ParagraphBuilder(style.getParagraphStyle())
      ..pushStyle(style.getTextStyle(textScaler: textScaler))
      ..addText('A');

    final paragraph = builder.build();
    paragraph.layout(const ui.ParagraphConstraints(width: double.infinity));

    _lastLineHeight = paragraph.height;
    _lastComputedStyle = style;
    _lastTextScaleFactor = textScaler;
    return _lastLineHeight!;
  }
}

/// A callback to handle a `performSelector` call.
typedef SuperTextFieldSelectorHandler = void Function({
  required SuperTextFieldContext textFieldContext,
});

const defaultTextFieldSelectorHandlers = <String, SuperTextFieldSelectorHandler>{
  // Control.
  MacOsSelectors.insertTab: _moveFocusNext,
  MacOsSelectors.cancelOperation: _giveUpFocus,

  // Caret movement.
  MacOsSelectors.moveLeft: _moveCaretUpstream,
  MacOsSelectors.moveRight: _moveCaretDownstream,
  MacOsSelectors.moveUp: _moveCaretUp,
  MacOsSelectors.moveDown: _moveCaretDown,
  MacOsSelectors.moveForward: _moveCaretDownstream,
  MacOsSelectors.moveBackward: _moveCaretUpstream,
  MacOsSelectors.moveWordLeft: _moveWordUpstream,
  MacOsSelectors.moveWordRight: _moveWordDownstream,
  MacOsSelectors.moveToLeftEndOfLine: _moveLineBeginning,
  MacOsSelectors.moveToRightEndOfLine: _moveLineEnd,

  // Selection expanding.
  MacOsSelectors.moveLeftAndModifySelection: _expandSelectionUpstream,
  MacOsSelectors.moveRightAndModifySelection: _expandSelectionDownstream,
  MacOsSelectors.moveUpAndModifySelection: _expandSelectionLineUp,
  MacOsSelectors.moveDownAndModifySelection: _expandSelectionLineDown,
  MacOsSelectors.moveWordLeftAndModifySelection: _expandSelectionWordUpstream,
  MacOsSelectors.moveWordRightAndModifySelection: _expandSelectionWordDownstream,
  MacOsSelectors.moveToLeftEndOfLineAndModifySelection: _expandSelectionLineUpstream,
  MacOsSelectors.moveToRightEndOfLineAndModifySelection: _expandSelectionLineDownstream,

  // Deletion.
  MacOsSelectors.deleteBackward: _deleteUpstream,
  MacOsSelectors.deleteForward: _deleteDownstream,
  MacOsSelectors.deleteWordBackward: _deleteWordUpstream,
  MacOsSelectors.deleteWordForward: _deleteWordDownstream,
  MacOsSelectors.deleteToBeginningOfLine: _deleteToBeginningOfLine,
  MacOsSelectors.deleteToEndOfLine: _deleteToEndOfLine,
  MacOsSelectors.deleteBackwardByDecomposingPreviousCharacter: _deleteUpstream,

  // Scrolling.
  MacOsSelectors.scrollToBeginningOfDocument: _scrollToBeginningOfDocument,
  MacOsSelectors.scrollToEndOfDocument: _scrollToEndOfDocument,
  MacOsSelectors.scrollPageUp: _scrollPageUp,
  MacOsSelectors.scrollPageDown: _scrollPageDown,
};

void _giveUpFocus({
  required SuperTextFieldContext textFieldContext,
}) {
  textFieldContext.focusNode.unfocus();
}

void _moveFocusNext({
  required SuperTextFieldContext textFieldContext,
}) {
  textFieldContext.focusNode.nextFocus();
}

void _moveCaretUpstream({
  required SuperTextFieldContext textFieldContext,
}) {
  textFieldContext.controller.moveCaretHorizontally(
    textLayout: textFieldContext.getTextLayout(),
    moveLeft: true,
    expandSelection: false,
    movementModifier: null,
  );
}

void _moveCaretDownstream({
  required SuperTextFieldContext textFieldContext,
}) {
  textFieldContext.controller.moveCaretHorizontally(
    textLayout: textFieldContext.getTextLayout(),
    moveLeft: false,
    expandSelection: false,
    movementModifier: null,
  );
}

void _moveCaretUp({
  required SuperTextFieldContext textFieldContext,
}) {
  textFieldContext.controller.moveCaretVertically(
    textLayout: textFieldContext.getTextLayout(),
    moveUp: true,
    expandSelection: false,
  );
}

void _moveCaretDown({
  required SuperTextFieldContext textFieldContext,
}) {
  textFieldContext.controller.moveCaretVertically(
    textLayout: textFieldContext.getTextLayout(),
    moveUp: false,
    expandSelection: false,
  );
}

void _moveWordUpstream({
  required SuperTextFieldContext textFieldContext,
}) {
  textFieldContext.controller.moveCaretHorizontally(
    textLayout: textFieldContext.getTextLayout(),
    moveLeft: true,
    expandSelection: false,
    movementModifier: MovementModifier.word,
  );
}

void _moveWordDownstream({
  required SuperTextFieldContext textFieldContext,
}) {
  textFieldContext.controller.moveCaretHorizontally(
    textLayout: textFieldContext.getTextLayout(),
    moveLeft: false,
    expandSelection: false,
    movementModifier: MovementModifier.word,
  );
}

void _moveLineBeginning({
  required SuperTextFieldContext textFieldContext,
}) {
  textFieldContext.controller.moveCaretHorizontally(
    textLayout: textFieldContext.getTextLayout(),
    moveLeft: true,
    expandSelection: false,
    movementModifier: MovementModifier.line,
  );
}

void _moveLineEnd({
  required SuperTextFieldContext textFieldContext,
}) {
  textFieldContext.controller.moveCaretHorizontally(
    textLayout: textFieldContext.getTextLayout(),
    moveLeft: false,
    expandSelection: false,
    movementModifier: MovementModifier.line,
  );
}

void _expandSelectionUpstream({
  required SuperTextFieldContext textFieldContext,
}) {
  textFieldContext.controller.moveCaretHorizontally(
    textLayout: textFieldContext.getTextLayout(),
    moveLeft: true,
    expandSelection: true,
    movementModifier: null,
  );
}

void _expandSelectionDownstream({
  required SuperTextFieldContext textFieldContext,
}) {
  textFieldContext.controller.moveCaretHorizontally(
    textLayout: textFieldContext.getTextLayout(),
    moveLeft: false,
    expandSelection: true,
    movementModifier: null,
  );
}

void _expandSelectionLineUp({
  required SuperTextFieldContext textFieldContext,
}) {
  textFieldContext.controller.moveCaretVertically(
    textLayout: textFieldContext.getTextLayout(),
    moveUp: true,
    expandSelection: true,
  );
}

void _expandSelectionLineDown({
  required SuperTextFieldContext textFieldContext,
}) {
  textFieldContext.controller.moveCaretVertically(
    textLayout: textFieldContext.getTextLayout(),
    moveUp: false,
    expandSelection: true,
  );
}

void _expandSelectionWordUpstream({
  required SuperTextFieldContext textFieldContext,
}) {
  textFieldContext.controller.moveCaretHorizontally(
    textLayout: textFieldContext.getTextLayout(),
    moveLeft: true,
    expandSelection: true,
    movementModifier: MovementModifier.word,
  );
}

void _expandSelectionWordDownstream({
  required SuperTextFieldContext textFieldContext,
}) {
  textFieldContext.controller.moveCaretHorizontally(
    textLayout: textFieldContext.getTextLayout(),
    moveLeft: false,
    expandSelection: true,
    movementModifier: MovementModifier.word,
  );
}

void _expandSelectionLineUpstream({
  required SuperTextFieldContext textFieldContext,
}) {
  textFieldContext.controller.moveCaretHorizontally(
    textLayout: textFieldContext.getTextLayout(),
    moveLeft: true,
    expandSelection: true,
    movementModifier: MovementModifier.line,
  );
}

void _expandSelectionLineDownstream({
  required SuperTextFieldContext textFieldContext,
}) {
  textFieldContext.controller.moveCaretHorizontally(
    textLayout: textFieldContext.getTextLayout(),
    moveLeft: false,
    expandSelection: true,
    movementModifier: MovementModifier.line,
  );
}

void _deleteUpstream({
  required SuperTextFieldContext textFieldContext,
}) {
  if (textFieldContext.controller.selection.isCollapsed) {
    textFieldContext.controller.deleteCharacter(TextAffinity.upstream);
  } else {
    textFieldContext.controller.deleteSelectedText();
  }
}

void _deleteDownstream({
  required SuperTextFieldContext textFieldContext,
}) {
  if (textFieldContext.controller.selection.isCollapsed) {
    textFieldContext.controller.deleteCharacter(TextAffinity.downstream);
  } else {
    textFieldContext.controller.deleteSelectedText();
  }
}

void _deleteWordUpstream({
  required SuperTextFieldContext textFieldContext,
}) {
  if (!textFieldContext.controller.selection.isCollapsed) {
    textFieldContext.controller.deleteSelectedText();
    return;
  }

  textFieldContext.controller.moveCaretHorizontally(
    textLayout: textFieldContext.getTextLayout(),
    expandSelection: true,
    moveLeft: true,
    movementModifier: MovementModifier.word,
  );
  textFieldContext.controller.deleteSelectedText();
}

void _deleteWordDownstream({
  required SuperTextFieldContext textFieldContext,
}) {
  if (!textFieldContext.controller.selection.isCollapsed) {
    textFieldContext.controller.deleteSelectedText();
    return;
  }

  textFieldContext.controller.moveCaretHorizontally(
    textLayout: textFieldContext.getTextLayout(),
    expandSelection: true,
    moveLeft: false,
    movementModifier: MovementModifier.word,
  );

  textFieldContext.controller.deleteSelectedText();
}

void _deleteToBeginningOfLine({
  required SuperTextFieldContext textFieldContext,
}) {
  if (!textFieldContext.controller.selection.isCollapsed) {
    textFieldContext.controller.deleteSelection();
    return;
  }

  if (textFieldContext.getTextLayout().getPositionAtStartOfLine(textFieldContext.controller.selection.extent).offset ==
      textFieldContext.controller.selection.extentOffset) {
    // The caret is sitting at the beginning of a line. There's nothing for us to
    // delete upstream on this line. But we also don't want a regular BACKSPACE to
    // run, either. Report this key combination as handled.
    return;
  }

  textFieldContext.controller.deleteTextOnLineBeforeCaret(textLayout: textFieldContext.getTextLayout());
}

void _deleteToEndOfLine({
  required SuperTextFieldContext textFieldContext,
}) {
  if (!textFieldContext.controller.selection.isCollapsed) {
    textFieldContext.controller.deleteSelection();
    return;
  }

  if (textFieldContext.getTextLayout().getPositionAtEndOfLine(textFieldContext.controller.selection.extent).offset ==
      textFieldContext.controller.selection.extentOffset) {
    // The caret is sitting at the end of a line. There's nothing for us to
    // delete downstream on this line.
    return;
  }

  textFieldContext.controller.deleteTextOnLineAfterCaret(textLayout: textFieldContext.getTextLayout());
}

/// Scrolls to the top of the textfield.
///
/// In absence of scrollable content within textfield, tries to scroll the ancestor
/// scrollable to its top.
///
/// Returns `true` if the scroll is performed, otherwise 'false'.
bool _scrollToBeginningOfDocument({
  required SuperTextFieldContext textFieldContext,
}) {
  final TextFieldScroller textFieldScroller = textFieldContext.scroller;
  final ScrollPosition? ancestorScrollable =
      textFieldContext.textFieldBuildContext.findAncestorScrollableWithVerticalScroll?.position;

  if (textFieldScroller.maxScrollExtent == 0 && ancestorScrollable == null) {
    // The text field doesn't have any scrollable content. There is no ancestor
    // scrollable to scroll. Fizzle.
    return false;
  }

  if (textFieldScroller.scrollOffset > 0) {
    // The text field has more content than can fit, and the text field is partially
    // scrolled downward. Scroll back to the top of the text field.
    textFieldScroller.animateTo(
      textFieldScroller.minScrollExtent,
      duration: const Duration(milliseconds: 150),
      curve: Curves.decelerate,
    );

    return true;
  }

  if (ancestorScrollable == null) {
    // There is no ancestor scrollable to scroll. Fizzle.
    return false;
  }

  // Scroll to the top of the ancestor scrollable.
  ancestorScrollable.animateTo(
    ancestorScrollable.minScrollExtent,
    duration: const Duration(milliseconds: 150),
    curve: Curves.decelerate,
  );

  return true;
}

/// Scrolls to the end of the textfield.
///
/// In absence of scrollable content within textfield, tries to scroll the ancestor
/// scrollable to its end.
///
/// Returns `true` if the scroll is performed, otherwise false.
bool _scrollToEndOfDocument({
  required SuperTextFieldContext textFieldContext,
}) {
  final TextFieldScroller textFieldScroller = textFieldContext.scroller;
  final ScrollPosition? ancestorScrollable =
      textFieldContext.textFieldBuildContext.findAncestorScrollableWithVerticalScroll?.position;

  if (textFieldScroller.maxScrollExtent == 0 && ancestorScrollable == null) {
    // The text field doesn't have any scrollable content. There is no ancestor
    // scrollable to scroll. Fizzle.
    return false;
  }

  if (textFieldScroller.scrollOffset < textFieldScroller.maxScrollExtent) {
    // The text field has more content than can fit, and the text field is partially
    // scrolled upward. Scroll back to the bottom of the text field.
    textFieldScroller.animateTo(
      textFieldScroller.maxScrollExtent,
      duration: const Duration(milliseconds: 150),
      curve: Curves.decelerate,
    );

    return true;
  }

  if (ancestorScrollable == null) {
    // There is no ancestor scrollable to scroll. Fizzle.
    return false;
  }

  if (!ancestorScrollable.maxScrollExtent.isFinite) {
    // We want to scroll to the end of the ancestor scrollable, but it's infinitely long,
    // so we can't. Fizzle.
    return false;
  }

  // Scroll to the end of the ancestor scrollable.
  ancestorScrollable.animateTo(
    ancestorScrollable.maxScrollExtent,
    duration: const Duration(milliseconds: 150),
    curve: Curves.decelerate,
  );

  return true;
}

/// Scrolls up textfield by viewport height.
///
/// In absence of scrollable content within textfield, tries to scroll the ancestor
/// scrollable up by its viewport height.
///
/// Returns `true` if the scroll is performed, otherwise false.
bool _scrollPageUp({
  required SuperTextFieldContext textFieldContext,
}) {
  final TextFieldScroller textFieldScroller = textFieldContext.scroller;
  final ScrollPosition? ancestorScrollable =
      textFieldContext.textFieldBuildContext.findAncestorScrollableWithVerticalScroll?.position;

  if (textFieldScroller.maxScrollExtent == 0 && ancestorScrollable == null) {
    // No scrollable content within `SuperDesktopField` and ancestor scrollable
    // is absent, give other handlers opportunity to handle the key event.
    return false;
  }

  if (textFieldScroller.scrollOffset > 0) {
    // The text field has more content than can fit. Scroll up text field by viewport height.
    textFieldScroller.animateTo(
      max(
        textFieldScroller.scrollOffset - textFieldScroller.viewportDimension,
        textFieldScroller.minScrollExtent,
      ),
      duration: const Duration(milliseconds: 150),
      curve: Curves.decelerate,
    );
    return true;
  }

  if (ancestorScrollable == null) {
    // There is no ancestor scrollable to scroll. Fizzle.
    return false;
  }

  // Scroll up ancestor scrollable by viewport height.
  ancestorScrollable.animateTo(
    max(ancestorScrollable.pixels - ancestorScrollable.viewportDimension, ancestorScrollable.minScrollExtent),
    duration: const Duration(milliseconds: 150),
    curve: Curves.decelerate,
  );

  return true;
}

/// Scrolls down textfield by viewport height.
///
/// In absence of scrollable content within textfield, tries to scroll the ancestor
/// scrollable down by its viewport height.
///
/// Returns `true` if the scroll is performed, otherwise false.
bool _scrollPageDown({
  required SuperTextFieldContext textFieldContext,
}) {
  final TextFieldScroller textFieldScroller = textFieldContext.scroller;
  final ScrollPosition? ancestorScrollable =
      textFieldContext.textFieldBuildContext.findAncestorScrollableWithVerticalScroll?.position;

  if (textFieldScroller.maxScrollExtent == 0 && ancestorScrollable == null) {
    // No scrollable content within `SuperDesktopField` and ancestor scrollable
    // is absent, give other handlers opportunity to handle the key event.
    return false;
  }

  if (textFieldScroller.scrollOffset < textFieldScroller.maxScrollExtent) {
    // The text field has more content than can fit. Scroll down text field by viewport height.
    textFieldScroller.animateTo(
      min(
        textFieldScroller.scrollOffset + textFieldScroller.viewportDimension,
        textFieldScroller.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 150),
      curve: Curves.decelerate,
    );
    return true;
  }

  if (ancestorScrollable == null) {
    // There is no ancestor scrollable to scroll. Fizzle.
    return false;
  }

  // Scroll down ancestor scrollable by viewport height.
  ancestorScrollable.animateTo(
    min(ancestorScrollable.pixels + ancestorScrollable.viewportDimension, ancestorScrollable.maxScrollExtent),
    duration: const Duration(milliseconds: 150),
    curve: Curves.decelerate,
  );

  return true;
}
