# Security

## Reporting a vulnerability

Use [private vulnerability reporting](https://github.com/maurice-jobst/bembel/security/advisories/new).
Please don't open a public issue for anything exploitable.

Expect an acknowledgement within a week. This is a small volunteer project with
a 2027 ship date, so there is no paid bounty and no formal SLA — what there is,
is a fix and public credit unless you'd rather not be named.

## What is in scope

BEMBEL has no backend, no accounts and no BEMBEL-operated servers, which
removes most of the usual surface. What remains:

- **The app** — the iOS client in `App/`, `Widgets/` and `Packages/BEMBELKit/`.
  Most interesting: the parsers, because they consume bytes from the public
  internet. `RadolanRadarProvider` decodes a bzip2 archive and a binary raster
  from DWD, and the dataset decoders parse JSON and GeoJSON fetched at runtime.
  A crafted payload that gets code execution, or reads or writes outside the
  app container, is a vulnerability.
- **The data pipeline** — `scripts/`, `data/` and the workflows in `.github/`.
  A path that lets a pull request write outside the repo, exfiltrate a token,
  or land unreviewed data in the published bundle is a vulnerability.
- **The deep-link surface** — `bembel://` URLs are attacker-supplied input. A
  link that makes the app act outside what the scheme documents counts.
- **Privacy claims.** The App Store label says Data Not Collected. Anything
  that puts identifiable user data on the wire is a security bug here, not a
  product decision, and will be treated as one.

## What is out of scope

- Anything about the **upstream open-data providers** themselves — the
  Frankfurt Geoportal, DWD, PEGELONLINE, the Autobahn GmbH and the rest, all
  registered in [`data/sources.json`](data/sources.json). Report those to the
  operator, not here. If an upstream is *dead* rather than vulnerable, that is
  an ordinary issue and the [weekly sweep](.github/workflows/sources-liveness.yml)
  probably already filed one.
- Content in the community register at
  [bembel-data](https://github.com/maurice-jobst/bembel-data). Wrong or abusive
  entries are a moderation matter — open an issue there.
- Missing hardening with no exploit path attached, and automated scanner output
  submitted without one.

## How the project reduces its own surface

- **No third-party runtime dependencies.** Nothing in the app is pulled from a
  package registry, so there is no dependency chain to compromise.
- **No secrets in the repo.** `Config/Secrets.xcconfig` is gitignored and CI
  builds from the template with no real values
  ([ADR 0005](docs/adr/0005-secrets-and-open-source-build.md)).
- **Actions are pinned to a commit SHA** with the version in a trailing comment,
  and every workflow declares least-privilege `permissions`. Dependabot watches
  the pins.
- **Data is validated before it is trusted.** `make validate` rejects a curated
  row without a source URL, and the payloads store scalars only — never prose
  pulled from a scraped page.
