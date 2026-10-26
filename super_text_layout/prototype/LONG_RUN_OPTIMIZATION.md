# Exact candidate-width reuse for long prose — 2026-10-26

Added a bounded cache of exact TextPainter widths for long, single-source plain
text. It targets the uninterrupted-prose bottleneck without changing the exact
reverse candidate search, legal break set, emergency policy, or custom-content
protocol. Selected candidates still obtain live shaped resources for metrics,
painting, selection, and caret queries.

## Uninterrupted 1,000-character result

The existing fixture v4 is unchanged: 1,000 characters in one source, no inline
widgets. Each edit independently mounts at width 600, resizes to 320, then
inserts seven characters at the beginning, middle, or end. Timings are full
paragraph layout, excluding widget build, paint, rasterization, and scheduling.

| Operation | Before median | After median | After p95 | Median reduction |
| --- | ---: | ---: | ---: | ---: |
| initial | 75.82 ms | 80.00 ms | 82.41 ms | -5.5% |
| resize | 146.88 ms | 112.75 ms | 115.73 ms | 23.2% |
| edit_beginning | 150.22 ms | 131.03 ms | 136.66 ms | 12.8% |
| edit_middle | 149.45 ms | 117.44 ms | 121.58 ms | 21.4% |
| edit_end | 150.56 ms | 8.29 ms | 8.75 ms | 94.5% |

The largest improvement is at the end: most previously rejected candidate strings
are unchanged, even though the whole source key changed and its break-decision
cache missed. Beginning/middle edits alter more candidate strings and therefore
retain more shaping work. First layout must populate the cache, so it has no
cross-layout reuse benefit and can incur additional overhead. The table retains
that cost rather than reporting only the faster cases.

## What is cached

- Only exact width numbers, keyed by the complete shaped TextSpan, including
  text and styles. No TextPainter, native paragraph, participant, source offset,
  placement, or whole-source break decision is stored in this cache.
- Eligibility is restricted to plain single-source runs of at least 256 UTF-16
  units. Short sources and padded/compound text keep their previous path.
  Mutable foreground/background Paint styles bypass retention.
- Cache hits return a deferred measurement with the exact saved width. Rejected
  candidates allocate no native shape. A selected candidate acquires a live
  shape when vertical metrics are requested, before commit. Debug assertions
  verify agreement with the cached width; regression tests compare full geometry
  against uncached public-iterator searches.
- Current break analysis still validates the range, including hard controls and
  soft-hyphen behavior. Visible-text normalization precedes the cache key, so
  differing rendered hyphen choices cannot alias accidentally.
- The backend's shaping configuration is fixed: LTR, one line, unconstrained
  TextPainter layout. Any future change to those inputs must update cache
  validity. Font notifications clear the cache and request layout. Detach and
  disposal clear it as well.

The per-paragraph LRU is bounded to **4,096 entries** and **2,097,152 counted
UTF-16 units** across retained candidate strings. These are retention bounds,
not a precise heap-byte limit; span/style/map objects also consume memory.
Native resources are not retained across layouts by this cache. This introduces
a real Dart-memory tradeoff for faster repeated layouts. Larger sources can
exceed the cache's working set and evict useful entries; the measurements here
do not establish 10,000-character uninterrupted-run performance.

## All fixture medians

Each cell is initial / resize / beginning / middle / end, milliseconds.

| Fixture | Before | After |
| --- | ---: | ---: |
| test_boxes | 3.30 / 4.40 / 4.11 / 4.10 / 3.62 | 3.36 / 4.42 / 3.98 / 4.15 / 3.79 |
| demo_buttons | 7.56 / 5.56 / 2.39 / 2.90 / 2.27 | 4.92 / 5.04 / 2.31 / 2.90 / 2.17 |
| long_prose | 75.82 / 146.88 / 150.22 / 149.45 / 150.56 | 80.00 / 112.75 / 131.03 / 117.44 / 8.29 |
| unique_prose | 40.94 / 65.52 / 11.27 / 9.56 / 8.71 | 41.22 / 65.80 / 11.46 / 9.60 / 8.93 |
| decorated_code | 31.63 / 35.26 / 34.94 / 35.81 / 35.54 | 31.47 / 35.12 / 35.26 / 35.34 / 35.35 |

The 10,000-character fixtures contain 100 shorter sources separated by widgets,
so they do not use this new long-source width cache. Their differences should
be read as control measurements, not attributed to this optimization.

## Measurement and verification

Same native macOS profile harness, Apple M4/macOS 26.4, Flutter 3.47.7/Dart 3.13.5,
800×600 viewport, five warm-up cycles, and 30 samples per case. CPU-sampling tags
are disabled. Native timing runs did not overlap tests or analysis jobs.
The [first trial](benchmark_results/macos-v4-width-cache-trial-2026-10-26.json)
is retained. The final pass also keeps the short-text path free of the new
shape-factory closure; the closure is needed only for deferred cache hits.

All **50 median/p95 limits passed** against the preceding v4 baseline, using
the standard 20% allowance. Line, fragment, and height-retry counts match the
baseline for every fixture/operation. Small control differences are not evidence
of a speedup; raw samples and p95 are retained for review.

- **108 headless tests pass**, including the full 16,672-case Unicode corpus.
- **47 Chrome break/cache/edit tests pass.**
- Added differential coverage for long-source edits, negative letter spacing,
  soft hyphens, combining marks/emoji/CJK, font invalidation, mutable Paint bypass,
  eviction, selection/caret geometry, disposal, and native-resource release.
- Library/prototype analysis and whitespace checks are clean.

## Artifacts and rerunning

- [Before: v4 edit-position baseline](benchmark_results/macos-v4-edit-positions-2026-10-26.json)
- [After: final samples, host metadata, and budget results](benchmark_results/macos-v4-width-cache-final-2026-10-26.json)

The fixture version remains 4 because the workload and timing scope did not
change. The older v4 baseline is still compatible, but its end-edit allowance is
too loose to protect the new gain. Once reviewed, use the newer artifact as the
matching-machine baseline; other machines should record their own.

```sh
# From prototype:
dart run tool/profile_macos.dart \
  --baseline benchmark_results/macos-v4-width-cache-final-2026-10-26.json \
  --output build/profile/current.json
```

See [PROFILE_TESTING.md](PROFILE_TESTING.md) for runner and environment details.
