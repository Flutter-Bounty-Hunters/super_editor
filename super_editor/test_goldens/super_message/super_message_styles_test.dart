import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_goldens/flutter_test_goldens.dart';
import 'package:flutter_test_goldens/golden_bricks.dart';
import 'package:super_editor/src/chat/super_message.dart';
import 'package:super_editor/src/default_editor/default_document_editor.dart';
import 'package:super_editor/src/test/flutter_extensions/test_documents.dart';
import 'package:super_editor/src/test/super_reader_test/super_reader_robot.dart';

void main() {
  group("Super Message > styles >", () {
    testGoldenSceneOnIOS("re-renders when styles change", (tester) async {
      final editor = createDefaultDocumentEditor(
        document: singleParagraphDocShortText(),
      );
      final lightStyles = SuperMessageStyles(
        stylesheet: defaultLightChatStylesheet,
        selectionStyles: defaultLightChatSelectionStyles,
      );
      final darkStyles = SuperMessageStyles(
        stylesheet: defaultDarkChatStylesheet,
        selectionStyles: defaultDarkChatSelectionStyles,
      );

      final timeline = Timeline(
        "Re-Render on Style Change",
        fileName: 'supermessage_re-render-on-style-change',
        windowSize: const Size(1179, 2556) / 3.0,
        layout: const ColumnSceneLayout(),
        // TODO: Document how to create an item scaffold, including the need for GoldenImageBounds
        itemScaffold: _chatItemScaffold,
      );

      final brightness = ValueNotifier(Brightness.light);
      timeline.setupWithWidget(
        ValueListenableBuilder(
          valueListenable: brightness,
          builder: (context, value, child) {
            return ColoredBox(
              color: switch (value) {
                Brightness.light => Colors.white,
                Brightness.dark => Colors.grey.shade900,
              },
              child: SuperMessage(
                editor: editor,
                styles: switch (value) {
                  Brightness.light => lightStyles,
                  Brightness.dark => darkStyles,
                },
              ),
            );
          },
        ),
      );

      await timeline
          .modifyScene((tester, testContext) async {
            await tester.doubleTapInParagraph("1", 24);
          })
          .takePhoto("Light")
          // Switch to dark.
          .modifyScene((tester, testContext) async {
            brightness.value = Brightness.dark;
            await tester.pump();
          })
          .takePhoto("Dark")
          .run(tester);
    });
  });
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
