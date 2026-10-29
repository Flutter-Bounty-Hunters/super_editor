# Checkpoint 6: automatic range routing

Historical research-stage report. The strategy is now [integrated into the real
paragraph](COMPACT_INTEGRATION.md).

This continues [checkpoint 5](PRETEXT_CHECKPOINT_5.md). The isolated text-fitting
performance project now selects compact or exact measurements automatically from effective
text styles. There is no caller-facing fitting-mode property. Production
`FlowParagraph` still uses its existing text measurement implementation; this is the routing experiment
before integration with retained fragments, widgets and painting.

## Result

**All 486 routing plans match exact Flutter break positions and widths** at the
0.01-pixel criterion in both headless and native profile runs. The previously
failing negative-spacing content now takes the exact route and matches.

| Fixture | Width plans | Compact candidate calls | Exact fallback calls |
| --- | ---: | ---: | ---: |
| supported | 49 | 1997 | 0 |
| negative_only | 47 | 0 | 757 |
| negative_beginning | 47 | 4202 | 3588 |
| negative_middle | 49 | 3918 | 7433 |
| negative_end | 49 | 1958 | 2983 |
| split_word | 49 | 1845 | 833 |
| mixed_fonts | 49 | 11609 | 0 |
| positive_spacing | 49 | 10484 | 0 |
| negative_word_spacing | 49 | 3927 | 7880 |
| mutable_paint | 49 | 3917 | 6292 |

Counts accumulate across the accuracy plans; they are not timings. The report's
width-error field is named `geometryFailures`, but it checks widths only, not
painting/caret/selection geometry. Across 40 fixed-width paragraph comparisons,
the styled exact oracle also matches production line ranges.

All 11 routing/compact regression tests pass, the native integration test passes,
and analysis is clean. This establishes routing behavior in the research fitter.
It does not yet establish production lifecycle or full-fragment correctness.

[Raw native correctness results](../../benchmark_results/automatic-routing-native-2026-10-27.json).

## Next checkpoint

Connect automatic routing to the measurement seam while retaining
exact committed artifacts for painting and interaction geometry. Compare actual
paragraphs with widgets, padded code, resizing and edits against the established
text measurement implementation. Measure complete paragraph-layout time again before claiming that the
research-fitter gains carry over to the application. The policy must remain
internal; applications should not select a fitting mode.

## Policy

A candidate range uses exact Flutter measurement when any overlapping text has:

- Negative letter spacing or word spacing.
- Explicit font features or font variations.
- A foreground/background Paint object.

Otherwise the range uses the compact three-grapheme model. The style decision
uses Flutter's merged paragraph/item style, so inherited values and explicit
child overrides participate. Preparation skips compact measurements for excluded
ranges. A fully unsupported source performs zero compact preparation measurements.

Ranges crossing an unsupported span take the exact path as a whole. Eligible
subranges elsewhere in the same paragraph can still use compact data. This avoids
splitting the paragraph's logical break analysis or treating every style boundary
as a shaping boundary. Compact preparation measures styled substrings, preserving
the individual text styles across an included boundary.

The policy is conservative for styles; it is not a proof that arbitrary fonts
have at most three-grapheme context. Findings and scope limits from checkpoint 5
remain in effect. The negligible long-token drift stays a nonblocking diagnostic.

## Checks

Ten fixture combinations cover supported text, negative spacing alone and at the
beginning/middle/end, a style boundary inside a word with a custom feature,
mixed fonts, positive spacing, negative word spacing and mutable Paint.

Each is fitted at widths 40/80/160/320, changing widths 40/160/80/320, and probes
0.02 pixels either side of exact prefix widths. Candidate counters verify actual
routing, not just equality of final output. Fully supported fixtures use no exact
candidate measurements; negative-only text uses no compact candidates. All mixed
unsupported fixtures exercise both paths.

Additional tests check:

- Reusing supported preparation across widths makes no exact candidate calls.
- Recreating the source after normal → negative → normal spacing changes selects
  the appropriate route, without decisions leaking across those source versions.
- Effective inherited negative spacing and an explicit child override.
- The styled exact reference matches actual production paragraph line ranges at
  all four fixed widths across all ten fixtures.
- The previous compact measurement, ordinary-range and original 520-plan checks.

These are width-fitting tests, not tests of a live editing/widget invalidation
lifecycle. Style/input changes currently create fresh research sources. Painting,
caret/selection geometry, actual embedded widgets and padded code remain future
integration checks. This study does not measure performance; exact fallback work
can still dominate a paragraph with unsupported content.

## Reproduce

From `performance`:

```sh
flutter test --no-pub test/automatic_routing_test.dart \
  test/prepared_text_checkpoint_test.dart

dart run lib/main_prepared_text_checkpoint.dart \
  --flutter /path/to/flutter/bin/flutter \
  --study routing \
  --output build/profile/automatic-routing-native.json
```

The routing study exports a correctness report, not a timing benchmark. The
headless report is `build/profile/automatic-routing-debug.json`. The native
integration report includes host/SDK metadata and is recorded in profile mode.
