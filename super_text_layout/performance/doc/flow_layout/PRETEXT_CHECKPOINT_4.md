# Checkpoint 4: compact prepared widths

This continues [checkpoint 3](PRETEXT_CHECKPOINT_3.md). Production layout is still
unchanged. The exact fragment/pair tables remain as a comparison implementation.
The new model removes their quadratic preparation/storage requirement.

## Result

The native profile run preserves all **520 original layout plans** and passes
all **26,714 ordinary-range comparisons**. Recorded plan names and widths were
compared with checkpoint 3 and are identical. The compact model now significantly
reduces preparation and retained table entries, while the additional long-token
diagnostic reveals an unresolved accuracy limit described below.

Medians of three samples after three warmups, 1,000-character Roboto:

| Metric | Exact tables (checkpoint 3) | Compact model (checkpoint 4) |
| --- | ---: | ---: |
| Preparation | 44.447 ms | 7.141 ms |
| Prepared fitting at width 320 | 0.206 ms | 0.152 ms |
| Preparation measurement calls | 3,458 | 530 |
| Retained numeric table entries | 9,854 | 3,000 |

Preparation time is about 84% lower in this run, with about 70% fewer numeric
entries. Fira Mono preparation is 7.070 ms and fitting at width 320 is 0.262 ms.
At width 40 the numeric exhaustive fitter still takes 6.138 ms for Roboto and
9.283 ms for Fira Mono. These preliminary values exclude widget layout, rendering
and interaction geometry, and are not production performance claims.

Six original/comparison tests passed together, followed by the added diagnostic
and storage-bound test. Analysis is clean. Native integration passed the original
accuracy contract and exported the extra stress-case failure without suppressing
or rounding it away. Production behavior remains unchanged.

[Raw native results and environment](../../benchmark_results/prepared-text-checkpoint-4-2026-10-27.json).

## Next checkpoint

Investigate the long-range discrepancy against Flutter's actual accumulation and
shaping behavior, keeping the original 0.01-pixel criterion. Also establish how
longer-context fonts/scripts can be recognized or handled before this model is
considered for production. Passing two fonts is insufficient justification for
a universal three-grapheme assumption. No automatic eligibility claim is made.

## Representation

Preparation measures substrings of up to three graphemes, across spaces and word
boundaries as well as inside words. It derives each substring's contribution
beyond what smaller substrings already account for:

```text
single(a) = width(a)
pair(a,b) = width(ab) - width(a) - width(b)
triple(a,b,c) = width(abc) - width(ab) - width(bc) + width(b)
```

A range sums its singles and its internal pair/triple contributions. Prefix sums
make those sums cheap. Contributions crossing a line boundary are excluded.
This handles the tested kerning and ligature context without storing every
possible fragment. Layout makes no Flutter measurements.

At fixed context length k, retained numeric tables grow O(k*n) with grapheme
count, and preparation requests O(k*n) bounded-length substring measurements,
with identical strings measured only once per preparation. Range lookup uses
binary searches for its grapheme endpoints and k prefix-sum differences. The
candidate fitter itself is still exhaustive numeric search.

## Correctness scope

The context-size comparison checks every legal range in the short fixtures
against checkpoint 3's exact tables. A two-grapheme model has 3,175 mismatches;
three-, four-, and six-grapheme models have none in that audit. Three was selected
for this experiment. **That is fixture evidence, not a guarantee that fonts have
no longer-context shaping.**

The 520 original layout plans, all their probe widths, and the 26,714 ordinary-range
audit remain unchanged. The native integration test still enforces zero errors
for that original matrix. The exact table implementation and direct Flutter
measurement remain the reference, not the compact representation itself.

## New stress-test failure

A separate diagnostic measures `officeAVATAR` repeated to lengths 120, 1,200,
2,400 and 4,800. It tests each whole token and short ranges near its ends.
In both the headless and native profile runs, the 4,800-character whole-token width is **48,816.40625** in
the compact model versus **48,816.1484375** in Flutter: a **0.2578125-pixel error**.
The other 11 probes match. The 0.01-pixel tolerance has not been widened.

This long-range discrepancy is unresolved; the length dependence is consistent
with numeric accumulation differences, but its cause has not been established.
The diagnostic records exact errors and checks bounded storage; it does not
pretend that every stress-case width passes. It is separate from the original
520-case matrix and is included in the exported results.

This known failure, and the unproven context-length limit for other fonts/scripts,
prevent production promotion. No developer-facing mode switch is introduced.

## Reproduce

From `performance`:

```sh
flutter test --no-pub test/prepared_text_checkpoint_test.dart

dart run lib/main_prepared_text_checkpoint.dart \
  --flutter /path/to/flutter/bin/flutter \
  --output build/profile/prepared-text-checkpoint-4.json
```

Timings use three warmups and three samples in native profile mode. Preparation,
numeric fitting and the uncached exact reference are timed separately. Audits
and stress diagnostics are excluded. This is not a widget/frame benchmark or a
performance-regression gate. Numeric table-entry counts are not heap-byte counts;
checkpoint 3 stored map entries, while this model stores prefix-sum cells.
