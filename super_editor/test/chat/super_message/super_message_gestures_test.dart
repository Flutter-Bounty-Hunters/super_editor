import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/src/infrastructure/links.dart';
import 'package:super_editor/src/test/flutter_extensions/test_documents.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../../test_tools.dart';

void main() {
  group("Chat > SuperMessage > gestures >", () {
    testWidgetsOnAllPlatforms("launches URL on tap", (tester) async {
      // Setup test version of UrlLauncher to log URL launches.
      final testUrlLauncher = TestUrlLauncher();
      UrlLauncher.instance = testUrlLauncher;
      addTearDown(() => UrlLauncher.instance = null);

      // Pump the UI.
      await _pumpScaffold(tester, document: singleParagraphWithLinkDoc());

      // Tap on the link.
      await tester.tapInParagraph("1", 27);

      // Ensure that we tried to launch the URL.
      expect(testUrlLauncher.urlLaunchLog.length, 1);
      expect(testUrlLauncher.urlLaunchLog.first.toString(), "https://fake.url");
    });

    testWidgetsOnAllPlatforms("launches different URLs on tap", (tester) async {
      // Setup test version of UrlLauncher to log URL launches.
      final testUrlLauncher = TestUrlLauncher();
      UrlLauncher.instance = testUrlLauncher;
      addTearDown(() => UrlLauncher.instance = null);

      // Pump the UI.
      final document = deserializeMarkdownToDocument("[Google](https://google.com) and [Flutter](https://flutter.dev)");
      final paragraphId = document.first.id;
      await _pumpScaffold(tester, document: document);

      // Tap on the first link.
      await tester.tapInParagraph(paragraphId, 3);

      // Ensure that we tried to launch the first URL.
      expect(testUrlLauncher.urlLaunchLog.length, 1);
      expect(testUrlLauncher.urlLaunchLog.first.toString(), "https://google.com");

      // Tap on the second link.
      await tester.tapInParagraph(paragraphId, 14);

      // Ensure that we tried to launch the second URL.
      expect(testUrlLauncher.urlLaunchLog.length, 2);
      expect(testUrlLauncher.urlLaunchLog.last.toString(), "https://flutter.dev");
    });
  });
}

Future<void> _pumpScaffold(
  WidgetTester tester, {
  MutableDocument? document,
}) async {
  final editor = createDefaultAiMessageEditor(
    document: document ?? MutableDocument.empty("1"),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              SuperMessage(editor: editor),
            ],
          ),
        ),
      ),
    ),
  );
}
