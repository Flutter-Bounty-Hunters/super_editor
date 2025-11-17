import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_debug_paint.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/core/styles.dart';
import 'package:super_editor/src/default_editor/layout_single_column/_layout.dart';
import 'package:super_editor/src/default_editor/layout_single_column/_presenter.dart';
import 'package:super_editor/src/default_editor/layout_single_column/_styler_per_component.dart';
import 'package:super_editor/src/default_editor/layout_single_column/_styler_shylesheet.dart';
import 'package:super_editor/src/default_editor/layout_single_column/_styler_user_selection.dart';
import 'package:super_editor/src/default_editor/super_editor.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/default_editor/text/custom_underlines.dart';
import 'package:super_editor/src/infrastructure/content_layers.dart';
import 'package:super_editor/src/infrastructure/content_layers_for_boxes.dart';
import 'package:super_editor/src/infrastructure/documents/selection_leader_document_layer.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/ios_document_controls.dart';
import 'package:super_editor/src/super_reader/read_only_document_ios_touch_interactor.dart';

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
    required this.editor,
    Stylesheet? stylesheet,
    SelectionStyles? selectionStyles,
    this.customStylePhases = const [],
    this.documentUnderlayBuilders = const [],
    this.documentOverlayBuilders = defaultSuperMessageDocumentOverlayBuilders,
    this.selectionLayerLinks,
    this.componentBuilders = defaultComponentBuilders,
    this.debugPaint = const DebugPaintConfig(),
  })  : stylesheet = stylesheet ?? defaultChatStylesheet,
        selectionStyles = selectionStyles ?? defaultChatSelectionStyles;

  final FocusNode? focusNode;

  final Editor editor;

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

  final List<ComponentBuilder> componentBuilders;

  final DebugPaintConfig debugPaint;

  @override
  State<SuperMessage> createState() => _SuperMessageState();
}

class _SuperMessageState extends State<SuperMessage> {
  final _documentLayoutKey = GlobalKey(debugLabel: 'SuperMessage-DocumentLayout');

  SingleColumnLayoutPresenter? _presenter;
  late SingleColumnStylesheetStyler _docStylesheetStyler;
  final _customUnderlineStyler = CustomUnderlineStyler();
  late SingleColumnLayoutCustomComponentStyler _docLayoutPerComponentBlockStyler;
  late SingleColumnLayoutSelectionStyler _docLayoutSelectionStyler;

  late SuperMessageContext _messageContext;

  // Leader links that connect leader widgets near the user's selection
  // to carets, handles, and other things that want to follow the selection.
  late SelectionLayerLinks _selectionLinks;

  final _iOSControlsController = SuperReaderIosControlsController();

  @override
  void initState() {
    super.initState();

    _initializePresenter();

    _selectionLinks = widget.selectionLayerLinks ?? SelectionLayerLinks();
  }

  @override
  void didUpdateWidget(covariant SuperMessage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.editor != oldWidget.editor ||
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
    _iOSControlsController.dispose();

    super.dispose();
  }

  void _initializePresenter() {
    if (_presenter != null) {
      _presenter!.dispose();
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

    _messageContext = SuperMessageContext(widget.editor, () => _documentLayoutKey.currentState as DocumentLayout);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      child: SuperReaderIosControlsScope(
        controller: _iOSControlsController,
        child: Builder(builder: (context) {
          return BoxContentLayers(
            content: (onBuildScheduled) => IntrinsicWidth(
              child: SingleColumnDocumentLayout(
                key: _documentLayoutKey,
                presenter: _presenter!,
                componentBuilders: widget.componentBuilders,
                onBuildScheduled: onBuildScheduled,
                wrapWithSliverAdapter: false,
                showDebugPaint: widget.debugPaint.layout,
              ),
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
          );
        }),
      ),
    );
  }
}

class SuperMessageContext {
  const SuperMessageContext(this.editor, this._getDocumentLayout);

  final Editor editor;

  /// The document layout that is a visual representation of the document.
  ///
  /// This member might change over time.
  DocumentLayout get documentLayout => _getDocumentLayout();
  final DocumentLayout Function() _getDocumentLayout;
}

// FIXME: De-dup this with SuperReader
/// A [SuperMessageDocumentLayerBuilder] that builds a [SelectionLeadersDocumentLayer], which positions
/// leader widgets at the base and extent of the user's selection, so that other widgets
/// can position themselves relative to the user's selection.
class _SelectionLeadersDocumentLayerBuilder implements SuperMessageDocumentLayerBuilder {
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
  ContentLayerWidget build(BuildContext context, SuperMessageContext messageContext) {
    print("Running build() on _SelectionLeadersDocumentLayerBuilder");
    return SelectionLeadersDocumentLayer(
      document: messageContext.editor.document,
      selection: messageContext.editor.composer.selectionNotifier,
      links: links,
      showDebugLeaderBounds: showDebugLeaderBounds,
    );
  }
}

/// Default list of document overlays that are displayed on top of the document
/// layout in a [SuperMessage].
const defaultSuperMessageDocumentOverlayBuilders = <SuperMessageDocumentLayerBuilder>[
  // Adds a Leader around the document selection at a focal point for the
  // iOS floating toolbar.
  SuperMessageIosToolbarFocalPointDocumentLayerBuilder(),
  // Displays caret and drag handles, specifically for iOS.
  SuperMessageIosHandlesDocumentLayerBuilder(),
];

/// Builds widgets that are displayed at the same position and size as
/// the document layout within a [SuperMessage].
abstract class SuperMessageDocumentLayerBuilder {
  ContentLayerWidget build(BuildContext context, SuperMessageContext messageContext);
}

/// A [SuperMessageDocumentLayerBuilder] that builds a [IosToolbarFocalPointDocumentLayer], which
/// positions a `Leader` widget around the document selection, as a focal point for an
/// iOS floating toolbar.
class SuperMessageIosToolbarFocalPointDocumentLayerBuilder implements SuperMessageDocumentLayerBuilder {
  const SuperMessageIosToolbarFocalPointDocumentLayerBuilder({
    // TODO(srawlins): `unused_element`, when reporting a parameter, is being
    // renamed to `unused_element_parameter`. For now, ignore each; when the SDK
    // constraint is >= 3.6.0, just ignore `unused_element_parameter`.
    // ignore: unused_element, unused_element_parameter
    this.showDebugLeaderBounds = false,
  });

  /// Whether to paint colorful bounds around the leader widget.
  final bool showDebugLeaderBounds;

  @override
  ContentLayerWidget build(BuildContext context, SuperMessageContext messageContext) {
    return IosToolbarFocalPointDocumentLayer(
      document: messageContext.editor.document,
      selection: messageContext.editor.composer.selectionNotifier,
      toolbarFocalPointLink: SuperReaderIosControlsScope.rootOf(context).toolbarFocalPoint,
      showDebugLeaderBounds: showDebugLeaderBounds,
    );
  }
}

/// A [SuperMessageLayerBuilder], which builds a [IosHandlesDocumentLayer],
/// which displays iOS-style handles.
class SuperMessageIosHandlesDocumentLayerBuilder implements SuperMessageDocumentLayerBuilder {
  const SuperMessageIosHandlesDocumentLayerBuilder({
    this.handleColor,
  });

  final Color? handleColor;

  @override
  ContentLayerWidget build(BuildContext context, SuperMessageContext messageContext) {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return const ContentLayerProxyWidget(child: SizedBox());
    }

    return IosHandlesDocumentLayer(
      document: messageContext.editor.document,
      documentLayout: messageContext.documentLayout,
      selection: messageContext.editor.composer.selectionNotifier,
      changeSelection: (newSelection, changeType, reason) {
        messageContext.editor.execute([
          ChangeSelectionRequest(
            newSelection,
            changeType,
            reason,
          ),
        ]);
      },
      handleColor: handleColor ?? Theme.of(context).primaryColor,
      shouldCaretBlink: ValueNotifier<bool>(false),
    );
  }
}

final defaultChatStylesheet = Stylesheet(
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

/// Default visual styles related to content selection.
const defaultChatSelectionStyles = SelectionStyles(
  selectionColor: Color(0xFFACCEF7),
);
