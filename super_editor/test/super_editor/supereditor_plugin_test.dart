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

    testWidgetsOnAllPlatforms(
        'replaces context resources across SuperEditor widget recreation, when different plugin instances are provided',
        (tester) async {
      final pump1Key = GlobalKey(debugLabel: 'pump-1');
      final plugin1 = _FakePlugin();

      final pump2Key = GlobalKey(debugLabel: 'pump-2');
      final plugin2 = _FakePlugin();

      final editor = createDefaultDocumentEditor(
        document: MutableDocument(
          nodes: [
            ParagraphNode(id: "1", text: AttributedText()),
          ],
        ),
        composer: MutableDocumentComposer(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            key: pump1Key,
            body: SuperEditor(
              editor: editor,
              plugins: {plugin1},
            ),
          ),
        ),
      );

      // Grab the instance of the context resource that was added by
      // the plugin. We want to make sure the instance doesn't disappear
      // or get replaced.
      expect(plugin1.attachCallCount, 1);
      expect(plugin1.detachCallCount, 0);
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
              plugins: {plugin2},
            ),
          ),
        ),
      );

      // Grab the context resource again and ensure it's the same one as before.
      expect(plugin1.attachCallCount, 1);
      expect(plugin1.detachCallCount, 1);

      expect(plugin2.attachCallCount, 1);
      expect(plugin2.detachCallCount, 0);

      final resource2 = editor.context.findMaybe(_FakePluginResource.key);
      expect(resource2, isNotNull);
      expect(resource1, isNot(resource2));
    });

    testWidgetsOnAllPlatforms(
        'an existing plugin can transition from one Editor to another Editor, in the same SuperEditor widget',
        (tester) async {
      final superEditorKey = GlobalKey(debugLabel: 'SuperEditor');
      final plugin = _FakePlugin();

      final editor1 = createDefaultDocumentEditor(
        document: MutableDocument(
          nodes: [
            ParagraphNode(id: "1", text: AttributedText()),
          ],
        ),
        composer: MutableDocumentComposer(),
      );

      final editor2 = createDefaultDocumentEditor(
        document: MutableDocument(
          nodes: [
            ParagraphNode(id: "1", text: AttributedText()),
          ],
        ),
        composer: MutableDocumentComposer(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            key: superEditorKey,
            body: SuperEditor(
              editor: editor1,
              plugins: {plugin},
            ),
          ),
        ),
      );

      // Ensure the plugin attached itself.
      expect(plugin.attachCallCount, 1);
      expect(plugin.detachCallCount, 0);

      final resource1 = editor1.context.findMaybe(_FakePluginResource.key);
      expect(resource1, plugin.fakeResource);

      // Re-pump with a different Editor, but the same SuperEditor and plugin.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            key: superEditorKey,
            body: SuperEditor(
              editor: editor2,
              plugins: {plugin},
            ),
          ),
        ),
      );

      // Ensure the plugin detached and re-attached when the `SuperEditor` rebuilt
      // with a new `Editor`.
      expect(plugin.attachCallCount, 2);
      expect(plugin.detachCallCount, 1);

      final resource2 = editor2.context.findMaybe(_FakePluginResource.key);
      expect(resource2, plugin.fakeResource);
    });

    testWidgetsOnAllPlatforms(
        'an existing plugin can transition from one SuperEditor+Editor combo to another SuperEditor+Editor',
        (tester) async {
      final plugin = _FakePlugin();

      final pump1Key = GlobalKey(debugLabel: 'pump-1');
      final editor1 = createDefaultDocumentEditor(
        document: MutableDocument(
          nodes: [
            ParagraphNode(id: "1", text: AttributedText()),
          ],
        ),
        composer: MutableDocumentComposer(),
      );

      final pump2Key = GlobalKey(debugLabel: 'pump-2');
      final editor2 = createDefaultDocumentEditor(
        document: MutableDocument(
          nodes: [
            ParagraphNode(id: "1", text: AttributedText()),
          ],
        ),
        composer: MutableDocumentComposer(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            key: pump1Key,
            body: SuperEditor(
              editor: editor1,
              plugins: {plugin},
            ),
          ),
        ),
      );

      // Ensure the plugin attached itself.
      expect(plugin.attachCallCount, 1);
      expect(plugin.detachCallCount, 0);
      final resource1 = editor1.context.findMaybe(_FakePluginResource.key);
      expect(resource1, plugin.fakeResource);

      // Re-pump with a different Editor, but the same plugin.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            key: pump2Key,
            body: SuperEditor(
              editor: editor2,
              plugins: {plugin},
            ),
          ),
        ),
      );

      // Ensure the plugin detached and re-attached.
      expect(plugin.attachCallCount, 2);
      expect(plugin.detachCallCount, 1);

      final resource2 = editor2.context.findMaybe(_FakePluginResource.key);
      expect(resource2, plugin.fakeResource);
    });
  });
}

/// A plugin that tracks whether it was detached.
class _FakePlugin extends SuperEditorPlugin {
  int get attachCallCount => _attachCallCount;
  int _attachCallCount = 0;

  int get detachCallCount => _detachCallCount;
  int _detachCallCount = 0;

  final fakeResource = _FakePluginResource();

  @override
  void attach(Editor editor) {
    print("Attaching _FakePlugin ($hashCode) - attachments: $attachCount");
    // FIXME: The attach count handles re-ification for the same Editor, but
    // not when the SuperEditor re-ifies with a different Editor. Then the
    // attach count is `1` but we're not actually attached to that `Editor`.
    //
    // And we can't have `SuperEditor` just call `detach()` before calling
    // `attach()` because the new `SuperEditor` doesn't have a reference to
    // the previous `Editor`.
    //
    // Can we temporarily be attached to 2 Editors?
    if (attachCount(editor) == 0) {
      print(" - this is first attachment, adding resource to context");
      editor.context.put(_FakePluginResource.key, fakeResource);
    }

    _attachCallCount += 1;

    super.attach(editor);
  }

  @override
  void detach(Editor editor) {
    print("Detaching _FakePlugin ($hashCode) - attachments: $attachCount");
    super.detach(editor);
    if (attachCount(editor) == 0) {
      print(" - no more attachments, deleting resource from context: $fakeResource");
      editor.context.remove(_FakePluginResource.key, fakeResource);
    } else {
      print(" - NOT removing the resource");
    }

    _detachCallCount += 1;
  }
}

class _FakePluginResource extends Editable {
  static const key = "fake-resource";
}
