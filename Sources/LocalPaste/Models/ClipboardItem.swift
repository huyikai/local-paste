import Foundation
import AppKit
import UniformTypeIdentifiers

/// Represents a single clipboard entry with all its pasteboard types preserved.
struct ClipboardItem: Identifiable, Hashable {
    let id: UUID
    var timestamp: Date
    /// Raw pasteboard data keyed by UTI string — preserves all formats.
    let data: [String: Data]
    /// Original order of UTI types on the pasteboard (richest first).
    /// Preserved so the receiving app picks the best available format.
    let typeOrder: [String]
    /// The application name that provided the content (if available).
    let appName: String?
    /// The source application icon as PNG data (if available).
    let appIconData: Data?
    /// Which pin group this item belongs to (nil = not pinned).
    var pinGroup: String?

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
        guard let data = data[UTType.fileURL.identifier] ?? data[PasteboardTypes.filenames] else {
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
        guard let data = data[PasteboardTypes.color] else {
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

    /// Rendered rich-text preview (HTML or RTF), if available.
    var attributedPreview: AttributedString? {
        if let html = htmlData,
           let nsAttr = try? NSAttributedString(
               data: html,
               options: [.documentType: NSAttributedString.DocumentType.html,
                         .characterEncoding: String.Encoding.utf8.rawValue],
               documentAttributes: nil
           ) {
            return AttributedString(nsAttr)
        }
        if let rtf = rtfData,
           let nsAttr = try? NSAttributedString(
               data: rtf,
               options: [.documentType: NSAttributedString.DocumentType.rtf,
                         .characterEncoding: String.Encoding.utf8.rawValue],
               documentAttributes: nil
           ) {
            return AttributedString(nsAttr)
        }
        return nil
    }

    var contentTypeIcon: String {
        if data.keys.contains(where: { PasteboardTypes.imageTypes.contains($0) }) { return "photo" }
        if data.keys.contains(where: { $0 == UTType.fileURL.identifier || $0 == PasteboardTypes.filenames }) { return "doc" }
        if data.keys.contains(PasteboardTypes.color) { return "paintpalette" }
        return "text.alignleft"
    }

    // MARK: - Search

    func matches(query: String) -> Bool {
        let q = query.lowercased()
        if let text = plainText, text.lowercased().contains(q) { return true }
        if contentTypeIcon.lowercased().contains(q) { return true }
        if let g = pinGroup, g.lowercased().contains(q) { return true }
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
