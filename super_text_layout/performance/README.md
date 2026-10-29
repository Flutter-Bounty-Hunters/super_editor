# Performance

A standalone, dark Flutter dashboard for the recorded `super_text_layout`
performance snapshot. All information is on one vertically scrollable screen:

- Five vertically stacked operation lines per benchmark, with titles at the left
  and Median/P95 column headers at the right. Compact 30 px lines use one shared
  scale based only on the current snapshot. Median uses a bright bar and p95 a
  muted tail. Bars and values turn yellow at 80–100% of the selected frame budget
  and red strictly above it; muted shades preserve the p95 distinction.
- A 60/120 FPS selector updates the budget, warning colors, and summary count.
  At 60 FPS, 16.67 ms boundaries are primary and intervening 8.33 ms boundaries
  are dashed. At 120 FPS, every 8.33 ms boundary is primary.
- Every failed regression check, with its current value and unchanged limit.
- Per-benchmark Show/Hide variability toggles beneath the flow description, hidden
  by default. When expanded, sample series appear below their timing meters,
  in darker areas spanning the operation through P95 columns, with run counts
  and minimum/maximum timings. Frame guides overlay these areas. Charts show
  runs in order and use individual vertical ranges; the frame grid follows the
  timing meters’ scale.
- CPU-share bars beneath timing meters. Padded-code bars show exclusive CPU
  percentages from the separate capture; hover a segment for its title, share,
  and short description. Other tests explicitly show CPU not recorded.
  CPU bars end at their timing bar’s P95. Segment proportions come from the
  separate CPU capture and are not exact per-task timings.
- Machine/SDK details and a copyable reproduction command.

Benchmark names are clickable links in the timing and regression tables.
They open a scrollable popover rendering the full live text layout, including real
inline widgets. The operation selector shows the original 600 px layout or the
320 px resize/edit states. Previews use the same fixture definitions as the
benchmark runner; they do not generate new timing measurements.

The shared fixture data and builders live in `lib/fixtures/`. Benchmark runners
and live previews import the same definitions.
The version and default benchmark geometry/colors are unchanged. Dark previews
adapt paint colors and add visible outlines to otherwise empty inline boxes.

Tables scroll horizontally on narrow windows. The FPS selector does not change recorded regression limits. Results are bundled snapshots, not measurements of this app's
current device. The existing five recorded regression failures remain visible.
The styling takes inspiration from [Supabase](https://supabase.com/).

From this directory:

```sh
flutter pub get
flutter run -d macos
```

For browser development, use `flutter run -d chrome`.
To verify the dashboard, run `flutter analyze` and `flutter test`.
Tests also write rendered desktop/mobile screenshots into `build/screenshots/`.

## Assets and provenance

The dashboard displays current measurements only; it has no historical bars,
"was" values, timing deltas, or before/after CPU counts. Archived baseline assets
are retained internally for validating the recorded checks and reproducing the
run, and remain available as source artifacts.

The app reads `assets/metrics/` via Flutter's asset bundle. These are exact copies
of the latest completed native comparison and CPU summaries recorded on
28 October 2026. Historical originals remain in `benchmark_results/`:

| App asset | Original result |
| --- | --- |
| `baseline.json` | `macos-v4-padded-hotspots-before-2026-10-28.json` |
| `current.json` | `macos-v4-padded-hotspots-after-2026-10-28.json` |
| `budget_check.json` | `macos-v4-padded-hotspots-budget-check-2026-10-28.json` |
| `cpu_baseline.json` | `padded-cpu-before-summary-2026-10-28.json` |
| `cpu_current.json` | `padded-cpu-after-summary-2026-10-28.json` |

Replace the five assets together when publishing another compatible comparison.
The app checks fixture compatibility and reconciles the recorded check failures.
No new samples or timings are fabricated by the UI. CPU percentages are sample
shares, not exact elapsed times. Initial layout uses fresh paragraph caches, not
a cold process. Layout timing excludes build, paint, rasterization and scheduling.

## Replication

The dashboard includes the complete command. From the repository root:

```sh
cd performance
dart run lib/main_profile_macos.dart \
  --baseline assets/metrics/baseline.json \
  --output build/profile/performance-check.json
```

Use the recorded native host/SDK, or record a baseline for the intended machine.
The runner preserves host/SDK/fixture checks and can fail its timing gate.
Benchmark execution, studies, CPU captures, and the results dashboard all live
in this project. Use native profile mode for timing measurements.


## Performance tests and tools

Run commands from this directory:

```sh
flutter test
# Native profile-mode timing capture (does not update dashboard assets):
dart run lib/main_profile_macos.dart --output build/profile/current.json
# Check against the recorded baseline:
dart run lib/main_profile_macos.dart --baseline assets/metrics/baseline.json
```

`lib/main.dart` opens the dashboard. `lib/main_profile.dart` runs the benchmark
app directly in profile mode. `lib/benchmarks/` contains the benchmark and budget
policy; `lib/profiling/` contains CPU-attribution and baseline helpers; `lib/checkpoints/` contains isolated measurement studies.
`integration_test/` and `test_driver/` support native captures. `lib/main_*.dart` entrypoints provide
reproducible timing runs, CPU capture, and summary generation. Timing history is
preserved in `benchmark_results/`; detailed protocols and reports are in
[profile testing](doc/flow_layout/PROFILE_TESTING.md).
