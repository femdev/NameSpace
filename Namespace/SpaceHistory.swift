// Tracks the immediately-previous Space so "Back" can toggle between two Spaces
// (like ⌘-Tab for desktops). Pure logic, unit-tested — the notification wiring and
// the actual switch live in StatusBarController / SpaceSwitcher.
//
// Identity here is the live id64 (the handle used for switching), not the UUID.
//
// The one wrinkle: our own programmatic switches can walk through intermediate
// Spaces (Ctrl+Arrow), each of which fires activeSpaceDidChange. We must not treat
// those fly-over Spaces as history. So a switch we initiate is announced with
// `beginProgrammaticSwitch(to:)`; intermediate landings are then ignored until the
// target is reached, and the whole switch is recorded as a single hop.

import Foundation

final class SpaceHistory {
    /// The Space we're currently on (last committed landing).
    private(set) var current: UInt64?
    /// The Space we were on before `current`; the target of "Back".
    private(set) var previous: UInt64?
    /// Non-nil while a programmatic switch is in flight; the id we expect to land on.
    private var pendingTarget: UInt64?

    /// The id "Back" would switch to, or nil if there's no prior Space yet.
    var back: UInt64? { previous }

    /// Feed every `activeSpaceDidChange`: `id` is the now-active Space's id64.
    /// Manual moves push history; intermediate landings during one of our own
    /// switches are ignored until the announced target is reached.
    func record(_ id: UInt64) {
        if let target = pendingTarget {
            guard id == target else { return } // fly-over during a walk — ignore
            previous = current
            current = id
            pendingTarget = nil
            return
        }
        guard id != current else { return } // spurious duplicate notification
        previous = current
        current = id
    }

    /// Announce that we're about to switch to `target` ourselves, so the
    /// intermediate Spaces a walk passes through aren't recorded as history.
    func beginProgrammaticSwitch(to target: UInt64) {
        pendingTarget = target
    }

    /// Abandon an in-flight programmatic switch (e.g. it failed to land), so manual
    /// moves are recorded again instead of being suppressed indefinitely.
    func abandonPendingSwitch() {
        pendingTarget = nil
    }
}
