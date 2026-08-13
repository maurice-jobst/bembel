# Contributing

Small team, strict habits. This file is the working agreement.

## Workflow

- Single `main`, PR-based. One commit per ticket where feasible, message
  prefixed with the ticket ID: `BEM-A05: curated dataset split`.
- **Two surfaces per ticket, not one:** [docs/BACKLOG.md](docs/BACKLOG.md) is
  the spec — scope, rationale, acceptance criteria. The matching
  [GitHub Issue](https://github.com/maurice-jobst/bembel/issues) (same
  `BEM-XXX` id in the title) is where work actually gets tracked — assign
  yourself, comment, and close it via your PR (`Closes #N`) rather than
  editing BACKLOG.md's status. If they ever disagree, BACKLOG.md wins for
  scope/ACs, the issue wins for current status.
- Issues carry an `epic:X` label, a `size:S/M/L` label, a lane label
  (`area:app` / `area:data`), and a milestone (M0–M3 for v1.0, M4 for
  post-1.0 side quests). `needs-decision`, `blocked`, and `learning-goal`
  show up where BACKLOG.md flags them. Issue bodies are self-contained
  briefs — pick one from your lane, assign yourself, start.
- Locked product decisions are in
  [the hero-repositioning spec](docs/superpowers/specs/2026-08-13-hero-repositioning-design.md)
  (the original kickoff prompt is archived under `docs/history/`) — don't
  relitigate them in PRs or issues.
- Any decision that would be expensive to reverse gets an ADR in `docs/adr/`
  before or with the PR that implements it.
- `main` requires the three CI checks green before merge (once the repo is
  public — GitHub Free doesn't support branch protection on private repos;
  run `scripts/apply_branch_protection.sh` right after flipping visibility).
  Force-pushes and deletions on `main` are blocked once that's on.

## Rules

- **No third-party dependencies** unless a ticket justifies one and the PM
  approves it.
- **No secrets in the repo.** Team ID and API keys live in
  `Config/Secrets.xcconfig` (gitignored); CI injects them from repository
  secrets. If you find a credential in a diff, stop the merge.
- All user-facing strings go through `Localizable.xcstrings`, German first.
- **Views never call a data source.** Features read the provider protocols in
  `Packages/BEMBELKit` ([ADR 0007](docs/adr/0007-provider-seam.md)); live
  implementations replace the `Sample…Provider`s behind the same protocol.
  Changing a protocol is a cross-lane API change — both lanes review.
- `make format` before pushing; CI runs `make format-check` (swift-format is
  bundled with Xcode, nothing to install).
- Tests where they earn their keep: data layer, region filter, decoders,
  deep-link parsing. Not SwiftUI view bodies.
- Every curated data row carries a source URL, and payloads store facts only —
  numbers, names, dates, links, never scraped prose. The validator enforces
  this; don't route around it.

## Lanes

- **App lane** (frontend, @cybeerboy): `App/`, `Widgets/`
- **Data lane** (backend, @jaypikay + @monsdroid): `data/`, `scripts/`,
  `.github/`, and later the LoD2 pipeline and operator-dataset harness
- **Shared seam** (all): `Packages/BEMBELKit/` — domain models, provider
  protocols, design system
- **Docs & decisions** (PM, @maurice-jobst): `docs/`, backlog, ADR review

Lanes are default ownership, not walls — cross-lane PRs just need the lane
owner's review.
