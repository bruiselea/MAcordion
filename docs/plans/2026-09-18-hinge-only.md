# Feature plan: Hinge-only MAcordion

- Status: Complete
- Owner: MAcordion
- Date: 2026-09-18
- Risk: Medium

## Context and goal

MAcordion is the MacBook-hinge instrument. The experimental Breath and Shisha editions should no longer be part of the repository or its release packages.

## Non-goals

- Changing hinge synchronization, keyboard mapping, synthesis, or visual design.
- Rewriting Git history that already contains the removed experiments.

## Acceptance criteria

- The package exposes only the `MAcordion` executable.
- Breath/Shisha source files, entry points, permissions, localization, and documentation are absent from the current tree.
- Packaging creates only `MAcordion.app` and its ZIP.
- The hinge-only app builds, packages, launches, and reads the hinge source as before.

## Affected surface and risks

- Screens/navigation: Removes mode abstractions; the existing hinge UI remains.
- State/persistence: No change.
- Permissions/device APIs: Removes microphone and external sensor access; retains IOHID hinge access.
- Privacy/security: Reduces permissions and device-access surface.
- Existing behavior: Hinge behavior must remain unchanged.

## Approach and slices

- [x] Remove the two executable targets and dedicated sensor implementations.
- [x] Simplify the shared UI and view model to hinge-only behavior.
- [x] Remove permissions, localization, README, and packaging references.
- [x] Build, package, launch, and inspect the final tree.

## Verification plan

- Automated tests: No retained test target; run `swift build`.
- Simulator scenarios: Not applicable to a macOS app.
- Physical-device scenarios: Launch the packaged app on this Mac and confirm the process is the hinge `MAcordion` executable.
- Release/configuration checks: Run `./scripts/package.sh`; verify only one app and ZIP are emitted.

## Decisions and open questions

- Decision: Remove current-tree implementation and references without rewriting Git history.
- Decision: Keep the generic `BellowsSource` protocol as the seam between hinge I/O and the view model.

## Verification evidence

- `swift package describe` — exactly one product and executable target: `MAcordion`.
- `swift build` — passed on 2026-09-18.
- `./scripts/package.sh` — passed arm64 and x86_64 Release builds; emitted only `MAcordion.app` and `MAcordion-1.4.0-universal2.zip`.
- `codesign --verify --deep --strict` — packaged app valid and satisfies its designated requirement.
- Process check — only the hinge `MAcordion` executable is running; the stale Breath process was terminated.
- Source scan — no Breath/Shisha implementation, permission, localization, documentation, or packaging references remain outside this decision record.

## Deferred work

- Live hinge-angle movement was not interactively exercised during this cleanup; the packaged hinge app launched successfully and the hinge code path was not behaviorally changed.
