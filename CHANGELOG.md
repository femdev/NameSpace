# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Permissions onboarding window shown on launch when Accessibility or Automation is
  missing, with live status that updates the instant you grant a permission (no relaunch)
  and one-click deep-links into the right System Settings panes.
- Menu-bar "permissions needed" banner that clears itself once everything is granted.

### Changed
- `setup-signing.sh` now wires a stable self-signed identity into the build (via a
  git-ignored `Signing.local.xcconfig` picked up through an optional `#include?`), so
  Accessibility / Automation grants **persist across rebuilds** instead of being
  invalidated each time. Contributors and CI still build ad-hoc with no setup.

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

[Unreleased]: https://github.com/femdev/NameSpace/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/femdev/NameSpace/releases/tag/v0.1.0
