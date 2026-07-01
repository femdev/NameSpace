// A single system-wide hotkey via Carbon's RegisterEventHotKey. Fires regardless of
// which app is frontmost. We use Carbon rather than an NSEvent global monitor because a
// monitor can only *observe* a chord, not claim it, and this is the standard mechanism
// for a real global shortcut. No extra entitlement is needed; the app already requires
// Accessibility for the switch keystrokes.
//
// Lifetime: keep a strong reference to the instance for as long as the hotkey should be
// active. `deinit` unregisters both the hotkey and its event handler.

import AppKit
import Carbon.HIToolbox

final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let onPress: () -> Void

    /// - Parameters:
    ///   - keyCode: a Carbon virtual key code (e.g. `kVK_LeftArrow`).
    ///   - modifiers: a Carbon modifier mask (e.g. `controlKey | optionKey`).
    ///   - onPress: invoked on the main thread each time the chord is pressed.
    /// Returns nil if the OS refuses the registration (e.g. the chord is already taken).
    init?(keyCode: UInt32, modifiers: UInt32, onPress: @escaping () -> Void) {
        self.onPress = onPress

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData -> OSStatus in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                hotKey.onPress()
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &handlerRef
        )
        guard installStatus == noErr else { return nil }

        // Signature "SNMR" (Namespace) + id 1 uniquely identify our one hotkey.
        let hotKeyID = EventHotKeyID(signature: OSType(0x534E_4D52), id: 1)
        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard registerStatus == noErr else {
            if let handlerRef { RemoveEventHandler(handlerRef) }
            return nil
        }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
