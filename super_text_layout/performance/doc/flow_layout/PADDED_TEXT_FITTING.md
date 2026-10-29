# Prepared rejection for padded text

A subsequent [profile and preparation optimization](PADDED_LAYOUT_HOTSPOTS.md)
records the current intrinsic-width path and its remaining performance failures.
The timing table below preserves this checkpoint's original measurements.

`FlowParagraph` now uses prepared text widths to reject clearly
oversized padded candidates before shaping their fragments. Applications need no
new property, protocol implementation or manual strategy choice.

## Behavior preserved

The numeric path splits text at exactly the same nonzero-padding ancestry changes
as the existing compound measurement. Each intersecting chunk contributes its
prepared text width. Padding uses the existing edge-reuse rules: both edges on a
new fragment, shared enclosing edges charged once between adjacent chunks.
Nested and asymmetric horizontal padding are supported. Vertical padding,
rounded backgrounds and all committed geometry still use the original exact
compound measurement and painting code.

Whole chunks and chunks shorter than 32 characters use cached exact numeric
widths. Longer partial chunks use the existing three-character interaction model
and exact calibration. This avoids preparing interaction tables for short edge
snippets that already have cheap, reusable exact widths. The rejection margin sums the margins of contributing chunks. A
candidate near the fit boundary or maximum-paragraph-width threshold is measured
exactly. Ranges without legal internal breaks retain exact overflow handling.
Unsupported styles, controls, non-ASCII text, empty chunks and failed calibration
retain the exact path as applicable. Custom widgets keep their original protocol.

This checkpoint deliberately keeps sequential candidate traversal for padded
sources. Binary lookup remains available for its existing unpadded scope.
Prepared values are rejection hints: public range measurements and accepted
fragments remain exact Flutter artifacts for painting, baseline placement,
carets, hit testing and external selection boxes.

Numeric caches retain text/style data only. Decorations and owners remain in the
current preparation session. Existing cache bounds, font invalidation and detach
cleanup remain in effect. Chunk analysis shares the paragraph's bounded cache.
Building prefix interactions now reuses already-read lower-order widths rather
than repeatedly querying the numeric LRU; the arithmetic and model are unchanged.

## Correctness validation

All 150 performance project tests and nine Chrome tests passed. Library and performance project
analysis reported no issues. New differential cases compare the exact reference
and automatic widget paths across nested/asymmetric padding, rounded decorations,
real inline widgets, obstacle regions, changing widths, padding changes, edits at
the beginning/middle/end, emergency breaks, overflow, empty owners and unsupported
shaping. They compare fragment and decoration bounds, baseline positions, retry
counts, carets with both affinities, hit testing and external selection boxes.

## Profile measurements

Native macOS profile mode uses the unchanged v4 fixtures, five warmups and 30
samples per operation. Times cover complete paragraph `performLayout`, excluding
widget building, painting, rasterization and scheduling. The decorated-code
fixture has 10,000 characters, 100 inline widgets and 200 nested decorations,
with an obstacle. Initial means a fresh paragraph and its caches, not a cold app.

| Operation | Before median ms | After median ms | Improvement | Before p95 ms | After p95 ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| initial | 36.334 | 37.387 | -2.9% | 41.377 | 45.505 |
| resize | 39.717 | 9.030 | 77.3% | 46.989 | 22.081 |
| edit_beginning | 42.311 | 11.041 | 73.9% | 47.499 | 18.189 |
| edit_middle | 41.123 | 10.290 | 75.0% | 49.184 | 13.831 |
| edit_end | 40.597 | 11.126 | 72.6% | 47.428 | 12.976 |

Resize and edit medians improve about 73–77%. Initial layout is about 3%
slower. These are meaningful repeated-layout gains, not a complete frame-budget
solution: initial layout remains expensive and resize p95 is still about 22 ms.
The final native run passed all 50 existing median/p95 limits at the unchanged
20% allowance. No timing allowance was widened or baseline reset to hide a failure.

All sampled line/fragment/height-retry count sets match, on identical host/SDK
metadata. Exact differential widget tests separately validate detailed geometry.

## Preparation tradeoffs and retained trials

The first trial prepared interaction models for every chunk. Its padded-code
initial median was 44.885 ms and p95 96.485 ms; the timing gate failed. Reusing
lower-order widths and sharing analysis reduced the initial median to 39.821 ms,
but p95 was still 85.207 ms and the gate failed. The final strategy uses cached
exact widths for whole/short chunks and models only for longer partial chunks.
Its initial median is 37.387 ms and p95 45.505 ms. These measurements do not
isolate the causes of individual tail spikes; do not attribute every spike to
preparation or garbage collection without a CPU/timeline capture.

All trial artifacts and their failures are retained:
[first trial](../../benchmark_results/macos-v4-padded-text-first-trial.json),
[pre-hybrid trial](../../benchmark_results/macos-v4-padded-text-pre-hybrid-trial.json).

## All fixture medians

| Fixture | Operation | Before ms | After ms |
| --- | --- | ---: | ---: |
| test_boxes | initial | 2.155 | 2.095 |
| test_boxes | resize | 3.101 | 3.035 |
| test_boxes | edit_beginning | 2.843 | 2.793 |
| test_boxes | edit_middle | 2.720 | 2.885 |
| test_boxes | edit_end | 2.557 | 2.700 |
| demo_buttons | initial | 8.825 | 5.824 |
| demo_buttons | resize | 6.015 | 5.776 |
| demo_buttons | edit_beginning | 2.791 | 2.689 |
| demo_buttons | edit_middle | 3.562 | 3.272 |
| demo_buttons | edit_end | 2.741 | 2.671 |
| long_prose | initial | 12.560 | 11.819 |
| long_prose | resize | 1.167 | 1.182 |
| long_prose | edit_beginning | 2.599 | 2.394 |
| long_prose | edit_middle | 2.657 | 2.319 |
| long_prose | edit_end | 2.602 | 2.272 |
| unique_prose | initial | 43.294 | 39.505 |
| unique_prose | resize | 12.566 | 10.442 |
| unique_prose | edit_beginning | 10.674 | 10.627 |
| unique_prose | edit_middle | 10.602 | 10.762 |
| unique_prose | edit_end | 10.607 | 10.476 |
| decorated_code | initial | 36.334 | 37.387 |
| decorated_code | resize | 39.717 | 9.030 |
| decorated_code | edit_beginning | 42.311 | 11.041 |
| decorated_code | edit_middle | 41.123 | 10.290 |
| decorated_code | edit_end | 40.597 | 11.126 |

Other workloads vary between runs; this is one before/after native comparison,
not a repeated paired statistical study. The initial pre-change run overlapped
a short headless verification near its end; final profile runs were separate
from tests. Treat small changes cautiously. The large padded repeated-layout
gains appeared in all three implementation trials.

## Reproduce

From `performance`:

```sh
dart run lib/main_profile_macos.dart \
  --baseline benchmark_results/macos-v4-padded-text-before.json \
  --output build/profile/padded-text-check.json
```

Use the same native machine/SDK as the baseline or record a new baseline for the
intended machine. The runner retains the original hardware/SDK/workload checks.
New automatic artifacts identify `compact-padded-v1`; sequential diagnostic
runs identify `compact-padded-linear-v1`. Known previous compact budgets remain
compatible to catch regressions across this optimization.

[Before](../../benchmark_results/macos-v4-padded-text-before.json),
[after](../../benchmark_results/macos-v4-padded-text-after.json),
[budget check](../../benchmark_results/macos-v4-padded-text-budget-check.json).
