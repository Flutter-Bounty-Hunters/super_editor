# Beginning, middle, and end edit benchmarks — 2026-10-26

The next optimization keeps this v4 workload unchanged. See
[LONG_RUN_OPTIMIZATION.md](LONG_RUN_OPTIMIZATION.md) for its measured improvement.
The results below remain the before-change baseline.


The native integration benchmark now measures all three edit locations in every
fixture. Each location inserts the same seven characters, `changed`, at width
320. Every edit starts independently: mount a fresh paragraph at width 600,
resize to 320, then apply the insertion. Restoring text in-place between cases
would retain cache entries from earlier edits, so the benchmark does not use
that approach. Initial/resize summaries come from the first setup in each cycle;
the other two setups are necessary preparation and are not included as samples.

Fixture version is now **4**. The result phases are `initial`, `resize`,
`edit_beginning`, `edit_middle`, and `edit_end`; the former `update` phase is now
explicitly named `edit_end`. All five fixtures have corresponding samples,
median/p95 summaries, printed results, and regression budgets: **25 cases and
50 timing limits**. Versions 1–3 are rejected as incompatible baselines.

## Exact insertion locations

The four 10,000-character workloads have 100 sources of 100 characters, separated
by 100 inline widgets. The uninterrupted workload has one 1,000-character source.
Indices below are zero-based, and text offsets exclude widgets.

| Case | 100-source fixtures | Uninterrupted fixture |
| --- | --- | --- |
| Beginning | Source 0, offset 0; text offset 0 | Offset 0 |
| Middle | Source 50, offset 50; text offset 5,050 | Offset 500 |
| End | Source 99, offset 100; text offset 10,000 | Offset 1,000 |

The middle case intentionally inserts *inside* the central source rather than
at a source/widget boundary. In decorated code it edits the inner styled span.
Beginning and end edits belong to the first head and last tail respectively.
All original text retains its original style/decoration ownership; inserting
text does not shift the old styled-segment boundaries. Results record the
per-scenario source and offset, the inserted text, and the independent setup.

## Measurements

Native macOS profile integration test on Apple M4, macOS 26.4, Flutter 3.47.7 /
Dart 3.13.5, viewport 800×600. Five warm-up cycles and 30 samples per case, with
CPU-sampling tags disabled. Timing covers complete paragraph layout including
snapshot disposal and committing fragments, excluding widget build, paint,
rasterization, and scheduling. No concurrent tests or analysis ran during either
timing pass. No layout optimization changed in this work item.

Baseline medians in **milliseconds**:

| Fixture | Initial | Resize | Edit beginning | Edit middle | Edit end |
| --- | ---: | ---: | ---: | ---: | ---: |
| Repeated prose + 100 boxes | 3.30 | 4.40 | 4.11 | 4.10 | 3.62 |
| Repeated prose + 100 buttons | 7.56 | 5.56 | 2.39 | 2.90 | 2.27 |
| Uninterrupted prose, 1,000 chars | 75.82 | 146.88 | 150.22 | 149.45 | 150.56 |
| Nonrepeating prose + 100 boxes | 40.94 | 65.52 | 11.27 | 9.56 | 8.71 |
| Nested decorated code + 100 boxes | 31.63 | 35.26 | 34.94 | 35.81 | 35.54 |

Baseline edit p95 in **milliseconds**:

| Fixture | Beginning | Middle | End |
| --- | ---: | ---: | ---: |
| Repeated prose + 100 boxes | 4.49 | 4.51 | 4.08 |
| Repeated prose + 100 buttons | 4.30 | 4.32 | 3.92 |
| Uninterrupted prose, 1,000 chars | 155.84 | 156.17 | 156.84 |
| Nonrepeating prose + 100 boxes | 11.94 | 10.84 | 9.68 |
| Nested decorated code + 100 boxes | 37.74 | 37.76 | 37.45 |

The split nonrepeating fixture shows modestly higher beginning/middle edit cost
than end edits. All three remain much cheaper than its initial layout or resize.
The uninterrupted source must invalidate its whole-source decision keys for any
of the edits; all three remain around 150 ms. Results on these fixtures do not
establish full-frame timing or performance on other devices.

An independent confirmation pass used the baseline's default 20% median/p95
allowance. **All 50 limits passed.**

Confirmation edit medians in **milliseconds**:

| Fixture | Beginning | Middle | End |
| --- | ---: | ---: | ---: |
| Repeated prose + 100 boxes | 3.97 | 4.17 | 3.80 |
| Repeated prose + 100 buttons | 2.41 | 2.97 | 2.29 |
| Uninterrupted prose, 1,000 chars | 149.37 | 150.00 | 150.33 |
| Nonrepeating prose + 100 boxes | 11.21 | 9.48 | 8.69 |
| Nested decorated code + 100 boxes | 34.77 | 35.18 | 34.72 |

## Correctness and regression coverage

- **106 headless tests pass**, including 15 new widget cases (each of the three
  edit locations in each of the five fixtures).
- **All 15 new edit cases pass in Chrome.**
- The widget tests use the actual benchmark fixture builder. They preserve the
  warm paragraph across initial layout, resize, and edit, then compare it with
  a fresh edited paragraph. They check size, lines/regions, every fragment's
  geometry, height retries, caret location, and selection boxes for inserted text.
- Pure fixture tests verify exactly one seven-character insertion, the exact
  locations, and the head/inner/tail ownership of decorated code edits.
- Budget tests verify median and p95 failures for each edit phase. Baseline
  validation rejects missing edit samples or a different edit setup.
- Prototype analysis and whitespace checks are clean.

The Dart runner, integration test, summaries, and budget logic share one phase
catalog, so beginning/middle edits receive the same regression checks as end
edits. See [PROFILE_TESTING.md](PROFILE_TESTING.md) for matching-machine setup.

```sh
# From prototype on the matching benchmark machine/SDK:
dart run tool/profile_macos.dart \
  --baseline benchmark_results/macos-v4-edit-positions-2026-10-26.json \
  --output build/profile/current.json
```

- [Baseline raw samples and metadata](benchmark_results/macos-v4-edit-positions-2026-10-26.json)
- [Confirmation samples and timing-gate results](benchmark_results/macos-v4-edit-positions-confirmation-2026-10-26.json)
