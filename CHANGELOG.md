# Changelog

All notable changes to BEMBEL. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[SemVer](https://semver.org) with 0.x meaning "pre-App-Store".

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

[0.1.0]: https://github.com/maurice-jobst/bembel/releases/tag/v0.1.0
