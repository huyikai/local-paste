import Foundation

/// Persists clipboard history to a local JSON file.
/// Binary chunks larger than `externalizeThreshold` are written to separate
/// files in a sibling `files/` directory; the JSON stores a reference
/// (filename) instead of the inline bytes. This keeps history.json small
/// (KBs instead of tens of MBs) so saving stays fast even with large images
/// in the history.
final class HistoryStore {

    // MARK: - Constants

    /// Data chunks at or above this size are stored as external files
    /// instead of inline Base64 in history.json.
    static let externalizeThreshold = 256 * 1024

    private static let filesDirName = "files"

    // MARK: - Codable wrapper

    private struct StorableItem: Codable {
        let id: UUID
        let timestamp: Date
        /// Inline data chunks (below threshold). Externalized chunks appear
        /// here as empty placeholder Data.
        let data: [String: Data]
        /// UTI → external filename for chunks stored in files/.
        /// Legacy files lack this key; decode it as empty instead of failing.
        var fileRefs: [String: String]
        let typeOrder: [String]
        let appName: String?
        let appIconData: Data?
        let pinGroup: String?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            timestamp = try container.decode(Date.self, forKey: .timestamp)
            data = try container.decode([String: Data].self, forKey: .data)
            fileRefs = try container.decodeIfPresent([String: String].self, forKey: .fileRefs) ?? [:]
            typeOrder = try container.decode([String].self, forKey: .typeOrder)
            appName = try container.decodeIfPresent(String.self, forKey: .appName)
            appIconData = try container.decodeIfPresent(Data.self, forKey: .appIconData)
            pinGroup = try container.decodeIfPresent(String.self, forKey: .pinGroup)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(timestamp, forKey: .timestamp)
            try container.encode(data, forKey: .data)
            try container.encode(fileRefs, forKey: .fileRefs)
            try container.encode(typeOrder, forKey: .typeOrder)
            try container.encode(appName, forKey: .appName)
            try container.encode(appIconData, forKey: .appIconData)
            try container.encode(pinGroup, forKey: .pinGroup)
        }

        private enum CodingKeys: String, CodingKey {
            case id, timestamp, data, fileRefs, typeOrder, appName, appIconData, pinGroup
        }

        init(from item: ClipboardItem, externalize: [String: String]) {
            self.id = item.id
            self.timestamp = item.timestamp
            // Externalized chunks become empty placeholders so the JSON
            // stays small; the bytes live in files/.
            var data = item.data
            for uti in externalize.keys {
                data[uti] = Data()
            }
            self.data = data
            self.fileRefs = externalize
            self.typeOrder = item.typeOrder
            self.appName = item.appName
            self.appIconData = item.appIconData
            self.pinGroup = item.pinGroup
        }

        /// All-inline variant (export format: bytes carried in the JSON so
        /// the file is portable on its own).
        init(inlining item: ClipboardItem) {
            self.id = item.id
            self.timestamp = item.timestamp
            self.data = item.data
            self.fileRefs = [:]
            self.typeOrder = item.typeOrder
            self.appName = item.appName
            self.appIconData = item.appIconData
            self.pinGroup = item.pinGroup
        }

        func toClipboardItem(resolving refs: [String: String], in dir: URL) -> ClipboardItem {
            var data = self.data
            for (uti, filename) in refs {
                guard let bytes = try? Data(contentsOf: dir.appendingPathComponent(filename)) else {
                    continue
                }
                data[uti] = bytes
            }
            return ClipboardItem(
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
    private let filesDir: URL
    let maxItems: Int
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    /// True when the last load() hit a decode error. While set, save() is
    /// a no-op so a corrupt/undecodable history file can never be silently
    /// overwritten with an empty list.
    private(set) var loadFailed = false

    /// The file size of the history database in bytes, or 0 if unavailable.
    var storageSizeBytes: Int {
        let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        return (attrs?[.size] as? Int) ?? 0
    }

    /// Human-readable storage size string (JSON + external files).
    var storageSizeString: String {
        var total = storageSizeBytes
        if let files = try? FileManager.default.contentsOfDirectory(
            at: filesDir, includingPropertiesForKeys: [.fileSizeKey]) {
            for file in files {
                total += (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            }
        }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(total))
    }

    // MARK: - Init

    /// Init with optional custom storage URL (for testing).
    init(maxItems: Int = 200, storageURL: URL? = nil) {
        self.maxItems = maxItems

        let appDir: URL
        if let storageURL = storageURL {
            fileURL = storageURL
            appDir = storageURL.deletingLastPathComponent()
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
                                                       in: .userDomainMask).first!
            appDir = appSupport.appendingPathComponent("LocalPaste", isDirectory: true)

            do {
                try FileManager.default.createDirectory(at: appDir,
                                                         withIntermediateDirectories: true,
                                                         attributes: nil)
            } catch {
                print("HistoryStore: failed to create app support directory: \(error)")
            }

            fileURL = appDir.appendingPathComponent("history.json")
        }

        filesDir = appDir.appendingPathComponent(Self.filesDirName, isDirectory: true)
        try? FileManager.default.createDirectory(at: filesDir,
                                                  withIntermediateDirectories: true,
                                                  attributes: nil)

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
    }

    // MARK: - Read / Write

    /// Load history from disk, resolving external file references.
    /// A legacy all-inline file (no fileRefs keys) with chunks above the
    /// threshold is migrated automatically on first load.
    func load() -> [ClipboardItem] {
        guard let data = try? Data(contentsOf: fileURL) else {
            loadFailed = false   // no file yet — normal first run
            return []
        }

        do {
            var storableItems = try decoder.decode([StorableItem].self, from: data)
            loadFailed = false
            if isLegacyFormat(storableItems) {
                migrateToExternalChunks(storableItems)
                // Re-read the migrated file so items resolve their chunks
                let migrated = try Data(contentsOf: fileURL)
                storableItems = try decoder.decode([StorableItem].self, from: migrated)
            }
            var items = storableItems.map {
                $0.toClipboardItem(resolving: $0.fileRefs, in: filesDir)
            }
            // Sort by timestamp descending
            items.sort { $0.timestamp > $1.timestamp }

            return items
        } catch {
            loadFailed = true
            print("HistoryStore: failed to load history from \(fileURL.path): \(error)")
            return []
        }
    }

    /// Legacy = any chunk over the threshold still inlined (no fileRefs).
    private func isLegacyFormat(_ items: [StorableItem]) -> Bool {
        items.contains { item in
            item.fileRefs.isEmpty && item.data.values.contains { $0.count >= Self.externalizeThreshold }
        }
    }

    /// One-time rewrite: back up the current file, externalize big chunks.
    private func migrateToExternalChunks(_ items: [StorableItem]) {
        let backupURL = fileURL.appendingPathExtension("pre-migration.bak")
        if !FileManager.default.fileExists(atPath: backupURL.path) {
            do {
                try FileManager.default.copyItem(at: fileURL, to: backupURL)
            } catch {
                print("HistoryStore: migration backup failed, skipping migration: \(error)")
                return
            }
        }
        let clipboardItems = items.map {
            $0.toClipboardItem(resolving: [:], in: filesDir)
        }
        save(clipboardItems)
        print("HistoryStore: migrated \(clipboardItems.count) items to external-chunk format")
    }

    /// Save history to disk, capping at the given limit. Chunks at or above
    /// the threshold are written to files/ and referenced from the JSON.
    /// The previous on-disk items are used to delete orphaned external files
    /// for items that are no longer kept.
    func save(_ items: [ClipboardItem], limit: Int? = nil) {
        guard !loadFailed else {
            print("HistoryStore: refusing to save — history file failed to load (would overwrite existing data)")
            return
        }
        let cap = limit ?? maxItems
        let limited = Array(items.prefix(cap))
        let previousRefs = currentOnDiskRefs()

        var newRefs: [String: Ref] = [:]   // filename -> uti+id (all kept items)
        var storableItems: [StorableItem] = []

        for item in limited {
            var external: [String: String] = [:]
            for (uti, chunk) in item.data where chunk.count >= Self.externalizeThreshold {
                let filename: String
                if let existing = previousRefs.first(where: { $0.value.uti == uti && $0.value.id == item.id })?.key {
                    filename = existing
                } else {
                    filename = "\(item.id.uuidString)-\(sanitize(uti)).bin"
                }
                let fileURL = filesDir.appendingPathComponent(filename)
                if !FileManager.default.fileExists(atPath: fileURL.path) {
                    do {
                        try chunk.write(to: fileURL, options: [.atomic])
                    } catch {
                        print("HistoryStore: failed to write external chunk \(filename): \(error)")
                        continue
                    }
                }
                external[uti] = filename
                newRefs[filename] = (uti: uti, id: item.id)
            }
            storableItems.append(StorableItem(from: item, externalize: external))
        }

        // Remove files no longer referenced by any kept item
        for (filename, _) in previousRefs where newRefs[filename] == nil {
            try? FileManager.default.removeItem(at: filesDir.appendingPathComponent(filename))
        }

        do {
            let data = try encoder.encode(storableItems)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("HistoryStore: failed to save \(limited.count) items to \(fileURL.path): \(error)")
        }
    }

    // MARK: - Migration & orphan cleanup

    /// Delete the pre-migration backup once the new format has proven itself
    /// (backups younger than a day are kept — the migration may have happened
    /// moments ago during this same launch's load()).
    func removeMigrationBackupIfPresent() {
        let backupURL = fileURL.appendingPathExtension("pre-migration.bak")
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: backupURL.path),
              let modified = attrs[.modificationDate] as? Date else {
            return
        }
        guard Date().timeIntervalSince(modified) > 86400 else { return }
        try? FileManager.default.removeItem(at: backupURL)
    }

    /// Delete external files that no item references (crash/bug leftovers).
    func sweepOrphanedFiles(currentItems: [ClipboardItem]) {
        let referenced = Set(currentItems.flatMap { item in
            item.data.compactMap { uti, chunk in
                chunk.count >= Self.externalizeThreshold ? key(for: item.id, uti: uti) : nil
            }
        })
        guard let files = try? FileManager.default.contentsOfDirectory(at: filesDir, includingPropertiesForKeys: nil) else {
            return
        }
        for file in files where !referenced.contains(file.lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    // MARK: - Export / Import

    /// Serialize items to JSON data for export. External references are
    /// inlined back so the output stays a single portable file identical to
    /// the legacy format.
    func exportJSON(_ items: [ClipboardItem]) -> Data? {
        let storableItems = items.map { StorableItem(inlining: $0) }
        return try? encoder.encode(storableItems)
    }

    /// Deserialize JSON data into clipboard items (e.g. from an imported
    /// file). Accepts both the legacy all-inline format and the new format
    /// with fileRefs; new-format chunks without an external file degrade to
    /// empty data (the JSON is portable, the files/ dir is not exported).
    func importJSON(from data: Data) -> [ClipboardItem]? {
        do {
            let storableItems = try decoder.decode([StorableItem].self, from: data)
            return storableItems.map {
                $0.toClipboardItem(resolving: $0.fileRefs, in: filesDir)
            }
        } catch {
            print("HistoryStore: failed to import JSON: \(error)")
            return nil
        }
    }

    // MARK: - Private helpers

    private typealias Ref = (uti: String, id: UUID)

    /// Filename -> (uti, item id) for chunks currently on disk per history.json.
    private func currentOnDiskRefs() -> [String: Ref] {
        guard let data = try? Data(contentsOf: fileURL),
              let storableItems = try? decoder.decode([StorableItem].self, from: data)
        else { return [:] }
        var refs: [String: Ref] = [:]
        for item in storableItems {
            for (uti, filename) in item.fileRefs {
                refs[filename] = (uti, item.id)
            }
        }
        return refs
    }

    private func key(for id: UUID, uti: String) -> String {
        "\(id.uuidString)-\(sanitize(uti)).bin"
    }

    private func sanitize(_ uti: String) -> String {
        String(uti.map { ($0.isLetter || $0.isNumber || $0 == "." || $0 == "-") ? $0 : "_" })
    }
}
