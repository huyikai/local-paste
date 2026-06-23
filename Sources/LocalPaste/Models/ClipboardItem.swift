import Foundation
import AppKit
import UniformTypeIdentifiers

/// Represents a single clipboard entry with all its pasteboard types preserved.
struct ClipboardItem: Identifiable, Hashable {
    let id: UUID
    var timestamp: Date
    /// Raw pasteboard data keyed by UTI string — preserves all formats.
    let data: [String: Data]
    /// The application name that provided the content (if available).
    let appName: String?
    /// The source application icon as PNG data (if available).
    let appIconData: Data?
    /// Whether the user has pinned this item.
    var isPinned: Bool

    var appIcon: NSImage? {
        guard let data = appIconData else { return nil }
        return NSImage(data: data)
    }

    // MARK: - Convenience accessors

    var plainText: String? {
        guard let data = data[UTType.utf8PlainText.identifier] ?? data[UTType.plainText.identifier],
              let str = String(data: data, encoding: .utf8)
        else { return nil }
        return str
    }

    var rtfData: Data? {
        data[UTType.rtf.identifier]
    }

    var htmlData: Data? {
        data[UTType.html.identifier]
    }

    var image: NSImage? {
        for uti in [UTType.png, UTType.tiff, UTType.jpeg, UTType.gif] {
            if let d = data[uti.identifier], let img = NSImage(data: d) {
                return img
            }
        }
        return nil
    }

    var fileURLs: [URL]? {
        guard let data = data[UTType.fileURL.identifier] ?? data["NSFilenamesPboardType"] else {
            return nil
        }
        // File URLs can be stored as plist array of strings or as file URL data
        if let urls = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, NSString.self, NSURL.self],
                                                               from: data) as? [URL] {
            return urls
        }
        if let urlStr = String(data: data, encoding: .utf8), let url = URL(string: urlStr) {
            return [url]
        }
        return nil
    }

    var color: NSColor? {
        guard let data = data["com.apple.cocoa.pasteboard.color"] else {
            return nil
        }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
    }

    /// Returns a short textual summary for the list display
    var displayText: String {
        if let text = plainText {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ")
        }
        if image != nil {
            return "[Image]"
        }
        if fileURLs != nil {
            return "[Files]"
        }
        if color != nil {
            return "[Color]"
        }
        if rtfData != nil {
            return "[Rich Text]"
        }
        return "[Clipboard Data (\(data.count) types)]"
    }

    var contentTypeIcon: String {
        if data.keys.contains(where: { PasteboardTypes.imageTypes.contains($0) }) { return "photo" }
        if data.keys.contains(where: { $0 == UTType.fileURL.identifier || $0 == "NSFilenamesPboardType" }) { return "doc" }
        if data.keys.contains("com.apple.cocoa.pasteboard.color") { return "paintpalette" }
        return "text.alignleft"
    }

    // MARK: - Search

    func matches(query: String) -> Bool {
        let q = query.lowercased()
        if let text = plainText, text.lowercased().contains(q) { return true }
        if contentTypeIcon.lowercased().contains(q) { return true }
        return false
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
    }
}
