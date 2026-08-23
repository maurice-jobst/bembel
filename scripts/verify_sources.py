#!/usr/bin/env python3
"""Liveness and drift check for data/sources.json. Stdlib only — same no-pip
rule as the rest of scripts/, so CI runs it without an install step.

    python3 scripts/verify_sources.py            # check every reachable source
    python3 scripts/verify_sources.py --tier 1   # only the load-bearing ones
    python3 scripts/verify_sources.py --stamp    # rewrite verified_at + observed on a clean run

A registry entry rots in two ways. The endpoint dies, which HTTP tells you, and
the endpoint quietly empties out, which it does not — a WFS layer that drops
from 270 features to 0 still answers 200. So every check compares its reading
against the `observed` block recorded when the entry was last verified, and a
collapse to nothing is a failure, not a note (LESSONS §E6: drift nobody sweeps
for is invisible by definition).

Coverage is enforced rather than assumed. plan() must produce a check for every
source that is not exempt-by-tier, and an entry it cannot plan for is reported
as a failure instead of being skipped in silence. scripts/test_validate_data.py
asserts that offline, so the registry cannot grow an unwatched entry.
"""

import argparse
import json
import re
import sys
import urllib.error
import urllib.request
from datetime import date

from bembel_paths import DATA

REGISTRY = DATA / "sources.json"

# Tier 3 needs a key we do not have, tier 5 has nothing to call. Both are
# recorded findings, not endpoints, so there is nothing to verify.
EXEMPT_TIERS = {3, 5}

# Which failures are worth waking someone for. Tier 1 is load-bearing and tier 2
# is live, so both are. Tier 4 is static reference data vendored at build time —
# nothing calls it at runtime, and the Frankfurt WFS hosts are intermittently
# slow enough that alerting on them would train everyone to ignore the alert
# (LESSONS §E1). Tier 0 is the sentinel for a source the verifier cannot reach
# at all, which is always actionable. Non-actionable failures are still printed.
ACTIONABLE_TIERS = {0, 1, 2}

WFS_HITS = "{base}?service=WFS&version=2.0.0&request=GetFeature&typeNames={typename}&resultType=hits"
CAPABILITIES = {"wfs": "?service=WFS&request=GetCapabilities", "wms": "?service=WMS&request=GetCapabilities"}
NUMBER_MATCHED = re.compile(rb'numberMatched="(\d+)"')
JSONP_WRAPPER = re.compile(rb"^[^(]*\(|\);?\s*$")

# Below this a 200 is almost always an error page or an empty envelope.
MIN_BODY = 200


class Check:
    """One request and the reading it should produce."""

    def __init__(self, label, url, kind, observed=None):
        self.label = label
        self.url = url
        self.kind = kind
        self.observed = observed or {}


def plan(source):
    """Yield the Checks for one source. Pure — no network, so it is testable."""
    sid, protocol = source["id"], source.get("protocol")
    observed = source.get("observed", {})

    if protocol == "wfs":
        base = source.get("base")
        if base:
            layers = source.get("layers") or ([{"typename": source["typename"]}] if source.get("typename") else [])
            if layers:
                for layer in layers:
                    yield Check(
                        f"{sid}/{layer['typename']}",
                        WFS_HITS.format(base=base, typename=layer["typename"]),
                        "hits",
                        layer.get("observed", observed if len(layers) == 1 else None),
                    )
            else:
                # A WFS with no layer named yet: GetCapabilities is still proof
                # of life, and is what the entry is claiming.
                yield Check(sid, base + CAPABILITIES["wfs"], "body")
        for name, url in (source.get("services") or {}).items():
            yield Check(f"{sid}/{name}", url + CAPABILITIES["wfs"], "body")

    elif protocol == "wms":
        for name, url in (source.get("services") or {}).items():
            yield Check(f"{sid}/{name}", url + CAPABILITIES["wms"], "body")

    elif protocol == "rest_json":
        url = source.get("url") or (source.get("base", "") + source.get("example", ""))
        if url:
            yield Check(sid, url, "json", observed)
        # A REST source can call more than one path. They were going unchecked
        # while looking checked, which is the tier-5-with-an-endpoint mistake
        # wearing a different hat. A service is either a full URL or a
        # {"path": ...} template relative to base, with {road} filled from the
        # first road the registry claims is relevant.
        for name, service in (source.get("services") or {}).items():
            if isinstance(service, dict):
                road = (source.get("roads_relevant") or ["A5"])[0]
                url = source.get("base", "") + service["path"].format(road=road)
            else:
                url = service
            yield Check(f"{sid}/{name}", url, "json")

    elif protocol == "jsonp":
        yield Check(sid, source["url"], "jsonp")

    elif protocol == "ckan_api":
        yield Check(sid, source["base"] + "/package_search?rows=0", "json")

    elif protocol == "gbfs":
        if source.get("discovery"):
            yield Check(sid, source["discovery"], "json")
        for name, url in (source.get("siblings") or {}).items():
            yield Check(f"{sid}/{name}", url, "json")

    elif protocol == "csv":
        # A plain file over HTTP. Nothing to introspect beyond "it is still
        # there and still has a body" — the column and unit assumptions are
        # checked in the app's own fixtures, where they can be checked
        # precisely rather than by counting bytes.
        yield Check(sid, source["url"], "body", observed)

    elif protocol in ("datex2_xml", "gtfs_static", "rdf_xml"):
        if source.get("url"):
            yield Check(sid, source["url"], "body", observed)
        for name, url in (source.get("feeds") or {}).items():
            yield Check(f"{sid}/{name}", url, "body")

    elif protocol is None:
        # Tier 4 has entries that are not an API at all: a plain file (the GBFS
        # systems catalogue) or a standing catalogue query. Both are still a URL
        # this repo believes in, and a URL can still 404.
        if source.get("url"):
            yield Check(sid, source["url"], "body", observed)
        if source.get("catalogue"):
            yield Check(sid, source["catalogue"], "json")


def coverage_gaps(registry):
    """Sources that should be checked and have no check. Offline."""
    return [
        s["id"]
        for s in registry["sources"]
        if s["tier"] not in EXEMPT_TIERS and s.get("auth", "none") == "none" and not list(plan(s))
    ]


def fetch(url, defaults):
    request = urllib.request.Request(url, headers={"User-Agent": defaults["user_agent"]})
    last = None
    for _ in range(defaults["retries"] + 1):
        try:
            with urllib.request.urlopen(request, timeout=defaults["timeout_s"]) as response:
                return response.status, response.read()
        except (urllib.error.URLError, OSError, TimeoutError) as exc:
            last = exc
    raise last


def read(check, body):
    """(reading, problem) — reading is what to record, problem fails the run."""
    if check.kind == "hits":
        match = NUMBER_MATCHED.search(body)
        if not match:
            return {}, "no numberMatched in the response"
        return {"count": int(match.group(1))}, None

    if check.kind in ("json", "jsonp"):
        payload = JSONP_WRAPPER.sub(b"", body.strip()) if check.kind == "jsonp" else body
        try:
            json.loads(payload)
        except ValueError as exc:
            return {}, f"not JSON — {exc}"
        return {"bytes": len(body)}, None

    if len(body) < MIN_BODY:
        return {"bytes": len(body)}, f"suspiciously small, {len(body)} bytes"
    return {"bytes": len(body)}, None


def drift(check, reading):
    """(message, is_failure). A count that collapsed to zero is a dead source
    wearing a 200; anything else that moved is just news."""
    was, now = check.observed.get("count"), reading.get("count")
    if was is None or now is None:
        return None, False
    if now == was:
        return None, False
    if now == 0:
        return f"was {was} features, now 0", True
    return f"{was} -> {now} features", False


def run(registry, tier_filter):
    defaults = {"timeout_s": 30, "retries": 2, "user_agent": "BEMBEL-verify/1.0"} | registry.get("defaults", {})
    failures, drifts, checked = [], [], 0

    for source in registry["sources"]:
        if source["tier"] in EXEMPT_TIERS or source.get("auth", "none") != "none":
            continue
        if tier_filter and source["tier"] not in tier_filter:
            continue

        for check in plan(source):
            checked += 1
            try:
                status, body = fetch(check.url, defaults)
                reading, problem = read(check, body)
                if status != 200:
                    problem = f"HTTP {status}"
            except Exception as exc:  # noqa: BLE001 — every transport failure reads the same here
                status, reading, problem = "ERR", {}, str(exc)[:80]

            note, fatal = (None, False) if problem else drift(check, reading)
            bad = bool(problem) or fatal
            detail = problem or note or ", ".join(f"{k}={v}" for k, v in reading.items())
            print(f"{'FAIL' if bad else 'DRIFT' if note else '  ok'}  {check.label:<46} {status}  {detail}")

            if bad:
                failures.append((source["tier"], check.label, detail))
            elif note:
                drifts.append((check.label, detail))

    return failures, drifts, checked


def stamp(registry, today):
    """Only the date. The observed numbers are a record of what a human looked
    at and reasoned about — a script that quietly rewrites them to match
    whatever came back turns the drift check into a check on nothing."""
    for source in registry["sources"]:
        if source["tier"] not in EXEMPT_TIERS and source.get("auth", "none") == "none":
            source["verified_at"] = today
    registry["updated"] = today
    with REGISTRY.open("w", encoding="utf-8") as fh:
        json.dump(registry, fh, ensure_ascii=False, indent=2)
        fh.write("\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tier", type=int, action="append", help="only this tier; repeatable")
    parser.add_argument("--stamp", action="store_true", help="rewrite verified_at when nothing failed")
    args = parser.parse_args()

    if args.stamp and args.tier:
        # Stamping writes verified_at across the registry, so a partial run
        # would date sources it never called — the exact lie the field exists
        # to prevent.
        parser.error("--stamp needs a full run; drop --tier")

    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))

    gaps = coverage_gaps(registry)
    for source_id in gaps:
        print(f"FAIL  {source_id:<46} —     no check defined — verify_sources.py cannot reach this entry")

    failures, drifts, checked = run(registry, set(args.tier or []))
    failures += [(0, source_id, "no check defined") for source_id in gaps]

    print(f"\n{checked} checks, {len(failures)} failure(s), {len(drifts)} drift(s). {date.today().isoformat()}.")
    for label, detail in drifts:
        print(f"  drift: {label} — {detail}")

    actionable = [f for f in failures if f[0] in ACTIONABLE_TIERS]
    if actionable:
        print(f"\n{len(actionable)} actionable (tier 1–2 or uncovered):", file=sys.stderr)
        for _, label, detail in actionable:
            print(f"  - {label}: {detail}", file=sys.stderr)
    for tier, label, detail in failures:
        if tier not in ACTIONABLE_TIERS:
            print(f"  noted (tier {tier}, not load-bearing): {label} — {detail}")

    if args.stamp:
        if failures:
            print("not stamping — fix the failures first", file=sys.stderr)
            return 1
        stamp(registry, date.today().isoformat())
        print("stamped verified_at")

    # Exit code is the alerting decision: 1 means a human should look. A slow
    # tier-4 host is reported and forgiven.
    return 1 if actionable else 0


if __name__ == "__main__":
    raise SystemExit(main())
