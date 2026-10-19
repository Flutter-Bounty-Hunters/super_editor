import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

void main() {
  group('SuperEditor > iOS > system context menu >', () {
    testWidgetsOnIos('hides the toolbar when iOS hides the menu', (tester) async {
      final showMenuCallCount = _countSystemMenuShows(tester);

      late final TestDocumentContext testContext;
      testContext = await tester //
          .createDocument()
          .withSingleParagraph()
          .withiOSToolbarBuilder(
            (context, toolbarKey, focalPoint) => iOSSystemPopoverEditorToolbarWithFallbackBuilder(
              context,
              toolbarKey,
              focalPoint,
              CommonEditorOperations(
                editor: testContext.editor,
                document: testContext.document,
                composer: testContext.composer,
                documentLayoutResolver: () => testContext.layoutKey.currentState as DocumentLayout,
              ),
              SuperEditorIosControlsScope.rootOf(context),
            ),
          )
          .withCustomWidgetTreeBuilder(_buildAppWithSystemContextMenuSupport)
          .pump();
      final nodeId = testContext.document.first.id;

      // Double tap to select a word, which shows the toolbar.
      await tester.doubleTapInParagraph(nodeId, 1);
      await tester.pumpAndSettle();

      // Ensure that the toolbar is displayed as the iOS system menu.
      expect(SuperEditorInspector.wantsMobileToolbarToBeVisible(), isTrue);
      expect(showMenuCallCount(), greaterThan(0));

      // Simulate iOS hiding the menu on its own, as it does when the user presses
      // one of its buttons, such as "Paste", or taps elsewhere.
      await _simulateIosHidingSystemMenu(tester);
      await tester.pump();

      // Ensure that the editor no longer wants to display the toolbar. If the editor still
      // wanted to display the toolbar, the menu would re-appear the next time the editor
      // repositions it, e.g., when the editor changes size.
      expect(SuperEditorInspector.wantsMobileToolbarToBeVisible(), isFalse);
    });
  });
}

/// Builds an app around the given [superEditor] in which the platform supports
/// the iOS system context menu, which a test environment otherwise doesn't.
Widget _buildAppWithSystemContextMenuSupport(Widget superEditor) {
  return MaterialApp(
    home: Builder(
      builder: (context) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(supportsShowingSystemContextMenu: true),
          child: Scaffold(body: superEditor),
        );
      },
    ),
  );
}

/// Intercepts requests to show the iOS system context menu, and returns a getter for
/// the number of those requests.
int Function() _countSystemMenuShows(WidgetTester tester) {
  var count = 0;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'ContextMenu.showSystemContextMenu') {
      count += 1;
    }
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

  return () => count;
}

/// Sends the message that iOS sends when it hides the system context menu on its own.
Future<void> _simulateIosHidingSystemMenu(WidgetTester tester) async {
  final message = const JSONMethodCodec().encodeMethodCall(
    const MethodCall('ContextMenu.onDismissSystemContextMenu'),
  );
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage('flutter/platform', message, (_) {});
}
