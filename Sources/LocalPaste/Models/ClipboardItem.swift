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

    /// Display-ready NSColor for swatch rendering.
    /// Detects color from NSColor data OR from hex text like "#FF6B35".
    var displayColor: NSColor? {
        if let c = color { return c }
        if let text = plainText?.trimmingCharacters(in: .whitespacesAndNewlines) {
            return NSColor.fromHex(text)
        }
        return nil
    }

    /// Hex string for color display.
    var colorHex: String {
        if let c = displayColor {
            let r = Int(round(c.redComponent * 255))
            let g = Int(round(c.greenComponent * 255))
            let b = Int(round(c.blueComponent * 255))
            return String(format: "#%02X%02X%02X", r, g, b)
        }
        return "[Color]"
    }

    /// Returns a short textual summary for the list display
    var displayText: String {
        if let text = plainText {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ")
        }
        if image != nil { return "[Image]" }
        if fileURLs != nil { return "[Files]" }
        if color != nil { return colorHex }
        if rtfData != nil { return "[Rich Text]" }
        return "[Clipboard Data (\(data.count) types)]"
    }

    /// Rendered rich-text preview (HTML or RTF), if available.
    /// Font is normalized to a uniform size for list consistency.
    var attributedPreview: AttributedString? {
        if let html = htmlData,
           let nsAttr = try? NSAttributedString(
               data: html,
               options: [.documentType: NSAttributedString.DocumentType.html,
                         .characterEncoding: String.Encoding.utf8.rawValue],
               documentAttributes: nil
           ) {
            var attr = AttributedString(nsAttr)
            attr.font = .system(size: 13)
            return attr
        }
        if let rtf = rtfData,
           let nsAttr = try? NSAttributedString(
               data: rtf,
               options: [.documentType: NSAttributedString.DocumentType.rtf,
                         .characterEncoding: String.Encoding.utf8.rawValue],
               documentAttributes: nil
           ) {
            var attr = AttributedString(nsAttr)
            attr.font = .system(size: 13)
            return attr
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

// MARK: - NSColor hex parsing

private extension NSColor {
    /// Parse hex color strings like "#FF6B35", "#fff", "FF6B35"
    static func fromHex(_ hex: String) -> NSColor? {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }

        let r, g, b: CGFloat
        switch s.count {
        case 3:
            guard let ri = Int(s.prefix(1), radix: 16), let gi = Int(s.dropFirst().prefix(1), radix: 16),
                  let bi = Int(s.suffix(1), radix: 16) else { return nil }
            r = CGFloat(ri * 17) / 255; g = CGFloat(gi * 17) / 255; b = CGFloat(bi * 17) / 255
        case 6:
            guard let ri = Int(s.prefix(2), radix: 16), let gi = Int(s.dropFirst(2).prefix(2), radix: 16),
                  let bi = Int(s.suffix(2), radix: 16) else { return nil }
            r = CGFloat(ri) / 255; g = CGFloat(gi) / 255; b = CGFloat(bi) / 255
        default:
            return nil
        }
        return NSColor(red: r, green: g, blue: b, alpha: 1.0)
    }
}
