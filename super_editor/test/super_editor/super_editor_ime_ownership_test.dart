import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/default_editor/default_document_editor.dart';
import 'package:super_editor/src/default_editor/super_editor.dart';

void main() {
  group("Super Editor > IME ownership >", () {
    testWidgets("throws exception on 2+ identical roles during build", (tester) async {
      final editor1 = createDefaultDocumentEditor();
      final editor2 = createDefaultDocumentEditor();

      // Ensure that we can pump a single editor with a role.
      await _pumpScaffold(
        tester,
        SuperEditor(
          editor: editor1,
          inputRole: "Global",
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
                  inputRole: "Global",
                ),
              ),
              Expanded(
                child: SuperEditor(
                  editor: editor2,
                  // This is the same role as above, which isn't allowed.
                  inputRole: "Global",
                ),
              ),
            ],
          ),
        ),
      );

      expect(errors.length, 1);
      expect(errors.first.exception, isA<Exception>());
      expect(errors.first.exception.toString(), startsWith("Exception: Found 2 duplicate input IDs this frame:"));
    });
  });
}

Future<void> _pumpScaffold(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: child,
      ),
    ),
  );
}

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
