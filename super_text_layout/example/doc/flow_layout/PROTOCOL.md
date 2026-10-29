# The implemented measurement seam

The API is exported by `experimental_flow.dart`.
The paragraph now uses the same operations for text, ordinary widget adapters,
and independent custom content:

```text
FlowContent.prepare(context)                         → FlowPreparedContent
FlowPreparedContent.breaksAfter(start)                → break alternatives
FlowPreparedContent.measureRange(range, constraints)  → FlowRangeMeasurement
```

The paragraph selects an alternative. It retains that exact measurement for
painting and geometry after placing it; it disposes rejected and retried results.
Candidate measurement does not publish fragments or recreate widget state.

## Inspect these files

- [measurement.dart](../../../lib/src/experimental/flow/measurement.dart): the contract
  and ordinary-box implementation.
- [flow_palette.dart](../../lib/flow_layout/flow_palette.dart): an independent implementation in
  the demo package, outside the layout library. Canvas-drawn swatches expose
  breaks between groups of three. They use no text or atomic-box entry types.
- [paragraph.dart](../../../lib/src/experimental/flow/paragraph.dart): the greedy
  composer selects and positions measured ranges without content-type checks.
- [text_backend.dart](../../../lib/src/experimental/flow/text_backend.dart): shared
  shaping across adjacent text/decorations and exact-range text measurements.

The palette can measure, for example, both `0..6` and `3..9`. Its measurement
supplies width, ascent/descent, local fragments, drawing, selection boxes, carets,
and pointer-to-location mapping. Enclosing decorations add fragment padding. Compound text measurements account
for their own padding so break analysis can span layout-changing wrappers.
An ordinary widget adapter uses the same contract, with only one legal range.

## Evidence

The existing regressions remain, including the empty line and its drag/caret
behavior, the independent palette participant, retained widget state, and exact
candidate ownership/disposal. The raw Unicode analyzer passes all 16,672 official
Unicode 16 line-break cases. Additional Flutter tests cover nonbreaking spaces,
word joiners, CJK punctuation, zero-width spaces, soft hyphens, hard controls,
Thai dictionary boundaries, grapheme safety, and break context across both
zero-padding and padded inline wrappers. Candidate-search regressions cover
nonmonotonic widths, skipping irrelevant shorter candidates, ordinary-break
priority, emergency eligibility in a line remainder, and artifact disposal.

Run engine correctness tests from the package root:

```sh
flutter test test/flow_layout
```

See [Unicode data and tailoring](../../../tool/unicode/README.md) for pinned inputs,
licenses, regeneration instructions, and the distinction between default Unicode
conformance and the integrated wrapping policy.

## Limits of this step

- Break discovery implements pinned Unicode 16 default rules, with grapheme
  filtering, emergency wrapping, and Flutter word-boundary tailoring for SA text.
  Dictionary quality depends on the Flutter engine. Arbitrary non-text/custom
  sources remain separate protocol sources, without Unicode context across them.
- The current newline/blank-line layout is preserved deliberately, including its
  empty line consuming a hard control. It is not conventional newline rendering.
- Candidate selection tries ordinary breaks from the furthest offset backwards
  and stops at the first fit. Only when none fit does it consider emergency
  alternatives, subject to the first ordinary range exceeding full paragraph
  width. This preserves greedy behavior without a monotonic-width assumption.
  Rejected artifacts are disposed immediately; chosen artifacts are retained.
  Immutable text metrics are computed once per exact-range painter.
- In a same-session debug comparison, the 10,000-character/100-box fixture went
  from approximately 165/104/98 ms (initial/resize/update) to 113/86/80 ms.
  These are widget-test samples, not release benchmarks or frame-budget claims.
  A native macOS profile run on Apple M4 measured full paragraph-layout medians
  of approximately 50/67/67 ms for that box fixture, and 43/59/58 ms for the demo's
  actual-button fixture. See [profile measurements](../../../performance/doc/flow_layout/PROFILE_BENCHMARK.md) for
  scope, samples, p95, hardware, and reproduction. Worst-case searches can still
  inspect every alternative; long-paragraph scaling and frame-time profiling
  remain subsequent work. The leading changes from the [CPU profile](../../../performance/doc/flow_layout/PROFILE_HOTSPOTS.md)
  are now implemented: width-rejected candidates skip vertical-metric queries,
  and taller lines retain chosen artifacts when all horizontal regions remain
  identical. Native profile medians for the actual-button fixture are now
  approximately 24/35/32 ms. See [optimization results](../../../performance/doc/flow_layout/PROFILE_OPTIMIZATIONS.md)
  for before/after samples and regression evidence.
- Subsequent internal optimizations cache bounded immutable break analysis,
  index breaks and source offsets, defer compound vertical metrics, share exact
  shaped text within a layout, and index snapshot fragments by participant.
  Shape sharing preserves owner-local geometry and reference-counts resources;
  eviction cannot dispose a shape still used by a committed measurement. Mutable
  Paint styles bypass sharing. Font notifications invalidate break analysis, and
  shape reuse never crosses layouts. Arbitrary custom sources keep their full
  constraint-dependent measurement path. See
  [sequential measurements](../../../performance/doc/flow_layout/SEQUENTIAL_OPTIMIZATIONS.md) for per-step results.
- Plain single-source text now bypasses compound measurement wrappers. The
  built-in text measurement implementation supplies immutable candidate windows; custom participants
  retain ordered-opportunity validation. A bounded cache can reuse a plain-text
  break decision only for identical full text, paragraph/content styles, start,
  and available/maximum widths. The chosen range is measured afresh, using the
  current owner; widget layout and region queries still run. Font notifications,
  detaching, and disposal clear retained decisions. Mutable Paint and padded or
  multi-source text bypass this cache. See [prose results](../../../performance/doc/flow_layout/PROSE_OPTIMIZATIONS.md).
- Long plain-text sources (at least 256 UTF-16 units) can retain exact candidate
  widths across layouts. Keys contain the actual shaped span and full styles;
  no document offsets or owners are retained. Cache hits can reject candidates
  without allocating a painter. Selected candidates still obtain a live shaped
  resource before their metrics, paint, or geometry are used. The same break
  search and overflow policy apply. Mutable Paint and padded/compound sources
  bypass this path. Font changes, detach, and disposal clear retention. See
  [long-run results and memory bounds](../../../performance/doc/flow_layout/LONG_RUN_OPTIMIZATION.md).
- Composition is still horizontal LTR and greedy. Bidi, balancing, justification,
  and input handling are not implemented. Snapshots remain valid only until the
  next layout. Basic semantics checks do not establish screen-reader behavior.

No review/sign-off on the earlier requirements document is needed to try this.
The concrete review surface is the API and the independent palette implementation.

## Automatic text fitting

There is no fitting-policy property on `FlowParagraph`. Eligible text uses an
internal compact numeric prefilter to reject clearly oversized ranges; candidates
that might fit receive the same exact measurements as before. The composer commits
those exact artifacts for painting and geometry. Unsupported content and custom
participants retain exact selection. See [automatic fitting](AUTOMATIC_TEXT_FITTING.md)
and [integration results](../../../performance/doc/flow_layout/COMPACT_INTEGRATION.md). Padded text now uses a separate
rejection-only path that accounts for nested fragment edges; final compound
artifacts and public measurements remain exact. See
[padded fitting](../../../performance/doc/flow_layout/PADDED_TEXT_FITTING.md) for scope and native measurements, and
[profiled preparation costs](../../../performance/doc/flow_layout/PADDED_LAYOUT_HOTSPOTS.md) for the subsequent
intrinsic-width/lazy-analysis optimization and its remaining timing failures.
