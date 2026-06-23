import Foundation

/// Persists clipboard history to a local JSON file.
/// Uses Codable with a wrapper struct to handle the [String: Data] dictionary.
final class HistoryStore {

    // MARK: - Codable wrapper

    private struct StorableItem: Codable {
        let id: UUID
        let timestamp: Date
        let data: [String: Data]
        let appName: String?
        let appIconData: Data?
        let isPinned: Bool

        init(from item: ClipboardItem) {
            self.id = item.id
            self.timestamp = item.timestamp
            self.data = item.data
            self.appName = item.appName
            self.appIconData = item.appIconData
            self.isPinned = item.isPinned
        }

        func toClipboardItem() -> ClipboardItem {
            ClipboardItem(
                id: id,
                timestamp: timestamp,
                data: data,
                appName: appName,
                appIconData: appIconData,
                isPinned: isPinned
            )
        }
    }

    // MARK: - Properties

    private let fileURL: URL
    private let maxItems: Int
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

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
            try? FileManager.default.createDirectory(at: appDir,
                                                      withIntermediateDirectories: true,
                                                      attributes: nil)

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

            // Sort: pinned items first, then by timestamp descending
            items.sort { a, b in
                if a.isPinned != b.isPinned {
                    return a.isPinned && !b.isPinned
                }
                return a.timestamp > b.timestamp
            }

            return items
        } catch {
            print("Failed to load history: \(error)")
            return []
        }
    }

    /// Save history to disk.
    func save(_ items: [ClipboardItem]) {
        let limited = Array(items.prefix(maxItems))
        let storableItems = limited.map { StorableItem(from: $0) }

        do {
            let data = try encoder.encode(storableItems)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("Failed to save history: \(error)")
        }
    }
}
