import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/src/default_editor/text_tools.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/attributed_text_styles.dart';
import 'package:super_editor/src/infrastructure/flutter/build_context.dart';
import 'package:super_editor/src/infrastructure/flutter/flutter_scheduler.dart';
import 'package:super_editor/src/infrastructure/flutter/text_input_configuration.dart';
import 'package:super_editor/src/infrastructure/ime_input_owner.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/toolbar.dart';
import 'package:super_editor/src/infrastructure/platforms/mobile_documents.dart';
import 'package:super_editor/src/infrastructure/signal_notifier.dart';
import 'package:super_editor/src/super_textfield/infrastructure/fill_width_if_constrained.dart';
import 'package:super_editor/src/super_textfield/infrastructure/hint_text.dart';
import 'package:super_editor/src/super_textfield/infrastructure/text_field_gestures_interaction_overrides.dart';
import 'package:super_editor/src/super_textfield/infrastructure/text_scrollview.dart';
import 'package:super_editor/src/super_textfield/input_method_engine/_ime_text_editing_controller.dart';
import 'package:super_editor/src/super_textfield/ios/editing_controls.dart';
import 'package:super_text_layout/super_text_layout.dart';

import 'package:super_editor/src/super_textfield/metrics.dart';
import 'package:super_editor/src/super_textfield/styles.dart';
import 'package:super_editor/src/super_textfield/ios/floating_cursor.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/ios_system_context_menu.dart';
import 'package:super_editor/src/super_textfield/ios/user_interaction.dart';

export '../infrastructure/magnifier.dart';
export 'caret.dart';
export 'editing_controls.dart';
export '../../infrastructure/platforms/ios/ios_system_context_menu.dart';
export 'user_interaction.dart';

final _log = iosTextFieldLog;

class SuperIOSTextField extends StatefulWidget {
  const SuperIOSTextField({
    Key? key,
    this.focusNode,
    this.tapRegionGroupId,
    this.tapHandlers = const [],
    this.textController,
    this.textStyleBuilder = defaultTextFieldStyleBuilder,
    this.inheritDefaultTextStyle = false,
    this.inlineWidgetBuilders = const [],
    this.textAlign = TextAlign.left,
    this.padding,
    this.hintBehavior = HintBehavior.displayHintUntilFocus,
    this.hintBuilder,
    this.minLines,
    this.maxLines = 1,
    this.lineHeight,
    required this.caretStyle,
    this.blinkTimingMode = BlinkTimingMode.ticker,
    required this.selectionColor,
    required this.handlesColor,
    this.textInputAction,
    this.imeConfiguration,
    this.showComposingUnderline = true,
    this.popoverToolbarBuilder = defaultIosPopoverToolbarBuilder,
    this.showDebugPaint = false,
  }) : super(key: key);

  /// [FocusNode] attached to this text field.
  final FocusNode? focusNode;

  /// {@macro super_text_field_tap_region_group_id}
  final String? tapRegionGroupId;

  /// {@macro super_text_field_tap_handlers}
  final List<SuperTextFieldTapHandler> tapHandlers;

  /// Controller that owns the text content and text selection for
  /// this text field.
  final ImeAttributedTextEditingController? textController;

  /// The alignment to use for text in this text field.
  ///
  /// If `null`, the text alignment is determined by the text direction
  /// of the content.
  final TextAlign? textAlign;

  /// Text style factory that creates styles for the content in
  /// [textController] based on the attributions in that content.
  final AttributionStyleBuilder textStyleBuilder;

  /// {@macro super_text_field_inline_widget_builders}
  final InlineWidgetBuilderChain inlineWidgetBuilders;

  /// {@macro super_text_field_inherit_default_text_style}
  final bool inheritDefaultTextStyle;

  /// Padding placed around the text content of this text field, but within the
  /// scrollable viewport.
  final EdgeInsets? padding;

  /// Policy for when the hint should be displayed.
  final HintBehavior hintBehavior;

  /// Builder that creates the hint widget, when a hint is displayed.
  ///
  /// To easily build a hint with styled text, see [StyledHintBuilder].
  final WidgetBuilder? hintBuilder;

  /// The visual representation of the caret.
  final CaretStyle caretStyle;

  /// The timing mechanism used to blink, e.g., `Ticker` or `Timer`.
  ///
  /// `Timer`s are not expected to work in tests.
  final BlinkTimingMode blinkTimingMode;

  /// Color of the selection rectangle for selected text.
  final Color selectionColor;

  /// Color of the selection handles.
  final Color handlesColor;

  /// The minimum height of this text field, represented as a
  /// line count.
  ///
  /// If [minLines] is non-null and greater than `1`, [lineHeight]
  /// must also be provided because there is no guarantee that all
  /// lines of text have the same height.
  ///
  /// See also:
  ///
  ///  * [maxLines]
  ///  * [lineHeight]
  final int? minLines;

  /// The maximum height of this text field, represented as a
  /// line count.
  ///
  /// If text exceeds the maximum line height, scrolling dynamics
  /// are added to accommodate the overflowing text.
  ///
  /// If [maxLines] is non-null and greater than `1`, [lineHeight]
  /// must also be provided because there is no guarantee that all
  /// lines of text have the same height.
  ///
  /// See also:
  ///
  ///  * [minLines]
  ///  * [lineHeight]
  final int? maxLines;

  /// The height of a single line of text in this text scroll view, used
  /// with [minLines] and [maxLines] to size the text field.
  ///
  /// If a [lineHeight] is provided, the text field viewport is sized as a
  /// multiple of that [lineHeight]. If no [lineHeight] is provided, the
  /// text field viewport is sized as a multiple of the line-height of the
  /// first line of text.
  final double? lineHeight;

  /// The type of action associated with the action button on the mobile
  /// keyboard.
  ///
  /// This property is ignored when an [imeConfiguration] is provided.
  @Deprecated('This will be removed in a future release. Use imeConfiguration instead')
  final TextInputAction? textInputAction;

  /// Preferences for how the platform IME should look and behave during editing.
  final TextInputConfiguration? imeConfiguration;

  /// Whether to show an underline beneath the text in the composing region.
  final bool showComposingUnderline;

  /// Builder that creates the popover toolbar widget that appears when text is selected.
  final IOSPopoverToolbarBuilder popoverToolbarBuilder;

  /// Whether to paint debug guides.
  final bool showDebugPaint;

  @override
  State createState() => SuperIOSTextFieldState();
}

class SuperIOSTextFieldState extends State<SuperIOSTextField>
    with TickerProviderStateMixin, WidgetsBindingObserver
    implements ProseTextBlock, ImeInputOwner {
  static const Duration _autoScrollAnimationDuration = Duration(milliseconds: 100);
  static const Curve _autoScrollAnimationCurve = Curves.fastOutSlowIn;

  final _textFieldKey = GlobalKey();
  final _textFieldLayerLink = LayerLink();
  final _textContentLayerLink = LayerLink();
  final _scrollKey = GlobalKey<IOSTextFieldTouchInteractorState>();
  final _textContentKey = GlobalKey<ProseTextState>();

  late FocusNode _focusNode;

  late ImeAttributedTextEditingController _textEditingController;

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

  late FloatingCursorController _floatingCursorController;

  final _toolbarLeaderLink = LeaderLink();
  final _magnifierLeaderLink = LeaderLink();
  late IOSEditingOverlayController _editingOverlayController;

  late TextScrollController _textScrollController;

  late MagnifierAndToolbarController _overlayController;

  /// Opens/closes the popover that displays the toolbar and magnifier, and
  // positions the invisible touch targets for base/extent dragging.
  final _popoverController = OverlayPortalController();

  late final BlinkController _caretBlinkController;

  /// Notifies the popover toolbar to rebuild itself.
  final _overlayControlsRebuildSignal = SignalNotifier();

  @override
  void initState() {
    super.initState();

    switch (widget.blinkTimingMode) {
      case BlinkTimingMode.ticker:
        _caretBlinkController = BlinkController(tickerProvider: this);
      case BlinkTimingMode.timer:
        _caretBlinkController = BlinkController.withTimer();
    }

    _focusNode = (widget.focusNode ?? FocusNode())..addListener(_updateSelectionAndImeConnectionOnFocusChange);

    _textEditingController = (widget.textController ?? ImeAttributedTextEditingController())
      ..addListener(_onTextOrSelectionChange)
      ..onIOSFloatingCursorChange = _onFloatingCursorChange
      ..onPerformActionPressed ??= _onPerformActionPressed;

    _textScrollController = TextScrollController(
      textController: _textEditingController,
      tickerProvider: this,
    )..addListener(_onTextScrollChange);

    _floatingCursorController = FloatingCursorController(
      textController: _textEditingController,
    );

    _overlayController = MagnifierAndToolbarController();

    _editingOverlayController = IOSEditingOverlayController(
      textController: _textEditingController,
      caretBlinkController: _caretBlinkController,
      toolbarFocalPoint: _toolbarLeaderLink,
      magnifierFocalPoint: _magnifierLeaderLink,
      overlayController: _overlayController,
    );

    _contentTextDirection = getParagraphDirection(_textEditingController.text.toPlainText());

    WidgetsBinding.instance.addObserver(this);

    if (_focusNode.hasFocus) {
      // The given FocusNode already has focus, we need to update selection and attach to IME.
      onNextFrame((_) => _updateSelectionAndImeConnectionOnFocusChange());
    }

    if (_textEditingController.selection.isValid) {
      // The text field was initialized with a selection - immediately ensure that the
      // extent is visible.
      onNextFrame((_) => _textScrollController.ensureExtentIsVisible());
    }
  }

  @override
  void didUpdateWidget(SuperIOSTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode.removeListener(_updateSelectionAndImeConnectionOnFocusChange);
      if (widget.focusNode != null) {
        _focusNode = widget.focusNode!;
      } else {
        _focusNode = FocusNode();
      }
      _focusNode.addListener(_updateSelectionAndImeConnectionOnFocusChange);
    }

    if (widget.textController != oldWidget.textController) {
      _textEditingController
        ..removeListener(_onTextOrSelectionChange)
        ..onIOSFloatingCursorChange = null;
      if (_textEditingController.onPerformActionPressed == _onPerformActionPressed) {
        _textEditingController.onPerformActionPressed = null;
      }

      if (widget.textController != null) {
        _textEditingController = widget.textController!;
      } else {
        _textEditingController = ImeAttributedTextEditingController();
      }

      _textEditingController
        ..addListener(_onTextOrSelectionChange)
        ..onIOSFloatingCursorChange = _onFloatingCursorChange
        ..onPerformActionPressed ??= _onPerformActionPressed;
    }

    if (widget.imeConfiguration != oldWidget.imeConfiguration &&
        widget.imeConfiguration != null &&
        (oldWidget.imeConfiguration == null || !widget.imeConfiguration!.isEquivalentTo(oldWidget.imeConfiguration!)) &&
        _textEditingController.isAttachedToIme) {
      _textEditingController.updateTextInputConfiguration(
        viewId: View.of(context).viewId,
        textInputAction: widget.imeConfiguration!.inputAction,
        textInputType: widget.imeConfiguration!.inputType,
        autocorrect: widget.imeConfiguration!.autocorrect,
        enableSuggestions: widget.imeConfiguration!.enableSuggestions,
        keyboardAppearance: widget.imeConfiguration!.keyboardAppearance,
        textCapitalization: widget.imeConfiguration!.textCapitalization,
      );
    }

    if (widget.showDebugPaint != oldWidget.showDebugPaint) {
      onNextFrame((_) => _rebuildHandles());
    }
  }

  @override
  void reassemble() {
    super.reassemble();

    // On Hot Reload we need to remove any visible overlay controls and then
    // bring them back a frame later to avoid having the controls attempt
    // to access the layout of the text. The text layout is not immediately
    // available upon Hot Reload. Accessing it results in an exception.
    _removeEditingOverlayControls();

    onNextFrame((_) => _showHandles());
  }

  @override
  void dispose() {
    _removeEditingOverlayControls();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      // Dispose after the current frame so that other widgets have
      // time to remove their listeners.
      _editingOverlayController.dispose();
      _overlayController.dispose();
    });

    _textEditingController
      ..removeListener(_onTextOrSelectionChange)
      ..onIOSFloatingCursorChange = null
      ..detachFromIme();
    if (widget.textController == null) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        // Dispose after the current frame so that other widgets have
        // time to remove their listeners.
        _textEditingController.dispose();
      });
    }

    _focusNode.removeListener(_updateSelectionAndImeConnectionOnFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }

    _textScrollController
      ..removeListener(_onTextScrollChange)
      ..dispose();

    _caretBlinkController.dispose();

    WidgetsBinding.instance.removeObserver(this);

    _overlayControlsRebuildSignal.dispose();

    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // The available screen dimensions may have changed, e.g., due to keyboard
    // appearance/disappearance.
    onNextFrame((_) {
      if (!_focusNode.hasFocus) {
        return;
      }

      _autoScrollToKeepTextFieldVisible();
    });
  }

  @visibleForTesting
  TextScrollController get scrollController => _textScrollController;

  @override
  ProseTextLayout get textLayout => _textContentKey.currentState!.textLayout;

  /// Calculates and returns the `Offset` from the top-left corner of this text field
  /// to the top-left corner of the [textLayout] within this text field.
  Offset get textLayoutOffsetInField {
    final fieldBox = context.findRenderObject() as RenderBox;
    final textLayoutBox = _textContentKey.currentContext!.findRenderObject() as RenderBox;
    return textLayoutBox.localToGlobal(Offset.zero, ancestor: fieldBox);
  }

  Rect? _getGlobalCaretRect() {
    if (!_textEditingController.selection.isValid || !_textEditingController.selection.isCollapsed) {
      // Either there's no selection, or the selection is expanded. In either case, there's no caret.
      return null;
    }

    final globalTextOffset =
        (_textContentKey.currentContext!.findRenderObject() as RenderBox).localToGlobal(Offset.zero);

    final caretPosition = _textEditingController.selection.extent;
    final caretOffset = textLayout.getOffsetForCaret(caretPosition) + globalTextOffset;
    final caretHeight = textLayout.getHeightForCaret(caretPosition)!;

    return Rect.fromLTWH(caretOffset.dx, caretOffset.dy, 1, caretHeight);
  }

  bool get _isMultiline => (widget.minLines ?? 1) != 1 || widget.maxLines != 1;

  @override
  DeltaTextInputClient get imeClient => _textEditingController;

  void _updateSelectionAndImeConnectionOnFocusChange() {
    // The focus change callback might be invoked in the build phase, usually when used inside
    // an OverlayPortal. If that's the case, defer the setState call until the end of the frame.
    WidgetsBinding.instance.runAsSoonAsPossible(() {
      if (!mounted) {
        return;
      }

      if (_focusNode.hasFocus) {
        if (!_textEditingController.isAttachedToIme) {
          _log.info('Attaching TextInputClient to TextInput');
          setState(() {
            if (!_textEditingController.selection.isValid) {
              _textEditingController.selection = TextSelection.collapsed(offset: _textEditingController.text.length);
            }

            if (widget.imeConfiguration != null) {
              _textEditingController.attachToImeWithConfig(widget.imeConfiguration!);
            } else {
              _textEditingController.attachToIme(
                viewId: View.of(context).viewId,
                textInputAction: widget.textInputAction ?? TextInputAction.done,
                textInputType: _isMultiline ? TextInputType.multiline : TextInputType.text,
              );
            }

            _autoScrollToKeepTextFieldVisible();
            _showHandles();
          });
        }
      } else {
        _log.info('Lost focus. Detaching TextInputClient from TextInput.');
        setState(() {
          _textEditingController.detachFromIme();
          _textEditingController.selection = const TextSelection.collapsed(offset: -1);
          _textEditingController.composingRegion = TextRange.empty;
          _removeEditingOverlayControls();
        });
      }
    });
  }

  void _onTextOrSelectionChange() {
    if (_textEditingController.selection.isCollapsed) {
      _editingOverlayController.hideToolbar();
    }

    setState(() {
      _contentTextDirection = getParagraphDirection(_textEditingController.text.toPlainText());
    });
  }

  void _onTextScrollChange() {
    if (_popoverController.isShowing) {
      _rebuildHandles();
    }
  }

  /// Displays [IOSEditingControls] in the [OverlayPortal], if not already
  /// displayed.
  void _showHandles() {
    if (!_popoverController.isShowing) {
      _popoverController.show();
    }
  }

  /// Rebuilds the [IOSEditingControls] in the [OverlayPortal], if
  /// they're currently displayed.
  void _rebuildHandles() {
    if (!_popoverController.isShowing) {
      _overlayControlsRebuildSignal.notifyListeners();
    }
  }

  /// Hides the [IOSEditingControls] in the [OverlayPortal], if they're
  /// currently displayed.
  void _removeEditingOverlayControls() {
    if (_popoverController.isShowing) {
      _popoverController.hide();
    }
  }

  void _onFloatingCursorChange(RawFloatingCursorPoint point) {
    _floatingCursorController.updateFloatingCursor(_textContentKey.currentState!.textLayout, point);
  }

  /// Handles actions from the IME
  void _onPerformActionPressed(TextInputAction action) {
    switch (action) {
      case TextInputAction.done:
        _focusNode.unfocus();
        break;
      case TextInputAction.next:
        _focusNode.nextFocus();
        break;
      case TextInputAction.previous:
        _focusNode.previousFocus();
        break;
      default:
        _log.warning("User pressed unhandled action button: $action");
    }
  }

  /// Scrolls the ancestor [Scrollable], if any, so [SuperTextField]
  /// is visible on the viewport when it's focused
  void _autoScrollToKeepTextFieldVisible() {
    // If we are not inside a [Scrollable] we don't autoscroll
    final ancestorScrollable = context.findAncestorScrollableWithVerticalScroll;
    if (ancestorScrollable == null) {
      return;
    }

    // Compute the text field offset that should be visible to the user
    final textFieldFocalPoint = widget.maxLines == null && _textEditingController.selection.isValid
        ? _textContentKey.currentState!.textLayout.getOffsetAtPosition(
            TextPosition(offset: _textEditingController.selection.extentOffset),
          )
        : Offset.zero;

    final lineHeight = _textContentKey.currentState!.textLayout.getLineHeightAtPosition(
      TextPosition(offset: _textEditingController.selection.extentOffset),
    );
    final fieldBox = context.findRenderObject() as RenderBox;

    // The area of the text field that should be revealed.
    // We add a small margin to leave some space between the text field and the keyboard.
    final textFieldFocalRect = Rect.fromLTWH(
      textFieldFocalPoint.dx,
      textFieldFocalPoint.dy,
      fieldBox.size.width,
      lineHeight + gapBetweenCaretAndKeyboard,
    );

    fieldBox.showOnScreen(
      rect: textFieldFocalRect,
      duration: _autoScrollAnimationDuration,
      curve: _autoScrollAnimationCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: widget.tapRegionGroupId,
      child: Focus(
        key: _textFieldKey,
        focusNode: _focusNode,
        child: CompositedTransformTarget(
          link: _textFieldLayerLink,
          child: IOSTextFieldTouchInteractor(
            focusNode: _focusNode,
            tapHandlers: widget.tapHandlers,
            selectableTextKey: _textContentKey,
            getGlobalCaretRect: _getGlobalCaretRect,
            textFieldLayerLink: _textFieldLayerLink,
            textController: _textEditingController,
            editingOverlayController: _editingOverlayController,
            textScrollController: _textScrollController,
            isMultiline: _isMultiline,
            handleColor: widget.handlesColor,
            showDebugPaint: widget.showDebugPaint,
            child: TextScrollView(
              key: _scrollKey,
              textScrollController: _textScrollController,
              textKey: _textContentKey,
              textEditingController: _textEditingController,
              textAlign: _textAlign,
              minLines: widget.minLines,
              maxLines: widget.maxLines,
              lineHeight: widget.lineHeight,
              padding: EdgeInsets.only(top: widget.padding?.top ?? 0, bottom: widget.padding?.bottom ?? 0),
              perLineAutoScrollDuration: const Duration(milliseconds: 100),
              showDebugPaint: widget.showDebugPaint,
              child: FillWidthIfConstrained(
                child: Padding(
                  padding: EdgeInsets.only(left: widget.padding?.left ?? 0, right: widget.padding?.right ?? 0),
                  child: CompositedTransformTarget(
                    link: _textContentLayerLink,
                    child: ListenableBuilder(
                      listenable: _textEditingController,
                      builder: (context, _) {
                        return _buildSelectableText();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectableText() {
    final textSpan = _textEditingController.text //
        .computeInlineSpan(
      context,
      widget.textStyleBuilder,
      widget.inlineWidgetBuilders,
      defaultTextStyle: widget.inheritDefaultTextStyle ? DefaultTextStyle.of(context).style : null,
    );

    CaretStyle caretStyle = widget.caretStyle;

    final caretColorOverride = _floatingCursorController.isShowingFloatingCursor ? Colors.grey : null;
    if (caretColorOverride != null) {
      caretStyle = caretStyle.copyWith(color: caretColorOverride);
    }

    return Directionality(
      textDirection: _textDirection,
      child: SuperText(
        key: _textContentKey,
        richText: textSpan,
        textAlign: _textAlign,
        textDirection: _textDirection,
        textScaler: MediaQuery.textScalerOf(context),
        layerBeneathBuilder: (context, textLayout) {
          final isTextEmpty = _textEditingController.text.isEmpty;
          final showHint = widget.hintBuilder != null &&
              ((isTextEmpty && widget.hintBehavior == HintBehavior.displayHintUntilTextEntered) ||
                  (isTextEmpty && !_focusNode.hasFocus && widget.hintBehavior == HintBehavior.displayHintUntilFocus));

          return Stack(
            clipBehavior: Clip.none,
            children: [
              if (_textEditingController.selection.isValid == true)
                // Selection highlight beneath the text.
                TextLayoutSelectionHighlight(
                  textLayout: textLayout,
                  style: SelectionHighlightStyle(
                    color: widget.selectionColor,
                  ),
                  selection: _textEditingController.selection,
                ),
              // Underline beneath the composing region.
              if (_textEditingController.composingRegion.isValid == true && widget.showComposingUnderline)
                TextUnderlineLayer(
                  textLayout: textLayout,
                  style: StraightUnderlineStyle(
                    color: widget.textStyleBuilder({}).color ?? //
                        (Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white),
                  ),
                  underlines: [
                    TextLayoutUnderline(
                      range: _textEditingController.composingRegion,
                    ),
                  ],
                ),
              if (showHint) //
                widget.hintBuilder!(context),
            ],
          );
        },
        layerAboveBuilder: (context, textLayout) {
          if (!_focusNode.hasFocus) {
            return const SizedBox();
          }

          return OverlayPortal(
            controller: _popoverController,
            overlayChildBuilder: _buildOverlayIosControls,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                TextLayoutCaret(
                  textLayout: textLayout,
                  style: widget.caretStyle,
                  position: _textEditingController.selection.isCollapsed //
                      ? _textEditingController.selection.extent
                      : null,
                  blinkController: _caretBlinkController,
                ),
                IOSFloatingCursor(
                  controller: _floatingCursorController,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverlayIosControls(BuildContext context) {
    return ListenableBuilder(
      listenable: _overlayControlsRebuildSignal,
      builder: (context, _) {
        return IOSEditingControls(
          editingController: _editingOverlayController,
          textScrollController: _textScrollController,
          textFieldLayerLink: _textFieldLayerLink,
          textFieldKey: _textFieldKey,
          textContentLayerLink: _textContentLayerLink,
          textContentKey: _textContentKey,
          tapRegionGroupId: widget.tapRegionGroupId,
          handleColor: widget.handlesColor,
          popoverToolbarBuilder: widget.popoverToolbarBuilder,
          showDebugPaint: widget.showDebugPaint,
        );
      },
    );
  }
}

/// Builder that returns a widget for an iOS-style popover editing toolbar.
typedef IOSPopoverToolbarBuilder = Widget Function(BuildContext, IOSEditingOverlayController);

/// An [IOSPopoverToolbarBuilder] that displays the iOS system popover toolbar, if the version of
/// iOS is recent enough, otherwise builds [defaultIosPopoverToolbarBuilder].
Widget iOSSystemPopoverTextFieldToolbarWithFallback(BuildContext context, IOSEditingOverlayController controller) {
  if (IOSSystemContextMenu.isSupported(context)) {
    return IOSSuperTextFieldSystemContextMenu(
      controller: controller,
    );
  }

  return defaultIosPopoverToolbarBuilder(context, controller);
}

/// Returns a widget for the default/standard iOS-style popover provided by Super Text Field.
Widget defaultIosPopoverToolbarBuilder(BuildContext context, IOSEditingOverlayController controller) {
  return IOSTextEditingFloatingToolbar(
    focalPoint: controller.toolbarFocalPoint,
    onCutPressed: () {
      final textController = controller.textController;
      final selection = textController.selection;
      if (selection.isCollapsed) {
        return;
      }

      final selectedText = selection.textInside(textController.text.toPlainText());

      textController.deleteSelectedText();

      Clipboard.setData(ClipboardData(text: selectedText));
    },
    onCopyPressed: () {
      final textController = controller.textController;
      final selection = textController.selection;
      final selectedText = selection.textInside(textController.text.toPlainText());

      Clipboard.setData(ClipboardData(text: selectedText));
    },
    onPastePressed: () async {
      final clipboardContent = await Clipboard.getData('text/plain');
      if (clipboardContent == null || clipboardContent.text == null) {
        return;
      }

      final textController = controller.textController;
      final selection = textController.selection;
      if (selection.isCollapsed) {
        textController.insertAtCaret(text: clipboardContent.text!);
      } else {
        textController.replaceSelectionWithUnstyledText(replacementText: clipboardContent.text!);
      }
    },
  );
}

class IOSSuperTextFieldSystemContextMenu extends StatefulWidget {
  const IOSSuperTextFieldSystemContextMenu({
    super.key,
    required this.controller,
  });

  final IOSEditingOverlayController controller;

  @override
  State<IOSSuperTextFieldSystemContextMenu> createState() => _IOSSuperTextFieldSystemContextMenuState();
}

class _IOSSuperTextFieldSystemContextMenuState extends State<IOSSuperTextFieldSystemContextMenu> {
  late final SystemContextMenuController _systemContextMenuController;

  @override
  void initState() {
    super.initState();
    _systemContextMenuController = SystemContextMenuController();
    widget.controller.addListener(_onControllerChanged);
    onNextFrame((_) {
      _positionSystemMenu();
    });
  }

  @override
  void didUpdateWidget(covariant IOSSuperTextFieldSystemContextMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
    onNextFrame((_) {
      _positionSystemMenu();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _systemContextMenuController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    onNextFrame((_) {
      _positionSystemMenu();
    });
  }

  void _positionSystemMenu() {
    // The size reported by the controller's toolbarFocalPoint is one frame behind. Query the information
    // overlayController instead.
    final topAnchor = widget.controller.overlayController.toolbarTopAnchor;
    final bottomAnchor = widget.controller.overlayController.toolbarTopAnchor;

    if (topAnchor == null || bottomAnchor == null) {
      // We don't expect the toolbar builder to be called without having the anchors
      // defined. But, since these properties are nullable, we account for that.
      return;
    }

    _systemContextMenuController.show(Rect.fromLTRB(topAnchor.dx, topAnchor.dy, bottomAnchor.dx, bottomAnchor.dy));
  }

  @override
  Widget build(BuildContext context) {
    assert(IOSSystemContextMenu.isSupported(context));
    return const SizedBox.shrink();
  }
}
