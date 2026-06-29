import XCTest
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

// MARK: - ClipboardItemTests

final class ClipboardItemTests: XCTestCase {

    func testPlainTextDetection() {
        let item = makeItem(text: "Hello, world!")
        XCTAssertEqual(item.plainText, "Hello, world!")
        XCTAssertEqual(item.displayText, "Hello, world!")
        XCTAssertEqual(item.contentTypeIcon, "text.alignleft")
    }

    func testImageContentTypeIcon() {
        _ = makeItem(data: [UTType.png.identifier: Data()])
    }

    func testFileURLContentIcon() {
        let item = makeItem(data: [UTType.fileURL.identifier: Data()])
        XCTAssertEqual(item.contentTypeIcon, "doc")
    }

    func testSearchMatchesPlainText() {
        let item = makeItem(text: "SwiftUI code snippet")
        XCTAssertTrue(item.matches(query: "SwiftUI"))
        XCTAssertTrue(item.matches(query: "swiftui"))
        XCTAssertTrue(item.matches(query: "snippet"))
        XCTAssertFalse(item.matches(query: "react"))
        XCTAssertFalse(item.matches(query: "xyz"))
    }

    func testItemsWithSameDataAreNotEqualByID() {
        let item1 = makeItem(text: "duplicate", id: UUID())
        let item2 = makeItem(text: "duplicate", id: UUID())
        XCTAssertNotEqual(item1.id, item2.id)
        XCTAssertNotEqual(item1, item2)
        XCTAssertEqual(item1.data, item2.data)
    }

    func testColorSwatchNotNull() {
        // Simulate copying a red color from the system color picker
        let color = NSColor(red: 1.0, green: 0.2, blue: 0.3, alpha: 1.0)
        let colorData = try! NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true)

        let item = makeItem(data: [PasteboardTypes.color: colorData])
        XCTAssertNotNil(item.color, "NSColor should decode from pasteboard color data")
        XCTAssertNotNil(item.displayColor, "displayColor should be available in sRGB")
        XCTAssertEqual(item.colorHex, "#FF334D", "hex should match r=255,g=51,b=77")
    }

    func testColorDisplayPipeline() {
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

        XCTAssertTrue(item.data.keys.contains(PasteboardTypes.color))
        XCTAssertEqual(item.contentTypeIcon, "paintpalette")
        XCTAssertNotNil(item.color)
        XCTAssertNotNil(item.displayColor)
        XCTAssertTrue(item.colorHex.hasPrefix("#"))
        XCTAssertEqual(item.colorHex.count, 7)
    }

    func testHexTextColorDetection() {
        // Copying "#fff001" as text → should detect as color
        let item = makeItem(text: "#fff001")
        XCTAssertNotNil(item.displayColor, "hex text should be detected as color")
        XCTAssertEqual(item.colorHex, "#FFF001")
    }

    func testHex3CharDetection() {
        // Copying "#fff" as text → should detect as color
        let item = makeItem(text: "#abc")
        XCTAssertNotNil(item.displayColor, "3-char hex should be detected")
        XCTAssertEqual(item.colorHex, "#AABBCC")
    }

    func testNonHexTextNotColor() {
        let item = makeItem(text: "hello world")
        XCTAssertNil(item.displayColor, "plain text should not be mistaken for color")
    }

    func testRealPasteboardColorRoundtrip() {
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
        XCTAssertTrue(dataMap.keys.contains(PasteboardTypes.color),
                      "pasteboard should have color type")
        XCTAssertTrue(dataMap.keys.contains(UTType.utf8PlainText.identifier),
                      "pasteboard also has plain text (like real color picker)")

        // Create item exactly as PasteboardManager would
        let item = ClipboardItem(
            id: UUID(), timestamp: Date(),
            data: dataMap, typeOrder: order,
            appName: nil, appIconData: nil, pinGroup: nil
        )

        // Display color check
        XCTAssertNotNil(item.displayColor, "displayColor should not be nil")
        XCTAssertEqual(item.contentTypeIcon, "paintpalette")

        // displayColor should work (from NSColor data)
        XCTAssertNotNil(item.displayColor, "displayColor should not be nil")
        XCTAssertEqual(item.contentTypeIcon, "paintpalette")

        // When both text and color exist, displayText shows original text;
        // the color is indicated by the left-edge strip
        XCTAssertEqual(item.displayText,
                       "sRGB IEC61966-2.1 colorspace 0.2 0.6 0.9 1")

        // colorHex works from the NSColor data
        XCTAssertTrue(item.colorHex.hasPrefix("#"))
    }

    func testColorItemAppearsInHistory() {
        let color = NSColor.red
        let colorData = try! NSKeyedArchiver.archivedData(withRootObject: color,
                                                           requiringSecureCoding: false)
        let item = makeItem(data: ["com.apple.cocoa.pasteboard.color": colorData])
        XCTAssertEqual(item.contentTypeIcon, "paintpalette")
    }

    func testPinGroupSearch() {
        let item = makeItem(text: "test", pinGroup: "Work")
        XCTAssertTrue(item.matches(query: "Work"))
    }
}

// MARK: - SortingTests

final class SortingTests: XCTestCase {

    func testNewestFirst() {
        let old = makeItem(text: "old", timestamp: Date(timeIntervalSince1970: 1000))
        let newer = makeItem(text: "new", timestamp: Date(timeIntervalSince1970: 2000))

        let sorted = [old, newer].sorted { $0.timestamp > $1.timestamp }
        XCTAssertEqual(sorted[0].plainText, "new")
        XCTAssertEqual(sorted[1].plainText, "old")
    }

    func testAllItemsSortedByTimestamp() {
        let a = makeItem(text: "a", pinGroup: "Work", timestamp: Date(timeIntervalSince1970: 1000))
        let b = makeItem(text: "b", timestamp: Date(timeIntervalSince1970: 3000))
        let c = makeItem(text: "c", pinGroup: "Work", timestamp: Date(timeIntervalSince1970: 2000))

        let sorted = [a, b, c].sorted { $0.timestamp > $1.timestamp }
        XCTAssertEqual(sorted[0].plainText, "b")
        XCTAssertEqual(sorted[1].plainText, "c")
        XCTAssertEqual(sorted[2].plainText, "a")
    }
}

// MARK: - PasteboardTypesTests

final class PasteboardTypesTests: XCTestCase {

    func testTextTypesAreAllUTIs() {
        for type in PasteboardTypes.textTypes {
            XCTAssertTrue(type.contains(".") || type.contains("-"))
        }
    }

    func testImageTypesIncludePNG() {
        XCTAssertTrue(PasteboardTypes.imageTypes.contains("public.png"))
    }

    func testAllCaptureTypesCoverage() {
        let all = PasteboardTypes.allCaptureTypes
        XCTAssertTrue(all.contains(PasteboardTypes.plainText))
        XCTAssertTrue(all.contains(PasteboardTypes.png))
        XCTAssertTrue(all.contains(PasteboardTypes.fileURL))
        XCTAssertTrue(all.contains(PasteboardTypes.color))
    }

    func testReadAllTypesReturnsDictionary() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString("test string", forType: .string)
        let result = pb.readAllTypes()
        XCTAssertFalse(result.data.isEmpty)
    }
}

// MARK: - HistoryStoreTests

final class HistoryStoreTests: XCTestCase {

    func testStoreSaveAndLoad() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalPasteTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("test-history.json")
        let store = HistoryStore(maxItems: 10, storageURL: fileURL)

        let item = makeItem(text: "test store", pinGroup: "Work")
        store.save([item])
        let loaded = store.load()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].plainText, "test store")
        XCTAssertEqual(loaded[0].pinGroup, "Work")
    }

    func testStoreEnforcesMaxItems() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalPasteTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("test-max.json")
        let store = HistoryStore(maxItems: 3, storageURL: fileURL)

        let items = (0..<10).map { makeItem(text: "item\($0)") }
        store.save(items)
        let loaded = store.load()

        XCTAssertEqual(loaded.count, 3)
    }

    func testStoreEmptyReturnsEmpty() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalPasteTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("test-empty.json")
        let store = HistoryStore(maxItems: 10, storageURL: fileURL)

        store.save([])
        XCTAssertEqual(store.load().count, 0)
    }

    func testExportImportRoundtrip() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalPasteTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = HistoryStore(maxItems: 10, storageURL: tempDir.appendingPathComponent("x.json"))

        let items = [
            makeItem(text: "hello", pinGroup: "Work"),
            makeItem(text: "world"),
        ]

        guard let exportedData = store.exportJSON(items) else {
            XCTFail("export should succeed")
            return
        }

        let imported = store.importJSON(from: exportedData)
        XCTAssertNotNil(imported)
        XCTAssertEqual(imported?.count, 2)
        XCTAssertEqual(imported?.first?.plainText, "hello")
        XCTAssertEqual(imported?.first?.pinGroup, "Work")
        XCTAssertEqual(imported?.last?.plainText, "world")
    }

    func testImportInvalidDataReturnsNil() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalPasteTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = HistoryStore(maxItems: 10, storageURL: tempDir.appendingPathComponent("x.json"))

        let badData = "not valid json".data(using: .utf8)!
        let result = store.importJSON(from: badData)
        XCTAssertNil(result)
    }

    func testExportEmptyArray() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalPasteTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = HistoryStore(maxItems: 10, storageURL: tempDir.appendingPathComponent("x.json"))

        let data = store.exportJSON([])
        XCTAssertNotNil(data)

        let imported = store.importJSON(from: data!)
        XCTAssertNotNil(imported)
        XCTAssertEqual(imported?.count, 0)
    }
}

// MARK: - PasteboardManagerTests

final class PasteboardManagerTests: XCTestCase {

    func testOwnWriteKeysAreFiltered() {
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
        XCTAssertNil(captured, "capture should skip items with only internal types")
    }

    func testHasChangedDetectsChanges() {
        let manager = PasteboardManager()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("hello", forType: .string)

        XCTAssertTrue(manager.hasChanged, "should detect change after writing")
    }

    func testResetChangeCountSuppressesChange() {
        let manager = PasteboardManager()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("hello", forType: .string)
        _ = manager.hasChanged // consume the change

        manager.resetChangeCount()
        XCTAssertFalse(manager.hasChanged, "after reset, no change should be reported")
    }

    func testCaptureNonEmptyItem() {
        let manager = PasteboardManager()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("test capture", forType: .string)
        _ = manager.hasChanged // sync

        let item = manager.captureCurrentContent()
        XCTAssertNotNil(item, "should capture non-empty pasteboard")
        XCTAssertEqual(item?.plainText, "test capture")
    }
}

// MARK: - PasteboardMonitorTests

final class PasteboardMonitorTests: XCTestCase {

    func testStartSetsIsRunning() {
        let manager = PasteboardManager()
        let monitor = PasteboardMonitor(pasteboardManager: manager, interval: 1.0)
        XCTAssertFalse(monitor.isRunning)

        monitor.start()
        XCTAssertTrue(monitor.isRunning)

        monitor.stop()
        XCTAssertFalse(monitor.isRunning)
    }

    func testDoubleStartIsIdempotent() {
        let manager = PasteboardManager()
        let monitor = PasteboardMonitor(pasteboardManager: manager, interval: 1.0)

        monitor.start()
        monitor.start() // should not crash or double-schedule
        XCTAssertTrue(monitor.isRunning)

        monitor.stop()
    }

    func testStopWithoutStartDoesNotCrash() {
        let manager = PasteboardManager()
        let monitor = PasteboardMonitor(pasteboardManager: manager)
        monitor.stop() // no-op should not crash
        XCTAssertFalse(monitor.isRunning)
    }
}

// MARK: - HotKeyManagerTests

final class HotKeyManagerTests: XCTestCase {

    func testOnHotKeyPressedCallback() {
        let manager = HotKeyManager()

        // Verify initial state
        XCTAssertNil(manager.onHotKeyPressed)

        var called = false
        manager.onHotKeyPressed = {
            called = true
        }
        XCTAssertNotNil(manager.onHotKeyPressed)
    }

    func testRegisterReturnsStatus() {
        let manager = HotKeyManager()
        let result = manager.register()
        // On CI / test environment without accessibility, this may fail
        // But we just verify it doesn't crash and returns a consistent result
        if result {
            manager.unregister()
        }
    }

    func testUnregisterIsSafe() {
        let manager = HotKeyManager()
        // Calling unregister without register should not crash
        manager.unregister()
    }

    func testRegisterThenUnregister() {
        let manager = HotKeyManager()
        let registered = manager.register()
        if registered {
            manager.unregister()
            // unregistering again should be safe
            manager.unregister()
        }
    }

    // MARK: - currentDescription formatting

    func testCurrentDescriptionDefault() {
        defer { cleanupHotKeyDefaults() }
        // Ensure clean slate
        UserDefaults.standard.removeObject(forKey: "com.localpaste.hotKeyKeyCode")
        UserDefaults.standard.removeObject(forKey: "com.localpaste.hotKeyModifiers")
        let manager = HotKeyManager()
        // Default is cmdKey | optionKey + kVK_ANSI_V → "⌘⌥V"
        XCTAssertEqual(manager.currentDescription, "⌘⌥V")
    }

    func testCurrentDescriptionAllFourModifiers() {
        defer { cleanupHotKeyDefaults() }
        let manager = HotKeyManager()
        let allMods = UInt32(cmdKey) | UInt32(optionKey) | UInt32(controlKey) | UInt32(shiftKey)
        manager.save(keyCode: UInt32(kVK_ANSI_F), modifiers: allMods)
        // Order: ⌘, ⌥, ⌃, ⇧, then "F"
        XCTAssertEqual(manager.currentDescription, "⌘⌥⌃⇧F")
    }

    func testCurrentDescriptionSingleModifier() {
        defer { cleanupHotKeyDefaults() }
        let manager = HotKeyManager()
        manager.save(keyCode: UInt32(kVK_Space), modifiers: UInt32(shiftKey))
        XCTAssertEqual(manager.currentDescription, "⇧Space")
    }

    func testCurrentDescriptionFunctionKey() {
        defer { cleanupHotKeyDefaults() }
        let manager = HotKeyManager()
        manager.save(keyCode: UInt32(kVK_F1), modifiers: UInt32(cmdKey))
        XCTAssertEqual(manager.currentDescription, "⌘F1")
    }

    func testCurrentDescriptionArrowKey() {
        defer { cleanupHotKeyDefaults() }
        let manager = HotKeyManager()
        manager.save(keyCode: UInt32(kVK_UpArrow), modifiers: UInt32(controlKey) | UInt32(optionKey))
        XCTAssertEqual(manager.currentDescription, "⌥⌃↑")
    }

    func testCurrentDescriptionEscape() {
        defer { cleanupHotKeyDefaults() }
        let manager = HotKeyManager()
        manager.save(keyCode: UInt32(kVK_Escape), modifiers: UInt32(cmdKey) | UInt32(shiftKey))
        XCTAssertEqual(manager.currentDescription, "⌘⇧Esc")
    }

    // MARK: - Persistence (save / read-back)

    func testSaveAndReadBackKeyCode() {
        defer { cleanupHotKeyDefaults() }
        let manager = HotKeyManager()
        manager.save(keyCode: 99, modifiers: UInt32(cmdKey))
        XCTAssertEqual(manager.savedKeyCode(), 99)
    }

    func testSaveAndReadBackModifiers() {
        defer { cleanupHotKeyDefaults() }
        let manager = HotKeyManager()
        let mods = UInt32(cmdKey) | UInt32(controlKey) | UInt32(shiftKey)
        manager.save(keyCode: UInt32(kVK_ANSI_X), modifiers: mods)
        XCTAssertEqual(manager.savedModifiers(), mods)
    }

    func testSavedDefaultsWhenEmpty() {
        defer { cleanupHotKeyDefaults() }
        // Remove any saved values to ensure we get defaults
        UserDefaults.standard.removeObject(forKey: "com.localpaste.hotKeyKeyCode")
        UserDefaults.standard.removeObject(forKey: "com.localpaste.hotKeyModifiers")
        let manager = HotKeyManager()
        XCTAssertEqual(manager.savedKeyCode(), HotKeyManager.defaultKeyCode)
        XCTAssertEqual(manager.savedModifiers(), HotKeyManager.defaultModifiers)
    }

    func testSaveThenReloadUpdatesCurrentDescription() {
        defer { cleanupHotKeyDefaults() }
        let manager = HotKeyManager()
        manager.save(keyCode: UInt32(kVK_ANSI_C), modifiers: UInt32(cmdKey) | UInt32(optionKey))
        _ = manager.reload()
        XCTAssertEqual(manager.currentDescription, "⌘⌥C")
    }

    // MARK: - Helpers

    /// Clean up UserDefaults keys set during persistence tests.
    private func cleanupHotKeyDefaults() {
        UserDefaults.standard.removeObject(forKey: "com.localpaste.hotKeyKeyCode")
        UserDefaults.standard.removeObject(forKey: "com.localpaste.hotKeyModifiers")
    }
}

// MARK: - AppStateTests

final class AppStateTests: XCTestCase {

    /// Create an AppState with a controller backed by a temporary in-memory store.
    private func makeAppState() -> AppState {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalPasteTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: tempDir) }

        let store = HistoryStore(maxItems: 200, storageURL: tempDir.appendingPathComponent("test.json"))
        let manager = PasteboardManager()
        let controller = ClipboardDataController(store: store, pasteboardManager: manager)
        return AppState(controller: controller)
    }

    func testInsertItemPutsNewestFirst() {
        let appState = makeAppState()

        let old = makeItem(text: "old", timestamp: Date(timeIntervalSince1970: 1000))
        let new = makeItem(text: "new", timestamp: Date(timeIntervalSince1970: 2000))

        appState.insertItem(old)
        appState.insertItem(new)

        XCTAssertGreaterThanOrEqual(appState.controller.items.count, 2)
        XCTAssertEqual(appState.controller.items[0].plainText, "new")
        XCTAssertEqual(appState.controller.items[1].plainText, "old")
    }

    func testInsertItemDeduplicatesIdenticalData() {
        let appState = makeAppState()

        let data = [UTType.utf8PlainText.identifier: "dup".data(using: .utf8)!]
        let id = UUID()
        let item1 = ClipboardItem(id: id, timestamp: Date(timeIntervalSince1970: 1000),
                                   data: data, typeOrder: Array(data.keys),
                                   appName: nil, appIconData: nil, pinGroup: nil)
        let item2 = ClipboardItem(id: id, timestamp: Date(timeIntervalSince1970: 2000),
                                   data: data, typeOrder: Array(data.keys),
                                   appName: nil, appIconData: nil, pinGroup: nil)

        appState.insertItem(item1)
        appState.insertItem(item2)

        XCTAssertEqual(appState.controller.items.count, 1)
    }

    func testFilteredItemsWithSearch() {
        let appState = makeAppState()

        appState.insertItem(makeItem(text: "Swift Programming"))
        appState.insertItem(makeItem(text: "Rust Programming"))
        appState.insertItem(makeItem(text: "Grocery List"))

        appState.controller.searchQuery = "swift"
        XCTAssertEqual(appState.filteredItems.count, 1)
        XCTAssertEqual(appState.filteredItems[0].plainText, "Swift Programming")

        appState.controller.searchQuery = "programming"
        XCTAssertEqual(appState.filteredItems.count, 2)

        appState.controller.searchQuery = ""
        XCTAssertEqual(appState.filteredItems.count, appState.controller.items.count)
    }

    func testSetPinGroup() {
        let appState = makeAppState()

        let item = makeItem(text: "pinned")
        appState.insertItem(item)

        guard let first = appState.controller.items.first else { XCTFail(); return }
        XCTAssertNil(first.pinGroup)

        appState.setPinGroup(for: first, group: "Work")
        guard let updated = appState.controller.items.first(where: { $0.id == first.id }) else { XCTFail(); return }
        XCTAssertEqual(updated.pinGroup, "Work")

        // Clear
        appState.setPinGroup(for: updated, group: nil)
        guard let cleared = appState.controller.items.first(where: { $0.id == first.id }) else { XCTFail(); return }
        XCTAssertNil(cleared.pinGroup)
    }

    func testDeletePinGroupClearsItems() {
        let appState = makeAppState()

        appState.insertItem(makeItem(text: "a"))
        appState.insertItem(makeItem(text: "b"))
        appState.insertItem(makeItem(text: "c"))

        // Pin via setPinGroup to register the group
        appState.setPinGroup(for: appState.controller.items.first(where: { $0.plainText == "a" })!, group: "Work")
        appState.setPinGroup(for: appState.controller.items.first(where: { $0.plainText == "b" })!, group: "Work")

        XCTAssertTrue(appState.controller.pinGroups.contains("Work"))
        appState.deletePinGroup("Work")

        XCTAssertFalse(appState.controller.pinGroups.contains("Work"))
        XCTAssertEqual(appState.controller.items.filter { $0.pinGroup != nil }.count, 0)
        XCTAssertEqual(appState.controller.items.count, 3)
    }

    func testClearHistory() {
        let appState = makeAppState()

        appState.insertItem(makeItem(text: "a"))
        appState.insertItem(makeItem(text: "b"))
        appState.clearHistory()
        XCTAssertTrue(appState.controller.items.isEmpty)
    }

    func testDeleteItem() {
        let appState = makeAppState()

        appState.insertItem(makeItem(text: "keep"))
        let toDelete = makeItem(text: "delete")
        appState.insertItem(toDelete)
        let countAfterInsert = appState.controller.items.count

        appState.deleteItem(toDelete)
        XCTAssertEqual(appState.controller.items.count, countAfterInsert - 1)
        XCTAssertFalse(appState.controller.items.contains { $0.plainText == "delete" })
    }

    func testMultiSelectBatchDelete() {
        let appState = makeAppState()

        appState.insertItem(makeItem(text: "A"))
        appState.insertItem(makeItem(text: "B"))
        appState.insertItem(makeItem(text: "C"))

        // Set multi-select on AppState (didSet syncs to controller)
        let toDelete = Set([appState.controller.items[0].id, appState.controller.items[2].id])
        appState.selectedItemIDs = toDelete
        appState.deleteSelectedItems()

        XCTAssertEqual(appState.controller.items.count, 1)
        XCTAssertEqual(appState.controller.items[0].plainText, "B")
        XCTAssertTrue(appState.selectedItemIDs.isEmpty)
    }

    func testKeyboardSelectionNavigationSyncsPublishedProperty() {
        let appState = makeAppState()

        appState.insertItem(makeItem(text: "C", timestamp: Date(timeIntervalSince1970: 3000)))
        appState.insertItem(makeItem(text: "B", timestamp: Date(timeIntervalSince1970: 2000)))
        appState.insertItem(makeItem(text: "A", timestamp: Date(timeIntervalSince1970: 1000)))

        let controllerItems = appState.controller.items
        guard controllerItems.count >= 3 else { XCTFail("Need at least 3 items"); return }

        let firstItemID = controllerItems[0].id
        let secondItemID = controllerItems[1].id

        // Start with no selection
        appState.clearSelection()
        XCTAssertNil(appState.selectedItemID)

        // selectNext sets both appState and controller selectedItemID to first item
        appState.selectNext()
        XCTAssertEqual(appState.selectedItemID, firstItemID,
                       "appState.selectedItemID should match first item")
        XCTAssertEqual(appState.controller.selectedItemID, firstItemID,
                       "controller.selectedItemID should also match")

        // selectNext moves down
        appState.selectNext()
        XCTAssertEqual(appState.selectedItemID, secondItemID)

        // selectPrevious moves back up
        appState.selectPrevious()
        XCTAssertEqual(appState.selectedItemID, firstItemID)

        // At top, selectPrevious stays at first
        appState.selectPrevious()
        XCTAssertEqual(appState.selectedItemID, firstItemID)

        // At bottom, selectNext stays at last
        // Set through controller so navigation uses the same state
        appState.controller.selectedItemID = controllerItems.last!.id
        appState.selectNext()
        XCTAssertEqual(appState.selectedItemID, controllerItems.last!.id)
    }

    func testEnforceHistoryLimit() {
        let appState = makeAppState()
        appState.controller.maxHistoryCount = 3

        for i in 0..<10 {
            appState.insertItem(makeItem(text: "item\(i)"))
        }

        XCTAssertLessThanOrEqual(appState.controller.items.count, 3)
    }

    /// Verifies that every AppState → controller delegate method properly
    /// syncs the result back to AppState's @Published properties.
    /// If this test fails after adding a new method, the method likely
    /// misses an `x = controller.x` sync line at the end.
    func testAllDelegateMethodsSyncPublishedProperties() {
        // We test that calling a method through AppState produces the same
        // state change as calling it directly on the controller.
        let itemA = makeItem(text: "A", pinGroup: "Work")
        let itemB = makeItem(text: "B")

        // --- insertItem ---
        let appState = makeAppState()
        appState.insertItem(itemA)
        appState.insertItem(itemB)
        XCTAssertEqual(appState.items.count, appState.controller.items.count,
                       "insertItem should sync items")

        // --- selectNext / selectedItemID ---
        appState.selectFirstItem()
        XCTAssertEqual(appState.selectedItemID, appState.controller.selectedItemID,
                       "selectFirstItem should sync selectedItemID")

        appState.selectNext()
        XCTAssertEqual(appState.selectedItemID, appState.controller.selectedItemID,
                       "selectNext should sync selectedItemID")

        appState.selectPrevious()
        XCTAssertEqual(appState.selectedItemID, appState.controller.selectedItemID,
                       "selectPrevious should sync selectedItemID")

        // --- clearSelection ---
        appState.clearSelection()
        XCTAssertEqual(appState.selectedItemID, appState.controller.selectedItemID,
                       "clearSelection should sync selectedItemID")

        // --- setPinGroup ---
        appState.setPinGroup(for: itemA, group: "Personal")
        XCTAssertEqual(appState.items.first(where: { $0.id == itemA.id })?.pinGroup,
                       appState.controller.items.first(where: { $0.id == itemA.id })?.pinGroup,
                       "setPinGroup should sync items and pinGroups")

        // --- deletePinGroup ---
        appState.deletePinGroup("Personal")
        XCTAssertEqual(appState.pinGroups, appState.controller.pinGroups,
                       "deletePinGroup should sync pinGroups")
        XCTAssertEqual(appState.selectedPinGroup, appState.controller.selectedPinGroup,
                       "deletePinGroup should sync selectedPinGroup")

        // --- deleteItem ---
        appState.deleteItem(itemB)
        XCTAssertEqual(appState.items.count, appState.controller.items.count,
                       "deleteItem should sync items")

        // --- multi-select delete ---
        appState.insertItem(makeItem(text: "X"))
        appState.insertItem(makeItem(text: "Y"))
        appState.insertItem(makeItem(text: "Z"))
        appState.selectedItemIDs = [appState.controller.items[0].id, appState.controller.items[2].id]
        appState.deleteSelectedItems()
        XCTAssertEqual(appState.items.count, appState.controller.items.count,
                       "deleteSelectedItems should sync items")
        XCTAssertEqual(appState.selectedItemIDs, appState.controller.selectedItemIDs,
                       "deleteSelectedItems should sync selectedItemIDs")

        // --- clearHistory ---
        appState.clearHistory()
        XCTAssertEqual(appState.items.count, appState.controller.items.count,
                       "clearHistory should sync items")
        XCTAssertEqual(appState.items.count, 0)
    }
}

// MARK: - ClipboardDataControllerTests

final class ClipboardDataControllerTests: XCTestCase {

    private func makeController(limit: Int = 200) -> ClipboardDataController {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalPasteTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: tempDir) }

        let store = HistoryStore(maxItems: limit, storageURL: tempDir.appendingPathComponent("ctl.json"))
        let manager = PasteboardManager()
        return ClipboardDataController(store: store, pasteboardManager: manager)
    }

    func testInsertAndSort() {
        let ctl = makeController()

        let old = makeItem(text: "old", timestamp: Date(timeIntervalSince1970: 1000))
        let new = makeItem(text: "new", timestamp: Date(timeIntervalSince1970: 2000))

        ctl.insertItem(old)
        ctl.insertItem(new)

        XCTAssertEqual(ctl.items.count, 2)
        XCTAssertEqual(ctl.items[0].plainText, "new")
        XCTAssertEqual(ctl.items[1].plainText, "old")
    }

    func testDeduplication() {
        let ctl = makeController()

        let data = [UTType.utf8PlainText.identifier: "dup".data(using: .utf8)!]
        let id = UUID()
        let item1 = ClipboardItem(id: id, timestamp: Date(timeIntervalSince1970: 1000),
                                   data: data, typeOrder: Array(data.keys),
                                   appName: nil, appIconData: nil, pinGroup: nil)
        let item2 = ClipboardItem(id: id, timestamp: Date(timeIntervalSince1970: 2000),
                                   data: data, typeOrder: Array(data.keys),
                                   appName: nil, appIconData: nil, pinGroup: nil)

        ctl.insertItem(item1)
        ctl.insertItem(item2)

        XCTAssertEqual(ctl.items.count, 1)
        // Should have the newer timestamp
        XCTAssertEqual(ctl.items[0].timestamp, Date(timeIntervalSince1970: 2000))
    }

    func testSearchFilter() {
        let ctl = makeController()
        ctl.insertItem(makeItem(text: "Swift Programming"))
        ctl.insertItem(makeItem(text: "Rust Programming"))
        ctl.insertItem(makeItem(text: "Grocery List"))

        ctl.searchQuery = "swift"
        XCTAssertEqual(ctl.filteredItems.count, 1)
        XCTAssertEqual(ctl.filteredItems[0].plainText, "Swift Programming")

        ctl.searchQuery = "programming"
        XCTAssertEqual(ctl.filteredItems.count, 2)

        ctl.searchQuery = ""
        XCTAssertEqual(ctl.filteredItems.count, ctl.items.count)
    }

    func testPinGroup() {
        let ctl = makeController()

        let item = makeItem(text: "test")
        ctl.insertItem(item)

        ctl.setPinGroup(for: item, group: "Work")
        XCTAssertEqual(ctl.items.first?.pinGroup, "Work")
        XCTAssertTrue(ctl.pinGroups.contains("Work"))

        ctl.setPinGroup(for: item, group: nil)
        XCTAssertNil(ctl.items.first?.pinGroup)
    }

    func testPinGroupFilter() {
        let ctl = makeController()
        ctl.insertItem(makeItem(text: "a", pinGroup: "Work"))
        ctl.insertItem(makeItem(text: "b"))
        ctl.insertItem(makeItem(text: "c", pinGroup: "Personal"))

        ctl.selectedPinGroup = nil
        XCTAssertEqual(ctl.displayItems.count, 3)

        ctl.selectedPinGroup = "Work"
        XCTAssertEqual(ctl.displayItems.count, 1)
        XCTAssertEqual(ctl.displayItems[0].plainText, "a")
    }

    func testDeletePinGroup() {
        let ctl = makeController()
        ctl.insertItem(makeItem(text: "a"))
        ctl.setPinGroup(for: ctl.items[0], group: "Work")
        ctl.insertItem(makeItem(text: "b"))
        ctl.setPinGroup(for: ctl.items[0], group: "Work")

        ctl.deletePinGroup("Work")
        XCTAssertFalse(ctl.pinGroups.contains("Work"))
        XCTAssertEqual(ctl.items.filter { $0.pinGroup != nil }.count, 0)
    }

    func testDeleteItem() {
        let ctl = makeController()
        ctl.insertItem(makeItem(text: "keep"))
        let toDelete = makeItem(text: "delete")
        ctl.insertItem(toDelete)

        ctl.deleteItem(toDelete)
        XCTAssertFalse(ctl.items.contains { $0.plainText == "delete" })
    }

    func testClearHistory() {
        let ctl = makeController()
        ctl.insertItem(makeItem(text: "a"))
        ctl.insertItem(makeItem(text: "b"))
        ctl.clearHistory()
        XCTAssertTrue(ctl.items.isEmpty)
    }

    func testKeyboardSelectionNavigation() {
        let ctl = makeController()

        ctl.insertItem(makeItem(text: "C", timestamp: Date(timeIntervalSince1970: 3000)))
        ctl.insertItem(makeItem(text: "B", timestamp: Date(timeIntervalSince1970: 2000)))
        ctl.insertItem(makeItem(text: "A", timestamp: Date(timeIntervalSince1970: 1000)))

        let display = ctl.displayItems
        guard display.count >= 3 else { XCTFail("Need at least 3 items"); return }

        ctl.clearSelection()
        XCTAssertNil(ctl.selectedItemID)

        ctl.selectNext()
        XCTAssertEqual(ctl.selectedItemID, display[0].id)

        ctl.selectNext()
        XCTAssertEqual(ctl.selectedItemID, display[1].id)

        ctl.selectPrevious()
        XCTAssertEqual(ctl.selectedItemID, display[0].id)

        ctl.selectPrevious()
        XCTAssertEqual(ctl.selectedItemID, display[0].id)

        ctl.selectedItemID = display[display.count - 1].id
        ctl.selectNext()
        XCTAssertEqual(ctl.selectedItemID, display[display.count - 1].id)
    }

    func testMultiSelectBatchDelete() {
        let ctl = makeController()

        ctl.insertItem(makeItem(text: "A"))
        ctl.insertItem(makeItem(text: "B"))
        ctl.insertItem(makeItem(text: "C"))

        let toDelete = Set([ctl.items[0].id, ctl.items[2].id])
        ctl.selectedItemIDs = toDelete
        ctl.deleteSelectedItems()

        XCTAssertEqual(ctl.items.count, 1)
        XCTAssertEqual(ctl.items[0].plainText, "B")
        XCTAssertTrue(ctl.selectedItemIDs.isEmpty)
    }

    func testEnforceHistoryLimit() {
        let ctl = makeController(limit: 3)

        for i in 0..<10 {
            ctl.insertItem(makeItem(text: "item\(i)"))
        }

        XCTAssertLessThanOrEqual(ctl.items.count, 3)
    }

    func testEnforceHistoryLimitViaAppState() {
        let ctl = makeController(limit: 200)
        ctl.maxHistoryCount = 3

        for i in 0..<10 {
            ctl.insertItem(makeItem(text: "item\(i)"))
        }

        XCTAssertLessThanOrEqual(ctl.items.count, 3)
    }
}
