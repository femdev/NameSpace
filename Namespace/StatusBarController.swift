// The menu-bar UI hub. Owns the NSStatusItem, shows the current Space name as its title,
// and builds the dropdown menu (rename / clear / switch-to / setup help / about / quit).
// Refreshes itself on activeSpaceDidChangeNotification. Delegates real work to SpaceStore,
// SpaceCatalog, and SpaceSwitcher — it doesn't do CGS or AppleScript itself.

import AppKit
import SwiftUI
import Carbon.HIToolbox // kVK_LeftArrow, controlKey, optionKey for the global hotkey

final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let store: SpaceStore
    private let history: SpaceHistory
    private let permissions: PermissionsMonitor
    private let openPermissions: () -> Void
    private var popover: NSPopover?
    private var backHotKey: GlobalHotKey?
    private let aboutWindow = AboutWindowController()

    init(store: SpaceStore,
         history: SpaceHistory,
         permissions: PermissionsMonitor,
         openPermissions: @escaping () -> Void) {
        self.store = store
        self.history = history
        self.permissions = permissions
        self.openPermissions = openPermissions
        diagLog("[Namespace] StatusBarController.init creating statusItem")
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        diagLog("[Namespace] statusItem created: \(self.statusItem), button: \(String(describing: self.statusItem.button))")
        super.init()
        // Seed history with the Space we launch on so the first move has a "back" target.
        history.record(SpaceCatalog.currentSpaceID())
        configureButton()
        rebuildMenu()
        registerBackHotKey()
        // Rebuild the menu whenever a permission flips, so its status line stays accurate.
        permissions.onChange = { [weak self] _ in self?.refresh() }
        // If a switch is attempted without Accessibility, surface the Setup window (with its
        // Grant button) instead of spamming the system prompt + an alert on every press.
        SpaceSwitcher.onAccessibilityMissing = { [openPermissions] in openPermissions() }
        diagLog("[Namespace] StatusBarController.init DONE")
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(spaceChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }

    /// Ctrl+Opt+Left toggles to the previous Space, system-wide. If the OS refuses the
    /// chord (already claimed), the "Back" menu item still works.
    private func registerBackHotKey() {
        backHotKey = GlobalHotKey(
            keyCode: UInt32(kVK_LeftArrow),
            modifiers: UInt32(controlKey | optionKey)
        ) { [weak self] in
            DispatchQueue.main.async { self?.goBack() }
        }
        if backHotKey == nil {
            diagLog("[Namespace] could not register ⌃⌥← global hotkey (already in use?)")
        }
    }

    func refresh() {
        configureButton()
        rebuildMenu()
    }

    private func configureButton() {
        guard let button = statusItem.button else {
            diagLog("[Namespace] configureButton: statusItem.button is NIL — cannot show")
            return
        }
        let name = currentDisplayName()
        // Menu-bar title is just the Space name; the stacked-squares SF Symbol (a
        // template image that adapts to the menu-bar appearance) is the glyph.
        button.title = name
        if let img = NSImage(systemSymbolName: "square.stack.3d.up", accessibilityDescription: "Spaces") {
            button.image = img
            button.imagePosition = .imageLeading
        } else {
            diagLog("[Namespace] SF Symbol 'square.stack.3d.up' not available; using text-only title")
        }
        diagLog("[Namespace] configureButton set title='\(button.title)' image=\(String(describing: button.image))")
    }

    private func currentDisplayName() -> String {
        if let uuid = SpaceCatalog.currentSpaceUUID() {
            return store.displayName(forUUID: uuid)
        }
        return "Space ?"
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        // Setup banner — only present while something still needs attention (permissions
        // or the auto-rearrange setting).
        if permissions.summary.needsAttention {
            let warn = NSMenuItem(title: "⚠️ Setup needed to switch Spaces", action: nil, keyEquivalent: "")
            warn.isEnabled = false
            menu.addItem(warn)
            let setup = NSMenuItem(
                title: "Finish setup…",
                action: #selector(setUpPermissions),
                keyEquivalent: ""
            )
            setup.target = self
            menu.addItem(setup)
            menu.addItem(.separator())
        }

        let currentUUID = SpaceCatalog.currentSpaceUUID()
        let currentName = currentUUID.map { store.displayName(forUUID: $0) } ?? "(unknown)"

        let header = NSMenuItem(title: "Current: \(currentName)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        menu.addItem(.separator())

        let renameItem = NSMenuItem(
            title: "Rename this Space…",
            action: #selector(renameRequested),
            keyEquivalent: "r"
        )
        renameItem.target = self
        renameItem.isEnabled = currentUUID != nil
        menu.addItem(renameItem)

        let clearItem = NSMenuItem(
            title: "Clear name for this Space",
            action: #selector(clearRequested),
            keyEquivalent: ""
        )
        clearItem.target = self
        clearItem.isEnabled = currentUUID.flatMap { store.name(forUUID: $0) } != nil
        menu.addItem(clearItem)

        menu.addItem(.separator())

        // "Back" toggles to the previously-active Space. Shows ⌃⌥← as its key
        // equivalent to match the global hotkey (cosmetic here — the accessory app
        // has no key window, so the real trigger is the Carbon hotkey).
        let backTitle = history.back.map { "Back to \(displayName(forID64: $0))" } ?? "Back"
        let backItem = NSMenuItem(
            title: backTitle,
            action: #selector(backRequested),
            keyEquivalent: String(utf16CodeUnits: [unichar(NSLeftArrowFunctionKey)], count: 1)
        )
        backItem.keyEquivalentModifierMask = [.control, .option]
        backItem.target = self
        backItem.isEnabled = history.back != nil
        menu.addItem(backItem)

        menu.addItem(.separator())

        let spaces = SpaceCatalog.currentDisplaySpaces()
        if !spaces.isEmpty {
            let listHeader = NSMenuItem(title: "All Spaces (in order)", action: nil, keyEquivalent: "")
            listHeader.isEnabled = false
            menu.addItem(listHeader)
            for space in spaces {
                let item = NSMenuItem(
                    title: store.displayName(forUUID: space.uuid),
                    action: #selector(switchRequested(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = space.id64
                if space.uuid == currentUUID { item.state = .on }
                menu.addItem(item)
            }
            menu.addItem(.separator())
        }

        let aboutItem = NSMenuItem(
            title: "About Namespace",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        let setupItem = NSMenuItem(title: "Setup Help", action: nil, keyEquivalent: "")
        let setupMenu = NSMenu()

        let kbItem = NSMenuItem(
            title: "Enable Ctrl+N direct jumps…",
            action: #selector(openKeyboardShortcuts),
            keyEquivalent: ""
        )
        kbItem.target = self
        kbItem.toolTip = "Opens Keyboard Shortcuts → Mission Control. Tick \"Switch to Desktop 1…9\" "
            + "so Namespace can jump directly without cycling through intermediate spaces."
        setupMenu.addItem(kbItem)

        let axItem = NSMenuItem(
            title: "Grant Accessibility permission…",
            action: #selector(openAccessibility),
            keyEquivalent: ""
        )
        axItem.target = self
        axItem.toolTip = "Opens Privacy & Security → Accessibility. Required so Namespace "
            + "can send the keystrokes that switch spaces."
        setupMenu.addItem(axItem)

        let autoItem = NSMenuItem(
            title: "Grant Automation permission…",
            action: #selector(openAutomation),
            keyEquivalent: ""
        )
        autoItem.target = self
        autoItem.toolTip = "Opens Privacy & Security → Automation. Required so Namespace "
            + "can ask System Events to send keystrokes."
        setupMenu.addItem(autoItem)

        let rearrangeItem = NSMenuItem(
            title: "Turn off auto-rearrange Spaces…",
            action: #selector(turnOffAutoRearrange),
            keyEquivalent: ""
        )
        rearrangeItem.target = self
        rearrangeItem.toolTip = "Turns off \"Automatically rearrange Spaces based on most "
            + "recent use\" and restarts the Dock. That setting reorders Spaces and makes "
            + "switching land on the wrong one."
        setupMenu.addItem(rearrangeItem)

        setupItem.submenu = setupMenu
        menu.addItem(setupItem)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit Namespace",
            action: #selector(NSApp.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quit)
        statusItem.menu = menu
    }

    @objc private func showAbout() {
        aboutWindow.show()
    }

    @objc private func openKeyboardShortcuts() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.keyboard?Shortcuts") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openAccessibility() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openAutomation() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func setUpPermissions() {
        openPermissions()
    }

    @objc private func turnOffAutoRearrange() {
        PermissionsMonitor.disableSpacesRearrange()
    }

    @objc private func spaceChanged() {
        // Record the new active Space for "Back" (fly-overs during our own switches are
        // suppressed inside SpaceHistory), then update the title/menu.
        history.record(SpaceCatalog.currentSpaceID())
        refresh()
    }

    /// The display name for a live Space id64, via its UUID. Falls back to "Space ?"
    /// if the id is no longer in the current display's Space list.
    private func displayName(forID64 id64: UInt64) -> String {
        guard let uuid = SpaceCatalog.currentDisplaySpaces().first(where: { $0.id64 == id64 })?.uuid
        else { return "Space ?" }
        return store.displayName(forUUID: uuid)
    }

    /// Toggle to the previous Space (menu item + global hotkey both call this).
    @objc private func backRequested() { goBack() }

    private func goBack() {
        guard let target = history.back else {
            diagLog("[Namespace] goBack: no previous space recorded")
            return
        }
        diagLog("[Namespace] goBack: switching to previous space id=\(target)")
        history.beginProgrammaticSwitch(to: target)
        SpaceSwitcher.switchTo(spaceID: target)
    }

    @objc private func renameRequested() {
        guard let button = statusItem.button,
              let uuid = SpaceCatalog.currentSpaceUUID() else { return }
        let pop = NSPopover()
        pop.behavior = .transient
        let initial = store.name(forUUID: uuid) ?? ""
        let view = RenamePopover(
            initial: initial,
            onSave: { [weak self] name in
                self?.store.setName(name, forUUID: uuid)
                self?.refresh()
                pop.performClose(nil)
            },
            onCancel: { pop.performClose(nil) }
        )
        pop.contentViewController = NSHostingController(rootView: view)
        pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        self.popover = pop
    }

    @objc private func clearRequested() {
        guard let uuid = SpaceCatalog.currentSpaceUUID() else { return }
        store.setName(nil, forUUID: uuid)
        refresh()
    }

    @objc private func switchRequested(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UInt64 else { return }
        history.beginProgrammaticSwitch(to: id)
        SpaceSwitcher.switchTo(spaceID: id)
    }
}
