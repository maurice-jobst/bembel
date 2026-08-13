# BEMBEL

A free iPhone city app for Frankfurt / Rhein-Main. Open data that already
exists but is unusable in practice, made accessible in one place — for a city
that keeps getting hotter: shade, water, air.

Free. No ads, no tracking, no BEMBEL backend and no BEMBEL accounts —
Apple services (Game Center, iCloud) and GitHub participation are opt-in.
The App Store privacy label says "Data Not Collected" and it is true.

Named after the Apfelwein jug: grey salt-glazed stoneware, cobalt diamond
relief.

## v1.0 — five features, nothing else

| Feature | Data source |
|---|---|
| RMV departures + Home/Lock Screen widgets | RMV Open Data API |
| **Schattenkarte** — on-device shadow map with time scrubbing | Hessen LoD2 building model (DL-DE Zero) |
| Free drinking water, with seasonal state engine | Frankfurt Geoportal, OSM, Refill |
| Rain radar | DWD open data |
| Stadtzustand — Main level, air quality, civil warnings | PEGELONLINE, HLNUG, NINA |

Ship target: 22 March 2027 (World Water Day).

## Architecture

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

## Building

Requires Xcode 16.4+ (iOS 18.5 SDK).

```
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

## Beyond 1.0

v1.0 stays five features. The horizon is
[epic S — side quests](https://github.com/maurice-jobst/bembel/issues?q=label%3Aepic%3AS):
a sticker album for visited hotspots, GrünGürtel walks, Wasserhäuschen and
Ebbelwei registers fed by a community data repo
([bembel-data](https://github.com/maurice-jobst/bembel-data) — reviews as
pull requests), Baumkataster, Stolpersteine, and more.

## Team

Three lanes: PM/architecture ([@maurice-jobst](https://github.com/maurice-jobst)),
frontend ([@cybeerboy](https://github.com/cybeerboy) — app, widgets),
backend ([@jaypikay](https://github.com/jaypikay),
[@monsdroid](https://github.com/monsdroid) — data pipeline, `data/`,
`scripts/`, CI). See [CONTRIBUTING.md](CONTRIBUTING.md) for the working
agreement.

## Licences

Code is [MIT](LICENSE). Bundled data carries its sources' licences —
attribution in `data/ATTRIBUTION.json`, rendered in-app. Note: datasets
derived from OpenStreetMap are ODbL, which is share-alike.
