# AI-native: the constraints that keep this repo reviewable

Most of the implementation here was written by AI agents and reviewed by a
human. This document covers the part specific to this repo: which constraints
it accepted because of that, and what enforces each. Every claim points at a
file, a check you can run, or an ADR; where a claim has no enforcement, it says
so. The failures are in [what got through anyway](#what-got-through-anyway).

## 1. Generators are deterministic

A regenerated dataset must produce the same bytes as the last run, or the diff
is unreviewable and the reviewer starts skimming.

- **No build timestamp in generated output.** The same sources on the same
  day produce identical files;
  [`scripts/generate_fountains.py`](../scripts/generate_fountains.py) says so
  where a timestamp would otherwise go.
- **`updated` answers "when did this row's facts last change".**
  `carry_updated()` in the same file compares every property except `updated`
  against the previous output and carries the old stamp forward for unchanged
  rows. Without it one re-run would touch all 73 fountains and bury the one
  that changed.
- **No geocoding in the pipeline.** Rings and AGS come out of an Overpass
  `area` query keyed on the AGS — correct by construction, not by a service
  that answers slightly differently next month.

**How to check:** run the generator twice and diff. `git status` is the test.

## 2. Every curated file exists twice, under a byte-equality gate

The app reads a bundled copy offline; the publisher reads the copy under
`data/`. Two copies is exactly where an agent updates one and forgets the
other, and both halves keep working until someone is offline.

- [`scripts/bembel_paths.py`](../scripts/bembel_paths.py) `mirrored()` returns
  **both** paths; generators write through it.
- [`scripts/validate_data.py`](../scripts/validate_data.py) `check_mirror()`
  fails the build if the two differ: `rings.json`, `manifest.json`,
  `bembeldata.json` and every `.geojson` under `data/`. That validator is a
  **required** status check
  ([`data-validate.yml`](../.github/workflows/data-validate.yml)).

**How to check:** `make validate`.

## 3. One provider protocol per upstream

[ADR 0007](adr/0007-provider-seam.md): views read a protocol from BEMBELKit;
sample and live implementations are interchangeable.

- **Going live is one ticket, not a refactor.** The temperature card went from
  fixture to DWD by one line in [`AppDependencies.swift`](../App/AppDependencies.swift).
- **A failure stays local.** Stadtzustand keeps *four* independent states, one
  per upstream, because it used to keep one and a river-gauge timeout blanked
  the civil-protection card with it. The rule and the reason are written into
  [`Providing.swift`](../Packages/BEMBELKit/Sources/BEMBELKit/Providers/Providing.swift)
  and [`CityModel.swift`](../App/Features/City/CityModel.swift), where someone
  would next be tempted to merge them back.

## 4. Sources are selected for agent-suitability

[ADR 0008](adr/0008-ai-native-selection-principle.md): given options a human
would rate the same, take the one that is deterministic, testable offline
against checked-in fixtures, free of a hosted third-party service in the
critical path, and boring in format. Two decisions it made against the easier
option:

- **Rain radar parses DWD RADOLAN composites on the device** instead of calling
  a community-hosted wrapper. That cost a bzip2 shim
  ([`CBZip2`](../Packages/BEMBELKit/Package.swift)) and bought a feature
  testable against a 133 KB archive checked into the repo.
- **Temperature reads DWD's own hourly station CSV**; the hosted wrapper stays
  in [`data/sources.json`](../data/sources.json) as the documented fallback.

Deviating from ADR 0008 requires a stated reason in the PR description. That
is a convention, not a gate.

## 5. Rules ship with the check that enforces them

| Rule | Mechanism |
|---|---|
| Curated rows are facts with a source URL, never prose | `check_geojson` / `check_operator_datasets` in [`validate_data.py`](../scripts/validate_data.py) |
| Generated files match their generator's output | `check_mirror`, above |
| Tier-1/2 sources are keyless; a tier-5 entry records the search, not an endpoint | `check_sources` in the same validator |
| README's three registry numbers match `data/sources.json` | `README_CLAIMS` in the same validator; reworded prose fails by design |
| Every registered source is reachable *by the verifier* | `coverage_gaps()` in [`verify_sources.py`](../scripts/verify_sources.py), asserted offline on every PR by [`test_validate_data.py`](../scripts/test_validate_data.py) |
| Upstreams still answer and feature counts have not collapsed | [`sources-liveness.yml`](../.github/workflows/sources-liveness.yml), weekly, files one issue |
| Formatting | `make format-check`, required |

A source registered in a shape the verifier does not understand *looks*
checked and is not; three once shipped that way, hence the offline coverage
test on every PR.

## 6. Rules without teeth, listed rather than hidden

- **No gate on "a human reviewed this."** Branch protection on `main` requires
  three checks and `strict: true`, **zero** approvals, and `enforce_admins` is
  off (#106). Human review is practice, not mechanism.
- **`Co-Authored-By: Claude` is a convention, not a check.** Most commits carry
  it; several do not — [count it yourself](#checking-any-of-this).
- **"No third-party dependencies"** is a property of
  [`Package.swift`](../Packages/BEMBELKit/Package.swift), not a CI rule.

## What got through anyway

- **An app that died on every cold start, with everything green.**
  `CLMonitor(_:)` raises an Objective-C exception on any non-alphanumeric name;
  Swift cannot catch it. `de.mauricejobst.bembel.kiosks` shipped to `main` with
  tests, build and review green — tests do not run CoreLocation, the build does
  not launch the app. Finding at the constant
  ([`VisitMonitor.swift`](../Packages/BEMBELKit/Sources/BEMBELKit/Community/VisitMonitor.swift));
  rule: a change touching a system framework is looked at in a running
  simulator before it is called done.
- **CI builds Debug, so Release rot walked in.** `#Preview` helpers referenced
  a `#if DEBUG` type; preview bodies are type-checked in Release too, so the
  archive broke with every required check green (#85). Release is now built by
  hand before any archive — a habit, not a gate.
- **A `switch` the local compiler accepted and CI did not.** CI pins Xcode
  16.4; local ran newer. A `(Bool, Bool?)` match that was exhaustive locally
  failed in CI. The repo prefers a plain branch to a clever pattern match; the
  reason is written where the branch is
  ([`CityView.swift`](../App/Features/City/CityView.swift)).
- **A required check that could never pass.** A path-filtered workflow does not
  report on a PR touching none of its paths; made required, it pinned every
  unrelated PR on "expected" forever. Fix and reason: [`data-validate.yml`](../.github/workflows/data-validate.yml).
- **Plausible numbers that were not measurements.** Sample providers carried a
  Main level of 3,42 m until the live gauge read 1,58 m; fountain cards carried
  an invented walking distance; the Regenradar drew four blurred ellipses over
  real coordinates under a headline computed from actual radar (until BEM-F02).
  Fixtures are now captured from real responses, and a field nobody can compute
  honestly is removed instead of approximated
  ([`FountainRanking`](../Packages/BEMBELKit/Sources/BEMBELKit/Domain/Fountain.swift)).
  The same rot reached README.md: three registry numbers drifted from 30/39/9
  to 32/48/6 with nobody editing them. `make validate` now recomputes all three
  and treats prose the pattern no longer matches as a failure.

## Checking any of this

```bash
make test           # BEMBELKit unit tests, native macOS, no simulator
make build          # iOS Simulator, unsigned
make validate       # data schemas, mirror equality, source registry rules, README numbers
make test-data      # the validator's own tests, incl. verifier coverage
make format-check   # the check CI runs
make verify-sources # every registered endpoint, called for real
git log --format='%h|%(trailers:key=Co-Authored-By,valueonly)' | grep -c Claude  # section 6
git rev-list --count main
```

Decisions: [docs/adr/](adr/). Spec and status: GitHub Issues, indexed in
[docs/BACKLOG.md](BACKLOG.md).
