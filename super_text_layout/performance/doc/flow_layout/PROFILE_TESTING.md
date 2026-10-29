# Profile-mode performance regression test

The benchmark is now a Flutter integration test:
[integration_test/flow_profile_test.dart](../../integration_test/flow_profile_test.dart).
It uses the same workload and complete paragraph-layout stopwatch as the
standalone benchmark, through `runFlowProfileBenchmark`. It runs on a real native
profile build with live frames, not the headless widget-test clock.

Fixture version 4 measures five workloads: the four v2 10,000-character fixtures
(repeated prose with boxes, repeated prose with stateful buttons, nonrepeating
prose with boxes, and nested decorated code with boxes), plus one uninterrupted
1,000-character prose source with no widgets. The 10,000-character sources are
still separated by 100 widgets; code additionally has 200 nested decorations.
Inputs and metadata live in [profile_fixture_data.dart](../../lib/fixtures/profile_fixture_data.dart).
Each fixture gets five warm-up cycles and 30 samples for initial layout at
width 600, resize to 320, and seven-character insertions at the beginning,
middle, and end. Each edit independently starts with a fresh paragraph laid out
at 600 and then resized to 320; no case inherits another edit's cache entries.
The middle insertion is inside the central source (offset 50 in source 50 for
100-source fixtures, offset 500 for the uninterrupted source). Nested code edits
preserve the original styled segments. The test fixes
the logical viewport at 800×600. Raw samples, median, p95, output counts, and host
metadata are exported as JSON. Widget building, painting, and rasterization are
outside the paragraph-layout stopwatch.

## Record a baseline on a benchmark machine

Requires macOS, Xcode, and Flutter (with its bundled Dart SDK) on PATH. From `performance`:

```sh
flutter pub get
dart run lib/main_profile_macos.dart --output build/profile/baseline.json
```

Use `--flutter /path/to/flutter/bin/flutter` when Flutter is not on PATH. The
runner creates a disposable macOS host outside the repository, runs the actual
integration test through `flutter drive --profile`, exports results, stops the
app, and removes the temporary host. The existing example app's native runner is
not modified by the benchmark tool. It uses SDK-supported profile settings without
custom VM flags. `integration_test` is a dev dependency of the example app.

Without `--baseline`, this records measurements and checks workload correctness;
it does **not** assert a performance budget. The command prints that distinction.
Run more than once on an otherwise idle machine before reviewing a baseline.

After reviewing the result, copy it to a versioned baseline location such as
`benchmark_results/<runner>-integration-v4.json`. Do not automatically replace
that reviewed file on every successful CI run: that would allow slow drift.

## Automatic fitting and diagnostic reference

Normal benchmark runs use automatic fitting, just like an application using
`FlowParagraph`. No widget property is required. `--text-fitting exhaustive`
selects a diagnostic reference build for comparisons; it is not an application
configuration requirement. The runner sets the internal
`FLOW_BENCHMARK_VALIDATED_HINTS` define only for the separate
`--text-fitting validated-hints` experiment. Normal automatic builds now use the integrated compact prefilter; exhaustive
reference builds disable it with `FLOW_BENCHMARK_EXHAUSTIVE`.

Results record `automatic` or `exhaustive`, plus a `fittingImplementation`
identifier (`compact-intrinsic-v1`, `compact-intrinsic-linear-v1`, or `exhaustive-v1`), and the runner rejects incompatible
baselines. Older results without the field mean exhaustive. Older automatic results without the implementation identifier must be
re-recorded. Historical `flutter`
results measured the former local-correction experiment and cannot be used as
an automatic-mode baseline. Both current modes use identical fixtures and timing
scope. See [automatic fitting](../../../example/doc/flow_layout/AUTOMATIC_TEXT_FITTING.md).

`--text-fitting linear-compact` uses compact numeric rejection with sequential
candidate traversal; it is a diagnostic control for the new binary lookup. The
normal automatic policy uses ordered binary lookup where worthwhile. Existing
automatic `compact-v1`, `compact-binary-v1` and `compact-padded-v1` budgets remain
compatible with `compact-intrinsic-v1`: fixtures, timing scope and the prepared
text model are unchanged. The current sequential control also includes the
padded prefilter and records `compact-intrinsic-linear-v1`; known previous
sequential compact budgets remain compatible. Baselines from other policies still require
a matching policy, and all hardware/SDK/workload checks remain enforced.

## Fail on regressions

```sh
dart run lib/main_profile_macos.dart \
  --baseline build/profile/baseline.json \
  --output build/profile/current.json
```

By default, **both median and p95 must remain within 20% of baseline** for each of
25 scenario/operation combinations (50 median/p95 limits). The derived limits are passed into the
integration test. A regression fails that test and exits the runner nonzero.
The result JSON and detailed log remain available even when a budget fails.
Missing results and crashed/failed tests fail the command too; old output cannot
be mistaken for a successful new run.

Change the allowance explicitly if runner noise warrants it:

```sh
dart run lib/main_profile_macos.dart --baseline benchmark_results/my-runner.json \
  --max-regression-percent 10
```

Use `--samples 60` for more samples; record and compare with the same count.
The test refuses debug/release mode and CPU-profiling instrumentation during a
timing run. The current comparison is for the complete paragraph-layout metric,
not the internal composition timer or a full-frame/FPS metric.

## Matching the environment

The runner rejects baselines with different CPU models, architecture, physical
core counts, memory capacity, macOS versions, Flutter/engine/Dart revisions,
fixtures, viewport, warm-up/sample counts, or execution harness. This avoids
applying one developer's timings to an unrelated laptop. The older standalone
results in this folder are historical measurements, not integration baselines.

`--allow-sdk-change` permits a deliberate Flutter/engine/Dart comparison while
retaining hardware/OS checks. Review and record a new baseline after an accepted
SDK or fixture change. Changes to workload, viewport, measurement scope, or
scheduling should bump the fixture version and update the baseline validator.
Keep power settings, thermal conditions, display/accessibility settings, and
background load consistent; matching metadata alone cannot eliminate noise.

An example from this Mac is included in
[macos-v4-width-cache-final-2026-10-26.json](../../benchmark_results/macos-v4-width-cache-final-2026-10-26.json).
It is not selected by default. Other developers should record their own baseline.
Versions 1–3 are historical and are rejected by the v4 comparison gate.
See [long-run optimization results](LONG_RUN_OPTIMIZATION.md) for the current
implementation and [edit-position measurements](EDIT_POSITION_BENCHMARK.md) for
the preceding baseline. Both use v4; the newer baseline protects the new gains. The preceding CPU capture and
optimizations are in [PROSE_OPTIMIZATIONS.md](PROSE_OPTIMIZATIONS.md). Earlier
results remain in [sequential measurements](SEQUENTIAL_OPTIMIZATIONS.md).

## CI

Run this as a separate performance job on a consistent benchmark machine. Keep
`flutter test` at the package root as the ordinary engine correctness suite.
Run `flutter test` in `example/` for UI, exploratory studies, and comparison-policy
tests. Neither suite asserts the local machine's speed.

The CI job runs the same command with its reviewed baseline, then archives
`build/profile/*.json` and `build/profile/*.log`, including when the job fails.
For example, from a checkout root on a configured macOS performance runner:

```sh
cd super_text_layout/performance project  # Adjust to the checkout layout.
dart run lib/main_profile_macos.dart \
  --baseline benchmark_results/my-runner-integration-v4.json \
  --output build/profile/current.json
```

The exit code gates the job. A new CI workflow is not installed here: the
repository currently has no package-local CI configuration, and a benchmark
runner/hardware baseline must be chosen by the team. Avoid enforcing a laptop
baseline on changing shared hosted-runner hardware.

## Standard Flutter entry points

The integration test and [driver](../../test_driver/profile_driver.dart) can also run
in a native Flutter host directly:

```sh
flutter drive --profile -d macos \
  --driver=test_driver/profile_driver.dart \
  --target=integration_test/flow_profile_test.dart \
  --dart-define=INTEGRATION_TEST_SHOULD_REPORT_RESULTS_TO_NATIVE=false
```

The disposable host adds the package dependency and bundled-font asset define.
The Dart runner handles those details automatically, attaches compatible host
metadata, and derives `FLOW_BENCHMARK_BUDGETS` when a baseline is supplied.
`FLOW_BENCHMARK_OUTPUT` controls the driver's output file. Manual driver runs
without budgets only record timings. Other native targets can host the same test
and driver, but require their own host setup, metadata, and baselines; the
convenience runner currently targets macOS.

## Verification

The real profile integration test was exercised in record-only mode, against a
matching baseline (pass), and against deliberately impossible synthetic limits
(normal test failure, nonzero exit, and samples retained). The synthetic baseline
is only a failure-path check in the ignored build directory.

Headless threshold-policy tests run with `flutter test`. Baseline compatibility
and raw-summary validation tests run from the performance project directory with:

```sh
flutter test test/profile_baseline_test.dart test/profile_runner_test.dart
```

CPU attribution and GC timeline inspection are separate from ordinary timing.
The [padded-layout profile report](PADDED_LAYOUT_HOTSPOTS.md) includes commands
for ten-cycle capture and the SDK-only Dart summary tool, which reports per-layout
CPU buckets, slow samples and layout-thread versus concurrent GC overlap.
