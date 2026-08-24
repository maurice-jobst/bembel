# AI-native: the constraints that keep this repo reviewable

Most of the implementation here was written by AI agents and reviewed by a
human. Plenty of repositories can say that, so this document covers the part
that is specific to this one: which constraints the project accepted because of
it, and what enforces each.

Every claim below points at a file, a check you can run, or an ADR. Where a
claim has no enforcement, it says so. The failures are in
[what got through anyway](#what-got-through-anyway).

---

## 1. Generators are deterministic

An agent that regenerates a dataset must produce the same bytes as the last
run, or the diff is unreviewable and the reviewer starts skimming.

**What that costs in practice:**

- **No build timestamp anywhere in generated output.** The same sources on the
  same day produce identical files;
  [`scripts/generate_fountains.py`](../scripts/generate_fountains.py) says so
  at the point where a timestamp would otherwise go.
- **`updated` answers "when did this row's facts last change", not "when did
  the generator run".** `carry_updated()` in the same file compares every
  property except `updated` against the previous output and carries the old
  stamp forward for unchanged rows. Without it, one re-run would touch all 73
  fountains and bury the one that changed.
- **No geocoding in the pipeline.** Fountain rings and AGS come out of an
  Overpass `area` query keyed on the AGS, so they are correct by construction
  rather than by a service that answers slightly differently next month.

**How to check:** run the generator twice and diff. `git status` is the test.

## 2. Every curated file exists twice, under a byte-equality gate

The app reads a bundled copy offline; the publisher reads the copy under
`data/`. Two copies of the same file is exactly the arrangement where an agent
updates one and forgets the other, and both halves keep working until someone
is offline.

- [`scripts/bembel_paths.py`](../scripts/bembel_paths.py) holds `mirrored()`,
  which returns **both** paths. Generators write through it, so writing one
  copy and forgetting the other is not a thing you can do by accident.
- [`scripts/validate_data.py`](../scripts/validate_data.py) `check_mirror()`
  fails the build if the two differ: `rings.json`, `manifest.json`,
  `bembeldata.json` and every `.geojson` under `data/`.
- That validator is a **required** status check
  ([`data-validate.yml`](../.github/workflows/data-validate.yml)).

**How to check:** `make validate`.

## 3. One provider protocol per upstream

[ADR 0007](adr/0007-provider-seam.md). Views read a protocol from BEMBELKit;
the sample implementation and the live one are interchangeable. Two things
follow, and both are about reviewability:

- **Going live is one ticket, not a refactor.** The temperature card went from
  fixture to DWD by changing one line in
  [`App/AppDependencies.swift`](../App/AppDependencies.swift). A reviewer can
  see the whole change.
- **A failure stays local.** The Stadtzustand screen keeps *four* independent
  states, one per upstream, because it used to keep one and a river-gauge
  timeout blanked the civil-protection warning card with it. The rule and the
  reason are written into
  [`Providing.swift`](../Packages/BEMBELKit/Sources/BEMBELKit/Providers/Providing.swift)
  and [`CityModel.swift`](../App/Features/City/CityModel.swift), at the place
  where someone would next be tempted to merge them back.

## 4. Sources are selected for agent-suitability

[ADR 0008](adr/0008-ai-native-selection-principle.md): given options a human
would rate the same, take the one that is deterministic, testable offline
against checked-in fixtures, free of a hosted third-party service in the
critical path, and boring in format.

Two decisions it made, both against the easier option:

- **Rain radar parses DWD RADOLAN composites on the device** rather than
  calling a community-hosted wrapper. That cost a bzip2 shim
  ([`CBZip2`](../Packages/BEMBELKit/Package.swift)), since Apple's Compression
  framework has no bzip2, and bought a feature testable against a 133 KB
  archive checked into the repo.
- **Temperature reads DWD's own hourly station CSV** for the same reason, after
  the ticket made the hosted wrapper conditional on the raw source being
  unusable. It was usable. The wrapper stays in
  [`data/sources.json`](../data/sources.json) as the documented fallback, with
  the evidence that would reopen the decision written down next to it.

Deviating from ADR 0008 is allowed and requires a stated reason in the PR
description. That is a convention, not a gate.

## 5. Rules ship with the check that enforces them

A rule an agent is asked to remember is a rule that drifts. Where this repo has
a rule it cares about, it has a mechanism:

| Rule | Mechanism |
|---|---|
| Curated rows are facts with a source URL, never prose | `check_geojson` / `check_operator_datasets` in [`validate_data.py`](../scripts/validate_data.py) |
| Generated files match their generator's output | `check_mirror`, above |
| A tier-1/2 source must be keyless; a tier-5 entry records the search, not an endpoint | `check_sources` in the same validator |
| Every registered source is actually reachable *by the verifier* | `coverage_gaps()` in [`verify_sources.py`](../scripts/verify_sources.py), asserted offline on every PR by [`test_validate_data.py`](../scripts/test_validate_data.py) |
| Upstreams still answer, and their feature counts have not collapsed to zero | [`sources-liveness.yml`](../.github/workflows/sources-liveness.yml), weekly, files one issue |
| Formatting | `make format-check`, required |

Registering a source in a shape the verifier does not understand produces an
entry that *looks* checked and is not. Three entries once shipped that way. The
offline coverage test now fails the pull request that introduces a new source
shape, so when `protocol: "csv"` was added for the DWD station file, the plan
branch and its test landed in the same commit.

## 6. Rules without teeth, listed rather than hidden

- **There is no gate on "a human reviewed this."** Branch protection on `main`
  requires three checks and `strict: true`; it requires **zero** approvals, and
  `enforce_admins` is off, so an admin can push straight past all of it. The
  README says a human reviews every pull request. That is true as practice, not
  as mechanism.
- **`Co-Authored-By: Claude` is a convention, not a check.** Most commits on
  `main` carry it; several do not — six from one session that dropped the
  trailer, plus Dependabot's. The count is deliberately not written here: the
  first draft of this document said "21 of 28", and two merges later that was
  wrong. A number nobody recomputes is the same failure this section is about,
  so [count them yourself](#checking-any-of-this).
- **"No third-party dependencies" is a property of
  [`Package.swift`](../Packages/BEMBELKit/Package.swift), not a CI rule.**
  Nothing would fail if someone added one.

Naming these here costs nothing and keeps a reader from mistaking practice for
mechanism.

---

## What got through anyway

Every mechanism above exists because something got past the ones that came
before it.

### An app that died on every cold start, with everything green

`CLMonitor(_:)` validates its name in Objective-C and raises
`NSInternalInconsistencyException` on any non-alphanumeric character. Swift
cannot catch it. The reverse-DNS name `de.mauricejobst.bembel.kiosks` looked
exactly like every other identifier in the project and killed the app at the
first `stop()`, which is every cold start with visit detection switched off.

It shipped to `main` with unit tests green, `make build` green, and a code
review that found ten other things. Tests do not run CoreLocation; the build
does not launch the app. The finding is now a comment at the constant itself
([`VisitMonitor.swift`](../Packages/BEMBELKit/Sources/BEMBELKit/Community/VisitMonitor.swift)),
and the rule it produced is that a change touching a system framework gets
looked at in a running simulator before it is called done.

### CI builds Debug, so Release rot walked in

The `#Preview` helpers in `CityView` referenced a type that only exists under
`#if DEBUG`. Preview bodies are type-checked in Release too, so the archive
build broke while every required check stayed green. Nobody noticed until the
first TestFlight attempt (#85). Release is now built by hand before any
archive; CI still builds Debug only, which means this remains a habit rather
than a gate.

### A `switch` the local compiler accepted and CI did not

CI pins Xcode 16.4; the development machine runs a newer one. A `switch` over
`(Bool, Bool?)` that the local compiler considered exhaustive failed in CI.
Local green is not CI green for type-checking edge cases, and the repo now
prefers a plain branch to a clever pattern match. The reason is written where
the branch is
([`CityView.swift`](../App/Features/City/CityView.swift)).

### A required check that could never pass

A path-filtered workflow does not report on a pull request that touches none of
its paths. Made required, it pinned every unrelated PR on "expected" forever.
The fix and the reason live in the workflow itself
([`data-validate.yml`](../.github/workflows/data-validate.yml)), because the
`paths:` filter is the obvious optimisation somebody will reach for again.

### Plausible numbers that were not measurements

The sample providers carried a Main level of 3,42 m. Nobody questioned it until
the live gauge was wired and read 1,58 m. The fabricated figure had never been
a plausible Osthafen level. Fountain cards carried a walking distance invented
by the same sample provider, which would have kept lying once real data
arrived; the field was deleted rather than filled
([`FountainRanking`](../Packages/BEMBELKit/Sources/BEMBELKit/Domain/Fountain.swift)
computes it from a fix, or shows nothing).

The Regenradar was the same thing at map scale: four blurred ellipses drawn
over real Frankfurt coordinates, under a headline computed from the actual
radar. It survived from the first mockup until the frames it was standing in
for finally arrived (BEM-F02).

A generated placeholder that looks like a measurement survives until something
independent contradicts it. Fixtures are now captured from real responses, and
a field nobody can compute honestly is removed instead of approximated.

---

## Checking any of this

```bash
make test           # BEMBELKit unit tests, native macOS, no simulator
make build          # iOS Simulator, unsigned
make validate       # data schemas, mirror equality, source registry rules
make test-data      # the validator's own tests, incl. verifier coverage
make format-check   # the check CI runs
make verify-sources # every registered endpoint, called for real
```

```bash
# The commit trailers behind section 6
git log --format='%h|%(trailers:key=Co-Authored-By,valueonly)' | grep -c Claude
git rev-list --count main
```

Decisions live in [docs/adr/](adr/); the spec lives in
[docs/BACKLOG.md](BACKLOG.md); status lives in GitHub Issues.
