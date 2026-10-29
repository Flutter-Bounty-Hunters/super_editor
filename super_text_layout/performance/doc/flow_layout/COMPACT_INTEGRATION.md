# Compact fitting integrated into the real paragraph

`FlowParagraph` and visible demo now use an automatic compact
prefilter for eligible text. This is the actual layout implementation, not only the
checkpoint harness. There is no caller-facing mode switch. Existing SuperText
APIs remain unchanged.

Select **Long prose** in the demo at http://127.0.0.1:8765/. Resize it, toggle the
obstacle and drag selections. The original mixed-content and button-stress
samples remain available. The demo measurement label is a debug-build composition
measurement, not the native profile metric below.

## Layout and feature preservation

The compact strategy is a private prepared-text capability that returns only a
rejection hint. The public `measureRange` protocol remains exact. Candidates that
might fit are measured by the established Flutter text measurement implementation; those exact artifacts
supply placement, painting, baselines, carets, selection boxes and hit testing.
Custom participants and real Flutter boxes keep their original paths.

The initial integration handles printable ASCII in unpadded text groups.
Negative spacing, custom features/variations and non-inheriting styles retain
exact measurement. Padding, controls, non-ASCII text and mutable Paint keep the
whole group on the established path. An immutable unsupported style within an
otherwise eligible group can route just the affected ranges to exact measurement.
Mostly repeated short runs keep their existing shape/decision-sharing path.

The model is checked against exact whole-run, ordinary-segment and neighboring
segment widths before use, with a conservative rejection margin. Indivisible
ranges retain exact overflow handling. Calibration is a practical guard, not a
universal proof for every possible custom font. Known checkpoint scope limits
remain; the tiny huge-range drift remains a nonblocking diagnostic.

Numeric caches contain no owners or native painters, are bounded, and clear on
font changes, detach and disposal. See [automatic fitting](../../../example/doc/flow_layout/AUTOMATIC_TEXT_FITTING.md)
for routing and retention details.

## Full paragraph measurements

Native macOS profile build, same v4 fixtures/viewport/SDK/hardware, five warmups
and 30 samples per operation. Medians are milliseconds for the complete
`RenderFlowParagraph.performLayout`, including child layout, snapshot disposal
and fragment commits. Build, painting, rasterization and frame scheduling are
excluded. These are no longer preparation-only checkpoint numbers.

`long_prose` is 1,000 uninterrupted characters. The other fixtures contain 10,000
characters and 100 actual widgets; decorated code adds nested padded decorations.
Each edit starts independently after fresh initial layout and resizing.

| Fixture | Operation | Exact control ms | Integrated automatic ms |
| --- | --- | ---: | ---: |
| test_boxes | initial | 3.24 | 3.32 |
| test_boxes | resize | 4.59 | 4.76 |
| test_boxes | edit_beginning | 4.11 | 4.33 |
| test_boxes | edit_middle | 4.19 | 4.44 |
| test_boxes | edit_end | 3.77 | 4.02 |
| demo_buttons | initial | 5.12 | 5.01 |
| demo_buttons | resize | 5.29 | 4.29 |
| demo_buttons | edit_beginning | 2.43 | 2.41 |
| demo_buttons | edit_middle | 3.00 | 2.95 |
| demo_buttons | edit_end | 2.31 | 2.21 |
| long_prose | initial | 79.04 | 15.55 |
| long_prose | resize | 112.25 | 1.47 |
| long_prose | edit_beginning | 130.25 | 3.60 |
| long_prose | edit_middle | 116.89 | 3.32 |
| long_prose | edit_end | 8.06 | 3.35 |
| unique_prose | initial | 40.65 | 36.99 |
| unique_prose | resize | 65.48 | 10.28 |
| unique_prose | edit_beginning | 11.34 | 8.63 |
| unique_prose | edit_middle | 9.70 | 8.41 |
| unique_prose | edit_end | 8.90 | 8.30 |
| decorated_code | initial | 32.07 | 31.05 |
| decorated_code | resize | 35.08 | 34.32 |
| decorated_code | edit_beginning | 36.35 | 35.17 |
| decorated_code | edit_middle | 36.21 | 34.86 |
| decorated_code | edit_end | 35.88 | 35.10 |

All sampled sets of line, fragment and height-retry counts match the exact control.
Detailed widget comparisons additionally verify actual fragment bounds, carets,
hit testing and externally painted selection boxes. The beginning/middle/end
benchmark edits match fresh exact layouts. Padded code still costs roughly 35 ms,
and unique prose initial layout roughly 37 ms; not every workload fits a frame
budget. Initial uninterrupted prose is near the budget before other frame work.

## Validation and timing-gate outcome

All 143 headless tests and all four focused Chrome integration checks pass. Coverage
includes actual stateful widgets, padded code, region/height retries, changing
widths, edits, external selection geometry, cache bounds, font invalidation,
detachment, resource cleanup and non-inheriting styles. The Long prose demo test
asserts that the new prefilter is used and drag selection survives resizing.
Both library and performance project analysis are clean.

Timing checks need to be distinguished from correctness tests. The native
correctness/output checks passed. Two confirmation attempts against preliminary
automatic baselines each missed one p95 limit: one repeated-button beginning-edit
limit, then a repeated-box end-edit limit (5.47 ms versus 5.22 ms). These failures
are retained, and the allowance was not widened. Medians were stable and the
corresponding p95 values were within 20% of the independently measured exact
control. This does **not** constitute a clean pass of the automatic CI timing gate.
A later final record-only run supplies the table above; it does not assert budgets.

Raw artifacts:

- [Exact control](../../benchmark_results/macos-v4-compact-integration-exact-confirmation-2026-10-27.json)
- [Final integrated measurements](../../benchmark_results/macos-v4-compact-integrated-2026-10-27.json)
- [First confirmation gate failure](../../benchmark_results/macos-v4-compact-integration-prior-gate-2026-10-27.json)
- [Second confirmation gate failure](../../benchmark_results/macos-v4-compact-integration-confirmation-gate-2026-10-27.json)
- [Initial integration trial](../../benchmark_results/macos-v4-compact-integration-initial-trial-2026-10-27.json), retained to show the preparation overhead that led to cache/admission changes.

No new timing baseline is silently promoted for CI. Automatic results carry
`fittingImplementation: compact-v1`; older automatic baselines are rejected.
Use [the existing native runner](PROFILE_TESTING.md) with automatic fitting by
default or `--text-fitting exhaustive` for the diagnostic control build.
