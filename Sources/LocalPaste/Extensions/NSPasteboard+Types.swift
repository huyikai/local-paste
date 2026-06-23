import AppKit
import UniformTypeIdentifiers

// MARK: - Common UTI strings used with NSPasteboard

/// Common pasteboard type identifiers used across the app.
/// This avoids repeated string literals and provides a central place for
/// the pasteboard type constants we care about.
enum PasteboardTypes {
    // Standard text types
    static let plainText     = "public.utf8-plain-text"
    static let rtf           = "public.rtf"
    static let rtfd          = "com.appwork.flat-rtfd"
    static let html          = "public.html"

    // Image types
    static let png           = "public.png"
    static let tiff          = "public.tiff"
    static let jpeg          = "public.jpeg"
    static let gif           = "public.gif"
    static let pdf           = "com.adobe.pdf"

    // File / URL types
    static let fileURL       = "public.file-url"
    static let filenames     = "NSFilenamesPboardType"
    static let url           = "public.url"

    // Other types
    static let color         = "com.apple.cocoa.pasteboard.color"
    static let multipleTextSelection = "com.apple.cocoa.pasteboard.multiple-text-selection"
    static let findPanel     = "com.apple.cocoa.pasteboard.find-panel"

    /// The complete list of text-like types we search first
    static let textTypes: [String] = [
        plainText,
        rtf,
        rtfd,
        html,
        multipleTextSelection,
    ]

    /// The complete list of image types
    static let imageTypes: [String] = [
        png, tiff, jpeg, gif, pdf,
    ]

    /// All interesting types for full capture
    static let allCaptureTypes: [String] = {
        var types = textTypes + imageTypes
        types.append(contentsOf: [fileURL, filenames, url, color, findPanel])
        return types
    }()
}

// MARK: - NSPasteboard convenience

extension NSPasteboard {

    /// Read all available data types from the pasteboard and return as a
    /// dictionary of [UTI-string : Data]. This preserves every format so
    /// we can write it all back later.
    func readAllTypes() -> [String: Data] {
        guard let types = pasteboardItems?.first?.types ?? self.types else {
            return [:]
        }

        var result: [String: Data] = [:]
        for type in types {
            let uti = type.rawValue
            if let data = data(forType: type) {
                result[uti] = data
            }
        }
        return result
    }

    /// Write a dictionary of [UTI-string : Data] back to the pasteboard.
    /// This restores the clipboard entry with all its original formats.
    func writeAllTypes(_ dataMap: [String: Data]) {
        clearContents()
        let items = [NSPasteboardItem()]
        for (uti, data) in dataMap {
            let type = NSPasteboard.PasteboardType(uti)
            items[0].setData(data, forType: type)
        }
        writeObjects(items)
    }

    /// Returns a simple string representation from the pasteboard
    /// for search indexing purposes.
    func readableString() -> String? {
        // Try plain text first
        if let str = string(forType: .string) {
            return str
        }
        // Fall back to any text-like type
        for typeKey in PasteboardTypes.textTypes {
            let type = NSPasteboard.PasteboardType(typeKey)
            if let data = data(forType: type),
               let str = String(data: data, encoding: .utf8) {
                return str
            }
        }
        return nil
    }
}
