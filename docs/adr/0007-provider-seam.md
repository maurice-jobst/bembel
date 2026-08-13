# ADR 0007 — Provider seam between app shell and data sources

Date: 2026-08-13 · Status: accepted

## Context

Three people now work in this repo in two lanes (app frontend; data/backend).
The v0.1 shell renders sample data; five epics (C–G) replace it with live
sources at different speeds. The lanes must not block each other, and sample
fixtures must stay deletable piece by piece.

## Decision

Every feature talks to a protocol that lives in BEMBELKit
(`DeparturesProviding`, `FountainProviding`, `RadarProviding`,
`CityStatusProviding`) alongside its domain models. `Sample…Provider`
implementations in the kit are the only place fabricated values exist. The
app wires providers through one `AppDependencies` value in the SwiftUI
environment; views render `@Observable` view-model state and never call a
data source directly.

## Consequences

- Backend lands a live provider behind an existing protocol without touching
  `App/`; frontend restyles views without touching data code.
- Widgets and previews reuse the same kit fixtures instead of private copies.
- Protocol changes are cross-lane API changes: they need review from both
  lanes (CODEOWNERS routes `Packages/` to everyone).
- Sample providers die ticket by ticket; grep for `Sample` to see what's
  still fabricated.
