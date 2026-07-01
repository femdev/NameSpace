// App lifecycle and composition root. Owns the SpaceStore and wires together the
// status-bar UI, the Mission Control overlay, and the MC activate/deactivate observer.
// Also defines `diagLog`, the app-wide diagnostic logger.

import AppKit

/// Whether diagnostic logging is active. Off by default, so a released build stays quiet
/// and writes no log file. Enable for a session in either of two ways:
///   • launch with the environment variable `SPACESNAMER_DEBUG=1`, or
///   • `defaults write com.elise.Namespace DiagnosticLogging -bool YES`
let diagLoggingEnabled: Bool = {
    if ProcessInfo.processInfo.environment["SPACESNAMER_DEBUG"] != nil { return true }
    return UserDefaults.standard.bool(forKey: "DiagnosticLogging")
}()

/// True when the process is hosting the XCTest bundle. The test runner sets
/// `XCTestConfigurationFilePath` in the environment; we key off that so the app can
/// suppress its normal (UI + permission-prompting) startup while under test.
let isRunningUnitTests: Bool =
    ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

/// Per-user log file at ~/Library/Logs/Namespace.log. Deliberately not a shared /tmp
/// path: a world-writable directory let another local user pre-create the file or plant a
/// symlink we'd follow on write. ~/Library/Logs is owned by the user and created if absent.
private let diagLogURL: URL? = {
    guard let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
    else { return nil }
    let logs = library.appendingPathComponent("Logs", isDirectory: true)
    try? FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
    return logs.appendingPathComponent("Namespace.log")
}()

func diagLog(_ msg: String) {
    guard diagLoggingEnabled else { return }
    let line = "[\(Date())] \(msg)\n"
    print(line, terminator: "")
    fflush(stdout)
    guard let url = diagLogURL, let data = line.data(using: .utf8) else { return }
    // O_NOFOLLOW: never follow a planted symlink. O_CREAT with mode 0600: if we create the
    // file it is private to this user. Append so concurrent writers don't clobber.
    let fd = open(url.path, O_WRONLY | O_APPEND | O_CREAT | O_NOFOLLOW, 0o600)
    guard fd >= 0 else { return }
    data.withUnsafeBytes { _ = write(fd, $0.baseAddress, $0.count) }
    close(fd)
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = SpaceStore()
    private let history = SpaceHistory()
    private var statusBar: StatusBarController!
    private var overlay: OverlayWindowController!
    private var mcObserver: MissionControlObserver!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // When the app is acting as the unit-test host, stay completely inert: don't
        // create the status-bar item, overlay, or observers, and never trigger an
        // Accessibility prompt. The tests only need the module loaded, not the UI.
        if isRunningUnitTests {
            diagLog("applicationDidFinishLaunching: unit-test host — skipping app setup")
            return
        }
        diagLog("applicationDidFinishLaunching START")
        NSApp.setActivationPolicy(.accessory)
        diagLog("activation policy set to accessory")

        statusBar = StatusBarController(store: store, history: history)
        diagLog("StatusBarController created")

        overlay = OverlayWindowController(store: store, history: history)
        mcObserver = MissionControlObserver()

        mcObserver.onActivate = { [weak self] in
            DispatchQueue.main.async { self?.overlay.show() }
        }
        mcObserver.onDeactivate = { [weak self] in
            DispatchQueue.main.async { self?.overlay.hide() }
        }
        diagLog("applicationDidFinishLaunching DONE")
    }

    func applicationWillTerminate(_ notification: Notification) {
        overlay?.hide()
    }
}
