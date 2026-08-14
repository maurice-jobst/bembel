#!/usr/bin/env python3
"""Build data/fountains.geojson from its three sources. Stdlib only, same rule
as the validator — CI and a fresh clone need no pip install.

    python3 scripts/generate_fountains.py            # Frankfurt
    python3 scripts/generate_fountains.py --ags 06412000 06434011

Sources
-------
1. Stadt Frankfurt, WFS_Trink_Erfrischungsbrunnen, layers `Trinkbrunnen` and
   `Erfrischungsbrunnen` (dl-de/by-2-0). The city's own metadata draws a line
   that matters for a drinking-water app and that we carry into the data:

     "Die historischen, mit Trinkwasser gespeisten, Laufbrunnen wurden […] als
     'Erfrischungsbrunnen' (nicht Trinkbrunnen) bezeichnet, da die
     Trinkwasserqualität der Brunnen nicht kontrolliert wird."

   So `Trinkbrunnen` are sampled, `Erfrischungsbrunnen` are not. They land as
   `stadt` and `historisch`, and every feature carries `geprueft` — merging the
   two into one undifferentiated blue dot would tell people the water is
   checked when nobody checks it.

2. OpenStreetMap `amenity=drinking_water` (ODbL, share-alike — derived rows stay
   identifiable through their `osm_id`).

3. Refill Deutschland: **not ingested.** They publish no machine-readable
   station list (the WordPress REST API exposes no station type, and the map
   page carries no data endpoint), and inventing one from scraped HTML is
   exactly what CONTRIBUTING forbids. Refill stations that *are* in OSM come
   through source 2 under `drinking_water:refill=yes`, correctly licensed. When
   Refill publishes an endpoint, add it here — the `refill` kind already exists.

Municipality assignment has no geocoding step: OSM is queried per municipality
through an Overpass `area` filter keyed on the official AGS, so every feature's
ags and ring are exact by construction rather than inferred from a point.
"""

import argparse
import json
import math
import re
import sys
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
from datetime import date
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
KIT_RESOURCES = REPO / "Packages" / "BEMBELKit" / "Sources" / "BEMBELKit" / "Resources"
DATASET_ID = "fountains"
FILENAME = f"{DATASET_ID}.geojson"

FRANKFURT_AGS = "06412000"

WFS = "https://geowebdienste.frankfurt.de/WFS_Trink_Erfrischungsbrunnen"
OVERPASS = "https://overpass-api.de/api/interpreter"
USER_AGENT = "BEMBEL-dataset-builder/1 (+https://github.com/maurice-jobst/bembel)"

# Dedupe is tiered, because names disagree far more than coordinates do. The
# city register and OSM describe the same fountain as "Hoher Brunnen" and
# "Historischer Trinkbrunnen Hoher Brunnen", as "Brunnen im Günthersburgpark"
# and "Trinkbrunnen im Güntersburgpark" (OSM has the typo), and as "Goldener
# Brunnen" and "Hauptwache-Brunnen" — all of them metres apart. A rule that
# demands matching names keeps 17 duplicate pins standing 30 cm apart.
#
#   ≤ 8 m   one fountain, whatever it is called. Nothing else fits in the
#           GPS scatter of two independent surveys of the same object.
#   ≤ 40 m  one fountain only if the names agree or one contains the other.
#   > 40 m  two fountains.
SAME_SPOT_METRES = 8.0
DEDUPE_METRES = 40.0

# Not public water: a fountain you need a key, a ticket or a membership for
# would send someone across town for nothing.
PRIVATE_ACCESS = {"private", "permit", "customers", "no"}

GENERIC_NAMES = {
    "stadt": "Trinkbrunnen",
    "historisch": "Historischer Erfrischungsbrunnen",
    "mainova": "Trinkbrunnen (Mainova)",
    "refill": "Refill-Station",
    "sonstige": "Trinkbrunnen",
}


def fetch(url: str, data: bytes | None = None, retries: int = 3) -> bytes:
    """One polite GET/POST with linear backoff. Overpass throttles hard when a
    build is re-run in a loop, and a half-fetched dataset must never be written."""
    request = urllib.request.Request(url, data=data, headers={"User-Agent": USER_AGENT})
    for attempt in range(1, retries + 1):
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                return response.read()
        except (urllib.error.URLError, TimeoutError) as exc:
            if attempt == retries:
                raise SystemExit(f"giving up on {url}: {exc}")
            wait = 10 * attempt
            print(f"  … {exc}; retrying in {wait}s ({attempt}/{retries - 1})", file=sys.stderr)
            time.sleep(wait)
    raise SystemExit("unreachable")


def haversine(lon1: float, lat1: float, lon2: float, lat2: float) -> float:
    radius = 6_371_000.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = p2 - p1
    dl = math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * radius * math.asin(math.sqrt(a))


def normalise(name: str | None) -> str:
    """Fold for comparison only — never for display. 'Löwenbrunnen' and
    'Loewenbrunnen' are the same fountain surveyed by two people."""
    if not name:
        return ""
    folded = name.lower()
    for source, target in (("ä", "ae"), ("ö", "oe"), ("ü", "ue"), ("ß", "ss")):
        folded = folded.replace(source, target)
    folded = unicodedata.normalize("NFKD", folded)
    folded = "".join(c for c in folded if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]+", "", folded)


# --- sources ---------------------------------------------------------------


def wfs_features(layer: str) -> list[dict]:
    query = urllib.parse.urlencode(
        {
            "SERVICE": "WFS",
            "VERSION": "2.0.0",
            "REQUEST": "GetFeature",
            "TYPENAMES": f"Erfrischungsbrunnen:{layer}",
            "OUTPUTFORMAT": "GEOJSON",
            "SRSNAME": "EPSG:4326",
        }
    )
    url = f"{WFS}?{query}"
    print(f"→ Stadt Frankfurt WFS, Layer {layer}")
    payload = json.loads(fetch(url))
    rows = []
    for feature in payload.get("features", []):
        geometry = feature.get("geometry") or {}
        if geometry.get("type") != "Point":
            continue
        lon, lat = geometry["coordinates"][:2]
        props = feature.get("properties", {})
        object_id = props.get("OBJECTID")
        if object_id is None:
            continue
        tested = layer == "Trinkbrunnen"
        status = props.get("Status")
        rows.append(
            {
                "id": f"ffm-{'tb' if tested else 'eb'}-{object_id}",
                "lon": round(float(lon), 7),
                "lat": round(float(lat), 7),
                "name": (props.get("Name") or "").strip() or None,
                "kind": "stadt" if tested else "historisch",
                "geprueft": tested,
                # Only the Trinkbrunnen layer maintains a status; absent is not
                # "out of service", it is "the city does not say".
                "inBetrieb": None if status is None else status == "In Betrieb",
                "sources": [f"{WFS}?REQUEST=GetCapabilities&SERVICE=WFS"],
                "ags": FRANKFURT_AGS,
                "authority": 2,  # the operator's own register outranks a survey
            }
        )
    print(f"  {len(rows)} Features")
    return rows


def osm_features(ags: str) -> list[dict]:
    query = (
        "[out:json][timeout:120];"
        f'area["de:amtlicher_gemeindeschluessel"="{ags}"]->.muni;'
        'node["amenity"="drinking_water"](area.muni);'
        "out body;"
    )
    print(f"→ OpenStreetMap, AGS {ags}")
    payload = json.loads(fetch(OVERPASS, data=urllib.parse.urlencode({"data": query}).encode()))
    rows, skipped = [], 0
    for element in payload.get("elements", []):
        tags = element.get("tags", {})
        if tags.get("access") in PRIVATE_ACCESS or tags.get("fee") == "yes":
            skipped += 1
            continue
        operator = tags.get("operator", "")
        if tags.get("drinking_water:refill") == "yes":
            kind = "refill"
        elif "mainova" in operator.lower():
            kind = "mainova"
        elif re.search(r"\b(stadt|gemeinde|magistrat|kreis)\b", operator, re.I):
            kind = "stadt"
        else:
            # No operator tagged. Claiming one would be fabrication; see the
            # note in the PR — the ticket's four-value vocabulary has no room
            # for "public fountain, operator unknown", which is most of OSM.
            kind = "sonstige"
        rows.append(
            {
                "id": f"osm-{element['id']}",
                "lon": round(float(element["lon"]), 7),
                "lat": round(float(element["lat"]), 7),
                "name": (tags.get("name") or "").strip() or None,
                "kind": kind,
                # OSM does not know whether anyone samples the water.
                "geprueft": None,
                "inBetrieb": None,
                "sources": [f"https://www.openstreetmap.org/node/{element['id']}"],
                "ags": ags,
                "osm_id": element["id"],
                "saisonal": tags.get("seasonal") == "yes" or None,
                "rollstuhlgerecht": tags.get("wheelchair") == "yes" or None,
                "flaschenfuellung": tags.get("bottle") == "yes" or None,
                "authority": 1,
            }
        )
    print(f"  {len(rows)} Features ({skipped} nicht öffentlich, übersprungen)")
    return rows


# --- merge -----------------------------------------------------------------


def same_fountain(row: dict, keeper: dict) -> bool:
    distance = haversine(row["lon"], row["lat"], keeper["lon"], keeper["lat"])
    if distance > DEDUPE_METRES:
        return False
    if distance <= SAME_SPOT_METRES:
        return True
    a, b = normalise(row["name"]), normalise(keeper["name"])
    if not a or not b:
        return True
    return a == b or a in b or b in a


def dedupe(rows: list[dict]) -> tuple[list[dict], int]:
    """Same fountain, two surveyors. The higher-authority row wins the identity
    and the facts; the loser only contributes its source URL and whatever the
    winner leaves blank — so an OSM survey can fill in wheelchair access on a
    fountain the city register named, without overwriting the city's own
    'is the water actually sampled' answer.
    """
    ordered = sorted(rows, key=lambda r: (-r["authority"], r["id"]))
    merged: list[dict] = []
    dropped = 0
    for row in ordered:
        for keeper in merged:
            if not same_fountain(row, keeper):
                continue
            for url in row["sources"]:
                if url not in keeper["sources"]:
                    keeper["sources"].append(url)
            for key in ("name", "saisonal", "rollstuhlgerecht", "flaschenfuellung", "osm_id"):
                if keeper.get(key) is None and row.get(key) is not None:
                    keeper[key] = row[key]
            # The city register lists every sampled fountain as one bucket; OSM
            # knows which of them Mainova runs, and which double as a Refill
            # station. Let the more specific kind win — but never over
            # `historisch`, which is not a bucket, it is the record that nobody
            # samples this water.
            if keeper["kind"] == "stadt" and row["kind"] in ("mainova", "refill"):
                keeper["kind"] = row["kind"]
            dropped += 1
            break
        else:
            merged.append(row)
    return merged, dropped


def to_feature(row: dict, rings: dict[str, str], today: str) -> dict:
    properties = {
        "name": row["name"] or GENERIC_NAMES[row["kind"]],
        "ags": row["ags"],
        "ring": rings[row["ags"]],
        "updated": today,
        "sources": row["sources"],
        "art": row["kind"],
        "geprueft": row["geprueft"],
        "inBetrieb": row["inBetrieb"],
    }
    for key in ("osm_id", "saisonal", "rollstuhlgerecht", "flaschenfuellung"):
        if row.get(key) is not None:
            properties[key] = row[key]
    return {
        "type": "Feature",
        "id": row["id"],
        "geometry": {"type": "Point", "coordinates": [row["lon"], row["lat"]]},
        "properties": properties,
    }


def carry_updated(features: list[dict]) -> int:
    """`updated` answers "when did this fountain's facts last change", not "when
    did someone last run the build". Without this, every rebuild restamps all
    73 rows and the diff of a data PR stops showing what actually moved.
    """
    existing = REPO / "data" / FILENAME
    if not existing.is_file():
        return 0
    try:
        previous = json.loads(existing.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return 0
    old = {f.get("id"): f for f in previous.get("features", []) if isinstance(f, dict)}
    carried = 0
    for feature in features:
        before = old.get(feature["id"])
        if not before:
            continue
        mine = {k: v for k, v in feature["properties"].items() if k != "updated"}
        theirs = {k: v for k, v in before.get("properties", {}).items() if k != "updated"}
        if mine == theirs and before.get("geometry") == feature["geometry"]:
            stamp = before.get("properties", {}).get("updated")
            if isinstance(stamp, str) and stamp != feature["properties"]["updated"]:
                feature["properties"]["updated"] = stamp
                carried += 1
    return carried


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--ags",
        nargs="+",
        default=[FRANKFURT_AGS],
        help="Municipalities to build, by official AGS. Default: Frankfurt.",
    )
    args = parser.parse_args()

    rings_doc = json.loads((REPO / "data" / "rings.json").read_text(encoding="utf-8"))
    rings = {row["ags"]: row["ring"] for row in rings_doc["municipalities"]}
    unknown = [ags for ags in args.ags if ags not in rings]
    if unknown:
        raise SystemExit(f"not in data/rings.json: {', '.join(unknown)} — the region model must know it first")

    rows: list[dict] = []
    if FRANKFURT_AGS in args.ags:
        rows += wfs_features("Trinkbrunnen")
        rows += wfs_features("Erfrischungsbrunnen")
    for i, ags in enumerate(args.ags):
        if i:
            time.sleep(2)  # Overpass asks for it, and a rebuild is not urgent
        rows += osm_features(ags)

    merged, dropped = dedupe(rows)
    print(f"→ {len(rows)} Rohdatensätze, {dropped} zusammengeführt, {len(merged)} Features")

    today = date.today().isoformat()
    features = [to_feature(row, rings, today) for row in merged]
    features.sort(key=lambda f: f["id"])
    carried = carry_updated(features)
    if carried:
        print(f"  {carried} unveränderte Features behalten ihr altes 'updated'")

    # No build timestamp anywhere: same sources on the same day must produce
    # byte-identical output, or "re-runnable" is a claim nobody can check.
    document = {
        "version": 1,
        "id": DATASET_ID,
        "type": "FeatureCollection",
        "generator": "scripts/generate_fountains.py",
        "features": features,
    }
    text = json.dumps(document, ensure_ascii=False, indent=2) + "\n"
    for target in (REPO / "data" / FILENAME, KIT_RESOURCES / FILENAME):
        target.write_text(text, encoding="utf-8")
        print(f"✓ {target.relative_to(REPO)}")

    counts: dict[str, int] = {}
    for feature in features:
        counts[feature["properties"]["art"]] = counts.get(feature["properties"]["art"], 0) + 1
    print("  " + ", ".join(f"{k}: {v}" for k, v in sorted(counts.items())))
    print("  make validate")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
