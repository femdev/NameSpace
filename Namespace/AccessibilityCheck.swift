// Accessibility-permission helpers. Wraps AXIsProcessTrustedWithOptions (optionally
// triggering the system prompt) and shows an in-app alert that deep-links to the
// Accessibility pane. Accessibility is required because switching Spaces synthesizes
// keystrokes through System Events.

import ApplicationServices
import AppKit

enum AccessibilityCheck {
    /// True if Namespace currently has Accessibility (used for synthesizing
    /// keystrokes via System Events). Pass `prompt=true` to make macOS show
    /// the system "Open System Settings" dialog when not trusted.
    @discardableResult
    static func isTrusted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options: CFDictionary = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Shows an in-app alert with a button that jumps straight to the
    /// Accessibility pane in System Settings. Use this when the system's
    /// own prompt has been dismissed and the user needs another nudge.
    static func showSettingsAlert() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Namespace needs Accessibility permission"
        // User-facing prose, intentionally unwrapped:
        // swiftlint:disable line_length
        alert.informativeText = """
            To switch Spaces, Namespace asks System Events to send Ctrl+N / Ctrl+Arrow keystrokes. macOS requires Accessibility permission for this.

            Click "Open System Settings", find Namespace in the list, and toggle it on. If it's already on, toggle it off and on again — a recent rebuild may have invalidated the grant.
            """
        // swiftlint:enable line_length
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
