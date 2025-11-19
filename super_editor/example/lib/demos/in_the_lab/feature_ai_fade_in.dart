import 'dart:async';
import 'dart:math';

import 'package:example/demos/in_the_lab/in_the_lab_scaffold.dart';
import 'package:flutter/material.dart' hide ListenableBuilder;
import 'package:super_editor/super_editor.dart';

class AiFadeInFeatureDemo extends StatefulWidget {
  const AiFadeInFeatureDemo({super.key});

  @override
  State<AiFadeInFeatureDemo> createState() => _AiFadeInFeatureDemoState();
}

class _AiFadeInFeatureDemoState extends State<AiFadeInFeatureDemo> with SingleTickerProviderStateMixin {
  late final MutableDocument _document;
  late final MutableDocumentComposer _composer;
  late final Editor _editor;
  late final FadeInStyler _fadeInStylePhase;

  late final _FakeAiWithEditor _fakeAiWithEditor;

  @override
  void initState() {
    super.initState();

    _document = MutableDocument.empty();
    _composer = MutableDocumentComposer(
      initialSelection: DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: _document.first.id,
          nodePosition: TextNodePosition(offset: 0),
        ),
      ),
    );
    _editor = createDefaultDocumentEditor(document: _document, composer: _composer);

    _fadeInStylePhase = FadeInStyler(this);

    _fakeAiWithEditor = _FakeAiWithEditor(_editor);
  }

  @override
  void dispose() {
    _fadeInStylePhase.dispose();

    _fakeAiWithEditor.dispose();

    _composer.dispose();
    _editor.dispose();
    _document.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InTheLabScaffold(
      content: SuperReader(
        editor: _editor,
        customStylePhases: [
          _fadeInStylePhase,
        ],
        stylesheet: defaultStylesheet.copyWith(
          selectedTextColorStrategy: ({
            required Color originalTextColor,
            required Color selectionHighlightColor,
          }) {
            return Colors.black;
          },
          addRulesAfter: [
            ...darkModeStyles,
          ],
        ),
      ),
      supplemental: Column(
        spacing: 16,
        children: [
          ElevatedButton(
            onPressed: () => _fakeAiWithEditor.startSimulatedTextEntry(),
            child: Text("Restart Simulation"),
          ),
          ElevatedButton(
            onPressed: () => _fakeAiWithEditor.stopSimulatedTextEntry(),
            child: Text("Pause Simulation"),
          ),
        ],
      ),
    );
  }
}

class _FakeAiWithEditor {
  _FakeAiWithEditor(this._editor) {
    _preCannedDocument = _createFakeAiDocument();
  }

  void dispose() {
    _contentEntryTimer?.cancel();

    _isSimulatingTextEntry = false;
    _simulatedEntryTextIndex = 0;
    _nextTextEntrySnippet = null;
    _contentEntryTimer = null;
  }

  final Editor _editor;
  late final MutableDocument _preCannedDocument;

  bool _isRunningFadeIn = false;

  String? _fadingNodeId;

  AttributedText? _textToInsert;
  bool _isSimulatingTextEntry = false;
  int _simulatedEntryTextIndex = 0;
  AttributedText? _nextTextEntrySnippet;

  Timer? _contentEntryTimer;

  void startSimulatedTextEntry() {
    stopSimulatedTextEntry();
    _editor.execute([
      ClearDocumentRequest(),
    ]);

    _isRunningFadeIn = true;
    _doInsertContent();
    _contentEntryTimer = Timer(_randomAiTextInsertionInterval, _doInsertContent);
  }

  void _doInsertContent() {
    if (!_isRunningFadeIn) {
      return;
    }

    if (_fadingNodeId == null) {
      // This is the start of the content insertion process.
      final firstNode = _preCannedDocument.first;
      _fadingNodeId = firstNode.id;

      _editor.execute([
        DeleteNodeRequest(nodeId: _editor.document.first.id),
      ]);
    } else if (!_isSimulatingTextEntry) {
      _selectNextNode();
      if (_fadingNodeId == null) {
        // We're done running the document fade-in.
        _isRunningFadeIn = false;
        return;
      }
    }

    bool isInsertingText = false;
    if (_isSimulatingTextEntry) {
      // We're in the process of inserting text.
      _selectNextTextSnippet();
      _doInsertText();

      isInsertingText = true;
    } else {
      final nextNode = _preCannedDocument.getNodeById(_fadingNodeId!)!;
      if (nextNode is TextNode) {
        // Start a new text node.
        _editor.execute([
          InsertNodeAtEndOfDocumentRequest(
            nextNode.copyTextNodeWith(
              text: AttributedText(),
            ),
          ),
        ]);

        if (nextNode.text.isNotEmpty) {
          _isSimulatingTextEntry = true;
          _textToInsert = nextNode.text;
          _simulatedEntryTextIndex = 0;
        }

        isInsertingText = true;
      } else {
        // Insert the next non-text node.
        _editor.execute([
          InsertNodeAtEndOfDocumentRequest(
            nextNode.copyWithAddedMetadata({
              NodeMetadata.createdAt: DateTime.now(),
            }),
          ),
        ]);
      }
    }

    if (_fadingNodeId != null) {
      _contentEntryTimer = Timer(
        isInsertingText ? _randomAiTextInsertionInterval : _randomAiNodeInsertionInterval,
        _doInsertContent,
      );
    }
  }

  void _selectNextNode() {
    final previousNodeId = _fadingNodeId;
    final nextNode = previousNodeId != null //
        ? _preCannedDocument.getNodeAfterById(previousNodeId)
        : _preCannedDocument.first;
    _fadingNodeId = nextNode?.id;
    if (nextNode == null) {
      return;
    }
  }

  void _selectNextTextSnippet() {
    const minLength = 3;
    const maxLength = 30;

    final remaining = _textToInsert!.length - _simulatedEntryTextIndex;
    if (remaining <= 0) {
      // There's no text left. Fizzle.
      _nextTextEntrySnippet = null;
      return;
    }
    if (remaining <= minLength) {
      // There's not enough text left to satisfy the minimum per-entry amount.
      // Add whatever characters remain in the text.
      _nextTextEntrySnippet = _textToInsert!.copyText(_simulatedEntryTextIndex);
      _simulatedEntryTextIndex = _textToInsert!.length;
      return;
    }

    // Pick a random amount of the remaining characters, based on a minimum and
    // maximum number of characters that we want to insert per cycle.
    final randomMax = min(maxLength, remaining) - minLength;
    final length = Random().nextInt(randomMax) + minLength;
    final endIndex = _simulatedEntryTextIndex + length;

    _nextTextEntrySnippet = _textToInsert!.copyText(_simulatedEntryTextIndex, endIndex);
    _simulatedEntryTextIndex = endIndex;
  }

  void _doInsertText() {
    _editor.execute([
      InsertStyledTextAtEndOfDocumentRequest(
        _nextTextEntrySnippet!,
        createdAt: DateTime.now(),
      ),
    ]);

    if (_simulatedEntryTextIndex >= _textToInsert!.length) {
      _isSimulatingTextEntry = false;
      _textToInsert = null;
      _simulatedEntryTextIndex = 0;
      _nextTextEntrySnippet = null;
    }
  }

  void stopSimulatedTextEntry() {
    if (!_isRunningFadeIn) {
      return;
    }

    _isRunningFadeIn = false;
    _fadingNodeId = null;
    _isSimulatingTextEntry = false;
    _textToInsert = null;
    _contentEntryTimer?.cancel();
    _contentEntryTimer = null;
  }

  Duration get _randomAiNodeInsertionInterval => Duration(milliseconds: Random().nextInt(600) + 400);

  Duration get _randomAiTextInsertionInterval => Duration(milliseconds: Random().nextInt(400) + 100);
}

MutableDocument _createFakeAiDocument() => deserializeMarkdownToDocument(_markdownDocument);

const _markdownDocument = '''
# AI-Style Fade-In
It's common for chat GPT AI systems to fade in text and content as its generated by the AI model. Super Editor supports this.

We recommend using a SuperReader widget for LLM content, so that the user can't edit that content while it's generated.

--- 
To fade-in content...

1. First step is to register a FadeInStyler with SuperReader.
2. Second, when inserting content, include a CreatedAtAttribution with the DateTime.now(). 
---

[Learn more in the docs](https://supereditor.dev/guides/ai/fad-in-content)

''';
