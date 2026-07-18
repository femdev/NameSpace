# Namespace

*Name your Mission Control Spaces.*

[![CI](https://github.com/femdev/NameSpace/actions/workflows/ci.yml/badge.svg)](https://github.com/femdev/NameSpace/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform: macOS 13+](https://img.shields.io/badge/platform-macOS%2013%2B-blue.svg)](#build--run)

<!--
GitHub repo setup — paste these into the repo's "About" panel (⚙ next to "About",
top-right of the repo page). Topics help discovery, since "Namespace" is a common word.

  Description:
    Name your macOS Mission Control Spaces — a menu-bar app that labels virtual
    desktops, keyed to each Space's stable UUID so names survive reordering.

  Topics:
    macos, menu-bar, menu-bar-app, mission-control, spaces, virtual-desktops,
    desktop, swift, appkit, swiftui, macos-app

  Website: (link to a release or docs page, once you have one)
-->

Native macOS menu bar app that lets you name Mission Control Spaces. Custom labels appear under each Space thumbnail when you open Mission Control. Click the name in the menu bar dropdown to switch to that Space, or press ⌃⌥← to jump back to the Space you came from. Names are keyed to each Space's stable UUID, so reordering desktops doesn't break them.

## Build & run

1. `open Namespace.xcodeproj`
2. Pick the **Namespace** scheme (top-left in Xcode) and hit **⌘R**.
3. On the first build, Xcode may prompt for a signing team — pick your personal team (free Apple ID is fine).
4. The icon appears in the menu bar (top of screen). Look for the **stacked-squares glyph** followed by the space name (e.g. `▣ Space xxxx` until you rename it).

## First-run setup (required for full functionality)

A few macOS settings need to be set. Without them, renaming works but switching does not. (The app's Setup window walks you through them — this is the manual reference.)

### 1. Enable "Switch to Desktop N" keyboard shortcuts (for instant jumps)

By default on macOS 26, the Ctrl+1/Ctrl+2/… direct-jump shortcuts are **disabled**. Namespace uses them under the hood to jump directly to a space without cycling through intermediates.

**Open the setting:**
```
System Settings → Keyboard → Keyboard Shortcuts… → Mission Control
```
Or paste in Terminal:
```bash
open "x-apple.systempreferences:com.apple.preference.keyboard?Shortcuts"
```

Scroll to the "Mission Control" section. Tick the boxes for **"Switch to Desktop 1"**, **"Switch to Desktop 2"**, etc., for each desktop you have. They'll show shortcuts like `^1`, `^2`.

If you skip this step or leave it partially enabled, Namespace falls back to walking through spaces one at a time (Ctrl+Arrow). Still works, but you see the cycle animation.

> **Note:** macOS only supports Ctrl+1 through Ctrl+9. For desktops 10+, Namespace always walks.

### 2. Grant Accessibility permission

Required so the app can send keystrokes (Ctrl+N / Ctrl+Arrow) to perform the switch.

```
System Settings → Privacy & Security → Accessibility
```
Or:
```bash
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
```

Find **Namespace** in the list and toggle it ON. If it's not in the list yet, run the app, click a space name to try switching, and macOS will prompt you the first time.

### 3. Allow control of System Events

The first time Namespace tries to switch a space, macOS prompts:
> "Namespace wants to control System Events"

Click **Allow**. (You can revisit this later in System Settings → Privacy & Security → Automation.)

### 4. Turn off "Automatically rearrange Spaces"

macOS reorders your Spaces by recent use by default, which makes position-based switching
land on the **wrong Space**. Namespace needs this **off**:

```
System Settings → Desktop & Dock → Mission Control →
  uncheck "Automatically rearrange Spaces based on most recent use"
```
Or in Terminal:
```bash
defaults write com.apple.dock mru-spaces -bool false && killall Dock
```

> **The app guides you through all of this.** On launch, if a permission is missing *or*
> auto-rearrange is on, Namespace opens a **Setup** window with a live status badge and a
> one-click button for each item (including a **"Turn off"** for auto-rearrange). It updates
> on its own the moment you fix one — no relaunch. Reopen it any time from the menu-bar icon.

### Make permissions stick across rebuilds (recommended, one-time)

By default the app is signed **ad-hoc** ("Sign to Run Locally"), so every Xcode rebuild
changes its code signature and macOS silently invalidates your Accessibility / Automation
grants — meaning you'd have to re-grant after every build.

Fix it once by signing with a **stable self-signed identity**:

```bash
./setup-signing.sh      # creates a self-signed cert + wires it into the build (git-ignored)
./reset-permissions.sh  # one final TCC reset so macOS re-issues grants against the new signature
# Then ⌘R in Xcode and grant both permissions. After this, grants persist across rebuilds.
```

`setup-signing.sh` writes a git-ignored `Signing.local.xcconfig` that the project picks up
via an optional `#include?`. Contributors and CI who skip this build ad-hoc exactly as
before. If you ever need to force a fresh re-grant, `./reset-permissions.sh` still does it.

## Using it

- **Status bar icon** shows the current Space's name (or `Space xxxx` as a fallback using the last 4 chars of its UUID).
- **Click the icon → "Rename this Space…"** → type a name → Enter. The icon updates immediately.
- **Click the icon → "Clear name for this Space"** to revert to the fallback name.
- **Click any space name in the dropdown** to switch to it.
- **"Back to «name»" (⌃⌥←)** toggles to the previously-active Space — works system-wide as a global hotkey, or from the menu. Press again to toggle back.
- **Open Mission Control (F3)** — labels appear under each thumbnail (if the overlay renders on your macOS version; see Known limitations below).
- **Move the menu bar icon:** hold ⌘ and drag it to where you want it. macOS remembers the position.

## Known limitations / caveats

- **Uses private macOS APIs.** `CGSCopyManagedDisplaySpaces`, `CGSGetActiveSpace`, etc. Apple gives no public alternative. Symbols have been stable for years but a future macOS update could break things.
- **No App Store distribution** — same reason. Distributed instead as a notarized Developer ID download (see [Releases](#releases-notarized-downloads)).
- **CoreDock framework was removed in macOS 26**, taking `CoreDockSwitchToSpace` with it. We work around it by driving Ctrl+N / Ctrl+Arrow via AppleScript → System Events. That's why the Accessibility + Automation + Keyboard Shortcuts setup matters.
- **The Mission Control overlay may not render above MC on current macOS.** Apple has tightened restrictions on screenSaver-level windows. If labels don't appear under thumbnails, the status bar UI still works for everything else.
- **Single-display only** for now. Multi-monitor with separate Spaces per display will only show labels on the main display.
- **Direct-jump shortcuts cover desktops 1–9 only.** Desktop 10+ falls back to walking.

## Releases (notarized downloads)

The app can't ship on the Mac App Store (it uses private Space APIs and needs
Accessibility/Automation, which the App Sandbox forbids). The distribution path is a
**Developer ID–signed, notarized `.dmg`** that opens with no Gatekeeper warnings — see
[`docs/distribution-prd.md`](docs/distribution-prd.md) for the full rationale.

**Cutting a release** (maintainer) — the tag drives the version, so there's nothing to
bump:

```bash
git tag v0.2.0
git push origin v0.2.0     # triggers .github/workflows/release.yml
```

That workflow builds Release at the tag's version, signs with hardened runtime, notarizes
via `notarytool`, staples, and attaches the `.dmg` to a GitHub Release. Full step-by-step
in [`RELEASING.md`](RELEASING.md).

**Prerequisites** (one-time):
- An **active paid Apple Developer Program** membership (required for Developer ID + notarization).
- These repository secrets (Settings → Secrets and variables → Actions):

  | Secret | What |
  |---|---|
  | `DEVELOPER_ID_CERT_P12` | base64 of your exported *Developer ID Application* cert (.p12) |
  | `DEVELOPER_ID_CERT_PASSWORD` | the .p12 export password |
  | `SIGN_IDENTITY` | e.g. `Developer ID Application: Your Name (TEAMID)` |
  | `AC_API_KEY_P8` | base64 of an App Store Connect API key (.p8) |
  | `AC_API_KEY_ID` | that key's Key ID |
  | `AC_API_ISSUER_ID` | the API issuer UUID |

  Base64 a file with `base64 -i cert.p12 | pbcopy`.

You can also run the packaging step locally once your Developer ID cert is in your keychain:

```bash
xcodebuild build -scheme Namespace -configuration Release -derivedDataPath build CODE_SIGNING_ALLOWED=NO
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  ./scripts/package-release.sh build/Build/Products/Release/Namespace.app dist
# (omit the AC_* env to produce a signed-but-not-notarized dmg for a dry run)
```

## File layout

```
Namespace.xcodeproj/        # hand-written Xcode project
Namespace.xcconfig            # base build config; optional #include of Signing.local.xcconfig
Namespace/
  main.swift                    # entry point: creates NSApplication, runs the loop
  AppDelegate.swift             # composition root; owns store/history/permissions
  CGSPrivate.swift              # private API declarations (@_silgen_name + dlopen)
  SpaceCatalog.swift            # enumerate Spaces, current Space ID/UUID
  SpaceStore.swift              # UserDefaults persistence (UUID → name)
  SpaceSwitcher.swift           # Ctrl+N direct jump, falls back to Ctrl+Arrow walking
  SpaceHistory.swift            # tracks the previous Space for the "Back" toggle
  GlobalHotKey.swift            # Carbon system-wide hotkey (⌃⌥← for Back)
  AccessibilityCheck.swift      # Accessibility permission helper
  Permissions.swift             # live Accessibility + Automation monitor (polling)
  PermissionsView.swift         # SwiftUI onboarding panel with live status
  PermissionsWindowController.swift # hosts the permissions window
  MissionControlObserver.swift  # detects MC activate / deactivate
  OverlayWindowController.swift # transparent screenSaver-level window
  OverlayView.swift             # SwiftUI labels positioned under thumbnails
  StatusBarController.swift     # NSStatusItem + menu + hotkey + help links
  RenamePopover.swift           # SwiftUI text input for rename
  UpdateChecker.swift           # on-demand "Check for Updates" via the GitHub Releases API
  AboutView.swift               # SwiftUI content for the custom About/Help panel
  AboutWindowController.swift   # hosts AboutView in a titled window
  Info.plist                    # LSUIElement=YES, NSAppleEventsUsageDescription
  Assets.xcassets/              # app icon
NamespaceTests/               # XCTest unit tests for the pure-logic layer
  SpaceStoreTests.swift
  SpaceCatalogTests.swift
  SpaceSwitcherTests.swift
  SpaceHistoryTests.swift
  PermissionsTests.swift
  UpdateCheckerTests.swift
docs/                         # PRDs and design notes
```

## Running the tests

Pure-logic units (store, Space-dict parsing, key-code / walk math, history) are covered
by XCTest. System code (CGS, AppleScript, overlay) is not unit-tested.

- In Xcode: **⌘U**.
- From the terminal:
  ```bash
  xcodebuild test -scheme Namespace -destination 'platform=macOS'
  ```

## Contributing

Contributions welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) for dev setup, how the
code is organized, how to add a feature, and how to run the tests. Please also read the
[Code of Conduct](CODE_OF_CONDUCT.md). To report a security issue, see
[SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE) © 2026 femdev.

## Debugging

Diagnostic logging is **off by default** (a released build writes no log file). Turn it on
for a session in either of two ways, then relaunch the app:

```bash
# Option A: a UserDefaults flag (persists until you turn it off)
defaults write com.namespaceapp.Namespace DiagnosticLogging -bool YES
# turn it back off with:  defaults write com.namespaceapp.Namespace DiagnosticLogging -bool NO

# Option B: an environment variable (just this launch, e.g. from Xcode's scheme)
SPACESNAMER_DEBUG=1 /path/to/Namespace.app/Contents/MacOS/Namespace
```

When enabled, the app writes a timestamped log to `~/Library/Logs/Namespace.log`
(per-user, created with private `0600` permissions). Tail it to see what's happening:

```bash
tail -f ~/Library/Logs/Namespace.log
```

Useful greps:
```bash
grep SpaceSwitcher ~/Library/Logs/Namespace.log    # which switching path is being used
grep StatusBar     ~/Library/Logs/Namespace.log    # status item lifecycle
grep AppleScript   ~/Library/Logs/Namespace.log    # System Events errors (permission issues)
```
