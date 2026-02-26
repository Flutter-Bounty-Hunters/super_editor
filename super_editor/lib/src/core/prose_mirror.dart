class EditorState {
  factory EditorState.create(DocumentNode document) {
    return EditorState(document);
  }

  EditorState(this.document);

  final DocumentNode document;

  Transaction buildTransaction() {
    return Transaction.start(document);
  }

  EditorState apply(Transaction transaction) {
    return EditorState(transaction.document);
  }

  @override
  String toString() => 'EditorState(document: $document)';

  @override
  int get hashCode => document.hashCode;

  @override
  bool operator ==(Object other) => identical(this, other) || other is EditorState && document == other.document;
}

class Transaction {
  factory Transaction.start(DocumentNode document) {
    return Transaction(document, const []);
  }

  Transaction(this.document, this.steps);

  final DocumentNode document;
  final List<Step> steps;

  Transaction applyStep(Step step) {
    final nextDocument = step.apply(document);
    return Transaction(nextDocument, [...steps, step]);
  }

  bool _compareSteps(List<Step> a, List<Step> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  int _hashSteps(List<Step> list) {
    return list.fold(0, (hash, step) => hash ^ step.hashCode);
  }

  @override
  String toString() => 'Transaction(steps: ${steps.length})';

  @override
  int get hashCode => document.hashCode ^ _hashSteps(steps);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Transaction && document == other.document && _compareSteps(steps, other.steps);
}

class DocumentNode {
  static const String typeRoot = 'root';
  static const String typeParagraph = 'paragraph';
  static const String typeText = 'text';
  static const String typeHorizontalRule = 'hr';
  static const String typeImage = 'image';

  factory DocumentNode.root(List<DocumentNode> children) {
    return DocumentNode._(typeRoot, null, const {}, children);
  }

  factory DocumentNode.paragraph(List<DocumentNode> children) {
    return DocumentNode._(typeParagraph, null, const {}, children);
  }

  factory DocumentNode.text(AttributedText text) {
    return DocumentNode._(typeText, text, const {}, const []);
  }

  factory DocumentNode.horizontalRule() {
    return DocumentNode._(typeHorizontalRule, null, const {}, const []);
  }

  factory DocumentNode.image(String url) {
    return DocumentNode._(typeImage, null, {'url': url}, const []);
  }

  DocumentNode._(this.type, this.text, this.attributes, this.children);

  final String type;
  final AttributedText? text;
  final Map<String, String> attributes;
  final List<DocumentNode> children;

  int get textLength {
    if (type == typeText) {
      return text?.text.length ?? 0;
    }
    return children.fold(0, (sum, child) => sum + child.textLength);
  }

  DocumentNode copyWith({
    String? type,
    AttributedText? text,
    Map<String, String>? attributes,
    List<DocumentNode>? children,
  }) {
    return DocumentNode._(
      type ?? this.type,
      text ?? this.text,
      attributes ?? this.attributes,
      children ?? this.children,
    );
  }

  bool _compareNodes(List<DocumentNode> a, List<DocumentNode> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  int _hashNodes(List<DocumentNode> list) {
    return list.fold(0, (hash, node) => hash ^ node.hashCode);
  }

  bool _compareAttributes(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  int _hashAttributes(Map<String, String> map) {
    return map.keys.fold(0, (hash, key) => hash ^ key.hashCode ^ map[key].hashCode);
  }

  @override
  String toString() => 'DocumentNode(type: $type, children: ${children.length})';

  @override
  int get hashCode => type.hashCode ^ text.hashCode ^ _hashAttributes(attributes) ^ _hashNodes(children);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentNode &&
          type == other.type &&
          text == other.text &&
          _compareAttributes(attributes, other.attributes) &&
          _compareNodes(children, other.children);
}

class AttributedText {
  factory AttributedText.empty() {
    return AttributedText('');
  }

  AttributedText(this.text);

  final String text;

  AttributedText insert(int offset, AttributedText other) {
    return AttributedText(text.substring(0, offset) + other.text + text.substring(offset));
  }

  AttributedText delete(int start, int end) {
    return AttributedText(text.substring(0, start) + text.substring(end));
  }

  AttributedText addAttribute(int start, int end, String attribute) {
    return AttributedText(text);
  }

  @override
  String toString() => 'AttributedText(text: $text)';

  @override
  int get hashCode => text.hashCode;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AttributedText && text == other.text;
}

abstract class Step {
  Step();

  DocumentNode apply(DocumentNode document);
}

class InsertTextStep extends Step {
  factory InsertTextStep.at(int position, AttributedText text) {
    return InsertTextStep(position, text);
  }

  InsertTextStep(this.position, this.text);

  final int position;
  final AttributedText text;

  @override
  DocumentNode apply(DocumentNode document) {
    int currentOffset = 0;
    final newChildren = <DocumentNode>[];

    for (final block in document.children) {
      final blockLength = block.textLength;

      if (position >= currentOffset && position <= currentOffset + blockLength) {
        final localOffset = position - currentOffset;
        int currentTextOffset = 0;
        final newBlockChildren = <DocumentNode>[];

        for (final textNode in block.children) {
          final textLength = textNode.textLength;
          if (localOffset >= currentTextOffset && localOffset <= currentTextOffset + textLength) {
            final localTextOffset = localOffset - currentTextOffset;
            final newText = textNode.text!.insert(localTextOffset, text);
            newBlockChildren.add(textNode.copyWith(text: newText));
          } else {
            newBlockChildren.add(textNode);
          }
          currentTextOffset += textLength;
        }

        if (block.children.isEmpty) {
          newBlockChildren.add(DocumentNode.text(text));
        }

        newChildren.add(block.copyWith(children: newBlockChildren));
      } else {
        newChildren.add(block);
      }
      currentOffset += blockLength;
    }

    return document.copyWith(children: newChildren);
  }

  @override
  String toString() => 'InsertTextStep(position: $position, text: $text)';

  @override
  int get hashCode => position.hashCode ^ text.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is InsertTextStep && position == other.position && text == other.text;
}

class DeleteContentStep extends Step {
  factory DeleteContentStep.range(int start, int end) {
    return DeleteContentStep(start, end);
  }

  DeleteContentStep(this.start, this.end);

  final int start;
  final int end;

  @override
  DocumentNode apply(DocumentNode document) {
    int currentOffset = 0;
    final newChildren = <DocumentNode>[];

    for (final block in document.children) {
      final blockLength = block.textLength;
      final blockStart = currentOffset;
      final blockEnd = currentOffset + blockLength;

      if (end <= blockStart || start >= blockEnd) {
        newChildren.add(block);
      } else {
        final localStart = start > blockStart ? start - blockStart : 0;
        final localEnd = end < blockEnd ? end - blockStart : blockLength;

        int currentTextOffset = 0;
        final newBlockChildren = <DocumentNode>[];

        for (final textNode in block.children) {
          final textLength = textNode.textLength;
          final textStart = currentTextOffset;
          final textEnd = currentTextOffset + textLength;

          if (localEnd <= textStart || localStart >= textEnd) {
            newBlockChildren.add(textNode);
          } else {
            final sliceStart = localStart > textStart ? localStart - textStart : 0;
            final sliceEnd = localEnd < textEnd ? localEnd - textStart : textLength;
            final newText = textNode.text!.delete(sliceStart, sliceEnd);
            newBlockChildren.add(textNode.copyWith(text: newText));
          }
          currentTextOffset += textLength;
        }
        newChildren.add(block.copyWith(children: newBlockChildren));
      }
      currentOffset += blockLength;
    }
    return document.copyWith(children: newChildren);
  }

  @override
  String toString() => 'DeleteContentStep(start: $start, end: $end)';

  @override
  int get hashCode => start.hashCode ^ end.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DeleteContentStep && start == other.start && end == other.end;
}

class AddTextAttributeStep extends Step {
  factory AddTextAttributeStep.range(int start, int end, String attribute) {
    return AddTextAttributeStep(start, end, attribute);
  }

  AddTextAttributeStep(this.start, this.end, this.attribute);

  final int start;
  final int end;
  final String attribute;

  @override
  DocumentNode apply(DocumentNode document) {
    int currentOffset = 0;
    final newChildren = <DocumentNode>[];

    for (final block in document.children) {
      final blockLength = block.textLength;
      final blockStart = currentOffset;
      final blockEnd = currentOffset + blockLength;

      if (end <= blockStart || start >= blockEnd) {
        newChildren.add(block);
      } else {
        final localStart = start > blockStart ? start - blockStart : 0;
        final localEnd = end < blockEnd ? end - blockStart : blockLength;

        int currentTextOffset = 0;
        final newBlockChildren = <DocumentNode>[];

        for (final textNode in block.children) {
          final textLength = textNode.textLength;
          final textStart = currentTextOffset;
          final textEnd = currentTextOffset + textLength;

          if (localEnd <= textStart || localStart >= textEnd) {
            newBlockChildren.add(textNode);
          } else {
            final sliceStart = localStart > textStart ? localStart - textStart : 0;
            final sliceEnd = localEnd < textEnd ? localEnd - textStart : textLength;
            final newText = textNode.text!.addAttribute(sliceStart, sliceEnd, attribute);

            if (sliceStart > 0 || sliceEnd < textLength) {
              newBlockChildren.add(textNode.copyWith(text: newText));
            } else {
              newBlockChildren.add(textNode.copyWith(text: newText));
            }
          }
          currentTextOffset += textLength;
        }
        newChildren.add(block.copyWith(children: newBlockChildren));
      }
      currentOffset += blockLength;
    }
    return document.copyWith(children: newChildren);
  }

  @override
  String toString() => 'AddTextAttributeStep(start: $start, end: $end, attribute: $attribute)';

  @override
  int get hashCode => start.hashCode ^ end.hashCode ^ attribute.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AddTextAttributeStep && start == other.start && end == other.end && attribute == other.attribute;
}

class InsertNodeStep extends Step {
  factory InsertNodeStep.at(int position, DocumentNode node) {
    return InsertNodeStep(position, node);
  }

  InsertNodeStep(this.position, this.node);

  final int position;
  final DocumentNode node;

  @override
  DocumentNode apply(DocumentNode document) {
    if (position < 0 || position > document.children.length) {
      return document;
    }

    final newChildren = [
      ...document.children.sublist(0, position),
      node,
      ...document.children.sublist(position),
    ];

    return document.copyWith(children: newChildren);
  }

  @override
  String toString() => 'InsertNodeStep(position: $position, node: $node)';

  @override
  int get hashCode => position.hashCode ^ node.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is InsertNodeStep && position == other.position && node == other.node;
}

class SplitNodeStep extends Step {
  factory SplitNodeStep.at(int position) {
    return SplitNodeStep(position);
  }

  SplitNodeStep(this.position);

  final int position;

  @override
  DocumentNode apply(DocumentNode document) {
    int currentOffset = 0;
    final newChildren = <DocumentNode>[];

    for (final block in document.children) {
      final blockLength = block.textLength;

      if (position > currentOffset && position < currentOffset + blockLength) {
        final localOffset = position - currentOffset;
        final leftChildren = <DocumentNode>[];
        final rightChildren = <DocumentNode>[];

        int currentTextOffset = 0;
        for (final textNode in block.children) {
          final textLength = textNode.textLength;
          if (localOffset > currentTextOffset && localOffset < currentTextOffset + textLength) {
            final splitPoint = localOffset - currentTextOffset;
            final leftText = AttributedText(textNode.text!.text.substring(0, splitPoint));
            final rightText = AttributedText(textNode.text!.text.substring(splitPoint));

            leftChildren.add(textNode.copyWith(text: leftText));
            rightChildren.add(textNode.copyWith(text: rightText));
          } else if (currentTextOffset >= localOffset) {
            rightChildren.add(textNode);
          } else {
            leftChildren.add(textNode);
          }
          currentTextOffset += textLength;
        }
        newChildren.add(block.copyWith(children: leftChildren));
        newChildren.add(block.copyWith(children: rightChildren));
      } else {
        newChildren.add(block);
      }
      currentOffset += blockLength;
    }
    return document.copyWith(children: newChildren);
  }

  @override
  String toString() => 'SplitNodeStep(position: $position)';

  @override
  int get hashCode => position.hashCode;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SplitNodeStep && position == other.position;
}

class JoinNodeStep extends Step {
  factory JoinNodeStep.at(int position) {
    return JoinNodeStep(position);
  }

  JoinNodeStep(this.position);

  final int position;

  @override
  DocumentNode apply(DocumentNode document) {
    if (position < 0 || position >= document.children.length - 1) {
      return document;
    }

    final topNode = document.children[position];
    final bottomNode = document.children[position + 1];

    final mergedChildren = [...topNode.children, ...bottomNode.children];
    final mergedNode = topNode.copyWith(children: mergedChildren);

    final newDocumentChildren = [
      ...document.children.sublist(0, position),
      mergedNode,
      ...document.children.sublist(position + 2),
    ];

    return document.copyWith(children: newDocumentChildren);
  }

  @override
  String toString() => 'JoinNodeStep(position: $position)';

  @override
  int get hashCode => position.hashCode;

  @override
  bool operator ==(Object other) => identical(this, other) || other is JoinNodeStep && position == other.position;
}
