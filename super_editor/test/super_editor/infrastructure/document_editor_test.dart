import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

import '../../../lib/src/test/super_reader_test/reader_test_tools.dart';

void main() {
  group('MutableDocument', () {
    group('.moveNode()', () {
      test('when the document is empty, throws an exception', () {
        final document = MutableDocument(nodes: []);
        expect(
          () => document.moveNode(nodeId: 'does-not-exist', targetIndex: 0),
          throwsException,
        );
      });

      test('when the node does not exist in the document, throws an exception', () {
        final node = ParagraphNode(id: 'move-me', text: AttributedText());
        final document = MutableDocument(
          nodes: [
            HorizontalRuleNode(id: '0'),
            node,
            HorizontalRuleNode(id: '2'),
          ],
        );

        expect(
          () => document.moveNode(nodeId: 'does-not-exist', targetIndex: 0),
          throwsException,
        );
      });

      test('when the given target index is negative, throws a RangeError', () {
        final node = ParagraphNode(id: 'move-me', text: AttributedText());
        final document = MutableDocument(
          nodes: [
            HorizontalRuleNode(id: '0'),
            node,
            HorizontalRuleNode(id: '2'),
          ],
        );

        expect(
          () => document.moveNode(nodeId: 'move-me', targetIndex: -1),
          throwsRangeError,
        );
      });

      test('when the given target index is out of document bounds, throws a RangeError', () {
        final node = ParagraphNode(id: 'move-me', text: AttributedText());
        final document = MutableDocument(
          nodes: [
            HorizontalRuleNode(id: '0'),
            node,
            HorizontalRuleNode(id: '2'),
          ],
        );

        expect(
          () => document.moveNode(nodeId: 'move-me', targetIndex: 3),
          throwsRangeError,
        );
      });

      test('when the node exists in the document, and the targetIndex is valid, moves it to the given target index',
          () {
        final node = ParagraphNode(id: 'move-me', text: AttributedText());
        final document = MutableDocument(
          nodes: [
            HorizontalRuleNode(id: '0'),
            node,
            HorizontalRuleNode(id: '2'),
          ],
        );

        document.moveNode(nodeId: 'move-me', targetIndex: 0);
        expect(
          document,
          documentEquivalentTo(
            MutableDocument(
              nodes: [
                node, // Node exists at index 0
                HorizontalRuleNode(id: '0'),
                HorizontalRuleNode(id: '2'),
              ],
            ),
          ),
        );

        document.moveNode(nodeId: 'move-me', targetIndex: 2);
        expect(
          document,
          documentEquivalentTo(
            MutableDocument(
              nodes: [
                HorizontalRuleNode(id: '0'),
                HorizontalRuleNode(id: '2'),
                node, // Node exists at index 2
              ],
            ),
          ),
        );

        document.moveNode(nodeId: 'move-me', targetIndex: 1);
        expect(
          document,
          documentEquivalentTo(
            MutableDocument(
              nodes: [
                HorizontalRuleNode(id: '0'),
                node, // Node exists at index 1
                HorizontalRuleNode(id: '2'),
              ],
            ),
          ),
        );
      });
    });

    test('it replaces one node by another ', () {
      final oldNode = ParagraphNode(id: 'old', text: AttributedText());
      final document = MutableDocument(
        nodes: [
          HorizontalRuleNode(id: '0'),
          oldNode,
          HorizontalRuleNode(id: '2'),
        ],
      );

      final newNode = ParagraphNode(id: 'new', text: AttributedText());
      document.replaceNode(oldNode: oldNode, newNode: newNode);

      // oldNode does not exist
      expect(document.contains(oldNode), false);
      // newNode exists at index 1
      expect(document.getNodeIndexById(newNode.id), 1);
    });

    test('it is equal to another document when both documents are empty', () {
      final document1 = MutableDocument(nodes: []);
      final document2 = MutableDocument(nodes: []);

      expect(document1 == document2, isTrue);
    });

    test(
        'it is equal to another document when each content node is equal to the corresponding node in the other document',
        () {
      final document1 = MutableDocument(nodes: [
        TextNode(
          id: '1',
          text: AttributedText(
            'a',
            AttributedSpans(),
          ),
        ),
      ]);
      final document2 = MutableDocument(nodes: [
        TextNode(
          id: '1',
          text: AttributedText(
            'a',
            AttributedSpans(),
          ),
        ),
      ]);

      expect(document1 == document2, isTrue);
    });

    test('it is NOT equal to a document with the same starting nodes but with additional nodes at the end', () {
      final document1 = MutableDocument(nodes: [HorizontalRuleNode(id: '1')]);
      final document2 = MutableDocument(nodes: [HorizontalRuleNode(id: '1'), HorizontalRuleNode(id: '2')]);

      expect(document1 == document2, isFalse);
    });

    test('it is NOT equal to a document when corresponding nodes are NOT equal', () {
      final document1 = MutableDocument(nodes: [HorizontalRuleNode(id: '1')]);
      final document2 = MutableDocument(nodes: [HorizontalRuleNode(id: '2')]);

      expect(document1 == document2, isFalse);
    });
  });
}
