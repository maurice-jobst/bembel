#!/usr/bin/env python3
"""Generate data/datasources.json — the filtered, app-facing view of the
upstream registry (BEM-B06, #70).

data/sources.json is an operator document: gotchas, request templates, tier-5
"we looked and found nothing" rows — none of that belongs on a Settings
screen, and shipping it verbatim would also ship the internal notes. This
script produces the small subset `DataSourcesView` actually reads and writes
both copies (data/ and the BEMBELKit resource) so they can never drift;
scripts/validate_data.py enforces byte equality and recomputes this same
output to catch a stale commit.

Two groups, matching how the app actually gets each upstream's data:

  live    — the running app requests this over the network. Registry rows
            tagged `"consumption": "live"`.
  bundled — fetched once by a script or pipeline and shipped in the app
            bundle. Sourced from data/ATTRIBUTION.json, the licence record
            for what ships — not from the `"bundled"`-tagged sources.json
            rows, which exist only so ATTRIBUTION rows have something to
            point `registry_id` at (see check_attribution_registry_links).

A row with no `consumption` tag — registered but not (yet) called — appears
in neither group. That is the fix for the bug this ticket exists to close:
the old hand-typed array listed RMV and HLNUG as sources this app reads,
and it read neither.

    python3 scripts/generate_data_sources_view.py
"""

import json
import sys

from bembel_paths import DATA, mirrored

REQUIRED_FOR_CONSUMPTION = ("name", "license", "attribution")


def build(sources_doc: dict, attribution_doc: dict) -> dict:
    """Pure — no I/O, so validate_data.py can call it to check freshness."""
    live = []
    for row in sources_doc.get("sources", []):
        if row.get("consumption") != "live":
            continue
        missing = [f for f in REQUIRED_FOR_CONSUMPTION if not row.get(f)]
        if missing:
            raise ValueError(f"{row.get('id')}: consumption:live but missing {missing}")
        entry = {"id": row["id"], "name": row["name"], "tier": row["tier"], "license": row["license"], "attribution": row["attribution"]}
        if row.get("status"):
            entry["status"] = row["status"]
        live.append(entry)

    bundled = []
    for row in attribution_doc.get("datasets", []):
        bundled.append(
            {
                "id": row["id"],
                "name": row["name"],
                "license": row["license"],
                "attribution": row["attribution"],
            }
        )

    live.sort(key=lambda e: e["id"])
    bundled.sort(key=lambda e: e["id"])
    return {
        "version": 1,
        "updated": sources_doc["updated"],
        "live": live,
        "bundled": bundled,
    }


def main() -> int:
    sources_doc = json.loads((DATA / "sources.json").read_text(encoding="utf-8"))
    attribution_doc = json.loads((DATA / "ATTRIBUTION.json").read_text(encoding="utf-8"))
    doc = build(sources_doc, attribution_doc)

    for target in mirrored("datasources.json"):
        with target.open("w", encoding="utf-8") as fh:
            json.dump(doc, fh, ensure_ascii=False, indent=2)
            fh.write("\n")

    print(f"datasources.json: {len(doc['live'])} live, {len(doc['bundled'])} bundled")
    return 0


if __name__ == "__main__":
    sys.exit(main())
