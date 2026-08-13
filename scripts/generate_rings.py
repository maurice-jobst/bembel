#!/usr/bin/env python3
"""Generate rings.json from the Destatis Gemeindeverzeichnis (GV100AD).

Writes both copies (data/rings.json and the BEMBELKit resource) so they can
never drift; scripts/validate_data.py enforces byte equality.

Selection rule (ADR 0003):
  frankfurt — AGS 06412000
  kernraum  — member municipalities of the Regionalverband FrankfurtRheinMain
  rheinmain — municipalities of the Metropolregion FrankfurtRheinMain

Usage:
  python3 scripts/generate_rings.py path/to/GV100AD.txt

The GV100AD fixed-width export is available from
https://www.destatis.de/DE/Themen/Laender-Regionen/Regionales/Gemeindeverzeichnis/
(re-download at each Gebietsstand; the file is not committed).
"""

import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OUTPUTS = [
    REPO / "data" / "rings.json",
    REPO / "Packages" / "BEMBELKit" / "Sources" / "BEMBELKit" / "Resources" / "rings.json",
]

# ---------------------------------------------------------------------------
# Membership definitions.
#
# VERIFIED must be flipped to True only after both lists below have been
# checked against the published sources:
#   - Regionalverband FrankfurtRheinMain: member list per RegFNP/Verbandsgebiet
#     (region-frankfurt.de) — the Verband covers Frankfurt, Offenbach and the
#     full or partial Kreise listed; partial Kreise need explicit Gemeinde
#     lists, not Kreis prefixes.
#   - Metropolregion FrankfurtRheinMain: Kreis list per the Metropolregion
#     definition (incl. the rheinland-pfälzische and bayerische parts).
# Until then this script refuses to run and the hand-seeded provisional
# rings.json stays in place. This is deliberate: a wrong table that looks
# generated is worse than a small table that says "provisional".
# ---------------------------------------------------------------------------
VERIFIED = False

FRANKFURT_AGS = "06412000"

# Kreis prefixes (5-digit) fully inside the Regionalverband, plus explicit
# Gemeinde lists for partially covered Kreise. PLACEHOLDERS — see VERIFIED.
KERNRAUM_FULL_KREISE: set[str] = set()
KERNRAUM_GEMEINDEN: set[str] = set()

# Kreis prefixes (5-digit) of the Metropolregion. PLACEHOLDERS — see VERIFIED.
RHEINMAIN_KREISE: set[str] = set()


def parse_gv100ad(path: Path) -> list[tuple[str, str]]:
    """Yield (ags, name) for every Gemeinde record (Satzart 60)."""
    municipalities = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if len(line) < 30 or line[0:2] != "60":
            continue
        # GV100AD layout: EF3 Land (pos 11-12), EF4 RB (13), EF5 Kreis (14-15),
        # EF6 Verbandsschlüssel, Gemeinde (19-21); name from pos 23.
        land, rb, kreis, gemeinde = line[10:12], line[12:13], line[13:15], line[18:21]
        ags = f"{land}{rb}{kreis}{gemeinde}"
        name = line[22:72].strip()
        if len(ags) == 8 and ags.isdigit():
            municipalities.append((ags, name))
    return municipalities


def ring_for(ags: str) -> str | None:
    if ags == FRANKFURT_AGS:
        return "frankfurt"
    if ags[:5] in KERNRAUM_FULL_KREISE or ags in KERNRAUM_GEMEINDEN:
        return "kernraum"
    if ags[:5] in RHEINMAIN_KREISE:
        return "rheinmain"
    return None


def main() -> int:
    if not VERIFIED:
        sys.exit(
            "refusing to generate: membership lists are unverified placeholders.\n"
            "Verify KERNRAUM_* and RHEINMAIN_KREISE against the published "
            "Regionalverband and Metropolregion definitions, set VERIFIED = True, "
            "and re-run. The provisional hand-seeded rings.json remains in place."
        )
    if len(sys.argv) != 2:
        sys.exit(__doc__)

    rows = []
    for ags, name in parse_gv100ad(Path(sys.argv[1])):
        ring = ring_for(ags)
        if ring:
            rows.append({"ags": ags, "name": name, "ring": ring})
    rows.sort(key=lambda r: r["ags"])

    payload = {
        "version": 1,
        "status": "generated",
        "definition": (
            "frankfurt = AGS 06412000; kernraum = Regionalverband "
            "FrankfurtRheinMain member municipalities; rheinmain = "
            "Metropolregion FrankfurtRheinMain"
        ),
        "source": "scripts/generate_rings.py from Destatis GV100AD",
        "municipalities": rows,
    }
    text = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    for output in OUTPUTS:
        output.write_text(text, encoding="utf-8")
        print(f"wrote {len(rows)} municipalities -> {output.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
