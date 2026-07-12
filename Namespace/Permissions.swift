// Live tracking of everything Namespace needs to switch Spaces reliably: the two macOS
// permissions — Accessibility (to synthesize keystrokes) and Automation (to drive System
// Events) — plus one Mission Control setting, "Automatically rearrange Spaces based on most
// recent use", which must be OFF (when on, macOS reorders Spaces out from under the
// position-based switching, causing off-by-one jumps).
//
// `PermissionsMonitor` polls all three — but only while something still needs attention —
// and publishes changes so the onboarding window and the menu update live, without a
// relaunch. The status mapping and the summary are pure and unit-tested; the probes are
// thin system calls.

import AppKit
import ApplicationServices
import CoreServices

enum PermissionState: Equatable {
    case granted
    case denied
    case notDetermined
}

/// A snapshot of the two permissions + the auto-rearrange setting, plus the derived
/// "are we good to go?" answer.
struct PermissionsSummary: Equatable {
    let accessibility: PermissionState
    let automation: PermissionState
    /// macOS "Automatically rearrange Spaces based on most recent use" — must be OFF for
    /// position-based Space switching to be reliable.
    let autoRearrangeOn: Bool

    var allGood: Bool {
        accessibility == .granted && automation == .granted && !autoRearrangeOn
    }
    var needsAttention: Bool { !allGood }
}

final class PermissionsMonitor: ObservableObject {
    @Published private(set) var accessibility: PermissionState = .notDetermined
    @Published private(set) var automation: PermissionState = .notDetermined
    @Published private(set) var autoRearrangeOn: Bool = false

    /// AppKit consumers (the status-bar menu) get a callback on any change.
    var onChange: ((PermissionsSummary) -> Void)?

    var summary: PermissionsSummary {
        PermissionsSummary(accessibility: accessibility, automation: automation,
                           autoRearrangeOn: autoRearrangeOn)
    }

    private var timer: Timer?

    // MARK: - Polling

    /// Re-probe permissions + the auto-rearrange setting now; publishes + notifies if
    /// anything changed, and stops polling once everything is in order.
    func refresh() {
        let ax = Self.accessibilityState()
        let auto = Self.automationState()
        let rearrange = Self.spacesRearrangeEnabled()
        let changed = ax != accessibility || auto != automation || rearrange != autoRearrangeOn
        accessibility = ax
        automation = auto
        autoRearrangeOn = rearrange
        if changed { onChange?(summary) }
        if summary.allGood { stopPolling() }
    }

    /// Begin polling (no-op if already all-good). Cheap: a single timer that tears itself
    /// down as soon as everything is in order.
    func startPolling(interval: TimeInterval = 1.5) {
        refresh()
        guard timer == nil, !summary.allGood else { return }
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

    // MARK: - Auto-rearrange setting

    /// Whether "Automatically rearrange Spaces based on most recent use" is on (the macOS
    /// default). Reads `com.apple.dock`'s `mru-spaces`; absent means the default (on).
    static func spacesRearrangeEnabled() -> Bool {
        let domain = "com.apple.dock" as CFString
        CFPreferencesAppSynchronize(domain)
        let value = CFPreferencesCopyAppValue("mru-spaces" as CFString, domain)
        guard let number = value as? NSNumber else { return true } // unset -> default ON
        return number.boolValue
    }

    /// Turn off auto-rearrange and restart the Dock so it takes effect. Writes to the
    /// Dock's own preference domain (allowed — Namespace is not sandboxed) and relaunches
    /// Dock, which reappears within about a second.
    static func disableSpacesRearrange() {
        let domain = "com.apple.dock" as CFString
        CFPreferencesSetAppValue("mru-spaces" as CFString, kCFBooleanFalse, domain)
        CFPreferencesAppSynchronize(domain)
        let killall = Process()
        killall.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        killall.arguments = ["Dock"]
        do {
            try killall.run()
        } catch {
            // The pref is written but Dock won't pick it up until its next relaunch.
            diagLog("disableSpacesRearrange: could not restart Dock: \(error)")
        }
    }

    /// Opens the Desktop & Dock settings pane (Mission Control lives there) for users who
    /// prefer to flip the setting themselves.
    static func openMissionControlSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
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
