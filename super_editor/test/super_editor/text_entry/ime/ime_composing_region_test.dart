import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

void main() {
  group('IME input >', () {
    group('clears composing region', () {
      testWidgetsOnAllPlatforms('after losing focus', (tester) async {
        final focusNode = FocusNode();

        final testContext = await tester
            .createDocument() //
            .withTwoEmptyParagraphs()
            .withInputSource(TextInputSource.ime)
            .withFocusNode(focusNode)
            .pump();

        // Place the caret at the beginning of the document.
        await tester.placeCaretInParagraph('1', 0);

        // Type something to have some text to tap on.
        await tester.typeImeText('Composing: ');

        // Ensure we don't have a composing region.
        expect(testContext.composer.composingRegion.value, isNull);

        // Simulate an insertion containing a composing region.
        await tester.ime.sendDeltas(
          [
            const TextEditingDeltaInsertion(
              oldText: '. Composing: ',
              textInserted: "あs",
              insertionOffset: 13,
              selection: TextSelection.collapsed(offset: 15),
              composing: TextRange(start: 13, end: 15),
            ),
          ],
          getter: imeClientGetter,
        );

        // Ensure the editor applied a composing region.
        expect(
          testContext.composer.composingRegion.value,
          isNotNull,
        );

        // Remove focus from the editor.
        focusNode.unfocus();
        await tester.pump();

        // Ensure the composing region was cleared.
        expect(testContext.composer.composingRegion.value, isNull);
      });

      testWidgetsOnAllPlatforms('after selection changes', (tester) async {
        final testContext = await tester
            .createDocument() //
            .withTwoEmptyParagraphs()
            .withInputSource(TextInputSource.ime)
            .pump();

        // Place the caret at the beginning of the document.
        await tester.placeCaretInParagraph('1', 0);

        // Type something to have some text to tap on.
        await tester.typeImeText('Composing: ');

        // Ensure we don't have a composing region.
        expect(testContext.composer.composingRegion.value, isNull);

        // Simulate an insertion containing a composing region.
        await tester.ime.sendDeltas(
          [
            const TextEditingDeltaInsertion(
              oldText: '. Composing: ',
              textInserted: "あs",
              insertionOffset: 13,
              selection: TextSelection.collapsed(offset: 15),
              composing: TextRange(start: 13, end: 15),
            ),
          ],
          getter: imeClientGetter,
        );

        // Ensure the editor applied a composing region.
        expect(
          testContext.composer.composingRegion.value,
          isNotNull,
        );

        // Intercept the setEditingState message sent to the platform to check if we
        // cleared the IME composing region when changing the selection.
        int? composingBase;
        int? composingExtent;
        tester
            .interceptChannel(SystemChannels.textInput.name) //
            .interceptMethod(
          'TextInput.setEditingState',
          (methodCall) {
            final params = methodCall.arguments as Map;
            composingBase = params['composingBase'];
            composingExtent = params['composingExtent'];

            return null;
          },
        );

        // Place the caret at the second paragraph.
        await tester.placeCaretInParagraph('2', 0);

        // Ensure the composing region was cleared in the IME.
        expect(composingBase, -1);
        expect(composingExtent, -1);

        // Ensure SuperEditor composing region was cleared.
        expect(testContext.composer.composingRegion.value, isNull);
      });

      testWidgetsOnAllPlatforms('when moving the caret up', (tester) async {
        // FIXME: When we intercept the text input messages, the test text input
        // does not reset some internal state, which causes macOS selectors
        // to not be reported. Remove this after this is fixed.
        SystemChannels.textInput.invokeMethod("TextInput.hide");

        final testContext = await tester
            .createDocument() //
            .fromMarkdown('A\n\nB')
            .withInputSource(TextInputSource.ime)
            .pump();

        // Place the caret at the end of the second paragraph.
        await tester.placeCaretInParagraph(testContext.document.last.id, 1);

        // Place the composing region at the same position as the caret.
        final lastCharacterPosition = DocumentPosition(
          nodeId: testContext.document.last.id,
          nodePosition: const TextNodePosition(offset: 1),
        );
        testContext.editor.execute([
          ChangeComposingRegionRequest(
            DocumentRange(
              start: lastCharacterPosition,
              end: lastCharacterPosition,
            ),
          ),
        ]);
        await tester.pump();

        // Ensure we have a composing region.
        expect(testContext.composer.composingRegion.value, isNotNull);

        // Intercept the setEditingState message sent to the platform to check if we
        // cleared the IME composing region after moving the caret up.
        int? composingBase;
        int? composingExtent;
        tester
            .interceptChannel(SystemChannels.textInput.name) //
            .interceptMethod(
          'TextInput.setEditingState',
          (methodCall) {
            final params = methodCall.arguments as Map;
            composingBase = params['composingBase'];
            composingExtent = params['composingExtent'];

            return null;
          },
        );

        // Press up arrow to move the caret to the first paragraph.
        await tester.pressUpArrow();

        // Ensure SuperEditor composing region was cleared.
        expect(testContext.composer.composingRegion.value, isNull);

        // Ensure the composing region was cleared in the IME.
        expect(composingBase, -1);
        expect(composingExtent, -1);
      });

      testWidgetsOnAllPlatforms('when moving the caret upstream', (tester) async {
        // FIXME: When we intercept the text input messages, the test text input
        // does not reset some internal state, which causes macOS selectors
        // to not be reported. Remove this after this is fixed.
        SystemChannels.textInput.invokeMethod("TextInput.hide");

        final testContext = await tester
            .createDocument() //
            .fromMarkdown('A\n\nB')
            .withInputSource(TextInputSource.ime)
            .pump();

        // Place the caret at the beginning of the second paragraph.
        await tester.placeCaretInParagraph(testContext.document.last.id, 0);

        // Place the composing region at the same position as the caret.
        final lastCharacterPosition = DocumentPosition(
          nodeId: testContext.document.last.id,
          nodePosition: const TextNodePosition(offset: 0),
        );
        testContext.editor.execute([
          ChangeComposingRegionRequest(
            DocumentRange(
              start: lastCharacterPosition,
              end: lastCharacterPosition,
            ),
          ),
        ]);
        await tester.pump();

        // Ensure we have a composing region.
        expect(testContext.composer.composingRegion.value, isNotNull);

        // Intercept the setEditingState message sent to the platform to check if we
        // cleared the IME composing region when merging paragraphs.
        int? composingBase;
        int? composingExtent;
        tester
            .interceptChannel(SystemChannels.textInput.name) //
            .interceptMethod(
          'TextInput.setEditingState',
          (methodCall) {
            final params = methodCall.arguments as Map;
            composingBase = params['composingBase'];
            composingExtent = params['composingExtent'];

            return null;
          },
        );

        // Press up arrow to move the caret to the first paragraph.
        await tester.pressLeftArrow();

        // Ensure the composing region was cleared in the IME.
        expect(composingBase, -1);
        expect(composingExtent, -1);

        // Ensure SuperEditor composing region was cleared.
        expect(testContext.composer.composingRegion.value, isNull);
      });

      testWidgetsOnAllPlatforms('when moving the caret down', (tester) async {
        // FIXME: When we intercept the text input messages, the test text input
        // does not reset some internal state, which causes macOS selectors
        // to not be reported. Remove this after this is fixed.
        SystemChannels.textInput.invokeMethod("TextInput.hide");

        final testContext = await tester
            .createDocument() //
            .fromMarkdown('A\n\nC')
            .withInputSource(TextInputSource.ime)
            .pump();

        // Place the caret at the end of first paragraph.
        await tester.placeCaretInParagraph(testContext.document.first.id, 1);

        // Place the composing region at the same position as the caret.
        final lastCharacterPosition = DocumentPosition(
          nodeId: testContext.document.first.id,
          nodePosition: const TextNodePosition(offset: 1),
        );
        testContext.editor.execute([
          ChangeComposingRegionRequest(
            DocumentRange(
              start: lastCharacterPosition,
              end: lastCharacterPosition,
            ),
          ),
        ]);
        await tester.pump();

        // Ensure we have a composing region.
        expect(testContext.composer.composingRegion.value, isNotNull);

        // Intercept the setEditingState message sent to the platform to check if we
        // cleared the IME composing region when merging paragraphs.
        int? composingBase;
        int? composingExtent;
        tester
            .interceptChannel(SystemChannels.textInput.name) //
            .interceptMethod(
          'TextInput.setEditingState',
          (methodCall) {
            final params = methodCall.arguments as Map;
            composingBase = params['composingBase'];
            composingExtent = params['composingExtent'];

            return null;
          },
        );

        // Press down arrow to move the caret to the second paragraph.
        await tester.pressDownArrow();

        // Ensure the composing region was cleared in the IME.
        expect(composingBase, -1);
        expect(composingExtent, -1);

        // Ensure SuperEditor composing region was cleared.
        expect(testContext.composer.composingRegion.value, isNull);
      });

      testWidgetsOnAllPlatforms('when moving the caret downstream', (tester) async {
        // FIXME: When we intercept the text input messages, the test text input
        // does not reset some internal state, which causes macOS selectors
        // to not be reported. Remove this after this is fixed.
        SystemChannels.textInput.invokeMethod("TextInput.hide");

        final testContext = await tester
            .createDocument() //
            .fromMarkdown('A\n\nB')
            .withInputSource(TextInputSource.ime)
            .pump();

        // Place the caret at the end of the first paragraph.
        await tester.placeCaretInParagraph(testContext.document.first.id, 1);

        // Place the composing region at the same position as the caret.
        final lastCharacterPosition = DocumentPosition(
          nodeId: testContext.document.first.id,
          nodePosition: const TextNodePosition(offset: 1),
        );
        testContext.editor.execute([
          ChangeComposingRegionRequest(
            DocumentRange(
              start: lastCharacterPosition,
              end: lastCharacterPosition,
            ),
          ),
        ]);
        await tester.pump();

        // Ensure we have a composing region.
        expect(testContext.composer.composingRegion.value, isNotNull);

        // Intercept the setEditingState message sent to the platform to check if we
        // cleared the IME composing region when merging paragraphs.
        int? composingBase;
        int? composingExtent;
        tester
            .interceptChannel(SystemChannels.textInput.name) //
            .interceptMethod(
          'TextInput.setEditingState',
          (methodCall) {
            final params = methodCall.arguments as Map;
            composingBase = params['composingBase'];
            composingExtent = params['composingExtent'];

            return null;
          },
        );

        // Press right arrow to move the caret to the second paragraph.
        await tester.pressRightArrow();

        // Ensure the composing region was cleared in the IME.
        expect(composingBase, -1);
        expect(composingExtent, -1);

        // Ensure SuperEditor composing region was cleared.
        expect(testContext.composer.composingRegion.value, isNull);
      });

      testWidgetsOnMac('after merging paragraphs', (tester) async {
        final testContext = await tester
            .createDocument() //
            .withTwoEmptyParagraphs()
            .withInputSource(TextInputSource.ime)
            .pump();

        // Place the caret at the beginning of the second paragraph.
        await tester.placeCaretInParagraph('2', 0);

        // Ensure we don't have a composing region.
        expect(testContext.composer.composingRegion.value, isNull);

        // Simulate an insertion containing a composing region.
        await tester.ime.sendDeltas(
          [
            const TextEditingDeltaNonTextUpdate(
              oldText: '. ',
              selection: TextSelection.collapsed(offset: 2),
              composing: TextRange(start: 2, end: 2),
            ),
            const TextEditingDeltaInsertion(
              oldText: '. ',
              textInserted: 'あ',
              insertionOffset: 2,
              selection: TextSelection.collapsed(offset: 3),
              composing: TextRange(start: 2, end: 3),
            ),
          ],
          getter: imeClientGetter,
        );

        // Ensure the editor applied the composing region.
        expect(
          testContext.composer.composingRegion.value,
          isNotNull,
        );

        // Intercept the setEditingState message sent to the platform to check if we
        // cleared the IME composing region when merging paragraphs.
        int? composingBase;
        int? composingExtent;
        tester
            .interceptChannel(SystemChannels.textInput.name) //
            .interceptMethod(
          'TextInput.setEditingState',
          (methodCall) {
            final params = methodCall.arguments as Map;
            composingBase = params['composingBase'];
            composingExtent = params['composingExtent'];

            return null;
          },
        );

        // Simulate the user pressing BACKSPACE to delete the first character.
        // Even though the selection sits after a whitespace in the IME, mac still reports
        // a composing region starting after the space.
        await tester.ime.sendDeltas(
          [
            const TextEditingDeltaDeletion(
              oldText: '. あ',
              deletedRange: TextRange(start: 2, end: 3),
              selection: TextSelection.collapsed(offset: 2),
              composing: TextRange(start: 2, end: 2),
            ),
          ],
          getter: imeClientGetter,
        );

        // Ensure we still have a composing region in the editor.
        expect(
          testContext.composer.composingRegion.value,
          isNotNull,
        );

        // Simulate the user pressing BACKSPACE to merge the paragraphs.
        // Now that we are deleting a whitespace, mac reports a deleteBackward: selector
        // instead of a deletion delta.
        await _receiveSelector('deleteBackward:');
        await tester.pump();

        // Ensure the composing region was cleared in the IME.
        expect(composingBase, -1);
        expect(composingExtent, -1);

        // Ensure SuperEditor composing region was cleared.
        expect(testContext.composer.composingRegion.value, isNull);

        // Ensure the paragraphs were merged.
        expect(testContext.document.nodeCount, equals(1));
      });
    });

    group('only rebuilds the composing paragraph', () {
      // Super Editor only shows the composing underline on macOS, iOS, and Android.
      testWidgetsOnMac('when a composition starts', _startComposingInParagraph);
      testWidgetsOnMobile('when a composition starts', _startComposingInParagraph);

      testWidgetsOnMac('when a composition ends', _stopComposingInParagraph);
      testWidgetsOnMobile('when a composition ends', _stopComposingInParagraph);
    });
  });
}

/// Starts composing the word "Second" in the second of three paragraphs, and checks that only that
/// paragraph's component is built again.
Future<void> _startComposingInParagraph(WidgetTester tester) async {
  final componentBuilds = <String, int>{};
  await _pumpThreeParagraphs(tester, componentBuilds: componentBuilds);

  // Place the caret at the end of the word "Second".
  await tester.placeCaretInParagraph('2', 6);

  // Start composing the word.
  componentBuilds.clear();
  await _changeImeComposingRegion(tester, (caretOffset) => TextRange(start: caretOffset - 6, end: caretOffset));

  // Ensure that the word is composing.
  expect(
    SuperEditorInspector.findComposingRegion(),
    const DocumentRange(
      start: DocumentPosition(nodeId: '2', nodePosition: TextNodePosition(offset: 0)),
      end: DocumentPosition(nodeId: '2', nodePosition: TextNodePosition(offset: 6)),
    ),
  );

  // Ensure that only the component of the paragraph with the composing region was built again.
  expect(
    componentBuilds,
    {'2': 1},
    reason: 'Starting a composition in one paragraph should build only that paragraph\'s component',
  );
}

/// Stops composing the word "Second" in the second of three paragraphs, and checks that only that
/// paragraph's component is built again.
Future<void> _stopComposingInParagraph(WidgetTester tester) async {
  final componentBuilds = <String, int>{};
  await _pumpThreeParagraphs(tester, componentBuilds: componentBuilds);

  // Place the caret at the end of the word "Second", and start composing the word.
  await tester.placeCaretInParagraph('2', 6);
  await _changeImeComposingRegion(tester, (caretOffset) => TextRange(start: caretOffset - 6, end: caretOffset));

  // Stop composing the word.
  componentBuilds.clear();
  await _changeImeComposingRegion(tester, (caretOffset) => TextRange.empty);

  // Ensure that nothing is composing.
  expect(SuperEditorInspector.findComposingRegion(), isNull);

  // Ensure that only the component of the paragraph that had the composing region was built again.
  expect(
    componentBuilds,
    {'2': 1},
    reason: 'Ending a composition in one paragraph should build only that paragraph\'s component',
  );
}

/// Pumps a [SuperEditor] with three paragraphs, whose IDs are "1", "2", and "3", which counts,
/// in [componentBuilds], how many times it builds the component of each node, by node ID.
Future<void> _pumpThreeParagraphs(WidgetTester tester, {required Map<String, int> componentBuilds}) async {
  await tester
      .createDocument()
      .withCustomContent(
        MutableDocument(
          nodes: [
            ParagraphNode(id: '1', text: AttributedText('First paragraph')),
            ParagraphNode(id: '2', text: AttributedText('Second paragraph')),
            ParagraphNode(id: '3', text: AttributedText('Third paragraph')),
          ],
        ),
      )
      .withInputSource(TextInputSource.ime)
      .withComponentBuilders([
    for (final builder in defaultComponentBuilders) _BuildCountingComponentBuilder(builder, componentBuilds),
  ]).pump();
}

/// Sends the IME a change of its composing region, to the region that [composingRegion] returns
/// for the IME's caret offset, without a change of its text or selection, as the platform does
/// when a composition starts or ends.
Future<void> _changeImeComposingRegion(WidgetTester tester, TextRange Function(int caretOffset) composingRegion) async {
  final imeValue = imeClientGetter().currentTextEditingValue!;
  await tester.ime.sendDeltas(
    [
      TextEditingDeltaNonTextUpdate(
        oldText: imeValue.text,
        selection: imeValue.selection,
        composing: composingRegion(imeValue.selection.extentOffset),
      ),
    ],
    getter: imeClientGetter,
  );
}

/// A [ComponentBuilder] that builds components with the [delegate], and counts, in
/// [componentBuilds], how many times it builds the component of each node, by node ID.
class _BuildCountingComponentBuilder implements ComponentBuilder {
  _BuildCountingComponentBuilder(this.delegate, this.componentBuilds);

  final ComponentBuilder delegate;

  final Map<String, int> componentBuilds;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) =>
      delegate.createViewModel(document, node);

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    final component = delegate.createComponent(componentContext, componentViewModel);
    if (component != null) {
      componentBuilds[componentViewModel.nodeId] = (componentBuilds[componentViewModel.nodeId] ?? 0) + 1;
    }
    return component;
  }
}

/// Simulates a `TextInputClient.performSelectors` call from the platform.
Future<void> _receiveSelector(String selectorName) async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.textInput.name,
    SystemChannels.textInput.codec.encodeMethodCall(
      MethodCall(
        "TextInputClient.performSelectors",
        [
          -1,
          [selectorName],
        ],
      ),
    ),
    null,
  );
}
