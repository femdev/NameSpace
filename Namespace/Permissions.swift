// Live tracking of the two macOS permissions Namespace needs to switch Spaces:
// Accessibility (to synthesize keystrokes) and Automation (to drive System Events).
//
// `PermissionsMonitor` polls both — but only while something is still missing — and
// publishes changes so the onboarding window and the menu update the instant a grant
// happens, without a relaunch. The status-code mapping and the summary are pure and
// unit-tested; the actual TCC probes are thin system calls.

import AppKit
import ApplicationServices
import CoreServices

enum PermissionState: Equatable {
    case granted
    case denied
    case notDetermined
}

/// A snapshot of both permissions plus the derived "are we good to go?" answer.
struct PermissionsSummary: Equatable {
    let accessibility: PermissionState
    let automation: PermissionState

    var allGranted: Bool { accessibility == .granted && automation == .granted }
    var needsAttention: Bool { !allGranted }
}

final class PermissionsMonitor: ObservableObject {
    @Published private(set) var accessibility: PermissionState = .notDetermined
    @Published private(set) var automation: PermissionState = .notDetermined

    /// AppKit consumers (the status-bar menu) get a callback on any change.
    var onChange: ((PermissionsSummary) -> Void)?

    var summary: PermissionsSummary {
        PermissionsSummary(accessibility: accessibility, automation: automation)
    }

    private var timer: Timer?

    // MARK: - Polling

    /// Re-probe both permissions now; publishes + notifies if anything changed, and stops
    /// polling once everything is granted.
    func refresh() {
        let ax = Self.accessibilityState()
        let auto = Self.automationState()
        let changed = ax != accessibility || auto != automation
        accessibility = ax
        automation = auto
        if changed { onChange?(summary) }
        if summary.allGranted { stopPolling() }
    }

    /// Begin polling (no-op if already all-granted). Cheap: a single timer that tears
    /// itself down as soon as both permissions are granted.
    func startPolling(interval: TimeInterval = 1.5) {
        refresh()
        guard timer == nil, !summary.allGranted else { return }
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        t.tolerance = 0.5
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Pure mapping (unit-tested)

    /// Map the OSStatus from `AEDeterminePermissionToAutomateTarget` to a state.
    static func automationState(fromStatus status: OSStatus) -> PermissionState {
        switch status {
        case noErr:
            return .granted
        case OSStatus(errAEEventNotPermitted):
            return .denied
        case OSStatus(errAEEventWouldRequireUserConsent):
            return .notDetermined
        default:
            // procNotFound (System Events not running) or anything unexpected — we can't
            // prove it's denied, so treat as not-yet-determined.
            return .notDetermined
        }
    }

    // MARK: - System probes

    static func accessibilityState() -> PermissionState {
        // AX can't distinguish "denied" from "never asked" — both report untrusted.
        AXIsProcessTrusted() ? .granted : .notDetermined
    }

    static func automationState() -> PermissionState {
        automationState(fromStatus: queryAutomationStatus())
    }

    // MARK: - Requests (may prompt)

    /// Ask macOS for Accessibility by opening the Accessibility pane so the user can toggle
    /// Namespace on. The non-prompting check both reports status and ensures the app is
    /// listed in that pane. We deliberately do NOT also fire the system "Open System
    /// Settings" prompt: doing both popped a dialog AND opened Settings at once, which was
    /// confusing.
    static func requestAccessibility() {
        _ = AccessibilityCheck.isTrusted(prompt: false)
        open(pane: "Privacy_Accessibility")
    }

    /// Ask macOS for Automation. Sending a real (harmless) Apple Event to System Events is
    /// what actually fires the one-time "control System Events" consent dialog AND registers
    /// Namespace in the Automation list — `AEDeterminePermissionToAutomateTarget` alone does
    /// not reliably prompt. This must run on the **main thread** (Apple Events and the TCC
    /// prompt misbehave off-main; the earlier background version quietly opened an empty
    /// pane and never prompted). If access was already denied, macOS won't prompt again, so
    /// we send the user to the Automation pane instead.
    static func requestAutomation(completion: @escaping () -> Void = {}) {
        let work = {
            if automationState() == .denied {
                open(pane: "Privacy_Automation")
            } else {
                // Not-yet-determined (or granted): actually SENDING a command to System
                // Events is what fires the consent prompt. It must be a real command the
                // app has to handle — `count processes` is harmless and read-only.
                // (A statement like `return true` is evaluated locally by AppleScript and
                // never reaches System Events, so it never prompts.)
                var err: NSDictionary?
                NSAppleScript(source: "tell application \"System Events\" to count processes")?
                    .executeAndReturnError(&err)
            }
            completion()
        }
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }

    // MARK: - Helpers

    /// Non-prompting determination of permission to send Apple Events to System Events.
    /// (Requesting is done by actually sending an event in `requestAutomation`.)
    private static func queryAutomationStatus() -> OSStatus {
        let bundleID = "com.apple.systemevents"
        var target = AEDesc()
        let bytes = Array(bundleID.utf8)
        let createStatus: OSStatus = bytes.withUnsafeBytes { raw in
            OSStatus(AECreateDesc(typeApplicationBundleID, raw.baseAddress, raw.count, &target))
        }
        guard createStatus == noErr else { return createStatus }
        defer { AEDisposeDesc(&target) }
        return AEDeterminePermissionToAutomateTarget(&target, typeWildCard, typeWildCard, false)
    }

    private static func open(pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}
