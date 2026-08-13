# BEMBEL — hero repositioning + pre-flip build (design)

Interviewed and approved 2026-08-13. Follows the bembel-data cold-start
brainstorm (docs/superpowers/brainstorms/2026-08-13-bembel-data-cold-start.md).
Supersedes the v1.0 scope section of the 2026-08-13 collaboration design and
the "five features, nothing else" lock where they conflict.

## 1. Repositioning & narrative

- **bembel-data + the community registers are the hero.** The Schattenkarte
  stays in v1.0 at full strength as a normal feature — demoted in narrative,
  not in scope.
- Framing: **showcase project** (for Maurice and the team once 1.0 ships),
  not "portfolio and learning project". "Written mostly by AI, reviewed by
  humans" is part of the story.
- Prior art (researched 2026-08-13): entries-in-git has niche precedent
  (Berlin-Vegan/berlin-vegan-data ~300 venues feeding apps; Gieß den Kiez =
  official base data + community layer, but backend+accounts; Karte von
  morgen/OpenFairDB = own Rust backend). **Ratings-as-PRs with the
  login=filename trust model has no findable analogue.** That is the pitch.
- Forkability for other regions is a **non-goal**: Frankfurt-first. Other
  cities fork the pattern because schemas and repo are clean, not because we
  built a framework.
- New ADR: **"best for AI-native development"** joins data-readiness as a
  selection principle — prefer deterministic, fixture-testable,
  service-independent choices during agent iteration. First application:
  RADOLAN direct over Bright Sky (operator decision 2026-08-13).
- Docs touched: README, BACKLOG.md, CHANGELOG, milestones/labels, memory.
  KICKOFF-PROMPT.md is retired to a historical note (describes a project
  shape that no longer exists).

## 2. v1.0 scope

The five original features unchanged (RMV departures + widgets,
Schattenkarte, Trinkbrunnen, Regenradar, Stadtzustand), **plus** the hero
layer:

- **Wasserhäuschen-Register** (pulls BEM-S04 forward, read-only + funnel):
  - map/list/detail with aggregated stars;
  - **Merkmale tags as primary navigation** ("spät offen", "Bänke draußen",
    "Ebbelwei", …) — not an afterthought filter sheet;
  - **provenance byline** on every entry: verified date, source link, last
    editor @handle, tap-through to the entry's GitHub history — the
    anti-Yelp identity move;
  - **in-app rating funnel**: "Bewerten" opens the prefilled GitHub
    issue-form/PR flow for that kiosk — the shipped app is the top of the
    rating funnel;
  - **coverage game**: unverified OSM-imported candidates render greyed with
    a "hilf mit, verifiziere dieses Häuschen" CTA; per-Stadtteil progress.
- **Ebbelwei-Wirtschaften register** (pulls BEM-S05 forward): second dataset
  through the same loader. Proves platform at launch (operator decision:
  both registers at 1.0).
- **Stickers** (partial BEM-S01 pull-forward):
  - data-linked: *Datenspender* (merged bembel-data PR, matched via
    contributors.json + optional GitHub-Benutzername in Settings),
    *Verifizierer*, *Erste-Bewertung*;
  - **kiosk visit stamps** via on-device visit detection at Wasserhäuschen
    locations;
  - full Sammelalbum (city hotspots, Game Center, seasonal drops) stays M4.
  - Guardrail update: the Datenspender sticker ships at 1.0, so it **may**
    be promised publicly at flip (supersedes the "don't promise before the
    Sammelalbum ships" guardrail).
- Privacy: visit detection is on-device region monitoring; nothing leaves
  the phone; App Store label stays **Data Not Collected**.
- Ship date **2027-03-22 unchanged**. Named risk: operator review bandwidth,
  not build capacity.

## 3. Architecture

Extends the ADR-0007 provider seam; no new patterns.

- `RegisterProviding` protocol + domain models (entry, rating, Merkmal,
  provenance) in BEMBELKit; `SampleRegisterProvider` fixtures like the
  existing seams.
- **BEM-S11 loader** follows the offline-first dataset pattern: bundled
  snapshot at build time, conditional GET (`If-None-Match`) against
  versioned bembel-data release bundles, last-good on malformed payload.
  `contributors.json` rides in the bundle.
- **Sticker engine** in BEMBELKit: rules as pure functions over
  (contributors.json match, local rating/verify state, visit log); state in
  the App Group store. Handle-squatting on the Settings field stays
  accepted (on-device only, harmless).
- **Rating funnel** = URL construction (prefilled GitHub issue-form/PR
  links). No auth, no API, no accounts.
- **Visit stamps**: CLMonitor/region monitoring, opt-in.
- Error handling inherits BEM-A05 semantics: offline → bundled data;
  malformed → last-good; candidates file missing → coverage game degrades
  to verified-only.
- Tests where they earn keep: loader (200/304/malformed/offline), RADOLAN
  parser against recorded binary fixtures, sticker rule functions, funnel
  URL builder. Not on SwiftUI view bodies.

## 4. Live providers (epics C–G)

- **RMV**: live provider against the documented API; key slot in
  Secrets.xcconfig (gitignored), sample fallback until the key exists.
  **Blocker Maurice owns: register the RMV Open Data key now** (issue #11) —
  the one thing AI cannot absorb.
- **Regenradar**: RADOLAN composite parsed on-device, checked-in binary
  fixtures for CI. No Bright Sky dependency.
- **Trinkbrunnen**: Geoportal + OSM + Refill with the existing
  FountainSeason engine.
- **Stadtzustand**: PEGELONLINE + HLNUG + NINA.
- **Schattenkarte**: LoD2 pipeline unchanged — biggest single technical
  chunk, built like any other feature.

## 5. bembel-data side

- New: Ebbelwei entry schema + Merkmale vocabulary (extends issue #3),
  rating deep-link templates the app funnel targets.
- Seed entries: AI-drafted **only with cited sources** (no-fabrication
  rule); Maurice merges.
- Issues #1–#3 **remain human starter tickets** — the team can work them
  privately pre-flip. The coverage game depends on #1 only softly
  (degrades to verified-only).

## 6. Build order & flip

Hero-first pipeline; one PR per feature; /code-review before each merge so
the team inherits a reviewable history.

1. **Phase 0** — docs/ADR/milestone repositioning (this spec's section 1).
2. **Phase 1 — hero**: loader, both registers, provenance, funnel, Merkmale
   navigation, coverage game, stickers.
3. **Phase 2 — live providers**: RMV, Trinkbrunnen, RADOLAN, Stadtzustand,
   Schattenkarte.
4. **Phase 3 — polish**: widgets, Dynamic Type/dark-mode audit, App Store
   prep.
5. **Flip at feature-complete** — one launch moment with a working app.
   The cold-start clock (IRL event, 30-day first-time-rater count) starts
   at flip. Team invites stay active meanwhile; humans join for review,
   polish, data curation, and community.

## Out of scope

Full Sammelalbum / Game Center / seasonal drops (M4), English localization
(v1.1), any region beyond Frankfurt for the registers, operator-dataset
barometers (harness only, BEM-B04), quizzes (dropped).
