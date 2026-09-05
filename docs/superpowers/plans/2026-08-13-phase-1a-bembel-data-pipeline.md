# Phase 1a — bembel-data publishing pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn bembel-data from a schema repo into a publishing pipeline: one deterministic JSON bundle per merge — entries, aggregated ratings, git-derived provenance, contributor tallies, coverage counts — served at a stable URL the BEMBEL app can fetch by conditional GET.

**Architecture:** A stdlib-only Python builder (`scripts/build_bundle.py`) reads the checked-in entry and rating files plus `git log`, and writes `dist/bembel-data.json`. A workflow runs it on every push to `main` and force-publishes the single file onto an orphan `dist` branch, so `main` stays source-only and the app fetches `raw.githubusercontent.com/.../dist/bembel-data.json` — no redirect, clean ETag, no bot commits on `main`. Tagged releases attach the same bytes as a versioned archive (the README already promises versioned bundles). Determinism per ADR 0008: `generatedAt` is the HEAD commit date, never `now()`; every list is sorted; same commit in → same bytes out.

**Tech Stack:** Python 3 (stdlib only — no `pip`, the repo's hard rule), `git`, GitHub Actions, JSON Schema (validated by the repo's own `scripts/validate.py` subset validator, not by a library).

## Global Constraints

- **Repo for every task here: `~/Projects/bembel-data`** (github.com/maurice-jobst/bembel-data, public, ODbL 1.0). Nothing in this plan touches the BEMBEL app repo — that is Phase 1b.
- **Stdlib only.** No `pip install`, no third-party GitHub Actions beyond `actions/checkout@v5`. This is the repo's stated promise ("Abhängigkeiten: keine") and a README claim.
- **German is the source language** for all docs, issue forms, workflow names, and commit messages in this repo. Code identifiers and JSON keys stay English/camelCase (the schemas already are).
- **No fabrication.** Every seeded entry carries real, verifiable `sources` URLs that were actually read. An entry whose facts cannot be sourced does not get written. `verified` stays `false` — only Maurice flips it.
- **Bundle URL of record:** `https://raw.githubusercontent.com/maurice-jobst/bembel-data/dist/bembel-data.json`. Phase 1b hardcodes this in the app manifest; do not change it without updating Phase 1b Task 3.
- **Rating trust model is untouchable:** `data/bewertungen/<entry-id>/<login>.json`, filename = PR author, enforced by `scripts/check_authorship.py`. Nothing here weakens it.
- Existing CI (`validate.yml`, `rating-authorship.yml`) must stay green throughout.
- One PR per task group; squash merge. Commits signed via the 1Password SSH agent — if signing fails ("agent refused operation"), ask Maurice to unlock 1Password and retry.

---

### Task 1: Merkmale vocabulary, districts, Ebbelwei features

Extends the schemas so one Merkmale vocabulary spans both registers (the app's Merkmale-first navigation needs a single tag namespace) and so coverage can be grouped by Stadtteil.

**Files:**
- Modify: `schemas/wasserhaeuschen.schema.json`
- Modify: `schemas/ebbelwei.schema.json`
- Modify: `data/wasserhaeuschen/yok-yok.json`
- Modify: `README.md` (dataset table row wording only)

**Interfaces:**
- Produces: the Merkmale vocabulary `sitzplaetze | eigenmarke | kunst | spaeti | historisch | trinkhalle-klassisch | spaet-offen | baenke-draussen | ebbelwei` (Wasserhäuschen) and `garten | eigenkelterei | historisch | sitzplaetze | handkaes | schoppen-vom-fass` (Ebbelwei); an optional `district` string on both. Task 2's builder reads `features` + `garden` + `eigenkelterei` and emits a unified `merkmale` array. Phase 1b's `Merkmal` type mirrors these raw values exactly.

- [ ] **Step 1: Create the branch**

```bash
cd /Users/krazykraut/Projects/bembel-data && git checkout -b feat/bundle-pipeline
```

- [ ] **Step 2: Extend the Wasserhäuschen schema**

In `schemas/wasserhaeuschen.schema.json`, replace the `features` property with the extended enum and add `district` after `address`:

```json
    "district": {
      "type": "string",
      "description": "Stadtteil, wie ihn die Stadt schreibt (z. B. \"Bahnhofsviertel\") — Grundlage der Abdeckungsanzeige in der App"
    },
    "features": {
      "type": "array",
      "items": {
        "enum": [
          "sitzplaetze",
          "eigenmarke",
          "kunst",
          "spaeti",
          "historisch",
          "trinkhalle-klassisch",
          "spaet-offen",
          "baenke-draussen",
          "ebbelwei"
        ]
      },
      "uniqueItems": true,
      "description": "Merkmale — in der App die Hauptnavigation, nicht ein Filter im Untermenü"
    },
```

Keep every other property untouched, and keep `district` out of `required` (unknown Stadtteil must stay legal).

- [ ] **Step 3: Extend the Ebbelwei schema**

In `schemas/ebbelwei.schema.json`, add `district` (same block as Step 2) and a `features` array, leaving `garden`, `gardenSeason` and `eigenkelterei` in place — the booleans stay the schema's truth, the builder projects them into Merkmale:

```json
    "features": {
      "type": "array",
      "items": {
        "enum": [
          "garten",
          "eigenkelterei",
          "historisch",
          "sitzplaetze",
          "handkaes",
          "schoppen-vom-fass"
        ]
      },
      "uniqueItems": true,
      "description": "Merkmale. \"garten\" und \"eigenkelterei\" leitet der Bundle-Bau zusätzlich aus den Feldern garden/eigenkelterei ab."
    },
```

- [ ] **Step 4: Backfill the seed entry**

In `data/wasserhaeuschen/yok-yok.json`, add `"district": "Bahnhofsviertel"` directly after the `address` object and add `"spaet-offen"` to `features` (the Bahnhofsviertel kiosk's late hours are the documented fact in the linked Gewerbeverein source; if that source does not state opening hours, leave `features` untouched and skip this half of the step — no fabrication).

- [ ] **Step 5: Validate**

```bash
cd /Users/krazykraut/Projects/bembel-data && python3 scripts/validate.py
```

Expected: `data validation OK (1 entries)`.

- [ ] **Step 6: Commit**

```bash
git add schemas data README.md && git commit -m "Schema: gemeinsames Merkmale-Vokabular, Stadtteil-Feld, Ebbelwei-Merkmale"
```

---

### Task 2: The bundle builder

**Files:**
- Create: `scripts/build_bundle.py`
- Create: `logins.json`
- Modify: `.gitignore` (create if absent) — ignore `dist/`

**Interfaces:**
- Consumes: Task 1's schema fields.
- Produces: `dist/bembel-data.json` with the exact shape below. Phase 1b Task 2's `BembelDataBundle` DTO decodes exactly these keys; changing a key name here breaks the app.

```json
{
  "schemaVersion": 1,
  "generatedAt": "2026-08-13T18:04:11+00:00",
  "commit": "0912f28",
  "entries": [
    {
      "id": "yok-yok",
      "kind": "wasserhaeuschen",
      "name": "City Kiosk Yok-Yok",
      "address": {"street": "Münchener Straße 32", "postalCode": "60329", "city": "Frankfurt am Main"},
      "district": "Bahnhofsviertel",
      "latitude": 50.10761,
      "longitude": 8.66833,
      "openingHours": null,
      "since": null,
      "merkmale": ["eigenmarke", "kunst", "spaeti"],
      "note": "…",
      "sources": ["https://…"],
      "verified": false,
      "provenance": {
        "lastEditor": "maurice-jobst",
        "lastChangedAt": "2026-08-13T12:00:00+00:00",
        "verifiedAt": null,
        "historyURL": "https://github.com/maurice-jobst/bembel-data/commits/main/data/wasserhaeuschen/yok-yok.json",
        "fileURL": "https://github.com/maurice-jobst/bembel-data/blob/main/data/wasserhaeuschen/yok-yok.json"
      },
      "rating": null
    }
  ],
  "contributors": [
    {"login": "maurice-jobst", "entries": 1, "verifications": 0, "ratings": 0, "firstRatings": []}
  ],
  "coverage": [
    {"district": "Bahnhofsviertel", "verified": 0, "candidates": 1}
  ]
}
```

- [ ] **Step 1: Write the login table**

Create `logins.json` — the only way a commit's author email becomes a GitHub `@handle` when it isn't a `users.noreply.github.com` address. Unmapped emails yield `null`, and the app's byline then shows the date and source without a handle. Never guess a login from a display name.

```json
{
  "lalebecreations@gmail.com": "maurice-jobst"
}
```

- [ ] **Step 2: Write the builder**

Create `scripts/build_bundle.py`:

```python
#!/usr/bin/env python3
"""Baut das veröffentlichte Daten-Bundle aus Einträgen, Bewertungen und der
Git-Historie. Nur Standardbibliothek und git — keine Abhängigkeiten.

Ausgabe: dist/bembel-data.json, die Datei, die die BEMBEL-App per Conditional
GET lädt (BEM-S11).

Deterministisch: derselbe Commit erzeugt dieselben Bytes. `generatedAt` ist das
Datum von HEAD, nicht die Uhrzeit des Laufs; alle Listen sind sortiert.
"""

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REPO_URL = "https://github.com/maurice-jobst/bembel-data"
REGISTERS = ("wasserhaeuschen", "ebbelwei")
SCHEMA_VERSION = 1
NOREPLY = "@users.noreply.github.com"


def git(*args: str) -> str:
    return subprocess.run(
        ["git", "-C", str(ROOT), *args],
        check=True,
        capture_output=True,
        text=True,
    ).stdout


def load_logins() -> dict[str, str]:
    path = ROOT / "logins.json"
    if not path.is_file():
        return {}
    return {k.lower(): v for k, v in json.loads(path.read_text(encoding="utf-8")).items()}


def resolve_login(email: str, table: dict[str, str]) -> str | None:
    """GitHub-Login aus der Autor-Mail. Nur ableiten, nie raten."""
    email = email.strip().lower()
    if email.endswith(NOREPLY):
        local = email[: -len(NOREPLY)]
        return local.split("+", 1)[1] if "+" in local else local
    return table.get(email)


def history(rel: str) -> list[tuple[str, str, str]]:
    """Commits, die rel berühren, älteste zuerst: (sha, ISO-Datum, Autor-Mail)."""
    out = git("log", "--reverse", "--format=%H%x1f%aI%x1f%ae", "--", rel)
    rows = []
    for line in out.splitlines():
        if line.strip():
            sha, date, email = line.split("\x1f")
            rows.append((sha, date, email))
    return rows


def blob_at(sha: str, rel: str):
    try:
        return json.loads(git("show", f"{sha}:{rel}"))
    except (subprocess.CalledProcessError, json.JSONDecodeError):
        return None


def provenance(rel: str, table: dict[str, str]) -> tuple[dict, str | None, str | None]:
    """(provenance-Block, Login des Ersterstellers, Login des Verifizierers)."""
    commits = history(rel)
    creator = resolve_login(commits[0][2], table) if commits else None

    verified_at = None
    verifier = None
    was_verified = False
    for sha, date, email in commits:
        doc = blob_at(sha, rel)
        if doc is None:
            continue
        now_verified = bool(doc.get("verified"))
        if now_verified and not was_verified:
            verified_at, verifier = date, resolve_login(email, table)
        elif not now_verified:
            verified_at, verifier = None, None
        was_verified = now_verified

    last = commits[-1] if commits else None
    return (
        {
            "lastEditor": resolve_login(last[2], table) if last else None,
            "lastChangedAt": last[1] if last else None,
            "verifiedAt": verified_at,
            "historyURL": f"{REPO_URL}/commits/main/{rel}",
            "fileURL": f"{REPO_URL}/blob/main/{rel}",
        },
        creator,
        verifier,
    )


def merkmale_for(kind: str, doc: dict) -> list[str]:
    tags = set(doc.get("features") or [])
    if kind == "ebbelwei":
        if doc.get("garden"):
            tags.add("garten")
        if doc.get("eigenkelterei"):
            tags.add("eigenkelterei")
    return sorted(tags)


def collect_ratings() -> dict[str, list[dict]]:
    """entry-id -> Bewertungen, sortiert nach (Datum, Login)."""
    by_entry: dict[str, list[dict]] = {}
    for path in sorted((ROOT / "data" / "bewertungen").glob("*/*.json")):
        doc = json.loads(path.read_text(encoding="utf-8"))
        by_entry.setdefault(path.parent.name, []).append(
            {
                "login": doc["login"],
                "stars": doc["stars"],
                "date": doc["date"],
                "comment": doc.get("comment"),
            }
        )
    for ratings in by_entry.values():
        ratings.sort(key=lambda r: (r["date"], r["login"]))
    return by_entry


def summarise(ratings: list[dict]) -> dict:
    total = sum(r["stars"] for r in ratings)
    return {
        "average": round(total / len(ratings), 2),
        "count": len(ratings),
        "ratings": ratings,
    }


def main() -> int:
    table = load_logins()
    ratings_by_entry = collect_ratings()
    tallies: dict[str, dict] = {}

    def tally(login: str | None) -> dict | None:
        if not login:
            return None
        return tallies.setdefault(
            login,
            {"login": login, "entries": 0, "verifications": 0, "ratings": 0, "firstRatings": []},
        )

    entries = []
    for kind in REGISTERS:
        for path in sorted((ROOT / "data" / kind).glob("*.json")):
            rel = str(path.relative_to(ROOT))
            doc = json.loads(path.read_text(encoding="utf-8"))
            prov, creator, verifier = provenance(rel, table)

            if (row := tally(creator)) is not None:
                row["entries"] += 1
            if (row := tally(verifier)) is not None:
                row["verifications"] += 1

            ratings = ratings_by_entry.get(doc["id"], [])
            if ratings and (row := tally(ratings[0]["login"])) is not None:
                row["firstRatings"].append(doc["id"])

            entries.append(
                {
                    "id": doc["id"],
                    "kind": kind,
                    "name": doc["name"],
                    "address": doc["address"],
                    "district": doc.get("district"),
                    "latitude": doc["latitude"],
                    "longitude": doc["longitude"],
                    "openingHours": doc.get("openingHours"),
                    "since": doc.get("since"),
                    "merkmale": merkmale_for(kind, doc),
                    "note": doc.get("note"),
                    "sources": doc["sources"],
                    "verified": bool(doc.get("verified")),
                    "provenance": prov,
                    "rating": summarise(ratings) if ratings else None,
                }
            )

    for entry_id, ratings in ratings_by_entry.items():
        for rating in ratings:
            if (row := tally(rating["login"])) is not None:
                row["ratings"] += 1

    coverage: dict[str, dict] = {}
    for entry in entries:
        area = entry["district"] or entry["address"]["city"]
        row = coverage.setdefault(area, {"district": area, "verified": 0, "candidates": 0})
        row["verified" if entry["verified"] else "candidates"] += 1

    head_date = git("log", "-1", "--format=%aI").strip()
    head_sha = git("log", "-1", "--format=%h").strip()

    bundle = {
        "schemaVersion": SCHEMA_VERSION,
        "generatedAt": head_date,
        "commit": head_sha,
        "entries": sorted(entries, key=lambda e: (e["kind"], e["id"])),
        "contributors": sorted(tallies.values(), key=lambda c: c["login"]),
        "coverage": sorted(coverage.values(), key=lambda c: c["district"]),
    }
    for contributor in bundle["contributors"]:
        contributor["firstRatings"].sort()

    out = ROOT / "dist" / "bembel-data.json"
    out.parent.mkdir(exist_ok=True)
    out.write_text(
        json.dumps(bundle, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(
        f"dist/bembel-data.json: {len(bundle['entries'])} Einträge, "
        f"{len(bundle['contributors'])} Mitwirkende, {len(bundle['coverage'])} Stadtteile"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 3: Ignore the build output**

`dist/` is a build artefact on `main` — it only exists as content on the `dist` branch. Create or extend `.gitignore`:

```
dist/
```

- [ ] **Step 4: Run it**

```bash
cd /Users/krazykraut/Projects/bembel-data && python3 scripts/build_bundle.py && python3 -c "import json;print(json.dumps(json.load(open('dist/bembel-data.json'))['entries'][0]['provenance'],indent=2,ensure_ascii=False))"
```

Expected: the summary line reports 1 entry, and the printed provenance block has a real `historyURL`, a `lastChangedAt` timestamp, `verifiedAt: null`, and `lastEditor` either `"maurice-jobst"` (if `logins.json` matched) or `null` — never a display name.

- [ ] **Step 5: Prove determinism**

```bash
cd /Users/krazykraut/Projects/bembel-data && cp dist/bembel-data.json /tmp/bundle-a.json && python3 scripts/build_bundle.py && diff /tmp/bundle-a.json dist/bembel-data.json && echo "byte-identisch"
```

Expected: `byte-identisch`. If it differs, something non-deterministic leaked in — fix it before moving on; the conditional-GET contract depends on identical bytes producing an identical ETag.

- [ ] **Step 6: Prove aggregation with a throwaway rating**

```bash
cd /Users/krazykraut/Projects/bembel-data && mkdir -p data/bewertungen/yok-yok && cat > data/bewertungen/yok-yok/maurice-jobst.json <<'JSON'
{
  "entry": "yok-yok",
  "login": "maurice-jobst",
  "stars": 5,
  "date": "2026-08-13",
  "comment": "Testbewertung, wird gleich wieder entfernt."
}
JSON
python3 scripts/validate.py && python3 scripts/build_bundle.py && python3 -c "import json;b=json.load(open('dist/bembel-data.json'));print(b['entries'][0]['rating']);print(b['contributors'])"
```

Expected: `{'average': 5.0, 'count': 1, 'ratings': [...]}` and a contributor row with `ratings: 1` and `firstRatings: ['yok-yok']`.

Then remove the throwaway rating — it is not a real rating and must not be committed:

```bash
cd /Users/krazykraut/Projects/bembel-data && rm -r data/bewertungen/yok-yok && git status --short
```

Expected: only `scripts/build_bundle.py`, `logins.json` and `.gitignore` show as changes.

- [ ] **Step 7: Commit**

```bash
git add scripts/build_bundle.py logins.json .gitignore && git commit -m "Bundle: deterministischer Bau aus Einträgen, Bewertungen und Git-Historie"
```

---

### Task 3: Publishing workflow + release archive

**Files:**
- Create: `.github/workflows/publish.yml`

**Interfaces:**
- Consumes: `scripts/build_bundle.py` (Task 2).
- Produces: the live URL `https://raw.githubusercontent.com/maurice-jobst/bembel-data/dist/bembel-data.json`, refreshed on every push to `main`; a `bembel-data.json` asset on every tagged release.

- [ ] **Step 1: Write the workflow**

Create `.github/workflows/publish.yml`:

```yaml
name: Bundle veröffentlichen

on:
  push:
    branches: [main]
  release:
    types: [published]
  workflow_dispatch:

permissions:
  contents: write

concurrency:
  group: publish
  cancel-in-progress: false

jobs:
  bundle:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
        with:
          fetch-depth: 0

      - name: Daten prüfen
        run: python3 scripts/validate.py

      - name: Bundle bauen
        run: python3 scripts/build_bundle.py

      - name: dist-Branch aktualisieren
        run: |
          set -euo pipefail
          git config user.name "bembel-data"
          git config user.email "noreply@github.com"
          work="$RUNNER_TEMP/dist"
          if git ls-remote --exit-code --heads origin dist >/dev/null 2>&1; then
            git fetch origin dist
            git worktree add "$work" origin/dist
            git -C "$work" checkout -B dist
          else
            git worktree add --detach "$work"
            git -C "$work" checkout --orphan dist
            git -C "$work" rm -rf . >/dev/null 2>&1 || true
          fi
          cp dist/bembel-data.json "$work/bembel-data.json"
          git -C "$work" add bembel-data.json
          if git -C "$work" diff --cached --quiet; then
            echo "Bundle unverändert — kein Push."
            exit 0
          fi
          git -C "$work" commit -m "Bundle für ${GITHUB_SHA:0:7}"
          git -C "$work" push origin dist

      - name: Release-Asset anhängen
        if: github.event_name == 'release'
        env:
          GH_TOKEN: ${{ github.token }}
        run: gh release upload "${{ github.event.release.tag_name }}" dist/bembel-data.json --clobber
```

- [ ] **Step 2: Commit and open the PR**

```bash
cd /Users/krazykraut/Projects/bembel-data && git add .github/workflows/publish.yml && git commit -m "CI: Bundle auf den dist-Branch veröffentlichen, Release-Asset anhängen" && git push -u origin feat/bundle-pipeline
gh pr create -R maurice-jobst/bembel-data --title "Bundle-Pipeline: Merkmale-Vokabular, deterministischer Bau, dist-Veröffentlichung" --body "Phase 1a der BEMBEL-Hero-Umsetzung.

- Gemeinsames Merkmale-Vokabular über beide Register, optionales \`district\`-Feld
- \`scripts/build_bundle.py\`: aggregierte Bewertungen, Provenienz aus der Git-Historie, Mitwirkenden-Zählung, Abdeckung je Stadtteil — nur Standardbibliothek, byte-deterministisch
- \`publish.yml\`: veröffentlicht \`bembel-data.json\` auf den Orphan-Branch \`dist\` (die App lädt es per Conditional GET von raw.githubusercontent.com) und hängt es an Releases an

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

- [ ] **Step 3: Merge and verify the pipeline actually ran**

```bash
gh pr merge -R maurice-jobst/bembel-data --squash --delete-branch
gh run watch -R maurice-jobst/bembel-data
curl -sI https://raw.githubusercontent.com/maurice-jobst/bembel-data/dist/bembel-data.json | rg -i '^(HTTP|etag|content-length)'
```

Expected: HTTP 200 with an `ETag` header. The ETag is the whole point — Phase 1b's loader sends it back as `If-None-Match`. If the header is missing, stop and reconsider the hosting choice before building the app side on it.

- [ ] **Step 4: Confirm the conditional GET round-trip**

```bash
etag=$(curl -sI https://raw.githubusercontent.com/maurice-jobst/bembel-data/dist/bembel-data.json | rg -i '^etag' | tr -d '\r' | cut -d' ' -f2)
curl -s -o /dev/null -w '%{http_code}\n' -H "If-None-Match: $etag" https://raw.githubusercontent.com/maurice-jobst/bembel-data/dist/bembel-data.json
```

Expected: `304`. This is the contract Phase 1b Task 2 tests against a mock; here it is verified against the real host once.

---

### Task 4: Contribution surfaces the app links into

The app's funnel is nothing but URL construction — but it can only target forms that exist. This task creates them and writes down the templates as the contract between the two repos.

**Files:**
- Create: `.github/ISSUE_TEMPLATE/ebbelwei.yml`
- Create: `.github/ISSUE_TEMPLATE/verifizierung.yml`
- Create: `scripts/check_funnel.py`
- Create: `docs/app-funnel.md`
- Modify: `.github/workflows/validate.yml`
- Modify: `README.md`
- Modify: `CONTRIBUTING.md`

**Interfaces:**
- Produces: issue-form ids `wasserhaeuschen.yml` (exists), `ebbelwei.yml`, `verifizierung.yml` with the field ids listed below. Phase 1b Task 4's `RatingFunnel` builds URLs against exactly these ids — a renamed field id silently produces an unprefilled form.

- [ ] **Step 1: Branch**

```bash
cd /Users/krazykraut/Projects/bembel-data && git checkout main && git pull && git checkout -b feat/app-funnel
```

- [ ] **Step 2: Ebbelwei issue form**

Create `.github/ISSUE_TEMPLATE/ebbelwei.yml` (field ids `name`, `adresse`, `quelle`, `details` — deliberately identical to the Wasserhäuschen form so the app builds both URLs with one code path):

```yaml
name: "🍎 Ebbelwei-Wirtschaft melden"
description: "Eine Apfelwein-Wirtschaft, die noch fehlt — wir machen einen Eintrag daraus."
title: "[Ebbelwei] "
labels: ["neuer-eintrag", "ebbelwei"]
body:
  - type: input
    id: name
    attributes:
      label: Name
      placeholder: "z. B. Zum Gemalten Haus"
    validations:
      required: true
  - type: input
    id: adresse
    attributes:
      label: Adresse
      description: Straße mit Hausnummer, PLZ, Stadt
      placeholder: "Schweizer Straße 67, 60594 Frankfurt am Main"
    validations:
      required: true
  - type: input
    id: quelle
    attributes:
      label: Quelle
      description: Ein Link, der die Angaben belegt (Website, Presse, OSM …)
      placeholder: "https://…"
    validations:
      required: true
  - type: textarea
    id: details
    attributes:
      label: Details
      description: "Garten, Saison, Eigenkelterei, Handkäs, Schoppen vom Fass — Fakten, keine Werbung."
    validations:
      required: false
```

- [ ] **Step 3: Verification issue form**

Create `.github/ISSUE_TEMPLATE/verifizierung.yml`. This is what the app's coverage game ("hilf mit, verifiziere dieses Häuschen") and its correction link open:

```yaml
name: "✅ Eintrag verifizieren oder korrigieren"
description: "Du warst da oder hast eine bessere Quelle — sag uns, was stimmt."
title: "[Verifizierung] "
labels: ["verifizierung"]
body:
  - type: input
    id: eintrag
    attributes:
      label: Eintrag-ID
      description: "Steht in der App unter dem Eintrag; die App füllt das Feld selbst aus."
      placeholder: "yok-yok"
    validations:
      required: true
  - type: dropdown
    id: art
    attributes:
      label: Worum geht es?
      options:
        - "Ich war da — die Angaben stimmen"
        - "Etwas stimmt nicht mehr"
        - "Der Laden gibt es nicht mehr"
    validations:
      required: true
  - type: input
    id: quelle
    attributes:
      label: Quelle
      description: "Link, der es belegt. Eigener Besuch: schreib \"vor Ort geprüft\" und das Datum."
      placeholder: "https://… oder: vor Ort geprüft am 2026-08-13"
    validations:
      required: true
  - type: textarea
    id: details
    attributes:
      label: Details
      validations:
        required: false
```

- [ ] **Step 4: Write the funnel contract**

Create `docs/app-funnel.md` — the templates the BEMBEL app constructs. Keep this file in sync with any form change; it is the only place both repos agree:

````markdown
# Der Trichter aus der App

„Bewerten“, „Eintrag fehlt“ und „verifizieren“ in der BEMBEL-App sind keine
API-Aufrufe — es sind vorausgefüllte GitHub-Links. Kein Backend, keine Konten,
kein Token. Die App baut die folgenden URLs; dieses Dokument ist der Vertrag.

## Bewerten (neue Bewertungsdatei)

```
https://github.com/maurice-jobst/bembel-data/new/main
  ?filename=data/bewertungen/<eintrag-id>/<login>.json
  &value=<URL-kodiertes JSON>
```

`<login>` ist der in den App-Einstellungen hinterlegte GitHub-Benutzername;
ohne Eintrag setzt die App `DEIN-LOGIN` und der Beitragende korrigiert den
Dateinamen im Browser. `value` ist der Inhalt nach
[`bewertung.schema.json`](../schemas/bewertung.schema.json), mit `stars` und
`date` vorbelegt, `comment` leer. GitHub legt Fork und Pull Request selbst an.

## Eintrag fehlt

```
https://github.com/maurice-jobst/bembel-data/issues/new
  ?template=wasserhaeuschen.yml        (oder ebbelwei.yml)
  &title=[Wasserhäuschen] <name>
  &name=<name>&adresse=<adresse>
```

Feld-IDs beider Formulare: `name`, `adresse`, `quelle`, `details`.

## Verifizieren / korrigieren

```
https://github.com/maurice-jobst/bembel-data/issues/new
  ?template=verifizierung.yml
  &title=[Verifizierung] <name>
  &eintrag=<eintrag-id>
```

Feld-IDs: `eintrag`, `art`, `quelle`, `details`.

## Regeln

- Feld-IDs sind Teil des Vertrags. Wer sie umbenennt, bricht den Trichter,
  ohne dass irgendetwas rot wird — das Formular öffnet sich dann einfach leer.
- Die App schickt nie einen Token und niemals personenbezogene Daten. Alles,
  was in der URL steht, steht ohnehin öffentlich im Repo.
````

- [ ] **Step 4b: Make the contract enforceable, not just written down**

A prose contract between two repos drifts silently — a renamed field id opens an
empty form and nothing turns red (no tool, no rule: a rule lands with its
enforcing check or it doesn't land). Create `scripts/check_funnel.py`:

```python
#!/usr/bin/env python3
"""Prüft, dass die Issue-Formulare die Feld-IDs tragen, auf die die BEMBEL-App
ihre Trichter-URLs baut (docs/app-funnel.md). Nur Standardbibliothek — die
YAML-Formulare werden zeilenweise nach `id:` abgesucht, nicht geparst.

Wer ein Feld umbenennt, bricht den Trichter, ohne dass irgendwo etwas
fehlschlägt — außer hier.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FORMS = ROOT / ".github" / "ISSUE_TEMPLATE"

CONTRACT = {
    "wasserhaeuschen.yml": {"name", "adresse", "quelle", "details"},
    "ebbelwei.yml": {"name", "adresse", "quelle", "details"},
    "verifizierung.yml": {"eintrag", "art", "quelle", "details"},
}

ID_RE = re.compile(r"^\s*id:\s*([a-z0-9_-]+)\s*$")


def main() -> int:
    problems: list[str] = []
    for form, expected in CONTRACT.items():
        path = FORMS / form
        if not path.is_file():
            problems.append(f"{form}: fehlt — die App verlinkt darauf")
            continue
        found = {m.group(1) for line in path.read_text(encoding="utf-8").splitlines() if (m := ID_RE.match(line))}
        if missing := expected - found:
            problems.append(f"{form}: Feld-IDs fehlen: {sorted(missing)}")

    if problems:
        print("Trichter-Vertrag verletzt (siehe docs/app-funnel.md):")
        for problem in problems:
            print(f"  - {problem}")
        return 1
    print(f"Trichter-Vertrag OK ({len(CONTRACT)} Formulare)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

Wire it into the existing validation workflow — read `.github/workflows/validate.yml`
first and add a step next to the `validate.py` step, matching its style:

```yaml
      - name: Trichter-Vertrag prüfen
        run: python3 scripts/check_funnel.py
```

Then prove it works in both directions:

```bash
cd /Users/krazykraut/Projects/bembel-data && python3 scripts/check_funnel.py && sed -i '' 's/^    id: eintrag$/    id: entry_id/' .github/ISSUE_TEMPLATE/verifizierung.yml && python3 scripts/check_funnel.py; echo "exit=$?"; git checkout .github/ISSUE_TEMPLATE/verifizierung.yml && python3 scripts/check_funnel.py
```

Expected: OK, then `Feld-IDs fehlen: ['eintrag']` with `exit=1`, then OK again. A
check that has never failed once is not known to work — governance that depends
on someone noticing is luck.

- [ ] **Step 5: Point the README at the new surfaces**

In `README.md`:

1. In the dataset table, change the `data/ebbelwei/` status from `geplant` to `im Aufbau`.
2. In the „🚚 Wie die Daten in die App kommen“ section, replace the paragraph's last sentences so the published URL is named:

```markdown
Releases dieses Repos sind versionierte Daten-Bundles. Gebaut wird jedes Bundle
von [`scripts/build_bundle.py`](scripts/build_bundle.py) — aggregierte
Bewertungen, Provenienz aus der Git-Historie, Abdeckung je Stadtteil, alles aus
dem Repo selbst, byte-deterministisch. Nach jedem Merge auf `main`
veröffentlicht die CI das Ergebnis auf den Branch
[`dist`](../../tree/dist); die App lädt es von dort per Conditional GET
(BEMBEL-Ticket [BEM-S11](https://github.com/maurice-jobst/bembel/issues/46)):

    https://raw.githubusercontent.com/maurice-jobst/bembel-data/dist/bembel-data.json

Ein Snapshot ist in der App gebündelt, damit alles offline funktioniert.
Aggregierte Bewertungen werden hier in der CI berechnet, nicht von einem
Server. Es gibt keinen Server. Wie die App zurück ins Repo verlinkt, steht in
[docs/app-funnel.md](docs/app-funnel.md).
```

- [ ] **Step 6: Note the funnel in CONTRIBUTING**

Add a short section to `CONTRIBUTING.md` (place it after the rating rules, matching the file's existing heading level and tone):

```markdown
## Beiträge aus der App

Wer „Bewerten“ oder „verifizieren“ in der BEMBEL-App tippt, landet mit
vorausgefüllten Feldern hier — als ganz normaler Pull Request oder Issue aus
dem eigenen Account. Dieselben Regeln, derselbe Review. Die genauen Vorlagen
stehen in [docs/app-funnel.md](docs/app-funnel.md); wer ein Formularfeld
umbenennt, ändert damit stillschweigend den Trichter der App.
```

- [ ] **Step 7: Validate, commit, PR, merge**

```bash
cd /Users/krazykraut/Projects/bembel-data && python3 scripts/validate.py && python3 scripts/check_funnel.py && git add -A && git commit -m "Trichter: Ebbelwei- und Verifizierungs-Formular, Vertrag mit der App dokumentiert und geprüft" && git push -u origin feat/app-funnel
gh pr create -R maurice-jobst/bembel-data --title "Trichter aus der App: Formulare + Vertrag" --body "Die Issue-Formulare und der dokumentierte URL-Vertrag, auf die der In-App-Trichter zielt (Phase 1a, Aufgabe 4). \`scripts/check_funnel.py\` hält den Vertrag in der CI fest — Regel und prüfende Kontrolle im selben PR; der Vertrag steht an genau einer Stelle.

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
gh pr merge -R maurice-jobst/bembel-data --squash --delete-branch
```

- [ ] **Step 8: Verify a prefilled form actually opens**

```bash
open "https://github.com/maurice-jobst/bembel-data/issues/new?template=verifizierung.yml&title=%5BVerifizierung%5D%20City%20Kiosk%20Yok-Yok&eintrag=yok-yok"
```

Expected: the form opens with title and Eintrag-ID filled. If the fields are empty, the field ids in `verifizierung.yml` and the query parameters disagree — fix before Phase 1b builds URLs against them. Close the browser tab without submitting.

---

### Task 5: Ebbelwei seed entries

The register must not launch empty. Four to six sourced entries make the second register real at flip; Maurice merges, and `verified` stays `false` until he says otherwise.

**Files:**
- Create: `data/ebbelwei/<slug>.json` (one per entry)

**Interfaces:**
- Consumes: Task 1's Ebbelwei schema.
- Produces: entries the app's Ebbelwei segment renders, and the coverage game's first non-Wasserhäuschen counts.

- [ ] **Step 1: Branch**

```bash
cd /Users/krazykraut/Projects/bembel-data && git checkout main && git pull && git checkout -b data/ebbelwei-seed
```

- [ ] **Step 2: Research each candidate before writing anything**

Pick well-documented Sachsenhausen and Alt-Bornheim houses (Zum Gemalten Haus, Wagner, Zur Buchscheer, Solzer, Zum Eichkatzerl, Adolf Wagner …). For each, open the tavern's own site plus one independent source (city press, Frankfurt Tourismus, OSM). Record only what those pages state: address, founding year, garden, Eigenkelterei. **If a fact is not on a page you actually read, it does not go in the file.** A missing optional field is correct; an invented one is a merge-blocking defect.

- [ ] **Step 3: Write the entries**

One file per entry at `data/ebbelwei/<slug>.json`, `<slug>` matching `^[a-z0-9-]+$` and equal to `id`. Shape, using the seeded Wasserhäuschen as the model:

```json
{
  "id": "zum-gemalten-haus",
  "name": "Zum Gemalten Haus",
  "address": {
    "street": "Schweizer Straße 67",
    "postalCode": "60594",
    "city": "Frankfurt am Main"
  },
  "district": "Sachsenhausen",
  "latitude": 50.1017,
  "longitude": 8.6836,
  "garden": true,
  "eigenkelterei": false,
  "features": ["historisch", "handkaes", "schoppen-vom-fass"],
  "since": 1922,
  "note": "Ein sachlicher Satz, der auf den Quellen steht.",
  "sources": [
    "https://…",
    "https://www.openstreetmap.org/…"
  ],
  "verified": false
}
```

Coordinates come from OSM (linked in `sources` — OSM data is ODbL, the licence note in the README applies). `note` is one neutral factual sentence, never marketing prose. Omit `gardenSeason` unless a source states the months.

- [ ] **Step 4: Validate and build**

```bash
cd /Users/krazykraut/Projects/bembel-data && python3 scripts/validate.py && python3 scripts/build_bundle.py
```

Expected: `data validation OK (N entries)` with N = 1 + your Ebbelwei count, and the builder reporting the same count plus the new Sachsenhausen/Bornheim coverage rows.

- [ ] **Step 5: Commit and PR — do not self-merge**

```bash
git add data/ebbelwei && git commit -m "Daten: erste Ebbelwei-Wirtschaften mit Quellen" && git push -u origin data/ebbelwei-seed
gh pr create -R maurice-jobst/bembel-data --title "Daten: erste Ebbelwei-Wirtschaften" --body "Von der KI recherchierte Ersteinträge, jede Angabe mit gelesener Quelle, \`verified\` überall \`false\`. Bitte inhaltlich prüfen und mergen — keine Selbstfreigabe (Regel aus dem Hero-Spec §5).

Quellen je Eintrag stehen im \`sources\`-Feld.

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

Leave the PR open for Maurice. Phase 1b does not depend on it — the app renders an empty Ebbelwei segment gracefully.

---

## Self-review notes

- Spec §5 coverage: Ebbelwei schema + Merkmale vocabulary (Task 1), rating deep-link templates (Task 4), sourced seed entries merged by Maurice (Task 5), bembel-data issues #1–#3 untouched as human starter tickets (nothing in this plan claims them).
- The coverage game's soft dependency on issue #1 (OSM candidate import) holds: `coverage` counts unverified entries as candidates, so the game works with whatever exists and grows when #1 lands.
