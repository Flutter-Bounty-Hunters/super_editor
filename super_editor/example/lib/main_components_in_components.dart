import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  runApp(
    MaterialApp(
      home: _ComponentsInComponentsDemoScreen(),
    ),
  );
}

class _ComponentsInComponentsDemoScreen extends StatefulWidget {
  const _ComponentsInComponentsDemoScreen();

  @override
  State<_ComponentsInComponentsDemoScreen> createState() => _ComponentsInComponentsDemoScreenState();
}

class _ComponentsInComponentsDemoScreenState extends State<_ComponentsInComponentsDemoScreen> {
  late final Editor _editor;

  @override
  void initState() {
    super.initState();

    _editor = createDefaultDocumentEditor(
      isHistoryEnabled: true,
      document: MutableDocument(
        nodes: [
          ParagraphNode(
            id: "header",
            text: AttributedText("This is a demo of a Banner component."),
            metadata: {
              NodeMetadata.blockType: header1Attribution,
            },
          ),
          _BannerNode(id: "main-banner", children: [
            ParagraphNode(
              id: "main-banner-header",
              text: AttributedText("Hello, Banner!"),
              metadata: {
                NodeMetadata.blockType: header2Attribution,
              },
            ),
            HorizontalRuleNode(id: "main-banner-hr"),
            ImageNode(
              id: "main-banner-image",
              imageUrl:
                  "https://www.thedroidsonroids.com/wp-content/uploads/2023/08/flutter_blog_series_What-is-Flutter-app-development-.png",
            ),
            HorizontalRuleNode(id: "main-banner-hr-2"),
            ParagraphNode(
              id: "main-banner-description",
              text: AttributedText("This is a banner, which can contain any other blocks you want"),
            ),
            _BannerNode(id: "inner-banner", children: [
              ParagraphNode(
                id: "inner-banner-header",
                text: AttributedText("Info!"),
                metadata: {
                  NodeMetadata.blockType: header3Attribution,
                },
              ),
              HorizontalRuleNode(id: "inner-banner-hr"),
              ParagraphNode(
                id: "inner-banner-description",
                text: AttributedText("This is an internal banner, which can be used to test multiple banners"),
              ),
            ]),
            ParagraphNode(
              id: "between-internal-banners",
              text: AttributedText("The text between internal banners"),
            ),
            _BannerNode(id: "inner-banner-2", children: [
              ParagraphNode(
                id: "inner-banner-2-header",
                text: AttributedText("Warning!"),
                metadata: {
                  NodeMetadata.blockType: header3Attribution,
                },
              ),
              HorizontalRuleNode(id: "inner-banner-2-hr"),
              ParagraphNode(
                id: "inner-banner-2-description",
                text: AttributedText("This is another internal banner"),
              ),
            ]),
            ParagraphNode(
              id: "last-text",
              text: AttributedText("Some notes after all internal banners"),
            ),
          ]),
          ParagraphNode(
            id: "footer text",
            text: AttributedText("This is after the banner component."),
          ),
        ],
      ),
      composer: MutableDocumentComposer(),
    );
  }

  @override
  void dispose() {
    _editor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SuperEditor(
        editor: _editor,
        stylesheet: defaultStylesheet.copyWith(
          addRulesAfter: [
            StyleRule(
              BlockSelector("banner"),
              (doc, docNode) {
                return {
                  Styles.padding: CascadingPadding.only(left: 0, right: 0, top: 24, bottom: 0),
                };
              },
            ),
            StyleRule(
              BlockSelector.all.childOf("banner"),
              (doc, docNode) {
                return {
                  Styles.padding: CascadingPadding.symmetric(vertical: 0, horizontal: 0),
                  Styles.textStyle: const TextStyle(
                    color: Colors.white,
                  ),
                };
              },
            ),
            StyleRule(
              BlockSelector('banner').childOf("banner"),
              (doc, docNode) {
                return {
                  Styles.backgroundColor: Colors.lightBlueAccent,
                };
              },
            ),
            StyleRule(
              BlockSelector('paragraph').childOf('banner').after(horizontalRuleBlockType.name),
              (doc, docNode) {
                return {Styles.textStyle: const TextStyle(color: Colors.white60)};
              },
            ),
            StyleRule(
              BlockSelector(horizontalRuleBlockType.name).childOf("banner"),
              (doc, docNode) {
                return {
                  Styles.backgroundColor: Colors.white.withValues(alpha: 0.25),
                };
              },
            ),
          ],
        ),
        componentBuilders: [
          _BannerComponentBuilder(),
          ...defaultComponentBuilders,
        ],
      ),
    );
  }
}

const bannerBlockType = NamedAttribution("banner");

class _BannerComponentBuilder implements ComponentBuilder {
  @override
  SingleColumnLayoutComponentViewModel? createViewModel(
    PresenterContext presenterContext,
    Document document,
    DocumentNode node,
  ) {
    if (node is! _BannerNode) {
      return null;
    }

    return _BannerNodeViewModel(
      nodeId: node.id,
      parent: node,
      children: node.children.map((childNode) => presenterContext.createViewModel(childNode)!).toList(),
    );
  }

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! _BannerNodeViewModel) {
      return null;
    }

    return _BannerComponent(
      key: componentContext.componentKey,
      backgroundColor: componentViewModel.backgroundColor,
      children: componentViewModel.children.map((childViewModel) {
        final (componentKey, component) = componentContext.buildChildComponent(childViewModel);
        return CompositeComponentChild(
          nodeId: childViewModel.nodeId,
          componentKey: componentKey,
          widget: component,
        );
      }).toList(),
    );
  }
}

class _BannerNodeViewModel extends CompositeNodeViewModel {
  Color? backgroundColor;

  _BannerNodeViewModel({
    required super.nodeId,
    required super.parent,
    required super.children,
  });

  @override
  SingleColumnLayoutComponentViewModel copy() {
    return internalCopy(
      _BannerNodeViewModel(
        nodeId: nodeId,
        parent: parent,
        children: List.from(children),
      ),
    );
  }

  @override
  CompositeNodeViewModel internalCopy(_BannerNodeViewModel viewModel) {
    final copy = super.internalCopy(viewModel) as _BannerNodeViewModel;
    copy.backgroundColor = backgroundColor;
    return copy;
  }

  @override
  void applyStyles(Map<String, dynamic> styles) {
    backgroundColor = styles[Styles.backgroundColor];
    super.applyStyles(styles);
  }
}

class _BannerComponent extends StatefulWidget {
  final Color? backgroundColor;
  const _BannerComponent({
    super.key,
    this.backgroundColor,
    required this.children,
  });

  final List<CompositeComponentChild> children;

  @override
  State<_BannerComponent> createState() => _BannerComponentState();
}

class _BannerComponentState extends State<_BannerComponent> with ProxyDocumentComponent<_BannerComponent> {
  @override
  final childDocumentComponentKey = GlobalKey(debugLabel: 'banner-internal-column');

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.backgroundColor ?? Colors.blue,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ColumnDocumentComponent(
          key: childDocumentComponentKey,
          children: widget.children,
        ),
      ),
    );
  }
}

class _BannerNode extends CompositeNode {
  _BannerNode({
    required super.id,
    required this.children,
    Map<String, dynamic>? metadata,
  }) : super(
          metadata: {
            if (metadata != null) //
              ...metadata,
            NodeMetadata.blockType: bannerBlockType,
          },
        ) {
    validateChildrenNodeIds();
  }

  final List<DocumentNode> children;

  @override
  DocumentNode copyWithAddedMetadata(Map<String, dynamic> newProperties) {
    // TODO: implement copyWithAddedMetadata
    throw UnimplementedError();
  }

  @override
  DocumentNode copyAndReplaceMetadata(Map<String, dynamic> newMetadata) {
    // TODO: implement copyAndReplaceMetadata
    throw UnimplementedError();
  }

  @override
  String? copyContent(NodeSelection selection) {
    final compositeSelection = selection;
    if (compositeSelection is! CompositeNodeSelection) {
      throw Exception('Unexpected selection type ${compositeSelection.runtimeType}');
    }
    // Maybe this should go to base class, so we only have to override the case when more than one
    // child node in the selection?
    if (compositeSelection.extent.childNodeId == compositeSelection.base.childNodeId) {
      final child = getChildByNodeId(compositeSelection.extent.childNodeId)!;
      final childSelection = child.computeSelection(
        base: compositeSelection.base.childNodePosition,
        extent: compositeSelection.extent.childNodePosition,
      );
      return child.copyContent(childSelection);
    }
    throw UnimplementedError('Copy more than one child node is not yet implemented');
  }

  CompositeNode copyWithChildren(List<DocumentNode> newChildren) {
    return _BannerNode(id: id, metadata: metadata, children: newChildren);
  }
}
