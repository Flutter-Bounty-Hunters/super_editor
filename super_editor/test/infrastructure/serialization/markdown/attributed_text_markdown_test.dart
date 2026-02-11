import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group("AttributedText markdown serializes", () {
    test("un-styled text", () {
      expect(
        AttributedText("This is unstyled text.").toMarkdown(),
        "This is unstyled text.",
      );
    });

    test("single character styles", () {
      expect(
        attributedTextFromMarkdown(
          "This is **s**ingle characte*r* styles.",
        ).toMarkdown(),
        "This is **s**ingle characte*r* styles.",
      );
    });

    test("bold text", () {
      expect(
        attributedTextFromMarkdown(
          "This is **bold** text.",
        ).toMarkdown(),
        "This is **bold** text.",
      );
    });

    test("italics text", () {
      expect(
        attributedTextFromMarkdown(
          "This is *italics* text.",
        ).toMarkdown(),
        "This is *italics* text.",
      );
    });

    test("multiple styles across the same span", () {
      expect(
        attributedTextFromMarkdown(
          "This is ***multiple styled*** text.",
        ).toMarkdown(),
        "This is ***multiple styled*** text.",
      );
    });

    test("partially overlapping styles", () {
      // This test needs to manually configure attributed spans because it
      // turns out that Markdown doesn't know how to parse overlapping styles,
      // so we can't parse this text from Markdown, but we can still test our
      // ability to serialize overlapping styles.
      expect(
        AttributedText(
          "This is overlapping styles.",
          AttributedSpans(
            attributions: [
              const SpanMarker(attribution: boldAttribution, offset: 8, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: boldAttribution, offset: 13, markerType: SpanMarkerType.end),
              const SpanMarker(attribution: italicsAttribution, offset: 11, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: italicsAttribution, offset: 18, markerType: SpanMarkerType.end),
            ],
          ),
        ).toMarkdown(),
        "This is **ove*rla**pping* styles.",
      );
    });
  });
}
