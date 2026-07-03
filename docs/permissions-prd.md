# PRD — Permissions that "just work"

Status: in progress · Branch: `feature/permissions-just-work` · Owner: femdev

## Problem

Namespace needs two macOS permissions to switch Spaces:
- **Accessibility** — to synthesize the Ctrl+N / Ctrl+Arrow keystrokes.
- **Automation** (Apple Events → System Events) — to ask System Events to send them.

Two pain points today:

1. **Grants don't survive rebuilds.** The app is signed **ad-hoc** ("Sign to Run
   Locally"), so every Xcode build produces a new code-signature hash. macOS TCC keys
   ad-hoc grants on that hash, so a rebuild silently invalidates Accessibility/Automation
   and the app stops switching. The only recovery is `tccutil reset …` from the command
   line (`reset-permissions.sh`) followed by a re-grant. This makes iterating painful —
   *"I'm unable to run/test without clearing things out from the command line."*

2. **Prompting is minimal.** Permissions are only requested when a switch is attempted,
   via a one-shot modal alert. There's no launch-time onboarding, no live status, and no
   feedback when a permission is granted (you must relaunch to pick it up).

## Goals

- Rebuilds **keep** existing permission grants — no more CLI resets in the normal loop.
- A clear, friendly **onboarding window** on launch when anything is missing.
- Status updates **live**: granting a permission flips the UI to ✅ within ~2s, no relaunch.
- Menu-bar dropdown reflects permission status and offers a one-click path to fix it.
- Contributors and CI who haven't set up signing build exactly as before (no new barrier).

## Non-goals

- Notarization / Developer ID / App Store signing (out of scope; source-distributed app).
- Auto-granting permissions (impossible — the user must grant in System Settings).
- Sandboxing.

## Approach

### 1. Stable code signing (persists grants)

A stable **self-signed** certificate gives the app a constant *designated requirement*,
so TCC matches the grant across rebuilds.

- `setup-signing.sh` already creates the cert (`Namespace Self-Signed`); it now also
  writes a git-ignored **`Signing.local.xcconfig`** with `CODE_SIGN_STYLE = Manual` and
  `CODE_SIGN_IDENTITY = Namespace Self-Signed`.
- The project's app target uses a committed base xcconfig (`Namespace.xcconfig`) that ends
  with `#include? "Signing.local.xcconfig"`. The `?` makes the include **optional**:
  - Local file present → build signs with the stable cert → grants persist.
  - Local file absent (contributors, CI) → falls back to ad-hoc, exactly as today.
- `CODE_SIGN_STYLE` is removed from the target's inline build settings so the xcconfig
  (lower precedence than inline settings) can actually take effect.

One-time cost for the maintainer: run `./setup-signing.sh`, then one final
`./reset-permissions.sh` + re-grant. After that, grants stick.

### 2. Live permission monitoring

`PermissionsMonitor` (an `ObservableObject`):
- **Accessibility**: `AXIsProcessTrusted()` (non-prompting) for status.
- **Automation**: `AEDeterminePermissionToAutomateTarget(…, askUserIfNeeded: false)`
  against `com.apple.systemevents`, mapping the OSStatus to granted / denied / notDetermined.
- Polls on a timer (~1.5s) **only while something is missing**, stopping once all granted
  to avoid needless wakeups; re-arms when the window reappears.
- Pure, unit-tested seams: the AE-status→state mapping and the overall summary.

### 3. Onboarding window + menu status

- `PermissionsView` (SwiftUI, brand-violet theme like About): one row per permission with a
  live ✅/⚠️ badge, an explanation, and an **Open…** button deep-linking to the exact pane.
  Shows an all-set state and auto-dismisses shortly after everything is granted.
- Shown automatically on launch when not all permissions are granted; reachable any time
  from the menu.
- `StatusBarController` shows a status line and a "Set up permissions…" item when anything
  is missing, and refreshes when the monitor reports a change.

## Acceptance criteria

- [ ] With `Signing.local.xcconfig` present, two consecutive `⌘R` builds keep an existing
      Accessibility grant (no re-grant needed).
- [ ] Without the local file, `xcodebuild build`/`test` still succeed (CI stays green).
- [ ] Launching with a permission missing shows the onboarding window.
- [ ] Granting a permission while the window is open flips it to ✅ within ~2s, no relaunch.
- [ ] Menu shows a "permissions needed" affordance until all are granted.
- [ ] Pure permission-logic unit tests pass; overall suite stays green.

## Rollout / manual verification

Automated tests can't exercise the TCC/system paths, so the maintainer verifies once:
`./setup-signing.sh` → `./reset-permissions.sh` → `⌘R` → grant both → rebuild → confirm
grants survived and switching works.
