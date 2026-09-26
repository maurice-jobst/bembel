# Governance

How BEMBEL is run: who decides what, how a decision is recorded, and what
happens when people disagree. [CONTRIBUTING.md](CONTRIBUTING.md) is the
working agreement for a change; [docs/PRODUCT.md](docs/PRODUCT.md) is the
scope of record. This file is the layer above both. Status: adopted
2026-09-26; changes go through the process at the end.

## 1. The shape of the project

BEMBEL is a **single-maintainer open-source project with named review lanes
and AI agents as the primary authors of code**. That sentence is the whole
model; the rest of this file spells out its consequences.

- The repo is public and MIT-licensed ([ADR 0006](docs/adr/0006-code-licence-mit.md)).
  The community register it renders lives in
  [bembel-data](https://github.com/maurice-jobst/bembel-data) under ODbL and
  has its own contribution rules; this document covers the app repo only.
- There is no legal entity, no foundation, no money. The App Store listing,
  the bundle ID prefix `de.mauricejobst` and the Apple developer account
  belong to the maintainer personally.
- The project is a portfolio artefact first and a product second
  ([ADR 0010](docs/adr/0010-portfolio-artefact-over-product.md)). That is
  the tie-breaker for every scope question below, and it is written down so
  it does not have to be re-argued.

## 2. Roles

| Role | Who | Can | Cannot |
|---|---|---|---|
| **Maintainer** | [@maurice-jobst](https://github.com/maurice-jobst) | Merge to `main`, accept or reject ADRs, set milestones and labels, cut releases, change branch protection, moderate | Bypass a red required check without visibly switching protection off (`enforce_admins` is on, #106) |
| **Lane reviewer** | App lane [@cybeerboy](https://github.com/cybeerboy); data lane [@jaypikay](https://github.com/jaypikay), [@monsdroid](https://github.com/monsdroid) | Review and approve within their lane ([CODEOWNERS](.github/CODEOWNERS)); self-assign lane issues; propose ADRs | Merge (today), change locked decisions |
| **Contributor** | Anyone with a pull request | Everything a PR can do; propose tickets via the [issue form](.github/ISSUE_TEMPLATE/new_ticket.yml) | Expect a feature outside the scope of record to be merged before v1.0 |
| **AI agent** | Claude Code sessions run by a human above | Author code, data, docs and PRs under that human's direction | Merge, approve, close an issue, change this file or any ADR without a human reviewing the diff |

Two honest notes about the table. First, the lanes exist in CODEOWNERS and
in review requests, but as of this revision every merged PR was authored by
the maintainer; the lanes are a review structure, not a record of who has
shipped. Second, "the maintainer reviews the agent's PR" is currently a
single person reviewing work they directed. The controls that make that
acceptable are mechanical, not social — see §5 and
[docs/AI-NATIVE.md](docs/AI-NATIVE.md).

**Becoming a lane reviewer:** a person who has had three non-trivial PRs
merged in a lane is offered the CODEOWNERS entry. **Losing it:** twelve
months without a review or a PR, or a conduct decision under §8; the
maintainer removes the entry and says so in the PR.

## 3. Decisions

Three tiers, each with its own home. The tier is decided by cost of
reversal, not by who raised it.

| Tier | Examples | Where it is made | Who decides |
|---|---|---|---|
| **Locked** | No backend, provider seam, licence, tab count, positioning, ship date, portfolio-over-product | An ADR in [docs/adr/](docs/adr/) | Maintainer accepts; anyone proposes |
| **Ticket** | Which upstream, which milestone, cut or keep, `needs-decision` questions | The GitHub Issue body and its comments | Maintainer, after the lane reviewer has had a week to object |
| **Implementation** | Names, file layout, test shape, wording | The pull request | Author and reviewer; a reviewer's "not blocking" is not blocking |

**Tie-breakers, in order,** when two viable options remain:

1. Portfolio value over product value (ADR 0010).
2. Best for AI-native development: deterministic, fixture-testable, no
   hosted third party in the critical path, boring formats
   ([ADR 0008](docs/adr/0008-ai-native-selection-principle.md)).
3. Data readiness first: a source that arrives as a URL beats three that
   need curation ([docs/FEATURE-CATALOG.md](docs/FEATURE-CATALOG.md)).
4. The smaller diff.

**Disagreement.** Argue in the issue, not in the PR. If the maintainer's
decision is contested by a lane reviewer, the maintainer writes the decision
and the objection into the issue and, if it is a locked-tier question, into
the ADR's Consequences. There is no appeal body; the honest remedy for a
disagreement a contributor cannot live with is a fork, and the licence makes
that easy on purpose.

**Locked decisions are not relitigated in PRs or issues.** The path to
change one is a superseding or amending ADR (ADR 0010 amended ADR 0009 —
that is the pattern). A PR that quietly implements a different answer is
closed with a pointer here, whatever its quality.

## 4. How an ADR is made

- One file, `docs/adr/NNNN-slug.md`, next number, headed `Date · Status`,
  sections **Context / Decision / Consequences**. Status is `proposed`,
  `accepted`, `amended by NNNN` or `superseded by NNNN`. Nothing is deleted.
- It lands **before or with** the PR that implements it, never after.
- Consequences name what the decision gives up. An ADR with no cost listed
  is sent back.
- Where a decision could be reopened, the ADR names the observation that
  would reopen it (ADR 0001 does this for the backend question). That is
  how "locked" stays honest rather than dogmatic.

## 5. Change control on `main`

What is mechanical, from
[`scripts/apply_branch_protection.sh`](scripts/apply_branch_protection.sh),
which is the source of truth for these settings:

- Three required checks must be green on the current head: BEMBELKit tests,
  the unsigned app build, and data validation. The branch must be up to date
  (`strict`).
- `enforce_admins: true` — the maintainer is bound by the same checks.
- Force-pushes and deletions on `main` are blocked.
- Required approving reviews: **zero.** With one active committer a review
  requirement would be satisfied only by that same person, which is theatre.
  **This rises to one the month a second person has merged two PRs in a
  row**, and this file is updated in the same PR as the script.

What is practice, and stated as such in
[docs/AI-NATIVE.md §6](docs/AI-NATIVE.md#6-rules-without-teeth-listed-rather-than-hidden):
a human reads every diff before merge; agent-authored commits carry a
`Co-Authored-By` trailer; a change touching a system framework is looked at
in a running simulator; Release is built by hand before any archive.

What is out of bounds for anyone, including the maintainer: skipping,
disabling or quarantining a test to get green; hand-editing a generated
file; a curated row without a source URL; a commit that puts identifiable
user data on the wire. Those are rejected on sight, not discussed.

## 6. Scope control

The scope of record is [docs/PRODUCT.md](docs/PRODUCT.md); the epic-to-issue
map is [docs/BACKLOG.md](docs/BACKLOG.md). Governance adds the rules that
keep both from drifting:

- **Milestones** M0–M3 are v1.0; M4 is everything after. An issue without a
  milestone is not scheduled.
- **Labels** are the taxonomy: `epic:A`–`epic:H`, `epic:S`; `size:S/M/L`;
  `area:app`, `area:data`; the exceptions `needs-decision`, `blocked`,
  `learning-goal`, `accessibility`. Labels are applied when the ticket gets
  its `BEM-XXX` id, by the maintainer.
- **The Epic S cap:** no new data-source ticket before the App Store
  release. A new upstream still gets an entry in `data/sources.json` (that
  is research, not scope) — it does not get a ticket.
- **Dated gates are decided on the date, not before and not after.** The
  standing one: `BEM-C01` — no RMV key by 1 December 2026 and epic C leaves
  v1.0 (departures do not ship on sample data). The rain widget (#123) is
  the hedge that keeps a Home Screen widget in the release either way.
- **The ship date does not move; scope does.** 22 March 2027 is World Water
  Day and the fountain season opening. The cut order is written in the
  BACKLOG ("first to cut"), so a cut is a lookup, not a meeting.

## 7. Releases

- Versions follow SemVer with `0.x` meaning "pre-App-Store"
  ([CHANGELOG.md](CHANGELOG.md), Keep a Changelog). `MARKETING_VERSION`
  lives in `Config/Shared.xcconfig` and moves once per TestFlight wave.
- The maintainer cuts releases; only the maintainer can, because the Apple
  account is personal (see §9). [docs/TESTFLIGHT.md](docs/TESTFLIGHT.md) is
  the runbook.
- A release is not cut on red `main`, and never with a known privacy
  regression, whatever else is waiting.
- The CHANGELOG is updated in the PR that makes the change, not in a sweep
  before release. A sweep that has to reconstruct three weeks from the git
  log is a governance failure, and it has happened (#87, #96).

## 8. Data, privacy and conduct

- **Data:** every upstream is registered in `data/sources.json` before code
  calls it; the weekly sweep files one issue when one dies; a dead source is
  fixed or moved to `deprecated` with a reason — never silenced. Licences
  are recorded per dataset in `data/ATTRIBUTION.json` and rendered in-app.
  Community content (entries, ratings) is governed in bembel-data, whose CI
  enforces one rating per GitHub account.
- **Privacy is an invariant, not a feature.** The App Store label says
  *Data Not Collected*. No analytics, no crash SDK, no BEMBEL backend, no
  BEMBEL accounts; location stays on the device. A PR that breaks this is a
  security bug ([SECURITY.md](SECURITY.md)) and is treated as one.
- **Conduct:** [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md). The maintainer
  enforces it; a report about the maintainer goes to a lane reviewer, who
  may act on it including by declining to review further work.

## 9. Known governance gaps

Listed so nobody has to discover them:

1. **Bus factor is one.** The Apple developer account, the App Store
   listing and the release path are personal to the maintainer. Mitigation
   today: everything else — code, data, CI, docs — is public and forkable,
   and the bundle ID prefix is documented so a fork can re-home the app.
   Successor arrangements are not made; this is the first item to fix if a
   second regular committer appears.
2. **Human review is not enforced mechanically** (§5). The compensating
   controls are the required checks and the determinism rules in
   AI-NATIVE.md.
3. **No conduct-report channel independent of the maintainer** beyond the
   lane reviewers named in §8.

## 10. Changing this document

A pull request. If the change touches a role, a tie-breaker or a §5 rule,
it also gets an ADR, and the lane reviewers are requested on it. Editorial
changes need neither. The date in the first paragraph is bumped either way.
