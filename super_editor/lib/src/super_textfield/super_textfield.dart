import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/infrastructure/attributed_text_styles.dart';
import 'package:super_editor/src/infrastructure/ime_input_owner.dart';
import 'package:super_editor/src/super_textfield/android/android_textfield.dart';
import 'package:super_editor/src/super_textfield/desktop/desktop_textfield.dart';
import 'package:super_editor/src/super_textfield/infrastructure/attributed_text_editing_controller.dart';
import 'package:super_editor/src/super_textfield/infrastructure/hint_text.dart';
import 'package:super_editor/src/super_textfield/infrastructure/text_field_gestures_interaction_overrides.dart';
import 'package:super_editor/src/super_textfield/input_method_engine/_ime_text_editing_controller.dart';
import 'package:super_editor/src/super_textfield/ios/ios_textfield.dart';
import 'package:super_editor/src/infrastructure/text_input.dart';
import 'package:super_text_layout/super_text_layout.dart';

import 'styles.dart';

export 'android/android_textfield.dart';
export 'desktop/desktop_textfield.dart';
export 'infrastructure/attributed_text_editing_controller.dart';
export 'infrastructure/hint_text.dart';
export 'infrastructure/magnifier.dart';
export 'infrastructure/text_scrollview.dart';
export 'infrastructure/text_field_gestures_interaction_overrides.dart';
export 'infrastructure/text_field_tap_handlers.dart';
export 'input_method_engine/_ime_text_editing_controller.dart';
export 'ios/ios_textfield.dart';
export 'styles.dart';
export 'super_textfield_context.dart';

/// Custom text field implementations that offer greater control than traditional
/// Flutter text fields.
///
/// For example, the custom text fields in this package use [AttributedText]
/// instead of regular `String`s or `InlineSpan`s, which makes it easier to style
/// text and edit other text metadata.

export "super_text_field_keys.dart";

/// Text field that supports styled text.
///
/// [SuperTextField] adapts to the expectations of the current platform, or
/// conforms to a specified [configuration].
///
///  - desktop uses a blinking cursor and mouse gestures
///  - Android uses draggable handles in the Android style
///  - iOS uses draggable handles in the iOS style
///
/// [SuperTextField] is built on top of platform-specific text field implementations,
/// which may offer additional customization beyond that of [SuperTextField]:
///
///  - [SuperDesktopTextField], configured for a typical desktop experience.
///  - [SuperAndroidTextField], configured for a typical Android experience.
///  - [SuperIOSTextField], configured for a typical iOS experience.
class SuperTextField extends StatefulWidget {
  const SuperTextField({
    Key? key,
    this.focusNode,
    this.tapRegionGroupId,
    this.configuration,
    this.textController,
    this.textAlign,
    this.textStyleBuilder = defaultTextFieldStyleBuilder,
    this.inheritDefaultTextStyle = false,
    this.inlineWidgetBuilders = const [],
    this.hintBehavior = HintBehavior.displayHintUntilFocus,
    this.hintBuilder,
    this.controlsColor,
    this.caretStyle,
    this.blinkTimingMode = BlinkTimingMode.ticker,
    this.selectionColor,
    this.minLines,
    this.maxLines = 1,
    this.lineHeight,
    this.inputSource,
    this.keyboardHandlers,
    this.selectorHandlers,
    this.tapHandlers = const [],
    this.padding,
    this.textInputAction,
    this.imeConfiguration,
    this.showComposingUnderline,
  }) : super(key: key);

  final FocusNode? focusNode;

  /// {@template super_text_field_tap_region_group_id}
  /// An optional group ID for a tap region that surrounds this text field
  /// and also surrounds any related widgets, such as drag handles and a toolbar.
  /// {@endtemplate}
  final String? tapRegionGroupId;

  /// The platform-style configuration for this text field, or `null` to
  /// automatically configure for the current platform.
  final SuperTextFieldPlatformConfiguration? configuration;

  /// Controller that holds the current text and selection for this field,
  /// similar to a standard Flutter `TextEditingController`.
  final AttributedTextEditingController? textController;

  /// The alignment of the text in this text field.
  ///
  /// If `null`, the text alignment is determined by the text direction
  /// of the content.
  final TextAlign? textAlign;

  /// Text style factory that creates styles for the content in
  /// [textController] based on the attributions in that content.
  final AttributionStyleBuilder textStyleBuilder;

  /// {@template super_text_field_inline_widget_builders}
  /// A Chain of Responsibility that's used to build inline widgets.
  ///
  /// The first builder in the chain to return a non-null `Widget` will be
  /// used for a given inline placeholder.
  /// {@endtemplate}
  final InlineWidgetBuilderChain inlineWidgetBuilders;

  /// {@template super_text_field_inherit_default_text_style}
  /// Whether this text field should inherit the enclosing [DefaultTextStyle].
  ///
  /// If `true`, the text styles in [textStyleBuilder] will be merged with the
  /// enclosing [DefaultTextStyle] in the widget tree.
  ///
  /// Defaults to `false`.
  /// {@endtemplate}
  final bool inheritDefaultTextStyle;

  /// Policy for when the hint should be displayed.
  final HintBehavior hintBehavior;

  /// Builder that creates the hint widget, when a hint is displayed.
  ///
  /// To easily build a hint with styled text, see [StyledHintBuilder].
  final WidgetBuilder? hintBuilder;

  /// The color of the caret, drag handles, and other controls.
  ///
  /// The color in [caretStyle] overrides the [controlsColor].
  final Color? controlsColor;

  /// The visual representation of the caret.
  ///
  /// The color in [caretStyle] overrides the [controlsColor].
  final CaretStyle? caretStyle;

  /// The timing mechanism used to blink, e.g., `Ticker` or `Timer`.
  ///
  /// `Timer`s are not expected to work in tests.
  final BlinkTimingMode blinkTimingMode;

  /// The color of selection rectangles that appear around selected text.
  final Color? selectionColor;

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

  /// The height of a single line of text in this text field, used
  /// with [minLines] and [maxLines] to size the text field.
  ///
  /// An explicit [lineHeight] is required because rich text in this
  /// text field might have lines of varying height, which would
  /// result in a constantly changing text field height during scrolling.
  /// To avoid that situation, a single, explicit [lineHeight] is
  /// provided and used for all text field height calculations.
  final double? lineHeight;

  /// The [SuperTextField] input source, e.g., keyboard or Input Method Engine.
  ///
  /// Only used on desktop. On mobile platforms, only [TextInputSource.ime] is available.
  final TextInputSource? inputSource;

  /// Priority list of handlers that process all physical keyboard
  /// key presses, for text input, deletion, caret movement, etc.
  ///
  /// Only used on desktop.
  final List<TextFieldKeyboardHandler>? keyboardHandlers;

  /// Handlers for all Mac OS "selectors" reported by the IME.
  ///
  /// The IME reports selectors as unique `String`s, therefore selector handlers are
  /// defined as a mapping from selector names to handler functions.
  final Map<String, SuperTextFieldSelectorHandler>? selectorHandlers;

  /// {@template super_text_field_tap_handlers}
  /// Optional list of handlers that respond to taps on content, e.g., opening
  /// a link when the user taps on text with a link attribution.
  ///
  /// If a handler returns [TapHandlingInstruction.halt], no subsequent handlers
  /// nor the default tap behavior will be executed.
  /// {@endtemplate}
  final List<SuperTextFieldTapHandler> tapHandlers;

  /// Padding placed around the text content of this text field, but within the
  /// scrollable viewport.
  final EdgeInsets? padding;

  /// The main action for the virtual keyboard, e.g. [TextInputAction.done].
  ///
  /// This property is ignored when an [imeConfiguration] is provided.
  ///
  /// When `null`, and in single-line mode, the action will be [TextInputAction.done],
  /// and when in multi-line mode, the action will be  [TextInputAction.newline].
  ///
  /// Only used on mobile.
  @Deprecated('This will be removed in a future release. Use imeConfiguration instead')
  final TextInputAction? textInputAction;

  /// Preferences for how the platform IME should look and behave during editing.
  final TextInputConfiguration? imeConfiguration;

  /// Whether to show an underline beneath the text in the composing region, or `null`
  /// to let [SuperTextField] decide when to show the underline.
  final bool? showComposingUnderline;

  @override
  State<SuperTextField> createState() => SuperTextFieldState();
}

class SuperTextFieldState extends State<SuperTextField> implements ImeInputOwner {
  final _platformFieldKey = GlobalKey();
  late FocusNode _focusNode;
  late ImeAttributedTextEditingController _controller;

  @override
  void initState() {
    super.initState();

    _focusNode = widget.focusNode ?? FocusNode();

    _controller = widget.textController != null
        ? widget.textController is ImeAttributedTextEditingController
            ? (widget.textController as ImeAttributedTextEditingController)
            : ImeAttributedTextEditingController(controller: widget.textController, disposeClientController: false)
        : ImeAttributedTextEditingController();
  }

  @override
  void didUpdateWidget(SuperTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.focusNode != oldWidget.focusNode) {
      if (oldWidget.focusNode == null) {
        _focusNode.dispose();
      }
      _focusNode = widget.focusNode ?? FocusNode();
    }

    if (widget.textController != oldWidget.textController) {
      _controller = widget.textController != null
          ? widget.textController is ImeAttributedTextEditingController
              ? (widget.textController as ImeAttributedTextEditingController)
              : ImeAttributedTextEditingController(controller: widget.textController, disposeClientController: false)
          : ImeAttributedTextEditingController();
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }

    super.dispose();
  }

  @visibleForTesting
  bool get hasFocus => _focusNode.hasFocus;

  @visibleForTesting
  AttributedTextEditingController get controller => _controller;

  @visibleForTesting
  ProseTextLayout get textLayout => (_platformFieldKey.currentState as ProseTextBlock).textLayout;

  @visibleForTesting
  @override
  DeltaTextInputClient get imeClient {
    switch (_configuration) {
      case SuperTextFieldPlatformConfiguration.desktop:
        // ignore: invalid_use_of_visible_for_testing_member
        return (_platformFieldKey.currentState as SuperDesktopTextFieldState).imeClient;
      case SuperTextFieldPlatformConfiguration.android:
        return (_platformFieldKey.currentState as SuperAndroidTextFieldState).imeClient;
      case SuperTextFieldPlatformConfiguration.iOS:
        return (_platformFieldKey.currentState as SuperIOSTextFieldState).imeClient;
    }
  }

  bool get _isMultiline => (widget.minLines ?? 1) != 1 || widget.maxLines != 1;

  TextInputAction get _textInputAction =>
      widget.textInputAction ?? (_isMultiline ? TextInputAction.newline : TextInputAction.done);

  SuperTextFieldPlatformConfiguration get _configuration {
    if (widget.configuration != null) {
      return widget.configuration!;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return SuperTextFieldPlatformConfiguration.android;
      case TargetPlatform.iOS:
        return SuperTextFieldPlatformConfiguration.iOS;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return SuperTextFieldPlatformConfiguration.desktop;
    }
  }

  /// Returns the desired [TextInputSource] for this text field.
  ///
  /// If the [widget.inputSource] is configured, it is used. Otherwise,
  /// the [TextInputSource] is chosen based on the platform.
  TextInputSource get _inputSource {
    if (widget.inputSource != null) {
      return widget.inputSource!;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return TextInputSource.ime;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return TextInputSource.keyboard;
    }
  }

  /// Shortcuts that should be ignored on web.
  ///
  /// Without this we can't handle space and arrow keys inside [SuperTextField].
  ///
  /// For exemple, when [SuperTextField] is inside a [ScrollView],
  /// pressing [LogicalKeyboardKey.space] scrolls the scrollview.
  final Map<LogicalKeySet, Intent> _scrollShortcutOverrides = kIsWeb
      ? {
          LogicalKeySet(LogicalKeyboardKey.space): const DoNothingAndStopPropagationIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowUp): const DoNothingAndStopPropagationIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowDown): const DoNothingAndStopPropagationIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowLeft): const DoNothingAndStopPropagationIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowRight): const DoNothingAndStopPropagationIntent(),
        }
      : const <LogicalKeySet, Intent>{};

  @override
  Widget build(BuildContext context) {
    switch (_configuration) {
      case SuperTextFieldPlatformConfiguration.desktop:
        return SuperDesktopTextField(
          key: _platformFieldKey,
          focusNode: _focusNode,
          tapRegionGroupId: widget.tapRegionGroupId,
          textController: _controller,
          textAlign: widget.textAlign,
          textStyleBuilder: widget.textStyleBuilder,
          inlineWidgetBuilders: widget.inlineWidgetBuilders,
          inheritDefaultTextStyle: widget.inheritDefaultTextStyle,
          hintBehavior: widget.hintBehavior,
          hintBuilder: widget.hintBuilder,
          selectionHighlightStyle: SelectionHighlightStyle(
            color: widget.selectionColor ?? defaultSelectionColor,
          ),
          caretStyle: widget.caretStyle ??
              CaretStyle(
                color: widget.controlsColor ?? defaultDesktopCaretColor,
                width: 1,
                borderRadius: BorderRadius.zero,
              ),
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          keyboardHandlers: widget.keyboardHandlers,
          selectorHandlers: widget.selectorHandlers,
          tapHandlers: widget.tapHandlers,
          padding: widget.padding ?? EdgeInsets.zero,
          inputSource: _inputSource,
          textInputAction: _textInputAction,
          imeConfiguration: widget.imeConfiguration,
          showComposingUnderline: widget.showComposingUnderline ?? defaultTargetPlatform == TargetPlatform.macOS,
          blinkTimingMode: widget.blinkTimingMode,
        );
      case SuperTextFieldPlatformConfiguration.android:
        return Shortcuts(
          shortcuts: _scrollShortcutOverrides,
          child: SuperAndroidTextField(
            key: _platformFieldKey,
            focusNode: _focusNode,
            tapRegionGroupId: widget.tapRegionGroupId,
            tapHandlers: widget.tapHandlers,
            textController: _controller,
            textAlign: widget.textAlign,
            textStyleBuilder: widget.textStyleBuilder,
            inlineWidgetBuilders: widget.inlineWidgetBuilders,
            inheritDefaultTextStyle: widget.inheritDefaultTextStyle,
            hintBehavior: widget.hintBehavior,
            hintBuilder: widget.hintBuilder,
            caretStyle: widget.caretStyle ??
                CaretStyle(
                  color: widget.controlsColor ?? defaultAndroidControlsColor,
                ),
            selectionColor: widget.selectionColor ?? defaultSelectionColor,
            handlesColor: widget.controlsColor ?? defaultAndroidControlsColor,
            minLines: widget.minLines,
            maxLines: widget.maxLines,
            lineHeight: widget.lineHeight,
            textInputAction: _textInputAction,
            imeConfiguration: widget.imeConfiguration,
            showComposingUnderline: widget.showComposingUnderline ?? true,
            padding: widget.padding,
            blinkTimingMode: widget.blinkTimingMode,
          ),
        );
      case SuperTextFieldPlatformConfiguration.iOS:
        return Shortcuts(
          shortcuts: _scrollShortcutOverrides,
          child: SuperIOSTextField(
            key: _platformFieldKey,
            focusNode: _focusNode,
            tapRegionGroupId: widget.tapRegionGroupId,
            tapHandlers: widget.tapHandlers,
            textController: _controller,
            textAlign: widget.textAlign,
            textStyleBuilder: widget.textStyleBuilder,
            inlineWidgetBuilders: widget.inlineWidgetBuilders,
            inheritDefaultTextStyle: widget.inheritDefaultTextStyle,
            padding: widget.padding,
            hintBehavior: widget.hintBehavior,
            hintBuilder: widget.hintBuilder,
            caretStyle: widget.caretStyle ??
                CaretStyle(
                  color: widget.controlsColor ?? defaultIOSControlsColor,
                ),
            selectionColor: widget.selectionColor ?? defaultSelectionColor,
            handlesColor: widget.controlsColor ?? defaultIOSControlsColor,
            minLines: widget.minLines,
            maxLines: widget.maxLines,
            lineHeight: widget.lineHeight,
            textInputAction: _textInputAction,
            imeConfiguration: widget.imeConfiguration,
            showComposingUnderline: widget.showComposingUnderline ?? true,
            blinkTimingMode: widget.blinkTimingMode,
          ),
        );
    }
  }
}

/// Configures a [SuperTextField] for the given platform.
///
/// Desktop uses physical keyboard handlers, while mobile uses the IME.
///
/// Desktop uses a blinking caret, while mobile uses a draggable caret
/// and selection handles, styled per platform.
enum SuperTextFieldPlatformConfiguration {
  desktop,
  android,
  iOS,
}
