# Sequential layout optimizations — 2026-10-26

This report records fixture v2. For the subsequent prose work and current v3
benchmark, see [PROSE_OPTIMIZATIONS.md](PROSE_OPTIMIZATIONS.md). Historical v2
baselines cannot be used with the current v3 runner.


All five opportunities from the source inspection are implemented, each measured
before adding the next. The expanded v2 benchmark was recorded on the previous
implementation **before any production optimization**. Existing APIs and custom
content measurement behavior remain in place.

## Workloads and method

Every fixture contains 10,000 text characters and 100 actual Flutter widgets.
The existing controls repeat one 100-character source 100 times. The new prose
fixture contains 100 distinct prose sources; the code fixture contains 100 varied
code sources in Fira Mono, each with two nested rounded decorations (200 total),
including internal padding boundaries. The prose uses Roboto. Both new fixtures
include boxes separating the sources. This does not benchmark a single
uninterrupted 10,000-character run. The button and code fixtures include an
obstacle. Fixture definitions and metadata are versioned together in
[profile_fixture_data.dart](../../lib/fixtures/profile_fixture_data.dart).

Runs use the native macOS profile integration test, Apple M4 (10 physical cores,
16 GiB), macOS 26.4, Flutter 3.47.7, and Dart 3.13.5. Each stage uses five warm-up
cycles and 30 measured samples per fixture/operation, viewport 800×600. Operations
are initial layout at width 600, resize to 320, and appending seven characters to
the final source at width 320. No CPU sampling instrumentation or custom VM flags
are enabled. Timings wrap the full paragraph layout, including previous snapshot
disposal and committing fragments. Widget build, paint, rasterization, and frame
scheduling are excluded. Timing runs were sequential, without concurrent test or
analysis jobs. Small changes around 1–3% should not be treated as established
speedups from one run per stage.

## Changes, in order

1. **Bounded immutable break analysis.** Reuse Unicode/grapheme/dictionary
   opportunities for identical text and paragraph segmentation context. Keep
   current participants separate. Per-paragraph LRU retention is limited to 256
   entries and 65,536 UTF-16 units; oversized entries bypass retention. Font
   notifications clear analysis and request layout; detaching also clears it.
2. **Indexed break and entry lookups.** Binary-search ordered offsets, use indexed
   legal and required breaks, and start span/range mapping at the relevant entry.
   Empty boundary participants and upstream carets retain their ordering.
3. **Lazy compound vertical metrics.** Compute padded chunk ascent/descent only
   when requested; width-rejected candidates avoid those queries.
4. **Bounded exact-shape reuse within one layout.** Share TextPainter glyph
   resources only for matching complete span inputs, keeping participant geometry
   separate. Reference counting preserves selected resources through eviction,
   then releases them on snapshot replacement/disposal. Failed composition
   releases unpublished resources without damaging the previous snapshot.
   Mutable Paint styles bypass sharing. Retention is limited to 256 entries and
   65,536 UTF-16 units; selected resources can outlive cache eviction.
   Admission favors repeated sources and padded compound text, avoiding candidate
   hash lookups for unique unpadded sources. Custom content remains uncached.
5. **Snapshot fragment index.** Build a participant-to-fragments map once per
   snapshot, preserving order, so participant commits and subsequent queries
   avoid repeated full scans. Returned lists remain independent copies.

## Median time at every stage

Each cell is **initial / resize / update**, milliseconds. Stage 0 is the newly
expanded baseline, rather than the older two-fixture v1 results.

| Stage | Repeated prose + boxes | Repeated prose + buttons | Nonrepeating prose + boxes | Nested decorated code + boxes |
| --- | ---: | ---: | ---: | ---: |
| 0: baseline | 24.84 / 37.12 / 36.69 | 24.46 / 35.91 / 33.64 | 39.85 / 69.83 / 69.98 | 54.57 / 74.83 / 74.11 |
| 1: analysis | 21.61 / 32.80 / 32.77 | 20.59 / 31.55 / 29.12 | 40.38 / 66.35 / 66.05 | 54.28 / 70.19 / 69.77 |
| 2: indexes | 20.68 / 30.55 / 30.88 | 19.79 / 30.56 / 27.82 | 39.96 / 64.46 / 64.62 | 53.46 / 68.63 / 68.62 |
| 3: lazy | 20.76 / 31.51 / 31.57 | 19.64 / 30.94 / 28.07 | 40.29 / 64.90 / 65.28 | 47.88 / 59.98 / 58.96 |
| 4: shapes | 5.43 / 7.92 / 8.43 | 9.87 / 8.87 / 6.83 | 39.73 / 64.13 / 63.86 | 37.12 / 42.51 / 41.90 |
| 5: fragments | 5.09 / 7.71 / 8.32 | 9.43 / 8.33 / 6.38 | 40.62 / 65.70 / 65.06 | 32.49 / 36.65 / 35.78 |

## Reduction relative to the immediately preceding stage

Positive values mean faster; negative values mean slower. Cells use the same
initial / resize / update order.

| Change | Repeated prose + boxes | Repeated prose + buttons | Nonrepeating prose + boxes | Nested decorated code + boxes |
| --- | ---: | ---: | ---: | ---: |
| 1: analysis | +13.0% / +11.6% / +10.7% | +15.8% / +12.2% / +13.4% | -1.3% / +5.0% / +5.6% | +0.5% / +6.2% / +5.9% |
| 2: indexes | +4.3% / +6.9% / +5.8% | +3.9% / +3.2% / +4.5% | +1.0% / +2.8% / +2.2% | +1.5% / +2.2% / +1.6% |
| 3: lazy | -0.4% / -3.1% / -2.2% | +0.8% / -1.3% / -0.9% | -0.8% / -0.7% / -1.0% | +10.4% / +12.6% / +14.1% |
| 4: shapes | +73.8% / +74.9% / +73.3% | +49.7% / +71.3% / +75.7% | +1.4% / +1.2% / +2.2% | +22.5% / +29.1% / +28.9% |
| 5: fragments | +6.3% / +2.6% / +1.2% | +4.5% / +6.1% / +6.5% | -2.3% / -2.5% / -1.9% | +12.5% / +13.8% / +14.6% |

Analysis caching and indexing reduced the existing controls. Lazy compound
metrics primarily helped the decorated-code workload (10–14%), while the other
fixtures showed little change or small regressions. Shape reuse produced the
largest gains for repeated text and a further 22–29% code improvement. Fragment
indexing reduced code time by another 12–15%; prose rose about 2% in that run.

The first shape-cache trial admitted every span. It made unique prose 3–5% slower
while substantially improving the other fixtures. That result is preserved as
[the initial trial](../../benchmark_results/macos-v2-step4-shapes-trial-2026-10-26.json).
The narrower admission policy was then tested and measured as final stage 4:
unique prose returned to approximately stage 3 timing. This refinement changes
cache eligibility only, retaining the full uncached rendering path.

## Final result against the expanded baseline

| Fixture | Operation | Baseline median | Final median | Final p95 | Median reduction |
| --- | --- | ---: | ---: | ---: | ---: |
| Repeated prose + boxes | initial | 24.84 ms | 5.09 ms | 5.35 ms | 79.5% |
| Repeated prose + boxes | resize | 37.12 ms | 7.71 ms | 8.30 ms | 79.2% |
| Repeated prose + boxes | update | 36.69 ms | 8.32 ms | 8.65 ms | 77.3% |
| Repeated prose + buttons | initial | 24.46 ms | 9.43 ms | 10.80 ms | 61.4% |
| Repeated prose + buttons | resize | 35.91 ms | 8.33 ms | 9.53 ms | 76.8% |
| Repeated prose + buttons | update | 33.64 ms | 6.38 ms | 8.19 ms | 81.0% |
| Nonrepeating prose + boxes | initial | 39.85 ms | 40.62 ms | 42.23 ms | -1.9% |
| Nonrepeating prose + boxes | resize | 69.83 ms | 65.70 ms | 68.79 ms | 5.9% |
| Nonrepeating prose + boxes | update | 69.98 ms | 65.06 ms | 67.49 ms | 7.0% |
| Nested decorated code + boxes | initial | 54.57 ms | 32.49 ms | 35.81 ms | 40.5% |
| Nested decorated code + boxes | resize | 74.83 ms | 36.65 ms | 40.23 ms | 51.0% |
| Nested decorated code + boxes | update | 74.11 ms | 35.78 ms | 38.91 ms | 51.7% |

The repeated-text gains should not be extrapolated to unique prose. Nonrepeating
prose initial layout remains effectively unchanged (about 2% slower here), and
resize/update improve about 6–7%. Unique prose and decorated code remain above
16.67 ms on these stress workloads, even before painting. This is neither a
full-frame benchmark nor a phone/browser performance claim.

Line, fragment, and height-requery counts match stage 0 for every operation in
every subsequent run. The final integration run also enforced stage 0's matching
machine median and p95 budgets: all 24 limits passed with the standard 20%
allowance. This budget pass is a regression guard, not proof that smaller timing
differences are statistically significant.

## Correctness and reproduction

The final headless suite passes 82 tests, including the complete 16,672-case
Unicode default line-break corpus and existing blank-line carets, arbitrary
custom content, nonmonotonic widths, changing regions, and retained widget state.
New tests cover cache invalidation/bounds, current owner mappings, indexed empty
boundaries, nested padding metrics, exact shape sharing, paint isolation,
eviction with live users, failure cleanup, cache admission, and snapshot-index
ordering/query isolation. Chrome passes all 25 break/measurement/cache tests.
Flow layout example analysis and whitespace checks are clean.

Run from `performance`:

```sh
dart run lib/main_profile_macos.dart --output build/profile/current.json
# On this same machine/SDK, compare against the final reviewed artifact:
dart run lib/main_profile_macos.dart \
  --baseline benchmark_results/macos-v2-step5-fragments-2026-10-26.json \
  --output build/profile/current.json
```

See [PROFILE_TESTING.md](PROFILE_TESTING.md) for matching-machine requirements,
baseline review, CI guidance, and explicit Flutter paths. Version 1 baselines
are deliberately incompatible with this expanded suite. Every stage retains raw
samples, p95, geometry counters, and host/SDK metadata:

- [Stage 0: baseline](../../benchmark_results/macos-v2-step0-baseline-2026-10-26.json)
- [Stage 1: analysis](../../benchmark_results/macos-v2-step1-analysis-2026-10-26.json)
- [Stage 2: indexes](../../benchmark_results/macos-v2-step2-indexes-2026-10-26.json)
- [Stage 3: lazy](../../benchmark_results/macos-v2-step3-lazy-2026-10-26.json)
- [Stage 4: shapes](../../benchmark_results/macos-v2-step4-shapes-2026-10-26.json)
- [Stage 5: fragments](../../benchmark_results/macos-v2-step5-fragments-2026-10-26.json)
