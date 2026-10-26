# Pinned Unicode line-break data

The experimental backend implements the Unicode **16.0.0** default UAX #14
algorithm in Dart. `UnicodeLineBreaks.compute` returns UTF-16 offsets and marks
mandatory breaks. The rule implementation is adapted from Masaaki Shibata's
[uniseg 0.10.1](https://pypi.org/project/uniseg/0.10.1/) (MIT); that package is
neither a build dependency nor a runtime dependency. Its notice is included in
[UNISEG-LICENSE.txt](UNISEG-LICENSE.txt). Generated Unicode data and the official
conformance fixture are covered by [UNICODE-LICENSE.txt](UNICODE-LICENSE.txt).

Unicode 16 is pinned deliberately; updating it requires regenerating the table,
reviewing changed rules, and replacing/running the corresponding conformance
fixture. It does not mean the backend follows whichever version a host engine
happens to bundle.

## Reproduce the table

Download these official files, preserving their bytes, into a temporary folder:

| Official source | Local filename |
| --- | --- |
| [LineBreak.txt](https://www.unicode.org/Public/16.0.0/ucd/LineBreak.txt) | `FlowLineBreak-16.txt` |
| [UnicodeData.txt](https://www.unicode.org/Public/16.0.0/ucd/UnicodeData.txt) | `FlowUnicodeData-16.txt` |
| [EastAsianWidth.txt](https://www.unicode.org/Public/16.0.0/ucd/EastAsianWidth.txt) | `FlowEastAsianWidth-16.txt` |
| [emoji-data.txt](https://www.unicode.org/Public/16.0.0/ucd/emoji/emoji-data.txt) | `FlowEmoji-16.txt` |

From the repository root run:

```sh
python3 tool/unicode/generate_line_break_data.py /path/to/downloads
```

The generator verifies all four SHA-256 checksums before writing the table.
Its output contains packed ranges for line-break classes and the category,
East Asian width, and pictographic properties needed by the rules. Python is
only used to regenerate data; the package itself uses standard Flutter/Dart APIs.

## Conformance and integration

`prototype/test/unicode_line_break_test.dart` compares all **16,672** cases in the
[official LineBreakTest.txt](https://www.unicode.org/Public/16.0.0/ucd/auxiliary/LineBreakTest.txt)
against the raw default analyzer, including UTF-16 offset conversion.
The checked-in fixture's SHA-256 is
`910759a611a479f37df4f535d2e64d7589be3c5ac5f7491cf1fb4fa4cdb211e9`.

The integrated text backend intentionally tailors those default opportunities:

- Intersect them with Flutter/Dart extended grapheme boundaries.
- Add Flutter `TextPainter.getWordBoundary` opportunities inside complex-context
  (SA) text, such as Thai. Dictionary coverage follows the host Flutter engine;
  the default Unicode conformance suite does not validate dictionary quality.
- Permit emergency grapheme breaks for oversized words, while protecting glue,
  joiners, hard controls, and opening/closing punctuation. This is a wrapping
  policy, separate from the default UAX #14 rules.
- Preserve the prototype's existing explicit-control/empty-line presentation:
  a hard control after text retains the boundary before the control and an empty
  line that consumes it. CRLF is one control sequence. This intentionally differs
  from conventional newline presentation; it preserves the reviewed demo and its
  pointer/caret behavior.

Adjacent text participants share break context, including across padded
wrappers. Zero-padding wrappers also share shaping; padding changes require
separate shaping and are included in each exact candidate's width/metrics.
A soft hyphen paints a visible hyphen only when the chosen fragment breaks there.
A normal widget/custom non-text participant remains a separate protocol source;
there is no claim of paragraph-wide Unicode analysis through arbitrary custom
content. Composition remains horizontal LTR.

Run the conformance and native integration tests from `prototype`:

```sh
flutter test
```

The Unicode fixture test reads a local file. The widget integration tests can
also run in Chrome independently:

```sh
flutter test --platform chrome test/break_correctness_test.dart
```
