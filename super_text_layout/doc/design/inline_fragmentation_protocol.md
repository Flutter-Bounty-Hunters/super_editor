# Inline fragmentation protocol proposal

Status: proposed; names and signatures below are sketches, not implemented API.
Date: 2026-10-24.

Implementation update: this document records the pre-refactor baseline and design
discussion. The range-measurement seam and independent custom participant now
exist. The text layout implementation also implements pinned Unicode 16 default break rules
with grapheme filtering and Flutter dictionary tailoring. See the shorter [current implementation note](../../example/doc/flow_layout/PROTOCOL.md)
for actual APIs, validation, and remaining limits.

## Purpose

Add a paragraph layout system in which one stateful inline widget can occupy
multiple fragments, across lines and across available segments on the same line.
The first participants are inline code and a sequence of ordinary Flutter
buttons. Existing `SuperText`, exports, and behavior remain intact.

The next implementation should prove an explicit negotiation contract:
participants supply legal breaks and measurements; the paragraph chooses breaks
and places fragments. The working flow layout example demonstrates much of the geometry,
but does not yet implement that general contract.

## Agreed requirements

| Concern | Decision |
| --- | --- |
| Integration | Additive, normal Flutter package; prioritize public Flutter APIs. Consider native/Wasm dependencies only after a demonstrated need. No engine changes. |
| Composition | Actual Flutter widgets and retained state, including nested fragmentable participants. Ordinary widgets enter through an indivisible-box adapter. |
| Text | A built-in participant in the same system as arbitrary content. Decoration-only boundaries preserve shaping and word boundaries. |
| Break ownership | Participants supply opportunities and restrictions. The paragraph selects breaks. Participants handle content they cannot display at maximum available width. |
| Geometry | Variable widths and multiple ordered segments per line from the beginning. Fill segments in reading order before advancing to the next line. |
| Regions | A region-provider interface, including rectangular exclusions. Callers position obstacles initially. Query with the whole proposed line height. |
| Height | Tall content may grow the line and require recomposition. |
| Selection | Text inside participants participates. Participants report geometry; external layers own all selection painting. Layers can paint beneath and above the paragraph. |
| Positions | Participant-local locations and container boundaries. Document indexing, insertion formatting, and editing behavior belong outside layout. |
| Decoration | Each fragment defaults to complete decoration and padding. Padding affects measurement. Allow other decoration policies later. The final wrapper API is undecided. |
| Scope | One paragraph first. Greedy line composition first; optional balancing and justification later. No keyboard/IME editing in this milestone. |
| International text | Account for bidi in the model; initial composition is horizontal LTR. Exact Flutter line-break compatibility is not required. |
| Accessibility | Preserve logical reading order and interactive descendants; fragments do not automatically become separate semantic items. |
| Scale | Initial stress case: 10,000 characters and 100 inline participants, including resize and content updates. |

## What the flow layout example establishes

Implementation: [entry point](../../lib/experimental_flow.dart),
[render participants](../../lib/src/experimental/flow/participants.dart),
[composer](../../lib/src/experimental/flow/paragraph.dart), and
[geometry](../../lib/src/experimental/flow/geometry.dart).

The [16 widget tests](../../test/flow_layout/flow_test.dart) passed in the last
implementation verification. They exercise wrapping code with fragment padding;
text on both sides of an obstacle; tall-content retries; advancing past a
full-width obstacle; button interaction and retained state after resize;
selection across participants; caret affinity; empty content; emoji boundaries;
basic semantics; and the stress case. The user has also verified the demo.

Adjacent text participants with matching padded ancestry share a Flutter text
run, including through zero-padding decoration wrappers. The shaping regression
uses a licensed Roboto font and compares geometry against a single `TextPainter`.
This is useful evidence, not comprehensive script, ligature, bidi, or pixel-level
validation.

Recent debug-test stress samples were approximately 25–45 ms per layout. These
are observations, not a release frame-time guarantee, a benchmark distribution,
or evidence of acceptable performance on other devices. The stress test uses
simple box children; it does not measure 100 complex interactive controls.

### What remains provisional

- `_Composer` recognizes text and atomic entries directly. It is not yet an
  extensible range-measurement implementation for arbitrary participants.
- The text layout implementation asks Flutter for a fitting prefix and reshapes that prefix.
  This demonstrates greedy fitting, not independent enumeration of legal breaks.
- Splits between run types are not yet governed by a general boundary resolver.
  A widget boundary must not automatically become a legal text break.
- Layout, paint bounds, hit regions, selection bounds, and semantic bounds need
  separate contracts. Current fragment bounds serve several purposes.
- Snapshots own painters that are disposed at the next layout. Retaining one
  beyond that point is unsafe. Lifetime and invalidation need an explicit API.
- Horizontal LTR and fixed text scaling are hard-coded. Bidi, locale-sensitive
  behavior, and text scaling are not demonstrated.
- Basic semantics tests do not establish native screen-reader reading order,
  focus traversal, or useful bounds for all fragmented interactive content.
- Current height growth is monotonic but lacks an explicit retry budget.
  Monotonic growth alone does not prove termination for arbitrary participants.
- Committing fragments repeatedly scans the complete fragment list. Preparation,
  repeated shaping, and commit lookup need profiling before cache design.

### Preserve the empty-line behavior under review

The caret corrections must preserve the demo's existing empty line and its
position. A previous attempt changed newline consumption and removed that line;
the change was reverted at the user's request. The regression now freezes the
original populated/blank/populated arrangement.

The protocol must represent blank lines explicitly, even without glyph ink.
Hit testing first chooses a line by its vertical band, then a location within
that line. At a shared text boundary, visual affinity distinguishes the previous
line's end from the blank line's start. Neither removing the blank line nor
always choosing the upstream caret satisfies the requirement. A future newline
semantics change must be reviewed separately from pointer geometry fixes.

## Proposed architecture

Keep a `RenderBox` at the paragraph boundary and a `RenderObject`-based protocol
inside it. This uses Flutter's ordinary widget/state lifecycle without treating
every fragment as a separate widget or render object.

| Component | Owns |
| --- | --- |
| Participant | Content, internal legal breaks, measurements, fragment rendering, local locations and geometry |
| Container participant | Nested structure and restrictions; delegates to children without hiding their legal breaks |
| Prepared paragraph | An ordered composition view, cross-participant boundary resolution, measurement dispatch, and shared shaping services |
| Line composer | Region queries, candidate selection, baselines, retries, and final placement |
| Region provider | Available segments for a proposed vertical band and how to advance when no space exists |
| Text layout implementation | Shared text context, legal text opportunities, shaping, glyph rendering, and text geometry |
| Editor/document adapter | Mapping layout locations to document positions, insertion context, mutations, and input handling |
| External layers | Selection, carets, and other optional decoration visuals |

Text needs cooperative shaping. Each text widget may own its string and
semantics while contributing to a shared shaping context. A decoration-only
wrapper must not force independent shaping. The text layout implementation may produce one
shared rendering artifact for several owners; source mappings preserve each
owner's locations and decoration geometry. Arbitrary non-text participants need
not expose strings or use that text measurement implementation.

## Proposed negotiation contract

### 1. Prepare a stable measurement session

During Flutter layout, participants prepare content and measure any ordinary
box children through the normal child-layout calls. Capture child dimensions
and baselines during the adapter's own layout; later queries read the captured
result, not a grandchild's live `RenderBox.size`.

A preparation session is tied to a content/style/font/environment revision and
the applicable constraints. Preparation records nested structure, ownership,
and contributions to shared text context. It does not commit visual fragments.
Actual widgets and their state are not rebuilt for candidate alternatives.

### 2. Discover opportunities, without choosing a break

An opportunity identifies a boundary, whether it is allowed or required, and
whether it ends a line or merely permits ending the current segment. A forced
newline ends the line even if another segment remains available. Exhausting a
segment does not itself force a new line.

Opportunities may be generated lazily and cached. The contract must allow
asking for alternatives, not only receiving the one break selected for a given
width. Do not require eagerly allocating one candidate per character.

For ordinary text, legal word/script breaks and emergency grapheme-safe breaks
are distinct classes. Use emergency opportunities only when an ordinary
unbreakable unit cannot fit in the applicable maximum fresh-line space under
the participant's policy; a narrow leftover segment alone is not sufficient.
No break may divide a grapheme cluster. An indivisible button offers boundaries
around itself; a sequence offers the permitted boundaries between its pieces.

Cross-child opportunities are resolved in context. Decorating `ell` in `hello`
must not introduce a break around `ell`. Ancestor restrictions also apply; the
resolver must be able to veto a child opportunity when a container keeps content
together. Required-break conflicts must yield a diagnostic rather than silently
discarding a constraint.

### 3. Measure an exact candidate range

**Recommendation for review:** allow the paragraph to ask for the measurement
of an exact legal range between two composition cursors. A participant should
not be limited to consuming a width and returning its preferred prefix.

Measurements include inline advance, ascent/descent, effects of fragment-edge
padding, and an opaque rendering/geometry artifact or a reproducible handle.
The context includes available inline space and whether each edge is an actual
content edge or a continuation edge. If a participant's geometry depends on
space, that dependency belongs in the query and cache key.

Padding applies once at the corresponding decorated fragment edges, not once
per text leaf or atom inside a shared wrapper. For example, a padded container
holding three buttons on one segment gets one leading and one trailing padding
contribution. Continuing on another segment adds the configured fragment-edge
padding again. Nesting composes these contributions from the actual ancestry.

Candidate measurements must be repeatable within the session and must not
replace committed layout, mutate widget state, or change which content exists.
Participants may cache derived measurements. A candidate can report that it
cannot satisfy the offered space; the paragraph tries another opportunity or
segment. Oversized content handling remains the participant's responsibility.

The paragraph-level prepared view orchestrates range measurements across
participants. Common text is measured together where shaping requires it;
custom content receives its own local subrange. Range metrics are not assumed
to equal a sum of isolated-character widths.

### 4. Select, retry, and commit

For the first strategy, the paragraph selects the furthest legal candidate that
fits the current segment, respecting required breaks and fallback classes.
It can reconsider earlier candidates when later information changes the fit.
The measurement interface must not assume widths are strictly additive or
monotonic across candidate ranges; optimized search requires measurement guarantees.

All segments of a line share its baseline. When candidate content increases the
line's ascent or descent, recompute regions using the full grown band and retry
from the same logical start. Keep height monotonic within that line attempt.
Empty available space may advance to a provider-supplied later vertical position.
Once a line is stable, place its fragments; publish one coherent paragraph
snapshot after all lines are composed.

The final commit uses the measured revision and selected artifacts. It may not
reshape or otherwise change the measurements after the break has been accepted.
A changed revision invalidates the attempt. Each participant receives all its
final fragments as one result; state and identity survive changes in fragment
count. Abandoned measurement artifacts are released through the session.

Every loop must consume ordered content or advance to valid later space.
Forced-break events have their own progress identity, including consecutive
breaks and empty participants; zero text length does not imply zero progress.
Require finite geometry and diagnose invalid region output. Use explicit retry
and region-query safety limits with actionable diagnostics; do not silently
commit a colliding layout when a participant/provider fails to converge.

### Sketch of the seam

These are conceptual operations, not final Dart declarations:

```text
PreparedParagraph
  opportunitiesAfter(cursor, boundaryContext) -> lazy opportunities
  measureRange(start, end, fragmentContext)   -> measurement or cannotFit
  commit(chosenPlacements)                    -> committed layout

BreakOpportunity
  cursor, kind (ordinary/emergency/required), break effect

FragmentMeasurement
  revision, start, end, advance, ascent, descent,
  edge contributions, rendering/geometry handle
```

The paragraph-owned ordered cursor is internal to layout. It can retain nested
boundary events without becoming a document index. Public locations remain
participant-local. An adapter maps them to any editor's indexing scheme.

The service must define range measurement before adopting these names as public
API. A custom participant should not need to produce a built-in text/box entry
type or patch the composer to participate.

## Committed geometry, painting, and interaction

Each fragment needs an owner, its local content interval or boundary events,
line/segment identity, baseline, layout bounds, paint bounds, and the text measurement implementation
handle needed to render and query it. One logical interval can eventually have
multiple visual fragments on the same line under bidi; avoid one-rect-per-range
assumptions. Reading order and visual order must be represented separately.

Retain the flow layout example's shared paragraph coordinate plane for the next experiment.
Box adapters transform ordinary children into that plane. Query results delivered
to external layers use paragraph coordinates. Do not simulate one render object
being located in several places by calling ordinary child painting repeatedly
with unrelated transforms; composited children and semantics need explicit
ownership and coordinate mapping.

The protocol should expose distinct queries for caret geometry, selection
boxes, hit regions, and decorated fragment bounds. A pointer first selects a
line by vertical extent, including blank lines, then selects a segment/content
location on that line. Ordinary widget gestures still use the corresponding
box-child hit-test transform. Visual affinity preserves ambiguous wrap-edge
locations; it does not decide what document container receives inserted text.

Participants never paint their own selection. External layers receive geometry
and can choose appearance. An external caret can distinguish inside/outside
padding boundaries without knowing a document's structural indices.

The committed result preserves logical semantic ownership and reading order;
wrapping must not repeat text announcements or duplicate a button's focus target.
Fragment-based semantic hit bounds and custom interactive participants require
further validation. Do not equate their bounding union with a fully solved
accessibility contract.

Committed snapshots should have an explicit generation/lifetime. A stale query
must be rejected or use retained resources, rather than reach a disposed painter.
Geometry-only public values can be immutable and independent of rendering
resources. The exact ownership mechanism remains an implementation decision.

## Refactor and validation plan

1. Preserve current visual behavior and the 16 existing tests. Keep the empty-line
   regression as a layout-and-interaction check, not just an offset assertion.
2. Add a prepared-content/range-measurement seam and a greedy composer using only
   that seam. Demonstrate a third custom, non-text participant with internal
   break opportunities without adding type checks to the composer.
3. Move the button sequence and its box adapters to the seam. Verify cloned
   padding around a container with several atoms, nested restrictions, no-fit
   advancement, and repeatable measurements with no state recreation.
4. Move text opportunity discovery and shaping into a dedicated text measurement component. Prove that it
   can offer alternative legal breaks and measure the chosen range using public
   Flutter APIs. A fitting-prefix query alone does not complete this step.
5. Add focused real-font rendering checks for shaping across leaf/decorator
   boundaries, grapheme-safe fallback, forced/consecutive/trailing breaks, and
   empty participants. Add mixed-direction cases as model probes before promising
   a bidi composer. Keep document-index mapping in a test adapter outside layout.
6. Validate native accessibility and focus for fragmented text and controls.
   Exercise resource lifetime, environment changes, child-size invalidation,
   retry limits, and selection-only repainting.
7. Profile preparation, opportunity discovery, shaping/measurement, region retry,
   commit, painting, and hit testing separately. Record repeated debug and release
   observations with device/runtime/font details. Then decide which caches or
   incremental work are justified. Do not infer a frame budget from the current
   stress test.

SDK feasibility is a gate in step 4, not an assumption. If public APIs cannot
support reliable opportunities, context-preserving shaping, or range rendering,
record the failing case and evaluate the smallest alternative. Do not quietly
weaken text correctness or commit to native/Wasm distribution in this proposal.

## Review point

The principal proposal is an exact-range measurement contract under
paragraph-owned break selection, with shared shaping as a text measurement service.
That seam should work for code, ordinary box sequences, and an independent custom
participant before being treated as stable API.

The wrapper API, snapshot ownership details, full bidi behavior, balancing,
justification, float placement, multi-paragraph flow, and keyboard editing remain
separate work. This proposal does not settle them by copying flow layout example shortcuts.
