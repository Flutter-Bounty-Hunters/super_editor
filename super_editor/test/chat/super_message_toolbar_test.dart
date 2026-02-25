import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/src/test/super_editor_test/supereditor_robot.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group("Chat > SuperMessage > toolbar >", () {
    group("iOS >", () {
      testWidgetsOnIos("dismisses after copy button is pressed", (tester) async {
        await _pumpScaffold(tester);

        // Long press to select text and show the toolbar.
        await tester.longPressInParagraph("1", 10);
        expect(find.byType(DefaultIOSSuperMessageToolbar), findsOne);

        // Press "Copy" on the toolbar, which should dismiss it.
        await tester.tap(find.text("Copy"));
        await tester.pump();

        // Ensure toolbar is dismissed.
        expect(find.byType(DefaultIOSSuperMessageToolbar), findsNothing);
      });

      testWidgetsOnIos("dismisses after select-all button is pressed", (tester) async {
        await _pumpScaffold(tester);

        // Long press to select text and show the toolbar.
        await tester.longPressInParagraph("1", 10);
        expect(find.byType(DefaultIOSSuperMessageToolbar), findsOne);

        // Press "Select All" on the toolbar, which should dismiss it.
        await tester.tap(find.text("Select All"));
        await tester.pump();

        // Ensure toolbar is dismissed.
        expect(find.byType(DefaultIOSSuperMessageToolbar), findsNothing);
      });
    });

    group("Android >", () {
      testWidgetsOnAndroid("dismisses after copy button is pressed", (tester) async {
        await _pumpScaffold(tester);

        // Long press to select text and show the toolbar.
        await tester.longPressInParagraph("1", 10);
        expect(find.byType(DefaultAndroidSuperMessageToolbar), findsOne);

        // Press "Copy" on the toolbar, which should dismiss it.
        await tester.tap(find.text("Copy"));
        await tester.pump();

        // Ensure toolbar is dismissed.
        expect(find.byType(DefaultAndroidSuperMessageToolbar), findsNothing);
      });

      testWidgetsOnAndroid("dismisses after select-all button is pressed", (tester) async {
        await _pumpScaffold(tester);

        // Long press to select text and show the toolbar.
        await tester.longPressInParagraph("1", 10);
        expect(find.byType(DefaultAndroidSuperMessageToolbar), findsOne);

        // Press "Select All" on the toolbar, which should dismiss it.
        await tester.tap(find.text("Select All"));
        await tester.pump();

        // Ensure toolbar is dismissed.
        expect(find.byType(DefaultAndroidSuperMessageToolbar), findsNothing);
      });
    });
  });
}

Future<void> _pumpScaffold(WidgetTester tester) async {
  final editor = createDefaultAiMessageEditor(
    document: MutableDocument(
      nodes: [
        ParagraphNode(
          id: "1",
          text: AttributedText("This is a message that is displayed in a SuperMessage"),
        ),
      ],
    ),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            SuperMessage(editor: editor),
          ],
        ),
      ),
    ),
  );
}
