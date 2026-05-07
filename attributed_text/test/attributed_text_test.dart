import 'package:attributed_text/attributed_text.dart';
import 'package:collection/collection.dart';
import 'package:test/test.dart';

void main() {
  group('Attributed Text', () {
    test('Bug 145 - insert character at beginning of styled text', () {
      final initialText = AttributedText(
        'abcdefghij',
        AttributedSpans(
          attributions: [
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 0, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 9, markerType: SpanMarkerType.end),
          ],
        ),
      );

      final newText = initialText.insertString(
        textToInsert: 'a',
        startOffset: 0,
        applyAttributions: {ExpectedSpans.bold},
      );

      expect(newText.toPlainText(), 'aabcdefghij');
      expect(
        newText.hasAttributionsWithin(attributions: {ExpectedSpans.bold}, range: const SpanRange(0, 10)),
        true,
      );
    });

    group('fragments', () {
      test('can be copied as attributed text with a SpanRange', () {
        final text = AttributedText(
          "this that other",
          AttributedSpans(
            attributions: [
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 0, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 6, markerType: SpanMarkerType.end),
              const SpanMarker(attribution: ExpectedSpans.italics, offset: 7, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.italics, offset: 14, markerType: SpanMarkerType.end),
            ],
          ),
        );

        final slice = text.copyTextInRange(const SpanRange(5, 9));
        expect(slice.toPlainText(), "that");
        expect(slice.length, 4);
        expect(slice.getAttributedRange({ExpectedSpans.bold}, 0), const SpanRange(0, 1));
        expect(slice.getAttributedRange({ExpectedSpans.italics}, 2), const SpanRange(2, 3));
      });

      test('can be copied as attributed text with start and end bounds', () {
        final text = AttributedText(
          "this that other",
          AttributedSpans(
            attributions: [
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 0, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 6, markerType: SpanMarkerType.end),
              const SpanMarker(attribution: ExpectedSpans.italics, offset: 7, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.italics, offset: 14, markerType: SpanMarkerType.end),
            ],
          ),
        );

        final slice = text.copyText(5, 9);
        expect(slice.toPlainText(), "that");
        expect(slice.length, 4);
        expect(slice.getAttributedRange({ExpectedSpans.bold}, 0), const SpanRange(0, 1));
        expect(slice.getAttributedRange({ExpectedSpans.italics}, 2), const SpanRange(2, 3));
      });

      test('can be copied as plain text with a SpanRange', () {
        final text = AttributedText(
          "this that other",
          AttributedSpans(
            attributions: [
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 0, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 6, markerType: SpanMarkerType.end),
              const SpanMarker(attribution: ExpectedSpans.italics, offset: 7, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.italics, offset: 14, markerType: SpanMarkerType.end),
            ],
          ),
        );

        final substring = text.substringInRange(const SpanRange(5, 9));
        expect(substring, "that");
      });

      test('can be copied as plain text with start and end bounds', () {
        final text = AttributedText(
          "this that other",
          AttributedSpans(
            attributions: [
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 0, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 6, markerType: SpanMarkerType.end),
              const SpanMarker(attribution: ExpectedSpans.italics, offset: 7, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.italics, offset: 14, markerType: SpanMarkerType.end),
            ],
          ),
        );

        final substring = text.substring(5, 9);
        expect(substring, "that");
      });
    });

    group('span manipulation', () {
      test('combines overlapping spans when adding from left to right', () {
        // Note: span overlaps at the boundary had a bug that was filed in #582.
        final text = AttributedText('01234567');
        text.addAttribution(ExpectedSpans.bold, const SpanRange(0, 4));
        text.addAttribution(ExpectedSpans.bold, const SpanRange(4, 8));

        // Ensure that the spans were merged into a single span.
        expect(text.spans.markers.length, 2);
        expect(
          text.spans.markers.first,
          const SpanMarker(attribution: ExpectedSpans.bold, offset: 0, markerType: SpanMarkerType.start),
        );
        expect(
          text.spans.markers.last,
          const SpanMarker(attribution: ExpectedSpans.bold, offset: 8, markerType: SpanMarkerType.end),
        );
      });

      test('combines overlapping spans when adding from left to right', () {
        final text = AttributedText('01234567');
        text.addAttribution(ExpectedSpans.bold, const SpanRange(4, 8));
        text.addAttribution(ExpectedSpans.bold, const SpanRange(0, 4));

        // Ensure that the spans were merged into a single span.
        expect(text.spans.markers.length, 2);
        expect(
          text.spans.markers.first,
          const SpanMarker(attribution: ExpectedSpans.bold, offset: 0, markerType: SpanMarkerType.start),
        );
        expect(
          text.spans.markers.last,
          const SpanMarker(attribution: ExpectedSpans.bold, offset: 8, markerType: SpanMarkerType.end),
        );
      });

      test('automatically combines back-to-back spans after addition', () {
        final text = AttributedText('ABCD');
        text.addAttribution(ExpectedSpans.bold, const SpanRange(0, 1));
        text.addAttribution(ExpectedSpans.bold, const SpanRange(2, 3));

        // Ensure that we only have a single span
        expect(text.spans.markers.length, 2);
        expect(
          text.spans.markers.first,
          const SpanMarker(attribution: ExpectedSpans.bold, offset: 0, markerType: SpanMarkerType.start),
        );
        expect(
          text.spans.markers.last,
          const SpanMarker(attribution: ExpectedSpans.bold, offset: 3, markerType: SpanMarkerType.end),
        );
      });

      test('keeps back-to-back spans separate when requested', () {
        final text = AttributedText('#john#sally');
        text.addAttribution(ExpectedSpans.hashTag, const SpanRange(0, 4));
        text.addAttribution(ExpectedSpans.hashTag, const SpanRange(5, 10), autoMerge: false);

        // Ensure that the hash tag spans were kept separate
        expect(text.spans.markers.length, 2 * 2);

        final markers = text.spans.markers.toList();

        // #john
        expect(
          markers[0],
          const SpanMarker(attribution: ExpectedSpans.hashTag, offset: 0, markerType: SpanMarkerType.start),
        );
        expect(
          markers[1],
          const SpanMarker(attribution: ExpectedSpans.hashTag, offset: 4, markerType: SpanMarkerType.end),
        );

        // #sally
        expect(
          markers[2],
          const SpanMarker(attribution: ExpectedSpans.hashTag, offset: 5, markerType: SpanMarkerType.start),
        );
        expect(
          markers[3],
          const SpanMarker(attribution: ExpectedSpans.hashTag, offset: 10, markerType: SpanMarkerType.end),
        );
      });

      test('throws exception when compatible attributions overlap but auto-merge is false', () {
        final text = AttributedText('#john#sally');
        text.addAttribution(ExpectedSpans.hashTag, const SpanRange(0, 4));

        expect(
          () => text.addAttribution(ExpectedSpans.hashTag, const SpanRange(0, 10), autoMerge: false),
          throwsA(isA<IncompatibleOverlappingAttributionsException>()),
        );
      });
    });

    test('notifies listeners when style changes', () {
      bool listenerCalled = false;

      final text = AttributedText('abcdefghij');
      text.addListener(() {
        listenerCalled = true;
      });

      text.addAttribution(ExpectedSpans.bold, const SpanRange(1, 1));

      expect(listenerCalled, isTrue);
    });

    group("equality", () {
      test("equivalent AttributedText are equal", () {
        expect(
          AttributedText(
            'abcdefghij',
            AttributedSpans(
              attributions: [
                const SpanMarker(attribution: ExpectedSpans.bold, offset: 2, markerType: SpanMarkerType.start),
                const SpanMarker(attribution: ExpectedSpans.italics, offset: 4, markerType: SpanMarkerType.start),
                const SpanMarker(attribution: ExpectedSpans.bold, offset: 5, markerType: SpanMarkerType.end),
                const SpanMarker(attribution: ExpectedSpans.italics, offset: 7, markerType: SpanMarkerType.end),
              ],
            ),
          ),
          equals(
            AttributedText(
              'abcdefghij',
              AttributedSpans(
                attributions: [
                  const SpanMarker(attribution: ExpectedSpans.bold, offset: 2, markerType: SpanMarkerType.start),
                  const SpanMarker(attribution: ExpectedSpans.italics, offset: 4, markerType: SpanMarkerType.start),
                  const SpanMarker(attribution: ExpectedSpans.bold, offset: 5, markerType: SpanMarkerType.end),
                  const SpanMarker(attribution: ExpectedSpans.italics, offset: 7, markerType: SpanMarkerType.end),
                ],
              ),
            ),
          ),
        );
      });

      test("different text are not equal", () {
        expect(
          AttributedText(
                'jihgfedcba',
                AttributedSpans(
                  attributions: [
                    const SpanMarker(attribution: ExpectedSpans.bold, offset: 2, markerType: SpanMarkerType.start),
                    const SpanMarker(attribution: ExpectedSpans.italics, offset: 4, markerType: SpanMarkerType.start),
                    const SpanMarker(attribution: ExpectedSpans.bold, offset: 5, markerType: SpanMarkerType.end),
                    const SpanMarker(attribution: ExpectedSpans.italics, offset: 7, markerType: SpanMarkerType.end),
                  ],
                ),
              ) ==
              AttributedText(
                'abcdefghij',
                AttributedSpans(
                  attributions: [
                    const SpanMarker(attribution: ExpectedSpans.bold, offset: 2, markerType: SpanMarkerType.start),
                    const SpanMarker(attribution: ExpectedSpans.italics, offset: 4, markerType: SpanMarkerType.start),
                    const SpanMarker(attribution: ExpectedSpans.bold, offset: 5, markerType: SpanMarkerType.end),
                    const SpanMarker(attribution: ExpectedSpans.italics, offset: 7, markerType: SpanMarkerType.end),
                  ],
                ),
              ),
          isFalse,
        );
      });

      test("different spans are not equal", () {
        expect(
          AttributedText(
                'abcdefghij',
                AttributedSpans(
                  attributions: [
                    const SpanMarker(attribution: ExpectedSpans.bold, offset: 2, markerType: SpanMarkerType.start),
                    const SpanMarker(attribution: ExpectedSpans.italics, offset: 4, markerType: SpanMarkerType.start),
                    const SpanMarker(attribution: ExpectedSpans.bold, offset: 5, markerType: SpanMarkerType.end),
                    const SpanMarker(attribution: ExpectedSpans.italics, offset: 7, markerType: SpanMarkerType.end),
                  ],
                ),
              ) ==
              AttributedText(
                'abcdefghij',
                AttributedSpans(
                  attributions: [
                    const SpanMarker(attribution: ExpectedSpans.bold, offset: 2, markerType: SpanMarkerType.start),
                    const SpanMarker(attribution: ExpectedSpans.bold, offset: 5, markerType: SpanMarkerType.end),
                  ],
                ),
              ),
          isFalse,
        );
      });
    });

    group('attribution queries', () {
      test('finds all spans for single attribution throughout text', () {
        final attributedText = AttributedText(
          'Hello world',
          AttributedSpans(
            attributions: [
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 2, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 3, markerType: SpanMarkerType.end),
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 6, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 7, markerType: SpanMarkerType.end),
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 9, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 10, markerType: SpanMarkerType.end),
            ],
          ),
        );

        final ranges = attributedText.getAttributionSpans({ExpectedSpans.bold});

        expect(ranges.length, 3);
        expect(
          ranges,
          [
            const AttributionSpan(attribution: ExpectedSpans.bold, start: 2, end: 3),
            const AttributionSpan(attribution: ExpectedSpans.bold, start: 6, end: 7),
            const AttributionSpan(attribution: ExpectedSpans.bold, start: 9, end: 10),
          ],
        );
      });

      test('finds all spans for multiple attributions throughout text', () {
        final attributedText = AttributedText(
          'Hello world',
          AttributedSpans(
            attributions: [
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 2, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 3, markerType: SpanMarkerType.end),
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 6, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 7, markerType: SpanMarkerType.end),
              const SpanMarker(attribution: ExpectedSpans.italics, offset: 5, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.italics, offset: 7, markerType: SpanMarkerType.end),
              const SpanMarker(attribution: ExpectedSpans.italics, offset: 9, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.italics, offset: 10, markerType: SpanMarkerType.end),
            ],
          ),
        );

        final ranges = attributedText.getAttributionSpans({ExpectedSpans.bold, ExpectedSpans.italics});

        expect(ranges.length, 4);
        expect(
          ranges,
          {
            const AttributionSpan(attribution: ExpectedSpans.bold, start: 2, end: 3),
            const AttributionSpan(attribution: ExpectedSpans.italics, start: 5, end: 7),
            const AttributionSpan(attribution: ExpectedSpans.bold, start: 6, end: 7),
            const AttributionSpan(attribution: ExpectedSpans.italics, start: 9, end: 10),
          },
        );
      });

      test('returns empty list when searching for non-existent attribution spans', () {
        final attributedText = AttributedText(
          'Hello world',
          AttributedSpans(
            attributions: [
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 2, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 3, markerType: SpanMarkerType.end),
            ],
          ),
        );

        final ranges = attributedText.getAttributionSpans({ExpectedSpans.italics});

        expect(ranges.length, 0);
      });

      test('finds all bold text around a character', () {
        final attributedText = AttributedText(
          'Hello world',
          AttributedSpans(
            attributions: [
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 4, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 9, markerType: SpanMarkerType.end),
            ],
          ),
        );

        final range = attributedText.getAttributedRange({ExpectedSpans.bold}, 5);
        expect(range, const SpanRange(4, 9));
      });

      test('finds all bold and italics text around a character', () {
        final attributedText = AttributedText(
          'Hello world',
          AttributedSpans(
            attributions: [
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 4, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 9, markerType: SpanMarkerType.end),
              const SpanMarker(attribution: ExpectedSpans.italics, offset: 0, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.italics, offset: 7, markerType: SpanMarkerType.end),
              const SpanMarker(attribution: ExpectedSpans.strikethrough, offset: 0, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.strikethrough, offset: 10, markerType: SpanMarkerType.end),
            ],
          ),
        );

        final range = attributedText.getAttributedRange({ExpectedSpans.bold, ExpectedSpans.italics}, 5);
        expect(range, const SpanRange(4, 7));
      });

      test(
          'finds all bold, italic and strikethrough text within a word that also includes a span with only bold and italics',
          () {
        final attributedText = AttributedText(
          'Hello world',
          AttributedSpans(
            attributions: [
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 0, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 4, markerType: SpanMarkerType.end),
              const SpanMarker(attribution: ExpectedSpans.italics, offset: 0, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.italics, offset: 4, markerType: SpanMarkerType.end),
              const SpanMarker(attribution: ExpectedSpans.strikethrough, offset: 1, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.strikethrough, offset: 3, markerType: SpanMarkerType.end),
            ],
          ),
        );

        final range = attributedText
            .getAttributedRange({ExpectedSpans.bold, ExpectedSpans.italics, ExpectedSpans.strikethrough}, 2);
        expect(range, const SpanRange(1, 3));
      });

      group('getAllAttributionsThroughout', () {
        test('returns empty list if the range does not have any attributions', () {
          final attributedText = AttributedText('Text without attributions');
          expect(attributedText.getAllAttributionsThroughout(const SpanRange(5, 12)), isEmpty);
        });

        test('returns attributions that apply to the entirety of the range', () {
          // Create a text with the following attributions:
          // - bold: applied throught the entire text.
          // - underline: applied to the word "with",
          // - italics: applied from the begining of the text until "wi|th".
          // - strikethrough: applied from "wi|th" until the end of the text.

          final attributedText = AttributedText(
            'Text with attributions',
            AttributedSpans(
              attributions: const [
                SpanMarker(attribution: ExpectedSpans.bold, offset: 0, markerType: SpanMarkerType.start),
                SpanMarker(attribution: ExpectedSpans.italics, offset: 0, markerType: SpanMarkerType.start),
                SpanMarker(attribution: ExpectedSpans.underline, offset: 5, markerType: SpanMarkerType.start),
                SpanMarker(attribution: ExpectedSpans.italics, offset: 6, markerType: SpanMarkerType.end),
                SpanMarker(attribution: ExpectedSpans.strikethrough, offset: 6, markerType: SpanMarkerType.start),
                SpanMarker(attribution: ExpectedSpans.underline, offset: 8, markerType: SpanMarkerType.end),
                SpanMarker(attribution: ExpectedSpans.strikethrough, offset: 21, markerType: SpanMarkerType.end),
                SpanMarker(attribution: ExpectedSpans.bold, offset: 21, markerType: SpanMarkerType.end),
              ],
            ),
          );

          expect(
            attributedText.getAllAttributionsThroughout(const SpanRange(5, 8)),
            {ExpectedSpans.bold, ExpectedSpans.underline},
          );
        });
      });
    });

    group("attribution visitation", () {
      test("visits full-length attributions", () {
        final attributedText = AttributedText(
          'Hello world',
          AttributedSpans(
            attributions: [
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 0, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 10, markerType: SpanMarkerType.end),
            ],
          ),
        );

        final expectedVisits = [
          _AttributionVisit(0, {ExpectedSpans.bold}, {}),
          _AttributionVisit(10, {}, {ExpectedSpans.bold}),
        ];

        attributedText.visitAttributions(
          CallbackAttributionVisitor(
            visitAttributions: (
              AttributedText fullText,
              int index,
              Set<Attribution> startingAttributions,
              Set<Attribution> endingAttributions,
            ) {
              expect(_AttributionVisit(index, startingAttributions, endingAttributions), expectedVisits.first);
              expectedVisits.removeAt(0);
            },
          ),
        );

        expect(expectedVisits, isEmpty);
      });

      test("visits partial-length attributions", () {
        final attributedText = AttributedText(
          'Hello world',
          AttributedSpans(
            attributions: [
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 2, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 8, markerType: SpanMarkerType.end),
            ],
          ),
        );

        final expectedVisits = [
          _AttributionVisit(2, {ExpectedSpans.bold}, {}),
          _AttributionVisit(8, {}, {ExpectedSpans.bold}),
        ];

        attributedText.visitAttributions(
          CallbackAttributionVisitor(
            visitAttributions: (
              AttributedText fullText,
              int index,
              Set<Attribution> startingAttributions,
              Set<Attribution> endingAttributions,
            ) {
              expect(_AttributionVisit(index, startingAttributions, endingAttributions), expectedVisits.first);
              expectedVisits.removeAt(0);
            },
          ),
        );

        expect(expectedVisits, isEmpty);
      });

      test("visits overlapping attributions", () {
        final attributedText = AttributedText(
          'Hello world',
          AttributedSpans(
            attributions: [
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 0, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 6, markerType: SpanMarkerType.end),
              const SpanMarker(attribution: ExpectedSpans.italics, offset: 4, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.italics, offset: 10, markerType: SpanMarkerType.end),
            ],
          ),
        );

        final expectedVisits = [
          _AttributionVisit(0, {ExpectedSpans.bold}, {}),
          _AttributionVisit(4, {ExpectedSpans.italics}, {}),
          _AttributionVisit(6, {}, {ExpectedSpans.bold}),
          _AttributionVisit(10, {}, {ExpectedSpans.italics}),
        ];

        attributedText.visitAttributions(
          CallbackAttributionVisitor(
            visitAttributions: (
              AttributedText fullText,
              int index,
              Set<Attribution> startingAttributions,
              Set<Attribution> endingAttributions,
            ) {
              expect(_AttributionVisit(index, startingAttributions, endingAttributions), expectedVisits.first);
              expectedVisits.removeAt(0);
            },
          ),
        );

        expect(expectedVisits, isEmpty);
      });

      test("visits multiple starting and ending attributions", () {
        final attributedText = AttributedText(
          'Hello world',
          AttributedSpans(
            attributions: [
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 2, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 8, markerType: SpanMarkerType.end),
              const SpanMarker(attribution: ExpectedSpans.italics, offset: 2, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.italics, offset: 8, markerType: SpanMarkerType.end),
            ],
          ),
        );

        final expectedVisits = [
          _AttributionVisit(2, {ExpectedSpans.bold, ExpectedSpans.italics}, {}),
          _AttributionVisit(8, {}, {ExpectedSpans.bold, ExpectedSpans.italics}),
        ];

        attributedText.visitAttributions(
          CallbackAttributionVisitor(
            visitAttributions: (
              AttributedText fullText,
              int index,
              Set<Attribution> startingAttributions,
              Set<Attribution> endingAttributions,
            ) {
              expect(_AttributionVisit(index, startingAttributions, endingAttributions), expectedVisits.first);
              expectedVisits.removeAt(0);
            },
          ),
        );

        expect(expectedVisits, isEmpty);
      });
    });

    group("attribution span visitation", () {
      test("visits full-length attributions", () {
        final attributedText = AttributedText(
          'Hello world',
          AttributedSpans(
            attributions: [
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 0, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 10, markerType: SpanMarkerType.end),
            ],
          ),
        );

        final expectedVisits = [
          MultiAttributionSpan(attributions: {ExpectedSpans.bold}, start: 0, end: 10),
        ];

        attributedText.visitAttributionSpans(
          (span) {
            expect(span, expectedVisits.first);
            expectedVisits.removeAt(0);
          },
        );

        expect(expectedVisits, isEmpty);
      });

      test("visits partial-length attributions", () {
        final attributedText = AttributedText(
          'Hello world',
          AttributedSpans(
            attributions: [
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 2, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 8, markerType: SpanMarkerType.end),
            ],
          ),
        );

        final expectedVisits = [
          const MultiAttributionSpan(attributions: {}, start: 0, end: 1),
          MultiAttributionSpan(attributions: {ExpectedSpans.bold}, start: 2, end: 8),
          const MultiAttributionSpan(attributions: {}, start: 9, end: 10),
        ];

        attributedText.visitAttributionSpans(
          (span) {
            expect(span, expectedVisits.first);
            expectedVisits.removeAt(0);
          },
        );

        expect(expectedVisits, isEmpty);
      });

      test("visits overlapping attributions", () {
        final attributedText = AttributedText(
          'Hello world',
          AttributedSpans(
            attributions: [
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 0, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 6, markerType: SpanMarkerType.end),
              const SpanMarker(attribution: ExpectedSpans.italics, offset: 4, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.italics, offset: 10, markerType: SpanMarkerType.end),
            ],
          ),
        );

        final expectedVisits = [
          MultiAttributionSpan(attributions: {ExpectedSpans.bold}, start: 0, end: 3),
          MultiAttributionSpan(attributions: {ExpectedSpans.bold, ExpectedSpans.italics}, start: 4, end: 6),
          MultiAttributionSpan(attributions: {ExpectedSpans.italics}, start: 7, end: 10),
        ];

        attributedText.visitAttributionSpans(
          (span) {
            expect(span, expectedVisits.first);
            expectedVisits.removeAt(0);
          },
        );

        expect(expectedVisits, isEmpty);
      });

      test("visits multiple starting and ending attributions", () {
        final attributedText = AttributedText(
          'Hello world',
          AttributedSpans(
            attributions: [
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 2, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 8, markerType: SpanMarkerType.end),
              const SpanMarker(attribution: ExpectedSpans.italics, offset: 2, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.italics, offset: 8, markerType: SpanMarkerType.end),
            ],
          ),
        );

        final expectedVisits = [
          const MultiAttributionSpan(attributions: {}, start: 0, end: 1),
          MultiAttributionSpan(attributions: {ExpectedSpans.bold, ExpectedSpans.italics}, start: 2, end: 8),
          const MultiAttributionSpan(attributions: {}, start: 9, end: 10),
        ];

        attributedText.visitAttributionSpans(
          (span) {
            expect(span, expectedVisits.first);
            expectedVisits.removeAt(0);
          },
        );

        expect(expectedVisits, isEmpty);
      });
    });

    group('collapseSpans', () {
      const boldAttribution = NamedAttribution('bold');

      test('returns a single span for text without attributions', () {
        final text = AttributedText('Hello World');

        final spans = text.computeAttributionSpans().toList();

        // Ensure a single span containing the whole text was returned.
        expect(spans.length, 1);
        expect(spans[0].attributions, isEmpty);
        expect(spans[0].start, 0);
        expect(spans[0].end, text.length - 1);
      });

      test('returns a single span for text with an attribution containing the whole text', () {
        final text = AttributedText(
          'Hello World',
          AttributedSpans(
            attributions: const [
              SpanMarker(
                attribution: boldAttribution,
                markerType: SpanMarkerType.start,
                offset: 0,
              ),
              SpanMarker(
                attribution: boldAttribution,
                markerType: SpanMarkerType.end,
                offset: 10,
              ),
            ],
          ),
        );

        final spans = text.computeAttributionSpans().toList();

        // Ensure a single span containing the whole text was returned.
        expect(spans.length, 1);
        expect(spans[0].attributions, isNotEmpty);
        expect(spans[0].start, 0);
        expect(spans[0].end, text.length - 1);
      });

      test('returns two spans for text with an attribution from the beginning until half of the text', () {
        // Create a text with a bold attribution in "Hello ".
        final text = AttributedText(
          'Hello World',
          AttributedSpans(
            attributions: const [
              SpanMarker(
                attribution: boldAttribution,
                markerType: SpanMarkerType.start,
                offset: 0,
              ),
              SpanMarker(
                attribution: boldAttribution,
                markerType: SpanMarkerType.end,
                offset: 5,
              ),
            ],
          ),
        );

        final spans = text.computeAttributionSpans().toList();

        // Ensure two spans were returned.
        // The first containing the attribution and the second without any attributions.
        expect(spans.length, 2);
        expect(spans[0].attributions, isNotEmpty);
        expect(spans[0].start, 0);
        expect(spans[0].end, 5);
        expect(spans[1].attributions, isEmpty);
        expect(spans[1].start, 6);
        expect(spans[1].end, text.length - 1);
      });

      test('handles markers which end after the end of the text', () {
        // Create a text with a bold attribution in "World".
        // The marker end offset is bigger than the last character index (the text lenght is 11).
        final text = AttributedText(
          'Hello World',
          AttributedSpans(
            attributions: const [
              SpanMarker(
                attribution: boldAttribution,
                markerType: SpanMarkerType.start,
                offset: 6,
              ),
              SpanMarker(
                attribution: boldAttribution,
                markerType: SpanMarkerType.end,
                offset: 11,
              ),
            ],
          ),
        );

        final spans = text.computeAttributionSpans().toList();

        // Ensure two spans were returned. The first containing no attributions and
        // the second containing the attribution.
        expect(spans.length, 2);
        expect(spans[0].attributions, isEmpty);
        expect(spans[0].start, 0);
        expect(spans[0].end, 5);
        expect(spans[1].attributions, isNotEmpty);
        expect(spans[1].start, 6);
        expect(spans[1].end, 10);
      });
    });

    group("copy >", () {
      test("copies an AttributedText without any attributions", () {
        final attributedText = AttributedText(
          'Sample Text',
        );

        expect(attributedText.copy(), AttributedText('Sample Text'));
      });

      test("copies an AttributedText with attributions", () {
        final attributedText = AttributedText(
          'abcdefghij',
          AttributedSpans(
            attributions: [
              const SpanMarker(
                attribution: ExpectedSpans.bold,
                offset: 2,
                markerType: SpanMarkerType.start,
              ),
              const SpanMarker(
                attribution: ExpectedSpans.italics,
                offset: 4,
                markerType: SpanMarkerType.start,
              ),
              const SpanMarker(
                attribution: ExpectedSpans.bold,
                offset: 5,
                markerType: SpanMarkerType.end,
              ),
              const SpanMarker(
                attribution: ExpectedSpans.italics,
                offset: 7,
                markerType: SpanMarkerType.end,
              ),
            ],
          ),
        );

        expect(
          attributedText.copy(),
          AttributedText(
            'abcdefghij',
            AttributedSpans(
              attributions: [
                const SpanMarker(
                  attribution: ExpectedSpans.bold,
                  offset: 2,
                  markerType: SpanMarkerType.start,
                ),
                const SpanMarker(
                  attribution: ExpectedSpans.italics,
                  offset: 4,
                  markerType: SpanMarkerType.start,
                ),
                const SpanMarker(
                  attribution: ExpectedSpans.bold,
                  offset: 5,
                  markerType: SpanMarkerType.end,
                ),
                const SpanMarker(
                  attribution: ExpectedSpans.italics,
                  offset: 7,
                  markerType: SpanMarkerType.end,
                ),
              ],
            ),
          ),
        );
      });
    });
  });
}

class _AttributionVisit {
  _AttributionVisit(
    this.index,
    this.startingAttributions,
    this.endingAttributions,
  );

  final int index;
  final Set<Attribution> startingAttributions;
  final Set<Attribution> endingAttributions;

  @override
  String toString() =>
      "[_AttributionVisit] - index: $index, starting: $startingAttributions, ending: $endingAttributions";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _AttributionVisit &&
          runtimeType == other.runtimeType &&
          index == other.index &&
          const DeepCollectionEquality().equals(startingAttributions, other.startingAttributions) &&
          const DeepCollectionEquality().equals(endingAttributions, other.endingAttributions);

  @override
  int get hashCode => index.hashCode ^ startingAttributions.hashCode ^ endingAttributions.hashCode;
}
