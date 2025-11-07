import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';

import 'supereditor_test_tools.dart';

void main() {
  group('SuperEditor > plugins >', () {
    testWidgetsOnAllPlatforms('are detached when the editor is disposed', (tester) async {
      final plugin = _FakePlugin();

      await tester //
          .createDocument()
          .withSingleParagraph()
          .withPlugin(plugin)
          .pump();

      // Ensure the plugin was not attached initially.
      expect(plugin.detachCallCount, 0);

      // Pump another widget tree to dispose SuperEditor.
      await tester.pumpWidget(Container());

      // Ensure the plugin was detached.
      expect(plugin.detachCallCount, 1);
    });

    testWidgetsOnAllPlatforms('preserves context resources across SuperEditor widget recreation', (tester) async {
      final pump1Key = GlobalKey(debugLabel: 'pump-1');
      final pump2Key = GlobalKey(debugLabel: 'pump-2');
      final editor = createDefaultDocumentEditor(
        document: MutableDocument(
          nodes: [
            ParagraphNode(id: "1", text: AttributedText()),
          ],
        ),
        composer: MutableDocumentComposer(),
      );
      final plugin = _FakePlugin();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            key: pump1Key,
            body: SuperEditor(
              editor: editor,
              plugins: {plugin},
            ),
          ),
        ),
      );

      // Grab the instance of the context resource that was added by
      // the plugin. We want to make sure the instance doesn't disappear
      // or get replaced.
      expect(plugin.attachCallCount, 1);
      expect(plugin.detachCallCount, 0);
      final resource1 = editor.context.findMaybe(_FakePluginResource.key);
      expect(resource1, isNotNull);

      // Pump another widget tree to replace the existing Super Editor tree
      // with another Super Editor tree (simulating something like a navigator
      // replacing an entire subtree, including SuperEditor, but wanting to
      // continue using the same backing editor and document).
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            key: pump2Key,
            body: SuperEditor(
              editor: editor,
              plugins: {plugin},
            ),
          ),
        ),
      );

      // Grab the context resource again and ensure it's the same one as before.
      expect(plugin.attachCallCount, 2);
      expect(plugin.detachCallCount, 1);
      final resource2 = editor.context.findMaybe(_FakePluginResource.key);
      expect(resource2, isNotNull);
      expect(resource1, resource2);
    });
  });
}

/// A plugin that tracks whether it was detached.
class _FakePlugin extends SuperEditorPlugin {
  int get attachCallCount => _attachCallCount;
  int _attachCallCount = 0;

  int get detachCallCount => _detachCallCount;
  int _detachCallCount = 0;

  @override
  void attach(Editor editor) {
    print("Attaching _FakePlugin");
    if (attachCount == 0) {
      editor.context.put(_FakePluginResource.key, _FakePluginResource());
    }

    _attachCallCount += 1;

    super.attach(editor);
  }

  @override
  void detach(Editor editor) {
    print("Detaching _FakePlugin");
    super.detach(editor);
    if (attachCount == 0) {
      editor.context.remove(_FakePluginResource.key);
    }

    _detachCallCount += 1;
  }
}

class _FakePluginResource extends Editable {
  static const key = "fake-resource";
}
