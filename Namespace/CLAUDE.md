# CLAUDE.md — Namespace/ (app source)

Per-file map, data flow, and conventions for the source directory.
Read the root `CLAUDE.md` first for product context and the private-API caveat.

## Per-file map

| File | Role |
|---|---|
| `main.swift` | Entry point. Creates `NSApplication`, sets the `AppDelegate`, runs the loop. |
| `AppDelegate.swift` | App lifecycle. Owns the `SpaceStore`, `StatusBarController`, `OverlayWindowController`, `MissionControlObserver` and wires them together. Also defines `diagLog`. |
| `CGSPrivate.swift` | Private API surface. `@_silgen_name` declarations for the CGS/SkyLight symbols + `dlopen` shim for the (now-removed) CoreDock switch. **The riskiest file** — undocumented symbols. |
| `SpaceCatalog.swift` | Reads Spaces from CGS: ordered Spaces for the current display, current Space id/UUID. `parseSpaces` turns the raw CGS dictionary into `[Space]`. Pure-ish; the parsing is unit-tested. |
| `SpaceStore.swift` | Persistence. UUID→name map in `UserDefaults`. Trimming, fallback names, display-name precedence. Fully unit-tested. |
| `SpaceSwitcher.swift` | Switching. Prefers a direct Ctrl+N jump (desktops 1–9, needs the shortcut enabled), falls back to walking with Ctrl+Arrow. Drives keystrokes via AppleScript→System Events. `digitKeyCode` + `walkDelta`/`walkKeyCode` are pure/testable. |
| `SpaceHistory.swift` | Tracks the immediately-previous Space (by id64) so "Back" can toggle. Suppresses the fly-over Spaces our own switches walk through. Pure/testable. |
| `GlobalHotKey.swift` | A single system-wide Carbon hotkey (`RegisterEventHotKey`). Drives the ⌃⌥← "Back" shortcut. |
| `AccessibilityCheck.swift` | Wraps `AXIsProcessTrustedWithOptions`; shows the "grant Accessibility" alert. |
| `Permissions.swift` | `PermissionsMonitor` (ObservableObject): live status of Accessibility + Automation, polling that stops once all granted, request helpers. The AE-status→state mapping + summary are pure/testable. |
| `PermissionsView.swift` | SwiftUI onboarding panel: per-permission live status badge + Grant button. |
| `PermissionsWindowController.swift` | Hosts `PermissionsView`; shown on launch when a permission is missing; auto-dismisses once all granted. |
| `MissionControlObserver.swift` | Listens on `DistributedNotificationCenter` for Mission Control activate/deactivate and fires callbacks. |
| `OverlayWindowController.swift` | Builds the transparent, screenSaver-level, all-Spaces window that hosts the labels. |
| `OverlayView.swift` | SwiftUI. Positions name labels under each Space thumbnail using the empirically-tuned Spaces-bar geometry constants. |
| `StatusBarController.swift` | The `NSStatusItem`, its menu (rename/clear/back/switch/setup help/about/quit), the rename popover trigger, and the ⌃⌥← hotkey registration. The main UI hub. |
| `RenamePopover.swift` | SwiftUI text field for entering a name. |
| `AboutView.swift` | SwiftUI content for the custom About/Help panel: app glyph, blurb, sectioned setup steps with inline "Open…" buttons, version + license footer. |
| `AboutWindowController.swift` | Hosts `AboutView` in a small reusable titled window. |
| `Info.plist` | `LSUIElement=YES` (no Dock icon), usage-description strings. |

## Data flow

**Naming / display**
`SpaceStore` (UserDefaults) ⇄ `StatusBarController`. On
`NSWorkspace.activeSpaceDidChangeNotification` the status bar refreshes its title
and rebuilds the menu from `SpaceCatalog` + `SpaceStore`.

**Switching**
User clicks a menu item / overlay label / presses ⌃⌥← → the initiator calls
`SpaceHistory.beginProgrammaticSwitch(to:)` then `SpaceSwitcher.switchTo(spaceID:)` →
Accessibility check → Ctrl+N direct jump (verify after ~0.9s) → fall back to
Ctrl+Arrow walk if nothing changed.

**Back / history**
Every `activeSpaceDidChange` feeds `SpaceHistory.record(id64)`. Manual moves push
history; the fly-over Spaces our own walks pass through are suppressed (announced via
`beginProgrammaticSwitch`). "Back" (menu item or the ⌃⌥← `GlobalHotKey`) switches to
`SpaceHistory.back`, toggling between the two most recent Spaces.

**Overlay**
`MissionControlObserver` (DistributedNotificationCenter) → `onActivate`/`onDeactivate`
→ `OverlayWindowController.show()/hide()` → renders `OverlayView` with the current
Spaces + names.

**Permissions**
`AppDelegate` owns a `PermissionsMonitor`. On launch it polls Accessibility +
Automation; if either is missing, `PermissionsWindowController` shows the onboarding
window (which keeps polling and auto-dismisses once all granted). `StatusBarController`
subscribes via `onChange` to show a "permissions needed" banner in the menu until
everything is granted. Grants persist across rebuilds only when the app is signed with a
stable identity — see the signing note in the root `CLAUDE.md` / README.

## Conventions

- One responsibility per type; UI types (`StatusBarController`, views) call into the
  logic types (`SpaceCatalog`, `SpaceStore`, `SpaceSwitcher`) rather than doing CGS /
  AppleScript work themselves.
- Keep new logic in pure, side-effect-free functions so it can be unit-tested; system
  calls stay thin and at the edges.
- Log through `diagLog`, never bare `print`.
- Space identity is the **UUID** for persistence (stable across reorder) and the
  **id64** for live CGS operations (switching). Don't conflate them.

## How to add a feature (worked example)

Adding a menu action that operates on the current Space:
1. Add any persisted state to `SpaceStore` (keyed by UUID) with a unit test.
2. Add the pure logic (e.g. compute a target) somewhere testable.
3. Add the `NSMenuItem` + `@objc` handler in `StatusBarController.rebuildMenu`.
4. If it switches Spaces, route through `SpaceSwitcher`, not raw keystrokes.
5. Call `refresh()` so the title/menu update.
