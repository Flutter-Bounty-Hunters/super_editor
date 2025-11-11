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
      document: MutableDocument(
        nodes: [
          ParagraphNode(
            id: "1",
            text: AttributedText("This is a demo of a Banner component."),
            metadata: {
              NodeMetadata.blockType: header1Attribution,
            },
          ),
          _BannerNode(id: "2", children: [
            ParagraphNode(
              id: "3",
              text: AttributedText("Hello, Banner!"),
              metadata: {
                NodeMetadata.blockType: header2Attribution,
              },
            ),
            HorizontalRuleNode(id: "7"),
            ImageNode(
              id: "4",
              imageUrl:
                  "https://www.thedroidsonroids.com/wp-content/uploads/2023/08/flutter_blog_series_What-is-Flutter-app-development-.png",
            ),
            HorizontalRuleNode(id: "8"),
            ParagraphNode(
              id: "5",
              text: AttributedText("This is a banner, which can contain any other blocks you want"),
            ),
          ]),
          ParagraphNode(
            id: "6",
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

    return CompositeNodeViewModel(
      nodeId: node.id,
      children: node.children.map((childNode) => presenterContext.createViewModel(childNode)!).toList(),
    );
  }

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! CompositeNodeViewModel) {
      return null;
    }

    assert(componentViewModel.children.isNotEmpty, 'Empty children does not makes sense here');

    // print("Building a _BannerComponent - banner key: ${componentContext.componentKey}");
    // print(" - child keys: ${childrenAndKeys.map((x) => x.$1)}");
    return _BannerComponent(
      key: componentContext.componentKey,
      children: componentViewModel.children.map((childViewModel) {
        final (componentKey, component) = componentContext.buildChildComponent(childViewModel);
        return CompositeChildComponent(
          nodeId: childViewModel.nodeId,
          componentKey: componentKey,
          widget: component,
        );
      }).toList(),
    );
  }
}

class _BannerComponent extends StatefulWidget {
  const _BannerComponent({
    super.key,
    required this.children,
  });

  final List<CompositeChildComponent> children;

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
          color: Colors.blue,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ColumnDocumentComponent(
          key: childDocumentComponentKey,
          // childComponentIds: widget.childComponentIds,
          // childComponentKeys: widget.childComponentKeys,
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
        );

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
    // TODO: implement copyContent
    throw UnimplementedError();
  }
}
