// Switches to a target Space. Prefers a direct Ctrl+N jump (desktops 1–9, requires the
// user to have enabled "Switch to Desktop N" shortcuts); falls back to walking with
// Ctrl+Arrow. Keystrokes are synthesized via AppleScript → System Events because the
// public/private direct-switch APIs are gone in macOS 26 (needs Accessibility +
// Automation). `digitKeyCode` and the walk-delta math are the pure, testable parts.

import Foundation
import AppKit
import CoreGraphics // CGEventSource — read the physically-held modifier keys

enum SpaceSwitcher {
    /// True while a switch is mid-flight, so mashing the hotkey doesn't stack overlapping
    /// walks on top of one another (the runaway behavior seen in the diagnostic logs).
    private static var isSwitching = false

    static func switchTo(spaceID: UInt64) {
        guard AccessibilityCheck.isTrusted(prompt: true) else {
            diagLog("switchTo: aborted — Accessibility not granted. Prompted user to grant.")
            DispatchQueue.main.async { AccessibilityCheck.showSettingsAlert() }
            return
        }
        guard !isSwitching else {
            diagLog("switchTo: ignored — a switch is already in progress")
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

        // The switch is driven by synthesized Ctrl+N / Ctrl+Arrow keystrokes. When this is
        // triggered by the global hotkey (⌃⌥←), the user is usually still holding those
        // modifiers, which contaminates the synthesized keystroke — e.g. a synthesized
        // Ctrl+4 lands as Ctrl+Option+4 and the "4" leaks into the focused text field
        // instead of switching. Wait for the physical modifiers to clear, then emit.
        isSwitching = true
        afterModifiersClear {
            emitSwitch(targetIdx: targetIdx, currentID: currentID, spaceID: spaceID) {
                isSwitching = false
            }
        }
    }

    private static func emitSwitch(targetIdx: Int, currentID: UInt64, spaceID: UInt64,
                                   completion: @escaping () -> Void) {
        // Prefer the direct Ctrl+N jump (no cycling). Only works for desktops 1–9
        // AND requires the user to have "Switch to Desktop N" enabled in
        // System Settings → Keyboard → Keyboard Shortcuts → Mission Control.
        let oneBased = targetIdx + 1
        if (1...9).contains(oneBased), let keyCode = digitKeyCode(oneBased) {
            diagLog("switchTo: direct jump via Ctrl+\(oneBased) (key code \(keyCode))")
            sendAppleScriptKey(keyCode: keyCode)
            // Poll for the jump to land instead of a fixed wait: finish (and release the
            // in-progress lock) the instant the Space actually changes — usually ~0.5s, the
            // animation floor — so Back feels snappy. Only if nothing happens after ~1.1s do
            // we assume the shortcut isn't enabled and fall back to walking.
            waitForSpaceChange(from: currentID, tries: 55) {
                let now = SpaceCatalog.currentSpaceID()
                if now == spaceID {
                    diagLog("switchTo: direct jump succeeded")
                    completion()
                } else if now == currentID {
                    diagLog("switchTo: Ctrl+\(oneBased) had no effect (shortcut likely not enabled) — walking instead")
                    walkToward(spaceID: spaceID, stalls: 0, completion: completion)
                } else {
                    diagLog("switchTo: landed elsewhere (now=\(now)); not piling on")
                    completion()
                }
            }
            return
        }

        // Desktop 10+ — Ctrl+N can't cover it; walk with Ctrl+Arrow.
        walkToward(spaceID: spaceID, stalls: 0, completion: completion)
    }

    /// Runs `action` on the main queue once the Control/Option/Command modifiers are
    /// physically released (or after a ~0.6s timeout). Without this, a hotkey-triggered
    /// switch fires its synthesized Ctrl+digit / Ctrl+arrow while the user is still holding
    /// the hotkey's modifiers, so the keystroke is corrupted (the digit leaks as text and
    /// the switch is unreliable).
    private static func afterModifiersClear(remainingTries: Int = 40, _ action: @escaping () -> Void) {
        let held: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand]
        let flags = CGEventSource.flagsState(.combinedSessionState)
        if remainingTries <= 0 || flags.isDisjoint(with: held) {
            action()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.015) {
                afterModifiersClear(remainingTries: remainingTries - 1, action)
            }
        }
    }

    /// Reliable walk: send one Ctrl+Arrow toward the target, then WAIT for the Space to
    /// actually change before the next step. Each Space switch animates for ~0.5s, so the
    /// old fixed 0.04s spacing fired arrows far faster than macOS could process them and
    /// most got dropped. This re-reads the live Space each step (so a dropped keystroke
    /// self-corrects) and gives up after a few stalls (a keystroke that never lands, e.g.
    /// at the ends of the Space list).
    private static func walkToward(spaceID: UInt64, stalls: Int, completion: @escaping () -> Void) {
        let ordered = SpaceCatalog.currentDisplaySpaces()
        let currentID = SpaceCatalog.currentSpaceID()
        guard let targetIdx = ordered.firstIndex(where: { $0.id64 == spaceID }),
              let currentIdx = ordered.firstIndex(where: { $0.id64 == currentID }) else {
            diagLog("switchTo: walk aborted — Space list changed")
            completion(); return
        }
        guard currentIdx != targetIdx else {
            diagLog("switchTo: walk reached target")
            completion(); return
        }
        guard stalls < 3 else {
            diagLog("switchTo: walk stalled (keystrokes not landing) — giving up")
            completion(); return
        }
        let keyCode = walkKeyCode(delta: walkDelta(targetIdx: targetIdx, fromIdx: currentIdx))
        diagLog("switchTo: walk step toward target (at idx \(currentIdx), want \(targetIdx))")
        sendAppleScriptKey(keyCode: keyCode)
        waitForSpaceChange(from: currentID, tries: 40) {
            let moved = SpaceCatalog.currentSpaceID() != currentID
            walkToward(spaceID: spaceID, stalls: moved ? 0 : stalls + 1, completion: completion)
        }
    }

    /// Polls (up to ~0.8s) until the active Space differs from `from`, then runs `done`.
    private static func waitForSpaceChange(from: UInt64, tries: Int, _ done: @escaping () -> Void) {
        if tries <= 0 || SpaceCatalog.currentSpaceID() != from {
            done()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                waitForSpaceChange(from: from, tries: tries - 1, done)
            }
        }
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
