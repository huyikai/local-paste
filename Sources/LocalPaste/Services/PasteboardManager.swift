import AppKit
import UniformTypeIdentifiers

/// Manages reading from and writing to the system pasteboard.
final class PasteboardManager {

    private let pasteboard = NSPasteboard.general
    private(set) var lastChangeCount: Int

    init() {
        lastChangeCount = pasteboard.changeCount
    }

    var hasChanged: Bool {
        let current = pasteboard.changeCount
        if current != lastChangeCount {
            lastChangeCount = current
            return true
        }
        return false
    }

    func resetChangeCount() {
        lastChangeCount = pasteboard.changeCount
    }

    // MARK: - Reading

    func captureCurrentContent(appName: String? = nil) -> ClipboardItem? {
        let (dataMap, typeOrder) = pasteboard.readAllTypes()
        guard !dataMap.isEmpty else { return nil }

        if dataMap.keys.allSatisfy({ $0.hasPrefix("com.localpaste.") }) {
            return nil
        }

        let (name, iconData) = frontmostAppInfo()

        return ClipboardItem(
            id: UUID(),
            timestamp: Date(),
            data: dataMap,
            typeOrder: typeOrder,
            appName: appName ?? name,
            appIconData: iconData,
            pinGroup: nil
        )
    }

    func forceCapture() -> ClipboardItem? {
        let (dataMap, typeOrder) = pasteboard.readAllTypes()
        guard !dataMap.isEmpty else { return nil }

        // Also guard against our own writes
        if dataMap.keys.allSatisfy({ $0.hasPrefix("com.localpaste.") }) {
            return nil
        }

        let (name, iconData) = frontmostAppInfo()

        return ClipboardItem(
            id: UUID(),
            timestamp: Date(),
            data: dataMap,
            typeOrder: typeOrder,
            appName: name,
            appIconData: iconData,
            pinGroup: nil
        )
    }

    // MARK: - Writing

    func copyToPasteboard(_ item: ClipboardItem) {
        pasteboard.writeAllTypes(dataMap: item.data, order: item.typeOrder)
        lastChangeCount = pasteboard.changeCount
    }

    func writeData(_ dataMap: [String: Data], order: [String] = []) {
        pasteboard.writeAllTypes(dataMap: dataMap, order: order)
        lastChangeCount = pasteboard.changeCount
    }

    // MARK: - Helpers

    private func frontmostAppInfo() -> (String?, Data?) {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return (nil, nil)
        }
        let name = app.localizedName
        let iconData: Data? = {
            guard let icon = app.icon else { return nil }
            let resized = NSImage(size: NSSize(width: 64, height: 64))
            resized.lockFocus()
            icon.draw(in: NSRect(x: 0, y: 0, width: 64, height: 64),
                      from: .zero, operation: .copy, fraction: 1.0)
            resized.unlockFocus()
            guard let tiff = resized.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
            return bitmap.representation(using: .png, properties: [:])
        }()
        return (name, iconData)
    }
}
