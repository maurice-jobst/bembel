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

## Amendment 2026-08-21 — what would reopen this

A long-term direction stated 2026-08-19 ends in a platform: third parties
(restaurants, Tankstellen, cinemas, train operators) publishing into BEMBEL,
and for tickets, money changing hands. That is a backend by definition, and
it would also break the "No BEMBEL accounts" line in `BACKLOG.md` (a
publishing third party needs identity) and strain the "Data Not Collected"
privacy label (payment flows).

There is no pull toward it today — no third party has asked, and the only
monetisation in the backlog is an optional tip (`BEM-H03`). So this is not a
decision to revisit now. It is a decision to revisit **on evidence**, and the
evidence is named here so the change cannot arrive by accretion across
individual tickets:

1. **A data source obtainable only through a server we operate.** A key that
   cannot ship in a client, or a source that needs a fetch cadence a device
   cannot provide. This is the trigger most likely to arrive disguised as one
   ordinary ticket — the "closed APIs and scraping" direction has exactly
   this shape. A scraper does not land without its own ADR covering terms of
   service, cadence and fragility.
2. **Revenue becoming a requirement rather than a tip.** The moment BEMBEL
   has to earn, the no-backend thesis is carrying weight it was never
   designed for.

Deliberately **not** triggers: a third party asking to be listed (answer:
they open a PR, like everyone else), and volume making GitHub-PR-as-write-path
slow (answer: that is the funnel working, and rate is not the same as
architecture).

Status of this ADR is unchanged: **accepted**. See ADR 0010 for the purpose
decision this amendment hangs off.
