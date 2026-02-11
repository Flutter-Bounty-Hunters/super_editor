import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

void main() {
  group('SuperEditor', () {
    testWidgetsOnIos('keeps current selection and does not show mobile controls when swipping to pop', (tester) async {
      // Run the test with a fixed size so we know how much we need to swipe
      // to pop the page.
      tester.view
        ..devicePixelRatio = 1.0
        ..platformDispatcher.textScaleFactorTestValue = 1.0
        ..physicalSize = const Size(300, 600);
      addTearDown(() => tester.platformDispatcher.clearAllTestValues());

      // Pump an app with two routes to simulate a swipe-to-pop gesture.
      //
      // The app pushes the SuperEditor route automatically after the first frame.
      await tester
          .createDocument()
          .withSingleParagraph()
          .withCustomWidgetTreeBuilder(
            (superEditor) => MaterialApp(
              home: _AutoPushRoute(
                route: MaterialPageRoute(
                  builder: (context) => Scaffold(
                    body: superEditor,
                  ),
                ),
              ),
            ),
          )
          .pump();

      // Wait until the editor route is displayed.
      await tester.pumpAndSettle();

      // Ensure there is no selection.
      expect(SuperEditorInspector.findDocumentSelection(), isNull);

      // Start dragging approximately from the top left corner of the editor.
      final gesture = await tester.startGesture(
        tester.getTopLeft(find.byType(SuperEditor)) + const Offset(10, 10),
      );

      // Move a little bit to start the swipe to pop gesture.
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();

      // Move to the right side of the screen to trigger the route pop.
      await gesture.moveBy(const Offset(200, 0));
      await tester.pump();

      // Let the long press timer resolve.
      await tester.pump(kLongPressTimeout);

      // Ensure there is still no selection and the magnifier is not displayed.
      expect(SuperEditorInspector.findDocumentSelection(), isNull);
      expect(SuperEditorInspector.findMobileMagnifier(), findsNothing);
      expect(SuperEditorInspector.isMobileToolbarVisible(), isFalse);

      // Release the gesture.
      await gesture.up();
      await tester.pumpAndSettle();

      // Ensure that the route was popped.
      expect(find.byType(SuperEditor), findsNothing);
    });
  });
}

/// Displays a placeholder and automatically pushes the given [route]
/// after the first frame.
class _AutoPushRoute extends StatefulWidget {
  const _AutoPushRoute({
    required this.route,
  });

  final Route route;

  @override
  State<_AutoPushRoute> createState() => _AutoPushRouteState();
}

class _AutoPushRouteState extends State<_AutoPushRoute> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((duration) {
      if (!mounted) {
        return;
      }

      Navigator.of(context).push(widget.route);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
