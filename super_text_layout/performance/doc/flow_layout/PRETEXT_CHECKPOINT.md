# Checkpoint 1: reusable text measurements

This records the original independent-segment baseline. The harness now also
implements [checkpoint 2: ordinary segment joins](PRETEXT_CHECKPOINT_2.md); the
raw checkpoint-1 results below remain unchanged.

This isolated experiment asks whether width-independent segment measurements
can reproduce our exact Flutter text fitting. It is inspired by Pretext's
prepare/layout split, not a port of Pretext's engine-specific corrections.
Production layout and widget APIs are unchanged.

## Result

**The prepare/layout split is promising, but independently measured segments and
graphemes do not preserve our current width/break behavior in proportional text.**
This is a successful diagnostic checkpoint, not a production-ready fast path.

The native profile run completed 520 fixture/font/width plans. There were 114
plans with different break positions and 211 with a predicted line-width error
greater than 0.01 logical pixels. Fira Mono passed every plan. Roboto's repeated
spaces fixture also passed every plan. Counts include intentionally adversarial
threshold probes and must not be presented as real-world error rates.

| Font | Fixture | Plans | Wrong breaks | Width errors |
| --- | --- | ---: | ---: | ---: |
| Roboto | nonrepeating_prose | 5 | 1 | 5 |
| Roboto | kerning | 91 | 21 | 91 |
| Roboto | ligatures | 75 | 17 | 21 |
| Roboto | spaces | 47 | 0 | 0 |
| Roboto | emergency | 97 | 75 | 94 |
| Mono | nonrepeating_prose | 5 | 0 | 0 |
| Mono | kerning | 50 | 0 | 0 |
| Mono | ligatures | 50 | 0 | 0 |
| Mono | spaces | 50 | 0 | 0 |
| Mono | emergency | 50 | 0 | 0 |

Concrete Roboto findings at 20 pixels:

- **Between complete segments:** `light. The ` was predicted as 87.1875 pixels,
  but exact shaping gave 86.796875. Neither endpoint was an emergency break.
  The missing information is shaping context across segment boundaries, including
  spaces; treating each whole segment as an independent width loses that context.
- **Inside a word:** `AVA` was predicted as 38.818359 pixels from standalone
  graphemes, but exact shaping gave 37.236328. `offi` similarly measured 30.146484
  versus 28.476563. Partial words need contextual advances/measurements that retain
  kerning and ligature effects, plus information about the new line's boundaries.
- **Matching breaks do not imply matching geometry:** the 1,000-character Roboto
  prose matched breaks at widths 80, 160, 320 and the changing-width plan, but had
  width errors in all five primary plans. At width 40 its breaks also differed.

### Preliminary native profile timings

For the 1,000-character Roboto fixture (median of three samples after three warmups):

| Operation | Time |
| --- | ---: |
| Prepare measurements and break data | 1.239 ms |
| Prepared fitting at width 320 | 0.098 ms |
| Prepared fitting at width 160 | 0.302 ms |
| Prepared fitting with changing widths | 0.290 ms |
| Prepared fitting at width 40 | 5.769 ms |
| Uncached exact fitting at width 320 | 149.982 ms |

The model still exhaustively searches numeric candidates; narrow emergency-heavy
layout is consequently much slower than ordinary numeric fitting. These numbers
do not establish correctness, full-frame performance, or production speedups.
Preparing plus fitting at width 320 is about 1.34 ms, but the resulting widths are
not fully correct. The recorded native integration run passed. Three comparison
tests validate the oracle and the expected mixture of passing/failing cases.

### Next checkpoint

Keep the same harness and first add **boundary-aware measurements for ordinary
segment joins**. Require the Roboto ordinary-wrap width errors to disappear,
including threshold probes, before moving on to contextual emergency-word fitting.
Prefix widths alone are not assumed sufficient for a line starting inside a word;
that is a separate boundary condition to measure and test.

[Raw native results and environment](../../benchmark_results/prepared-text-checkpoint-2026-10-27.json).

## Method

The harness uses the existing public `FlowPreparedContent` break analysis and
exact `measureRange` as its reference. Preparation measures each span between
ordinary breaks in Flutter. It additionally measures standalone graphemes for
possible emergency breaks. A local cache shares identical measured strings
within one preparation; each preparation starts with a fresh cache.

The model adds whole-segment widths when a line contains a complete segment.
For partial segments it adds the standalone grapheme advances. It preserves
spaces; it does not adopt browser trailing-space hanging semantics. Both fitters
search the same candidate sets exhaustively, ordinary before emergency, including
the maximum-paragraph-width rule. This isolates measurement reuse from search
heuristics. It is not yet Pretext's efficient sequential line walker.

Fixed widths are 40, 80, 160 and 320 logical pixels. A changing-width plan repeats
60, 180, 90 and 240. Short fixtures also probe widths 0.02 pixels above and below
exact and estimated prefix widths (at least 24 pixels). Those deliberately
adversarial probes are not a real-world error-rate sample.

Fixtures cover 1,000-character nonrepeating prose, kerning pairs, ligature-heavy
words, repeated/leading/trailing spaces, and overlong words requiring emergency
breaks. All use 20-pixel text, with bundled Roboto and Fira Mono. Findings cover
these fonts and fixtures only, not arbitrary fonts, scripts or rendering implementations.

## Correctness checks

The report records complete exact/predicted line ranges, width errors and the
first three mismatching ranges per plan. Predicted ranges are measured exactly
outside the timer, so wrong widths are detected even when breaks match.
No fallback repairs the model's failures. Tests check the reference against actual
production fragment ranges at fixed and changing widths and require both passing
and failing measurement cases. A region with no fit advances to its next row.

## Timing scope

The native integration run uses profile mode, three warmups and three samples (preliminary timings).
Preparation includes break analysis and fresh text measurements. Prepared layout
runs in batches of 100 with no Flutter measurement; the reported duration divides
by 100. Exact fitting uses the uncached public range-measurement path.

These are fitting-only measurements, excluding widget layout, fragment commits,
painting, hit testing, caret and selection geometry. They are **not comparable to
our previous full-paragraph benchmarks**. Font/engine caches are warm; preparation
is not a process-cold startup measurement. Accuracy probes are outside timing.

## Reproduce

From `performance`, with Flutter and its Dart SDK on PATH:

```sh
flutter test --no-pub test/prepared_text_checkpoint_test.dart

dart run lib/main_prepared_text_checkpoint.dart \
  --flutter /path/to/flutter/bin/flutter \
  --output build/profile/prepared-text-checkpoint.json
```

The Dart runner creates and removes a disposable macOS host, exports native
integration-test results and SDK/OS metadata, and leaves a log beside the JSON.
Use `--samples 20` for a longer timing run; the exact reference at narrow widths
is expensive and may need a longer integration/driver timeout. The initial
20-sample attempt was stopped before completion; no timings from it are reported.

Known measurement-model mismatches are findings, not integration-test failures;
missing output, test errors or crashes fail the run. No timing budget is asserted.

Implementation: [prepared model and exact fitter](../../lib/checkpoints/prepared_text.dart),
[fixtures and report](../../lib/checkpoints/prepared_text_benchmark.dart),
[comparison tests](../../test/prepared_text_checkpoint_test.dart).
