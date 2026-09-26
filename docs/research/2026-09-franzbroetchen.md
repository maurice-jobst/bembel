# Franzbrötchen → BEMBEL: what transfers, and what it costs

2026-09-26. BEMBEL was modelled on Franzbrötchen from the start (the kickoff
prompt names it). This note compares the two a year on, feature by feature,
against one question: **what could BEMBEL replicate from sources it already
calls?** The cap from BACKLOG still holds — no new data-source ticket before
the App Store release — so everything that needs a new upstream is listed, not
ticketed.

Franzbrötchen as of App Store v1.11.1: iPhone/iPad/iMessage, iOS 18.5+, one
developer (Mert Bulan), German only, 5.0 ★ from 102 ratings, privacy label "no
data collected", eight tip-jar IAPs at 0.99–9.99 €, Game Center achievements.
Sources: its [App Store listing](https://apps.apple.com/de/app/franzbr%C3%B6tchen-die-hamburg-app/id6753984831),
[the developer's page](https://fruitfulapps.com/franzbroetchen/), and
[a press piece](https://punkt-am-ende.work/2026/01/31/franzbrotchen-app-hamburg-entdecken-mert-bulan/).

## Already in BEMBEL, or already ticketed

| Franzbrötchen | BEMBEL |
|---|---|
| Regenradar | live, RADOLAN RV + RY (#26 #27 #99) |
| Trinkwasserbrunnen | live, with the season rule nobody else has (#23–#25) |
| Franzbrötchen ranking + price voting | the hero: Wasserhäuschen/Ebbelwei registers + rating funnel (#39 #40 #46); Schoppen-Index in the catalogue (C2) |
| HVV-Abfahrten | #11–#16, gated on the RMV key by 1 Dec |
| Stadtteil-Quiz, achievements | #36 sticker album; quiz is catalogue Tier D |
| iMessage | #37 sticker pack |
| Straßenbäume | #41 |
| Stolpersteine | #42 — OSM has 962 in Frankfurt; permission is the gate |
| Baustellen, Radweg-Sperrungen | #44 — both layers already registered (`ffm_baustellen`, `ffm_rad` Radinformation) |
| Bike routes | #38 GrünGürtel |
| Micromobility | #74, now two feeds after Dott left |
| Tip jar | #33 — Franzbrötchen shows it coexists with "no data collected" |

## New tickets — no new upstream

Measured 2026-09-26; counts are OSM via Overpass, AGS 06412000.

| Ticket | What | Reuses | Milestone |
|---|---|---|---|
| #123 BEM-F04 | Rain widget, Home + Lock Screen | `dwd_radolan_rv`, `RainOutlook` (built for this) | M2 — the Home Screen widget if epic C misses its gate |
| #124 BEM-H07 | Siri & Shortcuts: rain, nearest running fountain, nearest Wasserhäuschen | existing providers + `FountainSeason` | M3, first to cut |
| #125 BEM-S16 | Toilets (~239), bike service (39 + 9 air), splash pads (6) | `openstreetmap`, the fountain generator's pattern | M4 (ADR 0009) |
| #126 BEM-S17 | Bridge days + Hessen holidays | pure computation, `FountainSeason.easter` | M4 |

## Needs a new upstream — capped until after v1.0

Recorded so nobody re-researches them; each would enter `data/sources.json`
first, per CONTRIBUTING.

- **Apotheken-Notdienst** — daily utility, no open API known for Hessen; OSM
  has 147 pharmacies but not the rota.
- **Ladestationen** — OSM has 283; the Bundesnetzagentur register is the
  authoritative one. No heat angle.
- **Veranstaltungen, Kino** — `veranstaltungen` is tier 5: nothing to call.
- **Abfuhrkalender** — `fes_abfallkalender` is tier 5.
- **Wahlergebnisse, Parlament (PARLIS), Frag den Staat** — civic layer,
  Franzbrötchen's "Demokratie" section. Not on the heat positioning.
- **Mietspiegel, Demografie** — `ffm_dcat` is registered (Stadtteil-Steckbrief)
  and would be the start.
- **Züge ab Frankfurt** — #45, needs-decision.

## Not worth copying

The breadth. Franzbrötchen is some twenty sections deep — jobs, moving,
local brands, courses. BEMBEL's positioning (ADR 0010: für eine Stadt, die
heißer wird) is the reason it can be finished by one team by 22 March 2027;
the table above is sorted by that, not by how many rows Hamburg has.
