#!/usr/bin/env python3
"""Refresh the bundled bembel-data snapshot in both places.

The app ships a snapshot so a cold install works offline (BEM-A05). That file
is generated — run this before a release, or whenever the register looks stale
in a fresh build. Stdlib only.

    python3 scripts/sync_bembel_data.py                  # from the published dist branch
    python3 scripts/sync_bembel_data.py --from ../bembel-data/dist/bembel-data.json
"""

import argparse
import json
import sys
import urllib.request
from pathlib import Path

from bembel_paths import mirrored

SOURCE = "https://raw.githubusercontent.com/maurice-jobst/bembel-data/dist/bembel-data.json"
REQUIRED = {"schemaVersion", "entries", "contributors"}


def fetch(origin: str) -> bytes:
    if origin.startswith(("http://", "https://")):
        with urllib.request.urlopen(origin, timeout=30) as response:
            return response.read()
    return Path(origin).read_bytes()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--from", dest="origin", default=SOURCE)
    args = parser.parse_args()

    raw = fetch(args.origin)
    try:
        doc = json.loads(raw)
    except json.JSONDecodeError as exc:
        print(f"FAIL — {args.origin} is not JSON: {exc}", file=sys.stderr)
        return 1
    if missing := REQUIRED - doc.keys():
        print(f"FAIL — bundle is missing {sorted(missing)}; refusing to ship it", file=sys.stderr)
        return 1

    for target in mirrored("bembeldata.json"):
        target.write_bytes(raw)

    print(
        f"snapshot updated from {args.origin}: "
        f"{len(doc['entries'])} entries, schemaVersion {doc['schemaVersion']}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
