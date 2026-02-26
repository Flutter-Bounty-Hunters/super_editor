import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/src/foundation/basic_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:super_editor_clipboard/super_editor_clipboard.dart';
import 'package:super_native_extensions/raw_clipboard.dart' show DataReaderItem;

void main() {
  group("Max > Super Editor > copy and paste >", () {
    group("HTML >", () {
      test("pastes plain text in empty paragraph", () {
        const html = "<meta charset='utf-8'><p>Hello, World!</p>";
        final editor = createDefaultDocumentEditor(
          document: MutableDocument(
            nodes: [ParagraphNode(id: "1", text: AttributedText())],
          ),
        );

        // Place the caret so we know where to paste.
        editor.execute([
          ChangeSelectionRequest(
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 0),
              ),
            ),
            SelectionChangeType.placeCaret,
            SelectionReason.userInteraction,
          ),
        ]);

        // Paste the HTML.
        editor.pasteHtml(editor, html);

        // Ensure the HTML was turned into the expected document, with the
        // expected selection.
        expect(
          editor.document,
          documentEquivalentTo(
            MutableDocument(
              nodes: [
                ParagraphNode(id: "1", text: AttributedText("Hello, World!")),
              ],
            ),
          ),
        );
        expect(
          editor.composer.selection,
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 13),
            ),
          ),
        );
      });

      test("pastes plain text in middle of paragraph", () {
        const html = "<meta charset='utf-8'><p>Hello, World!</p>";
        final editor = createDefaultDocumentEditor(
          document: MutableDocument(
            nodes: [ParagraphNode(id: "1", text: AttributedText("abcdefgh"))],
          ),
        );

        // Place the caret so we know where to paste.
        editor.execute([
          ChangeSelectionRequest(
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 4),
              ),
            ),
            SelectionChangeType.placeCaret,
            SelectionReason.userInteraction,
          ),
        ]);

        // Paste the HTML.
        editor.pasteHtml(editor, html);

        // Ensure the HTML was turned into the expected document, with the
        // expected selection.
        expect(
          editor.document,
          documentEquivalentTo(
            MutableDocument(
              nodes: [
                ParagraphNode(
                  id: "1",
                  text: AttributedText("abcdHello, World!efgh"),
                ),
              ],
            ),
          ),
        );
        expect(
          editor.composer.selection,
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 17),
            ),
          ),
        );
      });

      test("ignores style tags", () {
        const html = "<meta charset='utf-8'><style>.p { color: BLACK; }</style><p>Hello, World!</p>";
        final editor = createDefaultDocumentEditor(
          document: MutableDocument(
            nodes: [ParagraphNode(id: "1", text: AttributedText())],
          ),
        );

        // Place the caret so we know where to paste.
        editor.execute([
          ChangeSelectionRequest(
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 0),
              ),
            ),
            SelectionChangeType.placeCaret,
            SelectionReason.userInteraction,
          ),
        ]);

        // Paste the HTML.
        editor.pasteHtml(editor, html);

        // Ensure the HTML was turned into the expected document, with the
        // expected selection.
        expect(
          editor.document,
          documentEquivalentTo(
            MutableDocument(
              nodes: [
                ParagraphNode(id: "1", text: AttributedText("Hello, World!")),
              ],
            ),
          ),
        );
        expect(
          editor.composer.selection,
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 13),
            ),
          ),
        );
      });

      test("pastes multiple paragraphs in empty paragraph", () {
        const html = "<meta charset='utf-8'><p>One</p><p>Two</p><p>Three</p>";
        final editor = createDefaultDocumentEditor(
          document: MutableDocument(
            nodes: [ParagraphNode(id: "1", text: AttributedText())],
          ),
        );

        // Place the caret so we know where to paste.
        editor.execute([
          ChangeSelectionRequest(
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 0),
              ),
            ),
            SelectionChangeType.placeCaret,
            SelectionReason.userInteraction,
          ),
        ]);

        // Paste the HTML.
        editor.pasteHtml(editor, html);

        // Ensure the HTML was turned into the expected document, with the
        // expected selection.
        expect(editor.document.length, 3);
        expect(
          editor.document,
          documentEquivalentTo(
            MutableDocument(
              nodes: [
                ParagraphNode(id: "1", text: AttributedText("One")),
                ParagraphNode(
                  id: editor.document.getNodeAt(1)!.id,
                  text: AttributedText("Two"),
                  metadata: {'textAlign': null},
                ),
                ParagraphNode(
                  id: editor.document.getNodeAt(2)!.id,
                  text: AttributedText("Three"),
                  metadata: {'textAlign': null},
                ),
              ],
            ),
          ),
        );
        expect(
          editor.composer.selection,
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: editor.document.getNodeAt(2)!.id,
              nodePosition: TextNodePosition(offset: 5),
            ),
          ),
        );
      });

      test("pastes multiple paragraphs in middle of paragraph", () {
        const html = "<meta charset='utf-8'><p>One</p><p>Two</p><p>Three</p>";
        final editor = createDefaultDocumentEditor(
          document: MutableDocument(
            nodes: [ParagraphNode(id: "1", text: AttributedText("abcdefgh"))],
          ),
        );

        // Place the caret so we know where to paste.
        editor.execute([
          ChangeSelectionRequest(
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 4),
              ),
            ),
            SelectionChangeType.placeCaret,
            SelectionReason.userInteraction,
          ),
        ]);

        // Paste the HTML.
        editor.pasteHtml(editor, html);

        // Ensure the HTML was turned into the expected document, with the
        // expected selection.
        expect(editor.document.length, 3);
        expect(
          editor.document,
          documentEquivalentTo(
            MutableDocument(
              nodes: [
                ParagraphNode(id: "1", text: AttributedText("abcdOne")),
                ParagraphNode(
                  id: editor.document.getNodeAt(1)!.id,
                  text: AttributedText("Two"),
                  metadata: {'textAlign': null},
                ),
                ParagraphNode(
                  id: editor.document.getNodeAt(2)!.id,
                  text: AttributedText("Threeefgh"),
                ),
              ],
            ),
          ),
        );
        expect(
          editor.composer.selection,
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: editor.document.getNodeAt(2)!.id,
              nodePosition: TextNodePosition(offset: 5),
            ),
          ),
        );
      });

      test("pastes table in empty paragraph", () {
        final editor = createDefaultDocumentEditor(
          document: MutableDocument(
            nodes: [ParagraphNode(id: "1", text: AttributedText())],
          ),
        );

        // Place the caret so we know where to paste.
        editor.execute([
          ChangeSelectionRequest(
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 0),
              ),
            ),
            SelectionChangeType.placeCaret,
            SelectionReason.userInteraction,
          ),
        ]);

        // Paste the HTML.
        editor.pasteHtml(editor, '<meta charset=\'utf-8\'>$_tableHtml');

        // Ensure the HTML was turned into the expected document, with the
        // expected selection.
        expect(
          editor.document,
          documentEquivalentTo(
            MutableDocument(
              nodes: [
                TableBlockNode(
                  id: editor.document.first.id,
                  cells: _tableCells,
                ),
                ParagraphNode(
                  id: editor.document.last.id,
                  text: AttributedText(),
                ),
              ],
            ),
          ),
        );
        expect(
          editor.composer.selection,
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: editor.document.last.id,
              nodePosition: TextNodePosition(offset: 0),
            ),
          ),
        );
      });

      test("pastes table in middle of paragraph", () {
        final editor = createDefaultDocumentEditor(
          document: MutableDocument(
            nodes: [ParagraphNode(id: "1", text: AttributedText("abcdefgh"))],
          ),
        );

        // Place the caret so we know where to paste.
        editor.execute([
          ChangeSelectionRequest(
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 4),
              ),
            ),
            SelectionChangeType.placeCaret,
            SelectionReason.userInteraction,
          ),
        ]);

        // Paste the HTML.
        editor.pasteHtml(editor, '<meta charset=\'utf-8\'>$_tableHtml');

        // Ensure the HTML was turned into the expected document, with the
        // expected selection.
        expect(
          editor.document,
          documentEquivalentTo(
            MutableDocument(
              nodes: [
                ParagraphNode(id: "1", text: AttributedText("abcd")),
                TableBlockNode(
                  id: editor.document.getNodeAt(1)!.id,
                  cells: _tableCells,
                ),
                ParagraphNode(
                  id: editor.document.last.id,
                  text: AttributedText("efgh"),
                ),
              ],
            ),
          ),
        );
        expect(
          editor.composer.selection,
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: editor.document.last.id,
              nodePosition: TextNodePosition(offset: 0),
            ),
          ),
        );
      });

      test("pastes mixed content in middle of paragraph", () {
        final editor = createDefaultDocumentEditor(
          document: MutableDocument(
            nodes: [ParagraphNode(id: "1", text: AttributedText("abcdefgh"))],
          ),
        );

        // Place the caret so we know where to paste.
        editor.execute([
          ChangeSelectionRequest(
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 4),
              ),
            ),
            SelectionChangeType.placeCaret,
            SelectionReason.userInteraction,
          ),
        ]);

        // Paste the HTML.
        editor.pasteHtml(editor, _mixedContent);

        // Ensure the HTML was turned into the expected document, with the
        // expected selection.
        expect(
          editor.document,
          documentEquivalentTo(
            MutableDocument(
              nodes: [
                ParagraphNode(id: "1", text: AttributedText("abcdBefore")),
                TableBlockNode(
                  id: editor.document.getNodeAt(1)!.id,
                  cells: _tableCells,
                ),
                ParagraphNode(
                  id: editor.document.getNodeAt(2)!.id,
                  text: AttributedText("Afterefgh"),
                ),
              ],
            ),
          ),
        );
        expect(
          editor.composer.selection,
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: editor.document.last.id,
              nodePosition: TextNodePosition(offset: 5),
            ),
          ),
        );
      });
    });

    test("URLs", () async {
      // Note: Clipboards have a dedicated URL/URI data type. For example, opening
      // a webpage in mobile Safari and then using the browser's share feature
      // saves a URI to the clipboard - not plain text, and not an HTML link.
      final editor = createDefaultDocumentEditor(
        document: MutableDocument(
          nodes: [ParagraphNode(id: "1", text: AttributedText())],
        ),
      );

      // Place the caret so we know where to paste.
      editor.execute([
        ChangeSelectionRequest(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 0),
            ),
          ),
          SelectionChangeType.placeCaret,
          SelectionReason.userInteraction,
        ),
      ]);

      // Setup fake clipboard with a URL in plain text.
      final fakeClipboard = _FakeClipboard(_FakeClipboardReader({
        Formats.uri,
      }, [
        _FakeUrlTextReaderItem("https://google.com"),
      ]));

      await pasteIntoEditorFromNativeClipboard(editor, testClipboard: fakeClipboard);

      final urlAttribution = LinkAttribution("https://google.com");
      expect(
        editor.document,
        documentEquivalentTo(
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText(
                  "https://google.com",
                  AttributedSpans(
                    attributions: [
                      SpanMarker(attribution: urlAttribution, offset: 0, markerType: SpanMarkerType.start),
                      SpanMarker(attribution: urlAttribution, offset: 17, markerType: SpanMarkerType.end),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });

    group("plain text >", () {
      test("parses URLs", () async {
        final editor = createDefaultDocumentEditor(
          document: MutableDocument(
            nodes: [ParagraphNode(id: "1", text: AttributedText())],
          ),
        );

        // Place the caret so we know where to paste.
        editor.execute([
          ChangeSelectionRequest(
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 0),
              ),
            ),
            SelectionChangeType.placeCaret,
            SelectionReason.userInteraction,
          ),
        ]);

        // Setup fake clipboard with a URL in plain text.
        final fakeClipboard = _FakeClipboard(_FakeClipboardReader({
          Formats.plainText,
        }, [
          _FakePlainTextReaderItem("Hello, https://google.com world"),
        ]));

        await pasteIntoEditorFromNativeClipboard(editor, testClipboard: fakeClipboard);

        final urlAttribution = LinkAttribution("https://google.com");
        expect(
          editor.document,
          documentEquivalentTo(
            MutableDocument(
              nodes: [
                ParagraphNode(
                  id: "1",
                  text: AttributedText(
                    "Hello, https://google.com world",
                    AttributedSpans(
                      attributions: [
                        SpanMarker(attribution: urlAttribution, offset: 7, markerType: SpanMarkerType.start),
                        SpanMarker(attribution: urlAttribution, offset: 24, markerType: SpanMarkerType.end),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      });
    });
  });
}

const _mixedContent = '<meta charset=\'utf-8\'>'
    '<p>Before<p>$_tableHtml<p>After</p>';

const _tableHtml = '<table><thead><tr>'
    '<th style="text-align:center">BMI Category</th>'
    '<th style="text-align:center">BMI Range (kg/m²)</th>'
    '</tr></thead>'
    '<tbody>'
    '<tr><td>Underweight</td><td>< 18.5</td></tr>'
    '<tr><td>Normal weight</td><td>18.5 - 24.9</td></tr>'
    '<tr><td>Overweight</td><td>25.0 - 29.9</td></tr>'
    '<tr><td>Obesity (Class I)</td><td>30.0 - 34.9</td></tr>'
    '<tr><td>Obesity (Class II)</td><td>35.0 - 39.9</td></tr>'
    '<tr><td>Obesity (Class III)</td><td>≥ 40.0</td></tr>'
    '</tbody></table>';

final _tableCells = [
  [
    TextNode(
      id: "1.1",
      text: AttributedText("BMI Category"),
      metadata: const {
        NodeMetadata.blockType: tableHeaderAttribution,
        'textAlign': TextAlign.center,
      },
    ),
    TextNode(
      id: "1.2",
      text: AttributedText("BMI Range (kg/m²)"),
      metadata: const {
        NodeMetadata.blockType: tableHeaderAttribution,
        'textAlign': TextAlign.center,
      },
    ),
  ],
  [
    TextNode(
      id: "2.1",
      text: AttributedText("Underweight"),
    ),
    TextNode(
      id: "2.2",
      text: AttributedText("< 18.5"),
    ),
  ],
  [
    TextNode(
      id: "3.1",
      text: AttributedText("Normal weight"),
    ),
    TextNode(
      id: "3.2",
      text: AttributedText("18.5 - 24.9"),
    ),
  ],
  [
    TextNode(
      id: "4.1",
      text: AttributedText("Overweight"),
    ),
    TextNode(
      id: "4.2",
      text: AttributedText("25.0 - 29.9"),
    ),
  ],
  [
    TextNode(
      id: "5.1",
      text: AttributedText("Obesity (Class I)"),
    ),
    TextNode(
      id: "5.2",
      text: AttributedText("30.0 - 34.9"),
    ),
  ],
  [
    TextNode(
      id: "6.1",
      text: AttributedText("Obesity (Class II)"),
    ),
    TextNode(
      id: "6.2",
      text: AttributedText("35.0 - 39.9"),
    ),
  ],
  [
    TextNode(
      id: "7.1",
      text: AttributedText("Obesity (Class III)"),
    ),
    TextNode(
      id: "7.2",
      text: AttributedText("≥ 40.0"),
    ),
  ],
];

class _FakeClipboard implements SystemClipboard {
  _FakeClipboard(this._reader);

  final ClipboardReader _reader;

  @override
  Future<ClipboardReader> read() async => _reader;

  @override
  Future<void> write(Iterable<DataWriterItem> items) {
    throw UnimplementedError();
  }
}

class _FakeClipboardReader implements ClipboardReader {
  _FakeClipboardReader(this._holdingFormats, this._items);

  final Set<DataFormat> _holdingFormats;

  final List<ClipboardDataReader> _items;

  @override
  bool canProvide(DataFormat<Object> format) {
    return _holdingFormats.contains(format);
  }

  @override
  bool hasValue(DataFormat<Object> format) {
    // TODO: implement hasValue
    throw UnimplementedError();
  }

  @override
  List<DataFormat<Object>> getFormats(List<DataFormat<Object>> allFormats) {
    // TODO: implement getFormats
    throw UnimplementedError();
  }

  @override
  List<ClipboardDataReader> get items => List.from(_items);

  @override
  List<PlatformFormat> get platformFormats => throw UnimplementedError();

  @override
  DataReaderItem? get rawReader => throw UnimplementedError();

  @override
  Future<T?> readValue<T extends Object>(ValueFormat<T> format) {
    throw UnimplementedError();
  }

  @override
  Future<String?> getSuggestedName() {
    // TODO: implement getSuggestedName
    throw UnimplementedError();
  }

  @override
  ReadProgress? getFile(
    FileFormat? format,
    AsyncValueChanged<DataReaderFile> onFile, {
    ValueChanged<Object>? onError,
    bool allowVirtualFiles = true,
    bool synthesizeFilesFromURIs = true,
  }) {
    throw UnimplementedError();
  }

  @override
  ReadProgress? getValue<T extends Object>(ValueFormat<T> format, AsyncValueChanged<T?> onValue,
      {ValueChanged<Object>? onError}) {
    throw UnimplementedError();
  }

  @override
  Future<VirtualFileReceiver?> getVirtualFileReceiver({FileFormat? format}) {
    throw UnimplementedError();
  }

  @override
  bool isSynthesized(DataFormat<Object> format) {
    throw UnimplementedError();
  }

  @override
  bool isVirtual(DataFormat<Object> format) {
    throw UnimplementedError();
  }
}

class _FakeUrlTextReaderItem implements ClipboardDataReader {
  _FakeUrlTextReaderItem(this._uri);

  final String _uri;

  @override
  bool canProvide(DataFormat<Object> format) {
    return format == Formats.uri;
  }

  @override
  List<DataFormat<Object>> getFormats(List<DataFormat<Object>> allFormats) {
    return [Formats.uri];
  }

  @override
  Future<T?> readValue<T extends Object>(ValueFormat<T> format) async {
    return format.codec.decode(_SimpleProvider(_uri), "text/uri-list");
  }

  @override
  ReadProgress? getFile(FileFormat? format, AsyncValueChanged<DataReaderFile> onFile,
      {ValueChanged<Object>? onError, bool allowVirtualFiles = true, bool synthesizeFilesFromURIs = true}) {
    // TODO: implement getFile
    throw UnimplementedError();
  }

  @override
  Future<String?> getSuggestedName() {
    // TODO: implement getSuggestedName
    throw UnimplementedError();
  }

  @override
  ReadProgress? getValue<T extends Object>(ValueFormat<T> format, AsyncValueChanged<T?> onValue,
      {ValueChanged<Object>? onError}) {
    // TODO: implement getValue
    throw UnimplementedError();
  }

  @override
  Future<VirtualFileReceiver?> getVirtualFileReceiver({FileFormat? format}) {
    // TODO: implement getVirtualFileReceiver
    throw UnimplementedError();
  }

  @override
  bool hasValue(DataFormat<Object> format) {
    return format == Formats.plainText;
  }

  @override
  bool isSynthesized(DataFormat<Object> format) {
    return false;
  }

  @override
  bool isVirtual(DataFormat<Object> format) {
    return false;
  }

  @override
  // TODO: implement platformFormats
  List<PlatformFormat> get platformFormats => throw UnimplementedError();

  @override
  // TODO: implement rawReader
  DataReaderItem? get rawReader => throw UnimplementedError();
}

class _FakePlainTextReaderItem implements ClipboardDataReader {
  _FakePlainTextReaderItem(this._plainText);

  final String _plainText;

  @override
  bool canProvide(DataFormat<Object> format) {
    return format == Formats.plainText;
  }

  @override
  List<DataFormat<Object>> getFormats(List<DataFormat<Object>> allFormats) {
    return [Formats.plainText];
  }

  @override
  Future<T?> readValue<T extends Object>(ValueFormat<T> format) async {
    return format.codec.decode(_SimpleProvider(_plainText), "public.utf8-plain-text");
  }

  @override
  ReadProgress? getFile(FileFormat? format, AsyncValueChanged<DataReaderFile> onFile,
      {ValueChanged<Object>? onError, bool allowVirtualFiles = true, bool synthesizeFilesFromURIs = true}) {
    // TODO: implement getFile
    throw UnimplementedError();
  }

  @override
  Future<String?> getSuggestedName() {
    // TODO: implement getSuggestedName
    throw UnimplementedError();
  }

  @override
  ReadProgress? getValue<T extends Object>(ValueFormat<T> format, AsyncValueChanged<T?> onValue,
      {ValueChanged<Object>? onError}) {
    // TODO: implement getValue
    throw UnimplementedError();
  }

  @override
  Future<VirtualFileReceiver?> getVirtualFileReceiver({FileFormat? format}) {
    // TODO: implement getVirtualFileReceiver
    throw UnimplementedError();
  }

  @override
  bool hasValue(DataFormat<Object> format) {
    return format == Formats.plainText;
  }

  @override
  bool isSynthesized(DataFormat<Object> format) {
    return false;
  }

  @override
  bool isVirtual(DataFormat<Object> format) {
    return false;
  }

  @override
  // TODO: implement platformFormats
  List<PlatformFormat> get platformFormats => throw UnimplementedError();

  @override
  // TODO: implement rawReader
  DataReaderItem? get rawReader => throw UnimplementedError();
}

class _SimpleProvider extends PlatformDataProvider {
  final Object data;

  _SimpleProvider(this.data);

  @override
  List<PlatformFormat> getAllFormats() => [];

  @override
  Future<Object?> getData(PlatformFormat format) async => data;
}
