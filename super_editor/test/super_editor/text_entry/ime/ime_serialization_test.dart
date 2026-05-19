import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

void main() {
  group('IME input > document serialization >', () {
    test('partial paragraph selection', () {
      const text = "This is a paragraph of text.";

      _expectTextEditingValue(
        actualTextEditingValue: DocumentImeSerializer(
          MutableDocument(nodes: [
            ParagraphNode(id: "1", text: AttributedText(text)),
          ]),
          const DocumentSelection(
            base: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 10),
            ),
            extent: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 19),
            ),
          ),
          null,
        ).toTextEditingValue(),
        expectedTextWithSelection: ". This is a |paragraph| of text.",
      );
    });

    test('partial selection across back-to-back paragraphs', () {
      const text1 = "This is the first paragraph of text.";
      const text2 = "This is the second paragraph of text.";

      _expectTextEditingValue(
        actualTextEditingValue: DocumentImeSerializer(
          MutableDocument(nodes: [
            ParagraphNode(id: "1", text: AttributedText(text1)),
            ParagraphNode(id: "2", text: AttributedText(text2)),
          ]),
          const DocumentSelection(
            base: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 12),
            ),
            extent: DocumentPosition(
              nodeId: "2",
              nodePosition: TextNodePosition(offset: 28),
            ),
          ),
          null,
        ).toTextEditingValue(),
        expectedTextWithSelection: ". This is the |first paragraph of text.\nThis is the second paragraph| of text.",
      );
    });

    test('selection across two paragraphs with non-text node in between', () {
      const text = "This is a paragraph of text.";

      _expectTextEditingValue(
        actualTextEditingValue: DocumentImeSerializer(
          MutableDocument(nodes: [
            ParagraphNode(id: "1", text: AttributedText(text)),
            HorizontalRuleNode(id: "2"),
            ParagraphNode(id: "3", text: AttributedText(text)),
          ]),
          const DocumentSelection(
            base: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 10),
            ),
            extent: DocumentPosition(
              nodeId: "3",
              nodePosition: TextNodePosition(offset: 19),
            ),
          ),
          null,
        ).toTextEditingValue(),
        expectedTextWithSelection: ". This is a |paragraph of text.\n~\nThis is a paragraph| of text.",
      );
    });

    test('selection across non-text nodes with a paragraph in between', () {
      const text = "This is the first paragraph of text.";

      _expectTextEditingValue(
        actualTextEditingValue: DocumentImeSerializer(
          MutableDocument(nodes: [
            HorizontalRuleNode(id: "1"),
            ParagraphNode(id: "2", text: AttributedText(text)),
            HorizontalRuleNode(id: "3"),
          ]),
          const DocumentSelection(
            base: DocumentPosition(
              nodeId: "1",
              nodePosition: UpstreamDownstreamNodePosition.upstream(),
            ),
            extent: DocumentPosition(
              nodeId: "3",
              nodePosition: UpstreamDownstreamNodePosition.downstream(),
            ),
          ),
          null,
        ).toTextEditingValue(),
        expectedTextWithSelection: ". |~\nThis is the first paragraph of text.\n~|",
      );
    });

    testWidgetsOnArbitraryDesktop('sends selection to platform', (tester) async {
      final context = await tester //
          .createDocument()
          .withSingleParagraph()
          .withInputSource(TextInputSource.ime)
          .pump();

      // Place caret at Lorem| ipsum.
      await tester.placeCaretInParagraph('1', 5);

      int selectionBase = -1;
      int selectionExtent = -1;
      String selectionAffinity = "";

      // Intercept messages sent to the platform.
      tester.binding.defaultBinaryMessenger.setMockMessageHandler(SystemChannels.textInput.name, (message) async {
        final methodCall = const JSONMethodCodec().decodeMethodCall(message);
        if (methodCall.method == 'TextInput.setEditingState') {
          selectionBase = methodCall.arguments['selectionBase'];
          selectionExtent = methodCall.arguments['selectionExtent'];
          selectionAffinity = methodCall.arguments['selectionAffinity'];
        }
        return null;
      });

      // Press shift+left to expand the selection upstream.
      await tester.pressShiftLeftArrow();

      final selection = SuperEditorInspector.findDocumentSelection()!;
      final base = (selection.base.nodePosition as TextNodePosition).offset;
      final extent = (selection.extent.nodePosition as TextNodePosition).offset;
      final affinity = context.findEditContext().document.getAffinityForSelection(selection);

      // Ensure we sent the same base, extent and affinity to the platform.
      // Add two to account for the invisible characters prepended to the text.
      expect(selectionBase, base + 2);
      expect(selectionExtent, extent + 2);
      expect(selectionAffinity, affinity.toString());
    });

    group('editable non-text nodes >', () {
      group('serialization >', () {
        test('caret placement within an attachment list node', () {
          _expectTextEditingValue(
            actualTextEditingValue: DocumentImeSerializer(
              MutableDocument(nodes: [
                AttachmentListNode(id: "1", attachments: const [
                  'attachment1',
                  'attachment2',
                  'attachment3',
                ]),
              ]),
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: "1",
                  nodePosition: AttachmentListNodePosition.start,
                ),
              ),
              null,
            ).toTextEditingValue(),
            expectedTextWithSelection: ". |~~~",
          );
        });

        test('expanded selection within an attachment list node', () {
          _expectTextEditingValue(
            actualTextEditingValue: DocumentImeSerializer(
              MutableDocument(nodes: [
                AttachmentListNode(id: "1", attachments: const [
                  'attachment1',
                  'attachment2',
                  'attachment3',
                ]),
              ]),
              const DocumentSelection(
                base: DocumentPosition(
                  nodeId: "1",
                  nodePosition: AttachmentListNodePosition(1, TextAffinity.upstream),
                ),
                extent: DocumentPosition(
                  nodeId: "1",
                  nodePosition: AttachmentListNodePosition(2, TextAffinity.downstream),
                ),
              ),
              null,
            ).toTextEditingValue(),
            expectedTextWithSelection: ". ~|~~|",
          );
        });

        test('selection across paragraphs with attachment list node in between', () {
          const text = "This is a paragraph of text.";

          _expectTextEditingValue(
            actualTextEditingValue: DocumentImeSerializer(
              MutableDocument(nodes: [
                ParagraphNode(id: "1", text: AttributedText(text)),
                AttachmentListNode(id: "2", attachments: const [
                  'attachment1',
                  'attachment2',
                  'attachment3',
                ]),
                ParagraphNode(id: "3", text: AttributedText(text)),
              ]),
              const DocumentSelection(
                base: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 10),
                ),
                extent: DocumentPosition(
                  nodeId: "3",
                  nodePosition: TextNodePosition(offset: 19),
                ),
              ),
              null,
            ).toTextEditingValue(),
            expectedTextWithSelection: ". This is a |paragraph of text.\n~~~\nThis is a paragraph| of text.",
          );
        });

        test('selection across attachment list nodes with text in between', () {
          _expectTextEditingValue(
            actualTextEditingValue: DocumentImeSerializer(
              MutableDocument(nodes: [
                AttachmentListNode(id: "1", attachments: const [
                  'attachment1',
                  'attachment2',
                  'attachment3',
                ]),
                ParagraphNode(id: "2", text: AttributedText("This is a paragraph of text.")),
                AttachmentListNode(id: "3", attachments: const [
                  'attachment4',
                  'attachment5',
                  'attachment6',
                ]),
              ]),
              const DocumentSelection(
                base: DocumentPosition(
                  nodeId: "1",
                  nodePosition: AttachmentListNodePosition(1, TextAffinity.upstream),
                ),
                extent: DocumentPosition(
                  nodeId: "3",
                  nodePosition: AttachmentListNodePosition(1, TextAffinity.downstream),
                ),
              ),
              null,
            ).toTextEditingValue(),
            expectedTextWithSelection: ". ~|~~\nThis is a paragraph of text.\n~~|~",
          );
        });

        test('selection across attachment list nodes with HR in between', () {
          _expectTextEditingValue(
            actualTextEditingValue: DocumentImeSerializer(
              MutableDocument(nodes: [
                AttachmentListNode(id: "1", attachments: const [
                  'attachment1',
                  'attachment2',
                  'attachment3',
                ]),
                HorizontalRuleNode(id: "2"),
                AttachmentListNode(id: "3", attachments: const [
                  'attachment4',
                  'attachment5',
                  'attachment6',
                ]),
              ]),
              const DocumentSelection(
                base: DocumentPosition(
                  nodeId: "1",
                  nodePosition: AttachmentListNodePosition(1, TextAffinity.upstream),
                ),
                extent: DocumentPosition(
                  nodeId: "3",
                  nodePosition: AttachmentListNodePosition(1, TextAffinity.downstream),
                ),
              ),
              null,
            ).toTextEditingValue(),
            expectedTextWithSelection: ". ~|~~\n~\n~~|~",
          );
        });
      });

      group('deserialization >', () {
        // TODO:
      });
    });
  });
}

/// Expects that the given [expectedTextWithSelection] corresponds to a
/// `TextEditingValue` that matches [actualTextEditingValue].
///
/// By combining the expected text with the expected selection into a formatted
/// `String`, this method provides a naturally readable expectation, as opposed
/// to a `TextSelection` with indices. For example, if the expected selection is
/// `TextSelection(base: 10, extent: 19)`, what segment of text does that include?
/// Instead, the caller provides a formatted `String`, like "Here is so|me text w|ith selection".
///
/// [expectedTextWithSelection] represents the expected text, and the expected
/// selection, all in one. The text within [expectedTextWithSelection] that
/// should be selected should be surrounded with "|" vertical bars.
///
/// Example:
///
///     This is expected text, and |this is the expected selection|.
///
/// This method doesn't work with text that actually contains "|" vertical bars.
void _expectTextEditingValue({
  required String expectedTextWithSelection,
  required TextEditingValue actualTextEditingValue,
}) {
  final selectionStartIndex = expectedTextWithSelection.indexOf("|");

  var selectionEndIndex =
      expectedTextWithSelection.indexOf("|", selectionStartIndex + 1) - 1; // -1 to account for the selection start "|"
  selectionEndIndex = selectionEndIndex >= 0 ? selectionEndIndex : selectionStartIndex;

  final expectedText = expectedTextWithSelection.replaceAll("|", "");
  final expectedSelection = TextSelection(baseOffset: selectionStartIndex, extentOffset: selectionEndIndex);

  expect(
    actualTextEditingValue,
    equalsTextEditingValue(
      TextEditingValue(text: expectedText, selection: expectedSelection),
    ),
  );
}

Matcher equalsTextEditingValue(TextEditingValue expected) => TextEditingValueMatcher(expected);

class TextEditingValueMatcher extends Matcher {
  const TextEditingValueMatcher(this.expected);

  final TextEditingValue expected;

  @override
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) {
    if (item is! TextEditingValue) {
      return false;
    }
    return item.text == expected.text && item.selection == expected.selection;
  }

  @override
  Description describe(Description description) {
    return description.add(_format(expected));
  }

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (item is! TextEditingValue) {
      return mismatchDescription.add('is not a TextEditingValue');
    }

    String expectedFormatted = _format(expected);
    String actualFormatted = _format(item);

    if (expectedFormatted == actualFormatted && expected.selection != item.selection) {
      expectedFormatted = _format(expected, includeDirectionInfo: true);
      actualFormatted = _format(item, includeDirectionInfo: true);
    }

    return mismatchDescription.add('is $actualFormatted');
  }

  String _format(TextEditingValue value, {bool includeDirectionInfo = false}) {
    final String text = value.text;
    final TextSelection selection = value.selection;

    if (!selection.isValid) {
      return '"$text" (invalid selection)';
    }

    final int baseOffset = max(0, min(selection.baseOffset, text.length));
    final int extentOffset = max(0, min(selection.extentOffset, text.length));

    final StringBuffer buffer = StringBuffer();
    buffer.write('"');

    if (selection.isCollapsed) {
      buffer.write(text.substring(0, baseOffset));
      buffer.write('|');
      buffer.write(text.substring(baseOffset));
    } else {
      final int startOffset = min(baseOffset, extentOffset);
      final int endOffset = max(baseOffset, extentOffset);

      buffer.write(text.substring(0, startOffset));
      buffer.write('|');
      buffer.write(text.substring(startOffset, endOffset));
      buffer.write('|');
      buffer.write(text.substring(endOffset));
    }

    buffer.write('"');

    if (includeDirectionInfo && !selection.isCollapsed) {
      buffer.write(' (base: ${selection.baseOffset}, extent: ${selection.extentOffset})');
    }

    return buffer.toString();
  }
}
