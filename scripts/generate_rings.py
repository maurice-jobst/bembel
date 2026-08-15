#!/usr/bin/env python3
"""Generate rings.json from the Destatis Gemeindeverzeichnis (GV100AD).

Writes both copies (data/rings.json and the BEMBELKit resource) so they can
never drift; scripts/validate_data.py enforces byte equality.

Selection rule (ADR 0003):
  frankfurt — AGS 06412000
  kernraum  — the 80 named member municipalities of the Regionalverband
              FrankfurtRheinMain (region-frankfurt.de/Ueber-uns/Der-Regionalverband)
  rheinmain — every municipality inside the 18 Landkreise + kreisfreie Städte
              of the Metropolregion FrankfurtRheinMain

Both source lists below are literal names transcribed from the Regionalverband's
own pages (see comments). The script resolves them against the official
Gemeindeverzeichnis to get authoritative 8-digit AGS codes — it does not
hand-type any AGS itself, so the table stays reproducible from these two name
lists plus any future GV100AD download.

Usage:
  python3 scripts/generate_rings.py path/to/GV100AD.txt

The GV100AD fixed-width export ships as a zip at, e.g.:
  https://www.destatis.de/DE/Themen/Laender-Regionen/Regionales/Gemeindeverzeichnis/Administrativ/Archiv/GV100ADQ/GV100AD<MMDD>.zip?__blob=publicationFile
(re-download at each Gebietsstand; the raw file is not committed — only the
generated rings.json is).

Record layout (Datensatzbeschreibung_GV100AD.pdf, bundled in that same zip),
1-indexed byte positions, ASCII fixed-width, one Land='DE' code page:
  Satzart 40 (Kreisdaten):   1-2 "40" · 11-12 Land · 13 RB · 14-15 Kreis ·
                             23-72 Kreisbezeichnung · 123-124 Textkennzeichen
                             (41 kreisfreie Stadt / 43 Kreis / 44 Landkreis)
  Satzart 60 (Gemeindedaten):1-2 "60" · 11-12 Land · 13 RB · 14-15 Kreis ·
                             16-18 Gemeinde · 23-72 Gemeindebezeichnung
  AGS = Land+RB+Kreis+Gemeinde (8 digits); Kreisschlüssel = Land+RB+Kreis (5).
"""

import json
import sys
import unicodedata
from pathlib import Path

from bembel_paths import mirrored

OUTPUTS = mirrored("rings.json")

FRANKFURT_AGS = "06412000"

# ---------------------------------------------------------------------------
# kernraum — the 80 Regionalverband FrankfurtRheinMain member municipalities,
# as named on https://www.region-frankfurt.de/Ueber-uns/Der-Regionalverband/
# (retrieved 2026-08-13). This is the literal membership list, not a Kreis
# rule — the Verband covers six Kreise only partially (Groß-Gerau,
# Main-Kinzig, Wetterau), so listing Gemeinden by name is the actual
# definition, not an approximation of one.
# ---------------------------------------------------------------------------
REGIONALVERBAND_MEMBERS = [
    "Bad Homburg v.d.Höhe", "Bad Nauheim", "Bad Soden am Taunus", "Bad Vilbel",
    "Bischofsheim", "Bruchköbel", "Butzbach", "Dietzenbach", "Dreieich",
    "Echzell", "Egelsbach", "Eppstein", "Erlensee", "Eschborn",
    "Flörsheim am Main", "Florstadt", "Frankfurt am Main", "Friedberg",
    "Friedrichsdorf", "Ginsheim-Gustavsburg", "Glashütten", "Glauburg",
    "Grävenwiesbach", "Groß-Gerau", "Großkrotzenburg", "Hainburg",
    "Hammersbach", "Hanau", "Hattersheim am Main", "Heusenstamm",
    "Hochheim am Main", "Hofheim am Taunus", "Karben", "Kelkheim (Taunus)",
    "Kelsterbach", "Königstein im Taunus", "Kriftel", "Kronberg im Taunus",
    "Langen", "Langenselbold", "Liederbach am Taunus", "Limeshain",
    "Mainhausen", "Maintal", "Mörfelden-Walldorf", "Mühlheim am Main",
    "Münzenberg", "Nauheim", "Neu-Anspach", "Neuberg", "Neu-Isenburg",
    "Nidda", "Niddatal", "Nidderau", "Niederdorfelden", "Ober-Mörlen",
    "Obertshausen", "Oberursel (Taunus)", "Offenbach am Main", "Ranstadt",
    "Raunheim", "Reichelsheim (Wetterau)", "Rockenberg", "Rodenbach",
    "Rodgau", "Rödermark", "Ronneburg", "Rosbach v. d. Höhe", "Rüsselsheim am Main",
    "Schmitten im Taunus", "Schöneck", "Schwalbach am Taunus", "Seligenstadt",
    "Steinbach (Taunus)", "Sulzbach (Taunus)", "Usingen", "Wehrheim",
    "Weilrod", "Wölfersheim", "Wöllstadt",
]
assert len(REGIONALVERBAND_MEMBERS) == 80

# ---------------------------------------------------------------------------
# rheinmain — Metropolregion FrankfurtRheinMain: 18 Landkreise + kreisfreie
# Städte (region-frankfurt.de/.../Die-Metropolregion-kurz-erklaert, retrieved
# 2026-08-13). Every Gemeinde inside one of these Kreise is "rheinmain".
#
# OPEN ITEM the source page states "acht kreisfreie Städte" but names only
# seven across every source checked (this list). Shipping with 7 — Maurice:
# confirm whether an 8th belongs here (candidates would be a Bavarian or RLP
# city not surfaced by search) before the next regeneration.
# ---------------------------------------------------------------------------
METROPOLREGION_KREISFREIE_STAEDTE = [
    "Frankfurt am Main", "Offenbach am Main", "Wiesbaden", "Darmstadt",
    "Mainz", "Worms", "Aschaffenburg",
]
# GV100AD's own Kreisbezeichnung is bare (no "Landkreis "/"Kreis " prefix) —
# using its exact spelling here, verified against the downloaded file, since
# a Land='09' (Bavaria) "Aschaffenburg" Landkreis and kreisfreie Stadt share
# that literal name and are disambiguated by Textkennzeichen, not spelling.
METROPOLREGION_LANDKREISE = [
    "Main-Taunus-Kreis", "Hochtaunuskreis", "Wetteraukreis",
    "Main-Kinzig-Kreis", "Offenbach", "Groß-Gerau",
    "Aschaffenburg", "Miltenberg",
    "Darmstadt-Dieburg", "Odenwaldkreis", "Bergstraße",
    "Alzey-Worms", "Mainz-Bingen",
    "Rheingau-Taunus-Kreis", "Limburg-Weilburg",
    "Gießen", "Vogelsbergkreis", "Fulda",
]


def _fold(name: str) -> str:
    """Casefold + ASCII-fold diacritics/punctuation to whitespace-separated
    tokens, so 'v.d.' / 'v. d.' and umlaut spellings compare equal."""
    n = unicodedata.normalize("NFC", name).strip().casefold()
    for a, b in (("ß", "ss"), ("ü", "ue"), ("ö", "oe"), ("ä", "ae"),
                 (".", " "), ("-", " "), ("(", " "), (")", " ")):
        n = n.replace(a, b)
    return " ".join(n.split())


def _norm_keys(name: str) -> tuple[str, str]:
    """Two matchable keys for a name, most-specific first:
    (1) primary name before the first comma (drops GV100AD honorific
        suffixes like ', Stadt' / ', Brüder-Grimm-Stadt'), folded whole;
    (2) the same, with any parenthetical dropped entirely — lets 'Friedberg'
        match 'Friedberg (Hessen)' and vice versa."""
    primary = name.split(",", 1)[0].strip()
    bare = primary.split("(", 1)[0].strip()
    return _fold(primary), _fold(bare)


def parse_gv100ad(
    path: Path,
) -> tuple[list[tuple[str, str]], list[tuple[str, str]], list[tuple[str, str]]]:
    """Return (gemeinden, kreisfreie_staedte, landkreise).

    gemeinden: (8-digit AGS, Gemeindebezeichnung) from Satzart 60.
    kreisfreie_staedte / landkreise: (5-digit Kreisschlüssel, Kreisbezeichnung)
    from Satzart 40, split by Textkennzeichen (41 = kreisfreie Stadt;
    43/44 = Kreis/Landkreis) — some names (e.g. Bavaria's "Aschaffenburg")
    are shared between a city and its surrounding Landkreis and are only
    distinguishable this way, not by spelling.
    """
    gemeinden, kreisfreie_staedte, landkreise = [], [], []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if len(line) < 128:
            continue
        satzart = line[0:2]
        land, rb, kreis = line[10:12], line[12:13], line[13:15]
        if satzart == "60":
            gemeinde = line[15:18]
            code = f"{land}{rb}{kreis}{gemeinde}"
            name = line[22:72].strip()
            if len(code) == 8 and code.isdigit():
                gemeinden.append((code, name))
        elif satzart == "40":
            code = f"{land}{rb}{kreis}"
            name = line[22:72].strip()
            textkennzeichen = line[122:124]
            if len(code) == 5 and code.isdigit():
                if textkennzeichen == "41":
                    kreisfreie_staedte.append((code, name))
                elif textkennzeichen in ("43", "44"):
                    landkreise.append((code, name))
    return gemeinden, kreisfreie_staedte, landkreise


def resolve_names(
    wanted: list[str],
    available: list[tuple[str, str]],
    label: str,
    restrict_prefix: str | None = None,
) -> dict[str, str]:
    """Match each wanted name to exactly one (code, name) in available, at
    the most specific key tier that yields a unique hit (see _norm_keys).

    If restrict_prefix is set, `available` is filtered to that code prefix
    BEFORE any matching happens — not used as a tie-break. A same-named but
    unrelated municipality/Kreis elsewhere in Germany (e.g. Bavaria also has
    a bare "Friedberg"; Lower Saxony has a bare "Langen") can otherwise win
    a spurious unique match at an early tier, before the real, ambiguous
    candidate set (and any tie-break) is ever considered. Every caller that
    knows its wanted names are all from one Land should pass this.

    Exits with a diff on any name that still doesn't resolve uniquely — a
    silent partial match is worse than a crash."""
    if restrict_prefix:
        available = [c for c in available if c[0].startswith(restrict_prefix)]

    by_key: list[dict[str, list[tuple[str, str]]]] = [{}, {}]
    for code, name in available:
        for tier, key in enumerate(_norm_keys(name)):
            by_key[tier].setdefault(key, []).append((code, name))

    resolved: dict[str, str] = {}
    missing = []
    for w in wanted:
        matches: list[tuple[str, str]] = []
        for tier, key in enumerate(_norm_keys(w)):
            candidates = by_key[tier].get(key, [])
            if len(candidates) == 1:
                matches = candidates
                break
            if candidates:
                matches = candidates  # keep the ambiguity for the error report
        if len(matches) == 1:
            code, name = matches[0]
            resolved[code] = name
        else:
            missing.append((w, matches))

    if missing:
        lines = [f"{label}: {len(missing)}/{len(wanted)} names failed to resolve uniquely:"]
        for w, matches in missing:
            lines.append(f"  {w!r} -> {len(matches)} candidate(s): {matches}")
        sys.exit("\n".join(lines))
    return resolved


def main() -> int:
    if len(sys.argv) != 2:
        sys.exit(__doc__)

    gemeinden, kreisfreie_staedte, landkreise = parse_gv100ad(Path(sys.argv[1]))

    kernraum_by_ags = resolve_names(
        REGIONALVERBAND_MEMBERS, gemeinden, "kernraum (Regionalverband)", restrict_prefix="06"
    )
    assert all(ags.startswith("06") for ags in kernraum_by_ags), "restrict_prefix invariant broken"

    rheinmain_kreis_codes = set(
        resolve_names(
            METROPOLREGION_KREISFREIE_STAEDTE, kreisfreie_staedte, "rheinmain (kreisfreie Städte)"
        ).keys()
    ) | set(
        resolve_names(
            METROPOLREGION_LANDKREISE, landkreise, "rheinmain (Landkreise)"
        ).keys()
    )

    rows = []
    for ags, name in gemeinden:
        if ags == FRANKFURT_AGS:
            ring = "frankfurt"
        elif ags in kernraum_by_ags:
            ring = "kernraum"
        elif ags[:5] in rheinmain_kreis_codes:
            ring = "rheinmain"
        else:
            continue
        rows.append({"ags": ags, "name": name, "ring": ring})
    rows.sort(key=lambda r: r["ags"])

    payload = {
        "version": 1,
        "status": "generated",
        "definition": (
            "frankfurt = AGS 06412000; kernraum = the 80 named Regionalverband "
            "FrankfurtRheinMain member municipalities; rheinmain = every "
            "municipality within the Metropolregion FrankfurtRheinMain's 18 "
            "Landkreise + kreisfreie Städte"
        ),
        "source": (
            "scripts/generate_rings.py from Destatis GV100AD "
            "(region-frankfurt.de membership lists, retrieved 2026-08-13; "
            "see script header for the open kreisfreie-Städte count question)"
        ),
        "municipalities": rows,
    }
    text = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    for output in OUTPUTS:
        output.write_text(text, encoding="utf-8")
        print(f"wrote {len(rows)} municipalities -> {output.relative_to(REPO)}")

    frankfurt = sum(1 for r in rows if r["ring"] == "frankfurt")
    kern = sum(1 for r in rows if r["ring"] == "kernraum")
    rhein = sum(1 for r in rows if r["ring"] == "rheinmain")
    print(f"frankfurt={frankfurt} kernraum={kern} rheinmain={rhein} total={len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
