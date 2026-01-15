import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:super_editor_clipboard/src/plugin/ios/super_editor_clipboard_ios_plugin.dart';
import 'package:super_editor_clipboard/src/super_editor_paste.dart';
import 'package:super_keyboard/super_keyboard_test.dart';

void main() {
  group("Paste > iOS > native >", () {
    testWidgetsOnIos("takes control of native paste when toolbar is shown", (tester) async {
      // Simulate fake keyboard expand/collapse because this impacts decisions to
      // show the popover toolbar on iOS.
      TestSuperKeyboard.install(tester, id: "editor");

      try {
        int enableCustomPasteCount = 0;
        int disableCustomPasteCount = 0;

        // Intercept plugin messages from the Dart side of our plugin to the iOS side.
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SuperEditorClipboardIosPlugin.methodChannel,
            (MethodCall methodCall) async {
          if (methodCall.method == SuperEditorClipboardIosPlugin.messageToPlatformEnableCustomPaste) {
            enableCustomPasteCount += 1;
          } else if (methodCall.method == SuperEditorClipboardIosPlugin.messageToPlatformDisableCustomPaste) {
            disableCustomPasteCount += 1;
          }

          // Flutter channels are expected to always return something.
          return null;
        });

        await _pumpScaffold(tester);

        // Ensure that the editor hasn't enabled custom paste, yet.
        expect(enableCustomPasteCount, 0);
        expect(disableCustomPasteCount, 0);

        // Tap to place the caret.
        await tester.tapInParagraph("1", 0);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        // Tap again to show the toolbar.
        await tester.tapInParagraph("1", 0);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        // Ensure that the editor has enabled custom paste, now that the toolbar is visible.
        expect(enableCustomPasteCount, 1);
        expect(disableCustomPasteCount, 0);

        // Tap on the caret again, to toggle the toolbar off.
        await tester.tap(find.byType(SuperEditor));
        await tester.pumpAndSettle();

        // Ensure that the editor disabled custom paste, now that the toolbar is gone.
        expect(enableCustomPasteCount, 1);
        expect(disableCustomPasteCount, 1);
      } finally {
        // Remove the fake software keyboard.
        TestSuperKeyboard.forceUninstall();
      }
    });
  });
}

Future<void> _pumpScaffold(WidgetTester tester) async {
  final editor = createDefaultDocumentEditor(
    document: MutableDocument(
      nodes: [
        ParagraphNode(id: "1", text: AttributedText()),
      ],
    ),
  );

  final documentLayoutKey = GlobalKey(debugLabel: "test_document-layout");
  final iOSControlsController = SuperEditorIosControlsControllerWithNativePaste(
    editor: editor,
    documentLayoutResolver: () => documentLayoutKey.currentState! as DocumentLayout,
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SuperEditorIosControlsScope(
          controller: iOSControlsController,
          child: SuperEditor(
            editor: editor,
            documentLayoutKey: documentLayoutKey,
          ),
        ),
      ),
    ),
  );
}
