# Brainstorm — bembel-data cold start (2026-08-13)

Mode: assumption testing. Question: the v1.1 hero feature ("Yelp inside
GitHub") assumes contributions from people who love Wasserhäuschen. Kiosk
regulars are not GitHub users. Does the model survive?

## Findings

**"Cold start" is two problems; one is fake.**

- *Entries* cold start is solvable unilaterally: ~300–400 Wasserhäuschen in
  Frankfurt, most mapped in OSM, and bembel-data is already ODbL — the same
  licence as OSM, so share-alike is satisfied by construction. Bulk-import
  candidates (`verified: false`), promote via source-verification passes.
  Nobody rates into an empty room; the room won't be empty.
- *Ratings* cold start is real and structural: the CI rule
  "filename = PR author login" is what makes one-rating-per-account
  credible, and it also makes ratings **impossible to proxy** through the
  issue-form funnel. Ratings are GitHub-account-holders only, by design,
  forever. Weakening that integrity property was considered and rejected.

**Locked contributor model: curator core + dev raters** (OSM/Wikipedia
shape, not Yelp shape). We seed entries near-complete; the community
product is ratings and corrections from the Frankfurt tech × kiosk-culture
overlap (est. a few hundred people; ~10–30 active early raters make the
feature feel alive).

**Motivation stack** (all four selected, sequenced):

1. *Now, pre-flip (backend-lane starter tickets):* CI progress surface
   ("127 von ~385 erfasst, 43 verifiziert"), `contributors.json` in the
   release bundle, OSM import script + source policy, structured
   rating tags (`merkmale`) in the schema. All `area:data`,
   self-contained, no Xcode — ideal first tickets for @jaypikay/@monsdroid.
2. *Launch moment:* completion-campaign framing ("alle 385 erfassen",
   Adoptier-ein-Viertel) in the going-public post; IRL mapping evening in
   the bubble (CCC-FFM / meetup, ends at a Wasserhäuschen) as the first
   real experiment — 10 first-PRs in one night beats a month organic.
3. *v1.1:* public credit surfaces in-app ("bewertet von @handle") — falls
   out of the data model for free.
4. *Epic S:* "Datenspender" sticker unlocked by a merged bembel-data PR.
   Identity bridge without a backend: app Settings gets an optional
   GitHub-Benutzername field, matched locally against `contributors.json`
   from the data bundle. Handle-squatting is possible, on-device-only, and
   harmless — accepted. **Guardrail: do not publicly promise the sticker
   before the Sammelalbum ships.**

**Ratings act:** stays sub-60-seconds. Schema already has stars + optional
280-char comment (bounded, review-gated — keep). Add structured tags;
tags aggregate, comments don't, and devs prefer ticking boxes to writing
feelings.

## Riskiest remaining assumption + cheapest test

Even with the full stack, devs may not rate. Test = the IRL event + first
30 days after the public flip: count first-time rating PRs. Graceful
degradation is built in: the verified register alone is a real product;
ratings are additive, so failure is quiet, not fatal.

## Set aside

- Broad-community funnel as primary path (forms stay as an entry side door).
- Prose reviews beyond the one-sentence comment.
- Any weakening of the login=filename integrity check.

## Captured as

- bembel-data issues: OSM-Import, CI-Fortschritt + contributors.json,
  Merkmale-Schema.
- Comment on BEMBEL #36 (BEM-S01): Datenspender sticker + identity bridge.
