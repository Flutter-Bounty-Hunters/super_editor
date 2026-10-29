# Native profile measurement — 2026-10-25

For the current four-fixture suite and subsequent changes, see
[sequential optimization measurements](SEQUENTIAL_OPTIMIZATIONS.md). Measurements
below describe the earlier implementation and fixtures.

Measured on an **Apple M4, arm64, macOS 26.4**, using **Flutter 3.47.7 / Dart
3.13.5**, native macOS **profile mode (AOT)**, Impeller/Metal. These measurements
are from the desktop app, not the web demo or widget-test runner.

Each scenario has five warm-up cycles followed by **30 samples per operation**.
Every cycle mounts a fresh paragraph at width 600, resizes that retained paragraph
to 320, and appends `changed` (seven characters) to the last text participant.
Widths are logical pixels. The bundled Roboto font is loaded before sampling.

## Complete paragraph layout

Times below include the complete `RenderFlowParagraph.performLayout` call,
including measuring child widgets, preparing content, composing lines, disposing
the previous snapshot, and committing fragments. They **exclude widget building,
painting, rasterization, and frame scheduling**.

| Scenario | Operation | Median | p95 |
| --- | --- | ---: | ---: |
| 10,000 characters + 100 boxes | Initial layout at 600 | 50.34 ms | 54.05 ms |
| Same | Resize to 320 | 66.76 ms | 70.39 ms |
| Same | Text update at 320 | 66.83 ms | 71.61 ms |
| 10,000 characters + 100 actual buttons | Initial layout at 600 | 42.78 ms | 46.64 ms |
| Same | Resize to 320 | 59.40 ms | 65.59 ms |
| Same | Text update at 320 | 57.94 ms | 62.02 ms |

The boxes scenario matches the existing debug test: 20 px text, 30×25 boxes,
no obstacle. The buttons scenario follows the interactive demo: 18 px text,
stateful `OutlinedButton`s, and the rectangular obstacle. Their text and geometry
differ, so comparing these rows does not isolate the overhead of a button.
Button state survives resize and update within each cycle.

First observed initial layouts were 58.63 ms for boxes and 44.72 ms for buttons.
These are not isolated process-cold measurements: fonts were already loaded, and
the buttons scenario followed the boxes scenario in the same process.

## Interpretation

Profile mode improves on the earlier debug-test timings, but this stress case
still exceeds the **16.67 ms total frame budget at 60 Hz**, before any painting or
raster work. These are paragraph-layout costs, not measured frame times or FPS.
They do not establish performance on phones, in browsers, or for typical shorter
paragraphs.

Each sampled stress layout recorded **100 line-height retries**. That is a useful
next profiling target, together with repeated candidate shaping and whole-
paragraph recomposition for a change in the final participant. The retry count
alone does not establish how much time each mechanism consumes.

The raw artifact includes every sample, first-observed values, internal
composition timings, and exact Flutter/engine metadata:
[macos-m4-profile-2026-10-25.json](../../benchmark_results/macos-m4-profile-2026-10-25.json).
The internal composition timer omits snapshot disposal and fragment commits;
the primary `fullLayoutUs` results above include both. Percentiles use the nearest
rank; medians average the two center samples.

## Repeat the measurement

The runner now uses the shared workload through a profile-mode integration test.
See [PROFILE_TESTING.md](PROFILE_TESTING.md) for baseline recording and regression
gates. The numbers above came from the earlier standalone harness; keep new
integration-test baselines separate when making automated comparisons.

From this directory, with Flutter on PATH:

```sh
dart run lib/main_profile_macos.dart
```

Or provide the SDK executable:

```sh
dart run lib/main_profile_macos.dart --flutter /path/to/flutter/bin/flutter
```

The runner creates and cleans up a disposable native Flutter host. It does not
add macOS platform scaffolding to this package. It saves JSON and a run log in
`build/profile/`, then stops the native app. Use `--samples` or `--output` to
change the sample count or output location. Initial builds need Xcode and the
usual Flutter macOS artifacts.

The benchmark entry point is [profile_benchmark.dart](../../lib/benchmarks/profile_benchmark.dart).
It refuses debug/release mode, checks that each operation produces exactly one
fresh paragraph layout at the requested width, and runs without changing the
interactive demo. The same entry point can be used on other Flutter targets,
but those targets require separate measurement and reporting.

For sampled CPU attribution and the resulting optimization priorities, see
[PROFILE_HOTSPOTS.md](PROFILE_HOTSPOTS.md).

The [subsequent optimization report](PROFILE_OPTIMIZATIONS.md) compares this
baseline with width-first metric queries and reuse after height rechecks.
