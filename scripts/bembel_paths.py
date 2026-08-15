#!/usr/bin/env python3
"""Repository paths, in one place. Stdlib only — same no-pip rule as the
scripts that import it.

Four scripts each derived `REPO` themselves and three spelled out the
BEMBELKit resources path, one of them inline. Moving that directory meant
finding every copy; missing one meant a script that still ran and quietly
wrote to the wrong place.
"""

from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DATA = REPO / "data"
KIT_RESOURCES = REPO / "Packages" / "BEMBELKit" / "Sources" / "BEMBELKit" / "Resources"


def mirrored(name: str) -> tuple[Path, Path]:
    """Both copies of a curated file: the published one under `data/` and the
    bundled one in the Kit's resources.

    Every curated file exists twice and the two must stay byte-identical — the
    app reads the bundled copy offline, the publisher reads the other. The
    validator enforces the equality; generators write through this so they
    cannot write one and forget the other.
    """
    return DATA / name, KIT_RESOURCES / name
