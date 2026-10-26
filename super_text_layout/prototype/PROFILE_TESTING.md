# Profile-mode performance regression test

The benchmark is now a Flutter integration test:
[integration_test/flow_profile_test.dart](integration_test/flow_profile_test.dart).
It uses the same workload and complete paragraph-layout stopwatch as the
standalone benchmark, through `runFlowProfileBenchmark`. It runs on a real native
profile build with live frames, not the headless widget-test clock.

The default suite measures both 10,000-character fixtures (100 boxes and 100
stateful buttons), with five warm-up cycles and 30 samples each for initial
layout at width 600, resize to 320, and a seven-character update. The test fixes
the logical viewport at 800×600. Raw samples, median, p95, output counts, and host
metadata are exported as JSON. Widget building, painting, and rasterization are
outside the paragraph-layout stopwatch.

## Record a baseline on a benchmark machine

Requires macOS, Xcode, and Flutter (with its bundled Dart SDK) on PATH. From `prototype`:

```sh
flutter pub get
dart run tool/profile_macos.dart --output build/profile/baseline.json
```

Use `--flutter /path/to/flutter/bin/flutter` when Flutter is not on PATH. The
runner creates a disposable macOS host outside the repository, runs the actual
integration test through `flutter drive --profile`, exports results, stops the
app, and removes the temporary host. The prototype needs no checked-in native
platform scaffolding. It uses SDK-supported profile settings without custom VM
flags. `integration_test` is an SDK dev dependency of this prototype only.

Without `--baseline`, this records measurements and checks workload correctness;
it does **not** assert a performance budget. The command prints that distinction.
Run more than once on an otherwise idle machine before reviewing a baseline.

After reviewing the result, copy it to a versioned baseline location such as
`benchmark_results/<runner>-integration-v1.json`. Do not automatically replace
that reviewed file on every successful CI run: that would allow slow drift.

## Fail on regressions

```sh
dart run tool/profile_macos.dart \
  --baseline build/profile/baseline.json \
  --output build/profile/current.json
```

By default, **both median and p95 must remain within 20% of baseline** for each of
six scenario/operation combinations. The derived limits are passed into the
integration test. A regression fails that test and exits the runner nonzero.
The result JSON and detailed log remain available even when a budget fails.
Missing results and crashed/failed tests fail the command too; old output cannot
be mistaken for a successful new run.

Change the allowance explicitly if runner noise warrants it:

```sh
dart run tool/profile_macos.dart --baseline benchmark_results/my-runner.json \
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
[macos-m4-integration-v1-2026-10-25.json](benchmark_results/macos-m4-integration-v1-2026-10-25.json).
It is not selected by default. Other developers should record their own baseline.

## CI

Run this as a separate performance job on a consistent benchmark machine. Keep
`flutter test` as the ordinary headless correctness suite; it contains tests of
the comparison policy but no assertions about the local machine's speed.

The CI job runs the same command with its reviewed baseline, then archives
`build/profile/*.json` and `build/profile/*.log`, including when the job fails.
For example, from a checkout root on a configured macOS performance runner:

```sh
cd super_text_layout/prototype  # Adjust to the checkout layout.
dart run tool/profile_macos.dart \
  --baseline benchmark_results/my-runner-integration-v1.json \
  --output build/profile/current.json
```

The exit code gates the job. A new CI workflow is not installed here: the
repository currently has no package-local CI configuration, and a benchmark
runner/hardware baseline must be chosen by the team. Avoid enforcing a laptop
baseline on changing shared hosted-runner hardware.

## Standard Flutter entry points

The integration test and [driver](test_driver/profile_driver.dart) can also run
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
and raw-summary validation tests run from the prototype directory with:

```sh
flutter test test/profile_baseline_test.dart test/profile_runner_test.dart
```
