import 'package:flutter/painting.dart';
import 'package:super_editor/super_editor.dart';

/// A Quill Delta document that uses every type of standard editor styles.
///
/// This is the Quill version of [createAllTextStylesSuperEditorDocument].
const allTextStylesDeltaDocument = [
  {"insert": "All Text Styles"},
  {
    "attributes": {"header": 1},
    "insert": "\n"
  },
  {"insert": "Samples of styles: "},
  {
    "attributes": {"bold": true},
    "insert": "bold"
  },
  {"insert": ", "},
  {
    "attributes": {"italic": true},
    "insert": "italics"
  },
  {"insert": ", "},
  {
    "attributes": {"underline": true},
    "insert": "underline"
  },
  {"insert": ", "},
  {
    "attributes": {"strike": true},
    "insert": "strikethrough"
  },
  {"insert": ", "},
  {
    "attributes": {"color": "#e60000"},
    "insert": "text color"
  },
  {"insert": ", "},
  {
    "attributes": {"background": "#e60000"},
    "insert": "background color"
  },
  {"insert": ", "},
  {
    "attributes": {"font": "serif"},
    "insert": "font change"
  },
  {"insert": ", "},
  {
    "attributes": {"link": "google.com"},
    "insert": "link"
  },
  {"insert": "\n\nLeft aligned\nCenter aligned"},
  {
    "attributes": {"align": "center"},
    "insert": "\n"
  },
  {"insert": "Right aligned"},
  {
    "attributes": {"align": "right"},
    "insert": "\n"
  },
  {"insert": "Justified"},
  {
    "attributes": {"align": "justify"},
    "insert": "\n"
  },
  {"insert": "\nOrdered item 1"},
  {
    "attributes": {"list": "ordered"},
    "insert": "\n"
  },
  {"insert": "Ordered item 2"},
  {
    "attributes": {"list": "ordered"},
    "insert": "\n"
  },
  {"insert": "\nUnordered item 1"},
  {
    "attributes": {"list": "bullet"},
    "insert": "\n"
  },
  {"insert": "Unordered item 2"},
  {
    "attributes": {"list": "bullet"},
    "insert": "\n"
  },
  {"insert": "\nI'm a task that's incomplete"},
  {
    "attributes": {"list": "unchecked"},
    "insert": "\n"
  },
  {"insert": "I'm a task that's complete"},
  {
    "attributes": {"list": "checked"},
    "insert": "\n"
  },
  {"insert": "\nI'm an indented paragraph at level 1"},
  {
    "attributes": {"indent": 1},
    "insert": "\n"
  },
  {"insert": "I'm a paragraph indented at level 2"},
  {
    "attributes": {"indent": 2},
    "insert": "\n"
  },
  {"insert": "\nSome content"},
  {
    "attributes": {"script": "sub"},
    "insert": "This is a subscript"
  },
  {"insert": "\nSome content"},
  {
    "attributes": {"script": "super"},
    "insert": "This is a superscript"
  },
  {"insert": "\n\n"},
  {
    "attributes": {"size": "huge"},
    "insert": "HUGE"
  },
  {"insert": "\n"},
  {
    "attributes": {"size": "large"},
    "insert": "Large"
  },
  {"insert": "\n"},
  {
    "attributes": {"size": "small"},
    "insert": "small"
  },
  {"insert": "\n\nThis is a blockquote"},
  {
    "attributes": {"blockquote": true},
    "insert": "\n"
  },
  // Notice: A multiline code block, while rendered as a single block, is
  // encoded as independently attributed deltas.
  {"insert": "\nThis is a code block"},
  {
    "attributes": {"code-block": "plain"},
    "insert": "\n"
  },
  {"insert": "That spans two lines."},
  {
    "attributes": {"code-block": "plain"},
    "insert": "\n"
  }
];

/// A Super Editor document that uses every type editor style that appears in
/// a standard Quill editor.
///
/// This is the Super Editor version of [allTextStylesDeltaDocument].
MutableDocument createAllTextStylesSuperEditorDocument() {
  return MutableDocument(
    nodes: [
      ParagraphNode(
        id: "1",
        text: AttributedText("All Text Styles"),
        metadata: const {
          "blockType": header1Attribution,
        },
      ),
      ParagraphNode(
        id: "2",
        text: AttributedText(
          "Samples of styles: bold, italics, underline, strikethrough, text color, background color, font change, link",
          AttributedSpans(
            attributions: [
              const SpanMarker(attribution: boldAttribution, offset: 19, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: boldAttribution, offset: 22, markerType: SpanMarkerType.end),
              const SpanMarker(attribution: italicsAttribution, offset: 25, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: italicsAttribution, offset: 31, markerType: SpanMarkerType.end),
              const SpanMarker(attribution: underlineAttribution, offset: 34, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: underlineAttribution, offset: 42, markerType: SpanMarkerType.end),
              const SpanMarker(attribution: strikethroughAttribution, offset: 45, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: strikethroughAttribution, offset: 57, markerType: SpanMarkerType.end),
              const SpanMarker(
                  attribution: ColorAttribution(Color(0xFFe60000)), offset: 60, markerType: SpanMarkerType.start),
              const SpanMarker(
                  attribution: ColorAttribution(Color(0xFFe60000)), offset: 69, markerType: SpanMarkerType.end),
              const SpanMarker(
                  attribution: BackgroundColorAttribution(Color(0xFFe60000)),
                  offset: 72,
                  markerType: SpanMarkerType.start),
              const SpanMarker(
                  attribution: BackgroundColorAttribution(Color(0xFFe60000)),
                  offset: 87,
                  markerType: SpanMarkerType.end),
              const SpanMarker(
                  attribution: FontFamilyAttribution("serif"), offset: 90, markerType: SpanMarkerType.start),
              const SpanMarker(
                  attribution: FontFamilyAttribution("serif"), offset: 100, markerType: SpanMarkerType.end),
              const SpanMarker(
                  attribution: LinkAttribution("google.com"), offset: 103, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: LinkAttribution("google.com"), offset: 106, markerType: SpanMarkerType.end),
            ],
          ),
        ),
      ),
      ParagraphNode(id: "3", text: AttributedText("")),
      ParagraphNode(id: "4", text: AttributedText("Left aligned")),
      ParagraphNode(id: "5", text: AttributedText("Center aligned"), metadata: const {"textAlign": "center"}),
      ParagraphNode(id: "6", text: AttributedText("Right aligned"), metadata: const {"textAlign": "right"}),
      ParagraphNode(id: "7", text: AttributedText("Justified"), metadata: const {"textAlign": "justify"}),
      ParagraphNode(id: "8", text: AttributedText("")),
      ListItemNode(id: "9", itemType: ListItemType.ordered, text: AttributedText("Ordered item 1")),
      ListItemNode(id: "10", itemType: ListItemType.ordered, text: AttributedText("Ordered item 2")),
      ParagraphNode(id: "11", text: AttributedText("")),
      ListItemNode(id: "12", itemType: ListItemType.unordered, text: AttributedText("Unordered item 1")),
      ListItemNode(id: "13", itemType: ListItemType.unordered, text: AttributedText("Unordered item 2")),
      ParagraphNode(id: "14", text: AttributedText("")),
      TaskNode(id: "15", text: AttributedText("I'm a task that's incomplete"), isComplete: false),
      TaskNode(id: "16", text: AttributedText("I'm a task that's complete"), isComplete: true),
      ParagraphNode(id: "17", text: AttributedText("")),
      ParagraphNode(id: "18", text: AttributedText("I'm an indented paragraph at level 1"), indent: 1),
      ParagraphNode(id: "19", text: AttributedText("I'm a paragraph indented at level 2"), indent: 2),
      ParagraphNode(id: "20", text: AttributedText("")),
      ParagraphNode(
        id: "21",
        text: AttributedText(
          "Some contentThis is a subscript",
          AttributedSpans(
            attributions: [
              const SpanMarker(attribution: subscriptAttribution, offset: 12, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: subscriptAttribution, offset: 30, markerType: SpanMarkerType.end),
            ],
          ),
        ),
      ),
      ParagraphNode(
        id: "22",
        text: AttributedText(
          "Some contentThis is a superscript",
          AttributedSpans(
            attributions: [
              const SpanMarker(attribution: superscriptAttribution, offset: 12, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: superscriptAttribution, offset: 32, markerType: SpanMarkerType.end),
            ],
          ),
        ),
      ),
      ParagraphNode(id: "23", text: AttributedText("")),
      ParagraphNode(
        id: "24",
        text: AttributedText(
          "HUGE",
          AttributedSpans(
            attributions: [
              const SpanMarker(
                  attribution: NamedFontSizeAttribution("huge"), offset: 0, markerType: SpanMarkerType.start),
              const SpanMarker(
                  attribution: NamedFontSizeAttribution("huge"), offset: 3, markerType: SpanMarkerType.end),
            ],
          ),
        ),
      ),
      ParagraphNode(
        id: "25",
        text: AttributedText(
          "Large",
          AttributedSpans(
            attributions: [
              const SpanMarker(
                  attribution: NamedFontSizeAttribution("large"), offset: 0, markerType: SpanMarkerType.start),
              const SpanMarker(
                  attribution: NamedFontSizeAttribution("large"), offset: 4, markerType: SpanMarkerType.end),
            ],
          ),
        ),
      ),
      ParagraphNode(
        id: "26",
        text: AttributedText(
          "small",
          AttributedSpans(
            attributions: [
              const SpanMarker(
                  attribution: NamedFontSizeAttribution("small"), offset: 0, markerType: SpanMarkerType.start),
              const SpanMarker(
                  attribution: NamedFontSizeAttribution("small"), offset: 4, markerType: SpanMarkerType.end),
            ],
          ),
        ),
      ),
      ParagraphNode(id: "27", text: AttributedText("")),
      ParagraphNode(
        id: "28",
        text: AttributedText("This is a blockquote"),
        metadata: const {"blockType": blockquoteAttribution},
      ),
      ParagraphNode(id: "29", text: AttributedText("")),
      ParagraphNode(
        id: "30",
        text: AttributedText("This is a code block\nThat spans two lines."),
        metadata: const {"blockType": codeAttribution},
      ),
    ],
  );
}
