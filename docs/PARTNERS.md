# Partners and neighbours

Projects, communities and data stewards BEMBEL should coordinate with rather
than duplicate. Compiled 2026-09-26 from a verification sweep: every entry
was checked against its page or repository on that day; anything that could
not be confirmed is marked **unverified**. Contact details are organisational
addresses only — no private names or numbers in a public repo.

Three rules for using this list:

1. **Partner data is still data.** An upstream from a partner enters
   `data/sources.json` before code calls it and lands in
   `data/ATTRIBUTION.json` with its licence, like any other source. A
   friendly project is not a licence.
2. **The Epic S cap holds.** A partnership that needs a new data source is
   research until v1.0 ships ([GOVERNANCE.md §6](../GOVERNANCE.md#6-scope-control)).
   Register the upstream, note the contact here, do not open a ticket.
3. **We give first.** BEMBEL's exchangeable assets are listed at the end;
   lead with one of them.

## Approach first

| # | Who | Why now | The ask | Touches |
|---|---|---|---|---|
| 1 | **[Transitous](https://transitous.org/)** — community-run MOTIS routing, [API](https://transitous.org/api/), [repo](https://github.com/public-transport/transitous) | The one hard blocker in v1.0 is the RMV key (#11, gate 1 Dec 2026). Transitous serves keyless stop times from the DELFI nationwide GTFS + GTFS-RT, which covers RMV; its usage policy (open source, non-commercial, light load, identifying User-Agent) is one BEMBEL already satisfies. A Swift precedent exists ([OVwijzer](https://github.com/unequalsine/OVwijzer)). | Confirm acceptable load for a departures screen and two widgets; agree the User-Agent; join the Matrix room; offer to add an RMV feed to `feeds/de.json` if RMV publishes one. | #11 #12 #14 #15 |
| 2 | **[trinkhallen-data](https://github.com/boredland/trinkhallen-data)** / [trinkhallen.app](https://trinkhallen.app/) | An actively maintained Trinkhallen dataset already exists, Frankfurt included (~950 kiosks on their map, updated the day of this sweep), built from OSM + enrichment + submissions as PRs. Same author runs [museumsufer](https://github.com/boredland/museumsufer). | Align on OSM ids and a schema crosswalk before bembel-data diverges; share provenance conventions. **Licence conflict to settle first:** their data is CC BY-NC 4.0, bembel-data is ODbL — NC rows cannot be imported into an ODbL register, so the realistic shape is shared identifiers and mutual linking, not a merge. | #39, bembel-data |
| 3 | **Klimareferat Frankfurt** — owner of the [Trink- und Erfrischungsbrunnen WFS](https://geodatenkatalog.frankfurt.de/geonetwork/srv/api/records/fa6035c9-a16e-4be8-8830-e9cf6ac5ea11) · klimareferat@stadt-frankfurt.de | The fountain layer is BEMBEL's launch-day feature and the season opens on the ship date. 16 additional fountains are funded for 2026–2028; without commissioning dates the seasonal logic will be wrong for exactly the fountains people will look for. The office also runs a Trinkbrunnen-Paten programme. | Commissioning dates and a heads-up channel for changes to the WFS; offer BEMBEL as the Paten's reporting front door (deep link to the Mängelmelder). | #23 #24 #25 |
| 4 | **Stabsstelle Stadtmarketing — [Wasserhäusje-Tag](https://wasserhaeusjetag.de/)** · wasserhaeusjetag@stadt-frankfurt.de | The city ran the day itself for the first time on 12 Sep 2026 with 20 participating kiosks — a curated, sourceable seed set for the register, and the strongest distribution moment for the app. | Permission to seed the 20 kiosks with the event page as source URL; propose BEMBEL as the map for the 2027 edition, with Kiosk-Stempel for visited kiosks. | #39 #105 #35 |
| 5 | **[CCC Frankfurt](https://ccc-ffm.de/)** and FSFE Rhein/Main (meets there) | Weekly Offenes Chaos, active in Sep 2026, the natural first public audience: privacy label review before the external TestFlight beta (31 Oct 2026), and the MIT/ODbL story for the FSFE group. | A lightning talk slot; a privacy-label read-through of the app against *Data Not Collected*. | #34 #35 |

Runner-up: **HVBG** (vertrieb-geobasisdaten@hvbg.hessen.de) for a written
confirmation that a simplified, derived Frankfurt building dataset from the
[LoD2 model](https://hvbg.hessen.de/landesvermessung/geotopographie/3d-daten/3d-gebaeudemodelle)
may be republished under dl-de/zero 2.0 — the M1 exit criterion (#17, #18).

## Open-data and civic tech, Frankfurt and Hessen

| Who | State | Angle |
|---|---|---|
| [OK Lab Frankfurt / Code for Frankfurt](https://codefor.de/frankfurt/) · [GitHub](https://github.com/codeforfrankfurt) | **Dormant** — the codefor.de page says the lab is not active; last commit Dec 2022. | Not a partner today. BEMBEL could be the occasion to revive it (a data evening); their old fine-dust sensor work overlaps #76. |
| [Stadt Frankfurt — Offene Daten](https://www.offenedaten.frankfurt.de/) / Stabsstelle Smart City | Active; the portal is migrating to the Statistikportal platform in 2026. | Ask for the post-migration endpoints for Trinkbrunnen and Baumkataster (conditional-GET refresh depends on stable URLs); get listed in the portal's re-use showcase. |
| [Urbane Datenplattform Frankfurt](https://urbane-datenplattform.frankfurt.de/) | Live since Oct 2022; city-owned air, traffic and pedestrian sensors; an Open-API exists. | A second source for Stadtzustand air/heat (#29, #76) — registered in `sources.json` as research first. |
| [Regionalverband FrankfurtRheinMain — Geoportal](https://www.region-frankfurt.de/Services/Geoportal/Open-Data-f%C3%BCr-Karten-und-Geodaten/) | Active; WMS/WFS under dl-de/by-2.0. | Regional layers matching the ring model (ADR 0003) — Tier-D material. |
| [opendata.hessen.de](https://opendata.hessen.de/en/dataset/3d-gebaudemodell-he-lod2) / HVBG | Active; LoD2 CityGML, dl-de/zero, free download. | See runner-up above. |
| [FOSSGIS e.V.](https://www.fossgis.de/) | Active; #hack4GDI_DE 13–14 Nov 2026 in Mainz; FOSSGIS 2027 CfP in autumn. | Submit RADOLAN-on-device and the LoD2 geometry dataset as a talk; the Mainz hackathon is Rhein-Main and could take the shadow dataset. |
| [Jugend hackt Frankfurt](https://www.digitale-welten.org/projekt/jugend-hackt/) (Digitale Welten / NODE) | Active; 2026 edition in May; mentors wanted. | Offer bembel-data and the fountain GeoJSON as ready datasets, plus a mentor slot, for 2027. |
| OSM Frankfurt Stammtisch ([wiki](https://wiki.openstreetmap.org/wiki/Frankfurt_am_Main/OSM-Fr%C3%BChschoppen)) | **Unverified** for 2026 — wiki last edited Jan 2024, no 2026 calendar entry found. | If it meets: agree kiosk and fountain tagging that bembel-data re-imports (#39, #23, #125). |
| [sensor.community](https://sensor.community/de/) | Global project active; a Frankfurt local group is **unverified**. | #76 already plans ingestion; a sensor-building evening at CCC-FFM would seed density. |

## Sibling apps and proven patterns

| Who | State | Angle |
|---|---|---|
| [Franzbrötchen](https://fruitfulapps.com/franzbroetchen/) — the Hamburg city app | Active on the App Store; closed source. | Developer exchange on DWD radar and privacy labels; a mutual "sister city app" mention at launch. Feature comparison: [research/2026-09-franzbroetchen.md](research/2026-09-franzbroetchen.md). |
| [Gieß den Kiez](https://github.com/technologiestiftung/giessdenkiez-de) (CityLAB Berlin) | Active, Sep 2026; forks in Leipzig and Magdeburg, none in Hessen; their [DWD harvester](https://github.com/technologiestiftung/giessdenkiez-de-dwd-harvester) handles RADOLAN via GDAL. | For the post-1.0 tree register (#41): BEMBEL as the iOS front end of a "Frankfurt gießt" instance rather than a competitor. Compare RADOLAN notes now. |
| [Bright Sky](https://github.com/jdemaeyer/brightsky) / dwdparse | Active, MIT; serves the RV composite. Rejected as a runtime dependency (ADR 0008), valued as a reference. | Cross-check the Swift RADOLAN decoder against dwdparse; contribute test vectors. |
| [wetterdienst](https://github.com/earthobservations/wetterdienst) · [wradlib RADOLAN guide](https://github.com/wradlib/radolan-guide) | Active. | Format reference for RADOLAN edge cases; cite in the decoder's tests. |
| [OpenData ÖPNV / DELFI](https://www.opendata-oepnv.de/) | Active; nationwide GTFS + GTFS-RT, RMV listed. | The fallback data path for epic C and the on-device stop list; also what Transitous ingests. |
| [Karte von morgen / OpenFairDB](https://github.com/kartevonmorgen/openfairdb) | Active; hosts the Refill stations behind a REST API. | Refill stations as a third water source next to WFS and OSM (#23) — via the API, registered first. |
| [Refill Deutschland / a tip: tap e.V.](https://atiptap.org/projekte/trinkwasser-projekte-in-deutschland/refill-deutschland/) · [Refill Frankfurt (Ernährungsrat)](https://ernaehrungsrat-frankfurt.de/trinkwasser-unterwegs-einfach-nachfuellen-mit-refill-frankfurt/) | Active. | World Water Day is their campaign day and BEMBEL's ship date: a joint 22 March 2027 note; the Ernährungsrat as a local multiplier (#35). |
| [Berlin-Vegan data](https://github.com/Berlin-Vegan/berlin-vegan-data) | Exists; activity not confirmed. | Pattern precedent only (curated rows → JSON feeding apps). |
| Stolpersteine — [Initiative Frankfurt](https://www.stolpersteine-frankfurt.de/de/frankfurt), [OSM scheme](https://wiki.openstreetmap.org/wiki/DE:Stolpersteine) | Initiative active (2,200+ stones); no open dataset or licence on their site. | #42 should build on Wikidata/OSM; the ask to the Initiative is a licence statement for coordinates, not hosting. |

## Data stewards

| Who | State | Angle |
|---|---|---|
| [DWD Open Data](https://www.dwd.de/DE/leistungen/opendata/hilfe.html) | Active; attribution "Deutscher Wetterdienst"; headquartered in Offenbach. | Attribution wording for #8; ten kilometres away — invite to the launch. |
| [HLNUG Luftmessnetz](https://www.hlnug.de/messwerte/datenportal/luftmessnetz) | Active portal; no documented API of its own (UBA relays the stations BEMBEL uses). | Low priority unless #29 needs sub-hourly data. |
| [RMV Open Data](https://www.rmv.de/s/de/rmv-open-data) | Active; key by web form; stop list published 2026-05-27. | File the form now citing MIT and no tracking; run Transitous in parallel so the 1 Dec gate has two ways to pass. |
| [Vereinigung der Äpfelweinwirte Frankfurt e.V.](https://www.apfelweinwirte.de/apfelweinwirte) | Live; 44 member taverns listed, all rights reserved. | Permission to seed the Ebbelwei register from the member list with one source URL per row (#40), and to mark members in the provenance UX. |
| [ebbelwoi-frankfurt.de](https://ebbelwoi-frankfurt.de/apfelweinwirtschaften/) | Live 2026; ~50 historic taverns, no licence stated. | A "früher hier" layer if the author agrees to CC BY. |
| [Wasserhäuschen und die Stadt](https://wdc2026.org/de/frames/wasserhaeuschen-und-die-stadt) (World Design Capital 2026) | Active through 2026. | History and photo provenance for kiosk entries; a design-credibility hook for launch. |
| [wasserhäuschen.eu](https://xn--wasserhuschen-hfb.eu/) | Site live, last news 2017; the Quartett was reissued Jan 2026. | Cultural blessing and photo rights, not data. |
| Linie 11 – Wir lieben Wasserhäuschen | **Unverified** — both known hosts failed to resolve on the sweep day. | Originators of the Wasserhäuschentage; reach via Stadtmarketing. |
| [mainziel (Straßenverkehrsamt)](https://mainziel.de/en/here-for-you/disclosure-of-data) | Active; Baustellen and parking via Mobilithek (DATEX II). | Post-1.0 Baustellen (#44) goes through Mobilithek registration (#73), never scraping. |
| nextbike Frankfurt GBFS ([Mobility Database](https://mobilitydatabase.org/feeds/gbfs/gbfs-nextbike_ff)) | Feed URL returned 404 on the sweep day — **unverified live**. | Post-1.0 micromobility (#74); `gbfs_systems_catalog` in the registry is the discovery path. |

## What BEMBEL can offer

- **A Swift RADOLAN decoder** (RV and RY composites, bzip2 + tar, parsed on
  device, fixture-tested). A GitHub search on the sweep day found no other
  Swift implementation. Extractable from BEMBELKit on request.
- **A Transitous/MOTIS Swift client**, once epic C goes that way — also
  first of its kind on GitHub as far as the sweep could see.
- **`data/sources.json`**: 38 Rhein-Main upstreams with licence, tier,
  gotchas and a weekly liveness sweep, plus six documented gaps — reusable
  by any Frankfurt project.
- **The ratings-as-pull-requests model** in bembel-data, with CI-enforced
  one-rating-per-account, as a pattern other cities can fork.
- **73 deduplicated drinking fountains** as GeoJSON with a seasonal state
  rule, under the sources' licences.

## Maintaining this file

Re-verify entries when they are next needed, not on a schedule; write the
date next to what changed. When a contact leads to an agreement, record it
as a note on the relevant `sources.json` entry (that is where the licence
terms live) and link the issue. Remove an entry when the project is gone,
not when it is merely quiet.
