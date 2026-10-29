# Flow layout example

This example exercises flow-based layout exported by
`package:super_text_layout/experimental_flow.dart`. Its dedicated entrypoint is
`example/lib/main_flow_layout.dart`; the existing SuperText examples keep their
`example/lib/main.dart` entrypoint.

The flow paragraph now uses automatic compact fitting where eligible.
Select **Long prose** to exercise it in the demo. See [integration results](../../../performance/doc/flow_layout/COMPACT_INTEGRATION.md)
for full-layout timings, preserved behavior, fallbacks and validation.

From the `example/` directory:

```sh
flutter pub get
flutter run -t lib/main_flow_layout.dart -d web-server --web-hostname 127.0.0.1 --web-port 8765
```

Open <http://127.0.0.1:8765/>. Resize the paragraph, toggle the obstacle and region
outlines, drag selections, and click counters before resizing. The stress toggle
uses 10,000 text characters and 100 buttons. The measurement button reports the
current layout duration; it is not a release benchmark.

The palette is an independent canvas participant that wraps between groups of
three swatches. It uses the same range-measurement contract as text and buttons.
See [PROTOCOL.md](PROTOCOL.md) for the short implementation note and review links.

Run engine correctness tests from the package root:

```sh
flutter test test/flow_layout
```

Run demo tests from `example/` with `flutter test`. Benchmark tests and studies
run from `performance/`.

The profile benchmark is captured in a native integration test. To record a
baseline and then enforce its median/p95 limits (from `performance/`):

```sh
dart run lib/main_profile_macos.dart --output build/profile/baseline.json
dart run lib/main_profile_macos.dart --baseline build/profile/baseline.json
```

See [PROFILE_TESTING.md](../../../performance/doc/flow_layout/PROFILE_TESTING.md) for developer/CI instructions,
matching-machine checks, and result export. Current long-run optimization results are in
[LONG_RUN_OPTIMIZATION.md](../../../performance/doc/flow_layout/LONG_RUN_OPTIMIZATION.md). The preceding beginning/middle/end
measurements are in [EDIT_POSITION_BENCHMARK.md](../../../performance/doc/flow_layout/EDIT_POSITION_BENCHMARK.md). The preceding prose
optimizations are in [PROSE_OPTIMIZATIONS.md](../../../performance/doc/flow_layout/PROSE_OPTIMIZATIONS.md). The preceding five changes
are recorded in [SEQUENTIAL_OPTIMIZATIONS.md](../../../performance/doc/flow_layout/SEQUENTIAL_OPTIMIZATIONS.md).

The current layout implementation is horizontal LTR and greedy, with fixed text scaling and no
keyboard editing. The range-measurement protocol exposes fragment measurements. Text break
discovery uses pinned Unicode 16 rules with Flutter dictionary tailoring. See
[Unicode coverage and tailoring](../../../tool/unicode/README.md) for the precise scope. Basic accessibility checks do not
constitute full screen-reader validation.

See the [protocol proposal](../../../doc/design/inline_fragmentation_protocol.md) for
agreed requirements, demonstrated behavior, limitations, and the proposed next
refactor. Keep the existing blank-line layout when making selection fixes.

The prose/test font is Roboto, copied from the Flutter SDK's material fonts, with
its license in [assets/fonts/LICENSE.txt](../../assets/fonts/LICENSE.txt). Inline code
uses Fira Mono from the repository's Quill clone example, with its license in
[assets/fonts/FiraMono-OFL.txt](../../assets/fonts/FiraMono-OFL.txt). Both are bundled in
the example app; the layout library adds no font or native dependencies.

Text fitting is selected internally; applications do not set a fitting policy.
See [automatic fitting](AUTOMATIC_TEXT_FITTING.md) for the current behavior and
[the earlier experiment](../../../performance/doc/flow_layout/FLUTTER_TEXT_FITTING.md) for historical measurements.

[Pretext checkpoint 1](../../../performance/doc/flow_layout/PRETEXT_CHECKPOINT.md) compares reusable segment measurements
with exact Flutter fitting in an isolated harness, including native profile data.

[Pretext checkpoint 2](../../../performance/doc/flow_layout/PRETEXT_CHECKPOINT_2.md) adds and audits corrections for
shaping across ordinary segment boundaries, without changing production layout.

[Pretext checkpoint 3](../../../performance/doc/flow_layout/PRETEXT_CHECKPOINT_3.md) tests contextual partial-word
measurements and records their preparation/storage cost. Production is unchanged.

[Pretext checkpoint 4](../../../performance/doc/flow_layout/PRETEXT_CHECKPOINT_4.md) reduces prepared-width storage
with bounded context and records both matrix accuracy and a long-token limitation.

[Pretext checkpoint 5](../../../performance/doc/flow_layout/PRETEXT_CHECKPOINT_5.md) expands font/script coverage and
identifies negative spacing as a case needing automatic exact fallback.

[Pretext checkpoint 6](../../../performance/doc/flow_layout/PRETEXT_CHECKPOINT_6.md) exercises automatic compact/exact
routing within mixed-style text, including inherited styles and changing widths.

Prepared text also supports [automatic binary break lookup](../../../performance/doc/flow_layout/BINARY_BREAK_SEARCH.md)
for sufficiently large, ordered candidate windows; other paths retain linear search.

Prepared rejection now accounts for nested fragment padding; see
[padded-text fitting and measurements](../../../performance/doc/flow_layout/PADDED_TEXT_FITTING.md) and the
[subsequent profile and optimization](../../../performance/doc/flow_layout/PADDED_LAYOUT_HOTSPOTS.md).
