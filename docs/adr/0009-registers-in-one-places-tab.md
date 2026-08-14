# ADR 0009 — All place datasets live in one Orte tab

Date: 2026-08-13 · Status: accepted

## Context

The hero repositioning (spec 2026-08-13) makes the bembel-data registers
v1.0's flagship, which means they need position one in the tab bar. The bar
was already full with the five original features, and a sixth tab pushes
iPhone into the "More" overflow — hiding two shipped features behind a menu
to promote a third.

## Decision

One **Orte** tab in position one carries every place dataset —
Wasserhäuschen, Ebbelwei, Trinkbrunnen — behind a segmented control, with
Merkmale as the navigation inside it. `BEMTab.water` is replaced by
`BEMTab.places`; `bembel://water` and `bembel://wasser` remain valid and open
Orte on the Trinkbrunnen segment.

## Consequences

- The tab bar stays at five, and the hero sits first.
- Trinkbrunnen keeps its full scope (`BEM-E02`/`BEM-E03`): the seasonal state
  engine, the detail card and the fountain pins moved unchanged into
  `App/Features/Places/`.
- The three datasets share one map, one camera and one detail-card idiom, so
  a fourth place register later is a segment, not a redesign.
- Deep links are additive: `bembel://kiosk`, `bembel://ebbelwei`,
  `bembel://orte`. Nothing that worked before stopped working.
