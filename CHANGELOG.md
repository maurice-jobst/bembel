# Changelog

All notable changes to BEMBEL. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[SemVer](https://semver.org) with 0.x meaning "pre-App-Store".

## [Unreleased]

### Added

- **Projekt- und Produkt-Governance, aufgeschrieben.** `GOVERNANCE.md` (Rollen,
  Entscheidungsstufen, Tie-Breaker, Änderungskontrolle auf `main`, bekannte
  Lücken wie den Bus-Faktor eins), `docs/PRODUCT.md` (Positionierung,
  Prinzipien, Scope of Record mit Status je Feature, Gates und Termine,
  Definition of Ready/Done, Roadmap, ADR-Index), `CODE_OF_CONDUCT.md` und
  `docs/PARTNERS.md` — 30 geprüfte Nachbarprojekte, Communities und
  Datenhalter mit konkretem Kooperationsansatz, allen voran Transitous als
  schlüsselloser Weg zu echten Abfahrten vor dem 1.-Dezember-Gate (#11).
- `data/sources.json` kennt Transitous (`transitous_motis`, Tier 2): MOTIS-API
  auf DELFI-GTFS + GTFS-RT, live gegen Hauptwache geprüft, Echtzeit inklusive.
  Registriert, nicht verdrahtet — der Epic-S-Deckel gilt.
- Pollenflug im Stadtzustand (BEM-G04, #71): DWD-Gefahrenindex für die Region
  Rhein-Main, gebündelt und per Conditional GET nachgeladen; die fünfte Karte
  mit eigenem Ladezustand.

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
- 73 Trinkbrunnen aus Frankfurter WFS + OSM auf der Orte-Karte, geprüft vs.
  ungeprüft dreifach unterscheidbar (Form, Farbe, Text), mit Saisonlogik
  (Winterpause, Osterregel für historische Brunnen).
- Live-Regenradar: DWD RADOLAN RV direkt auf dem Gerät geparst (2-h-Nowcast
  für Frankfurt), ohne Drittanbieter-Paket.
- Regenradar zeigt auch die **vergangene Stunde** (DWD RADOLAN RY): die
  Zeitleiste reicht von −60 Min bis +120 Min, „jetzt" ist darauf markiert und
  ist die Startposition. Damit ist zu sehen, ob ein Schauer auf einen zukommt
  oder abzieht — der Nowcast allein zeigt das nicht.
- Regenradar zeigt jetzt die echten Radarbilder auf der Karte statt vier
  dekorativer Farbflecken: 25 Bilder über zwei Stunden, Abspielen, Pause und
  Scrubben, Skala in mm/h mit sechs Stufen (einfarbig und monoton — die
  übliche Grün-Gelb-Rot-Skala ist für Rot-Grün-Sehschwäche die denkbar
  schlechteste). Die Zeitachse zeigt den Horizont, den die Quelle wirklich
  hat: `jetzt` bis `+120 Min` statt der erfundenen −60…+90.
- Stadtzustand mit echten Quellen, je Karte unabhängig: Main-Pegel von
  PEGELONLINE (Osthafen), amtliche Warnungen aus NINA (auf den gewählten Ring
  gefiltert), Luftqualität aus dem UBA-Messnetz (nächstgelegene Station).
  Fällt eine Quelle aus, sagt genau ihre Karte das — der Rest bleibt stehen.
- Echte Sonnenstände (NOAA-Ephemeride) hinter der Schattenkarte statt einer
  Parabel — Sonnenauf- und -untergang stimmen jetzt das ganze Jahr.
- Temperatur live aus den DWD-Stationsmeldungen (Station Frankfurt/Main, stündlich)
  statt aus dem Sample. Die Zeile nennt Messwert, Station und Messzeit: das
  Thermometer steht am Flughafen und liest an heißen Nachmittagen kühler als die
  Innenstadt — das soll die Zeile nicht verwischen. Damit ist der Stadtzustand
  vollständig live.
- App-Icon (generiert, `make icon`) und TestFlight-Weg: `make testflight`
  archiviert und lädt zu App Store Connect hoch (docs/TESTFLIGHT.md).
- [docs/AI-NATIVE.md](docs/AI-NATIVE.md): welche Beschränkungen dieses Repo
  angenommen hat, damit agentengeschriebene Änderungen überprüfbar bleiben —
  jede mit dem Mechanismus, der sie hält, plus den Regeln ohne Zähne und dem,
  was trotzdem durchkam.

- Sonnenstand erklärt sich: „Wie genau ist das?" nennt Quelle (NOAA, auf dem
  Gerät), die gegen ein zweites Verfahren geprüfte Genauigkeit, die
  Horizont-Konvention — und ausdrücklich, was die Zahlen *nicht* versprechen.
  Der berechnete Sonnenuntergang ist nicht der Moment, in dem die Sonne hinter
  dem Taunus oder dem Nachbarhaus verschwindet.

### Fixed

- **Sonnenauf- und -untergang lagen um Minuten daneben.** Die −0,833°-Grenze
  gilt für die *wahre* Sonnenhöhe und enthält die Refraktion bereits; geprüft
  wurde gegen die refraktionskorrigierte Höhe, also zweimal. Ergebnis:
  Sonnenaufgang rund drei Minuten zu früh, Untergang eine Minute zu spät —
  jeden Tag seit BEM-D03. Gefunden beim Schreiben der Offenlegung, die genau
  diese Konvention beschreibt.

### Changed

- **README neu geschrieben** als Schaufenster: was die App ist, was in v1.0
  drin ist und was nicht, wie die Daten fließen, was CI nachrechnet, wer
  entscheidet. Die drei Registry-Zahlen bleiben prüfbar (`make validate`).
- **Docs-Baum entschlackt.** `docs/superpowers/` heißt jetzt `docs/specs/`,
  der Cold-Start-Brainstorm liegt unter `docs/history/`; die drei
  abgearbeiteten Plan-Transkripte vom 13. August (4.400 Zeilen, nichts
  verwies darauf, lokale Pfade drin — #119) sind gelöscht. Verweise auf den
  aufgelösten Regel-Index einer früheren Repo-Familie (`LESSONS §…`) nennen
  die Regel jetzt an Ort und Stelle.
- **Stale Stellen bereinigt:** Onboarding versprach noch die Schattenkarte
  und kannte Orte nicht; ein Dutzend Kommentare beschrieben vier statt fünf
  Stadtzustand-Quellen oder „das Schatten-Screen“; Issue-Formulare boten
  „Schattenkarte“ und „Drinking water“ als Bereiche an; CONTRIBUTING wartete
  noch auf den Public-Flip; AI-NATIVE §6 hielt `enforce_admins` für aus.
  `SampleRadarProvider` (null Referenzen) ist raus. Der gebündelte
  bembel-data-Snapshot ist auf den Stand des dist-Branches (2026-09-02).
- Einstellungen › Quellen liest aus `data/sources.json` (BEM-B06, #70) statt
  aus einem hartkodierten Array; `data/ATTRIBUTION.json` verweist je Zeile
  per `registry_id` zurück in die Registry.
- Drift-Check der Quellen (BEM-B07, #122): ein Einbruch auf knapp über null
  gilt als Ausfall; Baustellen-Zähler sind als `volatile` markiert und
  melden nur noch den Kollaps, nicht die Wochenbewegung.
- Kiosk-Stempel-Text nennt die tatsächliche Reichweite (When-In-Use, #105);
  `enforce_admins` auf `main` ist an (#106).
- **Die drei Zahlen, die der README über `data/sources.json` behauptet, werden
  jetzt nachgerechnet.** Alle drei waren falsch — 30 Einträge statt 32, 39
  Endpunkte statt 48, „nine" Tier-5-Funde statt sechs. Keine davon war je
  geändert worden, weil keine je gelesen wurde. `make validate` rechnet sie
  jetzt aus der Registry nach, und eine Formulierung, auf die das Muster nicht
  mehr passt, ist ein Fehler statt einer stillen Abschaltung
  (`scripts/validate_data.py`, neun Tests).
- **Schattenkarte-Rendering aus v1.0 gestrichen (ADR 0010).** Die Geometrie
  (`BEM-D01`/`BEM-D02`) bleibt drin, aber als eigenständig veröffentlichter
  Datensatz mit sauberer dl-de/zero-Herkunft; das Rendern (`BEM-D04`) ist der
  Aufmacher von v1.2. Der Tab überlebt als **Sonnenstand** mit der echten
  NOAA-Ephemeride — die vorgetäuschte Schattenfläche darüber verschwindet.
  Der Tab heißt jetzt „Sonne" (Ergänzung zu ADR 0009); die Leiste bleibt bei
  fünf Einträgen.
- **Positionierung neu:** „Für eine Stadt, die heißer wird — Wasser, Luft,
  Regen." Schatten und Bäume sind nicht in v1.0, also stehen sie auch nicht
  mehr in der Zeile.
- **Zweck festgeschrieben (ADR 0010):** Im Konflikt gewinnt der
  Portfolio-Wert vor dem Produkt-Wert. Daraus folgen der Epic-S-Deckel (keine
  neuen Datenquellen-Tickets vor dem Release), `docs/AI-NATIVE.md` als
  v1.0-Lieferung und ein 1.-Dezember-Gate für den RMV-Schlüssel.
- ADR 0001 ergänzt: die zwei Beobachtungen, die die Backend-Entscheidung
  wieder aufmachen würden — eine Quelle, die nur über einen eigenen Server
  erreichbar ist, und Einnahmen als Pflicht statt als Trinkgeld.

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
