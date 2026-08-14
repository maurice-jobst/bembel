# Changelog

All notable changes to BEMBEL. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[SemVer](https://semver.org) with 0.x meaning "pre-App-Store".

## [Unreleased]

### Added

- Wasserhäuschen- und Ebbelwei-Register aus bembel-data: Karte, Merkmale-Navigation,
  Detailkarte mit Provenienz-Zeile (geprüft am, letzte Bearbeitung, Link in die
  Git-Historie).
- In-App-Trichter: „Bewerten“, „verifizieren“ und „Ort melden“ öffnen vorausgefüllte
  GitHub-Flows — ohne Konto, ohne Token, ohne Backend.
- Abdeckungsspiel: ungeprüfte Einträge als graue Kandidaten, Fortschritt je Stadtteil.
- Sticker: Datenspender, Verifizierer, Erste Bewertung (über den GitHub-Benutzernamen
  aus den Einstellungen) sowie Kiosk-Stempel per opt-in Standorterkennung auf dem Gerät.
- BEM-S11-Loader: gebündelter Snapshot, Conditional GET gegen das veröffentlichte
  bembel-data-Bundle, Datenstand in den Einstellungen.

### Changed

- Der Trinkwasser-Tab ist im neuen **Orte**-Tab aufgegangen (ADR 0009); Trinkbrunnen
  bleiben unverändert im Funktionsumfang. `bembel://water` funktioniert weiter.

- Repositioned around the bembel-data hero: Wasserhäuschen + Ebbelwei
  registers, rating funnel, provenance UX, and data-linked stickers join
  the v1.0 scope (spec 2026-08-13); Schattenkarte remains a full v1.0
  feature without the "signature" framing.
- ADR 0008: "best for AI-native development" selection principle; radar
  will parse RADOLAN directly (no Bright Sky dependency).
- KICKOFF-PROMPT retired to docs/history/.

## [0.1.0] — 2026-08-13

The collaboration-ready sample-data shell.

### Added

- All five v1.0 screens (Abfahrten, Schattenkarte, Trinkwasser, Regenradar,
  Stadtzustand) implemented from the Claude Design project, on sample data.
- Onboarding (stance + region rings + location permission), settings with
  Datenquellen & Lizenzen, small + medium departure Home-Screen widgets.
- Provider seam: per-feature protocols and sample implementations in
  BEMBELKit, `@Observable` view models in the app. Backend replaces
  providers; frontend owns views.
- Real logic where it's cheap to be real: fountain season engine
  (22 March – 30 September), crude solar model, region rings from the
  Destatis Gemeindeverzeichnis, offline-first curated data layer.
- swift-format gate (`make format`, `make format-check`, CI).
- CI: kit tests (native `swift test`), unsigned simulator build, data-schema
  validation.

### Changed

- Privacy wording: no tracking, no ads, no BEMBEL backend and no BEMBEL
  accounts; Apple services (Game Center, iCloud) and GitHub participation
  are opt-in. Privacy label stays "Data Not Collected".

[Unreleased]: https://github.com/maurice-jobst/bembel/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/maurice-jobst/bembel/releases/tag/v0.1.0
