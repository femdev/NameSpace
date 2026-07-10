// The onboarding / setup window content (SwiftUI). One row per requirement — the two
// permissions plus the auto-rearrange setting — each with a live status badge that flips as
// `PermissionsMonitor` re-probes, an explanation, and an action button. Themed in the brand
// violet to match the app icon and About window.

import SwiftUI

struct PermissionsView: View {
    @ObservedObject var monitor: PermissionsMonitor
    var onAllGood: () -> Void = {}

    private let brand = Color(red: 0.42, green: 0.34, blue: 0.90)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            Divider()
            Text("Namespace switches Spaces by sending keystrokes through System Events. "
                 + "It needs two permissions, and one Mission Control setting turned off. "
                 + "Set these once and you're done.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            row(title: "Accessibility",
                detail: "Lets Namespace synthesize the Ctrl+N / Ctrl+Arrow keystrokes that switch Spaces.",
                state: monitor.accessibility) {
                PermissionsMonitor.requestAccessibility()
            }

            row(title: "Automation",
                detail: "Lets Namespace ask System Events to send those keystrokes.",
                state: monitor.automation) {
                PermissionsMonitor.requestAutomation {}
            }

            rearrangeRow

            Divider()
            footer
        }
        .padding(24)
        .frame(width: 470)
        .onChange(of: monitor.summary.allGood) { done in
            if done { onAllGood() }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 36))
                .foregroundColor(brand)
            VStack(alignment: .leading, spacing: 2) {
                Text("Namespace Setup")
                    .font(.system(size: 20, weight: .semibold))
                Text(monitor.summary.allGood ? "All set — you're good to go."
                                              : "A few things are needed to switch Spaces.")
                    .font(.system(size: 12))
                    .foregroundColor(monitor.summary.allGood ? .green : .secondary)
            }
        }
    }

    private func row(title: String, detail: String, state: PermissionState,
                     action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 12) {
            badge(for: state)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if state == .granted {
                Text("Granted")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.green)
            } else {
                Button(state == .denied ? "Fix in Settings…" : "Grant…", action: action)
                    .controlSize(.small)
                    .fixedSize()
            }
        }
    }

    /// The auto-rearrange row: a Mission Control setting (not a permission). Shows ⚠️ + a
    /// one-click "Turn off…" while it's on, ✅ + "Off" once it's off.
    private var rearrangeRow: some View {
        let on = monitor.autoRearrangeOn
        return HStack(alignment: .top, spacing: 12) {
            badge(for: on ? .notDetermined : .granted)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text("Auto-rearrange Spaces is off")
                    .font(.system(size: 13, weight: .medium))
                Text("macOS's \"Automatically rearrange Spaces based on most recent use\" "
                     + "reorders your Spaces, which makes switching land on the wrong one. "
                     + "Namespace needs it off. (Turning it off restarts the Dock briefly.)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if on {
                Button("Turn off…") { PermissionsMonitor.disableSpacesRearrange() }
                    .controlSize(.small)
                    .fixedSize()
            } else {
                Text("Off")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.green)
            }
        }
    }

    @ViewBuilder
    private func badge(for state: PermissionState) -> some View {
        switch state {
        case .granted:
            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
        case .denied:
            Image(systemName: "xmark.octagon.fill").foregroundColor(.red)
        case .notDetermined:
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
        }
    }

    private var footer: some View {
        Text("This window updates on its own as you complete each step — no need to "
             + "relaunch. You can reopen it any time from the menu-bar icon.")
            .font(.system(size: 10))
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
