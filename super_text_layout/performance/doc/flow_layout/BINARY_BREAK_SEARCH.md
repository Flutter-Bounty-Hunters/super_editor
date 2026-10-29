# Binary lookup for prepared text breaks

The paragraph now has a private `furthestPotentialBreak` operation.
For sufficiently large, ordered prepared-text candidate windows it uses binary
search to trim the oversized tail before the existing exact-correction loop.
Applications use the normal `FlowParagraph`; no fitting/search property is needed.

## Scope and correctness

- A whole text group must be eligible for the existing compact model. Mixed
  unsupported styles, custom sources and padded content retain previous traversal.
- At least 32 candidates are required. Smaller windows remain linear because the
  initial profile trial showed that binary setup did not consistently pay there.
- The model checks margin-adjusted endpoint ordering once and caches the result.
  Near-flat or decreasing steps retain linear search. It does not infer ordering
  merely from nonnegative spacing or a font's name.
- With three-character interactions, endpoints at least three characters after
  a start differ from global end coordinates by a start-dependent constant. This
  permits one ordering check for all later line starts. The first two characters
  remain in the correction window rather than using that assumption.
- Indivisible ranges remain eligible for exact overflow handling. The previous
  prefilter's inspection band around maximum paragraph width is preserved in
  narrow regions. A trimmed search still inspects the first ordinary break when
  needed to decide whether emergency breaking is permitted.
- The lookup only skips candidates that the existing numeric prefilter could
  reject. It introduces no new text-width approximation. Public measurements,
  committed artifacts, painting, carets and selection geometry remain exact.

The bound is a furthest *potential* fit, not a claim that Flutter must accept it.
Exact measurements correct candidates near the fit boundary. Total paragraph
layout is not logarithmic: preparation/ordering validation remain linear in text
length, and exact shaping, widgets, commits and correction work still occur.
The binary lookup itself uses logarithmic width probes per ordered window.

## Work avoided

The focused 620-character test reflows the same source at widths 30, 80, 180 and
320 against a fresh exact reference. Across those layouts it recorded:

- 451 binary lookups.
- 3,653 binary width probes (about 8.1 per lookup).
- 65,144 sequential candidate visits skipped.

These counters are debug instrumentation, not native shape-call counts or total
work counts. They exclude ordering validation and the remaining correction loop.
The profile benchmark runs without that assertion-only instrumentation.

## Full-layout profile results

Same native macOS host/SDK, v4 fixtures, five warmups, 30 samples per operation.
Medians below are milliseconds for complete paragraph `performLayout`, excluding
build, painting, rasterization and scheduling. `long_prose` is 1,000 uninterrupted
characters; other fixtures have 10,000 characters and 100 widgets.

| Fixture | Operation | Sequential compact ms | Adaptive binary ms |
| --- | --- | ---: | ---: |
| test_boxes | initial | 3.829 | 3.184 |
| test_boxes | resize | 3.773 | 3.380 |
| test_boxes | edit_beginning | 2.740 | 2.692 |
| test_boxes | edit_middle | 2.769 | 2.743 |
| test_boxes | edit_end | 2.583 | 2.555 |
| demo_buttons | initial | 8.521 | 8.386 |
| demo_buttons | resize | 6.257 | 5.995 |
| demo_buttons | edit_beginning | 2.749 | 2.740 |
| demo_buttons | edit_middle | 3.377 | 3.420 |
| demo_buttons | edit_end | 2.771 | 3.305 |
| long_prose | initial | 11.812 | 12.504 |
| long_prose | resize | 1.306 | 1.095 |
| long_prose | edit_beginning | 2.779 | 2.594 |
| long_prose | edit_middle | 2.679 | 2.510 |
| long_prose | edit_end | 2.639 | 2.437 |
| unique_prose | initial | 41.318 | 40.904 |
| unique_prose | resize | 11.804 | 11.363 |
| unique_prose | edit_beginning | 10.194 | 10.241 |
| unique_prose | edit_middle | 10.284 | 10.191 |
| unique_prose | edit_end | 10.220 | 10.178 |
| decorated_code | initial | 36.454 | 36.641 |
| decorated_code | resize | 39.961 | 40.132 |
| decorated_code | edit_beginning | 40.800 | 40.794 |
| decorated_code | edit_middle | 40.886 | 40.815 |
| decorated_code | edit_end | 40.648 | 40.757 |

Long-prose resize improved about 16%; its edits improved about 6–8%. Initial
long-prose layout was about 6% slower, reflecting preparation/setup and run-to-run
variation; this change is not a universal speedup. Most short-source workloads
remain close to the prior traversal. Padded code is essentially unchanged because
its text measurement implementation does not yet supply prepared decoration-aware widths.

All sampled line/fragment/height-retry count sets match. The gated final native
run passed all 50 median/p95 limits against the pre-change baseline using the
existing 20% allowance. The allowance was not widened. An earlier eight-candidate
admission trial is retained; the final policy uses 32.

Raw artifacts: [before](../../benchmark_results/macos-v4-binary-search-before.json),
[after](../../benchmark_results/macos-v4-binary-search-after.json),
[budget check](../../benchmark_results/macos-v4-binary-search-budget-check.json),
[first trial](../../benchmark_results/macos-v4-binary-search-first-trial.json).

## Validation

All 148 performance project tests and seven Chrome integration tests passed. Library and
performance project analysis reported no issues. Focused coverage compares exact fragment
and caret geometry across changing widths, maximum-width inspection bands and
unordered-model fallback.

## Reproduce and baseline compatibility

From `performance`, automatic mode uses the adaptive search. For the sequential
compact control use:

```sh
dart run lib/main_profile_macos.dart --text-fitting linear-compact \
  --output build/profile/linear.json
```

Automatic output identifies `compact-binary-v1`; the control identifies
`compact-v1`. Existing automatic compact-v1 budgets remain compatible because the
width model, fixtures and metric are unchanged. Unknown model identities and
mismatched policies/hardware/SDK/workloads remain rejected. This preserves the
ability to catch regressions across this optimization without resetting budgets.

The public fragmentation protocol and widget API are unchanged. Prepared padded
widths remain the next prerequisite for applying similar fitting gains to code.
