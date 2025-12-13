import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/src/chat/super_message_android_overlays.dart';
import 'package:super_editor/src/chat/super_message_android_touch_interactor.dart';
import 'package:super_editor/src/chat/super_message_ios_overlays.dart';
import 'package:super_editor/src/chat/super_message_ios_touch_interactor.dart';
import 'package:super_editor/src/chat/super_message_keyboard_interactor.dart';
import 'package:super_editor/src/chat/super_message_mouse_interactor.dart';
import 'package:super_editor/src/core/document_composer.dart';
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
import 'package:super_editor/src/default_editor/super_editor.dart'
    show defaultComponentBuilders, defaultInlineTextStyler;
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/default_editor/text/custom_underlines.dart';
import 'package:super_editor/src/infrastructure/content_layers.dart';
import 'package:super_editor/src/infrastructure/content_layers_for_boxes.dart';
import 'package:super_editor/src/infrastructure/document_context.dart';
import 'package:super_editor/src/infrastructure/document_gestures_interaction_overrides.dart';
import 'package:super_editor/src/infrastructure/documents/selection_leader_document_layer.dart';
import 'package:super_editor/src/infrastructure/flutter/empty_box.dart';
import 'package:super_editor/src/infrastructure/keyboard.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/ios_document_controls.dart';
import 'package:super_editor/src/infrastructure/platforms/mobile_documents.dart';
import 'package:super_editor/src/super_reader/read_only_document_keyboard_interactor.dart';
import 'package:super_editor/src/super_reader/super_reader.dart';

/// A chat message widget.
///
/// This widget displays an entire rich-text document, laid out as a column.
/// This widget can be used to display simple, short, plain-text chat messages,
/// as well as multi-paragraph, rich-text messages with interspersed images,
/// list items, etc.
///
/// This message pulls its content from the given [editor]'s [Document]. An
/// [editor] is required whether this widget is used to display a read-only messages,
/// or an editable message. This is because, especially in the case of AI, a
/// message that is read-only for the user may be editable by some other actor.
class SuperMessage extends StatefulWidget {
  SuperMessage({
    super.key,
    this.focusNode,
    this.tapRegionGroupId,
    required this.editor,
    SuperMessageStyles? styles,
    this.customStylePhases = const [],
    this.documentUnderlayBuilders = const [],
    this.documentOverlayBuilders = defaultSuperMessageDocumentOverlayBuilders,
    this.selectionLayerLinks,
    this.contentTapDelegateFactory,
    this.gestureMode,
    this.overlayController,
    List<DocumentKeyboardAction>? keyboardActions,
    this.createOverlayControlsClipper,
    this.componentBuilders = defaultComponentBuilders,
    this.debugPaint = const DebugPaintConfig(),
  })  : styles = styles ?? SuperMessageStyles.lightAndDark(),
        keyboardActions = keyboardActions ?? superMessageDefaultKeyboardActions;

  final FocusNode? focusNode;

  /// {@template super_message_tap_region_group_id}
  /// A group ID for a tap region that surrounds the message and also surrounds any
  /// related widgets, such as drag handles and a toolbar.
  ///
  /// When the message is inside a [TapRegion], tapping at a drag handle causes
  /// [TapRegion.onTapOutside] to be called. To prevent that, provide a
  /// [tapRegionGroupId] with the same value as the ancestor [TapRegion] groupId.
  /// {@endtemplate}
  final String? tapRegionGroupId;

  final Editor editor;

  final SuperMessageStyles styles;

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
  /// types that aren't supported by [SuperMessage]. For example, [SuperMessage]
  /// doesn't include support for tables within documents, but you could
  /// implement a `TableNode` for that purpose. You may then want to make your
  /// table styleable. To accomplish this, you add a custom style phase that
  /// knows how to interpret and apply table styles for your visual table component.
  final List<SingleColumnLayoutStylePhase> customStylePhases;

  /// Layers that are displayed beneath the document layout, aligned
  /// with the location and size of the document layout.
  final List<SuperMessageDocumentLayerBuilder> documentUnderlayBuilders;

  /// Layers that are displayed on top of the document layout, aligned
  /// with the location and size of the document layout.
  final List<SuperMessageDocumentLayerBuilder> documentOverlayBuilders;

  /// Leader links that connect leader widgets near the user's selection
  /// to carets, handles, and other things that want to follow the selection.
  ///
  /// These links are always created and used within [SuperEditor]. By providing
  /// an explicit [selectionLayerLinks], external widgets can also follow the
  /// user's selection.
  final SelectionLayerLinks? selectionLayerLinks;

  /// Factory that creates a [ContentTapDelegate], which is given an
  /// opportunity to respond to taps on content before the editor, itself.
  ///
  /// A [ContentTapDelegate] might be used, for example, to launch a URL
  /// when a user taps on a link.
  final SuperMessageContentTapDelegateFactory? contentTapDelegateFactory;

  /// The gesture mode, e.g., mouse or touch.
  final DocumentGestureMode? gestureMode;

  /// Shows, hides, and positions a floating toolbar and magnifier.
  final MagnifierAndToolbarController? overlayController;

  /// All actions that this editor takes in response to key
  /// events, e.g., text entry, newlines, character deletion,
  /// copy, paste, etc.
  ///
  /// These actions are only used when in [TextInputSource.keyboard]
  /// mode.
  final List<DocumentKeyboardAction> keyboardActions;

  /// Creates a clipper that applies to overlay controls, like drag
  /// handles, magnifiers, and popover toolbars, preventing the overlay
  /// controls from appearing outside the given clipping region.
  ///
  /// If no clipper factory method is provided, then the overlay controls
  /// will be allowed to appear anywhere in the overlay in which they sit
  /// (probably the entire screen).
  final CustomClipper<Rect> Function(BuildContext overlayContext)? createOverlayControlsClipper;

  final List<ComponentBuilder> componentBuilders;

  final DebugPaintConfig debugPaint;

  @override
  State<SuperMessage> createState() => _SuperMessageState();
}

class _SuperMessageState extends State<SuperMessage> {
  late FocusNode _focusNode;

  late DocumentContext _messageContext;

  final _documentLayoutKey = GlobalKey(debugLabel: 'SuperMessage-DocumentLayout');

  Brightness? _mostRecentPresenterBrightness;
  SingleColumnLayoutPresenter? _presenter;
  late SingleColumnStylesheetStyler _docStylesheetStyler;
  final _customUnderlineStyler = CustomUnderlineStyler();
  late SingleColumnLayoutCustomComponentStyler _docLayoutPerComponentBlockStyler;
  late SingleColumnLayoutSelectionStyler _docLayoutSelectionStyler;

  ContentTapDelegate? _contentTapDelegate;

  // Leader links that connect leader widgets near the user's selection
  // to carets, handles, and other things that want to follow the selection.
  late SelectionLayerLinks _selectionLinks;

  final _iOSControlsController = SuperMessageIosControlsController();
  final _androidControlsController = SuperMessageAndroidControlsController();

  @override
  void initState() {
    super.initState();

    _focusNode = widget.focusNode ?? FocusNode(debugLabel: 'SuperMessage');
    _focusNode.addListener(_onFocusChange);

    _selectionLinks = widget.selectionLayerLinks ?? SelectionLayerLinks();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final brightness = MediaQuery.platformBrightnessOf(context);
    if (brightness != _mostRecentPresenterBrightness) {
      _mostRecentPresenterBrightness = brightness;
      _initializePresenter();
    }
  }

  @override
  void didUpdateWidget(covariant SuperMessage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode.removeListener(_onFocusChange);
      if (oldWidget.focusNode == null) {
        _focusNode.dispose();
      }

      _focusNode = widget.focusNode ?? FocusNode(debugLabel: 'SuperMessage');
      _focusNode.addListener(_onFocusChange);
    }

    if (widget.editor != oldWidget.editor ||
        widget.styles != oldWidget.styles ||
        !const DeepCollectionEquality().equals(widget.customStylePhases, oldWidget.customStylePhases) ||
        !const DeepCollectionEquality().equals(widget.componentBuilders, oldWidget.componentBuilders)) {
      _initializePresenter();
    }

    if (widget.selectionLayerLinks != oldWidget.selectionLayerLinks) {
      _selectionLinks = widget.selectionLayerLinks ?? SelectionLayerLinks();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }

    _contentTapDelegate?.dispose();

    _iOSControlsController.dispose();

    super.dispose();
  }

  void _initializePresenter() {
    if (_presenter != null) {
      _presenter!.dispose();
    }

    _docStylesheetStyler = SingleColumnStylesheetStyler(
      stylesheet: _mostRecentPresenterBrightness == Brightness.dark
          ? widget.styles.darkStylesheet
          : widget.styles.lightStylesheet,
    );

    _docLayoutPerComponentBlockStyler = SingleColumnLayoutCustomComponentStyler();

    _docLayoutSelectionStyler = SingleColumnLayoutSelectionStyler(
      document: widget.editor.document,
      selection: widget.editor.composer.selectionNotifier,
      selectionStyles: _mostRecentPresenterBrightness == Brightness.dark
          ? widget.styles.darkSelectionStyles
          : widget.styles.lightSelectionStyles,
      selectedTextColorStrategy: _mostRecentPresenterBrightness == Brightness.dark
          ? widget.styles.darkStylesheet.selectedTextColorStrategy
          : widget.styles.lightStylesheet.selectedTextColorStrategy,
    );

    _presenter = SingleColumnLayoutPresenter(
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

    _messageContext = DocumentContext(
      editor: widget.editor,
      getDocumentLayout: () => _documentLayoutKey.currentState as DocumentLayout,
    );

    _contentTapDelegate?.dispose();
    _contentTapDelegate = widget.contentTapDelegateFactory?.call(_messageContext);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && widget.editor.composer.selection != null) {
      // This message doesn't have focus. Clear the selection.
      widget.editor.execute([
        const ClearSelectionRequest(),
      ]);
    }
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
    return SuperMessageKeyboardInteractor(
      // Note: This widget adds a `Focus` widget, internally.
      focusNode: _focusNode,
      messageContext: _messageContext,
      keyboardActions: widget.keyboardActions,
      child: Builder(builder: (context) {
        return _buildGestureInteractor(
          context,
          child: IntrinsicWidth(
            child: BoxContentLayers(
              content: (onBuildScheduled) => SingleColumnDocumentLayout(
                key: _documentLayoutKey,
                presenter: _presenter!,
                componentBuilders: widget.componentBuilders,
                onBuildScheduled: onBuildScheduled,
                wrapWithSliverAdapter: false,
                showDebugPaint: widget.debugPaint.layout,
              ),
              underlays: [
                // Add any underlays that were provided by the client.
                for (final underlayBuilder in widget.documentUnderlayBuilders) //
                  (context) => underlayBuilder.build(context, _messageContext),
              ],
              overlays: [
                // Layer that positions and sizes leader widgets at the bounds
                // of the users selection so that carets, handles, toolbars, and
                // other things can follow the selection.
                (context) => _SelectionLeadersDocumentLayerBuilder(
                      links: _selectionLinks,
                    ).build(context, _messageContext),
                // Add any overlays that were provided by the client.
                for (final overlayBuilder in widget.documentOverlayBuilders) //
                  (context) => overlayBuilder.build(context, _messageContext),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildGestureInteractor(BuildContext context, {required Widget child}) {
    switch (_gestureMode) {
      case DocumentGestureMode.mouse:
        return SuperMessageMouseInteractor(
          focusNode: _focusNode,
          messageContext: _messageContext,
          contentTapHandler: _contentTapDelegate,
          showDebugPaint: widget.debugPaint.gestures,
          child: child,
        );
      case DocumentGestureMode.android:
        return SuperMessageAndroidControlsScope(
          controller: _androidControlsController,
          child: Builder(
            // ^ Builder to provide widgets below with access to controller.
            builder: (context) {
              return SuperMessageAndroidTouchInteractor(
                focusNode: _focusNode,
                editor: widget.editor,
                getDocumentLayout: () => _messageContext.documentLayout,
                showDebugPaint: widget.debugPaint.gestures,
                child: SuperMessageAndroidControlsOverlayManager(
                  editor: widget.editor,
                  getDocumentLayout: () => _messageContext.documentLayout,
                  defaultToolbarBuilder: (overlayContext, mobileToolbarKey, focalPoint) =>
                      DefaultAndroidSuperMessageToolbar(
                    floatingToolbarKey: mobileToolbarKey,
                    editor: widget.editor,
                    messageControlsController: SuperMessageAndroidControlsScope.rootOf(context),
                    focalPoint: focalPoint,
                  ),
                  child: child,
                ),
              );
            },
          ),
        );
      case DocumentGestureMode.iOS:
        return SuperMessageIosControlsScope(
          controller: _iOSControlsController,
          child: Builder(
              // ^ Builder to provide widgets below with access to controller.
              builder: (context) {
            return SuperMessageIosTouchInteractor(
              focusNode: _focusNode,
              messageContext: _messageContext,
              documentKey: _documentLayoutKey,
              getDocumentLayout: () => _messageContext.documentLayout,
              contentTapHandler: _contentTapDelegate,
              showDebugPaint: widget.debugPaint.gestures,
              child: SuperMessageIosToolbarOverlayManager(
                tapRegionGroupId: widget.tapRegionGroupId,
                defaultToolbarBuilder: (overlayContext, mobileToolbarKey, focalPoint) => DefaultIOSSuperMessageToolbar(
                  floatingToolbarKey: mobileToolbarKey,
                  editor: widget.editor,
                  messageControlsController: SuperMessageIosControlsScope.rootOf(context),
                  focalPoint: focalPoint,
                ),
                child: SuperMessageIosMagnifierOverlayManager(
                  child: child,
                ),
              ),
            );
          }),
        );
    }
  }
}

final defaultLightChatStylesheet = Stylesheet(
  rules: [
    StyleRule(
      BlockSelector.all,
      (doc, docNode) {
        return {
          Styles.padding: const CascadingPadding.symmetric(horizontal: 12),
          Styles.textStyle: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            height: 1.1,
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
          Styles.padding: const CascadingPadding.only(top: 6, bottom: 6),
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
          ),
        };
      },
    ),
  ],
  inlineTextStyler: defaultInlineTextStyler,
  inlineWidgetBuilders: defaultInlineWidgetBuilderChain,
);

const defaultLightChatSelectionStyles = SelectionStyles(
  selectionColor: Color(0xFFACCEF7),
);

final defaultDarkChatStylesheet = defaultLightChatStylesheet.copyWith(
  addRulesAfter: [
    StyleRule(
      BlockSelector.all,
      (doc, docNode) {
        return {
          Styles.textStyle: const TextStyle(
            color: Colors.white,
          ),
        };
      },
    ),
    StyleRule(
      const BlockSelector("blockquote"),
      (doc, docNode) {
        return {
          Styles.textStyle: const TextStyle(
            color: Colors.grey,
          ),
        };
      },
    ),
  ],
  inlineTextStyler: defaultInlineTextStyler,
  inlineWidgetBuilders: defaultInlineWidgetBuilderChain,
);

const defaultDarkChatSelectionStyles = SelectionStyles(
  selectionColor: Color(0xFFACCEF7),
);

/// Default list of document overlays that are displayed on top of the document
/// layout in a [SuperMessage].
const defaultSuperMessageDocumentOverlayBuilders = <SuperMessageDocumentLayerBuilder>[
  // Adds a Leader around the document selection at a focal point for the iOS floating toolbar.
  SuperMessageIosToolbarFocalPointDocumentLayerBuilder(),
  // Displays drag handles, specifically for iOS.
  SuperMessageIosHandlesDocumentLayerBuilder(),

  // Adds a Leader around the document selection at a focal point for the Android floating toolbar.
  SuperMessageAndroidToolbarFocalPointDocumentLayerBuilder(),
  // Displays drag handles, specifically for Android.
  SuperMessageAndroidHandlesDocumentLayerBuilder(),
];

/// Styles that apply to a given [SuperMessage], including a document stylesheet,
/// and selection styles, for both light and dark modes.
class SuperMessageStyles {
  SuperMessageStyles({
    required Stylesheet stylesheet,
    required SelectionStyles selectionStyles,
  })  : lightStylesheet = stylesheet,
        lightSelectionStyles = selectionStyles,
        darkStylesheet = stylesheet,
        darkSelectionStyles = selectionStyles;

  SuperMessageStyles.lightAndDark({
    Stylesheet? lightStylesheet,
    SelectionStyles? lightSelectionStyles,
    Stylesheet? darkStylesheet,
    SelectionStyles? darkSelectionStyles,
  })  : lightStylesheet = lightStylesheet ?? defaultLightChatStylesheet,
        lightSelectionStyles = lightSelectionStyles ?? defaultLightChatSelectionStyles,
        darkStylesheet = darkStylesheet ?? defaultDarkChatStylesheet,
        darkSelectionStyles = darkSelectionStyles ?? defaultDarkChatSelectionStyles;

  late final Stylesheet lightStylesheet;
  late final SelectionStyles lightSelectionStyles;

  late final Stylesheet darkStylesheet;
  late final SelectionStyles darkSelectionStyles;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SuperMessageStyles &&
          runtimeType == other.runtimeType &&
          lightStylesheet == other.lightStylesheet &&
          lightSelectionStyles == other.lightSelectionStyles &&
          darkStylesheet == other.darkStylesheet &&
          darkSelectionStyles == other.darkSelectionStyles;

  @override
  int get hashCode =>
      lightStylesheet.hashCode ^ lightSelectionStyles.hashCode ^ darkStylesheet.hashCode ^ darkSelectionStyles.hashCode;
}

/// A [SuperMessageDocumentLayerBuilder] that builds a [SelectionLeadersDocumentLayer], which positions
/// leader widgets at the base and extent of the user's selection, so that other widgets
/// can position themselves relative to the user's selection.
class _SelectionLeadersDocumentLayerBuilder implements SuperMessageDocumentLayerBuilder {
  const _SelectionLeadersDocumentLayerBuilder({
    required this.links,
    // ignore: unused_element_parameter
    this.showDebugLeaderBounds = false,
  });

  /// Collections of [LayerLink]s, which are given to leader widgets that are
  /// positioned at the selection bounds, and around the full selection.
  final SelectionLayerLinks links;

  /// Whether to paint colorful bounds around the leader widgets, for debugging purposes.
  final bool showDebugLeaderBounds;

  @override
  ContentLayerWidget build(BuildContext context, DocumentContext messageContext) {
    return SelectionLeadersDocumentLayer(
      document: messageContext.editor.document,
      selection: messageContext.editor.composer.selectionNotifier,
      links: links,
      showDebugLeaderBounds: showDebugLeaderBounds,
    );
  }
}

/// Builds widgets that are displayed at the same position and size as
/// the document layout within a [SuperMessage].
abstract class SuperMessageDocumentLayerBuilder {
  ContentLayerWidget build(BuildContext context, DocumentContext messageContext);
}

/// A [SuperMessageDocumentLayerBuilder] that builds a [IosToolbarFocalPointDocumentLayer], which
/// positions a `Leader` widget around the document selection, as a focal point for an
/// iOS floating toolbar.
class SuperMessageIosToolbarFocalPointDocumentLayerBuilder implements SuperMessageDocumentLayerBuilder {
  const SuperMessageIosToolbarFocalPointDocumentLayerBuilder({
    this.showDebugLeaderBounds = false,
  });

  /// Whether to paint colorful bounds around the leader widget.
  final bool showDebugLeaderBounds;

  @override
  ContentLayerWidget build(BuildContext context, DocumentContext messageContext) {
    if (defaultTargetPlatform != TargetPlatform.iOS || SuperMessageIosControlsScope.maybeNearestOf(context) == null) {
      // There's no controls scope. This probably means SuperEditor is configured with
      // a non-iOS gesture mode. Build nothing.
      return const ContentLayerProxyWidget(child: EmptyBox());
    }

    return IosToolbarFocalPointDocumentLayer(
      document: messageContext.editor.document,
      selection: messageContext.editor.composer.selectionNotifier,
      toolbarFocalPointLink: SuperMessageIosControlsScope.rootOf(context).toolbarFocalPoint,
      showDebugLeaderBounds: showDebugLeaderBounds,
    );
  }
}

typedef SuperMessageContentTapDelegateFactory = ContentTapDelegate Function(DocumentContext messageContext);

ContentTapDelegate superMessageLinkTapHandlerFactory(DocumentContext messageContext) =>
    SuperReaderLaunchLinkTapHandler(messageContext.document);

/// Keyboard actions for the standard [SuperReader].
final superMessageDefaultKeyboardActions = <DocumentKeyboardAction>[
  removeCollapsedSelectionWhenShiftIsReleased,
  expandSelectionWithLeftArrow,
  expandSelectionWithRightArrow,
  expandSelectionWithUpArrow,
  expandSelectionWithDownArrow,
  expandSelectionToLineStartWithHomeOnWindowsAndLinux,
  expandSelectionToLineEndWithEndOnWindowsAndLinux,
  expandSelectionToLineStartWithCtrlAOnWindowsAndLinux,
  expandSelectionToLineEndWithCtrlEOnWindowsAndLinux,
  selectAllWhenCmdAIsPressedOnMac,
  selectAllWhenCtlAIsPressedOnWindowsAndLinux,
  copyWhenCmdCIsPressedOnMac,
  copyWhenCtlCIsPressedOnWindowsAndLinux,
];

/// Executes this action, if the action wants to run, and returns
/// a desired [ExecutionInstruction] to either continue or halt
/// execution of actions.
///
/// It is possible that an action makes changes and then returns
/// [ExecutionInstruction.continueExecution] to continue execution.
///
/// It is possible that an action does nothing and then returns
/// [ExecutionInstruction.haltExecution] to prevent further execution.
typedef SuperMessageKeyboardAction = ExecutionInstruction Function({
  required DocumentContext documentContext,
  required KeyEvent keyEvent,
});
