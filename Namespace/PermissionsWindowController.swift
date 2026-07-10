// Hosts the SwiftUI `PermissionsView` in a small, centered, titled window. Reuses a
// single window instance, drives the monitor's polling while visible, and auto-dismisses
// shortly after everything (permissions + the auto-rearrange setting) is in order.

import AppKit
import SwiftUI

final class PermissionsWindowController {
    private var window: NSWindow?
    let monitor: PermissionsMonitor

    init(monitor: PermissionsMonitor) {
        self.monitor = monitor
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        monitor.startPolling()

        if let window {
            window.makeKeyAndOrderFront(nil)
            window.center()
            return
        }

        let view = PermissionsView(monitor: monitor) { [weak self] in
            // Everything's set — let the user see the ✅, then dismiss.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { self?.close() }
        }
        let host = NSHostingController(rootView: view)
        let win = NSWindow(contentViewController: host)
        win.title = "Namespace Setup"
        win.styleMask = [.titled, .closable]
        win.isReleasedWhenClosed = false
        win.setContentSize(host.view.fittingSize)
        win.center()
        win.makeKeyAndOrderFront(nil)
        self.window = win
    }

    func close() {
        window?.close()
    }
}
