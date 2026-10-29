> Historical experiment: the opt-in widget property and demo toggle described
> below have been removed. Validating later candidates preserved correctness but removed the speedup;
> normal layout therefore keeps cached exact search. These timings do **not**
> describe the current algorithm. See [automatic fitting](../../../example/doc/flow_layout/AUTOMATIC_TEXT_FITTING.md).

# Flutter text fitting

`FlowParagraph(textFitting: FlowTextFitting.flutter, ...)` opts into a text-only
fitting policy. The demo exposes the same choice as a filter chip. The default
remains `FlowTextFitting.exhaustive`.

## What changes

Instead of shaping every candidate from the longest remaining range downward,
the eligible text source asks Flutter's `TextPainter` for its first line boundary
at the current available width. The composer maps that hint onto our legal break
candidates, measures the candidate exactly, and corrects locally backward or
forward. The selected exact measurement still supplies painting and geometry.
Retained decisions avoid repeating this work across unchanged layouts.

This is a reduction in candidate searches, not a replacement of the fragmentation
protocol, document positions, widgets, or selection geometry.

## Feature preservation and limits

The hint is currently limited to a single text entry containing printable ASCII,
with zero decoration padding, nonnegative spacing, no custom font features or
variations, and no foreground/background Paint. Other sources use the existing
exhaustive fitting path. Custom participants always keep their existing protocol
and exhaustive selection, including nonmonotonic candidate widths.

Unicode breaks, grapheme safety, hard/blank lines, emergency breaks, nested padded
code, actual stateful widgets, changing widths and obstacles, external selection
painting, carets, hit testing, and resource ownership retain their implementations.
Switching policies clears retained break decisions.

**This is opt-in because local correction cannot prove the furthest fitting
candidate for every possible font's contextual shaping.** Even printable ASCII
can be shaped by an unusual custom font. Passing the comparisons below is evidence
for the tested cases, not a universal equivalence guarantee. Keep exhaustive mode
when that guarantee is required. No existing capability is removed from the
package; this candidate fitting mode should not become the default without resolving
that contract. It also still shapes the remaining text to obtain each hint, so
it is not a linear-time paragraph layout implementation.

## Validation

The headless suite passes 126 tests, including 30 fixture/edit comparisons
against fresh exhaustive layouts (beginning, middle, end), font invalidation,
resource cleanup, custom participant behavior, and policy switching/fallbacks.
An additional differential test compares 64 combinations of ASCII content,
widths, positive spacing, bold, and italic styles. The existing feature/break
suite also passes 43 tests with Flutter fitting enabled. These compare layout
behavior; the edit comparisons additionally check caret and selection geometry.
All seven candidate/cache comparisons also pass in Chrome. The broader Chrome
feature run was stopped after stalling in its font-loading setup, before layout;
its 43-test native run passed. The demo test verifies that switching to Flutter
fitting retains counter state and supports selection.

## Native profile results

Same v4 fixtures, five warmups and 30 samples, complete paragraph layout excluding
build/paint/raster. Values are median milliseconds. The uninterrupted `long_prose`
fixture has **1,000 characters**; the other fixtures have 10,000 characters and
100 widgets. Comparisons use the prior exhaustive width-cache baseline and the
first Flutter-mode run on the same machine. Small differences can be noise.
Padded code deliberately remains on the original path.

| Fixture | Operation | Exhaustive ms | Flutter ms | Reduction |
| --- | --- | ---: | ---: | ---: |
| test_boxes | initial | 3.36 | 3.26 | 3.0% |
| test_boxes | resize | 4.42 | 3.55 | 19.8% |
| test_boxes | edit_beginning | 3.98 | 3.58 | 10.1% |
| test_boxes | edit_middle | 4.15 | 3.43 | 17.4% |
| test_boxes | edit_end | 3.79 | 3.59 | 5.3% |
| demo_buttons | initial | 4.92 | 5.00 | -1.5% |
| demo_buttons | resize | 5.04 | 4.56 | 9.5% |
| demo_buttons | edit_beginning | 2.31 | 2.00 | 13.4% |
| demo_buttons | edit_middle | 2.90 | 2.31 | 20.3% |
| demo_buttons | edit_end | 2.17 | 2.03 | 6.5% |
| long_prose | initial | 80.00 | 2.98 | 96.3% |
| long_prose | resize | 112.75 | 4.17 | 96.3% |
| long_prose | edit_beginning | 131.03 | 6.98 | 94.7% |
| long_prose | edit_middle | 117.44 | 5.88 | 95.0% |
| long_prose | edit_end | 8.29 | 7.23 | 12.8% |
| unique_prose | initial | 41.22 | 21.67 | 47.4% |
| unique_prose | resize | 65.80 | 24.32 | 63.0% |
| unique_prose | edit_beginning | 11.46 | 9.62 | 16.1% |
| unique_prose | edit_middle | 9.60 | 9.05 | 5.7% |
| unique_prose | edit_end | 8.93 | 8.99 | -0.7% |
| decorated_code | initial | 31.47 | 31.62 | -0.5% |
| decorated_code | resize | 35.12 | 35.45 | -0.9% |
| decorated_code | edit_beginning | 35.26 | 35.64 | -1.1% |
| decorated_code | edit_middle | 35.34 | 35.85 | -1.5% |
| decorated_code | edit_end | 35.35 | 35.61 | -0.7% |

All 25 benchmark cases retain matching line, fragment, and height-retry counts.
The detailed edit comparisons check geometry, not just counts.
Nonrepeating prose initial/resize and decorated code still exceed a 16.7 ms frame
budget; the metric also excludes other frame work.

Raw results: [exhaustive baseline](../../benchmark_results/macos-v4-width-cache-final-2026-10-26.json)
and [Flutter fitting](../../benchmark_results/macos-v4-flutter-fitting-2026-10-26.json).
Use `dart run lib/main_profile_macos.dart --text-fitting flutter` to reproduce;
see [profile testing](PROFILE_TESTING.md) for baseline gating and host requirements.

A [confirmation run](../../benchmark_results/macos-v4-flutter-fitting-confirmation-2026-10-26.json)
passed all 50 median/p95 limits with the standard 20% allowance against the first
Flutter-mode run. All output counts matched again. Both analyzer checks were clean.
