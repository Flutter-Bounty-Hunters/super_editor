# Native CPU-profile findings — 2026-10-25

This is the baseline capture. The first two recommended changes are now
implemented; see [the optimization results](PROFILE_OPTIMIZATIONS.md).

The successful capture covers the actual-button stress scenario: 10,000 text
characters, 100 stateful buttons, the rectangular obstacle, and initial/resize/
update operations. Hardware and SDK match [the timing report](PROFILE_BENCHMARK.md).
Five cycles warmed up before collection; 30 cycles then supplied 90 layout calls.

CPU sampling used Flutter's standard profile-mode VM service at a 1,000 µs sample
period. Of 3,894 captured UI-isolate samples, 3,613 were tagged inside paragraph
layout. Every one of the 90 measured layout windows contains samples (29–48 per
call). Percentages below describe sampled CPU, not wall-clock measurements or
predicted speedups. 47 layout samples (1.3%) have truncated deep native stacks;
all layout samples retain the paragraph layout frame.

## Where layout CPU goes

These tags are exclusive and sum to 100% of layout samples:

| Layout phase | Samples | Share |
| --- | ---: | ---: |
| First line attempts | 2,037 | 56.4% |
| Attempts after line-height growth | 1,183 | 32.7% |
| Content preparation | 275 | 7.6% |
| Child-widget layout | 60 | 1.7% |
| Other paragraph work | 58 | 1.6% |

The retry tag includes evaluating candidates again and committing successful
retry placements. It does not establish that 32.7% is all removable work. Across
individual operations, retry shares were approximately 37% initial, 31% resize,
and 32% update. Each operation recorded 100 height retries.

Inside those phases, the inclusive call stacks identify the main work:

| Call stack | Share of all layout samples |
| --- | ---: |
| `_Composer._select` candidate evaluation (`choose`) | 83.3% |
| `TextPainter.layout` | 55.5% |
| `TextPainter._createParagraph` (inside layout above) | 40.2% |
| `TextPainter.computeLineMetrics` | 21.1% |
| Default Unicode break analysis | 4.3% |

These call-stack percentages overlap the phase table and each other. In
particular, paragraph construction is part of `TextPainter.layout`, and both
initial attempts and retries call the same candidate evaluator. Do not add the
tables together.

The expensive text path includes native paragraph-builder creation, style/font
setup, and native paragraph layout. Each exact text candidate currently creates
a fresh `TextPainter`; many are rejected and disposed. Although the engine may
reuse shaped data internally, the per-candidate builder/layout and metric work
still occurs. The profile supports reducing those calls before spending effort
on the Unicode analyzer or ordinary button layout.

## Recommendations from the baseline

1. **Check width before requesting vertical metrics.** In `paragraph.dart`,
   `_select.choose` validates ascent and descent before checking whether width
   fits. For built-in text, the first ascent query invokes
   `TextPainter.computeLineMetrics`, even on a candidate rejected for width.
   Keep range/width validation first; query and validate vertical metrics once
   a candidate can actually be selected. Chosen content still needs full metrics.
   The 21.1% stack share includes chosen candidates, so this is not a claim that
   all of that cost can be removed.
2. **Retain measurements when a taller line keeps the same width segments.**
   The height-growth path currently disposes every proposed piece and restarts
   selection. Query the region provider at the new height; if horizontal segment
   bounds and measurement constraints remain identical, reuse the existing
   pieces and update their baseline. Recompose when widths change around an
   obstacle. Preserve exact-range artifact ownership and disposal on every path.
   This needs focused tests for unchanged widths, changed widths, tall custom
   content, obstacle boundaries, and widget state.
3. **Then reduce remaining repeated candidate construction.** Consider bounded
   reuse within a layout, keyed by prepared source, exact range, and the complete
   measurement constraints. Arbitrary participants can depend on available width;
   width monotonicity and cross-layout cache validity cannot be assumed.

These are recommendations from the capture and source inspection. The first two were subsequently implemented and measured separately in
[PROFILE_OPTIMIZATIONS.md](PROFILE_OPTIMIZATIONS.md). Region-width invariance was not measured directly in this capture.

## Artifacts and repeatability

- [Verified summary](benchmark_results/macos-m4-cpu-summary-2026-10-25.json)
  contains counts and operation coverage.
- The complete local capture is `build/profile/cpu-native.json` (about 18 MB),
  including native/Dart stacks, sampling flags, timestamps, and benchmark samples.
  It is intentionally left in the ignored build directory.
- Opt-in `FLOW_PROFILE_LAYOUT=true` adds SDK `UserTag` attribution. Normal builds
  compile with it disabled. It changes no layout choices.
- `FLOW_BENCHMARK_WAIT_FOR_PROFILER=true` runs only the button scenario, waits
  after warm-up for the collector, and exposes sample windows through local VM
  service extensions. The ordinary benchmark remains automatic and runs both
  scenarios.

After creating the disposable host described by `tool/profile_macos.dart`, run in
that host directory:

```sh
flutter run --profile -d macos --no-pub \
  --dart-define=FLOW_BENCHMARK_FONT_ASSET=packages/flow_layout_prototype/assets/fonts/Roboto-Regular.ttf \
  --dart-define=FLOW_PROFILE_LAYOUT=true \
  --dart-define=FLOW_BENCHMARK_WAIT_FOR_PROFILER=true \
  > /tmp/flow-cpu.log 2>&1
```

In another terminal, from the prototype directory:

```sh
dart tool/capture_cpu_profile.dart /tmp/flow-cpu.log build/profile/cpu-native.json
```

Stop the Flutter run after collection. The collector uses SDK WebSocket/JSON
APIs and the VM service; it adds no package or native dependency.

A later confirmation launch attempted to change the sample-buffer duration via
`--sample_buffer_duration=30`. Flutter explicitly disallowed that VM flag and
aborted the temporary app before benchmark startup. That caused the reported
app crash. The app and collector were stopped; the failed launch contributes no
measurements to this report. The commands above use the successful launch's
standard profiler settings.


## Refreshed capture after the two optimizations

A fresh capture using the same supported profile settings covers all 90 measured
button-fixture layouts. There are 2,292 UI-isolate samples, including 2,014 inside
paragraph layout. The complete local capture is
`build/profile/cpu-after-optimizations.json`; the
[condensed summary](benchmark_results/macos-m4-cpu-after-optimizations-2026-10-25.json)
preserves operation coverage and hotspot counts. No further production changes
were made for this inspection.

| Current hotspot | Share of sampled layout CPU |
| --- | ---: |
| Candidate evaluation | 74.7% |
| TextPainter.layout | 65.4% |
| Paragraph construction, inside text layout above | 45.7% |
| Content preparation | 13.9% |
| Default Unicode analysis, inside preparation above | 8.0% |
| Text line metrics | 3.6% |

These are inclusive, overlapping stack shares. All layout samples retain the
paragraph frame; 32 (1.6%) have truncated deep native stacks.

The remaining feature-preserving candidates from code inspection are:

- Cache immutable break/grapheme analysis on width-only relayouts and unchanged
  runs. Invalidate on text and relevant segmentation-context changes; never reuse
  live participant references as cached analysis.
- Index legal/required breaks and entry offsets. Range validation currently scans
  break lists repeatedly, and range-to-span mapping walks from the first entry.
  Indexing changes lookup cost while retaining the exact break set and shaping.
- Make compound/padded text vertical metrics lazy. Its constructor still queries
  each chunk's ascent/descent even if the final candidate will fail by width.
  Add a decorated-code fixture because the button fixture does not exercise this.
- Consider a bounded cache of identical shaped text within a layout. Share the
  immutable text resource, keeping participant-local geometry separate and
  retaining resources until every committed user is finished. All shaping/paint
  inputs must match; arbitrary custom participants still use their full
  constraint-dependent protocol.
- Index snapshot fragments by participant for commit and geometry queries.
  This is a smaller current cost but avoids repeated full-fragment scans as the
  participant count grows.

Start with analysis caching and indexed lookups, then the compound-metrics path.
Shaping-resource reuse offers larger potential but requires stronger ownership
work and a diversified benchmark: current stress text repeats the same
100-character chunk 100 times, which can overstate cache benefits. Include unique
prose, a long single text run, and nested decorated code before judging it.

Incremental reuse of unaffected lines is a later architectural option for edits
near the end. It needs conservative invalidation for shared shaping/break context,
region changes, and arbitrary participant revisions. The current capture does
not measure that potential. None of these recommendations has a measured
speedup yet.
