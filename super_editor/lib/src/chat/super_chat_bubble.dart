import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_debug_paint.dart';
import 'package:super_editor/src/core/document_interaction.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/core/styles.dart';
import 'package:super_editor/src/default_editor/layout_single_column/_layout.dart';
import 'package:super_editor/src/default_editor/layout_single_column/_presenter.dart';
import 'package:super_editor/src/default_editor/layout_single_column/_styler_per_component.dart';
import 'package:super_editor/src/default_editor/layout_single_column/_styler_shylesheet.dart';
import 'package:super_editor/src/default_editor/layout_single_column/_styler_user_selection.dart';
import 'package:super_editor/src/default_editor/layout_single_column/super_editor_dry_layout.dart';
import 'package:super_editor/src/default_editor/text/custom_underlines.dart';
import 'package:super_editor/src/default_editor/unknown_component.dart';
import 'package:super_editor/src/infrastructure/content_layers.dart';
import 'package:super_editor/src/infrastructure/document_gestures_interaction_overrides.dart';
import 'package:super_editor/src/infrastructure/documents/document_scroller.dart';
import 'package:super_editor/src/infrastructure/documents/selection_leader_document_layer.dart';
import 'package:super_editor/src/infrastructure/flutter/build_context.dart';
import 'package:super_editor/src/infrastructure/platforms/mobile_documents.dart';
import 'package:super_editor/src/super_reader/read_only_document_android_touch_interactor.dart';
import 'package:super_editor/src/super_reader/read_only_document_ios_touch_interactor.dart';
import 'package:super_editor/src/super_reader/read_only_document_keyboard_interactor.dart';
import 'package:super_editor/src/super_reader/read_only_document_mouse_interactor.dart';
import 'package:super_editor/src/super_reader/reader_context.dart';
import 'package:super_editor/src/super_reader/super_reader.dart';

class SuperChatBubble extends StatefulWidget {
  SuperChatBubble({
    Key? key,
    this.focusNode,
    this.tapRegionGroupId,
    required this.editor,
    this.documentLayoutKey,
    this.selectionLayerLinks,
    Stylesheet? stylesheet,
    this.customStylePhases = const [],
    this.documentUnderlayBuilders = const [],
    this.documentOverlayBuilders = defaultSuperReaderDocumentOverlayBuilders,
    List<ComponentBuilder>? componentBuilders,
    List<ReadOnlyDocumentKeyboardAction>? keyboardActions,
    SelectionStyles? selectionStyle,
    this.gestureMode,
    this.contentTapDelegateFactory = superReaderLaunchLinkTapHandlerFactory,
    this.overlayController,
    this.androidHandleColor,
    this.androidToolbarBuilder,
    this.createOverlayControlsClipper,
    this.debugPaint = const DebugPaintConfig(),
  })  : stylesheet = stylesheet ?? readOnlyDefaultStylesheet,
        selectionStyles = selectionStyle ?? readOnlyDefaultSelectionStyle,
        keyboardActions = keyboardActions ?? readOnlyDefaultKeyboardActions,
        componentBuilders = componentBuilders != null
            ? [...componentBuilders, const UnknownComponentBuilder()]
            : [...readOnlyDefaultComponentBuilders, const UnknownComponentBuilder()],
        super(key: key);

  final FocusNode? focusNode;

  /// {@macro super_reader_tap_region_group_id}
  final String? tapRegionGroupId;

  /// The [Editor] whose [Document] displayed in this [SuperChatBubble].
  ///
  /// [SuperChatBubble] prevents users from interacting with, and altering the [Document].
  /// However, [SuperChatBubble] takes an [Editor] so that developers can alter the [Document]
  /// through code, such as contributing new content from an AI GPT.
  final Editor editor;

  /// [GlobalKey] that's bound to the [DocumentLayout] within
  /// this [SuperChatBubble].
  ///
  /// This key can be used to lookup visual components in the document
  /// layout within this [SuperChatBubble].
  final GlobalKey? documentLayoutKey;

  /// Leader links that connect leader widgets near the user's selection
  /// to carets, handles, and other things that want to follow the selection.
  ///
  /// These links are always created and used within [SuperChatBubble]. By providing
  /// an explicit [selectionLayerLinks], external widgets can also follow the
  /// user's selection.
  final SelectionLayerLinks? selectionLayerLinks;

  /// Style rules applied through the document presentation.
  final Stylesheet stylesheet;

  /// Styles applied to selected content.
  final SelectionStyles selectionStyles;

  /// Custom style phases that are added to the standard style phases.
  ///
  /// Documents are styled in a series of phases. A number of such
  /// phases are applied, automatically, e.g., text styles, per-component
  /// styles, and content selection styles.
  ///
  /// [customStylePhases] are added after the standard style phases. You can
  /// use custom style phases to apply styles that aren't supported with
  /// [stylesheet]s.
  ///
  /// You can also use them to apply styles to your custom [DocumentNode]
  /// types that aren't supported by [SuperChatBubble]. For example, [SuperChatBubble]
  /// doesn't include support for tables within documents, but you could
  /// implement a `TableNode` for that purpose. You may then want to make your
  /// table styleable. To accomplish this, you add a custom style phase that
  /// knows how to interpret and apply table styles for your visual table component.
  final List<SingleColumnLayoutStylePhase> customStylePhases;

  /// Layers that are displayed beneath the document layout, aligned
  /// with the location and size of the document layout.
  final List<SuperReaderDocumentLayerBuilder> documentUnderlayBuilders;

  /// Layers that are displayed on top of the document layout, aligned
  /// with the location and size of the document layout.
  final List<SuperReaderDocumentLayerBuilder> documentOverlayBuilders;

  /// Priority list of widget factories that create instances of
  /// each visual component displayed in the document layout, e.g.,
  /// paragraph component, image component, horizontal rule component, etc.
  final List<ComponentBuilder> componentBuilders;

  /// All actions that this editor takes in response to key
  /// events, e.g., text entry, newlines, character deletion,
  /// copy, paste, etc.
  ///
  /// These actions are only used when in [TextInputSource.keyboard]
  /// mode.
  final List<ReadOnlyDocumentKeyboardAction> keyboardActions;

  /// The [SuperChatBubble] gesture mode, e.g., mouse or touch.
  final DocumentGestureMode? gestureMode;

  /// Factory that creates a [ContentTapDelegate], which is given an
  /// opportunity to respond to taps on content before the editor, itself.
  ///
  /// A [ContentTapDelegate] might be used, for example, to launch a URL
  /// when a user taps on a link.
  final SuperReaderContentTapDelegateFactory? contentTapDelegateFactory;

  /// Shows, hides, and positions a floating toolbar and magnifier.
  final MagnifierAndToolbarController? overlayController;

  /// Color of the text selection drag handles on Android.
  final Color? androidHandleColor;

  /// Builder that creates a floating toolbar when running on Android.
  final WidgetBuilder? androidToolbarBuilder;

  /// Creates a clipper that applies to overlay controls, like drag
  /// handles, magnifiers, and popover toolbars, preventing the overlay
  /// controls from appearing outside the given clipping region.
  ///
  /// If no clipper factory method is provided, then the overlay controls
  /// will be allowed to appear anywhere in the overlay in which they sit
  /// (probably the entire screen).
  final CustomClipper<Rect> Function(BuildContext overlayContext)? createOverlayControlsClipper;

  /// Paints some extra visual ornamentation to help with
  /// debugging.
  final DebugPaintConfig debugPaint;

  @override
  State<SuperChatBubble> createState() => _SuperChatBubbleState();
}

class _SuperChatBubbleState extends State<SuperChatBubble> {
  // GlobalKey used to access the [DocumentLayoutState] to figure
  // out where in the document the user taps or drags.
  late GlobalKey _docLayoutKey;
  SingleColumnLayoutPresenter? _docLayoutPresenter;
  late SingleColumnStylesheetStyler _docStylesheetStyler;
  final _customUnderlineStyler = CustomUnderlineStyler();
  late SingleColumnLayoutCustomComponentStyler _docLayoutPerComponentBlockStyler;
  late SingleColumnLayoutSelectionStyler _docLayoutSelectionStyler;

  ContentTapDelegate? _contentTapDelegate;

  late SuperReaderContext _readerContext;

  @visibleForTesting
  FocusNode get focusNode => _focusNode;
  late FocusNode _focusNode;

  // Leader links that connect leader widgets near the user's selection
  // to carets, handles, and other things that want to follow the selection.
  late SelectionLayerLinks _selectionLinks;

  // GlobalKey for the iOS editor controls context so that the context data doesn't
  // continuously replace itself every time we rebuild. We want to retain the same
  // controls because they're shared throughout a number of disconnected widgets.
  final _iosControlsContextKey = GlobalKey();
  final _iosControlsController = SuperReaderIosControlsController();

  @override
  void initState() {
    super.initState();
    _focusNode = (widget.focusNode ?? FocusNode())..addListener(_onFocusChange);

    _selectionLinks = widget.selectionLayerLinks ?? SelectionLayerLinks();

    _docLayoutKey = widget.documentLayoutKey ?? GlobalKey();

    _createReaderContext();

    _createLayoutPresenter();
  }

  @override
  void didUpdateWidget(SuperChatBubble oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.selectionLayerLinks != oldWidget.selectionLayerLinks) {
      _selectionLinks = widget.selectionLayerLinks ?? SelectionLayerLinks();
    }

    if (widget.editor.document != oldWidget.editor.document) {
      _createReaderContext();
    }

    if (widget.stylesheet != oldWidget.stylesheet) {
      _createLayoutPresenter();
    }
  }

  @override
  void dispose() {
    _contentTapDelegate?.dispose();

    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) {
      // We are using our own private FocusNode. Dispose it.
      _focusNode.dispose();
    }

    super.dispose();
  }

  void _createReaderContext() {
    _readerContext = SuperReaderContext(
      editor: widget.editor,
      getDocumentLayout: () => _docLayoutKey.currentState as DocumentLayout,
      scroller: DocumentScroller(),
    );

    _contentTapDelegate?.dispose();
    _contentTapDelegate = widget.contentTapDelegateFactory?.call(_readerContext);
  }

  void _createLayoutPresenter() {
    if (_docLayoutPresenter != null) {
      _docLayoutPresenter!.dispose();
    }

    _docStylesheetStyler = SingleColumnStylesheetStyler(
      stylesheet: widget.stylesheet,
    );

    _docLayoutPerComponentBlockStyler = SingleColumnLayoutCustomComponentStyler();

    _docLayoutSelectionStyler = SingleColumnLayoutSelectionStyler(
      document: widget.editor.document,
      selection: widget.editor.composer.selectionNotifier,
      selectionStyles: widget.selectionStyles,
      selectedTextColorStrategy: widget.stylesheet.selectedTextColorStrategy,
    );

    _docLayoutPresenter = SingleColumnLayoutPresenter(
      document: widget.editor.document,
      componentBuilders: widget.componentBuilders,
      pipeline: [
        _docStylesheetStyler,
        _docLayoutPerComponentBlockStyler,
        _customUnderlineStyler,
        ...widget.customStylePhases,
        // Selection changes are very volatile. Put that phase last
        // to minimize view model recalculations.
        _docLayoutSelectionStyler,
      ],
    );

    _recomputeIfLayoutShouldShowCaret();
  }

  void _onFocusChange() {
    _recomputeIfLayoutShouldShowCaret();
  }

  void _recomputeIfLayoutShouldShowCaret() {
    _docLayoutSelectionStyler.shouldDocumentShowCaret =
        _focusNode.hasFocus && _gestureMode == DocumentGestureMode.mouse;
  }

  DocumentGestureMode get _gestureMode {
    if (widget.gestureMode != null) {
      return widget.gestureMode!;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return DocumentGestureMode.android;
      case TargetPlatform.iOS:
        return DocumentGestureMode.iOS;
      default:
        return DocumentGestureMode.mouse;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: SuperEditorDryLayout(
        superEditor: _buildGestureControlsScope(
          // We add a Builder immediately beneath the gesture controls scope so that
          // all descendant widgets built within SuperChatBubble can access that scope.
          child: Builder(builder: (controlsScopeContext) {
            return ReadOnlyDocumentKeyboardInteractor(
              // In a read-only document, we don't expect the software keyboard
              // to ever be open. Therefore, we only respond to key presses, such
              // as arrow keys.
              focusNode: _focusNode,
              readerContext: _readerContext,
              keyboardActions: widget.keyboardActions,
              child: _buildGestureInteractor(
                child: _buildPlatformSpecificViewportDecorations(
                  child: _buildDocumentLayout(),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  /// Builds an [InheritedWidget] that holds a shared context for editor controls,
  /// e.g., caret, handles, magnifier, toolbar.
  ///
  /// This context may be shared by multiple widgets within [SuperChatBubble]. It's also
  /// possible that a client app has wrapped [SuperChatBubble] with its own context
  /// [InheritedWidget], in which case the context is shared with widgets inside
  /// of [SuperChatBubble], and widgets outside of [SuperChatBubble].
  Widget _buildGestureControlsScope({
    required Widget child,
  }) {
    switch (_gestureMode) {
      // case DocumentGestureMode.mouse:
      // TODO: create context for mouse mode (#1533)
      // case DocumentGestureMode.android:
      // TODO: create context for Android (#1509)
      case DocumentGestureMode.iOS:
      default:
        return SuperReaderIosControlsScope(
          key: _iosControlsContextKey,
          controller: _iosControlsController,
          child: child,
        );
    }
  }

  /// Builds any widgets that a platform wants to wrap around the editor viewport,
  /// e.g., reader toolbar.
  Widget _buildPlatformSpecificViewportDecorations({
    required Widget child,
  }) {
    switch (_gestureMode) {
      case DocumentGestureMode.iOS:
        return SuperReaderIosToolbarOverlayManager(
          tapRegionGroupId: widget.tapRegionGroupId,
          defaultToolbarBuilder: (overlayContext, mobileToolbarKey, focalPoint) => defaultIosReaderToolbarBuilder(
            overlayContext,
            mobileToolbarKey,
            focalPoint,
            widget.editor.document,
            widget.editor.composer.selectionNotifier,
            SuperReaderIosControlsScope.rootOf(context),
          ),
          child: SuperReaderIosMagnifierOverlayManager(
            child: child,
          ),
        );
      case DocumentGestureMode.mouse:
      case DocumentGestureMode.android:
        return child;
    }
  }

  Widget _buildGestureInteractor({required Widget child}) {
    // Ensure that gesture object fill entire viewport when not being
    // in user specified scrollable.
    final fillViewport = context.findAncestorScrollableWithVerticalScroll == null;
    switch (_gestureMode) {
      case DocumentGestureMode.mouse:
        return ReadOnlyDocumentMouseInteractor(
          focusNode: _focusNode,
          readerContext: _readerContext,
          contentTapHandler: _contentTapDelegate,
          fillViewport: fillViewport,
          showDebugPaint: widget.debugPaint.gestures,
          child: child,
        );
      case DocumentGestureMode.android:
        return ReadOnlyAndroidDocumentTouchInteractor(
          focusNode: _focusNode,
          tapRegionGroupId: widget.tapRegionGroupId,
          readerContext: _readerContext,
          documentKey: _docLayoutKey,
          getDocumentLayout: () => _readerContext.documentLayout,
          selectionLinks: _selectionLinks,
          contentTapHandler: _contentTapDelegate,
          handleColor: widget.androidHandleColor ?? Theme.of(context).primaryColor,
          popoverToolbarBuilder: widget.androidToolbarBuilder ?? (_) => const SizedBox(),
          createOverlayControlsClipper: widget.createOverlayControlsClipper,
          showDebugPaint: widget.debugPaint.gestures,
          overlayController: widget.overlayController,
          fillViewport: fillViewport,
          child: child,
        );
      case DocumentGestureMode.iOS:
        return SuperReaderIosDocumentTouchInteractor(
          focusNode: _focusNode,
          readerContext: _readerContext,
          documentKey: _docLayoutKey,
          getDocumentLayout: () => _readerContext.documentLayout,
          contentTapHandler: _contentTapDelegate,
          fillViewport: fillViewport,
          showDebugPaint: widget.debugPaint.gestures,
          child: child,
        );
    }
  }

  Widget _buildDocumentLayout() {
    return ContentLayers(
      content: (onBuildScheduled) => SingleColumnDocumentLayout(
        key: widget.documentLayoutKey,
        presenter: _docLayoutPresenter!,
        componentBuilders: widget.componentBuilders,
        onBuildScheduled: onBuildScheduled,
        showDebugPaint: widget.debugPaint.layout,
      ),
      underlays: [
        // Add any underlays that were provided by the client.
        for (final underlayBuilder in widget.documentUnderlayBuilders) //
          (context) => underlayBuilder.build(context, _readerContext),
      ],
      overlays: [
        // Layer that positions and sizes leader widgets at the bounds
        // of the users selection so that carets, handles, toolbars, and
        // other things can follow the selection.
        (context) => _SelectionLeadersDocumentLayerBuilder(
              links: _selectionLinks,
            ).build(context, _readerContext),
        // Add any overlays that were provided by the client.
        for (final overlayBuilder in widget.documentOverlayBuilders) //
          (context) => overlayBuilder.build(context, _readerContext),
      ],
    );
  }
}

/// A [SuperReaderDocumentLayerBuilder] that builds a [SelectionLeadersDocumentLayer], which positions
/// leader widgets at the base and extent of the user's selection, so that other widgets
/// can position themselves relative to the user's selection.
class _SelectionLeadersDocumentLayerBuilder implements SuperReaderDocumentLayerBuilder {
  const _SelectionLeadersDocumentLayerBuilder({
    required this.links,
    // TODO(srawlins): `unused_element`, when reporting a parameter, is being
    // renamed to `unused_element_parameter`. For now, ignore each; when the SDK
    // constraint is >= 3.6.0, just ignore `unused_element_parameter`.
    // ignore: unused_element, unused_element_parameter
    this.showDebugLeaderBounds = false,
  });

  /// Collections of [LayerLink]s, which are given to leader widgets that are
  /// positioned at the selection bounds, and around the full selection.
  final SelectionLayerLinks links;

  /// Whether to paint colorful bounds around the leader widgets, for debugging purposes.
  final bool showDebugLeaderBounds;

  @override
  ContentLayerWidget build(BuildContext context, SuperReaderContext readerContext) {
    return SelectionLeadersDocumentLayer(
      document: readerContext.document,
      selection: readerContext.composer.selectionNotifier,
      links: links,
      showDebugLeaderBounds: showDebugLeaderBounds,
    );
  }
}
