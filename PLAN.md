# Namespace — Work Plan (2026-06-15)

Resumable plan for an 8-item improvement pass. Do one at a time; check off as we go.
Decisions locked: **MIT license**, **back = global hotkey + menu item**.

## Status legend
- [ ] not started  · [~] in progress  · [x] done

---

### 1. Security review + easier setup  — [x]
DONE: diagLog → ~/Library/Logs/Namespace.log, O_NOFOLLOW + 0600, gated behind
DiagnosticLogging default / SPACESNAMER_DEBUG env (off by default). README updated.
Remaining vuln-reporting note lands in SECURITY.md under #9.
Findings from read-through (no network access anywhere; private CGS APIs are documented):
- **Log file in `/tmp`** (`AppDelegate.swift` `diagLog`): predictable world-readable path, `FileHandle(forWritingAtPath:)` follows symlinks → minor local symlink/info-leak risk for an open-source app.
  - Fix: write to `~/Library/Logs/Namespace.log` (or `os_log`), create with restrictive perms, and gate verbose logging behind a debug flag so a published build isn't chatty.
- **AppleScript keystroke injection** is fixed key codes only (no interpolation of user data) → safe. Leave as-is, add a comment.
- **Self-signed cert script** is sound. Note in README it creates a non-CA codesigning cert valid 10y in the login keychain.
- Verdict: fundamentally fine. Action items are the log path/flag + a short SECURITY note in README/CLAUDE.md.

### 2. Code quality / linter  — [x]
DONE: added advisory `.swiftlint.yml` (warnings only, not wired into the build), tuned to
existing style. CONTRIBUTING (#9) + CI (#10) document/run it.
Deferred cleanups (do where they fit, not worth their own risk now):
- Move `diagLog` to its own `Diagnostics.swift` → do during #10 pbxproj edit (or skip).
- "very obvious title"/`▣ ` framing in configureButton → revisit in #8 (About/UI polish).

### 3. Architecture review + docs  — [x]
- Structure is already clean (catalog / store / switcher / overlay / observer / statusbar / popover). Keep it.
- Add file-header doc comments describing each type's role and the private-API risk surface.
- Document the data flow (NSWorkspace notifications → StatusBar refresh; DistributedNotificationCenter → overlay show/hide) in CLAUDE.md.

### 4. CLAUDE.md per subdirectory  — [x]
- Root `CLAUDE.md`: product overview, build/run, private-API caveats, where things live.
- `Namespace/CLAUDE.md`: per-file map, data flow, conventions, how to add a feature.
- (xcodeproj dir doesn't need one.)

### 5. Git + GitHub  — [x]
- Add `.gitignore` (xcuserdata, `*.xcuserstate`, DerivedData, `.build`, `.DS_Store`).
- `git init`, initial commit. Remove the already-present `UserInterfaceState.xcuserstate` from tracking.
- User creates empty GitHub repo, then `git remote add origin … && git push -u origin main`. (Provide exact commands at the end.)

### 6. License (MIT)  — [x]
- Add `LICENSE` (MIT, 2026 femdev).
- Update `Info.plist` `NSHumanReadableCopyright` and add a license line to README.

### 7. "Back" shortcut (global hotkey + menu)  — [x]
- New `SpaceHistory` (tiny): observe `activeSpaceDidChangeNotification`, remember the immediately-previous Space UUID/id64 (ignore programmatic round-trips).
- Menu item "Back to «name»" (key-equivalent) in StatusBarController.
- Global hotkey: register a system-wide shortcut (Carbon `RegisterEventHotKey` or `NSEvent.addGlobalMonitorForEvents`). Default candidate `⌥\`` ; confirm final keystroke with user. Document that it may need Accessibility (already required).

### 8. Polish About/Help UI  — [x]
- Replace the standard `orderFrontStandardAboutPanel` blurb with a custom SwiftUI window: proper margins, color/accent, app glyph, sectioned Setup steps with inline "Open…" buttons, version + license footer.
- Keep the existing System Settings deep-links, just present them better.

### 9. Contributor / OSS hygiene docs  — [x]
First-OSS-project completeness pass:
- `CONTRIBUTING.md` — dev environment, build/run, **how to add a feature** (which file does what, conventions), code style (SwiftLint), **how to run tests**, and a "How Claude is used on this repo" section (CLAUDE.md files, how to prompt, what Claude should/shouldn't touch).
- `SECURITY.md` — how to report a vulnerability + scope note about private-API usage and no network access.
- `.github/` issue + PR templates (lightweight).
- Optional, include unless user skips: `CODE_OF_CONDUCT.md` (Contributor Covenant), `CHANGELOG.md` (Keep a Changelog, v0.1).
- README: add badges (license, CI) + "Contributing" + "License" sections.

### 10. Tests + CI  — [x]
- Add an **XCTest** target to the hand-written `.xcodeproj` (chosen over Swift Testing for first-contributor familiarity + easier pbxproj wiring).
- Make the pure-logic seams testable (`SpaceCatalog.parseSpaces` internal, expose walk-delta), add `@testable import`.
- Unit tests: `SpaceStore`, `SpaceCatalog.parseSpaces` (sample CGS dicts, type-4 skip, id64/ManagedSpaceID/NSNumber variants), `SpaceSwitcher.digitKeyCode` + walk-delta, `SpaceHistory` (added with #7).
- CI: GitHub Actions, macOS runner, `xcodebuild build` + `xcodebuild test`. Free for public repos.
- Document `xcodebuild test` (and the Xcode ⌘U path) in CONTRIBUTING.

---

## Suggested order
6 → 5 (license before first public commit) is ideal, but git can come first locally.
Recommended: **3+4 (docs)** → **1 (security)** → **2 (linter)** → **10 (tests+CI infra, tests for existing logic)** → **7 (back, + its tests)** → **8 (about)** → **9 (contributor docs)** → **6 (license)** → **5 (git/push)** last so the first commit is the polished state.
Each item = its own commit. Tests (#10) land before #7 so SpaceHistory ships with coverage.
