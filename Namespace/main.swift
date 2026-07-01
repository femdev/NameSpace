// Entry point. Creates the NSApplication, installs the AppDelegate, runs the loop.
// The app is a menu-bar accessory (LSUIElement) — no Dock icon, no main window.

import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
