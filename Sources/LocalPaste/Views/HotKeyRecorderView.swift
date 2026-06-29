import SwiftUI
import Carbon

/// A SwiftUI component that records a keyboard shortcut.
/// Click to enter recording mode, then press the desired key combination.
struct HotKeyRecorderView: View {
    let currentDescription: String
    let onRecord: (UInt32, UInt32) -> Void

    @State private var isRecording = false

    /// We need a reference type because NSEvent.addLocalMonitorForEvents
    /// captures the closure strongly, and SwiftUI View is a value type.
    /// The coordinator owns the monitor and can be invalidated.
    @State private var coordinator = Coordinator()

    var body: some View {
        Button(action: { startRecording() }) {
            HStack(spacing: 4) {
                if isRecording {
                    Text(loc("hotkey.recording"))
                        .font(.caption)
                        .foregroundColor(.accentColor)
                } else {
                    // Parse the description into modifier tokens + key
                    let tokens = parseShortcut(currentDescription)
                    ForEach(0..<tokens.count, id: \.self) { i in
                        Text(tokens[i])
                            .font(.system(size: 11, weight: tokens[i].count == 1 ? .regular : .semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(.controlBackgroundColor))
                            .cornerRadius(4)
                    }
                }
            }
            .frame(minWidth: 80)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isRecording ? Color.accentColor : Color(.separatorColor), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        guard !isRecording else { return }
        isRecording = true

        let onRecord = self.onRecord
        let coordinator = self.coordinator

        coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // If recording was cancelled by parent, stop
            guard coordinator.isActive else {
                NSEvent.removeMonitor(coordinator.monitor!)
                coordinator.monitor = nil
                return event
            }

            let mods = event.modifierFlags
            let keyCode = UInt32(event.keyCode)

            // Ignore modifier keys themselves
            let modifierKeyCodes: Set<UInt32> = [
                UInt32(kVK_Command), UInt32(kVK_Option), UInt32(kVK_Control),
                UInt32(kVK_RightCommand), UInt32(kVK_RightOption), UInt32(kVK_RightControl),
                UInt32(kVK_Shift), UInt32(kVK_RightShift), UInt32(kVK_CapsLock),
                UInt32(kVK_Function),
            ]

            guard !modifierKeyCodes.contains(keyCode) else {
                return nil // consume modifier-only presses
            }

            // Build Carbon modifiers from NSEvent modifier flags
            var carbonMods: UInt32 = 0
            if mods.contains(.command) { carbonMods |= UInt32(cmdKey) }
            if mods.contains(.option)  { carbonMods |= UInt32(optionKey) }
            if mods.contains(.control) { carbonMods |= UInt32(controlKey) }
            if mods.contains(.shift)   { carbonMods |= UInt32(shiftKey) }

            // Require at least one modifier
            guard carbonMods != 0 else {
                return nil // consume but don't record
            }

            // Clean up, reset UI state, and callback
            stopRecording()
            onRecord(keyCode, carbonMods)
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        coordinator.isActive = false
        if let monitor = coordinator.monitor {
            NSEvent.removeMonitor(monitor)
            coordinator.monitor = nil
        }
    }

    /// Parse "⌥⌘V" style string into ["⌥", "⌘", "V"]
    private func parseShortcut(_ desc: String) -> [String] {
        var result: [String] = []
        for char in desc {
            let s = String(char)
            if "⌘⌥⌃⇧".contains(s) {
                result.append(s)
            }
        }
        let modifierSet = CharacterSet(charactersIn: "⌘⌥⌃⇧")
        let keyPart = desc.trimmingCharacters(in: modifierSet)
        if !keyPart.isEmpty {
            result.append(keyPart)
        }
        return result
    }
}

// MARK: - Coordinator

extension HotKeyRecorderView {
    final class Coordinator {
        var monitor: Any?
        var isActive = true
    }
}
