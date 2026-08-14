# ADR 0002 — Two data mechanisms: curated store and thin live tier

Date: 2026-08-13 · Status: accepted

## Context

The original BEM-A05 described one generic offline-first layer ("bundle +
conditional GET + override, generic over dataset type") as the architectural
spine. Mapping the five v1.0 features against it: the pattern fits the
curated tier exactly (Trinkbrunnen, region rings, attribution, every future
operator dataset) and fits nothing else. RMV is per-request and key-gated,
radar is a 5-minute raster cadence, Stadtzustand is three live polls, and the
LoD2 building index is an mmap'd binary that never refreshes. One abstraction
covering all of that would be generic over things that are not alike.

## Decision

Two mechanisms, honestly named:

- **`Data/Curated` — `DatasetStore`** (the real spine): bundled snapshot →
  persisted override → conditional GET with `If-None-Match` against the
  published manifest. Generic over `CuratedDataset`; a 200 must decode as the
  payload type before it replaces anything; every failure mode degrades to
  the last good data. Fully unit-tested (200 / 304 / malformed / offline /
  5xx / unknown dataset). Adding dataset N+1 = one JSON file + one manifest
  row + a payload-type conformance.
- **`Data/Live` — `HTTPClient` + `Staleness`**: a typed GET with timeout and
  an age policy. Per-API shape lives in feature clients (EPIC C/F/G).
- **The LoD2 spatial index participates in neither** — it is a bundled binary
  owned by the Schattenkarte feature (BEM-D02).
- The bundled manifest's `baseURL` points at `data.invalid` until the publish
  workflow (BEM-B03) exists — refreshes fail gracefully instead of hitting a
  host we don't control yet.

## Consequences

- "Adding a sixth dataset is a data change" holds for the tier where it was
  ever true, and the claim is now testable.
- Live features must define their own decoders and failure states — the thin
  tier won't grow per-API branches.
- If a future dataset genuinely straddles both tiers, that's an ADR
  amendment, not an ad-hoc special case.
