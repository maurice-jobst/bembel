# ADR 0008 — AI-native development as a selection principle

Date: 2026-08-13 · Status: accepted

## Context

Most implementation in this repo is authored by AI agents and reviewed by
humans (operator decision 2026-08-13: BEMBEL is a showcase project built
feature-complete before the public flip). Choices that depend on live
third-party services, nondeterministic environments, or data that cannot
be checked in as fixtures slow agent iteration and make CI flaky.

## Decision

When multiple viable options exist, prefer the one that is best for
AI-native development:

1. deterministic behavior,
2. testable offline against checked-in fixtures,
3. no third-party hosted service in the critical path,
4. boring, documented, standard formats.

This principle joins "data readiness first" (the BACKLOG selection
principle) when choosing data sources, dependencies, and tooling.

## Consequences

- First application: Regenradar parses DWD RADOLAN composites directly
  on-device with checked-in binary fixtures, instead of depending on the
  community-hosted Bright Sky API (a hosted service in the critical path
  of a no-backend app).
- Future provider and tooling choices cite this ADR; deviating from it
  requires a stated reason in the PR description.
