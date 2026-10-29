# Checkpoint 3: emergency breaks and resumed words

The current harness also implements [checkpoint 4](PRETEXT_CHECKPOINT_4.md).
This report and its raw data preserve the exact-table experiment.

This continues [checkpoint 2](PRETEXT_CHECKPOINT_2.md). The experiment remains
isolated from production layout. Its purpose is to establish a correctness
baseline for partial words and measure the cost of preparing the needed data.

## Result

**All 520 original layout plans now match both exact break positions and widths
within the 0.01-pixel tolerance.** The plan names and width lists were compared
against checkpoint 2 and match exactly. There are no remaining errors in this
matrix, including emergency splits and lines resuming inside words.

The 26,714 ordinary-range comparisons still pass. The additional short-fixture
test passes for every legal start/end pair in both fonts, including ranges whose
two ends are inside words. Five comparison tests and the native integration test
passed; analysis is clean. These are fixture-scoped results, not a proof for
arbitrary shaping behavior.

### Preliminary profile cost

Medians of three samples after three warmups, 1,000-character prose:

| Font | Preparation, checkpoint 2 | Preparation, checkpoint 3 | Fitting at 320, checkpoint 3 |
| --- | ---: | ---: | ---: |
| Roboto | 2.975 ms | 44.447 ms | 0.206 ms |
| Fira Mono | 2.709 ms | 46.109 ms | 0.377 ms |

For each font, that paragraph retains 4,262 fragment entries and 5,592 pair entries:
**9,854 total**, built using 3,458 distinct measurement calls. The entry count is
not a heap-memory measurement; maps and their keys add overhead beyond numbers.

At width 40, numeric fitting takes 8.844 ms for Roboto and 14.357 ms for Fira Mono.
The fitter still uses exhaustive numeric candidate search. Correct prepared
measurements do not by themselves make narrow-line search cheap.

These timings exclude rendering and interaction geometry. They establish that
correct repeated fitting is possible for this matrix without native measurement,
but **preparation is too expensive to treat this as a production solution**.
The data tables shift substantial work into preparation and have poor scaling
for long unbroken words.

[Raw profile results and environment](../../benchmark_results/prepared-text-checkpoint-3-2026-10-27.json).

## Next checkpoint

Reduce the preparation/table cost while retaining this exact representation as
a test reference. Evaluate a compact partial-word representation or bounded
preparation, with unchanged probes and all-range checks. Track preparation time,
measurement calls and retained entries together; reducing only hot-layout time
would hide the current bottleneck. Keep widgets, padded code and production
integration outside that checkpoint until this foundation is practical.

## Model

For each segment, preparation measures every nonempty grapheme-aligned substring
as text in its own right. This preserves the context of a line ending inside a
word, a line starting inside a word, and a line doing both. It does not assume
that subtracting two prefix widths gives the width of a reshaped suffix.

For each adjacent segment pair, preparation also measures every combination of
a suffix of the left segment and a prefix of the right. A line spanning exactly
two segments uses that pair measurement directly. Longer ranges combine:

- The exact leading suffix and trailing prefix widths.
- Exact joins between those partial pieces and their neighboring full segments.
- The checkpoint-2 full-segment widths and corrections for interior joins.

All of these measurements occur in preparation. Layout only reads tables and
performs arithmetic. Identical strings share measurements within a preparation.
This is not a port of Pretext's complete shaping model, and it does not establish
that arbitrary fonts/scripts can be represented using pairwise joins.

## Accuracy checks

The original 520 layout plans and their widths remain unchanged, including the
old model's threshold probes. The native integration test now requires **zero
break failures and zero width-error cases** in that matrix. It writes the report
before asserting, so failures remain inspectable.

The 26,714 ordinary-range audit remains in place. An additional test checks every
legal range in each short fixture, including cuts inside words and ranges crossing
multiple segments. Reference fitting is still checked against production at fixed
and changing widths. Five comparison tests pass, and analysis is clean.

Scope remains the same two bundled fonts, 20-pixel text, five fixtures, one style
per source, horizontal LTR, no hard breaks. These checks do not cover arbitrary
Unicode/scripts, mixed styles, padded code, widgets, selection or painting.

## Scalability limit

This is intentionally a costly reference representation. A segment with `g`
graphemes stores `g * (g + 1) / 2` fragment entries. An adjacent pair with `a` and
`b` graphemes stores `a * b` pair entries. Preparation may measure that many
unique strings; reusing measurements does not remove the retained table entries.

A very long unbroken token can therefore cause unacceptable preparation time
and memory use. Entry counts in the JSON quantify the tables, not heap bytes.
This model must not be enabled in production as-is, even if its repeated fitting
is fast. It gives us a correctness reference against which to test a compact
representation or a bounded strategy for preparing partial-word data.

## Reproduce

From `performance`:

```sh
flutter test --no-pub test/prepared_text_checkpoint_test.dart

dart run lib/main_prepared_text_checkpoint.dart \
  --flutter /path/to/flutter/bin/flutter \
  --output build/profile/prepared-text-checkpoint-3.json
```

The default native profile run has three warmups and three samples. Preparation,
numeric fitting and uncached exact fitting are timed separately. Audits and the
old model used to preserve probe widths are outside those timers. Measurements
exclude widget layout, painting, hit testing and selection/caret geometry.
