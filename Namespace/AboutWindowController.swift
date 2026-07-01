// Hosts the custom SwiftUI `AboutView` in a small, centered, titled window. Reuses a
// single window instance so repeated "About" clicks just bring the existing one forward.

import AppKit
import SwiftUI

final class AboutWindowController {
    private var window: NSWindow?

    /// App version shown in the footer, read from the bundle's Info.plist.
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)

        if let window {
            window.makeKeyAndOrderFront(nil)
            window.center()
            return
        }

        let host = NSHostingController(rootView: AboutView(version: version))
        let win = NSWindow(contentViewController: host)
        win.title = "About Namespace"
        win.styleMask = [.titled, .closable]
        win.isReleasedWhenClosed = false
        win.setContentSize(host.view.fittingSize)
        win.center()
        win.makeKeyAndOrderFront(nil)
        self.window = win
    }
}
