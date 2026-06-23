import AppKit
import UniformTypeIdentifiers

/// Manages reading from and writing to the system pasteboard.
/// Provides high-level methods for capturing clipboard contents into
/// ClipboardItem models and restoring them.
final class PasteboardManager {

    /// The pasteboard we monitor (general pasteboard).
    private let pasteboard = NSPasteboard.general

    /// The last known changeCount — used to detect changes.
    private(set) var lastChangeCount: Int

    init() {
        lastChangeCount = pasteboard.changeCount
    }

    // MARK: - Detection

    /// Returns `true` if the pasteboard contents have changed since we last checked.
    var hasChanged: Bool {
        let current = pasteboard.changeCount
        if current != lastChangeCount {
            lastChangeCount = current
            return true
        }
        return false
    }

    /// Force-reset the change tracking. Useful after we've consumed a change.
    func resetChangeCount() {
        lastChangeCount = pasteboard.changeCount
    }

    // MARK: - Reading

    /// Read the current pasteboard contents and create a ClipboardItem.
    func captureCurrentContent(appName: String? = nil) -> ClipboardItem? {
        let dataMap = pasteboard.readAllTypes()
        guard !dataMap.isEmpty else { return nil }

        // Ignore our own writes — if only our app's internal type is present, skip
        if dataMap.keys.allSatisfy({ $0.hasPrefix("com.localpaste.") }) {
            return nil
        }

        let item = ClipboardItem(
            id: UUID(),
            timestamp: Date(),
            data: dataMap,
            appName: appName ?? getFrontmostAppName(),
            isPinned: false
        )
        return item
    }

    /// Force-read the pasteboard regardless of change tracking.
    func forceCapture() -> ClipboardItem? {
        let dataMap = pasteboard.readAllTypes()
        guard !dataMap.isEmpty else { return nil }

        return ClipboardItem(
            id: UUID(),
            timestamp: Date(),
            data: dataMap,
            appName: getFrontmostAppName(),
            isPinned: false
        )
    }

    // MARK: - Writing

    /// Write a ClipboardItem back to the system pasteboard, restoring all
    /// original formats so the target app receives the richest representation.
    func copyToPasteboard(_ item: ClipboardItem) {
        pasteboard.writeAllTypes(item.data)

        // Update our tracking so we don't immediately re-capture our own write
        lastChangeCount = pasteboard.changeCount
    }

    /// Write a dictionary of UTI → Data directly to the pasteboard.
    func writeData(_ dataMap: [String: Data]) {
        pasteboard.writeAllTypes(dataMap)
        lastChangeCount = pasteboard.changeCount
    }

    // MARK: - Helpers

    /// Get the name of the currently frontmost (active) application.
    private func getFrontmostAppName() -> String? {
        NSWorkspace.shared.frontmostApplication?.localizedName
    }
}
