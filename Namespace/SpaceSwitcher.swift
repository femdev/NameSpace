// Switches to a target Space. Prefers a direct Ctrl+N jump (desktops 1–9, requires the
// user to have enabled "Switch to Desktop N" shortcuts); falls back to walking with
// Ctrl+Arrow. Keystrokes are synthesized via AppleScript → System Events because the
// public/private direct-switch APIs are gone in macOS 26 (needs Accessibility +
// Automation). `digitKeyCode` and the walk-delta math are the pure, testable parts.

import Foundation
import AppKit

enum SpaceSwitcher {
    static func switchTo(spaceID: UInt64) {
        guard AccessibilityCheck.isTrusted(prompt: true) else {
            diagLog("switchTo: aborted — Accessibility not granted. Prompted user to grant.")
            DispatchQueue.main.async { AccessibilityCheck.showSettingsAlert() }
            return
        }
        let ordered = SpaceCatalog.currentDisplaySpaces()
        guard let targetIdx = ordered.firstIndex(where: { $0.id64 == spaceID }) else {
            diagLog("switchTo: target id=\(spaceID) not in ordered list")
            return
        }
        let currentID = SpaceCatalog.currentSpaceID()
        guard let currentIdx = ordered.firstIndex(where: { $0.id64 == currentID }) else {
            diagLog("switchTo: current id=\(currentID) not in ordered list")
            return
        }
        guard targetIdx != currentIdx else {
            diagLog("switchTo: already on target")
            return
        }

        // Prefer the direct Ctrl+N jump (no cycling). Only works for desktops 1–9
        // AND requires the user to have "Switch to Desktop N" enabled in
        // System Settings → Keyboard → Keyboard Shortcuts → Mission Control.
        let oneBased = targetIdx + 1
        if (1...9).contains(oneBased), let keyCode = digitKeyCode(oneBased) {
            diagLog("switchTo: direct jump via Ctrl+\(oneBased) (key code \(keyCode))")
            sendAppleScriptKey(keyCode: keyCode)
            // Space-switch animation takes ~0.5–0.7s on macOS 26. Wait long enough
            // that currentSpaceID has actually updated before deciding whether to
            // fall back. Also: only fall back if NOTHING changed (currentID is
            // exactly where we started) — that means the keystroke was ignored.
            // Any other state means Ctrl+N is in progress or succeeded; don't pile on.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                let now = SpaceCatalog.currentSpaceID()
                if now == spaceID {
                    diagLog("switchTo: direct jump succeeded")
                } else if now == currentID {
                    diagLog("switchTo: Ctrl+\(oneBased) had no effect (likely shortcut not enabled) — falling back to walk")
                    walkTo(targetIdx: targetIdx, fromIdx: currentIdx)
                } else {
                    diagLog("switchTo: ended on a different space than target (now=\(now), target=\(spaceID)) — leaving it; not piling on")
                }
            }
            return
        }

        // Target is desktop 10+ — Ctrl+N doesn't cover it; walk with Ctrl+Arrow.
        walkTo(targetIdx: targetIdx, fromIdx: currentIdx)
    }

    private static func walkTo(targetIdx: Int, fromIdx: Int) {
        let delta = walkDelta(targetIdx: targetIdx, fromIdx: fromIdx)
        guard delta != 0 else { return }
        let keyCode = walkKeyCode(delta: delta) // RightArrow / LeftArrow
        diagLog("switchTo: walking \(abs(delta)) steps via Ctrl+\(delta > 0 ? "→" : "←")")
        var lines = ["tell application \"System Events\""]
        for _ in 0..<abs(delta) {
            lines.append("    key code \(keyCode) using {control down}")
            lines.append("    delay 0.04")
        }
        lines.append("end tell")
        runAppleScript(lines.joined(separator: "\n"))
    }

    private static func sendAppleScriptKey(keyCode: Int) {
        let script = """
        tell application "System Events"
            key code \(keyCode) using {control down}
        end tell
        """
        runAppleScript(script)
    }

    private static func runAppleScript(_ source: String) {
        var err: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&err)
        if let err = err { diagLog("AppleScript error: \(err)") }
    }

    // Signed number of steps to walk from the current index to the target
    // (positive = right, negative = left). Pure; unit-tested.
    static func walkDelta(targetIdx: Int, fromIdx: Int) -> Int {
        targetIdx - fromIdx
    }

    // Arrow key code for a walk direction: RightArrow (124) for forward, LeftArrow
    // (123) for backward. Pure; unit-tested.
    static func walkKeyCode(delta: Int) -> Int {
        delta > 0 ? 124 : 123
    }

    // macOS virtual key codes for the digits 1–9 on the main number row.
    // Internal (not private) so unit tests can exercise it via `@testable import`.
    static func digitKeyCode(_ n: Int) -> Int? {
        switch n {
        case 1: return 18
        case 2: return 19
        case 3: return 20
        case 4: return 21
        case 5: return 23
        case 6: return 22
        case 7: return 26
        case 8: return 28
        case 9: return 25
        default: return nil
        }
    }
}
