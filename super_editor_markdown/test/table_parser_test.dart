import 'dart:math';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_markdown/super_editor_markdown.dart';
import 'package:text_table/text_table.dart';

void main() {
  group('Markdown > deserialization > tables >', () {
    test('table with single column', () {
      expect(
        _parseMarkdownTable('''| header 1 |
|---|
| data 1 |'''),
        _matchesTableContent(TableBlockNode(
          id: '1',
          cells: [
            [
              TextNode(
                id: '1-1',
                text: AttributedText('header 1'),
                metadata: const {
                  NodeMetadata.blockType: tableHeaderAttribution,
                  TextNodeMetadata.textAlign: TextAlign.center,
                },
              )
            ],
            [TextNode(id: '1-2', text: AttributedText('data 1'))],
          ],
        )),
      );
    });

    test('table with two columns', () {
      expect(
        _parseMarkdownTable(
          '''| header 1 | header 2 |
|---|---|
| data 1 | data 2 |''',
        ),
        _matchesTableContent(TableBlockNode(
          id: '1',
          cells: [
            [
              TextNode(
                id: '1-1',
                text: AttributedText('header 1'),
                metadata: const {
                  NodeMetadata.blockType: tableHeaderAttribution,
                  TextNodeMetadata.textAlign: TextAlign.center,
                },
              ),
              TextNode(
                id: '1-2',
                text: AttributedText('header 2'),
                metadata: const {
                  NodeMetadata.blockType: tableHeaderAttribution,
                  TextNodeMetadata.textAlign: TextAlign.center,
                },
              ),
            ],
            [
              TextNode(id: '2-1', text: AttributedText('data 1')),
              TextNode(id: '2-2', text: AttributedText('data 2')),
            ],
          ],
        )),
      );
    });

    test('table with multiple rows', () {
      expect(
        _parseMarkdownTable(
          '''| header 1 | header 2 |
|---|---|
| data 1 | data 2 |
| data 3 | data 4 |
| data 5 | data 6 |''',
        ),
        _matchesTableContent(TableBlockNode(
          id: '1',
          cells: [
            [
              TextNode(
                id: '1-1',
                text: AttributedText('header 1'),
                metadata: const {
                  NodeMetadata.blockType: tableHeaderAttribution,
                  TextNodeMetadata.textAlign: TextAlign.center,
                },
              ),
              TextNode(
                id: '1-2',
                text: AttributedText('header 2'),
                metadata: const {
                  NodeMetadata.blockType: tableHeaderAttribution,
                  TextNodeMetadata.textAlign: TextAlign.center,
                },
              )
            ],
            [
              TextNode(id: '2-1', text: AttributedText('data 1')),
              TextNode(id: '2-2', text: AttributedText('data 2')),
            ],
            [
              TextNode(id: '3-1', text: AttributedText('data 3')),
              TextNode(id: '3-2', text: AttributedText('data 4')),
            ],
            [
              TextNode(id: '4-1', text: AttributedText('data 5')),
              TextNode(id: '4-2', text: AttributedText('data 6')),
            ],
          ],
        )),
      );
    });

    test('table with alignment', () {
      expect(
        _parseMarkdownTable(
          '''| header 1 | header 2 | header 3 |
|:---|:---:|---:|
| data 1 | data 2 | data 3 |''',
        ),
        _matchesTableContent(TableBlockNode(
          id: '1',
          cells: [
            [
              TextNode(
                id: '1-1',
                text: AttributedText('header 1'),
                metadata: const {
                  NodeMetadata.blockType: tableHeaderAttribution,
                  TextNodeMetadata.textAlign: TextAlign.center,
                },
              ),
              TextNode(
                id: '1-2',
                text: AttributedText('header 2'),
                metadata: const {
                  NodeMetadata.blockType: tableHeaderAttribution,
                  TextNodeMetadata.textAlign: TextAlign.center,
                },
              ),
              TextNode(
                id: '1-3',
                text: AttributedText('header 3'),
                metadata: const {
                  NodeMetadata.blockType: tableHeaderAttribution,
                  TextNodeMetadata.textAlign: TextAlign.center,
                },
              ),
            ],
            [
              TextNode(id: '2-1', text: AttributedText('data 1')),
              TextNode(
                id: '2-2',
                text: AttributedText('data 2'),
                metadata: const {
                  TextNodeMetadata.textAlign: TextAlign.center,
                },
              ),
              TextNode(
                id: '2-3',
                text: AttributedText('data 3'),
                metadata: const {
                  TextNodeMetadata.textAlign: TextAlign.right,
                },
              ),
            ],
          ],
        )),
      );
    });

    test('table with inline markdown', () {
      expect(
        _parseMarkdownTable(
          '''| **header 1** |
|---|
| [link](https://example.org) |''',
        ),
        _matchesTableContent(TableBlockNode(
          id: '1',
          cells: [
            [
              TextNode(
                id: '1-1',
                text: AttributedText(
                  'header 1',
                  AttributedSpans(
                    attributions: [
                      const SpanMarker(
                        attribution: boldAttribution,
                        offset: 0,
                        markerType: SpanMarkerType.start,
                      ),
                      const SpanMarker(
                        attribution: boldAttribution,
                        offset: 7,
                        markerType: SpanMarkerType.end,
                      ),
                    ],
                  ),
                ),
                metadata: const {
                  NodeMetadata.blockType: tableHeaderAttribution,
                  TextNodeMetadata.textAlign: TextAlign.center,
                },
              )
            ],
            [
              TextNode(
                id: '2-1',
                text: AttributedText(
                  'link',
                  AttributedSpans(
                    attributions: [
                      const SpanMarker(
                          attribution: LinkAttribution('https://example.org'),
                          offset: 0,
                          markerType: SpanMarkerType.start),
                      const SpanMarker(
                          attribution: LinkAttribution('https://example.org'),
                          offset: 3,
                          markerType: SpanMarkerType.end),
                    ],
                  ),
                ),
              )
            ]
          ],
        )),
      );
    });

    test('table without body', () {
      expect(
        _parseMarkdownTable(
          '''| header 1 | header 2 |
|---|---|''',
        ),
        _matchesTableContent(TableBlockNode(
          id: '1',
          cells: [
            [
              TextNode(
                id: '1-1',
                text: AttributedText('header 1'),
                metadata: const {
                  NodeMetadata.blockType: tableHeaderAttribution,
                  TextNodeMetadata.textAlign: TextAlign.center,
                },
              ),
              TextNode(
                id: '1-2',
                text: AttributedText('header 2'),
                metadata: const {
                  NodeMetadata.blockType: tableHeaderAttribution,
                  TextNodeMetadata.textAlign: TextAlign.center,
                },
              ),
            ],
          ],
        )),
      );
    });

    test('table with text containing pipe', () {
      expect(
        _parseMarkdownTable(
          '''| header\\|1 |
|---|
| data\\|1 |''',
        ),
        _matchesTableContent(TableBlockNode(
          id: '1',
          cells: [
            [
              TextNode(
                id: '1-1',
                text: AttributedText('header|1'),
                metadata: const {
                  NodeMetadata.blockType: tableHeaderAttribution,
                  TextNodeMetadata.textAlign: TextAlign.center,
                },
              ),
            ],
            [
              TextNode(id: '2-1', text: AttributedText('data|1')),
            ],
          ],
        )),
      );
    });

    test('table with inline markdown containing pipe', () {
      expect(
        _parseMarkdownTable(
          '''| header **\\|1** |
|---|
| data 1 |''',
        ),
        _matchesTableContent(TableBlockNode(
          id: '1',
          cells: [
            [
              TextNode(
                id: '1-1',
                text: AttributedText(
                  'header |1',
                  AttributedSpans(
                    attributions: [
                      const SpanMarker(
                        attribution: boldAttribution,
                        offset: 7,
                        markerType: SpanMarkerType.start,
                      ),
                      const SpanMarker(
                        attribution: boldAttribution,
                        offset: 8,
                        markerType: SpanMarkerType.end,
                      ),
                    ],
                  ),
                ),
                metadata: const {
                  NodeMetadata.blockType: tableHeaderAttribution,
                  TextNodeMetadata.textAlign: TextAlign.center,
                },
              ),
            ],
            [TextNode(id: '2-1', text: AttributedText('data 1'))],
          ],
        )),
      );
    });

    test('table with delimiter with more than three hyphens', () {
      expect(
        _parseMarkdownTable(
          '''| header 1 | header 2 |
|---|----------|
| data 1 | data 2 |''',
        ),
        _matchesTableContent(TableBlockNode(
          id: '1',
          cells: [
            [
              TextNode(
                id: '1-1',
                text: AttributedText('header 1'),
                metadata: const {
                  NodeMetadata.blockType: tableHeaderAttribution,
                  TextNodeMetadata.textAlign: TextAlign.center,
                },
              ),
              TextNode(
                id: '1-2',
                text: AttributedText('header 2'),
                metadata: const {
                  NodeMetadata.blockType: tableHeaderAttribution,
                  TextNodeMetadata.textAlign: TextAlign.center,
                },
              ),
            ],
            [
              TextNode(id: '2-1', text: AttributedText('data 1')),
              TextNode(id: '2-2', text: AttributedText('data 2')),
            ],
          ],
        )),
      );
    });

    test('table without leading pipe', () {
      expect(
        _parseMarkdownTable(
          '''header 1 | header 2 |
---|---|
 data 1 | data 2 |''',
        ),
        _matchesTableContent(TableBlockNode(
          id: '1',
          cells: [
            [
              TextNode(
                id: '1-1',
                text: AttributedText('header 1'),
                metadata: const {
                  NodeMetadata.blockType: tableHeaderAttribution,
                  TextNodeMetadata.textAlign: TextAlign.center,
                },
              ),
              TextNode(
                id: '1-2',
                text: AttributedText('header 2'),
                metadata: const {
                  NodeMetadata.blockType: tableHeaderAttribution,
                  TextNodeMetadata.textAlign: TextAlign.center,
                },
              ),
            ],
            [
              TextNode(id: '2-1', text: AttributedText('data 1')),
              TextNode(id: '2-2', text: AttributedText('data 2')),
            ],
          ],
        )),
      );
    });

    test('table without trailing pipe', () {
      expect(
        _parseMarkdownTable(
          '''| header 1 | header 2 
|---|---
| data 1 | data 2 ''',
        ),
        _matchesTableContent(TableBlockNode(
          id: '1',
          cells: [
            [
              TextNode(
                id: '1-1',
                text: AttributedText('header 1'),
                metadata: const {
                  NodeMetadata.blockType: tableHeaderAttribution,
                  TextNodeMetadata.textAlign: TextAlign.center,
                },
              ),
              TextNode(
                id: '1-2',
                text: AttributedText('header 2'),
                metadata: const {
                  NodeMetadata.blockType: tableHeaderAttribution,
                  TextNodeMetadata.textAlign: TextAlign.center,
                },
              ),
            ],
            [
              TextNode(id: '2-1', text: AttributedText('data 1')),
              TextNode(id: '2-2', text: AttributedText('data 2')),
            ],
          ],
        )),
      );
    });

    test('table without leading and trailing pipe', () {
      expect(
        _parseMarkdownTable(
          '''header 1 | header 2 
---|---
data 1 | data 2 ''',
        ),
        _matchesTableContent(TableBlockNode(
          id: '1',
          cells: [
            [
              TextNode(
                id: '1-1',
                text: AttributedText('header 1'),
                metadata: const {
                  NodeMetadata.blockType: tableHeaderAttribution,
                  TextNodeMetadata.textAlign: TextAlign.center,
                },
              ),
              TextNode(
                id: '1-2',
                text: AttributedText('header 2'),
                metadata: const {
                  NodeMetadata.blockType: tableHeaderAttribution,
                  TextNodeMetadata.textAlign: TextAlign.center,
                },
              ),
            ],
            [
              TextNode(id: '2-1', text: AttributedText('data 1')),
              TextNode(id: '2-2', text: AttributedText('data 2')),
            ],
          ],
        )),
      );
    });

    test('table with row with missing column', () {
      expect(
        _parseMarkdownTable(
          '''| header 1 | header 2 |
|---|---|
| data 1''',
        ),
        _matchesTableContent(TableBlockNode(
          id: '1',
          cells: [
            [
              TextNode(
                id: '1-1',
                text: AttributedText('header 1'),
                metadata: const {
                  NodeMetadata.blockType: tableHeaderAttribution,
                  TextNodeMetadata.textAlign: TextAlign.center,
                },
              ),
              TextNode(
                id: '1-2',
                text: AttributedText('header 2'),
                metadata: const {
                  NodeMetadata.blockType: tableHeaderAttribution,
                  TextNodeMetadata.textAlign: TextAlign.center,
                },
              ),
            ],
            [
              TextNode(id: '2-1', text: AttributedText('data 1')),
              TextNode(id: '2-2', text: AttributedText('')),
            ],
          ],
        )),
      );
    });

    test('table with row with extra column', () {
      expect(
        _parseMarkdownTable(
          '''| header 1 | header 2 |
|---|---|
| data 1 | data 2 | extra data |''',
        ),
        _matchesTableContent(TableBlockNode(
          id: '1',
          cells: [
            [
              TextNode(
                id: '1-1',
                text: AttributedText('header 1'),
                metadata: const {
                  NodeMetadata.blockType: tableHeaderAttribution,
                  TextNodeMetadata.textAlign: TextAlign.center,
                },
              ),
              TextNode(
                id: '1-2',
                text: AttributedText('header 2'),
                metadata: const {
                  NodeMetadata.blockType: tableHeaderAttribution,
                  TextNodeMetadata.textAlign: TextAlign.center,
                },
              ),
            ],
            [
              TextNode(id: '2-1', text: AttributedText('data 1')),
              TextNode(id: '2-2', text: AttributedText('data 2')),
            ],
          ],
        )),
      );
    });

    test('table with tabs between columns', () {
      expect(
        _parseMarkdownTable(
          '''| header 1 	| header 2 	| header 3 	|
|---	|---	|---	|
| data 1 	| data 2 	| data 3 	|''',
        ),
        _matchesTableContent(TableBlockNode(
          id: '1',
          cells: [
            [
              TextNode(
                id: '1-1',
                text: AttributedText('header 1'),
                metadata: const {
                  NodeMetadata.blockType: tableHeaderAttribution,
                  TextNodeMetadata.textAlign: TextAlign.center,
                },
              ),
              TextNode(
                id: '1-2',
                text: AttributedText('header 2'),
                metadata: const {
                  NodeMetadata.blockType: tableHeaderAttribution,
                  TextNodeMetadata.textAlign: TextAlign.center,
                },
              ),
              TextNode(
                id: '1-3',
                text: AttributedText('header 3'),
                metadata: const {
                  NodeMetadata.blockType: tableHeaderAttribution,
                  TextNodeMetadata.textAlign: TextAlign.center,
                },
              ),
            ],
            [
              TextNode(id: '2-1', text: AttributedText('data 1')),
              TextNode(id: '2-2', text: AttributedText('data 2')),
              TextNode(id: '2-3', text: AttributedText('data 3')),
            ],
          ],
        )),
      );
    });

    test('table broken by block level element', () {
      expect(
        _parseMarkdownTable(
          '''| header 1 | header 2 |
|---|---|
| data 1 | data 2 |
> blockquote''',
        ),
        _matchesTableContent(TableBlockNode(
          id: '1',
          cells: [
            [
              TextNode(
                id: '1-1',
                text: AttributedText('header 1'),
                metadata: const {
                  NodeMetadata.blockType: tableHeaderAttribution,
                  TextNodeMetadata.textAlign: TextAlign.center,
                },
              ),
              TextNode(
                id: '1-2',
                text: AttributedText('header 2'),
                metadata: const {
                  NodeMetadata.blockType: tableHeaderAttribution,
                  TextNodeMetadata.textAlign: TextAlign.center,
                },
              ),
            ],
            [
              TextNode(id: '2-1', text: AttributedText('data 1')),
              TextNode(id: '2-2', text: AttributedText('data 2')),
            ],
          ],
        )),
      );
    });

    test('table broken by empty line', () {
      expect(
        _parseMarkdownTable(
          '''| header 1 | header 2 |
|---|---|
| data 1 | data 2 |
data 3

paragraph''',
        ),
        _matchesTableContent(TableBlockNode(
          id: '1',
          cells: [
            [
              TextNode(
                id: '1-1',
                text: AttributedText('header 1'),
                metadata: const {
                  NodeMetadata.blockType: tableHeaderAttribution,
                  TextNodeMetadata.textAlign: TextAlign.center,
                },
              ),
              TextNode(
                id: '1-2',
                text: AttributedText('header 2'),
                metadata: const {
                  NodeMetadata.blockType: tableHeaderAttribution,
                  TextNodeMetadata.textAlign: TextAlign.center,
                },
              ),
            ],
            [
              TextNode(id: '2-1', text: AttributedText('data 1')),
              TextNode(id: '2-2', text: AttributedText('data 2')),
            ],
            [
              TextNode(id: '3-1', text: AttributedText('data 3')),
              TextNode(id: '3-2', text: AttributedText('')),
            ]
          ],
        )),
      );
    });

    test('does not parse table with delimiter with mismatch cell count', () {
      final document = deserializeMarkdownToDocument('''| header 1 | header 2 |
|---|
| data 1 | data 2 |''');

      expect(document.nodeCount, 1);
      expect(document.first, isA<ParagraphNode>());
      expect(
        (document.first as ParagraphNode).text.toPlainText(includePlaceholders: false),
        '''| header 1 | header 2 |
|---|
| data 1 | data 2 |''',
      );
    });
  });
}

/// Parses the given [markdown] string and attempts to extract a table
/// from the first element.
///
/// All subsequent elements are ignored.
TableBlockNode _parseMarkdownTable(String markdown) {
  final document = deserializeMarkdownToDocument(markdown);

  expect(document.nodeCount, greaterThanOrEqualTo(1));
  expect(document.first, isA<TableBlockNode>());

  return document.first as TableBlockNode;
}

/// Checks whether a [TableBlockNode] has equivalent content to an expected [TableBlockNode].
///
/// We cannot use the default equality operator because it would compare
/// the node ids, which are generated randomly.
///
/// This matcher checks that the number of rows and columns are the same,
/// and that the text and metadata of each cell are the same.
_TableBlockNodeMatcher _matchesTableContent(
  TableBlockNode expected,
) {
  return _TableBlockNodeMatcher(expected);
}

class _TableBlockNodeMatcher extends Matcher {
  const _TableBlockNodeMatcher(this._expected);

  final TableBlockNode _expected;

  @override
  Description describe(Description description) {
    return description.add("given TableBlockNode has equivalent content to expected TableBlockNode");
  }

  @override
  bool matches(covariant Object target, Map<dynamic, dynamic> matchState) {
    return _calculateMismatchReason(target, matchState) == null;
  }

  @override
  Description describeMismatch(
    covariant Object target,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    final mismatchReason = _calculateMismatchReason(target, matchState);
    if (mismatchReason != null) {
      mismatchDescription.add(mismatchReason);
    }
    return mismatchDescription;
  }

  String? _calculateMismatchReason(
    Object target,
    Map<dynamic, dynamic> matchState,
  ) {
    if (target is! TableBlockNode) {
      return 'Expected a TableBlockNode, but got ${target.runtimeType}';
    }

    final messages = <String>[];
    bool rowCountMismatch = false;
    bool rowContentMismatch = false;

    if (_expected.rowCount != target.rowCount) {
      messages.add("expected ${_expected.rowCount} rows but found ${target.rowCount}");
      rowCountMismatch = true;
    } else {
      messages.add("table have the same number of rows");
    }

    final maxRowCount = max(_expected.rowCount, target.rowCount);
    final rowComparisons = List.generate(maxRowCount, (index) => ["", "", " "]);
    for (int i = 0; i < maxRowCount; i += 1) {
      if (i < _expected.rowCount && i < target.rowCount) {
        rowComparisons[i][0] = _tableRowToString(_expected.getRow(i));
        rowComparisons[i][1] = _tableRowToString(target.getRow(i));

        bool columnCountMismatch = _expected.getRow(i).length != target.getRow(i).length;
        if (columnCountMismatch) {
          rowComparisons[i][2] = "Column count mismatch";
          rowContentMismatch = true;
        } else {
          rowComparisons[i][2] = "Same number of columns";

          for (int j = 0; j < _expected.getRow(i).length; j++) {
            final expectedCell = _expected.getRow(i)[j];
            final targetCell = target.getRow(i)[j];

            if (expectedCell.text != targetCell.text) {
              rowComparisons[i][2] = "Content mismatch in row $i column $j";
              rowContentMismatch = true;

              // No need to check further columns in this row.
              continue;
            }

            final expectedMetadata = expectedCell.metadata;
            final targetMetadata = targetCell.metadata;

            if (expectedMetadata.length != targetMetadata.length) {
              rowComparisons[i][0] = expectedMetadata.entries.map((e) => '${e.key}: ${e.value}').join(', ');
              rowComparisons[i][1] = targetMetadata.entries.map((e) => '${e.key}: ${e.value}').join(', ');
              rowComparisons[i][2] = "Metadata length mismatch in row $i column $j";
              rowContentMismatch = true;
              continue;
            }

            for (final key in expectedMetadata.keys) {
              if (!targetMetadata.containsKey(key)) {
                rowComparisons[i][2] = "Metadata key '$key' missing in row $i column $j";
                rowContentMismatch = true;
                break;
              }
              if (expectedMetadata[key] != targetMetadata[key]) {
                rowComparisons[i][0] = expectedMetadata[key].toString();
                rowComparisons[i][1] = targetMetadata[key].toString();
                rowComparisons[i][2] = "Metadata value mismatch for key '$key' in row $i column $j";
                rowContentMismatch = true;
                break;
              }
            }
          }
        }
      } else if (i < _expected.rowCount) {
        rowComparisons[i][0] = _tableRowToString(_expected.getRow(i));
        rowComparisons[i][1] = "NA";
        rowComparisons[i][2] = "Missing Row";
      } else if (i < target.rowCount) {
        rowComparisons[i][0] = "NA";
        rowComparisons[i][1] = _tableRowToString(target.getRow(i));
        rowComparisons[i][2] = "Missing Row";
      }
    }

    if (rowCountMismatch || rowContentMismatch) {
      String messagesList = messages.join(", ");
      messagesList += "\n";
      messagesList += const TableRenderer().render(rowComparisons, columns: ["Expected", "Actual", "Difference"]);
      return messagesList;
    }

    return null;
  }

  String _tableRowToString(List<TextNode> row) {
    return '| ${row.map((e) => e.text.toPlainText(includePlaceholders: false)).join(" | ")} |';
  }
}
