# ADR 0003 — Region model: AGS-keyed municipalities in three rings

Date: 2026-08-13 · Status: accepted

## Context

"Rhein-Main" has no legal definition. The app needs a reproducible answer to
"is this POI in the user's region?" that survives Gebietsreformen and doesn't
turn every edge suburb into an argument. In v1.0 exactly one dataset is
ring-filtered (Trinkbrunnen) — the model is deliberately minimal but is
load-bearing for every later curated dataset.

## Decision

- Every curated POI carries an **AGS** (Amtlicher Gemeindeschlüssel, 8
  digits, validated at decode time).
- Three concentric rings; a selection includes all inner rings:
  - `frankfurt` — AGS 06412000
  - `kernraum` — member municipalities of the **Regionalverband
    FrankfurtRheinMain** (formal planning association, published list)
  - `rheinmain` — the **Metropolregion FrankfurtRheinMain**
- Membership lives in `rings.json`, **generated** by
  `scripts/generate_rings.py` from the Destatis Gemeindeverzeichnis — never
  hand-typed, never in Swift code. The shipped seed table is marked
  `provisional` and contains only unambiguous major cities; the generator
  refuses to run until its membership lists are verified against the
  published sources.
- Default selection: `kernraum`, stored in App Group defaults.
- Unknown AGS = excluded. Departures ignore rings entirely (RMV is regional).

## Consequences

- Region changes are data changes: re-run the generator at a new
  Gebietsstand, ship the JSON.
- No `RegionFilterable` protocol, no predicate machinery — one lookup, one
  `isIncluded` call site until a second ring-filtered dataset exists.
- The two rings' definitions are citable, so "why is X not in kernraum?"
  has an answer that isn't ours.
