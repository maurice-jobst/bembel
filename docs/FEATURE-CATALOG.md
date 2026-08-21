# BEMBEL — Feature Catalog

Ordered by **data readiness first**, then coolness × feasibility. A feature whose data arrives as a URL is worth three features that need curation.

Effort is *implementation* effort assuming the data layer from `EPIC A` exists.
Rot = how fast the feature decays if nobody maintains it.

> **Note 2026-08-21.** This file is the record of *why features were selected*,
> and it is left standing as written. It is no longer the record of what v1.0
> ships: ADR 0010 moved the Schattenkarte's rendering (B1) out of v1.0 and
> rewrote the positioning line stated at the end of this document. `BACKLOG.md`
> rev. 5 is the current scope.

---

## Tier A — data already exists, effort is UI only

| Feature | Source | Access | Effort | Rot |
|---|---|---|---|---|
| **RMV departures** | RMV open data portal | REST, free key, registration lag | M | none |
| **Rain radar** | DWD `opendata.dwd.de` (GeoNutzV), RADOLAN parsed on-device (ADR 0008) | Open, no key | M | none |
| **Free drinking water** | Frankfurt Geoportal `Trink_Erfrischungsbrunnen` + OSM `amenity=drinking_water` + Refill partners | WFS/GeoJSON | S | slow |
| **Main water level** | PEGELONLINE (WSV) | REST, no key, no registration | S | none |
| **Civil warnings** | NINA / warnung.bund.de | Public JSON | S | none |
| **Air quality** | HLNUG Hessen measuring stations | Open | S | none |
| **Hyperlocal particulates** | sensor.community | Open API | S | none |
| **EV charging** | Bundesnetzagentur Ladesäulenregister | CSV | S | slow |
| **Public toilets / benches / book cabinets / BBQ spots** | OSM (`amenity=toilets`, `public_bookcase`, `bbq`) | Overpass | S | slow |
| **Tree register** | Frankfurt open data, 168k trees on public land | Download | M | slow |
| **Bridge days / Hessen holidays** | Pure computation | none | S | none |
| **3D building model** | HVBG LoD2, all of Hessen, **dl-de/zero-2-0** | WFS + Downloadcenter | — | none |

Two notes that matter more than they look:

**Hessen geodata is unusually good.** Since 1 Feb 2022 Hessen provides Geobasisdaten free and licence-free, and the LoD2 building model is published under Datenlizenz Deutschland **Zero** — effectively public domain, no attribution obligation. Height accuracy is roughly 1m for properly LoD2-modelled buildings, 5m for objects that are really LoD1. That is the single most valuable asset available to this project and nobody consumer-facing is using it.

**Trinkbrunnen have a season, and that's a feature.** Fountains are shut off from October against frost damage; the season starts on World Water Day, 22 March; historic fountains come back after Easter; historic ones run 10:00–22:00 on a timer. So "is this fountain running right now" is answerable from a date rule with zero API calls — and no map anywhere currently tells you.

---

## Tier B — compute-heavy, high wow, no ongoing maintenance

These are the ones worth building the app for. All are *derived* — the value is in the computation, not the dataset, so they never rot.

### B1 — Schattenkarte (shadow map)
LoD2 footprints + ridge heights + solar position → shadow polygons for any time of day and day of year.

Frankfurt is the ideal city for this: it's the only German skyline, and the Bankenviertel throws shadows hundreds of metres. Real uses: which side of the Main to walk in August, which Biergarten table still has sun at 19:00 in May, which playground is shaded at 14:00, whether your prospective flat gets afternoon light.

**Implementation:** on-device, not pre-rendered tiles. Extract `(footprint polygon, ground height, ridge height)` per building into a compact binary with an R-tree index; compute sun azimuth/elevation with NOAA's solar position algorithm; project shadow volumes for buildings in the viewport only. That gives continuous time-scrubbing instead of hourly snapshots, and no tile pipeline to maintain.

**Constraint worth accepting:** Frankfurt city has on the order of 10–15 MB of simplified footprints. The full Rhein-Main ring is several times that and blows the bundle. **Ship the shadow map Frankfurt-only in v1.0**, with optional region downloads later. This is a good reason the ring model exists.

### B2 — Schattenroute (shade routing)
The one that makes press. Combine B1 with the tree register and the drinking fountain layer: *walk from A to B staying in the shade, passing water*. Nothing like it exists for any German city, and it lands squarely on Frankfurt's actual policy conversation about heat in the city.

Weight the pedestrian graph by shade coverage at departure time. Expensive but self-contained, and reuses B1 entirely.

### B3 — Frankfurthenge
Days when the setting sun aligns with a street canyon, or drops exactly behind a named tower as seen from a named viewpoint (Eiserner Steg, Main-Ufer, Lohrberg). Pure geometry against the LoD2 model, a handful of KB of output, and an annual reason for people to open the app and post a photo. Cheap. Charming. Nobody has it.

### B4 — Solar potential
The shadow engine already knows roof orientation and annual insolation. "Is my roof worth a PV panel" falls out almost free. Probably v2 — it drags in assumptions and disclaimers.

---

## Tier C — operator-generated datasets

A new class: data that doesn't exist anywhere machine-readable, but that an agent can assemble on a schedule.

### The pattern

```
GitHub Action (cron, seasonal)
  → agent fetches source list (press, market operator pages, menus)
  → extracts structured facts, one source URL per data point
  → emits data/gluehwein.json
  → opens a PR
  → you review and merge
  → publish workflow updates the manifest
  → app picks it up on next refresh
```

**No backend is added.** The agent is CI, the review is a PR, the delivery is the manifest you already have. This is the reason the static architecture was worth defending.

Two rules that keep it honest:
- **Every data point carries a source URL.** No source, no row. This is the entire defence against a confidently invented Glühwein price.
- **Store facts, not prose.** Numbers, names, dates, and a link. Never scraped article text — that's a copyright problem you don't need.

### C1 — Glühwein-Preisbarometer (late Nov – 23 Dec)
Price per mug and Pfand across the Frankfurt Weihnachtsmarkt and the surrounding markets, refreshed weekly, with the delta against last year. Every regional outlet writes this story annually, which is precisely why the agent has material — and why they'll link to you if you do it better.

### C2 — Schoppen-Index (year-round)
Price of 0.3l Apfelwein across Apfelweinwirtschaften. On-brand for an app called BEMBEL, and it runs all year instead of five weeks. Harder to source than Glühwein — menus, not press — so it's a slower build with user submissions as a possible later input.

### C3 — Kreppel-Index (Jan–Feb)
Same engine, third instance. Demoted from a headline feature to one row in a generic barometer, which is where it belongs.

**Build the barometer as a generic feature with a dataset parameter**, not three separate features. One view, one schema, three JSON files, seasonal surfacing rules.

---

## Tier D — backlog, in rough order of appeal

- Abfall- und Sperrmüllkalender (FES) — highest daily-life utility of anything here, but scrape-fragile
- Parkhaus occupancy via the Parkleitsystem / Urbane Datenplattform — verify whether it's actually exposed
- Freibäder: opening status + water temperature
- Badegewässerqualität (Hessen), Langener Waldsee and friends
- Stolpersteine with biographies
- Wochenmärkte + Kleinmarkthalle stallholders
- Bike: Fahrradstraßen, Bügel, Luftstationen, counting-station throughput
- Grüngürtel / GrünGürtel-Tier / Regionalpark trails
- Ortsbeirat agendas from PARLIS
- Pollen forecast (DWD)
- Wäldchestag / Dippemess / Museumsuferfest calendar
- Wasserhäuschen (survives, but as curation-heavy Tier D rather than a launch feature)
- Apfelweinwirtschaften list
- District quiz / achievements

---

## Revised v1.0 cut

Five features, chosen so that four of them need **no curation at all**:

1. **RMV departures + Home Screen widget** — the daily-open hook
2. **Schattenkarte** — the signature, Frankfurt-only
3. **Free drinking water** — with the seasonal on/off logic
4. **Rain radar** — cheap, high frequency
5. **Main-Pegel + air quality + warnings** as one lightweight "Stadtzustand" screen — three trivial APIs, one screen

Deferred to v1.1+: Schattenroute, Frankfurthenge, Preisbarometer, everything in Tier D.

### The launch date should move

Carnival was the right hook when the app was called Kreppel. It isn't now.

**Target 22 March 2027 — World Water Day, the day Frankfurt's drinking fountains come back on.** That gives seven months instead of five, it's a real press hook that no other app can claim, and it opens straight into the summer season when shade, water, heat and air quality are what the city is actually talking about. Glühwein-Preisbarometer then lands in November 2027 as the first operator dataset, with a launched app behind it.

The positioning that falls out of this: **BEMBEL is the app for a city that keeps getting hotter.** Shade, water, trees, air. That's a sharper identity than "Hamburg's app but Frankfurt", it's defensible in press, and it happens to be exactly where the free data is best.
