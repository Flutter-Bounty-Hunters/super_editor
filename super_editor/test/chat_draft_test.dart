import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group('ChatDraftPreview', () {
    testWidgets('displays draft text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatDraftPreview(
              draftText: 'Hello world',
            ),
          ),
        ),
      );

      expect(find.text('Hello world'), findsOneWidget);
    });

    testWidgets('shows draft indicator by default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatDraftPreview(
              draftText: 'Hello world',
            ),
          ),
        ),
      );

      expect(find.text('Draft'), findsOneWidget);
    });

    testWidgets('hides draft indicator when disabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatDraftPreview(
              draftText: 'Hello world',
              showDraftIndicator: false,
            ),
          ),
        ),
      );

      expect(find.text('Draft'), findsNothing);
    });

    testWidgets('shows placeholder when text is empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatDraftPreview(
              draftText: '',
            ),
          ),
        ),
      );

      expect(find.text('Type a message...'), findsOneWidget);
    });

    testWidgets('handles tap callback', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatDraftPreview(
              draftText: 'Hello world',
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ChatDraftPreview));
      expect(tapped, isTrue);
    });
  });

  group('ChatDraftController', () {
    test('initial state is empty', () {
      final controller = ChatDraftController();
      
      expect(controller.draftText, isEmpty);
      expect(controller.hasDraft, isFalse);
      expect(controller.lastModified, isNull);
    });

    test('updateDraft sets text and hasDraft', () {
      final controller = ChatDraftController();
      
      controller.updateDraft('Hello');
      
      expect(controller.draftText, equals('Hello'));
      expect(controller.hasDraft, isTrue);
      expect(controller.lastModified, isNotNull);
    });

    test('clearDraft resets state', () {
      final controller = ChatDraftController();
      
      controller.updateDraft('Hello');
      controller.clearDraft();
      
      expect(controller.draftText, isEmpty);
      expect(controller.hasDraft, isFalse);
    });

    test('notifies listeners on update', () {
      final controller = ChatDraftController();
      int notifyCount = 0;
      
      controller.addListener(() {
        notifyCount++;
      });
      
      controller.updateDraft('Hello');
      expect(notifyCount, equals(1));
      
      controller.updateDraft('World');
      expect(notifyCount, equals(2));
    });
  });

  group('ChatInputWithDraft', () {
    testWidgets('renders input field', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInputWithDraft(
              onSend: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(SuperTextField), findsOneWidget);
    });

    testWidgets('shows draft preview when text entered', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInputWithDraft(
              onSend: (_) {},
            ),
          ),
        ),
      );

      // Initially no draft preview
      expect(find.byType(ChatDraftPreview), findsNothing);

      // Enter text
      await tester.enterText(find.byType(SuperTextField), 'Hello');
      await tester.pump();

      // Now draft preview should show
      expect(find.byType(ChatDraftPreview), findsOneWidget);
    });

    testWidgets('send button triggers onSend', (tester) async {
      String? sentMessage;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInputWithDraft(
              onSend: (msg) {
                sentMessage = msg;
              },
            ),
          ),
        ),
      );

      // Enter text
      await tester.enterText(find.byType(SuperTextField), 'Hello world');
      await tester.pump();

      // Tap send
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      expect(sentMessage, equals('Hello world'));
    });

    testWidgets('clears after send', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInputWithDraft(
              onSend: (_) {},
            ),
          ),
        ),
      );

      // Enter text
      await tester.enterText(find.byType(SuperTextField), 'Hello');
      await tester.pump();

      // Send
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      // Text should be cleared
      final textField = tester.widget<SuperTextField>(find.byType(SuperTextField));
      expect(textField.textController.text.text, isEmpty);
    });
  });
}
