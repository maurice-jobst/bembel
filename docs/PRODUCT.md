# BEMBEL — Product

The scope of record. What the app is, for whom, what is in v1.0 and what is
not, and the gates that decide it. [BACKLOG.md](BACKLOG.md) maps epics to
issues; [../GOVERNANCE.md](../GOVERNANCE.md) says who decides; the ADRs in
[adr/](adr/) carry the rationale. When this file and an ADR disagree, the ADR
wins and this file has a bug. Revised 2026-09-26.

## 1. One paragraph

**BEMBEL is a free iPhone app for Frankfurt and Rhein-Main, für eine Stadt,
die heißer wird — Wasser, Luft, Regen.** It puts open data the city already
publishes into one place you can use on a street corner: where the drinking
water is and whether it is running today, whether rain is about to arrive,
what the air and the river are doing, where the sun is. Its flagship is a
community register of Wasserhäuschen and Ebbelwei-Wirtschaften whose entries
and ratings arrive as pull requests, with the provenance shown in the app.
No backend, no accounts, no tracking. German first. Ships 22 March 2027.

## 2. Two audiences, ranked

1. **The reader.** Engineering leadership looking at how a small team ships
   an app whose code is mostly agent-written and human-reviewed. They read
   the ADRs, the provider seam, the CI discipline, `AI-NATIVE.md` — and the
   app is the evidence that it held ([ADR 0010](adr/0010-portfolio-artefact-over-product.md)).
2. **The user.** Someone in Frankfurt on a hot afternoon, and the
   Frankfurt tech × kiosk-culture overlap who will rate a Wasserhäuschen
   with a pull request.

When the two conflict, the reader wins. That is why v1.0 is smaller and
better documented than a product plan would make it, and why the App Store
release is the floor, not the ceiling: an artefact that never shipped is
discounted no matter how well it reads.

## 3. Principles

| # | Principle | Where it is decided | What it rules out |
|---|---|---|---|
| 1 | **Portfolio over product** | ADR 0010 | Breadth for its own sake; the "super-app" and platform directions before v1.0 |
| 2 | **Data readiness first** | [FEATURE-CATALOG.md](FEATURE-CATALOG.md) | Features whose data needs curation before it can be shown |
| 3 | **Best for AI-native development** | [ADR 0008](adr/0008-ai-native-selection-principle.md) | Hosted wrappers in the critical path; anything not testable against a checked-in fixture |
| 4 | **No backend, no accounts** | [ADR 0001](adr/0001-no-backend-static-data.md) | Servers, proxies, key-hiding middleware, sign-in |
| 5 | **Data Not Collected, literally** | ADR 0001, [SECURITY.md](../SECURITY.md) | Analytics, crash SDKs, location leaving the device |
| 6 | **Provenance over anonymity** | [hero spec](specs/2026-08-13-hero-repositioning-design.md) | Anonymous ratings; a rating not tied to a GitHub account |
| 7 | **Facts, not prose; a source URL per row** | CONTRIBUTING, `validate_data.py` | Scraped text in datasets; a curated row nobody can trace |
| 8 | **Honest numbers** | [AI-NATIVE.md](AI-NATIVE.md) | Fabricated sample values on real maps; a field nobody can compute, approximated |
| 9 | **Five tabs, Orte first** | [ADR 0009](adr/0009-registers-in-one-places-tab.md) | A sixth tab; a "More" overflow |
| 10 | **German first, English v1.1** | kickoff, BACKLOG | English-only strings; strings outside the catalog |
| 11 | **One team can finish it** | ADR 0010, GOVERNANCE §6 | Scope that needs a second maintainer to survive |

## 4. Scope of record — v1.0

Status as of the revision date; the issue is authoritative when they differ.

| Feature | Tab | Data | Status |
|---|---|---|---|
| Wasserhäuschen-Register: map, Merkmale navigation, provenance byline, rating funnel, coverage game | Orte | bembel-data (ODbL) | **shipped** (#39, #46) |
| Ebbelwei-Wirtschaften register | Orte | bembel-data | **shipped** (#40) |
| Sticker: Datenspender, Verifizierer, Erste Bewertung; Kiosk-Stempel (When-In-Use, on device) | Orte / Settings | contributors.json + local visits | **shipped** (#105 decided the reach) |
| Trinkbrunnen with seasonal state engine, sampled vs unsampled | Orte | Frankfurt Geoportal WFS + OSM | **shipped** (#23–#25) |
| RMV departures + Home/Lock Screen widgets, failure states | Abfahrten | RMV Open Data (key) | **gated** — see §5 (#11–#16) |
| Sonnenstand: NOAA ephemeris, time scrubber, accuracy disclosure | Sonne | computed on device | **shipped** (#19, #21, #22, #92) |
| Regenradar: past hour + 2 h nowcast, animated, scrubbable, colour-blind-safe scale | Regen | DWD RADOLAN RY + RV | **shipped** (#26, #27, #99) |
| Regen-Widget „Regnet's gleich?" | Widgets | DWD RADOLAN RV | **in review** (#123) |
| Stadtzustand: Main-Pegel, Luft, Temperatur, Pollen, Warnungen — one state per source | Stadt | PEGELONLINE, UBA, DWD, DWD, NINA | **shipped** (#28–#30, #71, #77, #91) |
| Data pipeline: schema, validator, mirror gate, source registry, weekly liveness + drift | — | — | **shipped** (#7, #69, #70, #122); publish workflow and attribution registry open (#8, #9, #10) |
| LoD2 building geometry as a published dataset | — | HVBG, dl-de/zero | **open**, own repo (#17, #18) |
| Ship: App Store presence, localisation audit, privacy + TestFlight, outreach, `AI-NATIVE.md` | — | — | #90 done; #31, #32, #34, #35 open; #33 tip jar `needs-decision`; #124 Siri first to cut |

**Not in v1.0, by decision:** Schattenkarte rendering and Schattenroute
(v1.2, ADR 0010), English (v1.1), Sammelalbum with Game Center and seasonal
drops (M4), operator-dataset barometers beyond the harness (M4), every
register beyond Frankfurt, quizzes, everything in epic S (#36–#45, #72–#75,
#125, #126).

**Known state of the hero data.** The register is in its cold-start phase:
the bundled snapshot carries a handful of entries and no verified ones yet.
The plan of record is the
[cold-start brainstorm](history/2026-08-13-bembel-data-cold-start-brainstorm.md):
seed entries near-complete from OSM as `verified: false` candidates, then a
verification pass and an IRL mapping evening at the public flip. Until the
seed import lands in bembel-data, the coverage game is the honest face of an
empty room, and the app says so rather than hiding it.

## 5. Gates and dates

| Gate | Date | Rule |
|---|---|---|
| **RMV key** (`BEM-C01`, #11) | 1 Dec 2026 | No key by then and epic C leaves v1.0. Departures do not ship on sample data. The tab bar goes to four; the rain widget (#123) keeps a Home Screen widget in the release. |
| **Tip jar** (#33) | by M2 | Yes or no; the Hamburg comp shows it coexists with *Data Not Collected*. |
| **External TestFlight beta** | 31 Oct 2026 | Internal testers as soon as the App Store Connect record exists ([TESTFLIGHT.md](TESTFLIGHT.md)). |
| **M2 exit** | Feb 2027 | Every v1.0 feature live; a widget on the Home Screen. |
| **Ship** | **22 Mar 2027** | World Water Day, fountain season opening. The date does not move; scope does, in the BACKLOG's "first to cut" order. |
| **Epic S cap** | until ship | No new data-source ticket. New upstreams enter `data/sources.json` as research only. |

## 6. Definition of ready — what a feature needs to enter

A ticket is not scheduled until all of these hold. They are in the order
they usually fail.

1. **The upstream is registered** in `data/sources.json` with licence,
   tier, cadence and a `verified_at` from a real request — and the
   verifier can plan a check for it (`make test-data` proves that offline).
2. **The licence is attributable** in-app, and share-alike consequences
   (ODbL) are understood for anything derived from OSM.
3. **There is a fixture story:** the feature can be tested against
   checked-in data with no network (ADR 0008). No fixture, no feature.
4. **It reads a provider protocol** from BEMBELKit and has a failure state
   of its own ([ADR 0007](adr/0007-provider-seam.md)); one dead upstream
   never blanks a neighbour.
5. **It fits an existing tab or segment.** A sixth tab is not an option
   (ADR 0009).
6. **Its rot is named.** How fast does it decay if nobody touches it for a
   year, and who would notice? "None" is a fine answer; "unknown" is not.
7. **It is written up as a self-contained issue** — scope, rationale,
   acceptance criteria, lane — and gets its labels and a BACKLOG row.

## 7. Definition of done — what a change needs to leave

- One commit per ticket, `BEM-XXX:` prefix; the PR closes the issue.
- `make test`, `make validate` (and `make test-data` when the validator
  changed) green; `make format-check` clean; the app builds in CI.
- German strings in `Localizable.xcstrings`; no `Text(verbatim:)` for
  user-facing copy in the app target.
- Every state the feature can be in is designed: loading, empty, offline,
  stale, source down, permission denied. The Regenradar and Stadtzustand
  screens are the reference.
- Numbers on screen are measurements or computations, never placeholders.
- Fixtures captured from real responses; generated files regenerated by
  their script, never hand-edited; both mirrored copies updated.
- CHANGELOG entry in the same PR. ADR if the decision is expensive to
  reverse. Docs that mention the old behaviour updated.
- A change touching a system framework (CoreLocation, WidgetKit, MapKit)
  was watched in a running simulator, because CI cannot.

## 8. Quality bars that are not negotiable

- **Privacy label stays *Data Not Collected*.** Verified by architecture,
  not by policy: there is nothing to send data to.
- **Works offline from the bundle.** Curated data is bundled and refreshed
  by conditional GET; the app never shows an empty map because the network
  was slow.
- **Accessible by default.** Dynamic Type on every screen; the radar's
  rain scale is monotone and single-hue because the usual green-yellow-red
  is the worst possible choice for red-green colour-vision deficiency —
  that reasoning generalises to every legend.
- **Honest about accuracy.** Where a number has a convention behind it
  (the sunset horizon, a station 12 km from the Innenstadt), the screen
  says so ("Wie genau ist das?").
- **Bundle size stays boring.** No dataset over a few hundred KB ships in
  the app; bigger data is a separate published dataset.

## 9. After 1.0

| Release | Headline | Hook |
|---|---|---|
| v1.1 | English localisation | — |
| v1.2 | Schattenkarte rendering + Schattenroute (#20) | 22 March's anniversary logic; June 2027 |
| v1.3 | Frankfurthenge | pure geometry, annual photo moment |
| v1.4 | Preisbarometer engine: Glühwein-Index first | Nov 2027, first operator dataset |
| v1.5+ | one Tier-D feature from the catalogue per release | — |

Epic S side quests (#36–#45, #72–#75, #125, #126) are pulled from M4 into a
release only after v1.0 ships, in the order the FEATURE-CATALOG ranks them.

## 10. Measures — honest ones

There are no in-app metrics and there will be none. What can be read
without collecting anything:

- bembel-data: entries, verified entries, first-time rating PRs in the 30
  days after the public flip (the cold-start test), number of contributors
  in `contributors.json`.
- App Store: ratings and written reviews; TestFlight feedback.
- Repository: weekly sweep green, time from ticket to merge, share of
  commits with a `Co-Authored-By` trailer (AI-NATIVE §6).
- Press: whether the 22 March hook lands — one regional outlet linking the
  app on launch day is the success criterion for #35.

## 11. Decision index

| ADR | Decision | One line |
|---|---|---|
| [0001](adr/0001-no-backend-static-data.md) | No backend | Bundled datasets + conditional GET; live APIs called from the device; names the two observations that would reopen it |
| [0002](adr/0002-curated-vs-live-data-split.md) | Two data mechanisms | `DatasetStore` for curated data, thin `HTTPClient` for live; nothing generic over things that are not alike |
| [0003](adr/0003-region-model-rings-and-ags.md) | Region model | AGS-keyed municipalities in three rings, generated from Destatis |
| [0004](adr/0004-bembelkit-as-local-package.md) | BEMBELKit as local package | Synced-folder Xcode project; tests run on macOS without a simulator |
| [0005](adr/0005-secrets-and-open-source-build.md) | Secrets | Gitignored xcconfig; a clean checkout builds unsigned |
| [0006](adr/0006-code-licence-mit.md) | MIT code licence | Data carries its own licences |
| [0007](adr/0007-provider-seam.md) | Provider seam | One protocol per upstream; views never call a source |
| [0008](adr/0008-ai-native-selection-principle.md) | AI-native selection | Deterministic, fixture-testable, no hosted third party |
| [0009](adr/0009-registers-in-one-places-tab.md) | One Orte tab | Five tabs, hero first, segments not tabs |
| [0010](adr/0010-portfolio-artefact-over-product.md) | Portfolio over product | The tie-breaker; Schattenkarte rendering to v1.2; Epic S cap; the C01 gate |
