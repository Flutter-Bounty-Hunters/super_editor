# Checkpoint 5: shaping-context breadth

The study broadens the compact model from the two original fonts to 19 text/style
cases using two bundled fonts and 12 locally loaded macOS font files. The native
profile and headless results agree: **18 cases pass all range and wrapping probes
at three-grapheme context**. One case, strong negative letter spacing, fails.
This is evidence for the approach over the tested text, not universal font/script
certification. Production layout remains unchanged.

## Native results

All legal ranges in each short sample are compared with the existing exact
Flutter measurer. Wrapping uses widths 80/120/200/320, changing widths, and probes
0.02 pixels either side of exact prefix widths. The negative-spacing case also
uses 24/40/60-pixel widths and probes down to 24 pixels. Every tested context size
receives the same plans. Context sizes are 3, 4, 6 and 8 graphemes.

| Case | Legal ranges | Width errors at context 3 | Wrong breaks / plans |
| --- | ---: | ---: | ---: |
| latin_control | 595 | 0 | 0 / 33 |
| mono_control | 595 | 0 | 0 / 41 |
| times_ligatures | 741 | 0 | 0 / 31 |
| palatino_ligatures | 741 | 0 | 0 / 33 |
| positive_spacing | 406 | 0 | 0 / 37 |
| negative_spacing | 351 | 236 | 24 / 50 |
| arabic | 703 | 0 | 0 / 33 |
| arabic_marks | 231 | 0 | 0 / 27 |
| urdu_nastaliq | 496 | 0 | 0 / 33 |
| devanagari | 171 | 0 | 0 / 29 |
| bengali | 190 | 0 | 0 / 35 |
| tamil | 276 | 0 | 0 / 43 |
| sinhala | 153 | 0 | 0 / 29 |
| thai | 465 | 0 | 0 / 39 |
| khmer | 120 | 0 | 0 / 25 |
| cjk | 105 | 0 | 0 / 26 |
| emoji | 66 | 0 | 0 / 20 |
| combining_marks | 253 | 0 | 0 / 33 |
| mixed_bidi_width_only | 325 | 0 | 0 / 35 |

The corpus includes Latin ligatures, positive/negative spacing, Arabic with and
without marks, Urdu Nastaliq, Devanagari, Bengali, Tamil, Sinhala, Thai, Khmer,
CJK punctuation, emoji sequences, combining marks, and mixed-direction widths.
A single short sample per case is deliberately limited coverage.

## Actionable failure: negative spacing

With bundled Roboto at 20 pixels and `letterSpacing: -5`, the 26-character input
`Wi WiWi iiiiiii WWW AVATAR` has 236 inaccurate legal-range widths and 24 wrong
wrapping plans out of 50 at three-grapheme context. The largest width error is
1.3671875 pixels, on a short range, not an enormous accumulated span.

For example, at width 25.126484375, exact fitting produces seven lines while the
compact model produces eight. This is a real line-break difference, distinct from
the previously accepted nonblocking long-token drift.

| Context size | Width-error ranges | Wrong wrapping plans |
| --- | ---: | ---: |
| 3 | 236 | 24 |
| 4 | 232 | 23 |
| 6 | 226 | 23 |
| 8 | 213 | 21 |

Simply increasing the fixed window does not solve this case. The automatic
eligibility policy should conservatively keep negative-spacing content on the
existing exact path. This retains the feature and need not block optimization
of other content. This study identifies that boundary; it does not modify the
production policy or establish the internal engine cause.

## Limits of the evidence

- These are width-fitting comparisons in the existing LTR engine, including
  shaping for the requested scripts. They do not establish RTL visual ordering,
  correct cursor navigation, selection, or complete language support.
- Font files are loaded under explicit aliases. Raw output records file paths,
  sizes and SHA-256 fingerprints for all 12 local files, plus SDK/OS metadata.
  Collection-face selection and fallback glyph coverage were not independently
  audited; requested font identity is not proof that every glyph came from it.
- Fonts are not redistributed or copied into the repository. Missing files are
  reported as skipped. All 12 were available on the recorded host.
- Only regular 20-pixel styles, the stated spacing values and the supplied text
  are covered. Variable-font axes, arbitrary custom contextual substitutions,
  custom features and broader text corpora remain unvalidated.
- Error counts use the original 0.01-pixel criterion, with a separate count for
  errors of at least half a pixel. This is an accuracy study, not a timing gate.
- The negligible long-token drift from checkpoint 4 remains a nonblocking
  diagnostic; this study does not reopen that decision.

## Reproduce

On macOS, from `performance`:

```sh
flutter test --no-pub test/shaping_study_test.dart

dart run lib/main_prepared_text_checkpoint.dart \
  --flutter /path/to/flutter/bin/flutter \
  --study shaping \
  --output build/profile/shaping-context-native.json
```

The headless test writes `build/profile/shaping-context-debug.json`. The native
runner writes the checkpoint report and host metadata. Both verify the bundled
Latin controls; other findings and missing-font cases remain visible in the
report. The native integration run and headless test passed; analysis is clean.

[Raw native results](../../benchmark_results/shaping-context-native-2026-10-27.json).

## Recommended next checkpoint

Exercise automatic routing between compact fitting and exact fitting in the
isolated performance project, beginning with the negative-spacing fallback. Compare mixed
supported/unsupported content and changing widths against the current engine.
Keep the decision internal to the implementation. Before broad production
promotion, expand custom-font/feature coverage rather than claiming that three
graphemes are universally sufficient.
