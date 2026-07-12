// Builds and tears down the label overlay: a transparent, borderless, screenSaver-level
// window that joins all Spaces and hosts the SwiftUI `OverlayView`. Shown while Mission
// Control is open. (May not render above MC on current macOS — see README caveats.)

import AppKit
import SwiftUI

final class OverlayWindowController {
    private var window: NSWindow?
    private let store: SpaceStore
    private let history: SpaceHistory

    init(store: SpaceStore, history: SpaceHistory) {
        self.store = store
        self.history = history
    }

    func show() {
        hide()
        guard let screen = NSScreen.main else { return }

        let spaces = SpaceCatalog.currentDisplaySpaces()
        guard !spaces.isEmpty else { return }

        let names = spaces.map { store.displayName(forUUID: $0.uuid) }

        let win = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.level = .screenSaver
        win.ignoresMouseEvents = false
        win.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary
        ]
        win.setFrame(screen.frame, display: true)

        let view = OverlayView(
            spaces: spaces,
            names: names,
            screenFrame: screen.frame
        ) { [history] spaceID in
            // Arm fly-over suppression so the Spaces a walk passes through aren't recorded
            // as history — but disarm it if the switch never starts or once it settles, so a
            // stranded pending target can't swallow the next real Space change.
            history.beginProgrammaticSwitch(to: spaceID)
            let started = SpaceSwitcher.switchTo(spaceID: spaceID) { history.abandonPendingSwitch() }
            if !started { history.abandonPendingSwitch() }
        }
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(origin: .zero, size: screen.frame.size)
        win.contentView = host
        win.orderFrontRegardless()
        self.window = win
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
    }
}
