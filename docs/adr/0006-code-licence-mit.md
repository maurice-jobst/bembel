# ADR 0006 — Code licence: MIT

Date: 2026-08-13 · Status: accepted

## Context

Public showcase repo; the code should be maximally reusable with minimal
ceremony. Data licensing is a separate problem: bundled datasets carry their
sources' terms (DL-DE Zero, DL-DE BY, ODbL — the ODbL share-alike question
for OSM-derived curated data gets its own ADR at BEM-B02).

## Decision

The code is MIT-licensed. The LICENSE file notes explicitly that `data/` is
governed by per-dataset licences recorded in `data/ATTRIBUTION.json`.

## Consequences

- No patent grant (Apache-2.0 was the alternative); for an open-data city app
  this is accepted as a non-issue.
- Contributors accept MIT by contributing; no CLA.
