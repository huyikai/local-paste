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

    func captureCurrentContent() -> ClipboardItem? {
        let (dataMap, typeOrder) = pasteboard.readAllTypes()
        guard !dataMap.isEmpty else { return nil }

        // Guard against our own writes
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

    /// Cache of the most recently seen frontmost app. Bundle ID is the
    /// stable identity; if it hasn't changed since the last capture we
    /// reuse the cached name + PNG so a 0.5 s capture poll doesn't redo
    /// the NSImage rendering on every tick.
    private struct FrontmostAppCache {
        let bundleID: String
        let name: String?
        let iconData: Data?
    }
    private var frontmostCache: FrontmostAppCache?

    private func frontmostAppInfo() -> (String?, Data?) {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return (nil, nil)
        }
        if let cached = frontmostCache, cached.bundleID == app.bundleIdentifier {
            return (cached.name, cached.iconData)
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
        frontmostCache = FrontmostAppCache(bundleID: app.bundleIdentifier ?? "",
                                            name: name, iconData: iconData)
        return (name, iconData)
    }
}
