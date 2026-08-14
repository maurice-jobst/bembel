# ADR 0004 — BEMBELKit as a local Swift package; synced-folder project

Date: 2026-08-13 · Status: accepted

## Context

Three targets (app, widgets, shared code) in a plain Xcode project, no
XcodeGen/Tuist, three contributors. Hand-authored pbxproj files with per-file
references are the most fragile artifact in an iOS repo and a chronic source
of merge conflicts.

## Decision

- **BEMBELKit is a local Swift package** (`Packages/BEMBELKit`), not a
  framework target. Membership is directory structure, `Package.swift` is
  readable and diffable, and tests run via `swift test` without Xcode.
- **BEMBELKit declares macOS as a platform** — not for a Mac app, but so unit
  tests run natively on any Mac and in CI without booting a simulator.
  UIKit-only code is gated with `#if canImport(UIKit)`.
- **The app project uses objectVersion 77 filesystem-synchronized groups**:
  the `App/` and `Widgets/` folders *are* the target membership. Adding a
  file never touches the pbxproj.

## Consequences

- Adding/removing source files causes zero project-file churn; pbxproj merge
  conflicts effectively disappear.
- Requires Xcode 16+ (already implied by the iOS 18.5 target).
- Widget code that needs sharing goes into BEMBELKit, never into
  cross-target file membership.
