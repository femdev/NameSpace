// Detects Mission Control opening/closing via DistributedNotificationCenter (undocumented
// "com.apple.expose.*" notifications) and fires onActivate / onDeactivate callbacks, which
// the AppDelegate uses to show/hide the label overlay.

import Foundation

final class MissionControlObserver {
    var onActivate: (() -> Void)?
    var onDeactivate: (() -> Void)?

    private let dnc = DistributedNotificationCenter.default()
    private let activateNames = [
        "com.apple.expose.front.awake",
        "com.apple.exposeDidActivate"
    ]
    private let deactivateNames = [
        "com.apple.expose.afterburner.done",
        "com.apple.exposeDidDeactivate"
    ]

    init() {
        for name in activateNames {
            dnc.addObserver(
                self,
                selector: #selector(activated),
                name: Notification.Name(name),
                object: nil
            )
        }
        for name in deactivateNames {
            dnc.addObserver(
                self,
                selector: #selector(deactivated),
                name: Notification.Name(name),
                object: nil
            )
        }
    }

    deinit { dnc.removeObserver(self) }

    @objc private func activated() { onActivate?() }
    @objc private func deactivated() { onDeactivate?() }
}
