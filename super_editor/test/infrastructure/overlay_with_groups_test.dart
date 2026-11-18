import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group('GroupedOverlayPortalController >', () {
    group("doesn't show a removed OverlayPortal again when another grouped overlay shows", () {
      testWidgets('after the OverlayPortal is added back', (tester) async {
        final appController = GroupedOverlayPortalController(displayPriority: OverlayGroupPriority.editingControls);
        final otherOverlay = _OtherOverlay();

        // Show the app's overlay.
        await tester.pumpWidget(_buildAppScreen(appController, otherOverlay, isAppPortalInTree: true));
        appController.show();
        await tester.pump();

        // Ensure that the app's overlay shows.
        expect(find.text(_appOverlayText), findsOneWidget, reason: "The app's overlay should show");

        // Remove the app's OverlayPortal, and add it back.
        await tester.pumpWidget(_buildAppScreen(appController, otherOverlay, isAppPortalInTree: false));
        await tester.pumpWidget(_buildAppScreen(appController, otherOverlay, isAppPortalInTree: true));

        // Ensure that the app's overlay doesn't show.
        expect(find.text(_appOverlayText), findsNothing, reason: "A re-added OverlayPortal shouldn't show its overlay");

        // Show another grouped overlay.
        otherOverlay.controller.show();
        await tester.pump();

        // Ensure that the app's overlay still doesn't show.
        expect(
          find.text(_appOverlayText),
          findsNothing,
          reason: "Showing another grouped overlay shouldn't show the app's overlay",
        );

        // Hide the other overlay, so that no grouped controller stays visible for the next test.
        otherOverlay.controller.hide();
      });

      testWidgets('while the OverlayPortal is removed', (tester) async {
        final appController = GroupedOverlayPortalController(displayPriority: OverlayGroupPriority.editingControls);
        final otherOverlay = _OtherOverlay();

        // Show the app's overlay.
        await tester.pumpWidget(_buildAppScreen(appController, otherOverlay, isAppPortalInTree: true));
        appController.show();
        await tester.pump();

        // Ensure that the app's overlay shows.
        expect(find.text(_appOverlayText), findsOneWidget, reason: "The app's overlay should show");

        // Remove the app's OverlayPortal.
        await tester.pumpWidget(_buildAppScreen(appController, otherOverlay, isAppPortalInTree: false));

        // Show another grouped overlay.
        otherOverlay.controller.show();
        await tester.pump();

        // Add the app's OverlayPortal back.
        await tester.pumpWidget(_buildAppScreen(appController, otherOverlay, isAppPortalInTree: true));

        // Ensure that the app's overlay doesn't show.
        expect(
          find.text(_appOverlayText),
          findsNothing,
          reason:
              "Showing another grouped overlay shouldn't show the app's overlay when its OverlayPortal is added back",
        );

        // Hide the other overlay, so that no grouped controller stays visible for the next test.
        otherOverlay.controller.hide();
      });
    });

    testWidgetsOnMobile("doesn't show a removed KeyboardEditingToolbar's overlay again", (tester) async {
      final editor = _createEditor();
      addTearDown(editor.dispose);
      final documentLayoutKey = GlobalKey();
      final otherOverlay = _OtherOverlay();

      // Show the toolbar, which shows its overlay.
      await tester.pumpWidget(_buildToolbarScreen(editor, documentLayoutKey, otherOverlay, isToolbarShown: true));
      final toolbarOverlayController = _findGroupedOverlayController(tester, find.byType(KeyboardEditingToolbar));

      // Ensure that the toolbar shows its overlay.
      expect(toolbarOverlayController.isShowing, isTrue, reason: 'The toolbar should show its overlay');

      // Remove the toolbar while its overlay shows.
      await tester.pumpWidget(_buildToolbarScreen(editor, documentLayoutKey, otherOverlay, isToolbarShown: false));

      // Show another grouped overlay.
      otherOverlay.controller.show();
      await tester.pump();

      // Ensure that the removed toolbar's controller wasn't shown again.
      expect(
        toolbarOverlayController.isShowing,
        isFalse,
        reason: "Showing another grouped overlay shouldn't show the removed toolbar's controller",
      );

      // Hide the other overlay, so that no grouped controller stays visible for the next test.
      otherOverlay.controller.hide();
    });

    testWidgetsOnAndroid("doesn't show a removed SuperReader's controls overlay again", (tester) async {
      // Only the Android reader shows its controls with a GroupedOverlayPortalController.
      final editor = _createEditor();
      addTearDown(editor.dispose);
      final otherOverlay = _OtherOverlay();

      // Show a focused reader, which shows its controls overlay.
      await tester.pumpWidget(_buildReaderScreen(editor, otherOverlay, isReaderShown: true));
      await tester.pump();
      final readerOverlayController = _findGroupedOverlayController(tester, find.byType(SuperReader));

      // Ensure that the reader shows its controls overlay.
      expect(readerOverlayController.isShowing, isTrue, reason: 'The focused reader should show its controls');

      // Remove the reader while its controls overlay shows.
      await tester.pumpWidget(_buildReaderScreen(editor, otherOverlay, isReaderShown: false));

      // Show another grouped overlay.
      otherOverlay.controller.show();
      await tester.pump();

      // Ensure that the removed reader's controller wasn't shown again.
      expect(
        readerOverlayController.isShowing,
        isFalse,
        reason: "Showing another grouped overlay shouldn't show the removed reader's controller",
      );

      // Hide the other overlay, so that no grouped controller stays visible for the next test.
      otherOverlay.controller.hide();
    });
  });
}

const _appOverlayText = 'App overlay';

/// Builds a screen with [otherOverlay], and with an [OverlayPortal] for [appController] when
/// [isAppPortalInTree] is `true`.
Widget _buildAppScreen(
  GroupedOverlayPortalController appController,
  _OtherOverlay otherOverlay, {
  required bool isAppPortalInTree,
}) {
  return MaterialApp(
    home: Scaffold(
      body: otherOverlay.build(
        isAppPortalInTree
            ? OverlayPortal(
                controller: appController,
                overlayChildBuilder: (_) => const Text(_appOverlayText),
                child: const SizedBox(),
              )
            : const SizedBox(),
      ),
    ),
  );
}

Editor _createEditor() {
  return createDefaultDocumentEditor(
    document: MutableDocument(
      nodes: [
        ParagraphNode(id: '1', text: AttributedText('A paragraph.')),
      ],
    ),
    composer: MutableDocumentComposer(
      initialSelection: const DocumentSelection.collapsed(
        position: DocumentPosition(nodeId: '1', nodePosition: TextNodePosition(offset: 0)),
      ),
    ),
  );
}

/// Finds the [GroupedOverlayPortalController] of the [OverlayPortal] below [owner].
GroupedOverlayPortalController _findGroupedOverlayController(WidgetTester tester, Finder owner) {
  final overlayPortal = tester.widget<OverlayPortal>(
    find.descendant(
      of: owner,
      matching: find.byWidgetPredicate(
        (widget) => widget is OverlayPortal && widget.controller is GroupedOverlayPortalController,
      ),
    ),
  );
  return overlayPortal.controller as GroupedOverlayPortalController;
}

/// Builds a screen with [otherOverlay] and a [SuperEditor] for [editor], whose document layout
/// has the [documentLayoutKey], with a [KeyboardEditingToolbar] below it when [isToolbarShown]
/// is `true`.
Widget _buildToolbarScreen(
  Editor editor,
  GlobalKey documentLayoutKey,
  _OtherOverlay otherOverlay, {
  required bool isToolbarShown,
}) {
  return MaterialApp(
    home: Scaffold(
      body: otherOverlay.build(
        Column(
          children: [
            Expanded(
              child: SuperEditor(
                editor: editor,
                documentLayoutKey: documentLayoutKey,
              ),
            ),
            if (isToolbarShown)
              KeyboardEditingToolbar(
                editor: editor,
                document: editor.document,
                composer: editor.composer,
                commonOps: CommonEditorOperations(
                  editor: editor,
                  document: editor.document,
                  composer: editor.composer,
                  documentLayoutResolver: () => documentLayoutKey.currentState as DocumentLayout,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Builds a screen with [otherOverlay], and with a focused [SuperReader] for [editor] when
/// [isReaderShown] is `true`.
Widget _buildReaderScreen(Editor editor, _OtherOverlay otherOverlay, {required bool isReaderShown}) {
  return MaterialApp(
    home: Scaffold(
      body: otherOverlay.build(
        isReaderShown ? SuperReader(editor: editor, autofocus: true) : const SizedBox(),
      ),
    ),
  );
}

/// An overlay that a test shows with a [GroupedOverlayPortalController] of its own.
class _OtherOverlay {
  final controller = GroupedOverlayPortalController(displayPriority: OverlayGroupPriority.windowChrome);

  /// Builds an [OverlayPortal] for the [controller] around [child].
  Widget build(Widget child) {
    return OverlayPortal(
      controller: controller,
      overlayChildBuilder: (_) => const Text('Other overlay'),
      child: child,
    );
  }
}
