import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_goldens/flutter_test_goldens.dart';
import 'package:flutter_test_goldens/golden_bricks.dart';
import 'package:super_editor/src/test/super_editor_test/supereditor_robot.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group("Super Message > selection >", () {
    testGoldenSceneOnAndroid("long press selection", (tester) async {
      final timeline = Timeline(
        "Android - Long Press Selection",
        fileName: 'supermessage_android_long-press-selection',
        windowSize: const Size(1179, 2556) / 3.0,
        layout: ColumnSceneLayout(
            // background: GoldenSceneBackground.widget(ShadcnBackground()),
            // itemDecorator: shadcnItemDecorator,
            ),
        // TODO: Document how to create an item scaffold, including the need for GoldenImageBounds
        itemScaffold: _chatItemScaffold,
      );

      timeline.setupWithWidget(
        _buildSuperMessage(),
      );

      await _runLongPressTimeline(tester, timeline);
    });

    testGoldenSceneOnIOS("long press selection", (tester) async {
      final timeline = Timeline(
        "iOS - Long Press Selection",
        fileName: 'supermessage_ios_long-press-selection',
        windowSize: const Size(1179, 2556) / 3.0,
        layout: ColumnSceneLayout(
            // background: GoldenSceneBackground.widget(ShadcnBackground()),
            // itemDecorator: shadcnItemDecorator,
            ),
        // TODO: Document how to create an item scaffold, including the need for GoldenImageBounds
        itemScaffold: _chatItemScaffold,
      );

      timeline.setupWithWidget(
        _buildSuperMessage(),
      );

      await _runLongPressTimeline(tester, timeline);
    });
  });
}

Future<void> _runLongPressTimeline(WidgetTester tester, Timeline timeline) async {
  await timeline
      .takePhoto("Idle")
      // Long press on word
      .modifyScene((tester, testContext) async {
        final longPress = await tester.longPressDownInParagraph("1", 62);
        testContext.activeGesture = longPress;

        await tester.pump();
      })
      .takePhoto("Long Press")
      // Drag to left
      .modifyScene((tester, testContext) async {
        final longPress = testContext.activeGesture!;
        await longPress.moveBy(const Offset(-75, 0));
        await tester.pump();

        // For some reason (on iOS) we need one extra pump to fully update dirty paint status.
        await tester.pump();
      })
      .takePhoto("Drag Left")
      // Drag up a line
      .modifyScene((tester, testContext) async {
        final longPress = testContext.activeGesture!;
        await longPress.moveBy(const Offset(0, -20));
        await tester.pump();

        // For some reason (on iOS) we need one extra pump to fully update dirty paint status.
        await tester.pump();
      })
      .takePhoto("Drag Up")
      // Drag back to the original word, then to the right.
      .modifyScene((tester, testContext) async {
        // Back to starting point.
        final longPress = testContext.activeGesture!;
        await longPress.moveBy(const Offset(75, 20));
        await tester.pump();

        // Drag to the right.
        await longPress.moveBy(const Offset(50, 0));
        await tester.pump();

        // For some reason (on iOS) we need one extra pump to fully update dirty paint status.
        await tester.pump();
      })
      .takePhoto("Drag Up")
      // Drag down a line
      .modifyScene((tester, testContext) async {
        final longPress = testContext.activeGesture!;
        await longPress.moveBy(const Offset(0, 20));
        await tester.pump();

        // For some reason we need one extra pump to fully update dirty paint status.
        await tester.pump();
      })
      .takePhoto("Drag Down")
      // Release the drag and show the handles and toolbar.
      .modifyScene((tester, testContext) async {
        final longPress = testContext.activeGesture!;
        await longPress.up();
        await tester.pump();

        // For some reason we need one extra pump to fully update dirty paint status.
        await tester.pump();
      })
      .takePhoto("Release")
      .run(tester);
}

Widget _chatItemScaffold(tester, content) {
  return GoldenSceneBounds(
    child: MaterialApp(
      theme: ThemeData(
        fontFamily: goldenBricks,
      ),
      home: Scaffold(
        body: Center(
          child: GoldenImageBounds(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: content,
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _buildSuperMessage() {
  return SuperMessage(
    editor: createDefaultDocumentEditor(
      document: MutableDocument(
        nodes: [
          ParagraphNode(
            id: "1",
            text: AttributedText(
              "This is a SuperMessage widget. It's used for chat use-cases. This message if fairly long so that we can have three lines of height.",
            ),
          ),
        ],
      ),
    ),
    styles: SuperMessageStyles(
      stylesheet: defaultLightChatStylesheet.copyWith(
        addRulesAfter: [
          StyleRule(
            BlockSelector.all,
            (doc, docNode) {
              return {
                Styles.textStyle: const TextStyle(
                  fontFamily: goldenBricks,
                ),
              };
            },
          ),
        ],
      ),
      selectionStyles: const SelectionStyles(
        selectionColor: Color(0xFFACCEF7),
      ),
    ),
  );
}
