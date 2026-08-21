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

## Amendment 2026-08-21 — one tab changes what it is

`BEM-D04` (shadow projection + rendering) leaves v1.0 with ADR 0010, so the
`shadow` tab no longer has the feature it was named for. What is behind it is
the solar ephemeris from #83 — real, cross-validated against published
sunrise/sunset data — under a flat cobalt wash that stands in for the LoD2
raster we are not shipping.

The wash goes; the ephemeris stays. `BEMTab.shadow` becomes `BEMTab.sun` and
the tab is **Sonnenstand**: where the sun is, honestly, rather than where the
shade falls, fabricated.

The bar therefore stays at **five**. An earlier draft of this amendment said
four, which was simply wrong arithmetic — the tab is renamed, not removed. It
goes to four only if the 1 December `BEM-C01` gate cuts departures.

The original reasoning is unchanged and still binding — this amendment renames
a tab, it does not license adding one. A fourth place dataset is still a
segment inside Orte, not a sixth tab.

- `bembel://shadow` and `bembel://schatten` keep resolving, with `?t=` intact;
  `bembel://sun` and `bembel://sonne` are added as aliases. Nothing that
  worked before stops working (`BEM-A03`'s totality requirement).
- The tab symbol moves off `building.2.fill`, which described the buildings
  casting the shadows. The replacement is verified in SF Symbols before it is
  committed, never synthesised from a base name — see the `wind.slash`
  incident in the Stadtzustand work.
- `BEM-D06` (accuracy disclosure) survives in re-scoped form: the ephemeris
  has its own accuracy story (refraction, the horizon convention), and being
  upfront still costs one screen and buys the credibility.
