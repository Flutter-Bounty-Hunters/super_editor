import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_debug_paint.dart';
import 'package:super_editor/src/core/document_interaction.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/core/styles.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/default_editor/blockquote.dart';
import 'package:super_editor/src/default_editor/document_scrollable.dart';
import 'package:super_editor/src/default_editor/horizontal_rule.dart';
import 'package:super_editor/src/default_editor/image.dart';
import 'package:super_editor/src/default_editor/layout_single_column/_presenter.dart';
import 'package:super_editor/src/default_editor/layout_single_column/_styler_per_component.dart';
import 'package:super_editor/src/default_editor/layout_single_column/_styler_shylesheet.dart';
import 'package:super_editor/src/default_editor/layout_single_column/_styler_user_selection.dart';
import 'package:super_editor/src/default_editor/list_items.dart';
import 'package:super_editor/src/default_editor/paragraph.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/default_editor/text/custom_underlines.dart';
import 'package:super_editor/src/default_editor/unknown_component.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/content_layers.dart';
import 'package:super_editor/src/infrastructure/document_gestures_interaction_overrides.dart';
import 'package:super_editor/src/infrastructure/documents/document_scaffold.dart';
import 'package:super_editor/src/infrastructure/documents/document_scroller.dart';
import 'package:super_editor/src/infrastructure/documents/document_selection.dart';
import 'package:super_editor/src/infrastructure/documents/selection_leader_document_layer.dart';
import 'package:super_editor/src/infrastructure/flutter/build_context.dart';
import 'package:super_editor/src/infrastructure/links.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/ios_document_controls.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/toolbar.dart';
import 'package:super_editor/src/infrastructure/platforms/mobile_documents.dart';
import 'package:super_editor/src/infrastructure/platforms/platform.dart';
import 'package:super_editor/src/infrastructure/text_input.dart';
import 'package:super_editor/src/super_reader/read_only_document_android_touch_interactor.dart';
import 'package:super_editor/src/super_reader/read_only_document_ios_touch_interactor.dart';
import 'package:super_editor/src/super_reader/read_only_document_keyboard_interactor.dart';
import 'package:super_editor/src/super_reader/read_only_document_mouse_interactor.dart';
import 'package:super_editor/src/super_reader/reader_context.dart';
import 'package:super_editor/src/super_reader/tasks.dart';

class SuperReader extends StatefulWidget {
  SuperReader({
    Key? key,
    this.focusNode,
    this.autofocus = false,
    this.tapRegionGroupId,
    required this.editor,
    this.documentLayoutKey,
    this.selectionLayerLinks,
    this.scrollController,
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
    this.iOSHandleColor,
    this.iOSToolbarBuilder,
    this.createOverlayControlsClipper,
    this.debugPaint = const DebugPaintConfig(),
    this.shrinkWrap = false,
  })  : stylesheet = stylesheet ?? readOnlyDefaultStylesheet,
        selectionStyles = selectionStyle ?? readOnlyDefaultSelectionStyle,
        keyboardActions = keyboardActions ?? readOnlyDefaultKeyboardActions,
        componentBuilders = componentBuilders != null
            ? [...componentBuilders, const UnknownComponentBuilder()]
            : [...readOnlyDefaultComponentBuilders, const UnknownComponentBuilder()],
        super(key: key);

  final FocusNode? focusNode;

  /// Whether or not the [SuperReader] should autofocus.
  final bool autofocus;

  /// {@template super_reader_tap_region_group_id}
  /// A group ID for a tap region that surrounds the reader
  /// and also surrounds any related widgets, such as drag handles and a toolbar.
  ///
  /// When the reader is inside a [TapRegion], tapping at a drag handle causes
  /// [TapRegion.onTapOutside] to be called. To prevent that, provide a
  /// [tapRegionGroupId] with the same value as the ancestor [TapRegion] groupId.
  /// {@endtemplate}
  final String? tapRegionGroupId;

  /// The [Editor] whose [Document] displayed in this [SuperReader].
  ///
  /// [SuperReader] prevents users from interacting with, and altering the [Document].
  /// However, [SuperReader] takes an [Editor] so that developers can alter the [Document]
  /// through code, such as contributing new content from an AI GPT.
  final Editor editor;

  /// [GlobalKey] that's bound to the [DocumentLayout] within
  /// this [SuperReader].
  ///
  /// This key can be used to lookup visual components in the document
  /// layout within this [SuperReader].
  final GlobalKey? documentLayoutKey;

  /// Leader links that connect leader widgets near the user's selection
  /// to carets, handles, and other things that want to follow the selection.
  ///
  /// These links are always created and used within [SuperEditor]. By providing
  /// an explicit [selectionLayerLinks], external widgets can also follow the
  /// user's selection.
  final SelectionLayerLinks? selectionLayerLinks;

  /// The [ScrollController] that governs this [SuperReader]'s scroll
  /// offset.
  ///
  /// [scrollController] is not used if this [SuperReader] has an ancestor
  /// [Scrollable].
  final ScrollController? scrollController;

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
  /// types that aren't supported by [SuperReader]. For example, [SuperReader]
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

  /// The [SuperReader] gesture mode, e.g., mouse or touch.
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

  /// Color of the text selection drag handles on iOS.
  @Deprecated("To configure handle color, surround SuperEditor with an IosEditorControlsScope, instead")
  final Color? iOSHandleColor;

  /// Builder that creates a floating toolbar when running on iOS.
  @Deprecated("To configure a toolbar builder, surround SuperEditor with an IosEditorControlsScope, instead")
  final WidgetBuilder? iOSToolbarBuilder;

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

  /// Whether the scroll view used by the reader should shrink-wrap its contents.
  /// Only used when reader is not inside an scrollable.
  final bool shrinkWrap;

  @override
  State<SuperReader> createState() => SuperReaderState();
}

class SuperReaderState extends State<SuperReader> {
  @visibleForTesting
  Document get document => widget.editor.document;

  @visibleForTesting
  DocumentSelection? get selection => widget.editor.composer.selection;

  // GlobalKey used to access the [DocumentLayoutState] to figure
  // out where in the document the user taps or drags.
  late GlobalKey _docLayoutKey;
  final _documentLayoutLink = LayerLink();
  SingleColumnLayoutPresenter? _docLayoutPresenter;
  late SingleColumnStylesheetStyler _docStylesheetStyler;
  final _customUnderlineStyler = CustomUnderlineStyler();
  late SingleColumnLayoutCustomComponentStyler _docLayoutPerComponentBlockStyler;
  late SingleColumnLayoutSelectionStyler _docLayoutSelectionStyler;

  ContentTapDelegate? _contentTapDelegate;

  late DocumentScroller _scroller;
  late ScrollController _scrollController;
  late AutoScrollController _autoScrollController;

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

    _scroller = DocumentScroller();
    _scrollController = widget.scrollController ?? ScrollController();
    _autoScrollController = AutoScrollController();

    _selectionLinks = widget.selectionLayerLinks ?? SelectionLayerLinks();

    _docLayoutKey = widget.documentLayoutKey ?? GlobalKey();

    _createReaderContext();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_docLayoutPresenter == null) {
      _createLayoutPresenter();
    } else if (widget.stylesheet.inheritDefaultTextStyle) {
      // The default text style might have changed. Update it in the stylesheet styler.
      final defaultTextStyle = DefaultTextStyle.of(context).style;
      _docStylesheetStyler.defaultTextStyle = defaultTextStyle;
    }
  }

  @override
  void didUpdateWidget(SuperReader oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.scrollController != oldWidget.scrollController) {
      _scrollController = widget.scrollController ?? ScrollController();
    }

    if (widget.selectionLayerLinks != oldWidget.selectionLayerLinks) {
      _selectionLinks = widget.selectionLayerLinks ?? SelectionLayerLinks();
    }

    if (widget.editor.document != oldWidget.editor.document || widget.scrollController != oldWidget.scrollController) {
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
      scroller: _scroller,
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
      defaultTextStyle: DefaultTextStyle.of(context).style,
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
    return _buildGestureControlsScope(
      // We add a Builder immediately beneath the gesture controls scope so that
      // all descendant widgets built within SuperReader can access that scope.
      child: Builder(builder: (controlsScopeContext) {
        return ReadOnlyDocumentKeyboardInteractor(
          // In a read-only document, we don't expect the software keyboard
          // to ever be open. Therefore, we only respond to key presses, such
          // as arrow keys.
          focusNode: _focusNode,
          readerContext: _readerContext,
          keyboardActions: widget.keyboardActions,
          autofocus: widget.autofocus,
          child: DocumentScaffold(
            viewportDecorationBuilder: _buildPlatformSpecificViewportDecorations,
            documentLayoutLink: _documentLayoutLink,
            documentLayoutKey: _docLayoutKey,
            gestureBuilder: _buildGestureInteractor,
            scrollController: _scrollController,
            autoScrollController: _autoScrollController,
            scroller: _scroller,
            presenter: _docLayoutPresenter!,
            componentBuilders: widget.componentBuilders,
            shrinkWrap: widget.shrinkWrap,
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
            debugPaint: widget.debugPaint,
          ),
        );
      }),
    );
  }

  /// Builds an [InheritedWidget] that holds a shared context for editor controls,
  /// e.g., caret, handles, magnifier, toolbar.
  ///
  /// This context may be shared by multiple widgets within [SuperEditor]. It's also
  /// possible that a client app has wrapped [SuperEditor] with its own context
  /// [InheritedWidget], in which case the context is shared with widgets inside
  /// of [SuperEditor], and widgets outside of [SuperEditor].
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
  Widget _buildPlatformSpecificViewportDecorations(
    BuildContext context, {
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
            document,
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

  Widget _buildGestureInteractor(BuildContext context, {required Widget child}) {
    // Ensure that gesture object fill entire viewport when not being
    // in user specified scrollable.
    final fillViewport = context.findAncestorScrollableWithVerticalScroll == null;
    switch (_gestureMode) {
      case DocumentGestureMode.mouse:
        return ReadOnlyDocumentMouseInteractor(
          focusNode: _focusNode,
          readerContext: _readerContext,
          contentTapHandler: _contentTapDelegate,
          autoScroller: _autoScrollController,
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
          scrollController: _scrollController,
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
          scrollController: _scrollController,
          fillViewport: fillViewport,
          showDebugPaint: widget.debugPaint.gestures,
          child: child,
        );
    }
  }
}

/// Builds a standard reader-style iOS floating toolbar.
Widget defaultIosReaderToolbarBuilder(
  BuildContext context,
  Key floatingToolbarKey,
  LeaderLink focalPoint,
  Document document,
  ValueListenable<DocumentSelection?> selection,
  SuperReaderIosControlsController editorControlsController,
) {
  if (CurrentPlatform.isWeb) {
    // On web, we defer to the browser's internal overlay controls for mobile.
    return const SizedBox();
  }

  return DefaultIosReaderToolbar(
    floatingToolbarKey: floatingToolbarKey,
    focalPoint: focalPoint,
    document: document,
    selection: selection,
    editorControlsController: editorControlsController,
  );
}

/// An iOS floating toolbar, which includes standard buttons for a reader use-case.
class DefaultIosReaderToolbar extends StatelessWidget {
  const DefaultIosReaderToolbar({
    super.key,
    this.floatingToolbarKey,
    required this.focalPoint,
    required this.document,
    required this.selection,
    required this.editorControlsController,
  });

  final Key? floatingToolbarKey;
  final LeaderLink focalPoint;
  final Document document;
  final ValueListenable<DocumentSelection?> selection;
  final SuperReaderIosControlsController editorControlsController;

  @override
  Widget build(BuildContext context) {
    return IOSTextEditingFloatingToolbar(
      floatingToolbarKey: floatingToolbarKey,
      focalPoint: focalPoint,
      onCopyPressed: _copy,
    );
  }

  /// Copies selected content to the OS clipboard.
  void _copy() {
    editorControlsController.hideToolbar();

    if (selection.value == null) {
      return;
    }

    final textToCopy = extractTextFromSelection(
      document: document,
      documentSelection: selection.value!,
    );
    // TODO: figure out a general approach for asynchronous behaviors that
    //       need to be carried out in response to user input.
    Clipboard.setData(ClipboardData(text: textToCopy));
  }
}

/// Default list of document overlays that are displayed on top of the document
/// layout in a [SuperReader].
const defaultSuperReaderDocumentOverlayBuilders = [
  // Adds a Leader around the document selection at a focal point for the
  // iOS floating toolbar.
  SuperReaderIosToolbarFocalPointDocumentLayerBuilder(),
  // Displays caret and drag handles, specifically for iOS.
  SuperReaderIosHandlesDocumentLayerBuilder(),
];

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

/// A [SuperReaderDocumentLayerBuilder] that builds a [IosToolbarFocalPointDocumentLayer], which
/// positions a `Leader` widget around the document selection, as a focal point for an
/// iOS floating toolbar.
class SuperReaderIosToolbarFocalPointDocumentLayerBuilder implements SuperReaderDocumentLayerBuilder {
  const SuperReaderIosToolbarFocalPointDocumentLayerBuilder({
    // TODO(srawlins): `unused_element`, when reporting a parameter, is being
    // renamed to `unused_element_parameter`. For now, ignore each; when the SDK
    // constraint is >= 3.6.0, just ignore `unused_element_parameter`.
    // ignore: unused_element, unused_element_parameter
    this.showDebugLeaderBounds = false,
  });

  /// Whether to paint colorful bounds around the leader widget.
  final bool showDebugLeaderBounds;

  @override
  ContentLayerWidget build(BuildContext context, SuperReaderContext readerContext) {
    return IosToolbarFocalPointDocumentLayer(
      document: readerContext.document,
      selection: readerContext.composer.selectionNotifier,
      toolbarFocalPointLink: SuperReaderIosControlsScope.rootOf(context).toolbarFocalPoint,
      showDebugLeaderBounds: showDebugLeaderBounds,
    );
  }
}

/// Builds widgets that are displayed at the same position and size as
/// the document layout within a [SuperReader].
abstract class SuperReaderDocumentLayerBuilder {
  ContentLayerWidget build(BuildContext context, SuperReaderContext documentContext);
}

typedef SuperReaderContentTapDelegateFactory = ContentTapDelegate Function(SuperReaderContext editContext);

SuperReaderLaunchLinkTapHandler superReaderLaunchLinkTapHandlerFactory(SuperReaderContext readerContext) =>
    SuperReaderLaunchLinkTapHandler(readerContext.document);

/// A [ContentTapDelegate] that opens links when the user taps text with
/// a [LinkAttribution].
class SuperReaderLaunchLinkTapHandler extends ContentTapDelegate {
  SuperReaderLaunchLinkTapHandler(this.document);

  final Document document;

  @override
  MouseCursor? mouseCursorForContentHover(DocumentPosition hoverPosition) {
    final link = _getLinkAtPosition(hoverPosition);
    return link != null ? SystemMouseCursors.click : null;
  }

  @override
  TapHandlingInstruction onTap(DocumentTapDetails details) {
    final tapPosition = details.documentLayout.getDocumentPositionNearestToOffset(details.layoutOffset);
    if (tapPosition == null) {
      return TapHandlingInstruction.continueHandling;
    }

    final link = _getLinkAtPosition(tapPosition);
    if (link != null) {
      // The user tapped on a link. Launch it.
      UrlLauncher.instance.launchUrl(link);
      return TapHandlingInstruction.halt;
    } else {
      // The user didn't tap on a link.
      return TapHandlingInstruction.continueHandling;
    }
  }

  Uri? _getLinkAtPosition(DocumentPosition position) {
    final nodePosition = position.nodePosition;
    if (nodePosition is! TextNodePosition) {
      return null;
    }

    final textNode = document.getNodeById(position.nodeId);
    if (textNode is! TextNode) {
      readerGesturesLog
          .shout("Received a report of a tap on a TextNodePosition, but the node with that ID is a: $textNode");
      return null;
    }

    final tappedAttributions = textNode.text.getAllAttributionsAt(nodePosition.offset);
    for (final tappedAttribution in tappedAttributions) {
      if (tappedAttribution is LinkAttribution) {
        return tappedAttribution.launchableUri;
      }
    }

    return null;
  }
}

/// Creates visual components for the standard [SuperReader].
///
/// These builders are in priority order. The first builder
/// to return a non-null component is used.
final readOnlyDefaultComponentBuilders = <ComponentBuilder>[
  const BlockquoteComponentBuilder(),
  const ParagraphComponentBuilder(),
  const ListItemComponentBuilder(),
  const ImageComponentBuilder(),
  const HorizontalRuleComponentBuilder(),
  const ReadOnlyTaskComponentBuilder(),
];

/// Stylesheet applied to all [SuperReader]s by default.
final readOnlyDefaultStylesheet = Stylesheet(
  rules: [
    StyleRule(
      BlockSelector.all,
      (doc, docNode) {
        return {
          Styles.maxWidth: 640.0,
          Styles.padding: const CascadingPadding.symmetric(horizontal: 24),
          Styles.textStyle: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            height: 1.4,
          ),
        };
      },
    ),
    StyleRule(
      const BlockSelector("header1"),
      (doc, docNode) {
        return {
          Styles.padding: const CascadingPadding.only(top: 40),
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
          Styles.padding: const CascadingPadding.only(top: 32),
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
          Styles.padding: const CascadingPadding.only(top: 28),
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
          Styles.padding: const CascadingPadding.only(top: 24),
        };
      },
    ),
    StyleRule(
      const BlockSelector("paragraph").after("header1"),
      (doc, docNode) {
        return {
          Styles.padding: const CascadingPadding.only(top: 0),
        };
      },
    ),
    StyleRule(
      const BlockSelector("paragraph").after("header2"),
      (doc, docNode) {
        return {
          Styles.padding: const CascadingPadding.only(top: 0),
        };
      },
    ),
    StyleRule(
      const BlockSelector("paragraph").after("header3"),
      (doc, docNode) {
        return {
          Styles.padding: const CascadingPadding.only(top: 0),
        };
      },
    ),
    StyleRule(
      const BlockSelector("listItem"),
      (doc, docNode) {
        return {
          Styles.padding: const CascadingPadding.only(top: 24),
        };
      },
    ),
    StyleRule(
      const BlockSelector("blockquote"),
      (doc, docNode) {
        return {
          Styles.textStyle: const TextStyle(
            color: Colors.grey,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            height: 1.4,
          ),
        };
      },
    ),
    StyleRule(
      BlockSelector.all.last(),
      (doc, docNode) {
        return {
          Styles.padding: const CascadingPadding.only(bottom: 96),
        };
      },
    ),
  ],
  inlineTextStyler: readOnlyDefaultInlineTextStyler,
  inlineWidgetBuilders: defaultInlineWidgetBuilderChain,
);

TextStyle readOnlyDefaultInlineTextStyler(Set<Attribution> attributions, TextStyle existingStyle) {
  return existingStyle.merge(readOnlyDefaultStyleBuilder(attributions));
}

/// Creates [TextStyles] for the standard [SuperReader].
TextStyle readOnlyDefaultStyleBuilder(Set<Attribution> attributions) {
  TextStyle newStyle = const TextStyle();

  for (final attribution in attributions) {
    if (attribution == boldAttribution) {
      newStyle = newStyle.copyWith(
        fontWeight: FontWeight.bold,
      );
    } else if (attribution == italicsAttribution) {
      newStyle = newStyle.copyWith(
        fontStyle: FontStyle.italic,
      );
    } else if (attribution == underlineAttribution) {
      newStyle = newStyle.copyWith(
        decoration: newStyle.decoration == null
            ? TextDecoration.underline
            : TextDecoration.combine([TextDecoration.underline, newStyle.decoration!]),
      );
    } else if (attribution == strikethroughAttribution) {
      newStyle = newStyle.copyWith(
        decoration: newStyle.decoration == null
            ? TextDecoration.lineThrough
            : TextDecoration.combine([TextDecoration.lineThrough, newStyle.decoration!]),
      );
    } else if (attribution is ColorAttribution) {
      newStyle = newStyle.copyWith(
        color: attribution.color,
      );
    } else if (attribution is LinkAttribution) {
      newStyle = newStyle.copyWith(
        color: Colors.lightBlue,
        decoration: TextDecoration.underline,
      );
    }
  }
  return newStyle;
}

/// Default visual styles related to content selection.
const readOnlyDefaultSelectionStyle = SelectionStyles(
  selectionColor: Color(0xFFACCEF7),
);
