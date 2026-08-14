#!/usr/bin/env python3
"""Schema validation for the curated data tier. Stdlib only — CI runs this
without a pip install.

Enforced here, not in any prompt (locked decision):
  - every operator-dataset row carries a source URL or the file is rejected
  - every curated GeoJSON feature carries id, name, ags, ring, sources[] and
    updated, and its ags/ring pair agrees with rings.json
  - payloads store facts only — scalars and lists of scalars, no prose blobs

Also enforced: data/rings.json and data/manifest.json are byte-identical to
their bundled copies in BEMBELKit/Resources, so app and published data can
never drift. Every data/*.geojson gets the same treatment.

The schemas under data/schema/ are the citable definitions; this file is what
actually rejects a bad dataset. scripts/test_validate_data.py proves it does.
"""

import json
import re
import sys
from datetime import date
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
KIT_RESOURCES = REPO / "Packages" / "BEMBELKit" / "Sources" / "BEMBELKit" / "Resources"

AGS_RE = re.compile(r"^\d{8}$")
DATASET_ID_RE = re.compile(r"^[a-z][a-z0-9_]*$")
FEATURE_ID_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")
ISO_DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
RINGS = {"frankfurt", "kernraum", "rheinmain"}
MAX_STRING_LEN = 300

# Generous box around the Rhein-Main region. This is not a plausibility check
# on the coordinate values — it is the swapped-lat/lon check. Frankfurt sits at
# lon 8.6 / lat 50.1, and a transposed pair is still two perfectly legal
# WGS84 numbers, so a plain -180..180 / -90..90 range test catches nothing.
LON_RANGE = (7.0, 10.0)
LAT_RANGE = (49.0, 51.2)

errors: list[str] = []


def err(msg: str) -> None:
    errors.append(msg)


def load(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        err(f"{path.relative_to(REPO)}: missing")
    except json.JSONDecodeError as exc:
        err(f"{path.relative_to(REPO)}: invalid JSON — {exc}")
    return None


def check_rings(doc, label: str) -> None:
    if doc is None:
        return
    if not isinstance(doc.get("version"), int):
        err(f"{label}: 'version' must be an integer")
    rows = doc.get("municipalities")
    if not isinstance(rows, list) or not rows:
        err(f"{label}: 'municipalities' must be a non-empty list")
        return
    seen: set[str] = set()
    for i, row in enumerate(rows):
        where = f"{label}: municipalities[{i}]"
        if not isinstance(row, dict):
            err(f"{where}: not an object")
            continue
        ags = row.get("ags")
        if not isinstance(ags, str) or not AGS_RE.match(ags):
            err(f"{where}: 'ags' must be 8 digits, got {ags!r}")
        elif ags in seen:
            err(f"{where}: duplicate ags {ags}")
        else:
            seen.add(ags)
        name = row.get("name")
        if not isinstance(name, str) or not name.strip():
            err(f"{where}: 'name' must be a non-empty string")
        if row.get("ring") not in RINGS:
            err(f"{where}: 'ring' must be one of {sorted(RINGS)}, got {row.get('ring')!r}")
    if "06412000" not in seen:
        err(f"{label}: Frankfurt (06412000) is missing")


def check_manifest(doc, label: str) -> None:
    if doc is None:
        return
    if not isinstance(doc.get("version"), int):
        err(f"{label}: 'version' must be an integer")
    base = doc.get("baseURL")
    if not isinstance(base, str) or not base.startswith("https://") or not base.endswith("/"):
        err(f"{label}: 'baseURL' must be https and end with '/', got {base!r}")
    datasets = doc.get("datasets")
    if not isinstance(datasets, dict) or not datasets:
        err(f"{label}: 'datasets' must be a non-empty object")
        return
    for dataset_id, entry in datasets.items():
        where = f"{label}: datasets['{dataset_id}']"
        if not DATASET_ID_RE.match(dataset_id):
            err(f"{where}: id must match {DATASET_ID_RE.pattern}")
        if not isinstance(entry, dict) or not isinstance(entry.get("path"), str):
            err(f"{where}: entry needs a string 'path'")
            continue
        path = entry["path"]
        if path.startswith("/") or ".." in path:
            err(f"{where}: 'path' must be relative and traversal-free, got {path!r}")
        for root, root_label in ((REPO / "data", "data/"), (KIT_RESOURCES, "Kit Resources/")):
            if not (root / path).is_file():
                err(f"{where}: '{path}' does not exist under {root_label}")
        if "url" in entry:
            url = entry["url"]
            if not isinstance(url, str) or not url.startswith("https://"):
                err(f"{where}: 'url' must be an https URL, got {url!r}")


def check_attribution(doc, label: str) -> None:
    if doc is None:
        return
    entries = doc.get("datasets")
    if not isinstance(entries, list):
        err(f"{label}: 'datasets' must be a list")
        return
    for i, entry in enumerate(entries):
        where = f"{label}: datasets[{i}]"
        if not isinstance(entry, dict):
            err(f"{where}: not an object")
            continue
        for field in ("id", "name", "source_url", "license", "license_url"):
            if not isinstance(entry.get(field), str) or not entry[field].strip():
                err(f"{where}: '{field}' must be a non-empty string")
        for field in ("source_url", "license_url"):
            value = entry.get(field)
            if isinstance(value, str) and not value.startswith(("https://", "http://")):
                err(f"{where}: '{field}' must be an http(s) URL")


def rings_index(doc) -> dict[str, str]:
    """ags → ring, from an already-checked rings table. An empty index means
    the rings file itself failed; the GeoJSON check then skips its
    cross-reference rather than blaming every feature for it."""
    if not isinstance(doc, dict) or not isinstance(doc.get("municipalities"), list):
        return {}
    return {
        row["ags"]: row["ring"]
        for row in doc["municipalities"]
        if isinstance(row, dict) and isinstance(row.get("ags"), str) and isinstance(row.get("ring"), str)
    }


def is_number(value) -> bool:
    # bool is an int in Python, and `true` is not a coordinate.
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def check_geometry(geometry, where: str) -> None:
    if not isinstance(geometry, dict):
        err(f"{where}: 'geometry' must be an object")
        return
    if geometry.get("type") != "Point":
        err(f"{where}: geometry type must be 'Point', got {geometry.get('type')!r}")
        return
    coordinates = geometry.get("coordinates")
    if not isinstance(coordinates, list) or len(coordinates) != 2 or not all(is_number(c) for c in coordinates):
        err(f"{where}: 'coordinates' must be [longitude, latitude], got {coordinates!r}")
        return
    lon, lat = coordinates
    if not LON_RANGE[0] <= lon <= LON_RANGE[1] or not LAT_RANGE[0] <= lat <= LAT_RANGE[1]:
        err(
            f"{where}: [{lon}, {lat}] is outside Rhein-Main "
            f"(lon {LON_RANGE[0]}–{LON_RANGE[1]}, lat {LAT_RANGE[0]}–{LAT_RANGE[1]}) — "
            "GeoJSON order is [longitude, latitude]; a swapped pair lands here"
        )


def check_feature_properties(props, where: str, rings: dict[str, str]) -> None:
    if not isinstance(props, dict):
        err(f"{where}: 'properties' must be an object")
        return

    name = props.get("name")
    if not isinstance(name, str) or not name.strip():
        err(f"{where}: 'name' must be a non-empty string")

    ags = props.get("ags")
    if not isinstance(ags, str) or not AGS_RE.match(ags):
        err(f"{where}: 'ags' must be 8 digits, got {ags!r}")
        ags = None
    elif rings and ags not in rings:
        err(f"{where}: ags {ags} is not in rings.json — the region model does not know this municipality")

    ring = props.get("ring")
    if ring not in RINGS:
        err(f"{where}: 'ring' must be one of {sorted(RINGS)}, got {ring!r}")
    elif ags and rings.get(ags) and rings[ags] != ring:
        err(f"{where}: ring {ring!r} contradicts rings.json, which puts {ags} in {rings[ags]!r}")

    updated = props.get("updated")
    if not isinstance(updated, str) or not ISO_DATE_RE.match(updated):
        err(f"{where}: 'updated' must be a YYYY-MM-DD date, got {updated!r}")
    else:
        try:
            date.fromisoformat(updated)
        except ValueError:
            err(f"{where}: 'updated' is not a real date: {updated!r}")

    sources = props.get("sources")
    if not isinstance(sources, list) or not sources:
        err(f"{where}: rejected — every feature must carry a non-empty 'sources' list")
    else:
        for i, source in enumerate(sources):
            if not isinstance(source, str) or not source.startswith(("https://", "http://")):
                err(f"{where}: sources[{i}] must be an http(s) URL, got {source!r}")

    for key, value in props.items():
        if key == "sources":
            continue
        if is_fact_scalar(value) or (isinstance(value, list) and all(is_fact_scalar(v) for v in value)):
            continue
        err(
            f"{where}: '{key}' rejected — facts only "
            f"(scalars or lists of scalars, strings ≤{MAX_STRING_LEN} chars, no newlines)"
        )


def check_geojson(doc, label: str, rings: dict[str, str]) -> None:
    """BEM-B01. One curated point layer, as published and as bundled."""
    if doc is None:
        return
    if not isinstance(doc, dict):
        err(f"{label}: not an object")
        return
    if not isinstance(doc.get("version"), int):
        err(f"{label}: 'version' must be an integer")
    dataset_id = doc.get("id")
    if not isinstance(dataset_id, str) or not DATASET_ID_RE.match(dataset_id):
        err(f"{label}: 'id' must match {DATASET_ID_RE.pattern}, got {dataset_id!r}")
    if doc.get("type") != "FeatureCollection":
        err(f"{label}: 'type' must be 'FeatureCollection', got {doc.get('type')!r}")

    features = doc.get("features")
    if not isinstance(features, list) or not features:
        err(f"{label}: 'features' must be a non-empty list")
        return

    seen: set[str] = set()
    for i, feature in enumerate(features):
        where = f"{label}: features[{i}]"
        if not isinstance(feature, dict):
            err(f"{where}: not an object")
            continue
        if feature.get("type") != "Feature":
            err(f"{where}: 'type' must be 'Feature', got {feature.get('type')!r}")
        feature_id = feature.get("id")
        if not isinstance(feature_id, str) or not FEATURE_ID_RE.match(feature_id):
            err(f"{where}: 'id' must match {FEATURE_ID_RE.pattern}, got {feature_id!r}")
        elif feature_id in seen:
            err(f"{where}: duplicate id {feature_id!r} — ids are how deep links and stamps name a place")
        else:
            seen.add(feature_id)
            where = f"{label}: features[{i}] ({feature_id})"
        check_geometry(feature.get("geometry"), where)
        check_feature_properties(feature.get("properties"), where, rings)


def check_geojson_datasets(rings: dict[str, str]) -> None:
    """Every curated layer under data/, plus its bundled twin. The directory
    holds none yet — the rules are already binding (same stance as BEM-B04)."""
    for path in sorted((REPO / "data").glob("*.geojson")):
        name = path.name
        check_geojson(load(path), f"data/{name}", rings)
        bundled = KIT_RESOURCES / name
        if bundled.is_file():
            check_geojson(load(bundled), f"Kit Resources/{name}", rings)
        else:
            err(f"Kit Resources/{name}: missing — every curated dataset ships bundled too")
        check_mirror(name)


def is_fact_scalar(value) -> bool:
    if value is None or isinstance(value, (bool, int, float)):
        return True
    if isinstance(value, str):
        return len(value) <= MAX_STRING_LEN and "\n" not in value
    return False


def check_operator_datasets() -> None:
    """BEM-B04 harness rules. The directory appears with the first operator
    dataset; the rules are already binding."""
    opdir = REPO / "data" / "operator"
    if not opdir.is_dir():
        return
    for path in sorted(opdir.glob("*.json")):
        label = str(path.relative_to(REPO))
        doc = load(path)
        if doc is None:
            continue
        rows = doc.get("rows") if isinstance(doc, dict) else None
        if not isinstance(rows, list) or not rows:
            err(f"{label}: operator datasets need a non-empty 'rows' list")
            continue
        for i, row in enumerate(rows):
            where = f"{label}: rows[{i}]"
            if not isinstance(row, dict):
                err(f"{where}: not an object")
                continue
            source = row.get("source_url")
            if not isinstance(source, str) or not source.startswith(("https://", "http://")):
                err(f"{where}: rejected — every row must carry an http(s) 'source_url'")
            for key, value in row.items():
                if is_fact_scalar(value):
                    continue
                if isinstance(value, list) and all(is_fact_scalar(v) for v in value):
                    continue
                err(
                    f"{where}: '{key}' rejected — facts only "
                    f"(scalars or lists of scalars, strings ≤{MAX_STRING_LEN} chars, no newlines)"
                )


def check_mirror(name: str) -> None:
    a, b = REPO / "data" / name, KIT_RESOURCES / name
    if a.is_file() and b.is_file() and a.read_bytes() != b.read_bytes():
        err(
            f"data/{name} and BEMBELKit Resources/{name} differ — "
            "regenerate both from the same source, never hand-edit one"
        )


def main() -> int:
    rings_doc = load(REPO / "data" / "rings.json")
    check_rings(rings_doc, "data/rings.json")
    check_rings(load(KIT_RESOURCES / "rings.json"), "Kit Resources/rings.json")
    check_manifest(load(REPO / "data" / "manifest.json"), "data/manifest.json")
    check_manifest(load(KIT_RESOURCES / "manifest.json"), "Kit Resources/manifest.json")
    check_attribution(load(REPO / "data" / "ATTRIBUTION.json"), "data/ATTRIBUTION.json")
    check_operator_datasets()
    check_geojson_datasets(rings_index(rings_doc))
    check_mirror("rings.json")
    check_mirror("manifest.json")
    check_mirror("bembeldata.json")

    if errors:
        print(f"FAIL — {len(errors)} problem(s):", file=sys.stderr)
        for problem in errors:
            print(f"  - {problem}", file=sys.stderr)
        return 1
    print("data validation OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
