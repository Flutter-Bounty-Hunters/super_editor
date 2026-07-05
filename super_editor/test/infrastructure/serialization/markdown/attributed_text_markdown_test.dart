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
      //
      // Overlapping styles can't be expressed directly in Markdown. The
      // serializer closes and re-opens the inner style so that the markers
      // nest properly, and the output re-parses to the same styled text.
      final text = AttributedText(
        "This is overlapping styles.",
        AttributedSpans(
          attributions: [
            const SpanMarker(attribution: boldAttribution, offset: 8, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: boldAttribution, offset: 13, markerType: SpanMarkerType.end),
            const SpanMarker(attribution: italicsAttribution, offset: 11, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: italicsAttribution, offset: 18, markerType: SpanMarkerType.end),
          ],
        ),
      );

      final markdown = text.toMarkdown();
      expect(markdown, "This is **ove*rla****pping* styles.");

      // The bar for overlapping styles: the output must re-parse to the same
      // styled text.
      final reparsed = parseInlineMarkdown(markdown);
      expect(reparsed.toPlainText(), "This is overlapping styles.");
      for (int i = 0; i < reparsed.length; i += 1) {
        expect(
          reparsed.getAllAttributionsAt(i).contains(boldAttribution),
          8 <= i && i <= 13,
          reason: "bold at index $i",
        );
        expect(
          reparsed.getAllAttributionsAt(i).contains(italicsAttribution),
          11 <= i && i <= 18,
          reason: "italics at index $i",
        );
      }
    });
  });

  group("AttributedText markdown round-trips", () {
    test("bold span with trailing whitespace is trimmed to valid CommonMark", () {
      // A user can select "bold " (including the space) and press the bold
      // button. Serializing the markers around the space would produce
      // "**bold ** text", which no CommonMark parser re-parses as bold — the
      // styling would silently vanish on the next load.
      final text = AttributedText("bold text");
      text.addAttribution(boldAttribution, const SpanRange(0, 4)); // "bold ", including the space.

      expect(text.toMarkdown(), "**bold** text");
    });

    test("bold span with leading whitespace is trimmed to valid CommonMark", () {
      final text = AttributedText("some bold");
      text.addAttribution(boldAttribution, const SpanRange(4, 8)); // " bold", including the space.

      expect(text.toMarkdown(), "some **bold**");
    });

    test("whitespace-only bold span is dropped", () {
      final text = AttributedText("a b");
      text.addAttribution(boldAttribution, const SpanRange(1, 1)); // just the space

      expect(text.toMarkdown(), "a b");
    });

    test("adjacent bold spans serialize as a single span", () {
      final text = AttributedText("ab");
      text.addAttribution(boldAttribution, const SpanRange(0, 0));
      text.addAttribution(boldAttribution, const SpanRange(1, 1));

      expect(text.toMarkdown(), "**ab**");
    });

    test("strikethrough serializes as GFM double tilde", () {
      final text = AttributedText("gone");
      text.addAttribution(strikethroughAttribution, const SpanRange(0, 3));

      expect(text.toMarkdown(), "~~gone~~");
      expect(
        parseInlineMarkdown("~~gone~~").getAllAttributionsAt(0).contains(strikethroughAttribution),
        true,
      );
      // Legacy single-tilde input is still parsed...
      expect(
        parseInlineMarkdown("~gone~").getAllAttributionsAt(0).contains(strikethroughAttribution),
        true,
      );
      // ...and heals to the GFM form on the next serialization.
      expect(parseInlineMarkdown("~gone~").toMarkdown(), "~~gone~~");
    });

    test("underline serializes as <u> tags and parses back", () {
      final text = AttributedText("underlined");
      text.addAttribution(underlineAttribution, const SpanRange(0, 9));

      expect(text.toMarkdown(), "<u>underlined</u>");

      final reparsed = parseInlineMarkdown("<u>underlined</u>");
      expect(reparsed.toPlainText(), "underlined");
      expect(reparsed.getAllAttributionsAt(0).contains(underlineAttribution), true);
      expect(reparsed.getAllAttributionsAt(9).contains(underlineAttribution), true);
    });

    test("legacy ¬ underline heals to <u>", () {
      expect(parseInlineMarkdown("¬underlined¬").toMarkdown(), "<u>underlined</u>");
    });

    test("underline containing nested styles round-trips", () {
      final reparsed = parseInlineMarkdown("<u>**bold** and plain</u>");
      expect(reparsed.toPlainText(), "bold and plain");
      expect(reparsed.getAllAttributionsAt(0).contains(underlineAttribution), true);
      expect(reparsed.getAllAttributionsAt(0).contains(boldAttribution), true);
      expect(reparsed.getAllAttributionsAt(5).contains(boldAttribution), false);
      expect(reparsed.getAllAttributionsAt(13).contains(underlineAttribution), true);
    });

    test("backslash escapes survive the round trip", () {
      // Parsing strips the backslash for display ("3*4"), records the escape as
      // an attribution, and serialization re-emits the backslash. Without this,
      // "3\*4 and a\_b" would save as "3*4 and a_b" and the bare markers could
      // be re-interpreted as emphasis on a later parse.
      final parsed = parseInlineMarkdown(r"3\*4 and a\_b");
      expect(parsed.toPlainText(), "3*4 and a_b");
      expect(parsed.toMarkdown(), r"3\*4 and a\_b");
    });

    test("unescaped plain text that would gain styling is escaped on serialization", () {
      // "3*4 and 5*6" contains a valid emphasis pair. Serializing it verbatim
      // would corrupt the text on the next parse: 3<em>4 and 5</em>6.
      final text = AttributedText("3*4 and 5*6");

      final markdown = text.toMarkdown();
      expect(markdown, r"3\*4 and 5\*6");

      final reparsed = parseInlineMarkdown(markdown);
      expect(reparsed.toPlainText(), "3*4 and 5*6");
      expect(reparsed.getAttributionSpansByFilter((a) => a == italicsAttribution), isEmpty);
    });

    test("invalid emphasis markers pass through without escaping", () {
      // "**bold ** text" never re-parses as bold (the closing marker follows a
      // space), so the serializer must not touch it.
      final text = AttributedText("**bold ** text");

      expect(text.toMarkdown(), "**bold ** text");
    });

    test("intraword underscores pass through without escaping", () {
      final text = AttributedText("use my_variable_name and a_b_c here");

      expect(text.toMarkdown(), "use my_variable_name and a_b_c here");
    });

    test("plain paragraph line starting with block syntax is escaped", () {
      expect(
        AttributedText("# not a heading").toMarkdown(escapeLineStartTriggers: true),
        r"\# not a heading",
      );
      expect(
        AttributedText("- not a list item").toMarkdown(escapeLineStartTriggers: true),
        r"\- not a list item",
      );
      expect(
        AttributedText("1. not a list item").toMarkdown(escapeLineStartTriggers: true),
        r"1\. not a list item",
      );
      expect(
        AttributedText("> not a blockquote").toMarkdown(escapeLineStartTriggers: true),
        r"\> not a blockquote",
      );

      // Without opt-in (headers, list items, table cells), nothing is escaped.
      expect(AttributedText("# still a heading").toMarkdown(), "# still a heading");
    });
  });
}
