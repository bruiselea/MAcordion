# MAcordion Swift Development Instructions

Use `$ios-release-loop` for feature work, bug fixes, refactors, QA, review, and release preparation.

## Project map

- Product purpose: Native macOS accordion controlled by a MacBook hinge.
- Supported platform: macOS 13 or later; Universal 2 release bundles.
- Project: Swift Package Manager package in `Package.swift`.
- Executable: `MAcordion`.
- Unit tests: None currently.
- Packaging source of truth: `scripts/package.sh` and `Packaging/Info.plist`.
- Device-only capability: MacBook hinge IOHID input.

## Required commands

- Discover products: `swift package describe`
- Focused tests: `swift test --filter <TestName>`
- Full tests: `swift test`
- Debug build: `swift build`
- Release/package verification: `./scripts/package.sh`

Treat successful `xcodebuild` output as authoritative over editor diagnostics. Never claim simulator or physical-device QA unless it was actually performed and recorded.

## Working agreement

- Define observable acceptance criteria and non-goals before substantial changes.
- Create `docs/plans/YYYY-MM-DD-<feature>.md` for medium/high-risk or multi-step work.
- Prefer a failing test before implementation when behavior is testable. Otherwise record the manual replacement check.
- Keep changes small, preserve unrelated edits, and follow the repository's generated-file conventions.
- Put reusable technical decisions in `docs/decisions/` and device evidence in `docs/qa/`.
- Keep QA bridges, catalogs, mock data, and diagnostic servers out of Release builds.
- Do not upload, submit, change store configuration, or release without explicit user authorization.

## Definition of done

- Acceptance criteria are met.
- Relevant tests and `xcodebuild` pass.
- Simulator checks pass when applicable.
- Required physical-device checks pass on a recorded build.
- Accessibility, privacy, lifecycle, persistence, and adjacent regressions are addressed in proportion to risk.
- Review findings are fixed or explicitly deferred.
- Release-impacting changes have an updated release record.
