#!/bin/sh
# Branch protection on main: require the three CI checks green + a PR
# (0 required approvals for now — a small team shouldn't be blocked from
# merging its own solo tickets; raise required_approving_review_count once
# there's more than one active contributor).
#
# GitHub Free doesn't support branch protection on PRIVATE repos (Pro/Team/
# Enterprise, or the repo must be public) — this fails with a 403 until
# maurice-jobst/bembel is switched to public. Run it right after that flip.
set -eu
gh api -X PUT repos/maurice-jobst/bembel/branches/main/protection --input - <<'EOF'
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "BEMBELKit tests (swift test, native macOS)",
      "App build (iOS Simulator, unsigned)",
      "Schema validation (stdlib only, no pip)"
    ]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0,
    "dismiss_stale_reviews": true
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
