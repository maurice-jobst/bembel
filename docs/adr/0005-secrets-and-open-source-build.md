# ADR 0005 — Secrets and the open-source build

Date: 2026-08-13 · Status: accepted

## Context

The repo is public from the start. The Apple Team ID and the RMV API key must
not live in the pbxproj (forks wouldn't build cleanly; identifiers end up in
the search index), and CI must build without any secret at all.

## Decision

- All machine-/owner-specific values live in `Config/Secrets.xcconfig`,
  which is **gitignored**. A committed `Secrets.xcconfig.template` documents
  every variable.
- `Shared.xcconfig` pulls it in with `#include?` (optional include): a clean
  checkout with no secrets file still builds unsigned for the simulator —
  which is exactly what CI does (`CODE_SIGNING_ALLOWED=NO`).
- CI creates `Secrets.xcconfig` from the template; values that CI genuinely
  needs later (none today) come from GitHub repository secrets.
- The bundle ID prefix `de.mauricejobst` is *not* secret and is committed in
  `Shared.xcconfig`; only `BEMBEL_TEAM_ID` and API keys are secret-adjacent.

## Consequences

- Forks build out of the box; no personal identifiers in the repo.
- Signing for a device requires the one-time template copy — documented in
  the README.
- How the RMV key reaches the app binary is decided at BEM-C01, not here.
