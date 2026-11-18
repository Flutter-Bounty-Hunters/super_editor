import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group('SuperMessage > plugins >', () {
    testWidgetsOnAllPlatforms('attach to the editor and detach when the message is disposed', (tester) async {
      final editor = _createEditor();
      final plugin = _FakePlugin();

      await tester.pumpWidget(_buildMessage(editor, plugins: {plugin}));

      expect(plugin.attachCallCount, 1);
      expect(plugin.detachCallCount, 0);
      expect(plugin.attachedEditor, editor);

      await tester.pumpWidget(const SizedBox());

      expect(plugin.attachCallCount, 1);
      expect(plugin.detachCallCount, 1);
    });

    testWidgetsOnAllPlatforms('stay attached when another message takes over the same editor', (tester) async {
      final editor = _createEditor();
      final plugin = _FakePlugin();

      await tester.pumpWidget(_buildMessage(editor, plugins: {plugin}, key: GlobalKey()));
      // A different key replaces the whole message subtree, so the new message
      // attaches before the old one detaches.
      await tester.pumpWidget(_buildMessage(editor, plugins: {plugin}, key: GlobalKey()));

      expect(plugin.attachCallCount, 1);
      expect(plugin.detachCallCount, 0);
    });

    testWidgetsOnAllPlatforms('move to a new editor when the message gets one', (tester) async {
      final editor1 = _createEditor();
      final editor2 = _createEditor();
      final plugin = _FakePlugin();

      await tester.pumpWidget(_buildMessage(editor1, plugins: {plugin}));
      await tester.pumpWidget(_buildMessage(editor2, plugins: {plugin}));

      expect(plugin.attachCallCount, 2);
      expect(plugin.detachCallCount, 1);
      expect(plugin.attachedEditor, editor2);
    });

    testWidgetsOnAllPlatforms('attach when added and detach when removed', (tester) async {
      final editor = _createEditor();
      final plugin = _FakePlugin();

      await tester.pumpWidget(_buildMessage(editor));
      expect(plugin.attachCallCount, 0);

      await tester.pumpWidget(_buildMessage(editor, plugins: {plugin}));
      expect(plugin.attachCallCount, 1);

      await tester.pumpWidget(_buildMessage(editor));
      expect(plugin.detachCallCount, 1);
    });

    testWidgetsOnAllPlatforms('are told about a new focus node when the message gets one', (tester) async {
      final editor = _createEditor();
      final plugin = _FakePlugin();
      final focusNode1 = FocusNode();
      final focusNode2 = FocusNode();
      addTearDown(focusNode1.dispose);
      addTearDown(focusNode2.dispose);

      await tester.pumpWidget(_buildMessage(editor, plugins: {plugin}, focusNode: focusNode1));
      expect(plugin.lastFocusNode, focusNode1);

      await tester.pumpWidget(_buildMessage(editor, plugins: {plugin}, focusNode: focusNode2));
      expect(plugin.lastFocusNode, focusNode2);
    });

    testWidgetsOnAllPlatforms('build nodes with their component builders', (tester) async {
      final editor = _createEditor();

      await tester.pumpWidget(_buildMessage(editor, plugins: {_FakePlugin()}));

      expect(find.byKey(_FakeParagraphComponentBuilder.componentKey), findsOneWidget);
    });

    testWidgetsOnAllPlatforms('build their document underlays and overlays, and remove them when removed',
        (tester) async {
      final editor = _createEditor();

      await tester.pumpWidget(_buildMessage(editor, plugins: {_FakeLayersPlugin()}));

      expect(find.byKey(_FakeLayersPlugin.underlayKey), findsOneWidget);
      expect(find.byKey(_FakeLayersPlugin.overlayKey), findsOneWidget);

      // Remove the plugin, which shifts the default overlays into the plugin's
      // former slots.
      await tester.pumpWidget(_buildMessage(editor));

      expect(find.byKey(_FakeLayersPlugin.underlayKey), findsNothing);
      expect(find.byKey(_FakeLayersPlugin.overlayKey), findsNothing);
    });
  });
}

Editor _createEditor() => createDefaultDocumentEditor(
      document: MutableDocument(
        nodes: [
          ParagraphNode(id: '1', text: AttributedText('Hello')),
        ],
      ),
      composer: MutableDocumentComposer(),
    );

Widget _buildMessage(
  Editor editor, {
  Set<SuperMessagePlugin> plugins = const {},
  FocusNode? focusNode,
  Key? key,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SuperMessage(
        key: key,
        focusNode: focusNode,
        editor: editor,
        plugins: plugins,
      ),
    ),
  );
}

class _FakePlugin extends SuperMessagePlugin {
  int attachCallCount = 0;
  int detachCallCount = 0;
  Editor? attachedEditor;
  FocusNode? lastFocusNode;

  @override
  void onFocusChange(FocusNode messageFocusNode) {
    lastFocusNode = messageFocusNode;
  }

  @override
  void attach(Editor editor) {
    attachCallCount += 1;
    attachedEditor = editor;
  }

  @override
  void detach(Editor editor) {
    detachCallCount += 1;
    if (attachedEditor == editor) {
      attachedEditor = null;
    }
  }

  @override
  List<ComponentBuilder> get componentBuilders => const [_FakeParagraphComponentBuilder()];
}

class _FakeLayersPlugin extends SuperMessagePlugin {
  static const underlayKey = ValueKey('fake-underlay');
  static const overlayKey = ValueKey('fake-overlay');

  @override
  List<SuperMessageDocumentLayerBuilder> get documentUnderlayBuilders => const [_FakeLayerBuilder(underlayKey)];

  @override
  List<SuperMessageDocumentLayerBuilder> get documentOverlayBuilders => const [_FakeLayerBuilder(overlayKey)];
}

class _FakeLayerBuilder implements SuperMessageDocumentLayerBuilder {
  const _FakeLayerBuilder(this.key);

  final Key key;

  @override
  ContentLayerWidget build(BuildContext context, DocumentContext messageContext) {
    return ContentLayerProxyWidget(child: SizedBox(key: key));
  }
}

/// Builds every paragraph as a keyed box, so a test can tell the plugin's
/// builder ran ahead of the default paragraph builder.
class _FakeParagraphComponentBuilder implements ComponentBuilder {
  const _FakeParagraphComponentBuilder();

  static const componentKey = ValueKey('fake-paragraph');

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! ParagraphNode) {
      return null;
    }
    return _FakeParagraphViewModel(nodeId: node.id);
  }

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! _FakeParagraphViewModel) {
      return null;
    }
    return SizedBox(key: componentKey, height: 20);
  }
}

class _FakeParagraphViewModel extends SingleColumnLayoutComponentViewModel {
  _FakeParagraphViewModel({required super.nodeId}) : super(createdAt: null, padding: EdgeInsets.zero);

  @override
  SingleColumnLayoutComponentViewModel copy() => _FakeParagraphViewModel(nodeId: nodeId);
}
