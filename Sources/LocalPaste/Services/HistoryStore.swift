import Foundation

/// Persists clipboard history to a local JSON file.
/// Uses Codable with a wrapper struct to handle the [String: Data] dictionary.
final class HistoryStore {

    // MARK: - Codable wrapper

    private struct StorableItem: Codable {
        let id: UUID
        let timestamp: Date
        let data: [String: Data]
        let typeOrder: [String]
        let appName: String?
        let appIconData: Data?
        let pinGroup: String?

        init(from item: ClipboardItem) {
            self.id = item.id
            self.timestamp = item.timestamp
            self.data = item.data
            self.typeOrder = item.typeOrder
            self.appName = item.appName
            self.appIconData = item.appIconData
            self.pinGroup = item.pinGroup
        }

        func toClipboardItem() -> ClipboardItem {
            ClipboardItem(
                id: id,
                timestamp: timestamp,
                data: data,
                typeOrder: typeOrder,
                appName: appName,
                appIconData: appIconData,
                pinGroup: pinGroup
            )
        }
    }

    // MARK: - Properties

    private let fileURL: URL
    let maxItems: Int
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// The file size of the history database in bytes, or 0 if unavailable.
    var storageSizeBytes: Int {
        let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        return (attrs?[.size] as? Int) ?? 0
    }

    /// Human-readable storage size string.
    var storageSizeString: String {
        let bytes = storageSizeBytes
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    // MARK: - Init

    /// Init with optional custom storage URL (for testing).
    init(maxItems: Int = 200, storageURL: URL? = nil) {
        self.maxItems = maxItems

        if let storageURL = storageURL {
            self.fileURL = storageURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
                                                       in: .userDomainMask).first!
            let appDir = appSupport.appendingPathComponent("LocalPaste", isDirectory: true)

            // Create directory if needed
            do {
                try FileManager.default.createDirectory(at: appDir,
                                                         withIntermediateDirectories: true,
                                                         attributes: nil)
            } catch {
                print("HistoryStore: failed to create app support directory: \(error)")
            }

            self.fileURL = appDir.appendingPathComponent("history.json")
        }

        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        self.decoder = JSONDecoder()
    }

    // MARK: - Read / Write

    /// Load history from disk.
    func load() -> [ClipboardItem] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }

        do {
            let storableItems = try decoder.decode([StorableItem].self, from: data)
            var items = storableItems.map { $0.toClipboardItem() }
            // Sort by timestamp descending
            items.sort { $0.timestamp > $1.timestamp }

            return items
        } catch {
            print("HistoryStore: failed to load history from \(fileURL.path): \(error)")
            return []
        }
    }

    /// Save history to disk, capping at the given limit.
    func save(_ items: [ClipboardItem], limit: Int? = nil) {
        let cap = limit ?? maxItems
        let limited = Array(items.prefix(cap))
        let storableItems = limited.map { StorableItem(from: $0) }

        do {
            let data = try encoder.encode(storableItems)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("HistoryStore: failed to save \(limited.count) items to \(fileURL.path): \(error)")
        }
    }

    // MARK: - Export / Import

    /// Serialize items to JSON data for export.
    func exportJSON(_ items: [ClipboardItem]) -> Data? {
        let storableItems = items.map { StorableItem(from: $0) }
        return try? encoder.encode(storableItems)
    }

    /// Deserialize JSON data into clipboard items (e.g. from an imported file).
    /// Returns nil if the data is invalid.
    func importJSON(from data: Data) -> [ClipboardItem]? {
        do {
            let storableItems = try decoder.decode([StorableItem].self, from: data)
            return storableItems.map { $0.toClipboardItem() }
        } catch {
            print("HistoryStore: failed to import JSON: \(error)")
            return nil
        }
    }
}
