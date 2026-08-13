# Phase 0 — Hero Repositioning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reposition the repo around the bembel-data hero (docs, ADR, milestones, issues) per the 2026-08-13 hero-repositioning spec, section 1 and the scope deltas of section 2.

**Architecture:** Docs-and-metadata only — no Swift code changes. One branch, one PR, commits per task. GitHub milestone/issue changes go via `gh` (idempotent, discover-then-mutate).

**Tech Stack:** Markdown, `gh` CLI.

## Global Constraints

- Operator overrides: **no TDD**, fail forward, proactive/auto mode.
- Spec of record: `docs/superpowers/specs/2026-08-13-hero-repositioning-design.md`.
- Ship date stays **2027-03-22**. Privacy label stays **Data Not Collected**.
- Remotes are HTTPS (gh credential helper); commits signed via 1Password SSH agent — if signing fails ("agent refused operation"), ask Maurice to unlock 1Password, then retry.
- Never edit `KICKOFF-PROMPT.md` content beyond the retirement header; it becomes a historical document.
- Repo is still **private**; nothing here flips it.
- Match each file's existing language (README/BACKLOG are English with German feature names; bembel-data docs are German).

---

### Task 1: Branch + ADR 0008 (AI-native selection principle)

**Files:**
- Create: `docs/adr/0008-ai-native-selection-principle.md`

**Interfaces:**
- Produces: ADR number 0008, cited by later tasks' copy as "ADR 0008".

- [ ] **Step 1: Create branch**

```bash
cd /Users/krazykraut/Projects/BEMBEL && git checkout -b docs/hero-repositioning
```

- [ ] **Step 2: Write the ADR**

Create `docs/adr/0008-ai-native-selection-principle.md` (match the header style of `docs/adr/0007-provider-seam.md` — read it first and mirror its layout):

```markdown
# 0008 — AI-native development as a selection principle

- Status: accepted
- Date: 2026-08-13

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

This principle joins "data readiness first" (BACKLOG selection principle)
when choosing data sources, dependencies, and tooling.

## Consequences

- First application: Regenradar parses DWD RADOLAN composites directly
  on-device with checked-in binary fixtures, instead of depending on the
  community-hosted Bright Sky API (a hosted service in the critical path
  of a no-backend app).
- Future provider and tooling choices cite this ADR; deviating from it
  requires a stated reason in the PR description.
```

- [ ] **Step 3: Commit**

```bash
git add docs/adr/0008-ai-native-selection-principle.md && git commit -m "Docs: ADR 0008 — AI-native development as a selection principle"
```

---

### Task 2: Retire KICKOFF-PROMPT.md

**Files:**
- Create: `docs/history/` (directory)
- Move: `docs/KICKOFF-PROMPT.md` → `docs/history/2026-06-kickoff-prompt.md`

**Interfaces:**
- Produces: `docs/history/` as the home for superseded docs; later tasks must not reference `docs/KICKOFF-PROMPT.md`.

- [ ] **Step 1: Move and annotate**

```bash
mkdir -p docs/history && git mv docs/KICKOFF-PROMPT.md docs/history/2026-06-kickoff-prompt.md
```

Prepend to the moved file (above the existing `# Kickoff prompt — BEMBEL` line):

```markdown
> **Historical document (retired 2026-08-13).** Describes the original
> project shape: five locked v1.0 features, Schattenkarte as signature
> feature, mid-January ship target. Superseded by
> `docs/superpowers/specs/2026-08-13-hero-repositioning-design.md`
> (bembel-data hero, ship 2027-03-22). Kept unedited below for context.

```

- [ ] **Step 2: Fix references**

```bash
rg -l "KICKOFF-PROMPT" --glob '!docs/history/**'
```

For every hit, replace the path with `docs/history/2026-06-kickoff-prompt.md` and, where the reference presents it as current guidance, reword to past tense ("the original kickoff prompt").

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "Docs: retire KICKOFF-PROMPT to docs/history (superseded by hero repositioning)"
```

---

### Task 3: README repositioning

**Files:**
- Modify: `README.md` (read it fully first; anchors below are structural, not line-based)

**Interfaces:**
- Consumes: ADR 0008 (Task 1), history path (Task 2).
- Produces: the public-facing hero narrative later phases link to.

- [ ] **Step 1: Rewrite the positioning**

Read `README.md`. Make these changes, preserving existing tone and badge/header block:

1. Wherever the Schattenkarte is presented as *the* signature/hero feature, demote to a normal feature listing — keep its full description, remove only the "signature" framing.
2. Insert a hero section directly after the intro/what-is-BEMBEL block:

```markdown
## The hero: community data, wie Yelp — nur in GitHub

BEMBEL's flagship is the **Wasserhäuschen-Register** (plus the
**Ebbelwei-Wirtschaften register**), powered by
[bembel-data](https://github.com/maurice-jobst/bembel-data): community-
maintained datasets where entries and ratings are pull requests.

- **Provenance over anonymity.** Every entry shows who verified it, when,
  from which source — one tap to its full GitHub history. No anonymous
  star soup.
- **Ratings you can trust.** One rating per GitHub account, enforced by CI
  (the rating file's name must match the PR author's login). As far as we
  can tell, nobody has built this trust model out of GitHub primitives
  before.
- **The app is the funnel.** "Bewerten" in the app opens a prefilled
  GitHub flow for that kiosk; contributors earn in-app sticker credit
  (Datenspender) — no BEMBEL accounts, no backend, label stays
  "Data Not Collected".

Built mostly by AI, reviewed by humans — see ADR 0008 for how that shapes
technical choices.
```

3. If the README lists v1.0 features, extend the list with: `Wasserhäuschen-Register`, `Ebbelwei-Wirtschaften`, `Sticker (Datenspender + Kiosk-Stempel)` — matching the list's existing formatting.

- [ ] **Step 2: Verify rendering**

```bash
glow README.md
```

Check the new section renders, links resolve, no duplicated feature listings.

- [ ] **Step 3: Commit**

```bash
git add README.md && git commit -m "Docs: reposition README around the bembel-data hero"
```

---

### Task 4: BACKLOG.md scope update

**Files:**
- Modify: `docs/BACKLOG.md` (large file — read fully first)

**Interfaces:**
- Consumes: spec section 2 scope; ADR 0008.
- Produces: BACKLOG as spec-of-record reflecting the new v1.0 scope; ticket IDs BEM-S04/S05/S11 marked as pulled forward.

- [ ] **Step 1: Update the scope sections**

In `docs/BACKLOG.md`:

1. Replace any "five features, nothing else" / locked-scope wording for v1.0 with a pointer: v1.0 = the five original features **plus the hero layer**, per `docs/superpowers/specs/2026-08-13-hero-repositioning-design.md` §2.
2. In the epic S section, annotate the pulled-forward items (keep their IDs):
   - `BEM-S04` (Wasserhäuschen-Register): "**pulled into v1.0** (read-only register + rating funnel + provenance + Merkmale navigation + coverage game); community/ratings-write stays GitHub-side."
   - `BEM-S05` (Ebbelwei): "**pulled into v1.0** (second register through the same loader)."
   - `BEM-S11` (bembel-data loader): "**pulled into v1.0** (hero dependency)."
   - `BEM-S01` (stickers): "**partially pulled into v1.0**: data-linked stickers (Datenspender, Verifizierer, Erste-Bewertung) + kiosk visit stamps. Sammelalbum/Game Center/seasonal drops remain M4."
3. Where the Schattenkarte is called the signature feature, demote the framing (feature scope unchanged).
4. In the radar ticket/notes, record the decision: RADOLAN direct with checked-in fixtures, per ADR 0008 (replaces the open RADOLAN-vs-Bright-Sky question).
5. Add the second selection principle next to "data readiness first": "best for AI-native development (ADR 0008)".

- [ ] **Step 2: Consistency sweep**

```bash
rg -n "five features|signature feature|Bright Sky|mid-January" docs/ README.md CONTRIBUTING.md
```

Fix every remaining hit that contradicts the new scope (historical docs under `docs/history/` and dated specs/brainstorms stay untouched).

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "Docs: BACKLOG v1.0 scope — hero layer pulled forward (BEM-S01/S04/S05/S11)"
```

---

### Task 5: CHANGELOG entry

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Add Unreleased entry**

Under `## [Unreleased]` (create the section if absent, Keep-a-Changelog style) add:

```markdown
### Changed
- Repositioned around the bembel-data hero: Wasserhäuschen + Ebbelwei
  registers, rating funnel, provenance UX, and data-linked stickers join
  the v1.0 scope (spec 2026-08-13); Schattenkarte remains a full v1.0
  feature without the "signature" framing.
- ADR 0008: "best for AI-native development" selection principle; radar
  will parse RADOLAN directly (no Bright Sky dependency).
- KICKOFF-PROMPT retired to docs/history/.
```

- [ ] **Step 2: Commit**

```bash
git add CHANGELOG.md && git commit -m "Docs: CHANGELOG entry for hero repositioning"
```

---

### Task 6: Milestones + issues reshuffle (gh)

**Files:** none (GitHub metadata).

**Interfaces:**
- Consumes: issue numbers discovered live; epic S issues are #36–#46, #36 = BEM-S01.
- Produces: milestone `v1.0` containing the pulled-forward issues; #36 split note.

- [ ] **Step 1: Discover current state**

```bash
gh api repos/maurice-jobst/bembel/milestones --jq '.[] | {number,title}'
gh issue list -R maurice-jobst/bembel --limit 50 --json number,title,milestone --jq '.[] | select(.number>=36 and .number<=46)'
```

Identify: the v1.0 milestone (create `v1.0 (2027-03-22)` with `gh api -X POST repos/maurice-jobst/bembel/milestones -f title='v1.0' -f due_on='2027-03-22T00:00:00Z'` if none exists) and the issue numbers for BEM-S04, BEM-S05, BEM-S11 by title.

- [ ] **Step 2: Move pulled-forward issues**

For each of BEM-S04, BEM-S05, BEM-S11 (numbers from Step 1):

```bash
gh issue edit <N> -R maurice-jobst/bembel --milestone "v1.0"
```

Then comment on each (one sentence, English, matching existing brief style): "Pulled into v1.0 by the hero repositioning — scope per docs/superpowers/specs/2026-08-13-hero-repositioning-design.md §2. Read-only + funnel at 1.0; write-side stays GitHub." (Adapt the parenthetical per issue: S05 "second register, same loader"; S11 "hero dependency, offline-first loader".)

- [ ] **Step 3: Split note on #36 (BEM-S01)**

#36 stays in M4. Comment:

"Split by the hero repositioning (spec 2026-08-13 §2): data-linked stickers (Datenspender, Verifizierer, Erste-Bewertung) and kiosk visit stamps ship in v1.0 (tracked in the Phase-1 hero plan). This issue keeps the Sammelalbum remainder: city-hotspot geofences, Game Center mirroring, seasonal drops. Guardrail update: the Datenspender sticker may be promised publicly at flip, since it ships at 1.0."

```bash
gh issue comment 36 -R maurice-jobst/bembel --body "<text above>"
```

- [ ] **Step 4: Verify**

```bash
gh issue list -R maurice-jobst/bembel --milestone "v1.0" --json number,title
```

Expected: BEM-S04, BEM-S05, BEM-S11 present (plus whatever already lived there).

---

### Task 7: PR + merge

- [ ] **Step 1: Push and open PR**

```bash
git push -u origin docs/hero-repositioning
gh pr create -R maurice-jobst/bembel --title "Docs: hero repositioning (Phase 0)" --body "Implements spec 2026-08-13 §1 + scope deltas of §2: ADR 0008 (AI-native selection), README/BACKLOG repositioned around the bembel-data hero, KICKOFF retired to docs/history, CHANGELOG entry. Milestone/issue reshuffle done via gh alongside. Schattenkarte scope unchanged — narrative demotion only.

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

- [ ] **Step 2: Review gate**

Run `/code-review` on the PR diff (docs-level: contradiction hunt, not bug hunt). Fix findings, push.

- [ ] **Step 3: Merge**

```bash
gh pr merge --squash --delete-branch
```

Expected: lands on main; CI (format-check, validate) green — no Swift touched, so failures mean environment, not this change.

---

## Follow-on plans (not in this document)

- Phase 1 — hero build (loader, registers, provenance, funnel, Merkmale nav, coverage, stickers): planned after Phase 0 merges, against the then-current repo state.
- Phase 2 — live providers (one plan per feature: RMV, Trinkbrunnen, RADOLAN, Stadtzustand, Schattenkarte).
- Phase 3 — polish + flip checklist.
- bembel-data: Ebbelwei schema + deep-link templates (planned with Phase 1, lives in the bembel-data repo).
