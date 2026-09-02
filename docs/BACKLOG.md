# BEMBEL — Backlog index (v1.0 → 22 March 2027)

One GitHub Issue per `BEM-XXX` ticket is the spec **and** the status: every
body is a self-contained brief with scope, acceptance criteria and lane. This
file is only the map from epic to issue; nothing here outranks an issue.
Decisions with rationale: [adr/](adr/). Why the features were chosen:
[FEATURE-CATALOG.md](FEATURE-CATALOG.md). Hero framing:
[hero-repositioning spec](superpowers/specs/2026-08-13-hero-repositioning-design.md).

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
| B Data pipeline | #7 schema + validator | #8 attribution registry · #9 publish workflow · #10 operator harness · #70 DataSourcesView from the registry |
| C Departures (RMV) | — | #11 key + client (`blocked`) · #12 nearby stops · #13 pinned stops · #14 Home Screen widget · #15 Lock Screen · #16 failure states |
| D Sonnenstand / LoD2 | #19 solar position · #21 time controls · #22 accuracy disclosure · #92 Schatten → Sonnenstand | #17 LoD2 acquisition · #18 building dataset · #20 shadow rendering (v1.2) |
| E Drinking water | #23 dataset · #24 seasonal engine · #25 map, list, detail | — |
| F Rain radar | #26 RADOLAN client · #27 overlay · #99 RY past hour | — |
| G Stadtzustand | #28 Main-Pegel · #29 air quality · #30 NINA · #77 per-source state · #91 live temperature | #71 Pollen (M4) · #76 Wasser & Hitze (M4, `needs-decision`) |
| H Ship | #90 AI-NATIVE.md | #31 App Store presence · #32 localisation audit · #33 tip jar (`needs-decision`) · #34 privacy + TestFlight · #35 outreach |
| S Side quests | #39 Wasserhäuschen-Register · #40 Ebbelwei · #46 bundle loader (hero, pulled into v1.0) | #36 #37 #38 #41 #42 #43 #44 #45 #72 #73 #74 #75 (all M4) |

Unlabelled operations: #102 source liveness, #105 kiosk-stamp auth,
#106 branch protection `enforce_admins`.

## Releases after 1.0

v1.1 English · v1.2 Schattenkarte rendering + Schattenroute (#20, June 2027) ·
v1.3 Frankfurthenge · v1.4 Preisbarometer engine + Glühwein-Index (Nov 2027) ·
v1.5+ one Tier-D feature from FEATURE-CATALOG.md per release.

## Open decisions

1. #33 tip jar — yes or no, decided by M2.
2. Sonnenstand tab symbol — `building.2.fill` described the shadow-casting
   buildings; the replacement is verified in SF Symbols before it is committed.
