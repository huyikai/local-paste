import Carbon

/// Manages a global hotkey using the Carbon Event Manager API.
/// This is the standard approach for registering system-wide hotkeys on macOS.
///
/// The default shortcut is **⌥⌘V** (Option + Command + V).
/// Users can customize it via the Settings panel.
final class HotKeyManager {

    // MARK: - UserDefaults keys

    private static let udModifiers = "com.localpaste.hotKeyModifiers"
    private static let udKeyCode = "com.localpaste.hotKeyKeyCode"

    /// The default hotkey ⌥⌘V.
    static let defaultModifiers: UInt32 = UInt32(cmdKey) | UInt32(optionKey)
    static let defaultKeyCode: UInt32 = UInt32(kVK_ANSI_V)

    // MARK: - Properties

    /// The hotkey id used in the Carbon Event Manager.
    private let hotKeyId = EventHotKeyID(signature: 0x4C5054, id: 1) // "LPT"

    /// The registered hotkey reference (nil if not registered).
    private var hotKeyRef: EventHotKeyRef?

    /// Callback invoked when the hotkey is pressed.
    var onHotKeyPressed: (() -> Void)?

    /// Whether the Carbon event handler has been installed.
    private var eventHandlerInstalled = false

    // MARK: - Registration

    /// Register with the user's saved hotkey (or default ⌥⌘V).
    @discardableResult
    func register() -> Bool {
        let mods = savedModifiers()
        let code = savedKeyCode()
        return register(keyCode: code, modifiers: mods)
    }

    /// Register a specific key combination.
    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32) -> Bool {
        // Unregister any existing registration first
        unregister()

        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyId,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr else {
            print("HotKeyManager: failed to register hotkey (keyCode=\(keyCode), modifiers=\(modifiers)) — Carbon error \(status). Another app may have registered this shortcut.")
            return false
        }

        // Install the event handler (only once)
        installEventHandler()

        return true
    }

    /// Reload the hotkey from saved preferences (called after user changes it).
    @discardableResult
    func reload() -> Bool {
        let mods = savedModifiers()
        let code = savedKeyCode()
        return register(keyCode: code, modifiers: mods)
    }

    /// Unregister the hotkey.
    func unregister() {
        guard let ref = hotKeyRef else { return }
        UnregisterEventHotKey(ref)
        hotKeyRef = nil
    }

    // MARK: - Persistence

    /// Save the current hotkey to UserDefaults.
    func save(keyCode: UInt32, modifiers: UInt32) {
        UserDefaults.standard.set(Int(keyCode), forKey: Self.udKeyCode)
        UserDefaults.standard.set(Int(modifiers), forKey: Self.udModifiers)
    }

    /// Read the saved modifiers (or default).
    func savedModifiers() -> UInt32 {
        let raw = UserDefaults.standard.integer(forKey: Self.udModifiers)
        return raw > 0 ? UInt32(raw) : Self.defaultModifiers
    }

    /// Read the saved key code (or default).
    func savedKeyCode() -> UInt32 {
        let raw = UserDefaults.standard.integer(forKey: Self.udKeyCode)
        return raw > 0 ? UInt32(raw) : Self.defaultKeyCode
    }

    /// Human-readable description of the current hotkey.
    var currentDescription: String {
        let mods = savedModifiers()
        let code = savedKeyCode()

        var parts: [String] = []
        if mods & UInt32(cmdKey) != 0 { parts.append("⌘") }
        if mods & UInt32(optionKey) != 0 { parts.append("⌥") }
        if mods & UInt32(controlKey) != 0 { parts.append("⌃") }
        if mods & UInt32(shiftKey) != 0 { parts.append("⇧") }

        // Map common key codes to readable names
        let keyNames: [UInt32: String] = [
            UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B", UInt32(kVK_ANSI_C): "C",
            UInt32(kVK_ANSI_D): "D", UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F",
            UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H", UInt32(kVK_ANSI_I): "I",
            UInt32(kVK_ANSI_J): "J", UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
            UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N", UInt32(kVK_ANSI_O): "O",
            UInt32(kVK_ANSI_P): "P", UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R",
            UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T", UInt32(kVK_ANSI_U): "U",
            UInt32(kVK_ANSI_V): "V", UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
            UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z",
            UInt32(kVK_ANSI_0): "0", UInt32(kVK_ANSI_1): "1", UInt32(kVK_ANSI_2): "2",
            UInt32(kVK_ANSI_3): "3", UInt32(kVK_ANSI_4): "4", UInt32(kVK_ANSI_5): "5",
            UInt32(kVK_ANSI_6): "6", UInt32(kVK_ANSI_7): "7", UInt32(kVK_ANSI_8): "8",
            UInt32(kVK_ANSI_9): "9",
            UInt32(kVK_ANSI_Grave): "`", UInt32(kVK_ANSI_Minus): "-",
            UInt32(kVK_ANSI_Equal): "=", UInt32(kVK_ANSI_LeftBracket): "[",
            UInt32(kVK_ANSI_RightBracket): "]", UInt32(kVK_ANSI_Backslash): "\\",
            UInt32(kVK_ANSI_Semicolon): ";", UInt32(kVK_ANSI_Quote): "'",
            UInt32(kVK_ANSI_Comma): ",", UInt32(kVK_ANSI_Period): ".",
            UInt32(kVK_ANSI_Slash): "/",
            UInt32(kVK_F1): "F1", UInt32(kVK_F2): "F2", UInt32(kVK_F3): "F3",
            UInt32(kVK_F4): "F4", UInt32(kVK_F5): "F5", UInt32(kVK_F6): "F6",
            UInt32(kVK_F7): "F7", UInt32(kVK_F8): "F8", UInt32(kVK_F9): "F9",
            UInt32(kVK_F10): "F10", UInt32(kVK_F11): "F11", UInt32(kVK_F12): "F12",
            UInt32(kVK_Space): "Space", UInt32(kVK_Return): "Return",
            UInt32(kVK_Tab): "Tab", UInt32(kVK_Delete): "Delete",
            UInt32(kVK_Escape): "Esc",
            UInt32(kVK_UpArrow): "↑", UInt32(kVK_DownArrow): "↓",
            UInt32(kVK_LeftArrow): "←", UInt32(kVK_RightArrow): "→",
        ]

        let keyName = keyNames[code] ?? "?"
        parts.append(keyName)
        return parts.joined()
    }

    // MARK: - Event Handler

    private func installEventHandler() {
        guard !eventHandlerInstalled else { return }
        eventHandlerInstalled = true

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
