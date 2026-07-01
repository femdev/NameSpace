# Contributing to Namespace

Thanks for your interest! Namespace is a small, single-purpose macOS menu-bar app.
This guide covers how to build it, how the code is laid out, how to add a feature, and
how it's tested.

## Development environment

- **macOS 13.0+** and a recent **Xcode** (the project was created with Xcode 15+).
- No package manager: the app has **no third-party dependencies** and the `.xcodeproj`
  is hand-written. There is nothing to `pod install` or `swift package resolve`.
- Language: **Swift 5**. Deployment target: **macOS 13.0**.

### Build & run

```bash
open Namespace.xcodeproj      # then pick the "Namespace" scheme and press ⌘R
```

On first run you'll need to grant a few permissions — see the **First-run setup**
section of the [README](README.md). If switching stops working after a rebuild, the
signature changed and macOS invalidated the TCC grants; run `./reset-permissions.sh`
(or the `tccutil` commands in the README) and re-grant.

For a stable code-signing identity that survives rebuilds (so you don't have to
re-grant permissions every time), run `./setup-signing.sh` once.

## How the code is organized

One responsibility per type. UI types call into the logic types; they don't do CGS or
AppleScript work themselves. See [`Namespace/CLAUDE.md`](Namespace/CLAUDE.md) for the
full per-file map and data-flow notes. In short:

- **Logic (pure, unit-tested):** `SpaceStore` (name persistence), `SpaceCatalog`
  (Space enumeration/parsing), `SpaceSwitcher` (key-code + walk math), `SpaceHistory`
  (previous-Space tracking).
- **System edges:** `CGSPrivate` (private SkyLight symbols), `SpaceSwitcher` (AppleScript
  keystrokes), `GlobalHotKey` (Carbon hotkey), `AccessibilityCheck` (permissions),
  `MissionControlObserver` (distributed notifications).
- **UI:** `StatusBarController` (the hub), `RenamePopover`, `OverlayView` /
  `OverlayWindowController`, `AboutView` / `AboutWindowController`.

### The important caveat

macOS exposes **no public API** for enumerating or switching Spaces. The app relies on
undocumented CoreGraphics/SkyLight (CGS) symbols and synthesized keystrokes. `CGSPrivate.swift`
and `SpaceCatalog.swift` are the riskiest files — a future macOS could change these
symbols. There is **no network access anywhere** in the app, by design; please keep it
that way.

## How to add a feature

Worked example — a menu action that operates on the current Space:

1. Add any persisted state to `SpaceStore` (keyed by the Space **UUID**) with a unit test.
2. Put the pure logic (computing a target, a mapping, etc.) somewhere testable.
3. Add the `NSMenuItem` + `@objc` handler in `StatusBarController.rebuildMenu`.
4. If it switches Spaces, route through `SpaceSwitcher` — and call
   `SpaceHistory.beginProgrammaticSwitch(to:)` first so the switch's fly-over Spaces
   aren't recorded as history. Don't synthesize raw keystrokes yourself.
5. Call `refresh()` so the title/menu update.

Space identity: use the **UUID** for anything persisted (stable across reorder) and the
**id64** for live CGS operations (switching). Don't conflate them.

## Code style

- Match the surrounding Swift style. A `.swiftlint.yml` is provided as **advisory**
  (warnings only; not wired into the build). If you have SwiftLint installed,
  `swiftlint` in the repo root will flag deviations.
- Route diagnostics through `diagLog`, never bare `print`.
- Keep new logic in pure, side-effect-free seams so it can be unit-tested; keep system
  calls thin and at the edges.
- No new network calls, analytics, or third-party dependencies without discussion first.

## Running the tests

Pure-logic units are covered by XCTest under `NamespaceTests/`.

- In Xcode: **⌘U**.
- Terminal:
  ```bash
  xcodebuild test -scheme Namespace -destination 'platform=macOS'
  ```

CI (GitHub Actions) runs `xcodebuild build` and `xcodebuild test` on every push and PR.
Please add tests alongside any new pure logic, and make sure the suite is green before
opening a PR.

## Pull requests

- Keep PRs focused; one logical change per PR.
- Describe what changed and why, and note anything you couldn't test (e.g. behavior that
  depends on private APIs or a specific macOS version).
- Make sure the build and tests pass.

## How Claude is used on this repo

This project is developed with the help of Claude (Anthropic's CLI). The `CLAUDE.md`
files (root + `Namespace/`) are the source of truth Claude reads for product context,
the per-file map, and conventions — keep them up to date when you move things around.
When prompting Claude here: point it at the relevant `CLAUDE.md`, ask it to keep logic in
testable seams, and remind it **not** to touch `CGSPrivate.swift` / `SpaceCatalog.swift`
casually or to add network/dependencies. Human review of any private-API changes is
expected.
