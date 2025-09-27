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
      expect(plugin.wasDetached, isFalse);

      // Pump another widget tree to dispose SuperEditor.
      await tester.pumpWidget(Container());

      // Ensure the plugin was detached.
      expect(plugin.wasDetached, isTrue);
    });
  });
}

/// A plugin that tracks whether it was detached.
class _FakePlugin extends SuperEditorPlugin {
  bool get wasDetached => _wasDetached;
  bool _wasDetached = false;

  @override
  void detach(Editor editor) {
    _wasDetached = true;
  }
}
