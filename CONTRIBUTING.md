# Contributing

Small team, strict habits. This file is the working agreement.

## Workflow

- Single `main`, PR-based. One commit per ticket where feasible, message
  prefixed with the ticket ID: `BEM-A05: curated dataset store`.
- Tickets live in [docs/BACKLOG.md](docs/BACKLOG.md). Locked product decisions
  are in [docs/KICKOFF-PROMPT.md](docs/KICKOFF-PROMPT.md) — don't relitigate
  them in PRs.
- Any decision that would be expensive to reverse gets an ADR in `docs/adr/`
  before or with the PR that implements it.

## Rules

- **No third-party dependencies** unless a ticket justifies one and the PM
  approves it.
- **No secrets in the repo.** Team ID and API keys live in
  `Config/Secrets.xcconfig` (gitignored); CI injects them from repository
  secrets. If you find a credential in a diff, stop the merge.
- All user-facing strings go through `Localizable.xcstrings`, German first.
- Tests where they earn their keep: data layer, region filter, decoders,
  deep-link parsing. Not SwiftUI view bodies.
- Every curated data row carries a source URL, and payloads store facts only —
  numbers, names, dates, links, never scraped prose. The validator enforces
  this; don't route around it.

## Lanes

- **App lane** (frontend): `App/`, `Widgets/`, `Packages/BEMBELKit/`
- **Data lane** (backend): `data/`, `scripts/`, `.github/`, and later the
  LoD2 pipeline and operator-dataset harness
- **Docs & decisions** (PM): `docs/`, backlog, ADR review

Lanes are default ownership, not walls — cross-lane PRs just need the lane
owner's review.
