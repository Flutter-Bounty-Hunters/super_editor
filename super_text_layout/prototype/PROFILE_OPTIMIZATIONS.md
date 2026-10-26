# Candidate metrics and height reuse — 2026-10-25

The two leading changes from the [CPU profile](PROFILE_HOTSPOTS.md) are implemented
in the experimental compositor.

- The compositor validates range and width first. It asks for ascent and descent
  only after a candidate passes the width/overflow test. Selected candidates still
  require finite, nonnegative vertical metrics. Participants can compute metrics
  lazily; the protocol does not require them to do so.
- A taller line always re-queries and validates the region provider. When the
  number and exact horizontal bounds of all ordered segments are unchanged, the
  compositor retains the chosen measurement artifacts and updates placement to
  the new baseline. Available-width and maximum-width constraints are identical.
  When bounds or segment count change, it disposes those artifacts and recomposes
  using the already queried space.

Reuse lasts only for the current proposed line. It introduces no cache across
paragraph layouts and no width-monotonicity assumption. Snapshot replacement and
paragraph disposal still release committed artifacts. A failed region requery
releases the proposed artifacts before propagating the error.

## Native profile comparison

Same Apple M4/macOS/Flutter setup, fixtures, five warm-up cycles, and 30 measured
samples per operation as the [baseline report](PROFILE_BENCHMARK.md). Both runs
use ordinary native profile mode and the complete paragraph-layout timer; the
CPU-sampling instrumentation is disabled. Widget building, painting, and
rasterization are outside these measurements.

| Scenario | Operation | Baseline median | New median | New p95 | Median reduction |
| --- | --- | ---: | ---: | ---: | ---: |
| 10k characters + 100 boxes | Initial, width 600 | 50.34 ms | 24.42 ms | 26.52 ms | 51.5% |
| Same | Resize to 320 | 66.76 ms | 36.08 ms | 38.59 ms | 46.0% |
| Same | Update last text | 66.83 ms | 35.80 ms | 39.47 ms | 46.4% |
| 10k characters + 100 buttons | Initial, width 600 | 42.78 ms | 23.53 ms | 25.56 ms | 45.0% |
| Same | Resize to 320 | 59.40 ms | 34.84 ms | 36.38 ms | 41.3% |
| Same | Update last text | 57.94 ms | 31.90 ms | 32.85 ms | 44.9% |

Line, fragment, and height-requery counts match the baseline in every operation
of both fixtures. The existing `lineRetries` counter counts height rechecks even
when no candidate remeasurement is necessary; the stress fixtures still report
100, so that counter alone no longer represents 100 recompositions.

These stress-case layout times remain above a 16.67 ms frame budget, before
painting. Smaller paragraphs and other devices require their own measurements.
There is no after-change CPU-stack capture here; the earlier CPU profile describes
the baseline, not the new distribution of remaining costs.

[Raw optimized samples and host metadata](benchmark_results/macos-m4-profile-after-reuse-2026-10-25.json)
are preserved alongside the baseline. Rerun with the existing
`tool/profile_macos.dart` runner; it uses the previously successful standard profile
settings without custom VM flags.

## Regression evidence

The existing tests retain blank-line caret behavior, Unicode conformance,
nonmonotonic widths, custom content, padded widgets, and retained button state.
New regressions verify:

- Width-rejected candidates never receive vertical-metric queries from the compositor.
- Selected invalid vertical metrics are still rejected and disposed.
- Exact artifacts survive height rechecks and are disposed on snapshot replacement.
- Tall padded custom content reuses both sides of unchanged split regions.
- Changed widths and newly split regions discard stale measurements and recompose.
- A failed taller-region query disposes its proposed artifacts.
