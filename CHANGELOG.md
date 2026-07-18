# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-07-18

### Added
- **"Check for Updates…"** menu item: an on-demand check that queries GitHub's Releases API,
  tells you if a newer version is out, and offers a Download button (opens the Releases page).
  No dependency, no background traffic, no auto-install — it only runs when you click it. This
  is the app's sole network use. (Works once the repo/releases are public.)

### Fixed
- **"Back" could get permanently stranded**: callers armed `SpaceHistory`'s fly-over
  suppression *before* `switchTo`, but `switchTo`'s early-return paths (no Accessibility,
  busy, already-on-target…) never disarmed it — so the pending target silently swallowed
  the next real Space change and broke Back. Most reachable by pressing ⌃⌥← before granting
  Accessibility. `switchTo` now reports whether it started and fires an on-finish callback,
  and callers keep history in sync. History is also no longer seeded with an invalid `0`
  Space id.

### Changed
- Hardening/cleanup from a security + code-quality review: removed the dead `CoreDock`
  `dlopen` shim from the private-API file, added `permissions: contents: read` to CI,
  restored the missing `NSWorkspace` observer removal in `deinit`, and now log (instead of
  swallow) a failed Dock restart.

### Added
- Notarized-release pipeline: `.github/workflows/release.yml` builds, Developer ID–signs
  (hardened runtime), notarizes, staples, and attaches a `.dmg` to a GitHub Release on
  every `v*` tag. Shared logic lives in `scripts/package-release.sh` (runs locally too).
- `Namespace.entitlements` (hardened-runtime Apple Events) and `docs/distribution-prd.md`.
- Permissions onboarding window shown on launch when Accessibility or Automation is
  missing, with live status that updates the instant you grant a permission (no relaunch)
  and one-click deep-links into the right System Settings panes.
- Menu-bar "permissions needed" banner that clears itself once everything is granted.
- **Auto-rearrange detection**: the setup window (and menu) now also check macOS's
  "Automatically rearrange Spaces based on most recent use" — which reorders Spaces and
  makes switching land one off — and offer a one-click **"Turn off"** (writes the pref and
  restarts the Dock). This was the cause of the "go to Space 3, land on Space 4" bug on
  fresh installs. The onboarding window is reframed from "Permissions" to "Setup".

### Changed
- `setup-signing.sh` now wires a stable self-signed identity into the build (via a
  git-ignored `Signing.local.xcconfig` picked up through an optional `#include?`), so
  Accessibility / Automation grants **persist across rebuilds** instead of being
  invalidated each time. Contributors and CI still build ad-hoc with no setup.

### Fixed
- Attempting to switch/Back without Accessibility no longer spams the macOS prompt **and** a
  modal alert on every press. `SpaceSwitcher` now checks quietly and surfaces the Setup
  window (with its Grant button) instead of nagging inline.
- **"Back" reliability**: the hotkey no longer leaks a digit ("4") into the focused text
  field — it waits for the ⌃⌥ modifiers to be released before synthesizing the switch
  keystroke. The Ctrl+Arrow walk is now reliable (waits for each Space to change before
  the next step, and self-corrects) instead of firing arrows faster than macOS can
  animate. Mashing the hotkey no longer stacks overlapping switches, and a direct jump
  now completes as soon as the Space changes rather than after a fixed delay.
- Onboarding Grant buttons: the "Grant… (Automation)" button now reliably triggers the
  "control System Events" consent prompt by sending a real Apple Event on the main thread
  (the old version ran off-thread and silently opened an empty pane); and the
  "Grant… (Accessibility)" button opens the pane cleanly instead of firing a system prompt
  *and* opening Settings at once.
- `setup-signing.sh` actually works now: it drives the OpenSSL-3 `-legacy` PKCS#12 fallback
  off the *import* (the export always succeeded, so the old fallback never ran), stops using
  `-v` (valid-only) when checking for the untrusted self-signed cert, always writes
  `Signing.local.xcconfig` (even when the cert already exists), and is ASCII-clean so it
  doesn't break under a non-UTF-8 shell.

## [0.1.0] - 2026-07-01

Initial public release.

### Added
- Menu-bar app that shows the current Mission Control Space's name.
- Rename / clear the current Space; names are keyed to each Space's stable UUID so they
  follow the Space when desktops are reordered.
- Switch to any Space from the menu-bar dropdown.
- **Back**: toggle to the previously-active Space via a menu item or the ⌃⌥← global
  hotkey.
- Mission Control overlay that draws name labels under each Space thumbnail (subject to
  macOS window-level restrictions; see the README).
- Custom About/Help window with inline links to the System Settings panes needed for
  first-run setup.
- Space-themed app icon (deep-space gradient + a stack of "Space" cards) and a matching
  brand-violet accent in the About window.
- Diagnostic logging (off by default) to `~/Library/Logs/Namespace.log`.
- Unit tests for the pure-logic layer (store, Space-dictionary parsing, key-code / walk
  math, and Space history) plus a GitHub Actions CI workflow.

[Unreleased]: https://github.com/femdev/NameSpace/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/femdev/NameSpace/releases/tag/v0.2.0
[0.1.0]: https://github.com/femdev/NameSpace/releases/tag/v0.1.0
