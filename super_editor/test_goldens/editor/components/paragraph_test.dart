import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:super_editor/super_test.dart';

void main() {
  group('SuperEditor', () {
    testGoldensOnAndroid('displays paragraphs with different alignments', (tester) async {
      await tester.createDocument().withCustomContent(_createParagraphTestDoc()).pump();

      await screenMatchesGolden(tester, 'paragraph_alignments');
    });
  });
}

MutableDocument _createParagraphTestDoc() {
  return MutableDocument(
    nodes: [
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
          'Various paragraph formations',
        ),
        metadata: {
          'blockType': header1Attribution,
        },
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
          'This is a short\nparagraph of text\nthat is left aligned',
        ),
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
          'This is a short\nparagraph of text\nthat is center aligned',
        ),
        metadata: {
          'textAlign': 'center',
        },
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
          'This is a short\nparagraph of text\nthat is right aligned',
        ),
        metadata: {
          'textAlign': 'right',
        },
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
          'orem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus sed sagittis urna. Aenean mattis ante justo, quis sollicitudin metus interdum id. Aenean ornare urna ac enim consequat mollis. In aliquet convallis efficitur. Phasellus convallis purus in fringilla scelerisque. Ut ac orci a turpis egestas lobortis. Morbi aliquam dapibus sem, vitae sodales arcu ultrices eu. Duis vulputate mauris quam, eleifend pulvinar quam blandit eget.',
        ),
      ),
    ],
  );
}
