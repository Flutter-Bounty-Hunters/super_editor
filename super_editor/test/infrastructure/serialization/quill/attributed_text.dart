import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  test("Attributed text split", () {
    final text = AttributedText(
      "Line one\nLine two\nLine three",
      AttributedSpans(
        attributions: [
          const SpanMarker(
            attribution: boldAttribution,
            offset: 14,
            markerType: SpanMarkerType.start,
          ),
          const SpanMarker(
            attribution: boldAttribution,
            offset: 21,
            markerType: SpanMarkerType.end,
          ),
        ],
      ),
    );
    final textByLine = text.split("\n");

    expect(textByLine.length, 3);
    expect(textByLine[0], AttributedText("Line one"));
    expect(
      textByLine[1],
      AttributedText(
        "Line two",
        AttributedSpans(
          attributions: [
            const SpanMarker(
              attribution: boldAttribution,
              offset: 5,
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
    );
    expect(
      textByLine[2],
      AttributedText(
        "Line three",
        AttributedSpans(
          attributions: [
            const SpanMarker(
              attribution: boldAttribution,
              offset: 0,
              markerType: SpanMarkerType.start,
            ),
            const SpanMarker(
              attribution: boldAttribution,
              offset: 3,
              markerType: SpanMarkerType.end,
            ),
          ],
        ),
      ),
    );
  });
}
