import 'dart:async';

import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/default_editor/default_document_editor.dart';
import 'package:super_editor/src/default_editor/document_ime/shared_ime.dart';
import 'package:super_editor/src/default_editor/paragraph.dart';
import 'package:super_editor/src/default_editor/super_editor.dart';
import 'package:super_editor/src/test/super_editor_test/supereditor_robot.dart';

void main() {
  group("Super Editor > IME ownership >", () {
    testWidgets("releases ownership when it loses focus", (tester) async {
      final focusNode = FocusNode(debugLabel: "test-editor");
      final editor1 = createDefaultDocumentEditor();
      await _pumpScaffold(
        tester,
        SuperEditor(
          focusNode: focusNode,
          editor: editor1,
          inputRole: _roleVariant.currentValue,
        ),
      );

      expect(SuperIme.instance.isOwned, isFalse);

      // Focus the editor. We do this directly with the `FocusNode` instead of tapping
      // on the editor because there are many cases where developers give focus to the editor
      // in this same way.
      focusNode.requestFocus();
      await tester.pump();

      expect(SuperIme.instance.isOwned, isTrue);

      // Take focus away from the editor. We expect the editor to give up the IME.
      focusNode.unfocus();
      await tester.pump();

      expect(SuperIme.instance.isOwned, isFalse);
    });

    testWidgets(
      "does not clear selection, or unfocus, when IME is claimed by a different SuperEditor with the same role",
      (tester) async {
        final focusNode = FocusNode(debugLabel: "test-editor");
        final editor = createDefaultDocumentEditor(document: _emptyParagraph);

        await _pumpScaffold(
          tester,
          SuperEditor(
            // We use a GlobalKey to force Flutter to throw away the tree and replace it.
            key: GlobalKey(debugLabel: 'first-editor-tree'),
            focusNode: focusNode,
            editor: editor,
            inputRole: "Chat",
          ),
        );

        expect(focusNode.hasPrimaryFocus, isFalse);
        expect(editor.composer.selection, isNull);
        expect(SuperIme.instance.isOwned, isFalse);

        // Place the caret, and focus the editor.
        await tester.tapInParagraph("1", 0);

        // Ensure that the editor now owns the IME.
        expect(focusNode.hasPrimaryFocus, isTrue);
        expect(editor.composer.selection, isNotNull);
        expect(SuperIme.instance.isOwned, isTrue);
        expect(SuperIme.instance.owner?.role, "Chat");
        final owner1 = SuperIme.instance.owner;

        // Pump a new widget tree, but still with a SuperEditor playing the same role.
        await _pumpScaffold(
          tester,
          SuperEditor(
            // We use a GlobalKey to force Flutter to throw away the tree and replace it.
            key: GlobalKey(debugLabel: 'second-editor-tree'),
            focusNode: focusNode,
            editor: editor,
            inputRole: "Chat",
          ),
        );
        await tester.pumpAndSettle();

        // Ensure that the editor state hasn't changed: still has selection, still focused,
        // IME still owned. BUT, the IME owner has changed instance.
        //
        // Note: This test was added for issue #2962 (https://github.com/Flutter-Bounty-Hunters/super_editor/issues/2962).
        // Before that, when replacing one SuperEditor with another, even with the same role, the
        // SuperEditor being disposed would clear the selection and unfocus, causing the IME to close.
        expect(focusNode.hasPrimaryFocus, isTrue);
        expect(editor.composer.selection, isNotNull);
        expect(SuperIme.instance.isOwned, isTrue);
        expect(SuperIme.instance.owner?.role, "Chat");
        expect(SuperIme.instance.owner, isNot(owner1));
      },
    );

    group("catches duplicate roles in the same build >", () {
      // Note about timing: This group tests when multiple editors `build()` in the same
      // frame. If a given editor already exists, it might not need to `build()` in the
      // same frame as another editor. That case is tested in a different group.

      testWidgets("throws exception on 2+", (tester) async {
        final editor1 = createDefaultDocumentEditor();
        final editor2 = createDefaultDocumentEditor();

        // Ensure that we can pump a single editor with a role.
        await _pumpScaffold(
          tester,
          SuperEditor(
            editor: editor1,
            inputRole: _roleVariant.currentValue,
          ),
        );

        // Expect that when we pump two editors with the same role, we get an exception.
        final errors = await _captureFlutterErrors(
          () => _pumpScaffold(
            tester,
            Column(
              children: [
                Expanded(
                  child: SuperEditor(
                    editor: editor1,
                    inputRole: _roleVariant.currentValue,
                  ),
                ),
                Expanded(
                  child: SuperEditor(
                    editor: editor2,
                    // This is the same role as above, which isn't allowed.
                    inputRole: _roleVariant.currentValue,
                  ),
                ),
              ],
            ),
          ),
        );

        expect(errors.length, 1);
        expect(errors.first.exception, isA<Exception>());
        expect(errors.first.exception.toString(), startsWith("Exception: Found 2 duplicate input IDs this frame:"));
      }, variant: _roleVariant);
    });

    group("catches duplicate roles in subsequent builds >", () {
      // Note about timing: Multiple editors might run `build()` in the same frame,
      // or one editor might already exist and not need to run build, but then a second
      // editor builds in another area of the tree. This group tests this timing situation.

      testWidgets("throws exception on 2+", (tester) async {
        final editor1 = createDefaultDocumentEditor();
        final editor2 = createDefaultDocumentEditor();
        final buildSecondEditor = ValueNotifier(false);

        // Ensure that we can pump a single editor with a role.
        await _pumpScaffold(
          tester,
          Column(
            children: [
              Expanded(
                child: SuperEditor(
                  editor: editor1,
                  inputRole: _roleVariant.currentValue,
                ),
              ),
              ListenableBuilder(
                  listenable: buildSecondEditor,
                  builder: (context, child) {
                    if (!buildSecondEditor.value) {
                      return const SizedBox();
                    }

                    return Expanded(
                      child: SuperEditor(
                        editor: editor2,
                        // This is the same role as above, which isn't allowed.
                        inputRole: _roleVariant.currentValue,
                      ),
                    );
                  }),
            ],
          ),
        );

        // Flip the signal to show the second editor. This should result in the second
        // editor building, but the first shouldn't re-run build.
        buildSecondEditor.value = true;

        // Pump a frame to let Flutter build what it wants. We expect to capture an exception
        // during this pump.
        final errors = await _captureFlutterErrors(
          () async => await tester.pump(),
        );

        expect(errors.length, 1);
        expect(errors.first.exception, isA<Exception>());
        expect(errors.first.exception.toString(), startsWith("Exception: Found 2 duplicate input IDs this frame:"));
      }, variant: _roleVariant);
    });
  });
}

final _roleVariant = ValueVariant({null, "Chat"});

Future<void> _pumpScaffold(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: child,
      ),
    ),
  );
}

final _emptyParagraph = MutableDocument(
  nodes: [
    ParagraphNode(id: "1", text: AttributedText()),
  ],
);

FutureOr<List<FlutterErrorDetails>> _captureFlutterErrors(FutureOr<void> Function() test) async {
  final errors = <FlutterErrorDetails>[];

  final originalOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    errors.add(details);
  };

  await test();

  // Restore the original handler to avoid affecting other tests
  FlutterError.onError = originalOnError;

  return errors;
}
