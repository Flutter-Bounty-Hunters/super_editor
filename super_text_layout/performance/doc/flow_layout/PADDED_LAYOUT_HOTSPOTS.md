# Padded-layout profile and preparation changes

Padded-code model preparation dominates initial layout. Exact Flutter fragment
creation dominates resize. Binary candidate search is not the next large win for
this fixture.

## Sampled CPU evidence

The before capture uses standard macOS profile-mode VM settings, a 1,000 µs sample
period, five warm-up cycles and ten measured cycles of the unchanged decorated
code fixture. All 50 selected layout windows received CPU samples. CPU percentages
are statistical shares, not stopwatch measurements of each component. Initial
means a fresh paragraph and its caches, not a cold Flutter process.

| Before profile | Initial samples / share | Resize samples / share |
| --- | ---: | ---: |
| Numeric model construction and calibration | 148 / 49.3% | 0 / 0% |
| Other exact numeric widths | 27 / 9.0% | 1 / 1.4% |
| Numeric chunk preparation | 27 / 9.0% | 1 / 1.4% |
| Source preparation | 40 / 13.3% | 2 / 2.7% |
| Exact fragment artifacts | 35 / 11.7% | 54 / 74.0% |
| Numeric candidate searching | 4 / 1.3% | 1 / 1.4% |

These exclusive categories partition sampled layout CPU; the remaining samples
cover GC, child layout, commits and other composition. Model-preparation stacks
include 107 `TextPainter.layout` samples, including 51 paragraph-creation samples.
Those are inclusive counts inside the 148 model-preparation samples, not extra
work to add to that total.

The three slowest resizes in this capture took 12.9–14.3 ms and recorded about
3.4–4.1 ms of GC events on the layout thread. Concurrent worker GC also overlapped
these windows; it must not be added to layout-thread time. These are separate
profile samples from the ordinary timing run, whose resize p95 was 20.3 ms. The
capture does not explain every uninstrumented tail sample. The timeline ring
buffer did not retain every early window; the summaries mark coverage explicitly.

## Production changes

- Numeric-only padded chunks with one text owner use Flutter's `ui.Paragraph`
  intrinsic width directly. `TextStyle.getParagraphStyle` and `getTextStyle`
  provide the same settings used by the previous unbounded LTR `TextPainter`
  path. Immutable encoded style descriptions are reused. Each temporary paragraph
  is disposed immediately. This avoids allocating `TextPainter` state that only
  serves painting, metrics and interaction queries which numeric hints never use.
- Text-break analysis is lazy. Short numeric chunks and cached models need no
  additional Unicode analysis. This also avoids filling the paragraph's bounded
  analysis cache with otherwise unused entries.

The short-chunk threshold remains 32 characters. Larger interaction models,
calibration guards, rejection margins and cache budgets are unchanged. Mixed-owner
numeric chunks and the ordinary plain-text strategy retain `TextPainter`.
Public range measurements, accepted compound fragments, widgets, rounded
backgrounds, baselines, carets, hit testing and external selection boxes continue
to use the existing exact artifacts. There is no new application setting.

## Rejected alternatives and timing trials

A trial raised the exact-width admission threshold from 32 to 128 characters.
It reduced initial layout from 43.3 to 38.1 ms, but resize rose from 12.9 to
16.3 ms and failed the existing gate. It is not in the final implementation.
An isolated line-metric batching probe also showed omitted trailing spaces and
spacing differences; that approach was not used to populate numeric width data.

The first intrinsic-width-only trial and the subsequent lazy-analysis trial are
retained with their budget failures. These are not clean timing-suite passes.
No allowance was widened and no baseline was reset to hide those failures.

## Final native timing comparison

These are uninstrumented, full-paragraph `performLayout` times from the same
macOS host and SDK, v4 fixtures, five warm-ups and 30 samples per operation.
Building widgets, painting, rasterization and scheduling are outside this timer.
The baseline is a fresh run of the implementation at the start of this work.

| Padded code | Before median ms | After median ms | Before p95 ms | After p95 ms |
| --- | ---: | ---: | ---: | ---: |
| initial | 43.257 | 37.697 | 61.313 | 41.426 |
| resize | 12.889 | 9.053 | 20.299 | 10.264 |
| edit_beginning | 12.089 | 9.162 | 22.704 | 10.436 |
| edit_middle | 11.782 | 11.200 | 34.046 | 13.105 |
| edit_end | 12.051 | 10.803 | 18.521 | 13.514 |

Initial median improves about 13% and p95 about 32% against the fresh baseline.
Resize median improves about 30% and p95 about 49%. This is useful incremental
progress: initial layout still exceeds a 60 Hz frame budget. Earlier work measured
an initial median of 37.4 ms on this machine, so the fresh before/after change
must not be treated as a precise universal speedup. The native model and accepted
fragment shaping remain substantial costs.

All ten padded-code median/p95 checks pass at the unchanged 20% allowance.
**The complete performance gate still fails five of its 50 checks**:

- demo_buttons.initial median: 8.31 ms exceeds 7.51 ms budget.
- long_prose.resize p95: 2.05 ms exceeds 1.61 ms budget.
- long_prose.edit_beginning p95: 3.08 ms exceeds 2.91 ms budget.
- long_prose.edit_middle p95: 3.66 ms exceeds 3.02 ms budget.
- long_prose.edit_end p95: 3.63 ms exceeds 2.74 ms budget.

All fixture medians and p95s, including failed checks, are retained in the raw
artifacts. These other-fixture failures have not been proven to be either noise
or regressions; no clean whole-suite timing pass is claimed. Ordinary plain-text
numeric shaping retains its previous `TextPainter` implementation in the final
source. This comparison is not a repeated randomized statistical study.

All sampled line/fragment/height-retry count sets match between baseline and final
runs. Detailed differential tests separately check geometry and interactions.

## Follow-up CPU capture

With the same ten-cycle profile protocol, initial-layout samples fell from 300 to
234, and resize samples from 73 to 57. All 50 selected windows again received
samples. These are statistical tick counts, not exact operation timings.

Numeric chunk preparation fell from 27 initial samples to one. Model preparation
itself remained 148 versus 147 samples and now accounts for about 63% of the
smaller initial total. It remains the largest cold-paragraph cost; the intrinsic
API does not eliminate the underlying native shaping work. Exact artifacts still
account for 41/57 (about 72%) of resize samples. Candidate searching accounts for
four resize samples; extending binary search does not address the dominant work.
The remaining slower resizes again overlap layout-thread GC events. Full details,
including timeline coverage and concurrent-GC separation, are in the summaries.

## Correctness validation

All 153 performance project tests and ten Chrome tests passed. Library and performance project
analysis reported no issues. The expanded differential matrix covers proportional
and monospace fonts, font sizes, word/letter spacing, whitespace, padding,
changing widths and interaction geometry. Existing tests retain nested decoration,
widget, obstacle, overflow, editing and font/cache lifecycle coverage.
The CPU-summary tests verify owner-qualified attribution, missing coverage,
layout-thread/concurrent-GC separation and nested-event de-duplication.

## Reproduce

Ordinary timing, from `performance` on the baseline's native machine/SDK:

```sh
dart run lib/main_profile_macos.dart \
  --baseline benchmark_results/macos-v4-padded-hotspots-before-2026-10-28.json \
  --output build/profile/padded-hotspots-check.json
```

For CPU attribution, after the disposable host has been created, run from its
folder with Flutter's standard profile VM settings:

```sh
flutter run --profile -d macos --no-pub \
  --dart-define=FLOW_BENCHMARK_FONT_ASSET=packages/performance/assets/fonts/Roboto-Regular.ttf \
  --dart-define=FLOW_PROFILE_LAYOUT=true \
  --dart-define=FLOW_CPU_SCENARIO=decorated_code \
  --dart-define=FLOW_BENCHMARK_SAMPLES=10 \
  --dart-define=FLOW_BENCHMARK_WAIT_FOR_PROFILER=true \
  > /tmp/padded-cpu.log 2>&1
```

From `performance`, collect and summarize:

```sh
dart lib/main_capture_cpu_profile.dart /tmp/padded-cpu.log build/profile/padded-cpu.json
dart lib/main_summarize_cpu_profile.dart build/profile/padded-cpu.json build/profile/padded-cpu-summary.json
```

Stop the opt-in profile app after collection. No VM flags or sample-buffer limits
are changed. Ten cycles reduce ring-buffer loss; inspect the summary's coverage
rather than assuming all GC events were retained. Both tools use SDK Dart APIs.
Raw captures remain in ignored `build/profile/padded-cpu-before.json` and
`padded-cpu-after.json`; the compact summaries are retained below.

New timing artifacts use `compact-intrinsic-v1` (or
`compact-intrinsic-linear-v1` for the sequential diagnostic control). Previous
known compact budgets stay compatible; host/SDK/workload checks remain enforced.

## Artifacts

- [Before timing](../../benchmark_results/macos-v4-padded-hotspots-before-2026-10-28.json)
- [Final timing](../../benchmark_results/macos-v4-padded-hotspots-after-2026-10-28.json)
- [Final budget check](../../benchmark_results/macos-v4-padded-hotspots-budget-check-2026-10-28.json)
- [Before CPU summary](../../benchmark_results/padded-cpu-before-summary-2026-10-28.json)
- [After CPU summary](../../benchmark_results/padded-cpu-after-summary-2026-10-28.json)
- [Rejected admission trial](../../benchmark_results/macos-v4-padded-hotspots-exact-admission-trial-2026-10-28.json)
- [Intrinsic-only trial](../../benchmark_results/macos-v4-padded-hotspots-intrinsic-trial-2026-10-28.json)
- [Lazy-analysis trial](../../benchmark_results/macos-v4-padded-hotspots-lazy-trial-2026-10-28.json)
