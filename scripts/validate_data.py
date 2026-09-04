#!/usr/bin/env python3
"""Schema validation for the curated data tier. Stdlib only — CI runs this
without a pip install.

Enforced here, not in any prompt (locked decision):
  - every operator-dataset row carries a source URL or the file is rejected
  - every curated GeoJSON feature carries id, name, ags, ring, sources[] and
    updated, and its ags/ring pair agrees with rings.json
  - payloads store facts only — scalars and lists of scalars, no prose blobs
  - every upstream is registered in data/sources.json, and an entry whose
    fields contradict its tier is rejected (a keyless tier that needs a key,
    a "no API exists" tier that carries an endpoint)

  - the three numbers README.md quotes about data/sources.json are recomputed
    from the registry, so the shop window cannot quietly go stale

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

import generate_data_sources_view
import verify_sources
from bembel_paths import DATA, KIT_RESOURCES, REPO, mirrored

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

# README.md states three numbers about data/sources.json. A number in the shop
# window that nobody recomputes is the failure docs/AI-NATIVE.md names under
# "Rules without teeth" — and by the time this check was written all three had
# rotted: 30 entries against 32, 39 endpoints against 48, nine tier-5 findings
# against six. Nothing had changed them, because nothing was reading them.
#
# Each claim is anchored to the prose around it, and a pattern that no longer
# matches is an error rather than a silent skip. That is the rule
# verify_sources.py already applies to a source it cannot plan a check for: an
# entry that looks watched and is not is worse than one that is openly missing.
# `\s+` between the words so reflowing a paragraph — which changes nothing a
# reader sees — does not read as a missing claim.
README_CLAIMS = (
    (
        "registered sources",
        re.compile(r"(\S+)\s+entries\s+across\s+the\s+Frankfurt\s+Geoportal"),
        len,
    ),
    (
        "endpoints the sweep calls",
        re.compile(r"calls\s+all\s+(\S+)\s+endpoints"),
        # A lambda only to defer the lookup: the function is defined below.
        lambda rows: planned_check_count(rows),
    ),
    (
        "tier-5 findings",
        re.compile(r"leave\s+out:\s+(\S+)\s+things\s+Frankfurt\s+does"),
        lambda rows: sum(1 for row in rows if row.get("tier") == 5),
    ),
)

# Enough to spell any count these claims will plausibly reach. Prose gets to say
# "six" instead of "6"; the check still has to read it.
NUMBER_WORDS = {
    "zero": 0,
    "one": 1,
    "two": 2,
    "three": 3,
    "four": 4,
    "five": 5,
    "six": 6,
    "seven": 7,
    "eight": 8,
    "nine": 9,
    "ten": 10,
    "eleven": 11,
    "twelve": 12,
}

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
        for root, root_label in ((DATA, "data/"), (KIT_RESOURCES, "Kit Resources/")):
            if not (root / path).is_file():
                err(f"{where}: '{path}' does not exist under {root_label}")
        if "url" in entry:
            url = entry["url"]
            if not isinstance(url, str) or not url.startswith("https://"):
                err(f"{where}: 'url' must be an https URL, got {url!r}")


def check_sources(doc, label: str) -> None:
    """data/sources.json — every upstream the app reads, and every upstream it
    looked for and did not find.

    This is not shipped data and is not mirrored into the bundle; ATTRIBUTION
    stays the licence record for what ships. What is enforced here is the part
    a JSON Schema cannot state: a tier is a claim about cost of access, so an
    entry whose fields contradict its tier is wrong even though every field is
    individually well-formed. Liveness is a separate concern — that is
    scripts/verify_sources.py, which runs against the network.
    """
    if doc is None:
        return
    if not isinstance(doc.get("version"), int):
        err(f"{label}: 'version' must be an integer")
    check_iso_date(doc.get("updated"), f"{label}: 'updated'")

    tiers = doc.get("tiers")
    if not isinstance(tiers, dict) or {"1", "2", "3", "4", "5"} - tiers.keys():
        err(f"{label}: 'tiers' must explain tiers 1 through 5 — JSON has no comments to hide the legend in")

    rows = doc.get("sources")
    if not isinstance(rows, list) or not rows:
        err(f"{label}: 'sources' must be a non-empty list")
        return

    seen: set[str] = set()
    for i, row in enumerate(rows):
        where = f"{label}: sources[{i}]"
        if not isinstance(row, dict):
            err(f"{where}: not an object")
            continue

        source_id = row.get("id")
        if not isinstance(source_id, str) or not DATASET_ID_RE.match(source_id):
            err(f"{where}: 'id' must match {DATASET_ID_RE.pattern}, got {source_id!r}")
        elif source_id in seen:
            err(f"{where}: duplicate id {source_id!r}")
        else:
            seen.add(source_id)
            where = f"{label}: sources[{i}] ({source_id})"

        if not isinstance(row.get("name"), str) or not row["name"].strip():
            err(f"{where}: 'name' must be a non-empty string")

        tier = row.get("tier")
        if tier not in (1, 2, 3, 4, 5):
            err(f"{where}: 'tier' must be 1–5, got {tier!r}")
            continue

        auth = row.get("auth", "none")
        if tier in (1, 2) and auth != "none":
            err(
                f"{where}: tier {tier} means keyless by definition, but 'auth' is {auth!r} — "
                "either the entry is really tier 3 or the auth note is stale"
            )
        if tier == 3 and auth == "none":
            err(f"{where}: tier 3 means onboarding is required, so 'auth' must say what it costs")

        if tier == 5:
            # A tier-5 entry is a recorded absence. Giving it an endpoint makes
            # it a tier-1..4 entry that the verifier will never check, because
            # it skips tier 5 — the one shape that rots invisibly.
            if not isinstance(row.get("finding"), str) or not row["finding"].strip():
                err(f"{where}: tier 5 records that no API was found — 'finding' must say what the search turned up")
            check_iso_date(row.get("searched_at"), f"{where}: 'searched_at'")
            for field in ("protocol", "base", "url", "feeds", "services", "discovery"):
                if field in row:
                    err(f"{where}: tier 5 means there is nothing to call, but it carries {field!r}")
        else:
            check_iso_date(row.get("verified_at"), f"{where}: 'verified_at'")

        for field in ("base", "url", "discovery", "catalogue", "portal"):
            value = row.get(field)
            if value is not None and (not isinstance(value, str) or not value.startswith("https://")):
                err(f"{where}: '{field}' must be an https URL, got {value!r}")

        for field in ("feeds", "services"):
            group = row.get(field)
            if group is None:
                continue
            if not isinstance(group, dict):
                err(f"{where}: '{field}' must be an object of name → endpoint, not a bare list")
                continue
            for name, value in group.items():
                if isinstance(value, str) and not value.startswith("https://"):
                    err(f"{where}: {field}['{name}'] must be an https URL, got {value!r}")

        gotchas = row.get("gotchas")
        if gotchas is not None and (
            not isinstance(gotchas, list) or not all(is_fact_scalar(g) and g for g in gotchas)
        ):
            err(f"{where}: 'gotchas' must be a list of one-line strings (≤{MAX_STRING_LEN} chars)")

        consumption = row.get("consumption")
        if consumption is not None:
            if consumption not in ("live", "bundled"):
                err(f"{where}: 'consumption' must be 'live' or 'bundled', got {consumption!r}")
            missing = [f for f in ("license", "attribution") if not row.get(f)]
            if missing:
                err(
                    f"{where}: consumption:{consumption} appears in Settings > Quellen, "
                    f"so it needs {missing} too"
                )

    for i, row in enumerate(doc.get("deprecated") or []):
        where = f"{label}: deprecated[{i}]"
        if not isinstance(row, dict):
            err(f"{where}: not an object")
            continue
        if not isinstance(row.get("status"), str) or not row["status"].strip():
            err(f"{where}: 'status' must say why it is dead — a bare id teaches nobody anything")
        check_iso_date(row.get("verified_at"), f"{where}: 'verified_at'")
        for replacement in row.get("replacement") or []:
            if replacement not in seen:
                err(f"{where}: replacement {replacement!r} is not a source id in this registry")


def planned_check_count(rows) -> int:
    """How many requests `make verify-sources` actually issues.

    verify_sources.plan() is the authority rather than a second count written
    out here — a number recomputed by different logic drifts from the sweep it
    claims to describe, which is the whole failure this check exists for.
    """
    return sum(
        len(list(verify_sources.plan(row)))
        for row in rows
        if row.get("tier") not in verify_sources.EXEMPT_TIERS and row.get("auth", "none") == "none"
    )


def as_number(raw: str):
    """A claim written as digits or as a word. None if it is neither."""
    return int(raw) if raw.isdigit() else NUMBER_WORDS.get(raw.lower())


def check_readme_claims(doc, label: str = "README.md", text: str | None = None) -> None:
    """The numbers README.md quotes about the source registry, recomputed.

    Not schema validation, but the same class of rule: a claim in the repo that
    a reader will believe, checked against the file it describes rather than
    against whoever last remembered to edit it. `text` is injectable so the
    tests can watch each way this fails without writing to the real README.
    """
    rows = doc.get("sources") if isinstance(doc, dict) else None
    if not isinstance(rows, list) or not rows:
        return  # check_sources has already rejected this; one complaint is enough

    if text is None:
        try:
            text = (REPO / "README.md").read_text(encoding="utf-8")
        except OSError as exc:
            err(f"{label}: unreadable — {exc}")
            return

    for name, pattern, compute in README_CLAIMS:
        match = pattern.search(text)
        if match is None:
            err(
                f"{label}: nothing matches {pattern.pattern!r} any more, so the {name} "
                "number is no longer checked — move the pattern with the prose or drop both"
            )
            continue
        claimed = as_number(match.group(1))
        if claimed is None:
            err(f"{label}: {name} reads {match.group(1)!r}, which is not a number this check can read")
            continue
        try:
            actual = compute(rows)
        except Exception as exc:  # noqa: BLE001 — a malformed registry is check_sources' complaint, not ours
            err(f"{label}: cannot recompute {name} from data/sources.json — {exc}")
            continue
        if claimed != actual:
            err(f"{label}: says {match.group(1)} {name}, data/sources.json has {actual}")


def check_iso_date(value, where: str) -> None:
    if not isinstance(value, str) or not ISO_DATE_RE.match(value):
        err(f"{where} must be a YYYY-MM-DD date, got {value!r}")
        return
    try:
        date.fromisoformat(value)
    except ValueError:
        err(f"{where} is not a real date: {value!r}")


def check_attribution(doc, label: str, source_ids: set[str] | None = None) -> None:
    """data/ATTRIBUTION.json — the licence record for datasets bundled at
    build time. `registry_id` (BEM-B06, #70) is the other half of that claim:
    every bundled dataset came from *somewhere*, and that somewhere belongs
    in data/sources.json too, not only in this file's free-text source_url.
    """
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
        registry_id = entry.get("registry_id")
        if not isinstance(registry_id, str) or not registry_id.strip():
            err(f"{where}: 'registry_id' must name the data/sources.json entry this dataset came from")
        elif source_ids is not None and registry_id not in source_ids:
            err(f"{where}: registry_id {registry_id!r} is not a source id in data/sources.json")


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

    check_iso_date(props.get("updated"), f"{where}: 'updated'")

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
    for path in sorted(DATA.glob("*.geojson")):
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
    opdir = DATA / "operator"
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
    a, b = mirrored(name)
    if a.is_file() and b.is_file() and a.read_bytes() != b.read_bytes():
        err(
            f"data/{name} and BEMBELKit Resources/{name} differ — "
            "regenerate both from the same source, never hand-edit one"
        )


def check_datasources_view(sources_doc, attribution_doc) -> None:
    """data/datasources.json is generated (scripts/generate_data_sources_view.py)
    — check_mirror above only proves the two shipped copies agree with each
    other, not that either agrees with data/sources.json and ATTRIBUTION.json.
    Recomputing here catches the case check_mirror cannot: someone edits the
    registry and forgets to re-run the generator, so both copies are
    identically stale (README_CLAIMS exists for the same reason)."""
    path = DATA / "datasources.json"
    if not path.is_file():
        err("data/datasources.json is missing — run scripts/generate_data_sources_view.py")
        return
    try:
        want = generate_data_sources_view.build(sources_doc, attribution_doc)
    except ValueError as exc:
        err(f"data/datasources.json: cannot regenerate — {exc}")
        return
    have = json.loads(path.read_text(encoding="utf-8"))
    if have != want:
        err(
            "data/datasources.json is stale — run "
            "'python3 scripts/generate_data_sources_view.py' and commit both copies"
        )


def main() -> int:
    rings_doc = load(DATA / "rings.json")
    check_rings(rings_doc, "data/rings.json")
    check_rings(load(KIT_RESOURCES / "rings.json"), "Kit Resources/rings.json")
    check_manifest(load(DATA / "manifest.json"), "data/manifest.json")
    check_manifest(load(KIT_RESOURCES / "manifest.json"), "Kit Resources/manifest.json")
    sources_doc = load(DATA / "sources.json")
    source_ids = {row["id"] for row in sources_doc.get("sources", []) if isinstance(row.get("id"), str)}
    attribution_doc = load(DATA / "ATTRIBUTION.json")
    check_attribution(attribution_doc, "data/ATTRIBUTION.json", source_ids)
    check_sources(sources_doc, "data/sources.json")
    check_readme_claims(sources_doc)
    check_operator_datasets()
    check_geojson_datasets(rings_index(rings_doc))
    check_mirror("rings.json")
    check_mirror("manifest.json")
    check_mirror("datasources.json")
    if not errors:
        check_datasources_view(sources_doc, attribution_doc)
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
