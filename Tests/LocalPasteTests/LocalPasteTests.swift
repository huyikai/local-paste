import XCTest
@testable import LocalPaste
import AppKit
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

        // displayText must show hex, NOT the plain text description
        XCTAssertEqual(item.displayText, item.colorHex,
                       "displayText should be hex, not plain text description")
        XCTAssertTrue(item.displayText.hasPrefix("#"),
                      "displayText should start with #, got: \(item.displayText)")
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
}

// MARK: - AppStateTests

final class AppStateTests: XCTestCase {

    override func setUp() {
        super.setUp()
        let appState = AppState()
        appState.resetForTesting()
    }

    func testInsertItemPutsNewestFirst() {
        let appState = AppState()
        appState.resetForTesting()

        let old = makeItem(text: "old", timestamp: Date(timeIntervalSince1970: 1000))
        let new = makeItem(text: "new", timestamp: Date(timeIntervalSince1970: 2000))

        appState.insertItem(old)
        appState.insertItem(new)

        XCTAssertGreaterThanOrEqual(appState.items.count, 2)
        XCTAssertEqual(appState.items[0].plainText, "new")
        XCTAssertEqual(appState.items[1].plainText, "old")
    }

    func testInsertItemDeduplicatesIdenticalData() {
        let appState = AppState()
        appState.resetForTesting()
        let initialCount = appState.items.count

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

        XCTAssertEqual(appState.items.count, initialCount + 1)
    }

    func testFilteredItemsWithSearch() {
        let appState = AppState()
        appState.resetForTesting()

        appState.insertItem(makeItem(text: "Swift Programming"))
        appState.insertItem(makeItem(text: "Rust Programming"))
        appState.insertItem(makeItem(text: "Grocery List"))

        appState.searchQuery = "swift"
        XCTAssertEqual(appState.filteredItems.count, 1)
        XCTAssertEqual(appState.filteredItems[0].plainText, "Swift Programming")

        appState.searchQuery = "programming"
        XCTAssertEqual(appState.filteredItems.count, 2)

        appState.searchQuery = ""
        XCTAssertEqual(appState.filteredItems.count, appState.items.count)
    }

    func testSetPinGroup() {
        let appState = AppState()
        appState.resetForTesting()

        let item = makeItem(text: "pinned")
        appState.insertItem(item)

        guard let first = appState.items.first else { XCTFail(); return }
        XCTAssertNil(first.pinGroup)

        appState.setPinGroup(for: first, group: "Work")
        guard let updated = appState.items.first(where: { $0.id == first.id }) else { XCTFail(); return }
        XCTAssertEqual(updated.pinGroup, "Work")

        // Clear
        appState.setPinGroup(for: updated, group: nil)
        guard let cleared = appState.items.first(where: { $0.id == first.id }) else { XCTFail(); return }
        XCTAssertNil(cleared.pinGroup)
    }

    func testPinGroupFilter() {
        let appState = AppState()
        appState.resetForTesting()

        appState.insertItem(makeItem(text: "a", pinGroup: "Work"))
        appState.insertItem(makeItem(text: "b"))
        appState.insertItem(makeItem(text: "c", pinGroup: "Personal"))

        // All (no filter)
        appState.selectedPinGroup = nil
        XCTAssertEqual(appState.displayItems.count, 3)

        // Filter by group
        appState.selectedPinGroup = "Work"
        XCTAssertEqual(appState.displayItems.count, 1)
        XCTAssertEqual(appState.displayItems[0].plainText, "a")

        appState.selectedPinGroup = "Personal"
        XCTAssertEqual(appState.displayItems.count, 1)
        XCTAssertEqual(appState.displayItems[0].plainText, "c")
    }

    func testDeletePinGroupClearsItems() {
        let appState = AppState()
        appState.resetForTesting()

        appState.insertItem(makeItem(text: "a"))
        appState.insertItem(makeItem(text: "b"))
        appState.insertItem(makeItem(text: "c"))

        // Pin via setPinGroup to register the group
        appState.setPinGroup(for: appState.items.first(where: { $0.plainText == "a" })!, group: "Work")
        appState.setPinGroup(for: appState.items.first(where: { $0.plainText == "b" })!, group: "Work")

        XCTAssertTrue(appState.pinGroups.contains("Work"))
        appState.deletePinGroup("Work")

        XCTAssertFalse(appState.pinGroups.contains("Work"))
        XCTAssertEqual(appState.items.filter { $0.pinGroup != nil }.count, 0)
        XCTAssertEqual(appState.items.count, 3)
    }

    func testClearHistory() {
        let appState = AppState()
        appState.resetForTesting()

        appState.insertItem(makeItem(text: "a"))
        appState.insertItem(makeItem(text: "b"))
        appState.clearHistory()
        XCTAssertTrue(appState.items.isEmpty)
    }

    func testDeleteItem() {
        let appState = AppState()
        appState.resetForTesting()

        appState.insertItem(makeItem(text: "keep"))
        let toDelete = makeItem(text: "delete")
        appState.insertItem(toDelete)
        let countAfterInsert = appState.items.count

        appState.deleteItem(toDelete)
        XCTAssertEqual(appState.items.count, countAfterInsert - 1)
        XCTAssertFalse(appState.items.contains { $0.plainText == "delete" })
    }

    func testKeyboardSelectionNavigation() {
        let appState = AppState()
        appState.resetForTesting()

        appState.insertItem(makeItem(text: "C", timestamp: Date(timeIntervalSince1970: 3000)))
        appState.insertItem(makeItem(text: "B", timestamp: Date(timeIntervalSince1970: 2000)))
        appState.insertItem(makeItem(text: "A", timestamp: Date(timeIntervalSince1970: 1000)))

        let display = appState.displayItems
        guard display.count >= 3 else { XCTFail("Need at least 3 items"); return }

        appState.clearSelection()
        XCTAssertNil(appState.selectedItemID)

        appState.selectNext()
        XCTAssertEqual(appState.selectedItemID, display[0].id)

        appState.selectNext()
        XCTAssertEqual(appState.selectedItemID, display[1].id)

        appState.selectPrevious()
        XCTAssertEqual(appState.selectedItemID, display[0].id)

        appState.selectPrevious()
        XCTAssertEqual(appState.selectedItemID, display[0].id)

        appState.selectedItemID = display[display.count - 1].id
        appState.selectNext()
        XCTAssertEqual(appState.selectedItemID, display[display.count - 1].id)
    }

    func testMultiSelectBatchDelete() {
        let appState = AppState()
        appState.resetForTesting()

        appState.insertItem(makeItem(text: "A"))
        appState.insertItem(makeItem(text: "B"))
        appState.insertItem(makeItem(text: "C"))

        let toDelete = Set([appState.items[0].id, appState.items[2].id])
        appState.selectedItemIDs = toDelete
        appState.deleteSelectedItems()

        XCTAssertEqual(appState.items.count, 1)
        XCTAssertEqual(appState.items[0].plainText, "B")
        XCTAssertTrue(appState.selectedItemIDs.isEmpty)
    }

    func testEnforceHistoryLimit() {
        let appState = AppState()
        appState.resetForTesting()
        appState.maxHistoryCount = 3

        for i in 0..<10 {
            appState.insertItem(makeItem(text: "item\(i)"))
        }

        XCTAssertLessThanOrEqual(appState.items.count, 3)
    }
}
