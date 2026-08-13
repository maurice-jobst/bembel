# BEMBEL — v1.0 Backlog (rev. 2)

Free Rhein-Main city app for iPhone. Portfolio-grade, no backend, no accounts.
Feature selection rationale lives in `FEATURE-CATALOG.md`. This file is the work.

**Locked decisions**

| Decision | Value |
|---|---|
| Name | BEMBEL |
| Positioning | The app for a city that keeps getting hotter — shade, water, air, trees |
| Scope | Rhein-Main rings (`BEM-A04`). Shadow map is Frankfurt-only in v1.0 |
| Platform | iPhone only, iOS 18.5+, SwiftUI |
| Backend | None. Static JSON + remote refresh with ETag. Operator datasets are CI + PR |
| Accounts | None |
| Base language | German, English v1.1, localisation scaffolding ships in v1.0 |
| Target ship | **22 March 2027** — World Water Day, Trinkbrunnen season opening |

**Selection principle:** data readiness first, then coolness × feasibility. Four of the five v1.0 features require zero curation.

**NOT in v1.0** — voting, accounts, events calendar, parliament, elections, quizzes, stickers, Wasserhäuschen, Apfelwein list, Kreppel ranking, price barometers, shade routing, Android, iPad.

---

## Milestones

| Milestone | Window | Exit criteria |
|---|---|---|
| **M0 — Skeleton** | Aug–Oct 2026 | App builds, navigates, renders one dataset on a map. CI green. |
| **M1 — Pipeline & geometry** | Oct–Dec 2026 | Data pipeline live. LoD2 extraction produces a loadable building index. |
| **M2 — Features** | Dec 2026–Feb 2027 | All five v1.0 features functional. Widget on home screen. |
| **M3 — Ship** | Mar 2027 | TestFlight → App Store by 22 March. Press sent. |

---

## EPIC A — Foundation

### BEM-A01 — Xcode project scaffold · `size:S` · M0
Plain Xcode project, no Tuist/XcodeGen. SwiftUI lifecycle, iOS 18.5 target, SPM only, zero third-party deps unless a ticket justifies one.
Targets: `BEMBEL`, `BEMBELWidgets`, `BEMBELKit`.
**AC:** `xcodebuild -scheme BEMBEL -destination 'platform=iOS Simulator,name=iPhone 16' build` passes from a clean checkout.

### BEM-A02 — Design system · `size:M` · M0 · `learning-goal`
Salt-glaze grey, cobalt blue, diamond relief as texture motif. Tokens in `BEMBELKit`. Dark mode + Dynamic Type to 200% from day one.
**AC:** `DesignSystemPreview` renders every token. No hardcoded hex outside the token file.

### BEM-A03 — Navigation shell · `size:M` · M0
`NavigationStack`, typed destinations, deep links (`bembel://shadow?t=2027-06-21T15:00`). Needed later by widgets and App Intents; cheap now.
**AC:** Every feature reachable in ≤2 taps; every detail reachable by URL.

### BEM-A04 — Region model and selector · `size:M` · M0 · `needs-decision`
Every POI carries `ags` + `ring` ∈ {`frankfurt`, `kernraum`, `rheinmain`}. User-selectable, default `kernraum`. Ring membership is a JSON lookup table, never Swift code. Departures ignore rings.
**AC:** Ring switch filters every list and map without relaunch.

### BEM-A05 — Offline-first data layer · `size:L` · M0/M1 · `learning-goal`
Bundled snapshot + conditional GET (`If-None-Match`) + Application Support override. Generic over dataset type — a sixth dataset must be a data change, not a code change.
**AC:** Airplane mode from cold install shows full data. Tests cover 200 / 304 / malformed / offline.

### BEM-A06 — CI · `size:S` · M0
Build + test on PR, SwiftLint, data schema validation job.

---

## EPIC B — Data pipeline

### BEM-B01 — GeoJSON schema + validator · `size:M` · M1
Required: `id`, `name`, `geometry`, `ags`, `ring`, `sources[]`, `updated`.
**AC:** `make validate` fails on missing `ags` or unknown `ring`.

### BEM-B02 — Attribution registry · `size:S` · M1
`data/ATTRIBUTION.json` → in-app credits screen.
- HVBG LoD2: **dl-de/zero-2-0** — no attribution obligation, credit anyway
- Stadt Frankfurt open data: dl-de/by-2-0, source naming required
- OSM: ODbL, share-alike applies to derived data
- DWD: GeoNutzV · RMV: per their terms · PEGELONLINE: per WSV terms

### BEM-B03 — Publish workflow · `size:M` · M1
Actions → Pages or R2, manifest with per-dataset version + ETag.
**AC:** Merging a data PR updates the live manifest within 5 minutes.

### BEM-B04 — Operator dataset harness · `size:M` · M1 · `learning-goal`
Scaffolding for Tier C, built now, first used in v1.1: scheduled Action → agent → structured JSON → PR → human merge.
Hard rules encoded in the validator: **every row carries a source URL**, and the payload stores facts only, never scraped prose.
**AC:** A dry-run job opens a PR against a fixture source list and the validator rejects a row with no source.

---

## EPIC C — Departures

### BEM-C01 — RMV key + client · `size:M` · M2 · `blocked`
Register on the RMV open data portal **in week 1** — approval lag blocks the whole epic. Defensive decoding, fixtures for unit tests, key gitignored.
**AC:** Integration test hits a real stop and returns ≥1 departure.

### BEM-C02 — Nearby stops + departures view · `size:L` · M2
CoreLocation → nearest stops → departures, Anzeigetafel aesthetic, honest delay and staleness rendering.
**AC:** Cold launch to visible departures <2s on cellular.

### BEM-C03 — Pinned stops · `size:M` · M2
Local storage shared with the widget via App Group.

### BEM-C04 — Home Screen widget · `size:L` · M2 · `learning-goal`
WidgetKit + `AppIntentConfiguration` — stop and line filter chosen from the widget. Small/medium/large.
**AC:** Survives 24h on device without going blank. Reload policy documented in an ADR.

### BEM-C05 — Lock Screen accessory · `size:M` · M2

### BEM-C06 — Failure states · `size:M` · M2
Designed states for: no location permission, no network, RMV down, no departures, data older than 90s. No infinite spinners.

---

## EPIC D — Schattenkarte

The signature feature. Everything here is geometry; nothing rots.

### BEM-D01 — LoD2 acquisition · `size:M` · M1
Pull the Frankfurt tile set from the HVBG Downloadcenter or the INSPIRE WFS (`geoportal.hessen.de/spatial-objects/831`). CityGML in, raw archive committed under `data/sources/` or fetched reproducibly by script.
**AC:** A documented, re-runnable command produces the same input set.

### BEM-D02 — Building index · `size:L` · M1 · `learning-goal`
CityGML → `(simplified footprint, ground height, ridge height)` in a compact binary with an R-tree. Budget: **≤15 MB for Frankfurt city**. Drop LoD1-quality objects below a height threshold; they add bytes and error.
**AC:** Viewport query for a 1km² area returns in <20ms on device.

### BEM-D03 — Solar position · `size:S` · M2
NOAA solar position algorithm. Pure function, exhaustively unit-testable against published values.
**AC:** Matches reference azimuth/elevation for 20 known place/time pairs within 0.1°.

### BEM-D04 — Shadow projection + rendering · `size:L` · M2 · `learning-goal`
Project shadow volumes for viewport buildings, render as a MapKit overlay. Continuous time scrubbing, not hourly snapshots.
**AC:** 60fps scrubbing on an iPhone 14. Flat memory over a 5-minute scrub.

### BEM-D05 — Time controls + "now" · `size:M` · M2
Date + time scrubber, snap-to-now, sunrise/sunset markers, a fast "when is this spot in shade today" readout.

### BEM-D06 — Accuracy disclosure · `size:S` · M2
Plain-language note on model limits: ~1m height accuracy, no balconies, no trees, no terrain shading in v1.0. Being upfront costs one screen and buys all the credibility.

---

## EPIC E — Free drinking water

### BEM-E01 — Fountain dataset · `size:M` · M1
Frankfurt Geoportal `Trink_Erfrischungsbrunnen` + OSM `amenity=drinking_water` + Refill partners, deduplicated, typed as `historisch` | `stadt` | `mainova` | `refill`.

### BEM-E02 — Seasonal state engine · `size:S` · M2
Date rules, no API: off from October; season opens 22 March; historic fountains after Easter; historic ones run 10:00–22:00. Computed movable-feast dates for Easter.
**AC:** "Running now / off for winter / opens 22 March" correct for any simulated date.

### BEM-E03 — Map, list, detail · `size:M` · M2
Distance sort, Apple Maps handoff, type filter, ring filter free from `BEM-A04`.

---

## EPIC F — Rain radar

### BEM-F01 — Radar client · `size:M` · M2 · `needs-decision`
DWD `opendata.dwd.de` under GeoNutzV, or Bright Sky's JSON wrapper. RADOLAN parsing is the better learning outcome; the wrapper is the better use of the calendar. Write the ADR, then pick.

### BEM-F02 — Animated overlay · `size:L` · M2
Last ~2h in loop, play/pause/scrub, colourblind-safe scale.

---

## EPIC G — Stadtzustand

One screen, three trivial APIs. Cheapest utility-per-line-of-code in the project.

### BEM-G01 — Main-Pegel · `size:S` · M2
PEGELONLINE (WSV), no key, no registration. Frankfurt Osthafen gauge. Trend arrow, flood/low-water context.

### BEM-G02 — Air quality · `size:S` · M2
HLNUG stations. Nearest station, index, plain-language interpretation.

### BEM-G03 — Civil warnings · `size:S` · M2
NINA / warnung.bund.de, filtered to the user's ring. Read-only, no push in v1.0 — push means a server.

---

## EPIC H — Ship

### BEM-H01 — App Store presence · `size:M` · M3
Hero shot is the shadow map at 15:00 over the Bankenviertel. Category Reference. Screenshots, icon, keywords.

### BEM-H02 — Localisation scaffolding · `size:M` · M2
String Catalogs, zero hardcoded user-facing strings, German base.
**AC:** Pseudo-locale build shows no untranslated strings.

### BEM-H03 — Tip IAP · `size:M` · M3 · `needs-decision`
StoreKit 2 consumables, or nothing. Decide deliberately by M2.

### BEM-H04 — Privacy + TestFlight · `size:S` · M3
"Data Not Collected", and mean it — no analytics SDK. 10–20 Rhein-Main beta testers.

### BEM-H05 — Launch outreach · `size:S` · M3
Send week of 15 March 2027, ahead of the 22 March fountain-season stories.
List: Journal Frankfurt, Frankfurt-Tipp, Hessenschau, FAZ Rhein-Main, Merkurist, plus `offene.daten@frankfurt.de` (they ask to be told, and list good examples) and HVBG (a consumer app on LoD2 is a case study they don't have).

---

## v1.1 and beyond

| Release | Content | Timing rationale |
|---|---|---|
| v1.1 | English localisation | Immediately post-launch, before summer traffic |
| v1.2 | Schattenroute (shade routing) | June 2027 — heat season |
| v1.3 | Frankfurthenge | Late summer, sunset alignment dates |
| v1.4 | Preisbarometer engine + Glühwein-Index | November 2027 |
| v1.5+ | Tier D from `FEATURE-CATALOG.md`, one per release | |

---

## Open decisions

1. **`BEM-D02` bundle budget.** 15 MB of building geometry for Frankfurt city is the working assumption. If extraction blows past it, the fallback is on-demand region download — decide before M2, not during.
2. **`BEM-F01`** RADOLAN vs. wrapper.
3. **`BEM-H03`** tip jar, yes or no.
4. **`data/` licence.** OSM-derived layers likely carry ODbL share-alike. LoD2-derived layers do not (dl-de/zero). Keeping those pipelines separate preserves your freedom on the shadow data — and an openly published Frankfurt shadow-geometry dataset may be a stronger portfolio artefact than the app around it.
