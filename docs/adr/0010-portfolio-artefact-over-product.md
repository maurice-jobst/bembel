# ADR 0010 — Portfolio artefact over product

Date: 2026-08-21 · Status: accepted

## Context

`BACKLOG.md` has said "portfolio-grade" since rev. 1 and ADR 0001 calls
BEMBEL "a one-team portfolio app". In parallel, a long-term direction was
stated (2026-08-19) that runs from "every public API in the app" through
"*the* Rhein-Main super-info app" to a platform where third parties sell
tickets through BEMBEL.

Those are two different objects. A portfolio artefact is optimised for a
reader: it may be small, finished, and heavily documented, and its job ends
when someone has read it. A product is optimised for users who return, and
its job never ends. The no-backend thesis is coherent for the first and a
cage for the second. Until now the repo has been built as the first and
narrated as the second, and every scoping decision has had to be re-argued
from scratch because the tie-breaker was never written down.

Two facts made the tie-break urgent rather than academic:

- v1.0 is 20 open issues over 7 months, and the least-started epic (D —
  Schattenkarte) owns the M1 exit criterion, two `size:L learning-goal`
  tickets, and the only feature with no fixture story.
- 31 of 32 merged PRs are authored by one person. The plan assumed four.

There is no external pull toward the platform direction today: no third
party has asked to publish into BEMBEL, and the only monetisation in the
backlog is an optional tip (`BEM-H03`).

## Decision

**When portfolio value and product value conflict, portfolio value wins.**

The reader this artefact is aimed at is engineering leadership: the ADR
corpus, the provider seam (ADR 0007), the AI-native selection principle
(ADR 0008) and the CI discipline are the artefact; the app is the evidence
that they held. A public App Store release is the floor — a portfolio app
that never shipped is discounted regardless of how well it reads.

Four consequences follow directly, and are decided here rather than left to
individual tickets:

1. **Depth over breadth.** Epic S is capped: no new data-source ticket is
   created before v1.0 ships. `BEM-S12`–`BEM-S15` are filed to M4 with the
   rest of the epic. The provider seam makes a new source cheap to *add* and
   permanent to *maintain*, and "nothing to rot" is a claim about the tail.
   This also blocks the "closed APIs and scraping" direction by construction:
   a scraper cannot enter v1.0 without first becoming a ticket.
2. **The Schattenkarte's rendering leaves v1.0** (`BEM-D04`, and `BEM-D06`
   in its shadow-geometry form). The data half stays: `BEM-D01`/`BEM-D02`
   ship as a published dataset (see Consequences), which `BACKLOG.md`'s own
   licence note already suspected was the stronger artefact. `BEM-D05` is
   delivered — the scrubber shipped with the solar ephemeris in #83.
3. **The sun screen survives without the fabricated overlay.** `ShadowView`
   currently draws a flat cobalt wash standing in for the LoD2 raster over a
   *real*, cross-validated NOAA ephemeris. The wash is the same class of
   defect as `Fountain.distanceLabel`, deleted in #60 for lying against real
   data. It goes; the ephemeris stays as a Sonnenstand tab.
4. **`docs/AI-NATIVE.md` is a v1.0 deliverable.** The most distinctive thing
   in this repo is not a feature: it is the set of constraints adopted so
   that agent-authored changes stay verifiable — byte-deterministic
   generators, mirrored files under byte-equality gates, one provider
   protocol per upstream, required checks, `LESSONS.md`. A reader currently
   learns none of that unless they infer it.

The 22 March 2027 ship date is **not** traded against scope. It is World
Water Day and the Trinkbrunnen season opening; the next date that carries
the same meaning is a year later. Scope gives, the date does not.

## Consequences

- The tab bar stays at five, but one of them changes what it is: `shadow`
  becomes `sun`. Dropping the tab was the first instinct and it was wrong —
  there is a real, cross-validated ephemeris behind it, and deleting a working
  screen to make a cut look tidy is not a cut, it is waste. The bar goes to
  four only if the `BEM-C01` gate below cuts departures. ADR 0009 is amended,
  not superseded — its reasoning about the "More" overflow is unchanged and
  still binding.
- The building/shadow geometry is published from a **separate repository**
  with dl-de/zero-2-0 lineage, not from `bembel-data`. `bembel-data` already
  carries OSM-derived rows under ODbL share-alike, and `BACKLOG.md`'s
  licence note is explicit that keeping those pipelines apart is what
  preserves freedom on the shadow data. The dataset has no community write
  path, so it gains nothing from living beside the registers.
- The positioning line loses two of its four nouns and is rewritten to
  describe what ships. A line that promises shade and trees while delivering
  water and air is exactly the kind of gap the intended reader checks first.
- v1.0's defensible core is now the bembel-data community layer plus water,
  air and radar. That is a smaller app than rev. 4 described, and a more
  original one.
- Freed capacity goes to polish, tests, App Store presence (`BEM-H01`),
  localisation (`BEM-H02`) and `AI-NATIVE.md` — not to reinstating epic D on
  an "if it's ready" basis, which is how the schedule risk would return
  through the side door. If the Schattenkarte comes back it comes back as
  the v1.1 headline, on 22 March's own anniversary logic.
- Phase 4 (super-app positioning) is untouched by this ADR — it is framing,
  not architecture. Phase 5 (platform) is out of scope; ADR 0001 now names
  the two observations that would reopen it.
