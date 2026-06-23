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

        let (name, iconData) = frontmostAppInfo()

        let item = ClipboardItem(
            id: UUID(),
            timestamp: Date(),
            data: dataMap,
            appName: appName ?? name,
            appIconData: iconData,
            isPinned: false
        )
        return item
    }

    /// Force-read the pasteboard regardless of change tracking.
    func forceCapture() -> ClipboardItem? {
        let dataMap = pasteboard.readAllTypes()
        guard !dataMap.isEmpty else { return nil }

        let (name, iconData) = frontmostAppInfo()

        return ClipboardItem(
            id: UUID(),
            timestamp: Date(),
            data: dataMap,
            appName: name,
            appIconData: iconData,
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
        frontmostAppInfo().0
    }

    /// Capture the frontmost application name and icon PNG data.
    private func frontmostAppInfo() -> (String?, Data?) {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return (nil, nil)
        }
        let name = app.localizedName
        let iconData = app.icon.flatMap { icon in
            // Render a 16x16 version for list display
            let smallIcon = NSImage(size: NSSize(width: 16, height: 16))
            smallIcon.lockFocus()
            icon.draw(in: NSRect(x: 0, y: 0, width: 16, height: 16),
                      from: .zero, operation: .copy, fraction: 1.0)
            smallIcon.unlockFocus()
            return smallIcon.tiffRepresentation
        }
        return (name, iconData)
    }
}
