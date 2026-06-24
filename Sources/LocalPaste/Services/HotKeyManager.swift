import Carbon

/// Manages a global hotkey using the Carbon Event Manager API.
/// This is the standard approach for registering system-wide hotkeys on macOS.
///
/// The chosen shortcut is **⌥⌘V** (Option + Command + V).
final class HotKeyManager {

    // MARK: - Properties

    /// The hotkey id used in the Carbon Event Manager.
    private let hotKeyId = EventHotKeyID(signature: 0x4C5054, id: 1) // "LPT"

    /// The registered hotkey reference (nil if not registered).
    private var hotKeyRef: EventHotKeyRef?

    /// Callback invoked when the hotkey is pressed.
    var onHotKeyPressed: (() -> Void)?

    // MARK: - Registration

    /// Register the global hotkey ⌥⌘V.
    func register() -> Bool {
        // ⌘ (command) = cmdKey, ⌥ (option) = optionKey
        // V = kVK_ANSI_V (9)
        let modifiers: UInt32 = UInt32(cmdKey) | UInt32(optionKey)
        let keyCode = UInt32(kVK_ANSI_V)

        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyId,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr else {
            print("Failed to register hotkey: \(status)")
            return false
        }

        // Install the event handler
        installEventHandler()

        return true
    }

    /// Unregister the hotkey.
    func unregister() {
        guard let ref = hotKeyRef else { return }
        UnregisterEventHotKey(ref)
        hotKeyRef = nil
    }

    // MARK: - Event Handler

    private func installEventHandler() {
        // The event type for hotkey presses
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                       eventKind: UInt32(kEventHotKeyPressed))

        // Install a handler on the application event target
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.onHotKeyPressed?()
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            nil
        )
    }

    // MARK: - Cleanup

    deinit {
        unregister()
    }
}
