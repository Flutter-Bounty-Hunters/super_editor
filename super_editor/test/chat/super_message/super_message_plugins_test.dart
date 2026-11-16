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

    testWidgetsOnAllPlatforms('build nodes with their component builders', (tester) async {
      final editor = _createEditor();

      await tester.pumpWidget(_buildMessage(editor, plugins: {_FakePlugin()}));

      expect(find.byKey(_FakeParagraphComponentBuilder.componentKey), findsOneWidget);
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

Widget _buildMessage(Editor editor, {Set<SuperEditorPlugin> plugins = const {}, Key? key}) {
  return MaterialApp(
    home: Scaffold(
      body: SuperMessage(
        key: key,
        editor: editor,
        plugins: plugins,
      ),
    ),
  );
}

class _FakePlugin extends SuperEditorPlugin {
  int attachCallCount = 0;
  int detachCallCount = 0;
  Editor? attachedEditor;

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
