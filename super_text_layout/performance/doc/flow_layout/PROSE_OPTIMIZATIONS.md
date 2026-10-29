# Prose layout follow-up — 2026-10-26

This report records fixture v3. The current v4 suite measures beginning, middle,
and end edits independently; see [EDIT_POSITION_BENCHMARK.md](EDIT_POSITION_BENCHMARK.md).
v3 baselines cannot be used with the v4 runner.


Implemented a direct plain-text measurement path and prepared candidate indexes,
measuring each independently. The fresh CPU profile showed shaping dominated the
remaining cost, so the next change reuses exact break decisions for unchanged
plain-text sources and identical constraints. It measures the selected range
anew, avoiding repeated rejected-candidate searches without retaining native
painters across layouts. This is a narrower alternative to the proposed native
shape cache and full unchanged-line reuse; those larger changes are not part of
this implementation. The exact greedy search remains the fallback.

The final confirmation run reduces the 10,000-character nonrepeating fixture's
edit layout from **64.05 ms to 8.64 ms (86.5%)**. Initial layout and resize remain
approximately unchanged. Uninterrupted prose also remains expensive.

## Expanded baseline and CPU evidence

Fixture v3 preserves all four v2 workloads and adds `long_prose`: one
**1,000-character** text source with **zero widgets**. The existing `unique_prose`
fixture still has 10,000 characters in 100 distinct sources separated by 100
boxes. The new case is deliberately smaller: the baseline already takes about
74/144/148 ms for initial/resize/update. It exposes long-run candidate-search
cost without making the default suite impractically slow. It is not a
10,000-character uninterrupted-run measurement.

The expanded baseline was measured before this round's production changes.
The native macOS profile integration harness uses the same Apple M4, macOS 26.4,
Flutter 3.47.7 / Dart 3.13.5, 800×600 viewport, five warm-up cycles, and 30 samples
per operation as the preceding report. Initial width is 600, resized width is
320, and the update appends seven characters at width 320. Full paragraph layout
includes disposal and fragment commits, but excludes widget build, paint,
rasterization, and frame scheduling. Timing runs have sampling tags disabled and
were performed without concurrent tests or analysis jobs.

A separate CPU capture of `unique_prose` covers **all 90 measured layouts**:
4,060 samples total, 3,938 inside paragraph layout, at the standard 1 ms sample
period. Inclusive stack shares overlap:

| Stack | Layout samples | Share |
| --- | ---: | ---: |
| Candidate selection | 3,781 | 96.0% |
| Exact range measurement | 3,475 | 88.2% |
| TextPainter.layout | 3,405 | 86.5% |
| Paragraph creation inside TextPainter | 1,221 | 31.0% |
| Content preparation (user tag) | 91 | 2.3% |

The [capture summary](../../benchmark_results/macos-v3-cpu-unique-before-2026-10-26.json)
retains counts and coverage. The full local capture is in the ignored
`build/profile/cpu-v3-unique-before.json`. It uses SDK-supported settings with no
custom VM flags. These samples describe the baseline, not the final distribution.

## Implemented changes

1. **Direct plain-text measurement.** A single text source without decoration
   padding bypasses chunk lists, decoration comparisons, owner sets, and compound
   wrappers. It retains the same span tree, exact shaping, hard-control ranges,
   soft hyphens, current ownership, and geometry methods. Decoration-only
   backgrounds can still paint through committed fragments.
2. **Prepared candidate indexes.** Immutable ordinary/emergency indexes provide
   windows ending at the next required break. The compositor traverses them in
   the same reverse order, without building and validating new lists per line.
   The private capability does not change the public protocol. Custom content
   still has its opportunities validated and retains nonmonotonic-width support.
3. **Retained exact break decisions.** For plain single-source text, cache the
   selected opportunity (or a complete-search non-fit) by full text, paragraph
   style, content style, start offset, available width, and maximum width. Hits
   reshape the chosen range and retain that fresh artifact for painting/queries.
   They do not reuse old placements, participants, or native resources. Region
   queries and actual widget layout still run. Text or style changes produce a
   different key; font notifications, detach, and disposal clear retention.
   Mutable Paint, compound/padded text, and arbitrary custom content bypass it.
   The LRU holds at most 1,024 decisions and 65,536 counted UTF-16 units, charging
   the full source length per decision conservatively.

## Every measured stage

Cells are **initial / resize / update median milliseconds**. Final is an
independent confirmation run of the same implementation as stage 3.

| Stage | Repeated + boxes | Repeated + buttons | Uninterrupted 1k | Nonrepeating 10k + boxes | Decorated code |
| --- | ---: | ---: | ---: | ---: | ---: |
| 0: baseline | 5.38 / 7.95 / 8.47 | 9.03 / 8.01 / 6.25 | 74.21 / 143.87 / 148.16 | 40.20 / 64.74 / 64.05 | 30.99 / 35.12 / 35.09 |
| 1: plain | 5.14 / 7.59 / 7.69 | 8.20 / 6.93 / 6.62 | 73.84 / 142.92 / 145.54 | 39.97 / 63.82 / 63.86 | 31.60 / 35.81 / 35.73 |
| 2: candidates | 4.40 / 6.80 / 6.81 | 8.74 / 5.99 / 5.67 | 74.60 / 144.91 / 148.40 | 40.01 / 63.21 / 63.25 | 32.31 / 36.36 / 36.41 |
| 3: decisions | 3.36 / 4.28 / 3.54 | 4.94 / 4.84 / 2.19 | 74.38 / 143.71 / 146.33 | 39.49 / 63.46 / 8.68 | 31.13 / 35.03 / 35.02 |
| Final confirmation | 3.55 / 4.62 / 3.92 | 5.04 / 4.85 / 2.17 | 73.80 / 142.89 / 146.12 | 39.80 / 63.01 / 8.64 | 30.91 / 34.79 / 34.63 |

## Change relative to the preceding stage

Positive is faster; negative is slower. Small 1–3% changes should be treated as
noise-sized observations from these runs rather than established speedups.

| Change | Repeated + boxes | Repeated + buttons | Uninterrupted 1k | Nonrepeating 10k + boxes | Decorated code |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1: plain | +4.5% / +4.5% / +9.2% | +9.2% / +13.4% / -5.9% | +0.5% / +0.7% / +1.8% | +0.6% / +1.4% / +0.3% | -2.0% / -2.0% / -1.8% |
| 2: candidates | +14.5% / +10.3% / +11.4% | -6.6% / +13.6% / +14.3% | -1.0% / -1.4% / -2.0% | -0.1% / +1.0% / +0.9% | -2.3% / -1.5% / -1.9% |
| 3: decisions | +23.6% / +37.1% / +48.0% | +43.5% / +19.3% / +61.4% | +0.3% / +0.8% / +1.4% | +1.3% / -0.4% / +86.3% | +3.7% / +3.6% / +3.8% |

The first two changes help the repeated controls more than unique prose. The
prose gains are too small to claim meaningful improvement. Decision reuse is the
material edit improvement: earlier sources in the 10k fixture are unchanged,
so their rejected-candidate searches can be skipped. In the uninterrupted case,
appending text changes the entire source key; its update remains a full search.

## Final confirmation against baseline

| Fixture | Operation | Baseline median | Final median | Final p95 | Reduction |
| --- | --- | ---: | ---: | ---: | ---: |
| Repeated prose + boxes | initial | 5.38 ms | 3.55 ms | 3.81 ms | 34.0% |
| Repeated prose + boxes | resize | 7.95 ms | 4.62 ms | 5.01 ms | 41.8% |
| Repeated prose + boxes | update | 8.47 ms | 3.92 ms | 4.14 ms | 53.7% |
| Repeated prose + buttons | initial | 9.03 ms | 5.04 ms | 5.28 ms | 44.2% |
| Repeated prose + buttons | resize | 8.01 ms | 4.85 ms | 5.18 ms | 39.4% |
| Repeated prose + buttons | update | 6.25 ms | 2.17 ms | 2.28 ms | 65.3% |
| Uninterrupted prose (1,000 chars) | initial | 74.21 ms | 73.80 ms | 77.07 ms | 0.6% |
| Uninterrupted prose (1,000 chars) | resize | 143.87 ms | 142.89 ms | 149.21 ms | 0.7% |
| Uninterrupted prose (1,000 chars) | update | 148.16 ms | 146.12 ms | 150.91 ms | 1.4% |
| Nonrepeating prose (10,000 chars + boxes) | initial | 40.20 ms | 39.80 ms | 42.65 ms | 1.0% |
| Nonrepeating prose (10,000 chars + boxes) | resize | 64.74 ms | 63.01 ms | 68.01 ms | 2.7% |
| Nonrepeating prose (10,000 chars + boxes) | update | 64.05 ms | 8.64 ms | 9.55 ms | 86.5% |
| Nested decorated code + boxes | initial | 30.99 ms | 30.91 ms | 32.71 ms | 0.3% |
| Nested decorated code + boxes | resize | 35.12 ms | 34.79 ms | 36.14 ms | 0.9% |
| Nested decorated code + boxes | update | 35.09 ms | 34.63 ms | 36.56 ms | 1.3% |

All 30 median/p95 budgets passed against the v3 baseline with the standard 20%
allowance. Line, fragment, and height-retry counts match the baseline in all
stages. A budget pass is a regression guard, not statistical proof of small gains.

## Correctness and remaining limits

- All **87 headless tests** pass, including the 16,672-case Unicode corpus.
- All **30 Chrome break/cache/index tests** pass.
- Library and performance project analysis and whitespace checks are clean.
- Added differential tests compare indexed choices with the public iterator
  path for hard controls, soft hyphens, CJK, Thai, emoji, negative letter spacing,
  and multiple widths. Plain and compound text agree on line/caret geometry.
- Reused choices match fresh searches after edits, width/style/obstacle changes,
  and font invalidation. Tests also exercise cached non-fits, current owner IDs,
  mutable-Paint bypass, bounded retention, disposal, and invalid custom breaks.

First layout and resize of unique text still shape many rejected candidates.
The exact reverse search is deliberately preserved: binary search or summing
word widths would require guarantees the protocol does not currently supply.
No unproven estimate skips a candidate. Full line reuse or a Flutter-assisted
alternative to exact candidate shaping remains a separate architectural change.

## Reproduction and artifacts

See [PROFILE_TESTING.md](PROFILE_TESTING.md) for the Dart runner and matching
machine checks. The default suite now has five fixtures, 15 operations, and 30
median/p95 limits. v1/v2 baselines are intentionally incompatible with v3.

```sh
# From example, on the same benchmark machine/SDK:
dart run lib/main_profile_macos.dart \
  --baseline benchmark_results/macos-v3-final-2026-10-26.json \
  --output build/profile/current.json
```

For a CPU capture, use the existing [capture instructions](PROFILE_HOTSPOTS.md),
setting `FLOW_CPU_SCENARIO=unique_prose` (now the default in profiler-wait mode).
The capture tool remains Dart and adds no package/native dependencies.

- [Stage 0: baseline](../../benchmark_results/macos-v3-step0-baseline-2026-10-26.json)
- [Stage 1: plain](../../benchmark_results/macos-v3-step1-plain-2026-10-26.json)
- [Stage 2: candidates](../../benchmark_results/macos-v3-step2-candidates-2026-10-26.json)
- [Stage 3: decisions](../../benchmark_results/macos-v3-step3-decisions-2026-10-26.json)
- [Final confirmation and enforced budgets](../../benchmark_results/macos-v3-final-2026-10-26.json)
