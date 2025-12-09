import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/src/test/super_editor_test/supereditor_robot.dart';
import 'package:super_editor/src/test/super_reader_test/super_reader_inspector.dart';

import '../../test_runners.dart';
import '../../../lib/src/test/super_reader_test/reader_test_tools.dart';

void main() {
  group("SuperReader > iOS > overlay controls >", () {
    group("on device and web > shows ", () {
      testWidgetsOnIosDeviceAndWeb("upstream and downstream handles", (tester) async {
        await _pumpApp(tester);

        // Create an expanded selection.
        await tester.doubleTapInParagraph("1", 1);

        // Ensure we have an expanded selection.
        expect(SuperReaderInspector.findDocumentSelection(), isNotNull);
        expect(SuperReaderInspector.findDocumentSelection()!.isCollapsed, isFalse);

        // Ensure expanded handles are visible, but caret isn't.
        expect(SuperReaderInspector.findMobileCaret(), findsNothing);
        expect(SuperReaderInspector.findMobileUpstreamDragHandle(), findsOneWidget);
        expect(SuperReaderInspector.findMobileDownstreamDragHandle(), findsOneWidget);
      });
    });

    group("on device >", () {
      group("shows", () {
        testWidgetsOnIos("the magnifier", (tester) async {
          await _pumpApp(tester);

          // Long press, and hold, so that the magnifier appears.
          await tester.longPressDownInParagraph("1", 1);

          // Ensure the magnifier is wanted AND visible.
          expect(SuperReaderInspector.wantsMobileMagnifierToBeVisible(), isTrue);
          expect(SuperReaderInspector.isMobileMagnifierVisible(), isTrue);
        });

        testWidgetsOnIos("the floating toolbar", (tester) async {
          await _pumpApp(tester);

          // Create an expanded selection.
          await tester.doubleTapInParagraph("1", 1);

          // Ensure we have an expanded selection.
          expect(SuperReaderInspector.findDocumentSelection(), isNotNull);
          expect(SuperReaderInspector.findDocumentSelection()!.isCollapsed, isFalse);

          // Ensure that the toolbar is desired AND displayed.
          expect(SuperReaderInspector.wantsMobileToolbarToBeVisible(), isTrue);
          expect(SuperReaderInspector.isMobileToolbarVisible(), isTrue);
        });
      });
    });

    group("on web >", () {
      group("defers to browser to show", () {
        testWidgetsOnWebIos("the magnifier", (tester) async {
          await _pumpApp(tester);

          // Long press, and hold, so that the magnifier appears.
          await tester.longPressDownInParagraph("1", 1);

          // Ensure the magnifier is desired, but not displayed.
          expect(SuperReaderInspector.wantsMobileMagnifierToBeVisible(), isTrue);
          expect(SuperReaderInspector.isMobileMagnifierVisible(), isFalse);
        });

        testWidgetsOnWebIos("the floating toolbar", (tester) async {
          await _pumpApp(tester);

          // Create an expanded selection.
          await tester.doubleTapInParagraph("1", 1);

          // Ensure we have an expanded selection.
          expect(SuperReaderInspector.findDocumentSelection(), isNotNull);
          expect(SuperReaderInspector.findDocumentSelection()!.isCollapsed, isFalse);

          // Ensure that the toolbar is desired, but not displayed.
          expect(SuperReaderInspector.wantsMobileToolbarToBeVisible(), isTrue);
          expect(SuperReaderInspector.isMobileToolbarVisible(), isFalse);
        });
      });
    });
  });
}

Future<void> _pumpApp(WidgetTester tester) async {
  await tester
      .createDocument()
      // Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor...
      .withSingleParagraph()
      .pump();
}
