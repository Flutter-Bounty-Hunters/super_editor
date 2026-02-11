import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/src/test/super_editor_test/supereditor_robot.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

void main() {
  group('Keyboard panel scaffold >', () {
    group('phones >', () {
      testWidgetsOnMobilePhone('does not show toolbar upon initialization when IME is disconnected', (tester) async {
        await _pumpTestAppWithTabsAndMultipleSafeAreaScopes(tester);

        // Ensure the toolbar isn't visible.
        expect(find.byKey(_aboveKeyboardToolbarKey), findsNothing);
      });

      testWidgetsOnMobilePhone('shows toolbar at the bottom when there is no keyboard', (tester) async {
        final softwareKeyboardController = SoftwareKeyboardController();
        final controller = KeyboardPanelController(softwareKeyboardController);

        await _pumpTestAppWithTabsAndMultipleSafeAreaScopes(
          tester,
          controller: controller,
          softwareKeyboardController: softwareKeyboardController,
        );

        // Request to show the above-keyboard toolbar.
        controller.showToolbar();
        await tester.pump();

        // Ensure the above-keyboard toolbar sits at the bottom of the screen.
        expect(
          tester.getBottomLeft(find.byKey(_aboveKeyboardToolbarKey)).dy,
          equals(tester.getSize(find.byType(MaterialApp)).height),
        );
      });

      testWidgetsOnMobilePhone('shows keyboard toolbar above the keyboard', (tester) async {
        final softwareKeyboardController = SoftwareKeyboardController();
        final controller = KeyboardPanelController(softwareKeyboardController);

        await _pumpTestAppWithTabsAndMultipleSafeAreaScopes(
          tester,
          controller: controller,
          softwareKeyboardController: softwareKeyboardController,
        );

        // Request to show the above-keyboard panel.
        controller.showToolbar();
        await tester.pump();

        // Place the caret at the beginning of the document to show the software keyboard.
        await tester.placeCaretInParagraph('1', 0);

        // Ensure the above-keyboard panel sits above the software keyboard.
        expect(
          tester.getBottomLeft(find.byKey(_aboveKeyboardToolbarKey)).dy,
          equals(tester.getSize(find.byType(MaterialApp)).height - _expandedPhoneKeyboardHeight),
        );
      });

      testWidgetsOnMobilePhone('shows content above the toolbar and keyboard when at bottom of screen', (tester) async {
        final softwareKeyboardController = SoftwareKeyboardController();
        final controller = KeyboardPanelController(softwareKeyboardController);

        await _pumpTestAppWithTabsAndMultipleSafeAreaScopes(
          tester,
          controller: controller,
          softwareKeyboardController: softwareKeyboardController,
        );

        // Request to show the above-keyboard panel.
        controller.showToolbar();
        await tester.pump();

        // Place the caret at the beginning of the document to show the software keyboard.
        await tester.placeCaretInParagraph('1', 0);

        // Ensure the editor sits just above the keyboard + toolbar.
        expect(
          tester.getBottomLeft(find.byType(SuperEditor)).dy,
          equals(tester.getSize(find.byType(MaterialApp)).height - _expandedPhoneKeyboardHeight - _toolbarHeight),
        );
      });

      testWidgetsOnMobilePhone('shows content above the toolbar and keyboard when above bottom of screen',
          (tester) async {
        final softwareKeyboardController = SoftwareKeyboardController();
        final controller = KeyboardPanelController(softwareKeyboardController);

        await _pumpTestAppWithTabsAndMultipleSafeAreaScopes(
          tester,
          controller: controller,
          softwareKeyboardController: softwareKeyboardController,
          // Push the editor up a bit.
          widgetBelowEditor: Container(
            width: double.infinity,
            height: 100,
            color: Colors.red,
          ),
        );

        // Request to show the above-keyboard panel.
        controller.showToolbar();
        await tester.pump();

        // Place the caret at the beginning of the document to show the software keyboard.
        await tester.placeCaretInParagraph('1', 0);

        // Ensure the editor sits just above the keyboard + toolbar, and there's
        // no extra space caused by the widget below the editor.
        expect(
          tester.getBottomLeft(find.byType(SuperEditor)).dy,
          equals(tester.getSize(find.byType(MaterialApp)).height - _expandedPhoneKeyboardHeight - _toolbarHeight),
        );
      });

      testWidgetsOnMobilePhone(
        'shows keyboard toolbar above the keyboard when toggling panels and showing the keyboard',
        (tester) async {
          final softwareKeyboardController = SoftwareKeyboardController();
          final controller = KeyboardPanelController(softwareKeyboardController);

          await _pumpTestAppWithTabsAndMultipleSafeAreaScopes(
            tester,
            controller: controller,
            softwareKeyboardController: softwareKeyboardController,
          );

          // Request to show the above-keyboard panel.
          controller.showToolbar();
          await tester.pump();

          // Place the caret at the beginning of the document to show the software keyboard.
          await tester.placeCaretInParagraph('1', 0);

          // Request to show the keyboard panel.
          controller.showKeyboardPanel(_Panel.panel1);
          await tester.pumpAndSettle();

          // Hide both the keyboard panel and the software keyboard.
          controller.closeKeyboardAndPanel();
          await tester.pumpAndSettle();

          // Place the caret at the beginning of the document to show the software keyboard again.
          await tester.placeCaretInParagraph('1', 0);

          // Ensure the top panel sits above the keyboard.
          expect(
            tester.getBottomLeft(find.byKey(_aboveKeyboardToolbarKey)).dy,
            equals(tester.getSize(find.byType(MaterialApp)).height - _expandedPhoneKeyboardHeight),
          );
        },
      );

      testWidgetsOnMobilePhone('does not show keyboard panel upon keyboard appearance', (tester) async {
        await _pumpTestAppWithTabsAndMultipleSafeAreaScopes(tester);

        // Place the caret at the beginning of the document to show the software keyboard.
        await tester.placeCaretInParagraph('1', 0);

        // Ensure the keyboard panel is not visible.
        expect(find.byKey(_keyboardPanelKey), findsNothing);
      });

      testWidgetsOnMobilePhone('shows keyboard panel upon request', (tester) async {
        final softwareKeyboardController = SoftwareKeyboardController();
        final controller = KeyboardPanelController(softwareKeyboardController);

        await _pumpTestAppWithTabsAndMultipleSafeAreaScopes(
          tester,
          controller: controller,
          softwareKeyboardController: softwareKeyboardController,
        );

        // Place the caret at the beginning of the document to show the software keyboard.
        await tester.placeCaretInParagraph('1', 0);

        // Request to show the keyboard panel.
        controller.showKeyboardPanel(_Panel.panel1);
        await tester.pumpAndSettle();

        // Ensure the keyboard panel is visible.
        expect(find.byKey(_keyboardPanelKey), findsOneWidget);
      });

      testWidgetsOnMobilePhone('displays panel with the same height as the keyboard', (tester) async {
        final softwareKeyboardController = SoftwareKeyboardController();
        final controller = KeyboardPanelController(softwareKeyboardController);

        await _pumpTestAppWithTabsAndMultipleSafeAreaScopes(
          tester,
          controller: controller,
          softwareKeyboardController: softwareKeyboardController,
        );

        // Request to show the above-keyboard panel.
        controller.showToolbar();
        await tester.pump();

        // Place the caret at the beginning of the document to show the software keyboard.
        await tester.placeCaretInParagraph('1', 0);

        // Request to show the keyboard panel and let the entrance animation run.
        controller.showKeyboardPanel(_Panel.panel1);
        await tester.pumpAndSettle();

        // Ensure the keyboard panel has the same size as the software keyboard.
        expect(
          tester.getSize(find.byKey(_keyboardPanelKey)).height,
          equals(_expandedPhoneKeyboardHeight),
        );

        // Ensure the above-keyboard panel sits immediately above the keyboard panel.
        expect(
          tester.getBottomLeft(find.byKey(_aboveKeyboardToolbarKey)).dy,
          equals(tester.getSize(find.byType(MaterialApp)).height - _expandedPhoneKeyboardHeight),
        );
      });

      testWidgetsOnMobilePhone('hides the panel when showing the keyboard', (tester) async {
        final softwareKeyboardController = SoftwareKeyboardController();
        final controller = KeyboardPanelController(softwareKeyboardController);

        await _pumpTestAppWithTabsAndMultipleSafeAreaScopes(
          tester,
          controller: controller,
          softwareKeyboardController: softwareKeyboardController,
        );

        // Request to show the toolbar.
        controller.showToolbar();
        await tester.pump();

        // Place the caret at the beginning of the document to show the software keyboard.
        await tester.placeCaretInParagraph('1', 0);

        // Request to show the keyboard panel and let the entrance animation run.
        controller.showKeyboardPanel(_Panel.panel1);
        await tester.pumpAndSettle();

        // Ensure the keyboard panel is visible.
        expect(find.byKey(_keyboardPanelKey), findsOneWidget);

        // Hide the keyboard panel and show the software keyboard.
        controller.showSoftwareKeyboard();
        await tester.pumpAndSettle();

        // Ensure the keyboard panel is not visible.
        expect(find.byKey(_keyboardPanelKey), findsNothing);

        // Ensure the toolbar sits immediately above the keyboard.
        expect(
          tester.getBottomLeft(find.byKey(_aboveKeyboardToolbarKey)).dy,
          equals(tester.getSize(find.byType(MaterialApp)).height - _expandedPhoneKeyboardHeight),
        );
      });

      testWidgetsOnMobilePhone('hides the panel upon request', (tester) async {
        final softwareKeyboardController = SoftwareKeyboardController();
        final controller = KeyboardPanelController(softwareKeyboardController);

        await _pumpTestAppWithTabsAndMultipleSafeAreaScopes(
          tester,
          controller: controller,
          softwareKeyboardController: softwareKeyboardController,
        );

        // Request to show the above-keyboard panel.
        controller.showToolbar();
        await tester.pump();

        // Place the caret at the beginning of the document to show the software keyboard.
        await tester.placeCaretInParagraph('1', 0);

        // Request to show the keyboard panel and let the entrance animation run.
        controller.showKeyboardPanel(_Panel.panel1);
        await tester.pumpAndSettle();

        // Ensure the keyboard panel is visible.
        expect(find.byKey(_keyboardPanelKey), findsOneWidget);

        controller.closeKeyboardAndPanel();
        await tester.pumpAndSettle();

        // Ensure the keyboard panel is not visible.
        expect(find.byKey(_keyboardPanelKey), findsNothing);

        // Ensure the above-keyboard panel sits at the bottom of the screen.
        expect(
          tester.getBottomLeft(find.byKey(_aboveKeyboardToolbarKey)).dy,
          equals(tester.getSize(find.byType(MaterialApp)).height),
        );
      });

      testWidgetsOnMobilePhone('hides the panel when IME connection closes', (tester) async {
        final softwareKeyboardController = SoftwareKeyboardController();
        final controller = KeyboardPanelController(softwareKeyboardController);

        await _pumpTestAppWithTabsAndMultipleSafeAreaScopes(
          tester,
          controller: controller,
          softwareKeyboardController: softwareKeyboardController,
        );

        // Request to show the keyboard toolbar.
        controller.showToolbar();
        await tester.pump();

        // Place the caret at the beginning of the document to open the IME connection.
        await tester.placeCaretInParagraph('1', 0);

        // Request to show the keyboard panel and let the entrance animation run.
        controller.showKeyboardPanel(_Panel.panel1);
        await tester.pumpAndSettle();

        // Ensure the keyboard panel is visible.
        expect(find.byKey(_keyboardPanelKey), findsOneWidget);

        // Close the IME connection.
        softwareKeyboardController.close();
        await tester.pumpAndSettle();

        // Ensure the keyboard panel is not visible.
        expect(find.byKey(_keyboardPanelKey), findsNothing);
      });

      testWidgetsOnMobilePhone('shows toolbar at the bottom after closing the panel and the keyboard', (tester) async {
        final softwareKeyboardController = SoftwareKeyboardController();
        final controller = KeyboardPanelController(softwareKeyboardController);

        await _pumpTestAppWithTabsAndMultipleSafeAreaScopes(
          tester,
          controller: controller,
          softwareKeyboardController: softwareKeyboardController,
        );

        // Request to show the above-keyboard toolbar.
        controller.showToolbar();
        await tester.pump();

        // Place the caret at the beginning of the document to show the software keyboard.
        await tester.placeCaretInParagraph('1', 0);

        // Request to show the keyboard panel and let the entrance animation run.
        controller.showKeyboardPanel(_Panel.panel1);
        await tester.pumpAndSettle();

        // Ensure the keyboard panel is visible.
        expect(find.byKey(_keyboardPanelKey), findsOneWidget);

        // Hide the keyboard panel and the software keyboard.
        controller.closeKeyboardAndPanel();
        await tester.pumpAndSettle();

        // Ensure the keyboard panel is not visible.
        expect(find.byKey(_keyboardPanelKey), findsNothing);

        // Ensure the above-keyboard toolbar sits at the bottom of the screen.
        expect(
          tester.getBottomLeft(find.byKey(_aboveKeyboardToolbarKey)).dy,
          tester.getSize(find.byType(MaterialApp)).height,
        );
      });
    });

    group('iPad >', () {
      testWidgetsOnIPad('shows panel when keyboard is docked', (tester) async {
        final softwareKeyboardController = SoftwareKeyboardController();
        final controller = KeyboardPanelController(softwareKeyboardController);

        await _pumpTestAppWithTabsAndMultipleSafeAreaScopes(
          tester,
          controller: controller,
          softwareKeyboardController: softwareKeyboardController,
          simulatedKeyboardHeight: _expandedIPadKeyboardHeight,
        );

        // Place the caret at the beginning of the document to show the software keyboard.
        await tester.placeCaretInParagraph('1', 0);

        // Request to show the keyboard panel and let the entrance animation run.
        controller.showKeyboardPanel(_Panel.panel1);
        await tester.pumpAndSettle();

        // Ensure the keyboard panel is visible.
        expect(find.byKey(_keyboardPanelKey), findsOneWidget);

        final panelSize = tester.getSize(find.byKey(_keyboardPanelKey));
        expect(panelSize.height, _expandedIPadKeyboardHeight);
      });

      testWidgetsOnIPad('shows and closes panel when keyboard is floating or minimized', (tester) async {
        final softwareKeyboardController = SoftwareKeyboardController();
        final controller = KeyboardPanelController(softwareKeyboardController);

        await _pumpTestAppWithTabsAndMultipleSafeAreaScopes(
          tester,
          controller: controller,
          softwareKeyboardController: softwareKeyboardController,
          simulatedKeyboardHeight: _minimizedIPadKeyboardHeight,
        );

        // Place the caret at the beginning of the document to show the software keyboard.
        await tester.placeCaretInParagraph('1', 0);

        // Ensure the toolbar is above the minimized keyboard area.
        final screenHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;
        expect(
          tester.getBottomLeft(find.byKey(_aboveKeyboardToolbarKey)).dy,
          screenHeight - _minimizedIPadKeyboardHeight,
        );

        // Request to show the keyboard panel and let the entrance animation run.
        controller.showKeyboardPanel(_Panel.panel1);
        await tester.pumpAndSettle();

        // Ensure the keyboard panel is visible and positioned at the bottom of the screen.
        expect(find.byKey(_keyboardPanelKey), findsOneWidget);

        final panelSize = tester.getSize(find.byKey(_keyboardPanelKey));
        expect(panelSize.height, _keyboardPanelHeight);

        expect(
          tester.getBottomLeft(find.byKey(_keyboardPanelKey)).dy,
          screenHeight,
        );

        // Ensure the toolbar is above the panel.
        expect(
          tester.getBottomLeft(find.byKey(_aboveKeyboardToolbarKey)).dy,
          screenHeight - _keyboardPanelHeight,
        );

        // Request to hide the keyboard panel.
        controller.hideKeyboardPanel();
        await tester.pumpAndSettle();

        // Ensure the keyboard panel is gone.
        expect(find.byKey(_keyboardPanelKey), findsNothing);

        // Ensure the toolbar is above the minimized keyboard area.
        expect(
          tester.getBottomLeft(find.byKey(_aboveKeyboardToolbarKey)).dy,
          screenHeight - _minimizedIPadKeyboardHeight,
        );
      });
    });

    group('Android tablets >', () {
      testWidgetsOnAndroidTablet('shows panel when keyboard is docked', (tester) async {
        final softwareKeyboardController = SoftwareKeyboardController();
        final controller = KeyboardPanelController(softwareKeyboardController);

        await _pumpTestAppWithTabsAndMultipleSafeAreaScopes(
          tester,
          controller: controller,
          softwareKeyboardController: softwareKeyboardController,
          simulatedKeyboardHeight: _expandedAndroidTabletKeyboardHeight,
        );

        // Place the caret at the beginning of the document to show the software keyboard.
        await tester.placeCaretInParagraph('1', 0);

        // Request to show the keyboard panel and let the entrance animation run.
        controller.showKeyboardPanel(_Panel.panel1);
        await tester.pumpAndSettle();

        // Ensure the keyboard panel is visible.
        expect(find.byKey(_keyboardPanelKey), findsOneWidget);

        final panelSize = tester.getSize(find.byKey(_keyboardPanelKey));
        expect(panelSize.height, _expandedAndroidTabletKeyboardHeight);
      });

      testWidgetsOnAndroidTablet('shows panel when keyboard is floating or minimized', (tester) async {
        final softwareKeyboardController = SoftwareKeyboardController();
        final controller = KeyboardPanelController(softwareKeyboardController);

        await _pumpTestAppWithTabsAndMultipleSafeAreaScopes(
          tester,
          controller: controller,
          softwareKeyboardController: softwareKeyboardController,
          simulatedKeyboardHeight: _minimizedAndroidTabletKeyboardHeight,
        );

        // Place the caret at the beginning of the document to show the software keyboard.
        await tester.placeCaretInParagraph('1', 0);

        // Ensure the toolbar is above the minimized keyboard area.
        final screenHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;
        expect(
          tester.getBottomLeft(find.byKey(_aboveKeyboardToolbarKey)).dy,
          screenHeight - _minimizedAndroidTabletKeyboardHeight,
        );

        // Request to show the keyboard panel and let the entrance animation run.
        controller.showKeyboardPanel(_Panel.panel1);
        await tester.pumpAndSettle();

        // Ensure the keyboard panel is visible and positioned at the bottom of the screen.
        expect(find.byKey(_keyboardPanelKey), findsOneWidget);

        final panelSize = tester.getSize(find.byKey(_keyboardPanelKey));
        expect(panelSize.height, _keyboardPanelHeight);

        expect(
          tester.getBottomLeft(find.byKey(_keyboardPanelKey)).dy,
          screenHeight,
        );

        // Ensure the toolbar is above the panel.
        expect(
          tester.getBottomLeft(find.byKey(_aboveKeyboardToolbarKey)).dy,
          screenHeight - _keyboardPanelHeight,
        );

        // Request to hide the keyboard panel.
        controller.hideKeyboardPanel();
        await tester.pumpAndSettle();

        // Ensure the keyboard panel is gone.
        expect(find.byKey(_keyboardPanelKey), findsNothing);

        // Ensure the toolbar is above the minimized keyboard area.
        expect(
          tester.getBottomLeft(find.byKey(_aboveKeyboardToolbarKey)).dy,
          screenHeight - _minimizedAndroidTabletKeyboardHeight,
        );
      });
    });

    group('safe area >', () {
      testWidgetsOnMobilePhone('makes room for keyboard panel (with single scope)', (tester) async {
        final softwareKeyboardController = SoftwareKeyboardController();
        final keyboardPanelController = KeyboardPanelController(softwareKeyboardController);
        final imeConnectionNotifier = ValueNotifier<bool>(false);

        await _pumpTestAppWithSingleSafeAreaScope(
          tester,
          softwareKeyboardController: softwareKeyboardController,
          keyboardPanelController: keyboardPanelController,
          isImeConnected: imeConnectionNotifier,
        );

        // Record the height of the content when no keyboard or panel is open.
        final contentHeightWithNoKeyboard = tester.getSize(find.byKey(_chatPageKey)).height;

        // Show the keyboard.
        await tester.placeCaretInParagraph("1", 0);
        await tester.pumpAndSettle();

        // Record the height of the content now that the keyboard is open.
        final contentHeightWithKeyboardOpen = tester.getSize(find.byKey(_chatPageKey)).height;

        // Ensure that the content is pushed up above the keyboard + toolbar.
        expect(
          contentHeightWithNoKeyboard - contentHeightWithKeyboardOpen,
          _toolbarHeight + _expandedPhoneKeyboardHeight,
        );
      });

      testWidgetsOnMobilePhone('makes room for keyboard panel (with multiple scopes)', (tester) async {
        final softwareKeyboardController = SoftwareKeyboardController();
        final controller = KeyboardPanelController(softwareKeyboardController);

        await _pumpTestAppWithTabsAndMultipleSafeAreaScopes(
          tester,
          controller: controller,
          softwareKeyboardController: softwareKeyboardController,
          simulatedKeyboardHeight: _expandedPhoneKeyboardHeight,
        );

        // Record the height of the content when no keyboard or panel is open.
        final contentHeightWithNoKeyboard = tester.getSize(find.byKey(_chatPageKey)).height;

        // Show a keyboard panel (not the keyboard).
        controller.showKeyboardPanel(_Panel.panel1);
        await tester.pumpAndSettle();

        // Record the height of the content now that a keyboard panel is open.
        final contentHeightWithKeyboardPanelOpen = tester.getSize(find.byKey(_chatPageKey)).height;

        // Ensure that the content is pushed up above the keyboard panel.
        expect(contentHeightWithNoKeyboard - contentHeightWithKeyboardPanelOpen, _toolbarHeight + _keyboardPanelHeight);
      });

      testWidgetsOnMobilePhone('removes bottom insets when focus leaves editor', (tester) async {
        final softwareKeyboardController = SoftwareKeyboardController();
        final controller = KeyboardPanelController(softwareKeyboardController);

        await _pumpTestAppWithTabsAndMultipleSafeAreaScopes(
          tester,
          controller: controller,
          softwareKeyboardController: softwareKeyboardController,
          simulatedKeyboardHeight: _expandedPhoneKeyboardHeight,
        );

        // Record the height of the content when no keyboard or panel is open.
        final contentHeightWithNoKeyboard = tester.getSize(find.byKey(_chatPageKey)).height;

        // Show a keyboard panel (not the keyboard).
        controller.showKeyboardPanel(_Panel.panel1);
        await tester.pumpAndSettle();

        // Record the height of the content now that a keyboard panel is open.
        final contentHeightWithKeyboardPanelOpen = tester.getSize(find.byKey(_chatPageKey)).height;

        // Ensure that the content is pushed up above the keyboard panel.
        expect(contentHeightWithNoKeyboard - contentHeightWithKeyboardPanelOpen, _toolbarHeight + _keyboardPanelHeight);

        // Switch to other tab.
        await tester.tap(find.byKey(_accountTabKey));
        await tester.pumpAndSettle();

        // Ensure the chat page is gone.
        expect(find.byKey(_chatPageKey), findsNothing);

        // Ensure that the account tab's content is full height (isn't restricted by safe area).
        expect(tester.getSize(find.byKey(_accountPageKey)).height, contentHeightWithNoKeyboard);
      });

      testWidgetsOnMobilePhone('does not retain bottom insets when closing keyboard during navigation', (tester) async {
        final navigatorKey = GlobalKey<NavigatorState>();
        final softwareKeyboardController = SoftwareKeyboardController();
        final controller = KeyboardPanelController(softwareKeyboardController);

        await _pumpTestAppWithNavigationScreens(
          tester,
          navigatorKey: navigatorKey,
          controller: controller,
          softwareKeyboardController: softwareKeyboardController,
          simulatedKeyboardHeight: _expandedPhoneKeyboardHeight,
        );

        // Record the height of the content when no keyboard is open.
        final contentHeightWithNoKeyboard = tester.getSize(find.byKey(_chatPageKey)).height;

        // Show the keyboard. Don't show the toolbar because it's irrelevant for this test.
        controller.toolbarVisibility = KeyboardToolbarVisibility.hidden;
        await tester.placeCaretInParagraph("1", 0);
        await tester.pumpAndSettle();

        // Record the height of the content now that the keyboard is open.
        final contentHeightWithKeyboardPanelOpen = tester.getSize(find.byKey(_chatPageKey)).height;

        // Ensure that the content is pushed up above the keyboard.
        expect(contentHeightWithNoKeyboard - contentHeightWithKeyboardPanelOpen, _expandedPhoneKeyboardHeight);

        // Navigate to screen 2, while simultaneously closing the keyboard (which is what
        // happens when navigating to a new screen without an IME connection).
        navigatorKey.currentState!.pushNamed("/second");

        // CRITICAL: The reason navigation is a problem is because the first pump of a new
        // screen happens before the keyboard starts to close (in a real app). Therefore, we
        // pump one frame here to create the new screen and THEN we close the keyboard.
        await tester.pump();

        // Close the keyboard now that the new screen is starting to navigate in.
        softwareKeyboardController.close();

        // Pump and settle to let the navigation animation play.
        await tester.pumpAndSettle();

        // Ensure that the second page body takes up all available space.
        expect(tester.getSize(find.byKey(_screen2BodyKey)).height, contentHeightWithNoKeyboard);
      });
    });
  });
}

/// Pumps a tree that displays a two tab UI, one tab has an editor that shows
/// a keyboard panel, and the other tab has no editor at all, which can be
/// used to verify what happens when navigating from an open editor to another
/// tab.
///
/// The pumped widget tree includes multiple keyboard safe area scopes, which helps
/// to stress test their communication with each other in the widget tree.
///
/// Simulates the software keyboard appearance and disappearance by animating
/// the `MediaQuery` view insets when the app communicates with the IME to show/hide
/// the software keyboard.
Future<void> _pumpTestAppWithTabsAndMultipleSafeAreaScopes(
  WidgetTester tester, {
  KeyboardPanelController? controller,
  SoftwareKeyboardController? softwareKeyboardController,
  ValueNotifier<bool>? isImeConnected,
  double simulatedKeyboardHeight = _expandedPhoneKeyboardHeight,
  // (Optional) widget that's positioned below the chat editor, which pushes
  // the chat editor up from the bottom of the screen.
  Widget? widgetBelowEditor,
}) async {
  final keyboardController = softwareKeyboardController ?? SoftwareKeyboardController();
  final keyboardPanelController = controller ?? KeyboardPanelController(keyboardController);
  final imeConnectionNotifier = isImeConnected ?? ValueNotifier<bool>(false);

  await tester //
      .createDocument()
      .withLongDoc()
      .withSoftwareKeyboardController(keyboardController)
      .withImeConnectionNotifier(imeConnectionNotifier)
      .simulateSoftwareKeyboardInsets(
        true,
        simulatedKeyboardHeight: simulatedKeyboardHeight,
      )
      .withCustomWidgetTreeBuilder(
        (superEditor) => _TestAppWithTabsAndMultipleSafeAreaScopes(
          superEditor: superEditor,
          keyboardPanelController: keyboardPanelController,
          imeConnectionNotifier: imeConnectionNotifier,
          widgetBelowEditor: widgetBelowEditor,
        ),
      )
      .pump();
}

/// An app scaffold with the following structure:
///
/// MaterialApp
///   |-- Column
///     |-- App bar with tabs
///     |-- Page (chat page or profile page)
class _TestAppWithTabsAndMultipleSafeAreaScopes extends StatelessWidget {
  const _TestAppWithTabsAndMultipleSafeAreaScopes({
    required this.superEditor,
    required this.keyboardPanelController,
    required this.imeConnectionNotifier,
    this.widgetBelowEditor,
  });

  final Widget superEditor;

  final KeyboardPanelController keyboardPanelController;
  final ValueNotifier<bool> imeConnectionNotifier;
  final Widget? widgetBelowEditor;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            bottom: const TabBar(
              tabs: [
                Tab(
                  key: _chatTabKey,
                  icon: Icon(Icons.chat),
                ),
                Tab(
                  key: _accountTabKey,
                  icon: Icon(Icons.account_circle),
                ),
              ],
            ),
          ),
          resizeToAvoidBottomInset: false,
          body: TabBarView(children: [
            // ^ We build a tab view so that we can test what happens when the editor
            //   has focus and a keyboard panel is up, and then the user navigates to
            //   another tab, which should remove the bottom safe area when it happens.
            _ChatPage(
              keyboardPanelController: keyboardPanelController,
              imeConnectionNotifier: imeConnectionNotifier,
              superEditor: superEditor,
              widgetBelowEditor: widgetBelowEditor,
            ),
            const _AccountPage(),
          ]),
        ),
      ),
    );
  }
}

class _ChatPage extends StatelessWidget {
  const _ChatPage({
    required this.superEditor,
    required this.keyboardPanelController,
    required this.imeConnectionNotifier,
    this.widgetBelowEditor,
  });

  final Widget superEditor;
  final KeyboardPanelController keyboardPanelController;
  final ValueNotifier<bool> imeConnectionNotifier;
  final Widget? widgetBelowEditor;

  @override
  Widget build(BuildContext context) {
    return KeyboardScaffoldSafeAreaScope(
      debugLabel: "Root",
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                _buildPageContent(),
                _buildChatEditor(),
              ],
            ),
          ),
          // Arbitrary widget below the page and editor content. Simulates, e.g.,
          // persistent bottom tabs, chat status, etc.
          if (widgetBelowEditor != null) //
            widgetBelowEditor!,
        ],
      ),
    );
  }

  Widget _buildPageContent() {
    // An area that simulates content that sits underneath
    // a bottom mounted chat editor.
    return Positioned.fill(
      child: KeyboardScaffoldSafeArea(
        debugLabel: "content",
        child: Container(
          key: _chatPageKey,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildChatEditor() {
    // An area that simulates a bottom mounted chat editor.
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: KeyboardScaffoldSafeArea(
        debugLabel: "editor",
        child: Builder(builder: (context) {
          return KeyboardPanelScaffold(
            controller: keyboardPanelController,
            isImeConnected: imeConnectionNotifier,
            contentBuilder: (context, isKeyboardPanelVisible) => ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: ColoredBox(
                color: Colors.yellow,
                child: superEditor,
              ),
            ),
            toolbarBuilder: (context, isKeyboardPanelVisible) => Container(
              key: _aboveKeyboardToolbarKey,
              height: 54,
              color: Colors.green,
            ),
            fallbackPanelHeight: _keyboardPanelHeight,
            keyboardPanelBuilder: (context, panel) => const SizedBox.expand(
              child: ColoredBox(
                key: _keyboardPanelKey,
                color: Colors.red,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _AccountPage extends StatelessWidget {
  const _AccountPage();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: _accountPageKey,
      color: Colors.grey.shade100,
      child: const Center(
        child: Icon(Icons.account_circle),
      ),
    );
  }
}

/// Pumps a tree that displays a page of content with an editor above it, at the bottom
/// of the screen.
///
/// The pumped tree only includes a single safe area scope, which ensures that apps with
/// only a single safe area work as expected.
///
/// Simulates the software keyboard appearance and disappearance by animating
/// the `MediaQuery` view insets when the app communicates with the IME to show/hide
/// the software keyboard.
Future<void> _pumpTestAppWithSingleSafeAreaScope(
  WidgetTester tester, {
  KeyboardPanelController? keyboardPanelController,
  SoftwareKeyboardController? softwareKeyboardController,
  ValueNotifier<bool>? isImeConnected,
  double simulatedKeyboardHeight = _expandedPhoneKeyboardHeight,
  // (Optional) widget that's positioned below the chat editor, which pushes
  // the chat editor up from the bottom of the screen.
  Widget? widgetBelowEditor,
}) async {
  final keyboardController = softwareKeyboardController ?? SoftwareKeyboardController();
  final panelController = keyboardPanelController ?? KeyboardPanelController(keyboardController);
  final imeConnectionNotifier = isImeConnected ?? ValueNotifier<bool>(false);

  await tester //
      .createDocument()
      .withLongDoc()
      .withSoftwareKeyboardController(keyboardController)
      .withImeConnectionNotifier(imeConnectionNotifier)
      .simulateSoftwareKeyboardInsets(
        true,
        simulatedKeyboardHeight: simulatedKeyboardHeight,
      )
      .withCustomWidgetTreeBuilder(
        (superEditor) => _TestAppWithSingleSafeAreaScope(
          superEditor: superEditor,
          keyboardPanelController: panelController,
          imeConnectionNotifier: imeConnectionNotifier,
          widgetBelowEditor: widgetBelowEditor,
        ),
      )
      .pump();
}

class _TestAppWithSingleSafeAreaScope extends StatelessWidget {
  const _TestAppWithSingleSafeAreaScope({
    required this.superEditor,
    required this.keyboardPanelController,
    required this.imeConnectionNotifier,
    this.widgetBelowEditor,
  });

  final Widget superEditor;

  final KeyboardPanelController keyboardPanelController;
  final ValueNotifier<bool> imeConnectionNotifier;
  final Widget? widgetBelowEditor;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        resizeToAvoidBottomInset: false,
        body: KeyboardScaffoldSafeArea(
          // ^ This is the one and only safe area scope in this tree.
          debugLabel: "Root",
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        key: _chatPageKey,
                        color: Colors.blue,
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Builder(builder: (context) {
                        return KeyboardPanelScaffold(
                          controller: keyboardPanelController,
                          isImeConnected: imeConnectionNotifier,
                          contentBuilder: (context, isKeyboardPanelVisible) => ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 250),
                            child: ColoredBox(
                              color: Colors.yellow,
                              child: superEditor,
                            ),
                          ),
                          toolbarBuilder: (context, isKeyboardPanelVisible) => Container(
                            key: _aboveKeyboardToolbarKey,
                            height: 54,
                            color: Colors.green,
                          ),
                          fallbackPanelHeight: _keyboardPanelHeight,
                          keyboardPanelBuilder: (context, panel) => const SizedBox.expand(
                            child: ColoredBox(
                              key: _keyboardPanelKey,
                              color: Colors.red,
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _chatTabKey = ValueKey("chat_tab_button");
const _chatPageKey = ValueKey("chat_content");

const _accountTabKey = ValueKey("account_tab_button");
const _accountPageKey = ValueKey("account_content");

const _screen2BodyKey = ValueKey("screen_2_body");

/// Pumps a tree that can display two screens - the first screen has an editor
/// with a keyboard panel scaffold, the second screen has a keyboard safe area
/// but no editor or keyboard panel scaffold.
///
/// Simulates the software keyboard appearance and disappearance by animating
/// the `MediaQuery` view insets when the app communicates with the IME to show/hide
/// the software keyboard.
Future<void> _pumpTestAppWithNavigationScreens(
  WidgetTester tester, {
  required GlobalKey<NavigatorState> navigatorKey,
  KeyboardPanelController? controller,
  SoftwareKeyboardController? softwareKeyboardController,
  ValueNotifier<bool>? isImeConnected,
  double simulatedKeyboardHeight = _expandedPhoneKeyboardHeight,
  // (Optional) widget that's positioned below the chat editor, which pushes
  // the chat editor up from the bottom of the screen.
  Widget? widgetBelowEditor,
}) async {
  final keyboardController = softwareKeyboardController ?? SoftwareKeyboardController();
  final keyboardPanelController = controller ?? KeyboardPanelController(keyboardController);
  final imeConnectionNotifier = isImeConnected ?? ValueNotifier<bool>(false);

  await tester //
      .createDocument()
      .withLongDoc()
      .withSoftwareKeyboardController(keyboardController)
      .withImeConnectionNotifier(imeConnectionNotifier)
      .simulateSoftwareKeyboardInsets(
        true,
        simulatedKeyboardHeight: simulatedKeyboardHeight,
      )
      .withCustomWidgetTreeBuilder(
        (superEditor) => MaterialApp(
          navigatorKey: navigatorKey,
          routes: {
            '/': (context) {
              return _Screen1(
                keyboardPanelController: keyboardPanelController,
                imeConnectionNotifier: imeConnectionNotifier,
                superEditor: superEditor,
                widgetBelowEditor: widgetBelowEditor,
              );
            },
            '/second': (context) {
              return const _Screen2();
            },
          },
        ),
      )
      .pump();
}

class _Screen1 extends StatelessWidget {
  const _Screen1({
    required this.keyboardPanelController,
    required this.imeConnectionNotifier,
    required this.superEditor,
    this.widgetBelowEditor,
  });

  final KeyboardPanelController keyboardPanelController;
  final ValueNotifier<bool> imeConnectionNotifier;
  final Widget superEditor;
  final Widget? widgetBelowEditor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: KeyboardScaffoldSafeAreaScope(
        // ^ This safe area is needed to receive the bottom insets from the
        //   bottom mounted editor, and then make it available to the subtree
        //   with the content behind the chat.
        debugLabel: "_Screen1",
        child: _ChatPage(
          keyboardPanelController: keyboardPanelController,
          imeConnectionNotifier: imeConnectionNotifier,
          superEditor: superEditor,
          widgetBelowEditor: widgetBelowEditor,
        ),
      ),
    );
  }
}

class _Screen2 extends StatelessWidget {
  const _Screen2();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: KeyboardScaffoldSafeArea(
        debugLabel: "_Screen2",
        child: Builder(builder: (context) {
          return ListView.builder(
            key: _screen2BodyKey,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text("Item $index"),
              );
            },
          );
        }),
      ),
    );
  }
}

void testWidgetsOnMobilePhone(
  String description,
  WidgetTesterCallback test, {
  bool skip = false,
  TestVariant<Object?> variant = const DefaultTestVariant(),
}) {
  testWidgetsOnMobile(
    description,
    (WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(1179, 2556)
        ..devicePixelRatio = 3.0;

      addTearDown(() {
        tester.view.reset();
      });

      await test(tester);
    },
    skip: skip,
    variant: variant,
  );
}

// TODO: we want the iPad and Android tablet to be configurable in some way for
//       minimized/floating keyboard vs docked keyboard.

void testWidgetsOnIPad(
  String description,
  WidgetTesterCallback test, {
  bool skip = false,
  TestVariant<Object?> variant = const DefaultTestVariant(),
}) {
  testWidgetsOnIos(
    description,
    (WidgetTester tester) async {
      tester.view
        // Simulate an iPad Pro 12
        ..physicalSize = const Size(2048, 2732)
        ..devicePixelRatio = 2.0;

      addTearDown(() {
        tester.view.reset();
      });

      await test(tester);
    },
    skip: skip,
    variant: variant,
  );
}

void testWidgetsOnAndroidTablet(
  String description,
  WidgetTesterCallback test, {
  bool skip = false,
  TestVariant<Object?> variant = const DefaultTestVariant(),
}) {
  testWidgetsOnAndroid(
    description,
    (WidgetTester tester) async {
      tester.view
        // Simulate a Pixel tablet.
        ..physicalSize = const Size(1600, 2560)
        ..devicePixelRatio = 2.0;

      addTearDown(() {
        tester.view.reset();
      });

      await test(tester);
    },
    skip: skip,
    variant: variant,
  );
}

// Height of the toolbar that sits above the keyboard/panel.
const _toolbarHeight = 54.0;

// Simulated height of a fully visible phone keyboard. We specify this because
// there's no real window in a widget test, and therefore no real keyboard.
const _expandedPhoneKeyboardHeight = 300.0;

// Arbitrary height used to display keyboard panels in place of the keyboard. These
// panels are controlled entirely by the KeyboardScaffold in the app, so the height can
// be whatever is desired. Ideally, apps would make these the same height as the keyboard,
// but we specify a value that's different from the simulated keyboard so that we can
// verify heights without accidentally confusing the keyboard and panel heights.
const _keyboardPanelHeight = 275.0;

const _expandedIPadKeyboardHeight = 300.0;
// iPad can show a "minimized" keyboard, which takes up a short area at
// the bottom of the screen, and within that short area is a small
// toolbar that shows spelling suggestions along with a button that
// opens a keyboard options menu.
const _minimizedIPadKeyboardHeight = 69.0;

const _expandedAndroidTabletKeyboardHeight = 300.0;
// Android tablets can show a "minimized" keyboard, which takes up a
// short area at the bottom of the screen, and within that short area
// is a small toolbar that includes delete, emojis, audio recording, and
// a button to open a menu.
const _minimizedAndroidTabletKeyboardHeight = 62.0;

const _aboveKeyboardToolbarKey = ValueKey('toolbar');
const _keyboardPanelKey = ValueKey('keyboardPanel');

enum _Panel {
  panel1,
  panel2;
}
