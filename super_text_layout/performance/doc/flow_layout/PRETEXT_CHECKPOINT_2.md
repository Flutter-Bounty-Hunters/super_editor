# Checkpoint 2: ordinary segment joins

The harness now implements [checkpoint 3](PRETEXT_CHECKPOINT_3.md). This report
and its raw measurements preserve the checkpoint-2 model.

This continues [checkpoint 1](PRETEXT_CHECKPOINT.md). Production layout remains
unchanged. The experiment now prepares a correction for each adjacent segment
pair, using Flutter measurements with the same style as the exact reference:

```text
joinCorrection(A, B) = width(A + B) - width(A) - width(B)
rangeWidth = sum(segmentWidths) + sum(internalJoinCorrections)
```

Only joins *inside* the selected range contribute. A join across a line break is
not charged. Prefix sums make looking up the correction inexpensive and require
no text measurement during fitting. Preparation adds at most one pair measurement
per adjacent pair (identical measured strings reuse the local preparation cache).

This checkpoint applies the correction only when both endpoints lie on ordinary
segment boundaries. Partial-word ranges deliberately retain checkpoint 1's
standalone-grapheme model. Their remaining inaccuracies are separate work.
This is a measurement-model experiment, not an implementation of all Pretext rules.

## Result

**All 26,714 ordinary-aligned ranges matched exact Flutter widths, with zero
observed width error**, across both bundled fonts and all five fixtures.
This includes the Roboto `light. The ` example that failed in checkpoint 1.

The same 520 full-layout plans were checked; the recorded plan names and widths
were compared against the prior artifact and matched exactly. Width-error cases
fell from 211 to 139, and break-error cases from 114 to 106. All remaining reported
width-error examples have an emergency boundary. The ordinary-range audit covers
all ordinary-aligned ranges in the fixtures, including unselected candidates.

| Roboto fixture | Break errors: before → after | Width errors: before → after |
| --- | ---: | ---: |
| nonrepeating_prose | 1 → 1 | 5 → 2 |
| kerning | 21 → 13 | 91 → 22 |
| ligatures | 17 → 17 | 21 → 21 |
| spaces | 0 → 0 | 0 → 0 |
| emergency | 75 → 75 | 94 → 94 |

Fira Mono continues to match every layout plan. Roboto nonrepeating prose now
matches both breaks and widths at 160 pixels, 320 pixels, and the changing-width
plan. Its 40/80-pixel cases still expose partial-word measurement errors.
These counts include adversarial threshold probes, not a real-world error rate.

### Preparation cost and repeated fitting

Native profile medians, 1,000-character Roboto, three samples after three warmups:

| Operation | Checkpoint 1 | Checkpoint 2 |
| --- | ---: | ---: |
| Preparation | 1.239 ms | 2.975 ms |
| Prepared fitting at width 320 | 0.098 ms | 0.108 ms |

Preparation is more expensive because it measures neighboring segments together.
Repeated fitting remains measurement-free. These preliminary timings are neither
full-widget timings nor a performance-regression gate. The model is still not
correct for all line breaks, so it is not ready for production.

The native integration test passed its ordinary-range correctness assertions;
four comparison tests passed and analysis is clean.
[Raw results and environment](../../benchmark_results/prepared-text-checkpoint-2-2026-10-27.json).

## Next checkpoint

Replace standalone-grapheme sums for emergency breaks with contextual word
measurements. Test both cutting a word at the end of a line and resuming inside
that word on the next line; prefix differences alone are not assumed sufficient.
Keep these ordinary-range audits and the original threshold probes as regression
checks. No change to the widget protocol is indicated by these findings.

## Validation

In addition to the original fixed/changing widths and threshold probes, the
harness now checks **every ordinary-aligned range** in every fixture: each possible
ordinary start against each later ordinary end. This covers long ranges with many
joins and different line starts, not just the final selected lines. Each is
compared with the existing exact Flutter range measurement at 0.01-pixel tolerance.
The test and native integration run require zero ordinary-range audit failures.

The 520 original layout plans are retained exactly, including threshold widths
from checkpoint 1's model. That avoids making the comparison easier by moving
probe widths after correcting the model. The full layout report still records
known emergency-breaking failures rather than hiding them with a fallback.

Four comparison tests pass: reference agreement at fixed widths, reference
agreement with changing widths, all ordinary-aligned ranges, and full-matrix
reporting. The scope remains 20-pixel Roboto and Fira Mono, five text fixtures,
LTR, one style per source, and no hard breaks. Passing these tests does not prove
that arbitrary fonts/scripts have only pairwise context; broader shaping context
may require a richer representation. No production promotion is implied.

## Reproduce

From `performance`:

```sh
flutter test --no-pub test/prepared_text_checkpoint_test.dart

dart run lib/main_prepared_text_checkpoint.dart \
  --flutter /path/to/flutter/bin/flutter \
  --output build/profile/prepared-text-checkpoint-2.json
```

The default uses three warmups and three samples. Timing scope is unchanged:
fresh preparation, numeric fitting, and uncached exact reference fitting are
reported separately. Layout timings exclude rendering and interaction geometry.
The ordinary-range audit and extra preparation of the old model for probe widths
are accuracy-only work outside the timers.
