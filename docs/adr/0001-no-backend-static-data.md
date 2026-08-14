# ADR 0001 — No backend; static data + conditional GET

Date: 2026-08-13 · Status: accepted

## Context

BEMBEL is a one-team portfolio app with a "nothing to rot" thesis: no
accounts, no tracking, a privacy label that says "Data Not Collected". Any
server component would need operating, securing, and paying for — and would
make every feature breakable by hosting.

## Decision

There is no backend. Two data tiers only:

1. **Curated datasets** (Trinkbrunnen, region rings, attribution, later
   operator datasets): GeoJSON/JSON bundled at build time, refreshed at
   runtime via conditional GET (`If-None-Match`) against a static manifest on
   GitHub Pages / R2. The app always works from the bundle if the network
   never answers.
2. **Live APIs** (RMV, DWD, PEGELONLINE, HLNUG, NINA): called directly from
   the device. No proxy, no key-hiding middleware.

Operator-assembled datasets (BEM-B04) keep this property: a scheduled GitHub
Action produces JSON, a human merges the PR, the existing publish workflow
ships it. The schema validator — not a prompt — enforces that every row
carries a source URL and payloads contain facts only.

## Consequences

- The RMV API key ships in the binary. Acceptable: it is a free, rate-limited
  open-data key, and the alternative is a proxy — a backend.
- Static hosting is cache-friendly and effectively free; worst-case outage
  degrades to bundled data, not a broken app.
- Anything that would need per-user state is out of scope by construction.
