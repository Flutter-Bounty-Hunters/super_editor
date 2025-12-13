import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

void main() {
  group("SuperEditor shortcuts", () {
    testWidgetsOnDesktop("overrides ancestor Shortcut widgets", (tester) async {
      bool didTriggerAncestorShortcut = false;
      await _pumpShortcutsAndSuperEditor(
        tester,
        // The default keyboard actions include an ENTER handler.
        defaultKeyboardActions,
        () {
          didTriggerAncestorShortcut = true;
        },
      );
      await tester.placeCaretInParagraph("1", 0);

      // Press ENTER, which we expect to be handled by SuperEditor.
      await tester.pressEnter();

      // Ensure that the ancestor Shortcuts widget didn't receive
      // the ENTER key.
      expect(didTriggerAncestorShortcut, false);
    });

    testWidgetsOnDesktop("defers to ancestor Shortcut widgets when requested", (tester) async {
      int ancestorTriggerCount = 0;
      await _pumpShortcutsAndSuperEditor(
        tester,
        [
          ignoreKeyCombos([
            const SingleActivator(LogicalKeyboardKey.enter),
            const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true),
          ]),
          ...defaultKeyboardActions,
        ],
        () {
          ancestorTriggerCount += 1;
        },
      );
      await tester.placeCaretInParagraph("1", 0);

      // Press ENTER, which we expect to defer to the ancestor Shortcuts.
      await tester.pressEnter();
      // Press SHIFT + RIGHT ARROW, which we expect to defer to the ancestor
      // Shortcuts. We test this combination to make sure that SuperEditor
      // considers modifier keys, too.
      await tester.pressShiftRightArrow();

      // Ensure that the ancestor Shortcuts widget received the key combos.
      expect(ancestorTriggerCount, 2);
    });
  });
}

Future<void> _pumpShortcutsAndSuperEditor(
  WidgetTester tester,
  List<SuperEditorKeyboardAction> keyboardActions,
  VoidCallback onShortcut,
) async {
  final document = MutableDocument.empty("1");
  final composer = MutableDocumentComposer();
  final editor = createDefaultDocumentEditor(document: document, composer: composer);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Shortcuts(
          shortcuts: {
            // These activators should only trigger when the child
            // SuperEditor explicitly ignores these keys.
            const SingleActivator(LogicalKeyboardKey.enter): _VoidCallbackIntent(onShortcut),
            const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true): _VoidCallbackIntent(onShortcut),
          },
          child: Actions(
            actions: {
              _VoidCallbackIntent: _VoidCallbackAction(),
            },
            child: SuperEditor(
              editor: editor,
              keyboardActions: keyboardActions,
            ),
          ),
        ),
      ),
    ),
  );
}

// TODO: This was copied from "master" because it's not yet on "stable".
// Delete this when VoidCallbackIntent rolls to stable.
/// An [Intent] that keeps a [VoidCallback] to be invoked by a
/// [VoidCallbackAction] when it receives this intent.
class _VoidCallbackIntent extends Intent {
  /// Creates a [VoidCallbackIntent].
  const _VoidCallbackIntent(this.callback);

  /// The callback that is to be called by the [VoidCallbackAction] that
  /// receives this intent.
  final VoidCallback callback;
}

class _VoidCallbackAction extends Action<_VoidCallbackIntent> {
  @override
  Object? invoke(_VoidCallbackIntent intent) {
    intent.callback();
    return null;
  }
}
