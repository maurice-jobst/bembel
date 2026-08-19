# BEMBEL — v1.0 Backlog (rev. 4 — hero repositioning 2026-08-13)

Free Rhein-Main city app for iPhone. Portfolio-grade, no backend of our own.
Feature selection rationale lives in `FEATURE-CATALOG.md`.

**This file is the spec — the "why" and the acceptance criteria for each
ticket.** Day-to-day tracking (assignee, status, PR links) lives in [GitHub
Issues](https://github.com/maurice-jobst/bembel/issues), one per `BEM-XXX`
below, labeled by epic/size/milestone. If the two ever disagree, this file
wins for scope and ACs; the issue wins for current status. `**done**` markers
below are a point-in-time note, not a live status — check the issue.

**Locked decisions**

| Decision | Value |
|---|---|
| Name | BEMBEL |
| Positioning | The app for a city that keeps getting hotter — shade, water, air, trees |
| Scope | Rhein-Main rings (`BEM-A04`). Shadow map is Frankfurt-only in v1.0 |
| Platform | iPhone only, iOS 18.5+, SwiftUI |
| Backend | None of our own. Static JSON + remote refresh with ETag. Operator datasets are CI + PR |
| Accounts | No BEMBEL accounts. Apple services (Game Center, iCloud) opt-in — revised 2026-08-13, "no accounts" was never locked |
| Base language | German, English v1.1, localisation scaffolding ships in v1.0 |
| Target ship | **22 March 2027** — World Water Day, Trinkbrunnen season opening |
| Navigation | Five tabs. Orte (Wasserhäuschen · Ebbelwei · Trinkbrunnen) first — ADR 0009 |

**Selection principles:** data readiness first, then coolness × feasibility; and best for AI-native development (ADR 0008 — deterministic, fixture-testable, no hosted service in the critical path). Four of the five classic features require zero curation.

**Hero (added 2026-08-13):** the bembel-data community layer is v1.0's flagship — Wasserhäuschen-Register + Ebbelwei-Wirtschaften register (read-only + rating funnel; write-side stays GitHub), provenance UX, Merkmale-first navigation, coverage game, and data-linked stickers (Datenspender/Verifizierer/Erste-Bewertung) + kiosk visit stamps. Pulled forward from epic S: `BEM-S04`, `BEM-S05`, `BEM-S11`, and the data-linked slice of `BEM-S01`. Scope of record: [hero-repositioning spec](superpowers/specs/2026-08-13-hero-repositioning-design.md). The Schattenkarte keeps its full scope; only the "signature feature" framing moved.
**Delivered 2026-08-14 (Phase 1b):** register loader (`BEM-S11`), both registers in the Orte tab with Merkmale navigation and provenance bylines (`BEM-S04`), rating/verify/report funnel, coverage game, data-linked stickers + opt-in kiosk stamps (`BEM-S01` slice). Plan of record: [2026-08-13-phase-1b-hero-app.md](superpowers/plans/2026-08-13-phase-1b-hero-app.md).

**NOT in v1.0** — voting, events calendar, parliament, elections, quizzes, the full Sticker-Sammelalbum (hotspot geofences, Game Center, seasonal drops), Kreppel ranking, price barometers, shade routing, Android, iPad. These live as post-1.0 side quests in [epic S](https://github.com/maurice-jobst/bembel/issues?q=label%3Aepic%3AS) (milestone M4).

---

## Milestones

| Milestone | Window | Exit criteria |
|---|---|---|
| **M0 — Skeleton** | Aug–Oct 2026 | App builds, navigates, renders one dataset on a map. CI green. |
| **M1 — Pipeline & geometry** | Oct–Dec 2026 | Data pipeline live. LoD2 extraction produces a loadable building index. |
| **M2 — Features** | Dec 2026–Feb 2027 | All v1.0 features functional (five classic + hero layer). Widget on home screen. |
| **M3 — Ship** | Mar 2027 | TestFlight → App Store by 22 March. Press sent. |

---

## EPIC A — Foundation

<a id="bem-a01"></a>
### BEM-A01 — Xcode project scaffold · `size:S` · M0 · **done**
Plain Xcode project, no Tuist/XcodeGen. SwiftUI lifecycle, iOS 18.5 target, SPM only, zero third-party deps unless a ticket justifies one.
Targets: `BEMBEL`, `BEMBELWidgets`, `BEMBELKit` (local Swift package — ADR 0004).
Also carries: secrets via gitignored xcconfig (ADR 0005), App Group entitlement on both targets (needed later by `BEM-C03`), MIT licence (ADR 0006).
**AC:** `make build` (`xcodebuild -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO`) passes from a clean checkout — `generic/platform`, not a named simulator, so CI doesn't depend on which runtimes happen to be installed on the runner.

<a id="bem-a02"></a>
### BEM-A02 — Design system · `size:M` · M0 · `learning-goal` · **done**
Salt-glaze grey, cobalt blue, diamond relief as texture motif. Tokens in `BEMBELKit`. Dark mode + Dynamic Type to 200% from day one.
Also scaffolds `Localizable.xcstrings` (German source language) — pulled forward from `BEM-H02` per the kickoff's "String Catalogs from commit one," not left as a retrofit.
**AC:** `DesignSystemPreview` renders every token. No hardcoded hex outside the token file.

<a id="bem-a03"></a>
### BEM-A03 — Navigation shell · `size:M` · M0 · **done**
`NavigationStack`, typed destinations, deep links (`bembel://shadow?t=2027-06-21T15:00`). Needed later by widgets and App Intents; cheap now. The parser is total — hostile/malformed URLs never trap or crash, they fall back to a graceful landing destination.
**AC:** Every feature reachable in ≤2 taps; every detail reachable by URL.

<a id="bem-a04"></a>
### BEM-A04 — Region model and selector · `size:M` · M0 · `needs-decision` · **done**
Every POI carries `ags` + `ring` ∈ {`frankfurt`, `kernraum`, `rheinmain`}. User-selectable, default `kernraum`. Ring membership is a JSON lookup table (`data/rings.json`), generated by `scripts/generate_rings.py` from the Destatis Gemeindeverzeichnis, never hand-typed or Swift code (ADR 0003). Departures ignore rings. kernraum = the 80 named Regionalverband FrankfurtRheinMain member municipalities; rheinmain = the Metropolregion FrankfurtRheinMain's 18 Landkreise + kreisfreie Städte.
**Resolved:** region definition decided 2026-08-13 (Regionalverband + Metropolregion, not the RMV tariff area or a hand-curated S-Bahn catchment). One sub-item still open — the Metropolregion's own page claims 8 kreisfreie Städte but only 7 are named anywhere found; shipped with 7, flagged in the script header.
**AC:** Ring switch filters every list and map without relaunch.

<a id="bem-a05"></a>
### BEM-A05 — Offline-first data layer · `size:L` · M0/M1 · `learning-goal` · **done**
Split in two per ADR 0002, not one generic mechanism: `Data/Curated` (bundled snapshot + conditional GET `If-None-Match` + Application Support override — Trinkbrunnen, rings, attribution, future operator datasets) and `Data/Live` (thin shared client, no bundling, no ETag — RMV, DWD, PEGELONLINE, HLNUG, NINA). A sixth *curated* dataset must be a data change, not a code change; live APIs were never going to fit that same generic shape without speculative generality.
**AC:** Airplane mode from cold install shows full curated data. Tests cover 200 / 304 / malformed / offline / 5xx / unknown-dataset for the curated store.

<a id="bem-a06"></a>
### BEM-A06 — CI · `size:S` · M0 · **done**
Build + test on PR (`ci.yml`), data schema validation job (`data-validate.yml`, stdlib-only Python, no pip install). SwiftLint config exists but isn't wired into CI yet — the codebase is small enough that it wasn't worth the runner time; revisit once EPIC B/C land.

---

## EPIC B — Data pipeline

<a id="bem-b01"></a>
### BEM-B01 — GeoJSON schema + validator · `size:M` · M1
Required: `id`, `name`, `geometry`, `ags`, `ring`, `sources[]`, `updated`.
**AC:** `make validate` fails on missing `ags` or unknown `ring`.

<a id="bem-b02"></a>
### BEM-B02 — Attribution registry · `size:S` · M1
`data/ATTRIBUTION.json` → in-app credits screen.
- HVBG LoD2: **dl-de/zero-2-0** — no attribution obligation, credit anyway
- Stadt Frankfurt open data: dl-de/by-2-0, source naming required
- OSM: ODbL, share-alike applies to derived data
- DWD: GeoNutzV · RMV: per their terms · PEGELONLINE: per WSV terms

<a id="bem-b03"></a>
### BEM-B03 — Publish workflow · `size:M` · M1
Actions → Pages or R2, manifest with per-dataset version + ETag.
**AC:** Merging a data PR updates the live manifest within 5 minutes.

<a id="bem-b04"></a>
### BEM-B04 — Operator dataset harness · `size:M` · M1 · `learning-goal`
Scaffolding for Tier C, built now, first used in v1.1: scheduled Action → agent → structured JSON → PR → human merge.
Hard rules encoded in the validator: **every row carries a source URL**, and the payload stores facts only, never scraped prose.
**AC:** A dry-run job opens a PR against a fixture source list and the validator rejects a row with no source.

---

## EPIC C — Departures

<a id="bem-c01"></a>
### BEM-C01 — RMV key + client · `size:M` · M2 · `blocked`
Register on the RMV open data portal **in week 1** — approval lag blocks the whole epic. Defensive decoding, fixtures for unit tests, key gitignored.
**AC:** Integration test hits a real stop and returns ≥1 departure.

<a id="bem-c02"></a>
### BEM-C02 — Nearby stops + departures view · `size:L` · M2
CoreLocation → nearest stops → departures, Anzeigetafel aesthetic, honest delay and staleness rendering.
**AC:** Cold launch to visible departures <2s on cellular.

<a id="bem-c03"></a>
### BEM-C03 — Pinned stops · `size:M` · M2
Local storage shared with the widget via App Group.

<a id="bem-c04"></a>
### BEM-C04 — Home Screen widget · `size:L` · M2 · `learning-goal`
WidgetKit + `AppIntentConfiguration` — stop and line filter chosen from the widget. Small/medium/large.
**AC:** Survives 24h on device without going blank. Reload policy documented in an ADR.

<a id="bem-c05"></a>
### BEM-C05 — Lock Screen accessory · `size:M` · M2

<a id="bem-c06"></a>
### BEM-C06 — Failure states · `size:M` · M2
Designed states for: no location permission, no network, RMV down, no departures, data older than 90s. No infinite spinners.

---

## EPIC D — Schattenkarte

Everything here is geometry; nothing rots. Full scope unchanged by the 2026-08-13 hero repositioning.

<a id="bem-d01"></a>
### BEM-D01 — LoD2 acquisition · `size:M` · M1
Pull the Frankfurt tile set from the HVBG Downloadcenter or the INSPIRE WFS (`geoportal.hessen.de/spatial-objects/831`). CityGML in, raw archive committed under `data/sources/` or fetched reproducibly by script.
**AC:** A documented, re-runnable command produces the same input set.

<a id="bem-d02"></a>
### BEM-D02 — Building index · `size:L` · M1 · `learning-goal`
CityGML → `(simplified footprint, ground height, ridge height)` in a compact binary with an R-tree. Budget: **≤15 MB for Frankfurt city**. Drop LoD1-quality objects below a height threshold; they add bytes and error.
**AC:** Viewport query for a 1km² area returns in <20ms on device.

<a id="bem-d03"></a>
### BEM-D03 — Solar position · `size:S` · M2
NOAA solar position algorithm. Pure function, exhaustively unit-testable against published values.
**AC:** Matches reference azimuth/elevation for 20 known place/time pairs within 0.1°.
Note for D04/D05: the scrubber's range is a **clock** range (05:00–22:00, wide enough for the
earliest Frankfurt sunrise and the latest sunset), not the sun's day — sunrise, sunset and solar
noon all move across the year and `SunModel` computes them rather than asserting them. The curve
drawn behind the scrubber is still the design's fixed bezier and no longer matches the real
elevation away from midsummer; redrawing it from `SunModel` belongs to D05.

<a id="bem-d04"></a>
### BEM-D04 — Shadow projection + rendering · `size:L` · M2 · `learning-goal`
Project shadow volumes for viewport buildings, render as a MapKit overlay. Continuous time scrubbing, not hourly snapshots.
**AC:** 60fps scrubbing on an iPhone 14. Flat memory over a 5-minute scrub.

<a id="bem-d05"></a>
### BEM-D05 — Time controls + "now" · `size:M` · M2
Date + time scrubber, snap-to-now, sunrise/sunset markers, a fast "when is this spot in shade today" readout.

<a id="bem-d06"></a>
### BEM-D06 — Accuracy disclosure · `size:S` · M2
Plain-language note on model limits: ~1m height accuracy, no balconies, no trees, no terrain shading in v1.0. Being upfront costs one screen and buys all the credibility.

---

## EPIC E — Free drinking water

<a id="bem-e01"></a>
### BEM-E01 — Fountain dataset · `size:M` · M1
Frankfurt Geoportal `Trink_Erfrischungsbrunnen` + OSM `amenity=drinking_water` + Refill partners, deduplicated, typed as `historisch` | `stadt` | `mainova` | `refill`.

<a id="bem-e02"></a>
### BEM-E02 — Seasonal state engine · `size:S` · M2
Date rules, no API: off from October; season opens 22 March; historic fountains after Easter; historic ones run 10:00–22:00. Computed movable-feast dates for Easter.
**AC:** "Running now / off for winter / opens 22 March" correct for any simulated date.

<a id="bem-e03"></a>
### BEM-E03 — Map, list, detail · `size:M` · M2
Distance sort, Apple Maps handoff, type filter, ring filter free from `BEM-A04`.
The fountain map now lives as the Trinkbrunnen segment of the Orte tab (ADR 0009) — same scope, new home in `App/Features/Places/`.

---

## EPIC F — Rain radar

<a id="bem-f01"></a>
### BEM-F01 — Radar client · `size:M` · M2
**Decided 2026-08-13 (ADR 0008):** parse DWD RADOLAN composites directly on-device, with checked-in binary fixtures for tests — no Bright Sky dependency (hosted service in the critical path of a no-backend app).

<a id="bem-f02"></a>
### BEM-F02 — Animated overlay · `size:L` · M2
Last ~2h in loop, play/pause/scrub, colourblind-safe scale.

---

## EPIC G — Stadtzustand

One screen, three trivial APIs. Cheapest utility-per-line-of-code in the project.

<a id="bem-g01"></a>
### BEM-G01 — Main-Pegel · `size:S` · M2
PEGELONLINE (WSV), no key, no registration. Frankfurt Osthafen gauge. Trend arrow, flood/low-water context.

<a id="bem-g02"></a>
### BEM-G02 — Air quality · `size:S` · M2
HLNUG stations. Nearest station, index, plain-language interpretation.

<a id="bem-g03"></a>
### BEM-G03 — Civil warnings · `size:S` · M2
NINA / warnung.bund.de, filtered to the user's ring. Read-only, no push in v1.0 — push means a server.

---

## EPIC H — Ship

<a id="bem-h01"></a>
### BEM-H01 — App Store presence · `size:M` · M3
Hero shot is the shadow map at 15:00 over the Bankenviertel. Category Reference. Screenshots, icon, keywords.

<a id="bem-h02"></a>
### BEM-H02 — Localisation audit · `size:S` · M2
String Catalog scaffolding shipped at `BEM-A02`/`BEM-A03` (German source language, from commit one — not a retrofit). This ticket is the sweep before ship: confirm every feature epic actually used it, zero hardcoded user-facing strings anywhere.
**AC:** Pseudo-locale build shows no untranslated strings.

<a id="bem-h03"></a>
### BEM-H03 — Tip IAP · `size:M` · M3 · `needs-decision`
StoreKit 2 consumables, or nothing. Decide deliberately by M2.

<a id="bem-h04"></a>
### BEM-H04 — Privacy + TestFlight · `size:S` · M3
"Data Not Collected", and mean it — no analytics SDK. 10–20 Rhein-Main beta testers.

<a id="bem-h05"></a>
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
2. ~~**`BEM-F01`** RADOLAN vs. wrapper.~~ Resolved 2026-08-13: RADOLAN direct (ADR 0008).
3. **`BEM-H03`** tip jar, yes or no.
4. **`data/` licence.** OSM-derived layers likely carry ODbL share-alike. LoD2-derived layers do not (dl-de/zero). Keeping those pipelines separate preserves your freedom on the shadow data — and an openly published Frankfurt shadow-geometry dataset may be a stronger portfolio artefact than the app around it.
