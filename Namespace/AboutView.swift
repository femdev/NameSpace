// The custom About / Help panel content (SwiftUI). Replaces the stock
// `orderFrontStandardAboutPanel` blurb with a sectioned layout: app glyph, what the app
// does, the three setup steps each with an inline "Open…" button that deep-links into
// the right System Settings pane, and a version + license footer.

import SwiftUI

struct AboutView: View {
    let version: String

    /// The app's brand violet — matches the app icon's deep-space gradient.
    private let brand = Color(red: 0.42, green: 0.34, blue: 0.90)

    // Each setup step: a title, an explanation, the button label, and the
    // System Settings URL it opens.
    private struct SetupStep: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
        let buttonTitle: String
        let url: String
    }

    private let steps: [SetupStep] = [
        SetupStep(
            title: "Enable direct jumps",
            detail: "Turn on \"Switch to Desktop 1…9\" so Namespace can jump straight to a "
                + "Space instead of cycling through the ones in between.",
            buttonTitle: "Open Keyboard Shortcuts",
            url: "x-apple.systempreferences:com.apple.preference.keyboard?Shortcuts"
        ),
        SetupStep(
            title: "Grant Accessibility",
            detail: "Required so Namespace can send the Ctrl+N / Ctrl+Arrow keystrokes that "
                + "switch Spaces.",
            buttonTitle: "Open Accessibility",
            url: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ),
        SetupStep(
            title: "Grant Automation",
            detail: "Required so Namespace can ask System Events to send those keystrokes.",
            buttonTitle: "Open Automation",
            url: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        )
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            Divider()
            Text("Adds custom names to your Mission Control Spaces. macOS only labels them "
                 + "\"Desktop 1, 2, 3…\" — Namespace keeps a name per Space (keyed to its "
                 + "stable UUID), so names follow each Space when you reorder them.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 12) {
                Text("Setup")
                    .font(.system(size: 13, weight: .semibold))
                ForEach(steps) { step in setupRow(step) }
            }

            Divider()
            footer
        }
        .padding(24)
        .frame(width: 460)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 40))
                .foregroundColor(brand)
            VStack(alignment: .leading, spacing: 2) {
                Text("Namespace")
                    .font(.system(size: 22, weight: .semibold))
                Text("Name your Mission Control Spaces")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func setupRow(_ step: SetupStep) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.system(size: 12, weight: .medium))
                Text(step.detail)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button(step.buttonTitle) { open(step.url) }
                .controlSize(.small)
                .fixedSize()
        }
    }

    private var footer: some View {
        HStack {
            Text("Version \(version)")
            Spacer()
            Text("MIT License · © 2026 femdev")
        }
        .font(.system(size: 10))
        .foregroundColor(.secondary)
    }

    private func open(_ urlString: String) {
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
