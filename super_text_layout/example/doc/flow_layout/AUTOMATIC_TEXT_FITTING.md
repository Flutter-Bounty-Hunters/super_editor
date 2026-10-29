# Automatic text fitting in the paragraph

`FlowParagraph` now uses compact text widths to reject clearly oversized
candidates. Applications set no fitting-policy property. A candidate that might
fit is still measured by the original text measurement implementation, and the retained exact artifact
supplies placement, painting, baselines, carets, hit testing and selection boxes.
This implementation is additive to the package's existing SuperText APIs.

## Routing

The integrated path handles printable ASCII in unpadded and padded text runs.
Negative letter/word spacing, non-inheriting styles, explicit font
features/variations and mutable Paint
retain exact measurement. An eligible range can use compact data even when
other text in the same run has an unsupported immutable style. A control character
or non-ASCII character keeps the whole text run on the established path.
Custom participants keep their existing protocol.

Padded sources build numeric models for the same shaping chunks as exact compound
measurement. Each candidate sums intersecting text widths and fragment padding,
reusing common decoration edges across chunks. Margins accumulate per chunk.
An intersected unsupported chunk, failed calibration or empty chunk retains exact
measurement. Indivisible overflow and the maximum-width inspection band remain
exact. Padded candidates retain linear traversal; binary search is unchanged and
still applies only to eligible unpadded groups. See [padded fitting](../../../performance/doc/flow_layout/PADDED_TEXT_FITTING.md).

Flat numeric-only padded chunks now use Flutter's intrinsic paragraph width with
reusable encoded styles; temporary native paragraphs are disposed immediately.
Break analysis is lazy, so numeric sessions that need no breaks avoid redundant
Unicode work. Ordinary plain-text and mixed-owner width shaping retain their
previous TextPainter path. Models, calibration, margins and final exact artifacts
are unchanged. See [measured hotspots and limits](../../../performance/doc/flow_layout/PADDED_LAYOUT_HOTSPOTS.md).

Numeric data comes from three-grapheme interactions, with prefix sums for range
queries. The model is calibrated against exact whole-run, ordinary-segment and
neighboring-segment widths before use. A failed calibration caches an exact-path
decision instead. This is a practical guard, not a universal proof about arbitrary
fonts' contextual shaping. Prior fixture evidence and scope limits still apply.

A rejection requires a margin beyond the available width. Near the maximum-width
threshold the text measurement implementation measures exactly, preserving the normal/emergency-break
rule. Ranges with no legal internal break always remain exact so they retain
their overflow behavior. Small accumulated drift on huge unwrapped ranges remains
a nonblocking diagnostic. Committed artifacts never use approximate geometry.

## Break lookup

For at least 32 candidates in a wholly eligible unpadded text group, prepared data can
supply an internal furthest-potential-break bound. Its margin-adjusted endpoint
ordering is checked once and cached. Ordered windows use binary search to skip
the clearly oversized tail; short, mixed/unsupported or unordered windows keep
linear traversal. Exact measurements still resolve the near-fit window.

The first two characters, indivisible overflow ranges, maximum-width inspection
band and first-word emergency decision retain their existing handling. This
changes candidate traversal, not the public exact measurement protocol. See
[binary-search results](../../../performance/doc/flow_layout/BINARY_BREAK_SEARCH.md).

## Retention and lifecycle

Mostly repeated short runs retain the existing shape/decision path because
compact preparation adds overhead there. Each paragraph bounds numeric models to 256 entries / 65,536 UTF-16 units, and
shared grapheme widths to 2,048 entries / 8,192 units, and separate calibration
widths to 2,048 entries / 65,536 units. At most 64 immutable style keys are indexed. Keys contain
immutable styled spans, not participant owners. Numeric caches retain no native
painters. Font notifications, detachment and disposal clear the data. Layouts
reuse prepared models across width changes; edited text/styles use distinct keys.

## Reference and measurement

The normal widget path is automatic. Differential tests can force the exact
reference through a `@visibleForTesting` render-object setter. The profile runner
supports `--text-fitting exhaustive` as a diagnostic build; no application setting
is required. New automatic profile artifacts record `fittingImplementation: compact-intrinsic-v1`.
Existing `compact-v1`, `compact-binary-v1` and `compact-padded-v1` automatic budgets remain compatible
because the prepared text model and workloads are unchanged. Older automatic runs without that model
identity are still rejected. `--text-fitting linear-compact` retains the prior
traversal for diagnostic comparisons, including the padded prefilter
(`compact-intrinsic-linear-v1`).

See [integration results](../../../performance/doc/flow_layout/COMPACT_INTEGRATION.md),
[profile testing](../../../performance/doc/flow_layout/PROFILE_TESTING.md), and the [checkpoint reports](../../../performance/doc/flow_layout/PRETEXT_CHECKPOINT.md)
for preparation experiments and their remaining limits. The historical native
line-hint experiment remains diagnostic-only and does not drive normal fitting.
