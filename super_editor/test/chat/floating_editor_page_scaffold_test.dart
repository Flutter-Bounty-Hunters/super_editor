import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/test/super_editor_test/supereditor_robot.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_keyboard/super_keyboard_test.dart';

import '../infrastructure/keyboard_panel_scaffold_test.dart';

void main() {
  group('Floating editor page scaffold >', () {
    group('keyboard panel >', () {
      testWidgetsOnMobilePhone('holds the sheet above the panel while the keyboard replaces it', (tester) async {
        final pageController = await _pumpScaffold(tester, animateKeyboard: true);

        // Open the keyboard, and then replace it with a panel.
        await tester.placeCaretInParagraph('1', 0);
        await tester.pumpAndSettle();
        pageController.showKeyboardPanel(_Panel.panel1);
        await tester.pumpAndSettle();

        // Ensure the sheet sits on top of the panel.
        expect(tester.getBottomLeft(find.byKey(_editorSheetKey)).dy, _screenHeight(tester) - _keyboardHeight);

        // Start replacing the panel with the keyboard, and stop halfway through
        // the keyboard's opening animation.
        pageController.showSoftwareKeyboard();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Ensure the panel is still visible, and the sheet still sits on top of it,
        // rather than dropping down to the partially open keyboard.
        expect(find.byKey(_keyboardPanelKey), findsOneWidget);
        expect(tester.getBottomLeft(find.byKey(_editorSheetKey)).dy, _screenHeight(tester) - _keyboardHeight);

        await tester.pumpAndSettle();

        // Ensure the panel is gone, and the sheet sits on top of the keyboard.
        expect(find.byKey(_keyboardPanelKey), findsNothing);
        expect(tester.getBottomLeft(find.byKey(_editorSheetKey)).dy, _screenHeight(tester) - _keyboardHeight);
      });

      testWidgetsOnMobilePhone('moves the sheet to the bottom when the keyboard closes after replacing the panel',
          (tester) async {
        final pageController = await _pumpScaffold(tester);

        // Open the keyboard, replace it with a panel, and then replace the panel
        // with the keyboard.
        await tester.placeCaretInParagraph('1', 0);
        pageController.showKeyboardPanel(_Panel.panel1);
        await tester.pumpAndSettle();
        pageController.showSoftwareKeyboard();
        await tester.pumpAndSettle();

        // Ensure the panel is gone, and the sheet sits on top of the keyboard.
        expect(find.byKey(_keyboardPanelKey), findsNothing);
        expect(tester.getBottomLeft(find.byKey(_editorSheetKey)).dy, _screenHeight(tester) - _keyboardHeight);

        // Close the keyboard without going through the page controller, similar
        // to the OS closing the keyboard when the user presses the back button, or
        // goes to the home screen.
        await _closeKeyboardOutsideOfScaffold(tester);

        // Ensure the sheet moved down to the bottom of the screen, rather than
        // remaining where the (now removed) panel used to be.
        expect(tester.getBottomLeft(find.byKey(_editorSheetKey)).dy, _screenHeight(tester));
      });

      testWidgetsOnMobilePhone('moves the sheet to the bottom when the keyboard closes after toggling the panel off',
          (tester) async {
        final pageController = await _pumpScaffold(tester);

        // Open the keyboard, replace it with a panel, and then toggle the panel off,
        // which brings the keyboard back up.
        await tester.placeCaretInParagraph('1', 0);
        pageController.showKeyboardPanel(_Panel.panel1);
        await tester.pumpAndSettle();
        pageController.toggleKeyboardPanel(_Panel.panel1);
        await tester.pumpAndSettle();

        // Ensure the panel is gone, and the sheet sits on top of the keyboard.
        expect(find.byKey(_keyboardPanelKey), findsNothing);
        expect(tester.getBottomLeft(find.byKey(_editorSheetKey)).dy, _screenHeight(tester) - _keyboardHeight);

        // Close the keyboard without going through the page controller.
        await _closeKeyboardOutsideOfScaffold(tester);

        // Ensure the sheet moved down to the bottom of the screen.
        expect(tester.getBottomLeft(find.byKey(_editorSheetKey)).dy, _screenHeight(tester));
      });

      testWidgetsOnMobilePhone('animates the next panel up after the keyboard replaced the previous panel',
          (tester) async {
        final pageController = await _pumpScaffold(tester);

        // Open the keyboard, replace it with a panel, replace the panel with the
        // keyboard, and then close the keyboard.
        await tester.placeCaretInParagraph('1', 0);
        pageController.showKeyboardPanel(_Panel.panel1);
        await tester.pumpAndSettle();
        pageController.showSoftwareKeyboard();
        await tester.pumpAndSettle();
        await _closeKeyboardOutsideOfScaffold(tester);

        // Show a panel while the keyboard is closed, and stop partway through the
        // panel's entrance animation.
        pageController.showKeyboardPanel(_Panel.panel1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 125));

        // Ensure the panel is animating up from the bottom, rather than popping in
        // at full height.
        expect(tester.getSize(find.byKey(_keyboardPanelKey)).height, greaterThan(0));
        expect(tester.getSize(find.byKey(_keyboardPanelKey)).height, lessThan(_keyboardHeight));

        await tester.pumpAndSettle();

        // Ensure the panel ends at full height, with the sheet on top of it.
        expect(tester.getSize(find.byKey(_keyboardPanelKey)).height, _keyboardHeight);
        expect(tester.getBottomLeft(find.byKey(_editorSheetKey)).dy, _screenHeight(tester) - _keyboardHeight);
      });

      testWidgetsOnMobilePhone('moves the sheet down with the panel as the panel closes', (tester) async {
        final pageController = await _pumpScaffold(tester);

        // Open the keyboard, replace it with a panel, and then close the keyboard
        // connection so that only the panel is showing.
        await tester.placeCaretInParagraph('1', 0);
        pageController.showKeyboardPanel(_Panel.panel1);
        await tester.pumpAndSettle();

        // Start closing the panel, and stop partway through the exit animation.
        pageController.hideKeyboardPanel();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 125));

        // Ensure the panel is still visible, and the sheet is moving down with it.
        expect(find.byKey(_keyboardPanelKey), findsOneWidget);
        final panelHeight = tester.getSize(find.byKey(_keyboardPanelKey)).height;
        expect(panelHeight, greaterThan(0));
        expect(panelHeight, lessThan(_keyboardHeight));
        expect(tester.getBottomLeft(find.byKey(_editorSheetKey)).dy, _screenHeight(tester) - panelHeight);

        await tester.pumpAndSettle();

        // Ensure the panel is gone, and the sheet sits at the bottom of the screen.
        expect(find.byKey(_keyboardPanelKey), findsNothing);
        expect(tester.getBottomLeft(find.byKey(_editorSheetKey)).dy, _screenHeight(tester));
      });
    });
  });
}

/// Pumps a [FloatingEditorPageScaffold] whose editor sheet contains a chat editor,
/// with a simulated software keyboard, and returns the scaffold's page controller.
Future<FloatingEditorPageController<_Panel>> _pumpScaffold(
  WidgetTester tester, {
  bool animateKeyboard = false,
}) async {
  final editor = createDefaultChatEditor(
    document: MutableDocument(
      nodes: [
        ParagraphNode(id: '1', text: AttributedText('This is a chat message.')),
      ],
    ),
  );
  final pageController = FloatingEditorPageController<_Panel>(SoftwareKeyboardController());
  addTearDown(pageController.dispose);

  await tester.pumpWidget(
    MaterialApp(
      home: SoftwareKeyboardHeightSimulator(
        keyboardHeight: _keyboardHeight,
        animateKeyboard: animateKeyboard,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          body: FloatingEditorPageScaffold<_Panel>(
            pageController: pageController,
            softwareKeyboardController: pageController.softwareKeyboardController,
            // Remove the margin so that the sheet's bottom edge sits directly on top
            // of whatever is beneath it, e.g., the bottom of the screen, the keyboard,
            // or a panel.
            editorSheetMargin: EdgeInsets.zero,
            pageBuilder: (context, pageGeometry) => const SizedBox(),
            editorSheet: ColoredBox(
              key: _editorSheetKey,
              color: Colors.white,
              child: BottomSheetEditorHeight(
                previewHeight: 32,
                child: SuperChatEditor(
                  editor: editor,
                  pageController: pageController,
                  softwareKeyboardController: pageController.softwareKeyboardController,
                ),
              ),
            ),
            keyboardPanelBuilder: (context, panel) {
              return const ColoredBox(
                key: _keyboardPanelKey,
                color: Colors.blue,
              );
            },
          ),
        ),
      ),
    ),
  );

  return pageController;
}

/// Closes the software keyboard without going through the scaffold's page controller,
/// similar to the OS closing the keyboard when the user presses the back button, or
/// goes to the home screen.
///
/// The IME connection remains open, just like it does on Android when the OS closes
/// the keyboard.
Future<void> _closeKeyboardOutsideOfScaffold(WidgetTester tester) async {
  await SystemChannels.textInput.invokeMethod('TextInput.hide');
  await tester.pumpAndSettle();
}

double _screenHeight(WidgetTester tester) => tester.getSize(find.byType(MaterialApp)).height;

// Simulated height of a fully visible phone keyboard. Keyboard panels take on the
// height of the keyboard, so this is also the full height of a keyboard panel.
const _keyboardHeight = 300.0;

const _editorSheetKey = ValueKey('editorSheet');
const _keyboardPanelKey = ValueKey('keyboardPanel');

enum _Panel {
  panel1,
}
