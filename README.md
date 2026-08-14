# 🍎 BEMBEL

**A free iPhone city app for Frankfurt and Rhein-Main.** Open data that already
exists but is unusable in practice, made accessible in one place — for a city
that keeps getting hotter: shade, water, air.

![Platform: iOS 18.5+](https://img.shields.io/badge/iOS-18.5%2B-000000?style=flat-square&logo=apple&logoColor=white)
![Swift + SwiftUI](https://img.shields.io/badge/Swift-SwiftUI-F05138?style=flat-square&logo=swift&logoColor=white)
[![Code: MIT](https://img.shields.io/badge/Code-MIT-green?style=flat-square)](LICENSE)
![Dependencies: none](https://img.shields.io/badge/dependencies-none-blue?style=flat-square)
![Privacy: Data Not Collected](https://img.shields.io/badge/privacy-Data%20Not%20Collected-6f42c1?style=flat-square)
![Ship target: 22 March 2027](https://img.shields.io/badge/v1.0-22%20March%202027-orange?style=flat-square)

<!-- At the v1.0 public flip: add the CI and data-validation status badges.
     shields.io and GitHub's own badge.svg cannot read a private repo. -->

Free. No ads, no tracking, no BEMBEL backend and no BEMBEL accounts —
Apple services (Game Center, iCloud) and GitHub participation are opt-in.
The App Store privacy label says "Data Not Collected" and it is true.

Named after the Apfelwein jug: grey salt-glazed stoneware, cobalt diamond
relief.

## 🥤 The hero: community data, wie Yelp — nur in GitHub

BEMBEL's flagship is the **Wasserhäuschen-Register** (plus the
**Ebbelwei-Wirtschaften register**), powered by
[bembel-data](https://github.com/maurice-jobst/bembel-data):
community-maintained datasets where entries and ratings are pull requests.

- **Provenance over anonymity.** Every entry shows who verified it, when,
  from which source — one tap to its full GitHub history. No anonymous
  star soup.
- **Ratings you can trust.** One rating per GitHub account per entry, enforced
  by CI: [`check_authorship.py`](https://github.com/maurice-jobst/bembel-data/blob/main/scripts/check_authorship.py)
  rejects any pull request that touches a rating file named for someone else,
  with no proxy path for maintainers either. We have not found this trust model
  built out of GitHub primitives anywhere else.
- **The app is the funnel.** "Bewerten" in the app opens a prefilled
  GitHub flow for that kiosk; contributors earn in-app sticker credit
  (Datenspender) — no BEMBEL accounts, no backend, the privacy label
  stays "Data Not Collected".
- **Built and shipped.** Both registers live in the **Orte** tab (position
  one, ADR 0009) with Merkmale as the navigation, a provenance byline on
  every entry, the coverage game per Stadtteil, and the Sammlung with
  data-linked stickers plus opt-in kiosk visit stamps.

## 📱 v1.0

| Feature | Data source |
|---|---|
| **Wasserhäuschen-Register** — ratings, Merkmale, provenance, rating funnel, coverage game | [bembel-data](https://github.com/maurice-jobst/bembel-data) (community, ODbL) |
| **Ebbelwei-Wirtschaften register** | [bembel-data](https://github.com/maurice-jobst/bembel-data) |
| Sticker — Datenspender/Verifizierer/Erste-Bewertung + Kiosk-Stempel | contributors.json + on-device visits |
| RMV departures + Home/Lock Screen widgets | RMV Open Data API |
| Schattenkarte — on-device shadow map with time scrubbing | Hessen LoD2 building model (DL-DE Zero) |
| Free drinking water, with seasonal state engine | Frankfurt Geoportal, OSM, Refill |
| Rain radar | DWD open data (RADOLAN, parsed on-device) |
| Stadtzustand — Main level, air quality, civil warnings | PEGELONLINE, HLNUG, NINA |

Ship target: 22 March 2027 (World Water Day). Scope of record:
[hero-repositioning spec](docs/superpowers/specs/2026-08-13-hero-repositioning-design.md).

## 🏗️ Architecture

```mermaid
flowchart TD
    C["bembel-data<br/>community pull requests"] -->|"CI: schema · source · authorship"| R["Release bundle<br/>versioned, ODbL"]
    subgraph device["iPhone — no BEMBEL backend, no BEMBEL accounts"]
        V["Views · SwiftUI"] --> P["Provider protocols<br/>BEMBELKit"]
        P --> B["Bundled snapshot<br/>refreshed by conditional GET"]
        P --> L["Live open data, called from the device<br/>RMV · DWD · PEGELONLINE · HLNUG · NINA"]
    end
    R --> B
```

- **iOS 18.5+, SwiftUI, iPhone only.** Plain Xcode project, no generators.
- Three targets: `BEMBEL` (app), `BEMBELWidgets` (widget extension),
  `BEMBELKit` (local Swift package — design system, navigation, region model,
  data layer).
- **No backend.** Curated datasets are bundled at build time and refreshed at
  runtime via conditional GET against a static manifest. Live APIs (RMV, DWD,
  PEGELONLINE, HLNUG, NINA) are called directly from the device.
- **Provider seam** ([ADR 0007](docs/adr/0007-provider-seam.md)): each feature
  reads a protocol from BEMBELKit; today's implementations are sample
  fixtures, replaced live source by live source without touching views.
- No third-party dependencies.
- German is the base language; all strings go through String Catalogs.

Decisions that would be expensive to reverse are recorded in
[docs/adr/](docs/adr/). The backlog lives in [docs/BACKLOG.md](docs/BACKLOG.md)
as the spec; day-to-day status is tracked in
[GitHub Issues](https://github.com/maurice-jobst/bembel/issues) and
[Milestones](https://github.com/maurice-jobst/bembel/milestones)
(M0 Skeleton → M1 Pipeline & geometry → M2 Features → M3 Ship).

## 🤖 How it is built

AI agents author the implementation; a human reviews every pull request; CI
enforces what a reviewer should never have to check by hand — formatting,
schema conformance, and the data-provenance rules. That split is the doctrine
this project runs on: **AI at the edges, deterministic core.** It also drives
technical selection — where two options are equally good for a human, we take
the one an agent can work in safely
([ADR 0008](docs/adr/0008-ai-native-selection-principle.md)).

| Gate | What runs |
|---|---|
| Format | `make format-check` — swift-format, bundled with Xcode |
| Tests | `swift test` on BEMBELKit, natively on macOS, no simulator |
| App build | `xcodebuild`, iOS Simulator, unsigned |
| Data | `make validate` — schemas, generated-file equality, source URLs |
| Community data | schema + authorship checks in [bembel-data](https://github.com/maurice-jobst/bembel-data) |

## 🔨 Building

Requires Xcode 16.4+ (iOS 18.5 SDK).

```bash
cp Config/Secrets.xcconfig.template Config/Secrets.xcconfig
# fill in BEMBEL_TEAM_ID (and later RMV_API_KEY) — the file is gitignored
make build         # xcodebuild, iOS Simulator, no signing
make test          # BEMBELKit unit tests via swift test (no simulator needed)
make validate      # data schema validation
make format        # swift-format (bundled with Xcode) — run before pushing
make format-check  # the same check CI runs
```

`BEMBELKit` also compiles for macOS — not for a Mac app, but so `swift test`
runs natively on any machine and in CI without booting a simulator.

## 🔭 Beyond 1.0

The horizon is
[milestone M4 — side quests](https://github.com/maurice-jobst/bembel/milestone/5):
the full Sticker-Sammelalbum (city-hotspot geofences, Game Center, seasonal
drops — the data-linked stickers ship in 1.0), GrünGürtel walks,
Baumkataster, Stolpersteine, Blaulicht-Archiv, and more. English
localization is v1.1.

## 👥 Team

Three lanes: PM/architecture ([@maurice-jobst](https://github.com/maurice-jobst)),
frontend ([@cybeerboy](https://github.com/cybeerboy) — app, widgets),
backend ([@jaypikay](https://github.com/jaypikay),
[@monsdroid](https://github.com/monsdroid) — data pipeline, `data/`,
`scripts/`, CI). See [CONTRIBUTING.md](CONTRIBUTING.md) for the working
agreement.

## ⚖️ Licences

Code is [MIT](LICENSE). Bundled data carries its sources' licences —
attribution in `data/ATTRIBUTION.json`, rendered in-app. Note: datasets
derived from OpenStreetMap are ODbL, which is share-alike.

---

Led by [Maurice Jobst](https://maurice-jobst.github.io/) as PM and architect.
The same doctrine applied to knowledge work is written up in
[ai-workbench](https://github.com/maurice-jobst/ai-workbench).
