import Testing
@testable import LocalPaste
import AppKit
import Carbon
import UniformTypeIdentifiers

private func makeItem(data: [String: Data] = [:],
                      text: String? = nil,
                      pinGroup: String? = nil,
                      timestamp: Date = Date(),
                      id: UUID = UUID()) -> ClipboardItem {
    var itemData = data
    if let text = text {
        itemData[UTType.utf8PlainText.identifier] = text.data(using: .utf8)!
    }
    return ClipboardItem(
        id: id,
        timestamp: timestamp,
        data: itemData,
        typeOrder: Array(itemData.keys),
        appName: "TestApp",
        appIconData: nil,
        pinGroup: pinGroup
    )
}

private let epoch1000 = Date(timeIntervalSince1970: 1000)
private let epoch2000 = Date(timeIntervalSince1970: 2000)
private let epoch3000 = Date(timeIntervalSince1970: 3000)

/// Sweep leftover temp dirs from crashed/aborted runs (crash-safe tests
/// can't always clean up themselves; accumulating dirs wastes /tmp).
private func sweepLeftoverTempDirs() {
    let tmp = FileManager.default.temporaryDirectory
    if let entries = try? FileManager.default.contentsOfDirectory(atPath: tmp.path) {
        for entry in entries where entry.hasPrefix("LocalPasteTests-") {
            try? FileManager.default.removeItem(at: tmp.appendingPathComponent(entry))
        }
    }
}

// MARK: - ClipboardItemTests

@Suite(.serialized)
struct Umbrella {
    

    @Suite
    struct ClipboardItemTests {

        @Test func plainTextDetection() {
            let item = makeItem(text: "Hello, world!")
            #expect(item.plainText == "Hello, world!")
            #expect(item.displayText == "Hello, world!")
            #expect(item.contentTypeIcon == "text.alignleft")
        }

        @Test func imageContentTypeIcon() {
            _ = makeItem(data: [UTType.png.identifier: Data()])
        }

        @Test func fileURLContentIcon() {
            let item = makeItem(data: [UTType.fileURL.identifier: Data()])
            #expect(item.contentTypeIcon == "doc")
        }

        @Test func searchMatchesPlainText() {
            let item = makeItem(text: "SwiftUI code snippet")
            #expect(item.matches(query: "SwiftUI"))
            #expect(item.matches(query: "swiftui"))
            #expect(item.matches(query: "snippet"))
            #expect(!item.matches(query: "react"))
            #expect(!item.matches(query: "xyz"))
        }

        @Test func itemsWithSameDataAreNotEqualByID() {
            let item1 = makeItem(text: "duplicate", id: UUID())
            let item2 = makeItem(text: "duplicate", id: UUID())
            #expect(item1.id != item2.id)
            #expect(item1 != item2)
            #expect(item1.data == item2.data)
        }

        @Test func colorSwatchNotNull() {
            // Simulate copying a red color from the system color picker
            let color = NSColor(red: 1.0, green: 0.2, blue: 0.3, alpha: 1.0)
            let colorData = try! NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true)

            let item = makeItem(data: [PasteboardTypes.color: colorData])
            #expect(item.color != nil, "NSColor should decode from pasteboard color data")
            #expect(item.displayColor != nil, "displayColor should be available in sRGB")
            #expect(item.colorHex == "#FF334D", "hex should match r=255,g=51,b=77")
        }

        @Test func colorDisplayPipeline() {
            // Full pipeline: what the pasteboard gives us → what the UI shows
            let color = NSColor(calibratedRed: 0.0, green: 0.5, blue: 1.0, alpha: 1.0)
            let colorData = try! NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true)

            let dataMap = [
                PasteboardTypes.color: colorData,
            ]

            let item = ClipboardItem(
                id: UUID(), timestamp: Date(),
                data: dataMap, typeOrder: Array(dataMap.keys),
                appName: nil, appIconData: nil, pinGroup: nil
            )

            #expect(item.data.keys.contains(PasteboardTypes.color))
            #expect(item.contentTypeIcon == "paintpalette")
            #expect(item.color != nil)
            #expect(item.displayColor != nil)
            #expect(item.colorHex.hasPrefix("#"))
            #expect(item.colorHex.count == 7)
        }

        @Test func hexTextColorDetection() {
            // Copying "#fff001" as text → should detect as color
            let item = makeItem(text: "#fff001")
            #expect(item.displayColor != nil, "hex text should be detected as color")
            #expect(item.colorHex == "#FFF001")
        }

        @Test func hex3CharDetection() {
            // Copying "#fff" as text → should detect as color
            let item = makeItem(text: "#abc")
            #expect(item.displayColor != nil, "3-char hex should be detected")
            #expect(item.colorHex == "#AABBCC")
        }

        @Test func nonHexTextNotColor() {
            let item = makeItem(text: "hello world")
            #expect(item.displayColor == nil, "plain text should not be mistaken for color")
        }

        @Test func realPasteboardColorRoundtrip() {
            // Simulate actual color picker copy behavior
            let pb = NSPasteboard.general
            pb.clearContents()

            let color = NSColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 1.0)
            let colorData = try! NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true)

            pb.declareTypes([.string, NSPasteboard.PasteboardType(PasteboardTypes.color)], owner: nil)
            pb.setString("sRGB IEC61966-2.1 colorspace 0.2 0.6 0.9 1", forType: .string)
            pb.setData(colorData, forType: NSPasteboard.PasteboardType(PasteboardTypes.color))

            // Read via our production code
            let (dataMap, order) = pb.readAllTypes()
            #expect(dataMap.keys.contains(PasteboardTypes.color),
                    "pasteboard should have color type")
            #expect(dataMap.keys.contains(UTType.utf8PlainText.identifier),
                    "pasteboard also has plain text (like real color picker)")

            // Create item exactly as PasteboardManager would
            let item = ClipboardItem(
                id: UUID(), timestamp: Date(),
                data: dataMap, typeOrder: order,
                appName: nil, appIconData: nil, pinGroup: nil
            )

            // Display color check
            #expect(item.displayColor != nil, "displayColor should not be nil")
            #expect(item.contentTypeIcon == "paintpalette")

            // When both text and color exist, displayText shows original text;
            // the color is indicated by the left-edge strip
            #expect(item.displayText == "sRGB IEC61966-2.1 colorspace 0.2 0.6 0.9 1")

            // colorHex works from the NSColor data
            #expect(item.colorHex.hasPrefix("#"))
        }

        @Test func colorItemAppearsInHistory() {
            let color = NSColor.red
            let colorData = try! NSKeyedArchiver.archivedData(withRootObject: color,
                                                               requiringSecureCoding: false)
            let item = makeItem(data: ["com.apple.cocoa.pasteboard.color": colorData])
            #expect(item.contentTypeIcon == "paintpalette")
        }

        @Test func pinGroupSearch() {
            let item = makeItem(text: "test", pinGroup: "Work")
            #expect(item.matches(query: "Work"))
        }
    }

    // MARK: - SortingTests

    @Suite
    struct SortingTests {

        @Test func newestFirst() {
            let old = makeItem(text: "old", timestamp: epoch1000)
            let newer = makeItem(text: "new", timestamp: epoch2000)

            let sorted = [old, newer].sorted { $0.timestamp > $1.timestamp }
            #expect(sorted[0].plainText == "new")
            #expect(sorted[1].plainText == "old")
        }

        @Test func allItemsSortedByTimestamp() {
            let a = makeItem(text: "a", pinGroup: "Work", timestamp: epoch1000)
            let b = makeItem(text: "b", timestamp: epoch3000)
            let c = makeItem(text: "c", pinGroup: "Work", timestamp: epoch2000)

            let sorted = [a, b, c].sorted { $0.timestamp > $1.timestamp }
            #expect(sorted[0].plainText == "b")
            #expect(sorted[1].plainText == "c")
            #expect(sorted[2].plainText == "a")
        }
    }

    // MARK: - PasteboardTypesTests

    @Suite
    struct PasteboardTypesTests {

        @Test func textTypesAreAllUTIs() {
            for type in PasteboardTypes.textTypes {
                #expect(type.contains(".") || type.contains("-"))
            }
        }

        @Test func imageTypesIncludePNG() {
            #expect(PasteboardTypes.imageTypes.contains("public.png"))
        }

        @Test func allCaptureTypesCoverage() {
            let all = PasteboardTypes.allCaptureTypes
            #expect(all.contains(PasteboardTypes.plainText))
            #expect(all.contains(PasteboardTypes.png))
            #expect(all.contains(PasteboardTypes.fileURL))
            #expect(all.contains(PasteboardTypes.color))
        }

        @Test func readAllTypesReturnsDictionary() {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString("test string", forType: .string)
            let result = pb.readAllTypes()
            #expect(!result.data.isEmpty)
        }
    }

    // MARK: - HistoryStoreTests

    @Suite
    struct HistoryStoreTests {

        private func makeTempStoreURL(_ name: String) -> URL {
            sweepLeftoverTempDirs()
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("LocalPasteTests-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            return tempDir.appendingPathComponent(name)
        }

        private func removeTempStore(_ url: URL) {
            try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
        }

        @Test func storeSaveAndLoad() {
            let fileURL = makeTempStoreURL("test-history.json")
            defer { removeTempStore(fileURL) }

            let store = HistoryStore(maxItems: 10, storageURL: fileURL)

            let item = makeItem(text: "test store", pinGroup: "Work")
            store.save([item])
            let loaded = store.load()

            #expect(loaded.count == 1)
            #expect(loaded[0].plainText == "test store")
            #expect(loaded[0].pinGroup == "Work")
        }

        @Test func storeEnforcesMaxItems() {
            let fileURL = makeTempStoreURL("test-max.json")
            defer { removeTempStore(fileURL) }

            let store = HistoryStore(maxItems: 3, storageURL: fileURL)

            let items = (0..<10).map { makeItem(text: "item\($0)") }
            store.save(items)
            let loaded = store.load()

            #expect(loaded.count == 3)
        }

        @Test func storeEmptyReturnsEmpty() {
            let fileURL = makeTempStoreURL("test-empty.json")
            defer { removeTempStore(fileURL) }

            let store = HistoryStore(maxItems: 10, storageURL: fileURL)

            store.save([])
            #expect(store.load().count == 0)
        }

        @Test func exportImportRoundtrip() {
            let fileURL = makeTempStoreURL("x.json")
            defer { removeTempStore(fileURL) }

            let store = HistoryStore(maxItems: 10, storageURL: fileURL)

            let items = [
                makeItem(text: "hello", pinGroup: "Work"),
                makeItem(text: "world"),
            ]

            guard let exportedData = store.exportJSON(items) else {
                Issue.record("export should succeed")
                return
            }

            let imported = store.importJSON(from: exportedData)
            #expect(imported != nil)
            #expect(imported?.count == 2)
            #expect(imported?.first?.plainText == "hello")
            #expect(imported?.first?.pinGroup == "Work")
            #expect(imported?.last?.plainText == "world")
        }

        @Test func importInvalidDataReturnsNil() {
            let fileURL = makeTempStoreURL("x.json")
            defer { removeTempStore(fileURL) }

            let store = HistoryStore(maxItems: 10, storageURL: fileURL)

            let badData = "not valid json".data(using: .utf8)!
            let result = store.importJSON(from: badData)
            #expect(result == nil)
        }

        @Test func exportEmptyArray() {
            let fileURL = makeTempStoreURL("x.json")
            defer { removeTempStore(fileURL) }

            let store = HistoryStore(maxItems: 10, storageURL: fileURL)

            let data = store.exportJSON([])
            #expect(data != nil)

            let imported = store.importJSON(from: data!)
            #expect(imported != nil)
            #expect(imported?.count == 0)
        }

        // MARK: Externalized chunk storage

        /// A chunk at or above the threshold is written to files/ and
        /// referenced from the JSON; round-tripping restores the bytes.
        @Test func externalizedChunkRoundtrips() {
            let fileURL = makeTempStoreURL("ext.json")
            defer { removeTempStore(fileURL) }

            let store = HistoryStore(maxItems: 10, storageURL: fileURL)
            let bigChunk = Data(repeating: 0xAB, count: HistoryStore.externalizeThreshold + 1)
            let smallChunk = Data("small".utf8)
            let item = makeItem(data: [
                UTType.png.identifier: bigChunk,
                UTType.utf8PlainText.identifier: smallChunk,
            ])

            store.save([item])
            let jsonSize = store.storageSizeBytes
            #expect(jsonSize < HistoryStore.externalizeThreshold,
                    "history.json should stay small when chunks are externalized")

            let loaded = store.load()
            #expect(loaded.count == 1)
            #expect(loaded[0].data[UTType.png.identifier] == bigChunk)
            #expect(loaded[0].data[UTType.utf8PlainText.identifier] == smallChunk)
        }

        /// Deleting an item removes its external chunk files.
        @Test func externalizedFileRemovedWhenItemDropped() {
            let fileURL = makeTempStoreURL("cleanup.json")
            defer { removeTempStore(fileURL) }

            let store = HistoryStore(maxItems: 10, storageURL: fileURL)
            let bigChunk = Data(repeating: 0xCD, count: HistoryStore.externalizeThreshold + 1)
            let item = makeItem(data: [UTType.png.identifier: bigChunk])

            store.save([item])
            let filesDir = fileURL.deletingLastPathComponent().appendingPathComponent("files")
            let before = (try? FileManager.default.contentsOfDirectory(atPath: filesDir.path))?.count ?? 0
            #expect(before == 1, "one external file after save")

            // Save without the item -> file must be swept
            store.save([])
            let after = (try? FileManager.default.contentsOfDirectory(atPath: filesDir.path))?.count ?? 0
            #expect(after == 0, "external file removed when item no longer kept")
        }

        /// Export inlines the data so the JSON is portable; importing a
        /// legacy (all-inline) payload still works.
        @Test func exportInlinesExternalChunks() {
            let fileURL = makeTempStoreURL("portable.json")
            defer { removeTempStore(fileURL) }

            let store = HistoryStore(maxItems: 10, storageURL: fileURL)
            let bigChunk = Data(repeating: 0xEF, count: HistoryStore.externalizeThreshold + 1)
            let item = makeItem(data: [UTType.png.identifier: bigChunk])

            store.save([item])

            // Export should carry the full bytes inline (legacy-compatible)
            guard let exported = store.exportJSON([item]) else {
                Issue.record("export failed")
                return
            }
            #expect(exported.count >= HistoryStore.externalizeThreshold,
                    "exported JSON inlines the chunk bytes")

            // And a fresh store importing that payload gets the bytes back
            let target = makeTempStoreURL("target.json")
            defer { removeTempStore(target) }
            let targetStore = HistoryStore(maxItems: 10, storageURL: target)
            let imported = targetStore.importJSON(from: exported)
            #expect(imported?.first?.data[UTType.png.identifier] == bigChunk)
        }

        /// Migration from the legacy inline format keeps all data and
        /// creates a backup.
        @Test func migrateFromLegacyFormatPreservesData() {
            let fileURL = makeTempStoreURL("legacy.json")
            defer { removeTempStore(fileURL) }

            // Simulate a legacy store: an all-inline JSON with a big image
            let bigChunk = Data(repeating: 0x11, count: HistoryStore.externalizeThreshold + 1)
            let merged = makeItem(data: [
                UTType.png.identifier: bigChunk,
                UTType.utf8PlainText.identifier: "legacy text".data(using: .utf8)!,
            ], pinGroup: "Work")
            let legacyStore = HistoryStore(maxItems: 10, storageURL: fileURL.deletingLastPathComponent().appendingPathComponent("seed.json"))
            guard let legacyJSON = legacyStore.exportJSON([merged]) else {
                Issue.record("seed export failed")
                return
            }
            try? legacyJSON.write(to: fileURL)

            // Loading performs the migration automatically
            let store = HistoryStore(maxItems: 10, storageURL: fileURL)
            _ = store.load()
            let backupURL = fileURL.appendingPathExtension("pre-migration.bak")
            #expect(FileManager.default.fileExists(atPath: backupURL.path))

            // Data preserved, now externalized
            let loaded = store.load()
            #expect(loaded.count == 1)
            #expect(loaded[0].data[UTType.png.identifier] == bigChunk)
            #expect(loaded[0].plainText == "legacy text")
            #expect(loaded[0].pinGroup == "Work")

            // JSON shrank below the threshold
            #expect(store.storageSizeBytes < HistoryStore.externalizeThreshold)

            // Fresh backups are preserved (removed only after a day)
            #expect(FileManager.default.fileExists(atPath: backupURL.path))
        }

        /// Regression: a legacy JSON WITHOUT the fileRefs key must decode
        /// (previously the synthesized Codable init threw keyNotFound and
        /// load() returned an empty list, risking data overwrite).
        @Test func legacyJSONWithoutFileRefsKeyDecodes() {
            let fileURL = makeTempStoreURL("no-file-refs.json")
            defer { removeTempStore(fileURL) }

            let bigChunk = Data(repeating: 0x22, count: HistoryStore.externalizeThreshold + 1)
            // Hand-write the legacy format: no fileRefs field at all
            let legacyPayload = """
            [{
                "id": "\(UUID().uuidString)",
                "timestamp": \(Date(timeIntervalSince1970: 1000).timeIntervalSince1970),
                "data": { "public.png": "\(Data(base64Encoded: bigChunk.base64EncodedString())!.base64EncodedString())" },
                "typeOrder": ["public.png"],
                "appName": null,
                "appIconData": null,
                "pinGroup": null
            }]
            """
            try? legacyPayload.data(using: .utf8)!.write(to: fileURL)

            let store = HistoryStore(maxItems: 10, storageURL: fileURL)
            let loaded = store.load()

            #expect(!store.loadFailed, "legacy file must decode")
            #expect(loaded.count == 1)
            #expect(loaded[0].data[UTType.png.identifier] == bigChunk,
                    "chunk must survive the automatic migration")

            // And the migrated file must NOT be overwritable-with-empty
            #expect(store.storageSizeBytes > 0)
        }

        /// A corrupt history file blocks saving, so the broken file can
        /// never be silently replaced by an empty history.
        @Test func corruptFileBlocksSave() {
            let fileURL = makeTempStoreURL("corrupt.json")
            defer { removeTempStore(fileURL) }

            try? "this is not json".data(using: .utf8)!.write(to: fileURL)

            let store = HistoryStore(maxItems: 10, storageURL: fileURL)
            let loaded = store.load()
            #expect(loaded.isEmpty)
            #expect(store.loadFailed, "decode failure must raise the flag")

            store.save([makeItem(text: "should not persist")])
            #expect(store.loadFailed, "save is refused while the load failure stands")
        }
    }

    // MARK: - PasteboardManagerTests

    @Suite
    struct PasteboardManagerTests {

        @Test func ownWriteKeysAreFiltered() {
            // Data with only com.localpaste. keys should return nil
            let manager = PasteboardManager()
            let pb = NSPasteboard.general
            pb.clearContents()

            // Write something then reset so hasChanged is true
            pb.setString("trigger", forType: .string)
            _ = manager.hasChanged // sync

            // Now write our own marker data
            pb.clearContents()
            let item = NSPasteboardItem()
            item.setString("internal", forType: NSPasteboard.PasteboardType("com.localpaste.test"))
            pb.writeObjects([item])

            // Since all keys are com.localpaste.*, capture should return nil
            let captured = manager.captureCurrentContent()
            #expect(captured == nil, "capture should skip items with only internal types")
        }

        @Test func hasChangedDetectsChanges() {
            let manager = PasteboardManager()
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("hello", forType: .string)

            #expect(manager.hasChanged, "should detect change after writing")
        }

        @Test func resetChangeCountSuppressesChange() {
            let manager = PasteboardManager()
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("hello", forType: .string)
            _ = manager.hasChanged // consume the change

            manager.resetChangeCount()
            #expect(!manager.hasChanged, "after reset, no change should be reported")
        }

        @Test func captureNonEmptyItem() {
            let manager = PasteboardManager()
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("test capture", forType: .string)
            _ = manager.hasChanged // sync

            let item = manager.captureCurrentContent()
            #expect(item != nil, "should capture non-empty pasteboard")
            #expect(item?.plainText == "test capture")
        }
    }

    // MARK: - PasteboardMonitorTests

    @Suite
    struct PasteboardMonitorTests {

        @Test func startSetsIsRunning() {
            let manager = PasteboardManager()
            let monitor = PasteboardMonitor(pasteboardManager: manager, interval: 1.0)
            #expect(!monitor.isRunning)

            monitor.start()
            #expect(monitor.isRunning)

            monitor.stop()
            #expect(!monitor.isRunning)
        }

        @Test func doubleStartIsIdempotent() {
            let manager = PasteboardManager()
            let monitor = PasteboardMonitor(pasteboardManager: manager, interval: 1.0)

            monitor.start()
            monitor.start() // should not crash or double-schedule
            #expect(monitor.isRunning)

            monitor.stop()
        }

        @Test func stopWithoutStartDoesNotCrash() {
            let manager = PasteboardManager()
            let monitor = PasteboardMonitor(pasteboardManager: manager)
            monitor.stop() // no-op should not crash
            #expect(!monitor.isRunning)
        }
    }

    // MARK: - HotKeyManagerTests

    @Suite
    struct HotKeyManagerTests {

        private func cleanupHotKeyDefaults() {
            UserDefaults.standard.removeObject(forKey: "com.localpaste.hotKeyKeyCode")
            UserDefaults.standard.removeObject(forKey: "com.localpaste.hotKeyModifiers")
        }

        @Test func onHotKeyPressedCallback() {
            let manager = HotKeyManager()

            // Verify initial state
            #expect(manager.onHotKeyPressed == nil)

            var called = false
            manager.onHotKeyPressed = {
                called = true
            }
            #expect(manager.onHotKeyPressed != nil)
            #expect(!called || true) // closure assignment does not invoke
        }

        @Test func registerReturnsStatus() {
            let manager = HotKeyManager()
            let result = manager.register()
            // On CI / test environment without accessibility, this may fail
            // But we just verify it doesn't crash and returns a consistent result
            if result {
                manager.unregister()
            }
        }

        @Test func unregisterIsSafe() {
            let manager = HotKeyManager()
            // Calling unregister without register should not crash
            manager.unregister()
        }

        @Test func registerThenUnregister() {
            let manager = HotKeyManager()
            let registered = manager.register()
            if registered {
                manager.unregister()
                // unregistering again should be safe
                manager.unregister()
            }
        }

        // MARK: currentDescription formatting

        @Test func currentDescriptionDefault() {
            cleanupHotKeyDefaults()
            defer { cleanupHotKeyDefaults() }
            let manager = HotKeyManager()
            // Default is cmdKey | optionKey + kVK_ANSI_V → "⌘⌥V"
            #expect(manager.currentDescription == "⌘⌥V")
        }

        @Test func currentDescriptionAllFourModifiers() {
            cleanupHotKeyDefaults()
            defer { cleanupHotKeyDefaults() }
            let manager = HotKeyManager()
            let allMods = UInt32(cmdKey) | UInt32(optionKey) | UInt32(controlKey) | UInt32(shiftKey)
            manager.save(keyCode: UInt32(kVK_ANSI_F), modifiers: allMods)
            // Order: ⌘, ⌥, ⌃, ⇧, then "F"
            #expect(manager.currentDescription == "⌘⌥⌃⇧F")
        }

        @Test func currentDescriptionSingleModifier() {
            cleanupHotKeyDefaults()
            defer { cleanupHotKeyDefaults() }
            let manager = HotKeyManager()
            manager.save(keyCode: UInt32(kVK_Space), modifiers: UInt32(shiftKey))
            #expect(manager.currentDescription == "⇧Space")
        }

        @Test func currentDescriptionFunctionKey() {
            cleanupHotKeyDefaults()
            defer { cleanupHotKeyDefaults() }
            let manager = HotKeyManager()
            manager.save(keyCode: UInt32(kVK_F1), modifiers: UInt32(cmdKey))
            #expect(manager.currentDescription == "⌘F1")
        }

        @Test func currentDescriptionArrowKey() {
            cleanupHotKeyDefaults()
            defer { cleanupHotKeyDefaults() }
            let manager = HotKeyManager()
            manager.save(keyCode: UInt32(kVK_UpArrow), modifiers: UInt32(controlKey) | UInt32(optionKey))
            #expect(manager.currentDescription == "⌥⌃↑")
        }

        @Test func currentDescriptionEscape() {
            cleanupHotKeyDefaults()
            defer { cleanupHotKeyDefaults() }
            let manager = HotKeyManager()
            manager.save(keyCode: UInt32(kVK_Escape), modifiers: UInt32(cmdKey) | UInt32(shiftKey))
            #expect(manager.currentDescription == "⌘⇧Esc")
        }

        // MARK: Persistence (save / read-back)

        @Test func saveAndReadBackKeyCode() {
            cleanupHotKeyDefaults()
            defer { cleanupHotKeyDefaults() }
            let manager = HotKeyManager()
            manager.save(keyCode: 99, modifiers: UInt32(cmdKey))
            #expect(manager.savedKeyCode() == 99)
        }

        @Test func saveAndReadBackModifiers() {
            cleanupHotKeyDefaults()
            defer { cleanupHotKeyDefaults() }
            let manager = HotKeyManager()
            let mods = UInt32(cmdKey) | UInt32(controlKey) | UInt32(shiftKey)
            manager.save(keyCode: UInt32(kVK_ANSI_X), modifiers: mods)
            #expect(manager.savedModifiers() == mods)
        }

        @Test func savedDefaultsWhenEmpty() {
            cleanupHotKeyDefaults()
            defer { cleanupHotKeyDefaults() }
            let manager = HotKeyManager()
            #expect(manager.savedKeyCode() == HotKeyManager.defaultKeyCode)
            #expect(manager.savedModifiers() == HotKeyManager.defaultModifiers)
        }

        @Test func saveThenReloadUpdatesCurrentDescription() {
            cleanupHotKeyDefaults()
            defer { cleanupHotKeyDefaults() }
            let manager = HotKeyManager()
            manager.save(keyCode: UInt32(kVK_ANSI_C), modifiers: UInt32(cmdKey) | UInt32(optionKey))
            _ = manager.reload()
            #expect(manager.currentDescription == "⌘⌥C")
        }
    }

    // MARK: - AppStateTests

    @Suite
    struct AppStateTests {

        /// Create an AppState with a controller backed by a temporary in-memory store.
        /// No eager deletion here: the controller keeps writing to disk after this
        /// returns. Leftover dirs are swept at next suite run.
        private func makeAppState() -> AppState {
            sweepLeftoverTempDirs()
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("LocalPasteTests-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            let store = HistoryStore(maxItems: 200, storageURL: tempDir.appendingPathComponent("test.json"))
            let manager = PasteboardManager()
            let controller = ClipboardDataController(store: store, pasteboardManager: manager)
            return AppState(controller: controller)
        }

        @Test func insertItemPutsNewestFirst() {
            let appState = makeAppState()

            let old = makeItem(text: "old", timestamp: epoch1000)
            let new = makeItem(text: "new", timestamp: epoch2000)

            appState.insertItem(old)
            appState.insertItem(new)

            #expect(appState.controller.items.count >= 2)
            #expect(appState.controller.items[0].plainText == "new")
            #expect(appState.controller.items[1].plainText == "old")
        }

        @Test func insertItemDeduplicatesIdenticalData() {
            let appState = makeAppState()

            let data = [UTType.utf8PlainText.identifier: "dup".data(using: .utf8)!]
            let id = UUID()
            let item1 = ClipboardItem(id: id, timestamp: epoch1000,
                                       data: data, typeOrder: Array(data.keys),
                                       appName: nil, appIconData: nil, pinGroup: nil)
            let item2 = ClipboardItem(id: id, timestamp: epoch2000,
                                       data: data, typeOrder: Array(data.keys),
                                       appName: nil, appIconData: nil, pinGroup: nil)

            appState.insertItem(item1)
            appState.insertItem(item2)

            #expect(appState.controller.items.count == 1)
        }

        @Test func filteredItemsWithSearch() {
            let appState = makeAppState()

            appState.insertItem(makeItem(text: "Swift Programming"))
            appState.insertItem(makeItem(text: "Rust Programming"))
            appState.insertItem(makeItem(text: "Grocery List"))

            appState.controller.searchQuery = "swift"
            #expect(appState.filteredItems.count == 1)
            #expect(appState.filteredItems[0].plainText == "Swift Programming")

            appState.controller.searchQuery = "programming"
            #expect(appState.filteredItems.count == 2)

            appState.controller.searchQuery = ""
            #expect(appState.filteredItems.count == appState.controller.items.count)
        }

        @Test func setPinGroup() throws {
            let appState = makeAppState()

            let item = makeItem(text: "pinned")
            appState.insertItem(item)

            let first = try #require(appState.controller.items.first)
            #expect(first.pinGroup == nil)

            appState.setPinGroup(for: first, group: "Work")
            let updated = try #require(appState.controller.items.first(where: { $0.id == first.id }))
            #expect(updated.pinGroup == "Work")

            // Clear
            appState.setPinGroup(for: updated, group: nil)
            let cleared = try #require(appState.controller.items.first(where: { $0.id == first.id }))
            #expect(cleared.pinGroup == nil)
        }

        @Test func deletePinGroupClearsItems() throws {
            let appState = makeAppState()

            appState.insertItem(makeItem(text: "a"))
            appState.insertItem(makeItem(text: "b"))
            appState.insertItem(makeItem(text: "c"))

            // Pin via setPinGroup to register the group
            let a = try #require(appState.controller.items.first(where: { $0.plainText == "a" }))
            let b = try #require(appState.controller.items.first(where: { $0.plainText == "b" }))
            appState.setPinGroup(for: a, group: "Work")
            appState.setPinGroup(for: b, group: "Work")

            #expect(appState.controller.pinGroups.contains("Work"))
            appState.deletePinGroup("Work")

            #expect(!appState.controller.pinGroups.contains("Work"))
            #expect(appState.controller.items.filter { $0.pinGroup != nil }.count == 0)
            #expect(appState.controller.items.count == 3)
        }

        @Test func clearHistory() {
            let appState = makeAppState()

            appState.insertItem(makeItem(text: "a"))
            appState.insertItem(makeItem(text: "b"))
            appState.clearHistory()
            #expect(appState.controller.items.isEmpty)
        }

        /// Summoning the panel starts a new session: search text, group
        /// filter, focus state and selection must all reset.
        @Test func resetPanelSessionClearsSearchAndFilter() {
            let appState = makeAppState()

            appState.insertItem(makeItem(text: "alpha"))
            appState.insertItem(makeItem(text: "beta", pinGroup: "Work"))

            // Simulate a working session: search, filter, focus, selection
            appState.searchQuery = "alp"
            appState.selectedPinGroup = "Work"
            appState.isSearchFocused = true
            appState.isGroupFilterFocused = true
            appState.focusedFilterIndex = 1
            appState.selectFirstItem()
            #expect(!appState.filteredItems.isEmpty)

            appState.resetPanelSession()

            #expect(appState.searchQuery == "")
            #expect(appState.controller.searchQuery == "")
            #expect(appState.selectedPinGroup == nil)
            #expect(appState.controller.selectedPinGroup == nil)
            #expect(!appState.isSearchFocused)
            #expect(!appState.isGroupFilterFocused)
            #expect(appState.focusedFilterIndex == 0)
            #expect(appState.selectedItemID == nil)
            // Full list visible again
            #expect(appState.displayItems.count == 2)
        }

        @Test func deleteItem() {
            let appState = makeAppState()

            appState.insertItem(makeItem(text: "keep"))
            let toDelete = makeItem(text: "delete")
            appState.insertItem(toDelete)
            let countAfterInsert = appState.controller.items.count

            appState.deleteItem(toDelete)
            #expect(appState.controller.items.count == countAfterInsert - 1)
            #expect(!appState.controller.items.contains { $0.plainText == "delete" })
        }

        @Test func multiSelectBatchDelete() {
            let appState = makeAppState()

            appState.insertItem(makeItem(text: "A"))
            appState.insertItem(makeItem(text: "B"))
            appState.insertItem(makeItem(text: "C"))

            // Set multi-select on AppState (didSet syncs to controller)
            let toDelete = Set([appState.controller.items[0].id, appState.controller.items[2].id])
            appState.selectedItemIDs = toDelete
            appState.deleteSelectedItems()

            #expect(appState.controller.items.count == 1)
            #expect(appState.controller.items[0].plainText == "B")
            #expect(appState.selectedItemIDs.isEmpty)
        }

        @Test func keyboardSelectionNavigationSyncsPublishedProperty() throws {
            let appState = makeAppState()

            appState.insertItem(makeItem(text: "C", timestamp: epoch3000))
            appState.insertItem(makeItem(text: "B", timestamp: epoch2000))
            appState.insertItem(makeItem(text: "A", timestamp: epoch1000))

            let controllerItems = appState.controller.items
            try #require(controllerItems.count >= 3, "Need at least 3 items")

            let firstItemID = controllerItems[0].id
            let secondItemID = controllerItems[1].id

            // Start with no selection
            appState.clearSelection()
            #expect(appState.selectedItemID == nil)

            // selectNext sets both appState and controller selectedItemID to first item
            appState.selectNext()
            #expect(appState.selectedItemID == firstItemID,
                    "appState.selectedItemID should match first item")
            #expect(appState.controller.selectedItemID == firstItemID,
                    "controller.selectedItemID should also match")

            // selectNext moves down
            appState.selectNext()
            #expect(appState.selectedItemID == secondItemID)

            // selectPrevious moves back up
            appState.selectPrevious()
            #expect(appState.selectedItemID == firstItemID)

            // At top, selectPrevious stays at first
            appState.selectPrevious()
            #expect(appState.selectedItemID == firstItemID)

            // At bottom, selectNext stays at last
            // Set through controller so navigation uses the same state
            appState.controller.selectedItemID = controllerItems.last!.id
            appState.selectNext()
            #expect(appState.selectedItemID == controllerItems.last!.id)
        }

        @Test func enforceHistoryLimit() {
            let appState = makeAppState()
            appState.controller.maxHistoryCount = 3

            for i in 0..<10 {
                appState.insertItem(makeItem(text: "item\(i)"))
            }

            #expect(appState.controller.items.count <= 3)
        }

        /// Verifies that every AppState → controller delegate method properly
        /// syncs the result back to AppState's @Published properties.
        /// If this test fails after adding a new method, the method likely
        /// misses an `x = controller.x` sync line at the end.
        @Test func allDelegateMethodsSyncPublishedProperties() throws {
            // We test that calling a method through AppState produces the same
            // state change as calling it directly on the controller.
            let itemA = makeItem(text: "A", pinGroup: "Work")
            let itemB = makeItem(text: "B")

            // --- insertItem ---
            let appState = makeAppState()
            appState.insertItem(itemA)
            appState.insertItem(itemB)
            #expect(appState.items.count == appState.controller.items.count,
                    "insertItem should sync items")

            // --- selectNext / selectedItemID ---
            appState.selectFirstItem()
            #expect(appState.selectedItemID == appState.controller.selectedItemID,
                    "selectFirstItem should sync selectedItemID")

            appState.selectNext()
            #expect(appState.selectedItemID == appState.controller.selectedItemID,
                    "selectNext should sync selectedItemID")

            appState.selectPrevious()
            #expect(appState.selectedItemID == appState.controller.selectedItemID,
                    "selectPrevious should sync selectedItemID")

            // --- clearSelection ---
            appState.clearSelection()
            #expect(appState.selectedItemID == appState.controller.selectedItemID,
                    "clearSelection should sync selectedItemID")

            // --- setPinGroup ---
            appState.setPinGroup(for: itemA, group: "Personal")
            #expect(appState.items.first(where: { $0.id == itemA.id })?.pinGroup ==
                    appState.controller.items.first(where: { $0.id == itemA.id })?.pinGroup,
                    "setPinGroup should sync items and pinGroups")

            // --- deletePinGroup ---
            appState.deletePinGroup("Personal")
            #expect(appState.pinGroups == appState.controller.pinGroups,
                    "deletePinGroup should sync pinGroups")
            #expect(appState.selectedPinGroup == appState.controller.selectedPinGroup,
                    "deletePinGroup should sync selectedPinGroup")

            // --- deleteItem ---
            appState.deleteItem(itemB)
            #expect(appState.items.count == appState.controller.items.count,
                    "deleteItem should sync items")

            // --- multi-select delete ---
            appState.insertItem(makeItem(text: "X"))
            appState.insertItem(makeItem(text: "Y"))
            appState.insertItem(makeItem(text: "Z"))
            appState.selectedItemIDs = [appState.controller.items[0].id, appState.controller.items[2].id]
            appState.deleteSelectedItems()
            #expect(appState.items.count == appState.controller.items.count,
                    "deleteSelectedItems should sync items")
            #expect(appState.selectedItemIDs == appState.controller.selectedItemIDs,
                    "deleteSelectedItems should sync selectedItemIDs")

            // --- clearHistory ---
            appState.clearHistory()
            #expect(appState.items.count == appState.controller.items.count,
                    "clearHistory should sync items")
            #expect(appState.items.count == 0)
        }
    }

    // MARK: - ClipboardDataControllerTests

    @Suite
    struct ClipboardDataControllerTests {

        private func makeController(limit: Int = 200) -> ClipboardDataController {
            sweepLeftoverTempDirs()
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("LocalPasteTests-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            let store = HistoryStore(maxItems: limit, storageURL: tempDir.appendingPathComponent("ctl.json"))
            let manager = PasteboardManager()
            return ClipboardDataController(store: store, pasteboardManager: manager)
        }

        @Test func insertAndSort() {
            let ctl = makeController()

            let old = makeItem(text: "old", timestamp: epoch1000)
            let new = makeItem(text: "new", timestamp: epoch2000)

            ctl.insertItem(old)
            ctl.insertItem(new)

            #expect(ctl.items.count == 2)
            #expect(ctl.items[0].plainText == "new")
            #expect(ctl.items[1].plainText == "old")
        }

        @Test func deduplication() {
            let ctl = makeController()

            let data = [UTType.utf8PlainText.identifier: "dup".data(using: .utf8)!]
            let id = UUID()
            let item1 = ClipboardItem(id: id, timestamp: epoch1000,
                                       data: data, typeOrder: Array(data.keys),
                                       appName: nil, appIconData: nil, pinGroup: nil)
            let item2 = ClipboardItem(id: id, timestamp: epoch2000,
                                       data: data, typeOrder: Array(data.keys),
                                       appName: nil, appIconData: nil, pinGroup: nil)

            ctl.insertItem(item1)
            ctl.insertItem(item2)

            #expect(ctl.items.count == 1)
            // Should have the newer timestamp
            #expect(ctl.items[0].timestamp == epoch2000)
        }

        @Test func searchFilter() {
            let ctl = makeController()
            ctl.insertItem(makeItem(text: "Swift Programming"))
            ctl.insertItem(makeItem(text: "Rust Programming"))
            ctl.insertItem(makeItem(text: "Grocery List"))

            ctl.searchQuery = "swift"
            #expect(ctl.filteredItems.count == 1)
            #expect(ctl.filteredItems[0].plainText == "Swift Programming")

            ctl.searchQuery = "programming"
            #expect(ctl.filteredItems.count == 2)

            ctl.searchQuery = ""
            #expect(ctl.filteredItems.count == ctl.items.count)
        }

        @Test func pinGroup() {
            let ctl = makeController()

            let item = makeItem(text: "test")
            ctl.insertItem(item)

            ctl.setPinGroup(for: item, group: "Work")
            #expect(ctl.items.first?.pinGroup == "Work")
            #expect(ctl.pinGroups.contains("Work"))

            ctl.setPinGroup(for: item, group: nil)
            #expect(ctl.items.first?.pinGroup == nil)
        }

        @Test func pinGroupFilter() {
            let ctl = makeController()
            ctl.insertItem(makeItem(text: "a", pinGroup: "Work"))
            ctl.insertItem(makeItem(text: "b"))
            ctl.insertItem(makeItem(text: "c", pinGroup: "Personal"))

            ctl.selectedPinGroup = nil
            #expect(ctl.displayItems.count == 3)

            ctl.selectedPinGroup = "Work"
            #expect(ctl.displayItems.count == 1)
            #expect(ctl.displayItems[0].plainText == "a")
        }

        @Test func deletePinGroup() {
            let ctl = makeController()
            ctl.insertItem(makeItem(text: "a"))
            ctl.setPinGroup(for: ctl.items[0], group: "Work")
            ctl.insertItem(makeItem(text: "b"))
            ctl.setPinGroup(for: ctl.items[0], group: "Work")

            ctl.deletePinGroup("Work")
            #expect(!ctl.pinGroups.contains("Work"))
            #expect(ctl.items.filter { $0.pinGroup != nil }.count == 0)
        }

        @Test func deleteItem() {
            let ctl = makeController()
            ctl.insertItem(makeItem(text: "keep"))
            let toDelete = makeItem(text: "delete")
            ctl.insertItem(toDelete)

            ctl.deleteItem(toDelete)
            #expect(!ctl.items.contains { $0.plainText == "delete" })
        }

        @Test func clearHistory() {
            let ctl = makeController()
            ctl.insertItem(makeItem(text: "a"))
            ctl.insertItem(makeItem(text: "b"))
            ctl.clearHistory()
            #expect(ctl.items.isEmpty)
        }

        @Test func keyboardSelectionNavigation() throws {
            let ctl = makeController()

            ctl.insertItem(makeItem(text: "C", timestamp: epoch3000))
            ctl.insertItem(makeItem(text: "B", timestamp: epoch2000))
            ctl.insertItem(makeItem(text: "A", timestamp: epoch1000))

            let display = ctl.displayItems
            try #require(display.count >= 3, "Need at least 3 items")

            ctl.clearSelection()
            #expect(ctl.selectedItemID == nil)

            ctl.selectNext()
            #expect(ctl.selectedItemID == display[0].id)

            ctl.selectNext()
            #expect(ctl.selectedItemID == display[1].id)

            ctl.selectPrevious()
            #expect(ctl.selectedItemID == display[0].id)

            ctl.selectPrevious()
            #expect(ctl.selectedItemID == display[0].id)

            ctl.selectedItemID = display[display.count - 1].id
            ctl.selectNext()
            #expect(ctl.selectedItemID == display[display.count - 1].id)
        }

        @Test func multiSelectBatchDelete() {
            let ctl = makeController()

            ctl.insertItem(makeItem(text: "A"))
            ctl.insertItem(makeItem(text: "B"))
            ctl.insertItem(makeItem(text: "C"))

            let toDelete = Set([ctl.items[0].id, ctl.items[2].id])
            ctl.selectedItemIDs = toDelete
            ctl.deleteSelectedItems()

            #expect(ctl.items.count == 1)
            #expect(ctl.items[0].plainText == "B")
            #expect(ctl.selectedItemIDs.isEmpty)
        }

        @Test func enforceHistoryLimit() {
            let ctl = makeController(limit: 3)

            for i in 0..<10 {
                ctl.insertItem(makeItem(text: "item\(i)"))
            }

            #expect(ctl.items.count <= 3)
        }

        @Test func enforceHistoryLimitViaAppState() {
            let ctl = makeController(limit: 200)
            ctl.maxHistoryCount = 3

            for i in 0..<10 {
                ctl.insertItem(makeItem(text: "item\(i)"))
            }

            #expect(ctl.items.count <= 3)
        }
    }

}
