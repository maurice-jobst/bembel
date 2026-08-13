#!/usr/bin/env python3
"""Schema validation for the curated data tier. Stdlib only — CI runs this
without a pip install.

Enforced here, not in any prompt (locked decision):
  - every operator-dataset row carries a source URL or the file is rejected
  - payloads store facts only — scalars and lists of scalars, no prose blobs

Also enforced: data/rings.json and data/manifest.json are byte-identical to
their bundled copies in BEMBELKit/Resources, so app and published data can
never drift.
"""

import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
KIT_RESOURCES = REPO / "Packages" / "BEMBELKit" / "Sources" / "BEMBELKit" / "Resources"

AGS_RE = re.compile(r"^\d{8}$")
DATASET_ID_RE = re.compile(r"^[a-z][a-z0-9_]*$")
RINGS = {"frankfurt", "kernraum", "rheinmain"}
MAX_STRING_LEN = 300

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
    check_rings(load(REPO / "data" / "rings.json"), "data/rings.json")
    check_rings(load(KIT_RESOURCES / "rings.json"), "Kit Resources/rings.json")
    check_manifest(load(REPO / "data" / "manifest.json"), "data/manifest.json")
    check_manifest(load(KIT_RESOURCES / "manifest.json"), "Kit Resources/manifest.json")
    check_attribution(load(REPO / "data" / "ATTRIBUTION.json"), "data/ATTRIBUTION.json")
    check_operator_datasets()
    check_mirror("rings.json")
    check_mirror("manifest.json")

    if errors:
        print(f"FAIL — {len(errors)} problem(s):", file=sys.stderr)
        for problem in errors:
            print(f"  - {problem}", file=sys.stderr)
        return 1
    print("data validation OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
