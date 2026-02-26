import 'package:super_editor/prose_mirror.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Document Lifecycle', () {
    test('User opens an existing document', () {
      final paragraph = DocumentNode.paragraph([DocumentNode.text(AttributedText('Existing content'))]);
      final document = DocumentNode.root([paragraph]);

      final state = EditorState.create(document);

      expect(state.document.children.length, equals(1));
      expect(state.document.children.first.children.first.text?.text, equals('Existing content'));
    });
  });

  group('Human Editing Actions', () {
    test('User types text into a blank document', () {
      final blankParagraph = DocumentNode.paragraph([]);
      final document = DocumentNode.root([blankParagraph]);
      var state = EditorState.create(document);

      var transaction = state.buildTransaction();
      transaction = transaction.applyStep(InsertTextStep.at(0, AttributedText('Hello world')));
      state = state.apply(transaction);

      final firstParagraph = state.document.children.first;
      final textNode = firstParagraph.children.first;
      expect(textNode.text?.text, equals('Hello world'));
    });

    test('User presses Enter to create a new paragraph', () {
      final paragraph = DocumentNode.paragraph([DocumentNode.text(AttributedText('Hello world'))]);
      final document = DocumentNode.root([paragraph]);
      var state = EditorState.create(document);

      var transaction = state.buildTransaction();
      // Simulating pressing Enter between "Hello " and "world"
      transaction = transaction.applyStep(SplitNodeStep.at(6));
      state = state.apply(transaction);

      expect(state.document.children.length, equals(2));

      final firstParagraph = state.document.children.first;
      expect(firstParagraph.children.first.text?.text, equals('Hello '));

      final secondParagraph = state.document.children.last;
      expect(secondParagraph.children.first.text?.text, equals('world'));
    });

    test('User deletes a word using backspace', () {
      final paragraph = DocumentNode.paragraph([DocumentNode.text(AttributedText('The quick brown fox'))]);
      final document = DocumentNode.root([paragraph]);
      var state = EditorState.create(document);

      var transaction = state.buildTransaction();
      // Simulating selecting "quick " and pressing backspace
      transaction = transaction.applyStep(DeleteContentStep.range(4, 10));
      state = state.apply(transaction);

      final firstParagraph = state.document.children.first;
      final textNode = firstParagraph.children.first;
      expect(textNode.text?.text, equals('The brown fox'));
    });

    test('User presses backspace at the start of a paragraph to merge it with the previous one', () {
      final paragraphOne = DocumentNode.paragraph([DocumentNode.text(AttributedText('First paragraph.'))]);
      final paragraphTwo = DocumentNode.paragraph([DocumentNode.text(AttributedText('Second paragraph.'))]);
      final document = DocumentNode.root([paragraphOne, paragraphTwo]);
      var state = EditorState.create(document);

      var transaction = state.buildTransaction();
      // Simulating pressing backspace at the start of paragraph two (block index 0 and 1)
      transaction = transaction.applyStep(JoinNodeStep.at(0));
      state = state.apply(transaction);

      expect(state.document.children.length, equals(1));

      final mergedParagraph = state.document.children.first;
      expect(mergedParagraph.children.length, equals(2));
      expect(mergedParagraph.children.first.text?.text, equals('First paragraph.'));
      expect(mergedParagraph.children.last.text?.text, equals('Second paragraph.'));
    });
  });

  group('Formatting and Media', () {
    test('User highlights text and makes it bold', () {
      final paragraph = DocumentNode.paragraph([DocumentNode.text(AttributedText('Make this bold text'))]);
      final document = DocumentNode.root([paragraph]);
      var state = EditorState.create(document);

      var transaction = state.buildTransaction();
      // Simulating highlighting "this bold" and pressing Ctrl+B
      transaction = transaction.applyStep(AddTextAttributeStep.range(5, 14, 'bold'));
      state = state.apply(transaction);

      final nextBlock = state.document.children.first;
      final nextTextNode = nextBlock.children.first;

      // Validating that the document structure updated correctly to hold the formatted text
      expect(identical(paragraph.children.first, nextTextNode), isFalse);
    });

    test('User inserts an image into the document', () {
      final paragraph = DocumentNode.paragraph([DocumentNode.text(AttributedText('Look at this image:'))]);
      final document = DocumentNode.root([paragraph]);
      var state = EditorState.create(document);

      var transaction = state.buildTransaction();
      // Simulating the user invoking an image picker and inserting a graphic below the paragraph
      final imageNode = DocumentNode.image('https://example.com/flutter.png');
      transaction = transaction.applyStep(InsertNodeStep.at(1, imageNode));
      state = state.apply(transaction);

      expect(state.document.children.length, equals(2));
      expect(state.document.children[0].type, equals(DocumentNode.typeParagraph));

      final insertedImage = state.document.children[1];
      expect(insertedImage.type, equals(DocumentNode.typeImage));
      expect(insertedImage.attributes['url'], equals('https://example.com/flutter.png'));
    });
  });
}
