# BEMBEL — Backlog index (v1.0 → 22 March 2027)

One GitHub Issue per `BEM-XXX` ticket is the spec **and** the status: every
body is a self-contained brief with scope, acceptance criteria and lane. This
file is only the map from epic to issue; nothing here outranks an issue.
Decisions with rationale: [adr/](adr/); who decides and how:
[../GOVERNANCE.md](../GOVERNANCE.md); scope of record and gates:
[PRODUCT.md](PRODUCT.md). Why the features were chosen:
[FEATURE-CATALOG.md](FEATURE-CATALOG.md); what the Hamburg comp has that we could
reuse: [research/2026-09-franzbroetchen.md](research/2026-09-franzbroetchen.md). Hero framing:
[hero-repositioning spec](specs/2026-08-13-hero-repositioning-design.md).

## Locked (ADR 0008, 0009, 0010)

Portfolio artefact first, product second. Für eine Stadt, die heißer wird —
Wasser, Luft, Regen. iPhone only, iOS 18.5+, no backend, no BEMBEL accounts,
German first (English v1.1). Five tabs, Orte first. Shadow *rendering* is out
of v1.0; the LoD2 geometry ships as a published dataset in its own repo. Epic
S is capped until v1.0 ships: no new data-source ticket before the App Store
release.

## Milestones

| Milestone | Window | Exit |
|---|---|---|
| M0 Skeleton | Aug–Oct 2026 | Builds, navigates, one dataset on a map, CI green — **done** |
| M1 Pipeline & geometry | Oct–Dec 2026 | Publish workflow live; LoD2 geometry published as its own dataset |
| M2 Features | Dec 2026–Feb 2027 | Every v1.0 feature live; widget on the home screen |
| M3 Ship | Mar 2027 | App Store by 22 March; press sent |
| M4 Side quests | post-1.0 | Epic S and everything ADR 0010 cut |

TestFlight runs ahead of M3: internal testers once the App Store Connect
record exists, external beta 31 Oct 2026 ([TESTFLIGHT.md](TESTFLIGHT.md)).
**`BEM-C01` gate 1 Dec 2026:** no RMV key by then and epic C leaves v1.0 —
departures do not ship on sample data.

## Epics → issues

| Epic | Done | Open |
|---|---|---|
| A Foundation | #1 #2 #3 #4 #5 #6 | — |
| B Data pipeline | #7 schema + validator · #70 DataSourcesView from the registry | #8 attribution registry · #9 publish workflow · #10 operator harness · #122 drift check: collapse short of zero, volatile layers |
| C Departures (RMV) | — | #11 key + client (`blocked`) · #12 nearby stops · #13 pinned stops · #14 Home Screen widget · #15 Lock Screen · #16 failure states |
| D Sonnenstand / LoD2 | #19 solar position · #21 time controls · #22 accuracy disclosure · #92 Schatten → Sonnenstand | #17 LoD2 acquisition · #18 building dataset · #20 shadow rendering (v1.2) |
| E Drinking water | #23 dataset · #24 seasonal engine · #25 map, list, detail | — |
| F Rain radar | #26 RADOLAN client · #27 overlay · #99 RY past hour | #123 rain widget (M2, hedge for the C01 gate; PR #127 in review) |
| G Stadtzustand | #28 Main-Pegel · #29 air quality · #30 NINA · #71 Pollen · #77 per-source state · #91 live temperature | #76 Wasser & Hitze (M4, scope entschieden — Unterbildschirm vom Stadtzustand, Pegel + sensor_community, Klimaplanatlas/Starkregen vorerst raus) |
| H Ship | #90 AI-NATIVE.md | #31 App Store presence · #32 localisation audit · #33 tip jar (`needs-decision`) · #34 privacy + TestFlight · #35 outreach · #124 Siri & Kurzbefehle (M3, first to cut) |
| S Side quests | #39 Wasserhäuschen-Register · #40 Ebbelwei · #46 bundle loader (hero, pulled into v1.0) | #36 #37 #38 #41 #42 #43 #44 #45 #72 #73 #74 #75 #125 #126 (all M4) |

Operations issues (source-liveness reports, branch protection, repo hygiene)
carry no epic and are not indexed here; the weekly sweep files and closes its
own. Open ones are listed under the
[`area:data`](https://github.com/maurice-jobst/bembel/issues?q=is%3Aopen+label%3Aarea%3Adata+-label%3Aepic%3AS)
filter or have no label at all.

## Releases after 1.0

v1.1 English · v1.2 Schattenkarte rendering + Schattenroute (#20, June 2027) ·
v1.3 Frankfurthenge · v1.4 Preisbarometer engine + Glühwein-Index (Nov 2027) ·
v1.5+ one Tier-D feature from FEATURE-CATALOG.md per release.

## Open decisions

1. #33 tip jar — yes or no, decided by M2 (`needs-decision`).
2. #45, #73, #75 side quests marked `needs-decision` — ToS or onboarding
   questions that stay parked until after v1.0 (Epic S cap, ADR 0010).

Decided since the last revision: the Sonnenstand tab symbol is
`sun.max.fill` (verified in SF Symbols, `App/RootView.swift`); Kiosk-Stempel
stay When-In-Use (#105); `enforce_admins` is on (#106).
