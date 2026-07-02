// The onboarding / permissions window content (SwiftUI). One row per required permission
// with a live status badge that flips as `PermissionsMonitor` re-probes, an explanation,
// and a button that requests the grant + opens the matching System Settings pane. Themed
// in the brand violet to match the app icon and About window.

import SwiftUI

struct PermissionsView: View {
    @ObservedObject var monitor: PermissionsMonitor
    var onAllGranted: () -> Void = {}

    private let brand = Color(red: 0.42, green: 0.34, blue: 0.90)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            Divider()
            Text("Namespace switches Spaces by sending keystrokes through System Events, "
                 + "which macOS gates behind two permissions. Grant them once — with stable "
                 + "signing set up (see the README), they persist across rebuilds.")
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

            Divider()
            footer
        }
        .padding(24)
        .frame(width: 470)
        .onChange(of: monitor.summary.allGranted) { done in
            if done { onAllGranted() }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 36))
                .foregroundColor(brand)
            VStack(alignment: .leading, spacing: 2) {
                Text("Namespace Permissions")
                    .font(.system(size: 20, weight: .semibold))
                Text(monitor.summary.allGranted ? "All set — you're good to go."
                                                 : "Two permissions are needed to switch Spaces.")
                    .font(.system(size: 12))
                    .foregroundColor(monitor.summary.allGranted ? .green : .secondary)
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
        Text("This window updates on its own as you grant each permission — no need to "
             + "relaunch. You can reopen it any time from the menu-bar icon.")
            .font(.system(size: 10))
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
