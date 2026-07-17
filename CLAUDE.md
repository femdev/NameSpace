# CLAUDE.md — Namespace (root)

Guidance for Claude (and humans) working in this repository.

## What this product is

Namespace is a native macOS **menu-bar app** that lets you give custom names to
Mission Control Spaces (virtual desktops). macOS only labels Spaces "Desktop 1, 2,
3…" with no rename option. Namespace keeps a name **per Space, keyed to the
Space's stable UUID**, so names follow a Space even when you reorder desktops.

It does three things:
1. Shows the current Space's name in the menu bar.
2. Lets you rename / clear the current Space, jump to any Space from a menu, and
   toggle back to the previous Space (menu item or the ⌃⌥← global hotkey).
3. Draws name labels under each Space thumbnail when Mission Control opens.

## How it works (the important caveat)

macOS exposes **no public API** for enumerating or switching Spaces. Namespace
relies on:
- **Private CoreGraphics SkyLight (CGS) symbols** for Space enumeration —
  `CGSCopyManagedDisplaySpaces`, `CGSGetActiveSpace`, `CGSMainConnectionID`
  (declared via `@_silgen_name` in `CGSPrivate.swift`).
- **System Events (AppleScript)** to synthesize the keystrokes that actually
  switch a Space, because `CoreDockSwitchToSpace` was removed in macOS 26. This is
  why the app needs **Accessibility** + **Automation** permissions.

Consequences worth remembering when editing:
- Symbols are undocumented and could break on a future macOS. Touch `CGSPrivate.swift`
  and `SpaceCatalog.swift` carefully.
- No App Store distribution is possible. Distribution is source + self-signed build.
- The app's **only** network use is an on-demand "Check for Updates…" menu action that
  queries GitHub's public Releases API (see `UpdateChecker.swift`). No background traffic,
  no analytics, no telemetry, no automatic downloads.

## Build & run

- Open `Namespace.xcodeproj`, select the **Namespace** scheme, ⌘R.
- Deployment target: macOS 13.0. Swift 5. Hand-written `.xcodeproj` (no SPM/CocoaPods).
- Bundle id: `com.elise.Namespace`.
- First run needs the permissions described in `README.md` ("First-run setup").
- `setup-signing.sh` creates a stable self-signed identity so TCC grants survive
  rebuilds; `reset-permissions.sh` clears stale grants after an unsigned rebuild.

## Tests

- Unit tests cover the **pure-logic layer** (see `Namespace/CLAUDE.md`): store,
  Space-dictionary parsing, key-code mapping, space history.
- Run from Xcode with ⌘U, or `xcodebuild test -scheme Namespace
  -destination 'platform=macOS'`.
- System-dependent code (CGS calls, AppleScript, overlay rendering) is **not**
  unit-tested; keep new logic in testable, side-effect-free seams where possible.

## Repository layout

```
Namespace.xcodeproj/   hand-written Xcode project
Namespace/             app source — see Namespace/CLAUDE.md for the per-file map
setup-signing.sh         one-time stable self-signed codesigning identity
reset-permissions.sh     clear stale TCC grants after a rebuild
README.md                user-facing install + usage
CONTRIBUTING.md          dev setup, how to add a feature, how Claude is used here
PLAN.md                  current improvement work plan (resumable)
```

## Conventions for changes

- Keep the clean separation of concerns (one type per responsibility — see the
  per-file map). Don't fold system calls into UI types.
- New pure logic should be unit-testable; add tests alongside it.
- Diagnostic logging goes through `diagLog`; don't `print` directly.
- Match the surrounding Swift style; SwiftLint config is advisory (see `.swiftlint.yml`).
- Don't add network calls, analytics, or third-party dependencies without discussion.
