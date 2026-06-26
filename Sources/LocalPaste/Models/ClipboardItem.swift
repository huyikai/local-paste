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
        // Only parse hex colors when the string starts with # (e.g. "#fff", "#FF6B35").
        // Plain numbers like "123" should NOT be treated as colors.
        if let text = plainText?.trimmingCharacters(in: .whitespacesAndNewlines),
           text.hasPrefix("#") {
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
        return loc("item.color")
    }

    /// Returns a short textual summary for the list display
    var displayText: String {
        if let text = plainText {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ")
        }
        if image != nil { return loc("item.image") }
        if fileURLs != nil { return loc("item.files") }
        if color != nil { return colorHex }
        if rtfData != nil { return loc("item.rich.text") }
        return loc("item.clipboard.data", data.count)
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

    // MARK: - Detail metadata

    /// Image format name extracted from the UTI key.
    private var imageFormatName: String? {
        if data.keys.contains(PasteboardTypes.png) { return "PNG" }
        if data.keys.contains(PasteboardTypes.jpeg) { return "JPEG" }
        if data.keys.contains(PasteboardTypes.gif) { return "GIF" }
        if data.keys.contains(PasteboardTypes.tiff) { return "TIFF" }
        if data.keys.contains(PasteboardTypes.pdf) { return "PDF" }
        return nil
    }

    /// Image pixel size, if available.
    private var imageSize: NSSize? {
        guard let rep = image?.representations.first else { return nil }
        // NSImageRep has pixelsWide/pixelsHigh which give actual pixel dimensions
        let w = rep.pixelsWide > 0 ? rep.pixelsWide : Int(rep.size.width)
        let h = rep.pixelsHigh > 0 ? rep.pixelsHigh : Int(rep.size.height)
        guard w > 0, h > 0 else { return nil }
        return NSSize(width: w, height: h)
    }

    /// Human-readable detail string for the item's content.
    var detailInfo: String {
        // Color items
        if color != nil {
            let hex = colorHex
            let ns = color ?? displayColor
            let r = Int(round((ns?.redComponent ?? 0) * 255))
            let g = Int(round((ns?.greenComponent ?? 0) * 255))
            let b = Int(round((ns?.blueComponent ?? 0) * 255))
            return "\(hex)  ·  RGB(\(r), \(g), \(b))"
        }
        // Image items
        if let img = image, let fmt = imageFormatName {
            let sizeStr: String
            if let px = imageSize {
                sizeStr = "\(Int(px.width))×\(Int(px.height))"
            } else {
                sizeStr = "\(Int(img.size.width))×\(Int(img.size.height))"
            }
            let dataSize = data.compactMap { key, val in
                PasteboardTypes.imageTypes.contains(key) ? val : nil
            }.first?.count ?? 0
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            let size = formatter.string(fromByteCount: Int64(dataSize))
            return "\(sizeStr)  ·  \(fmt)  ·  \(size)"
        }
        // File items
        if let urls = fileURLs {
            let count = urls.count
            let totalSize = urls.reduce(0) { sum, url in
                let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
                return sum + ((attrs?[.size] as? Int) ?? 0)
            }
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            let size = formatter.string(fromByteCount: Int64(totalSize))
            let firstName = urls.first?.lastPathComponent ?? ""
            if count == 1 {
                return "\(firstName)  ·  \(size)"
            }
            return loc("detail.files.count", count, size, firstName)
        }
        // Text items
        if let text = plainText {
            let chars = text.count
            let words = text.split(whereSeparator: \.isWhitespace).count
            let lines = text.split(separator: "\n").count
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            let size = formatter.string(fromByteCount: Int64(text.lengthOfBytes(using: .utf8)))
            return loc("detail.text.info", chars, words, lines, size)
        }
        // Fallback
        return loc("item.clipboard.data", data.count)
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
