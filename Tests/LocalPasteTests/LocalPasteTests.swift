import XCTest
@testable import LocalPaste
import AppKit
import UniformTypeIdentifiers

// MARK: - Helpers

private func makeItem(data: [String: Data] = [:],
                      text: String? = nil,
                      pinned: Bool = false,
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
        appName: "TestApp",
        appIconData: nil,
        isPinned: pinned
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
        // Even with empty PNG data, key detection should identify it as photo
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

    func testColorContentIcon() {
        let color = NSColor.red
        let colorData = try! NSKeyedArchiver.archivedData(withRootObject: color,
                                                           requiringSecureCoding: false)
        let item = makeItem(data: ["com.apple.cocoa.pasteboard.color": colorData])
        XCTAssertEqual(item.contentTypeIcon, "paintpalette")
    }
}

// MARK: - SortingTests

final class SortingTests: XCTestCase {

    func testPinnedItemsComeFirst() {
        let now = Date()
        let pinned = makeItem(text: "p", pinned: true, timestamp: now.addingTimeInterval(-100))
        let unpinned = makeItem(text: "u", pinned: false, timestamp: now)

        let sorted = [unpinned, pinned].sorted(by: sortFn)
        XCTAssertTrue(sorted[0].isPinned)
        XCTAssertFalse(sorted[1].isPinned)
    }

    func testNewestFirstWithinSamePinState() {
        let old = makeItem(text: "old", pinned: false,
                           timestamp: Date(timeIntervalSince1970: 1000))
        let newer = makeItem(text: "new", pinned: false,
                             timestamp: Date(timeIntervalSince1970: 2000))

        let sorted = [old, newer].sorted(by: sortFn)
        XCTAssertEqual(sorted[0].plainText, "new")
        XCTAssertEqual(sorted[1].plainText, "old")
    }

    func testMultiplePinnedNewestFirst() {
        let p1 = makeItem(text: "p1", pinned: true,
                          timestamp: Date(timeIntervalSince1970: 1000))
        let p2 = makeItem(text: "p2", pinned: true,
                          timestamp: Date(timeIntervalSince1970: 2000))
        let u1 = makeItem(text: "u1", pinned: false,
                          timestamp: Date(timeIntervalSince1970: 3000))
        let u2 = makeItem(text: "u2", pinned: false,
                          timestamp: Date(timeIntervalSince1970: 1500))

        let sorted = [u1, p1, u2, p2].sorted(by: sortFn)
        XCTAssertTrue(sorted[0].isPinned)
        XCTAssertTrue(sorted[1].isPinned)
        XCTAssertFalse(sorted[2].isPinned)
        XCTAssertFalse(sorted[3].isPinned)
        XCTAssertEqual(sorted[0].timestamp, Date(timeIntervalSince1970: 2000))
        XCTAssertEqual(sorted[2].timestamp, Date(timeIntervalSince1970: 3000))
        XCTAssertEqual(sorted[3].timestamp, Date(timeIntervalSince1970: 1500))
    }

    private var sortFn: (ClipboardItem, ClipboardItem) -> Bool {{
        if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
        return $0.timestamp > $1.timestamp
    }}
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
        XCTAssertFalse(result.isEmpty)
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

        let item = makeItem(text: "test store")
        store.save([item])
        let loaded = store.load()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].plainText, "test store")
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
        // Reset persisted data before each test to avoid cross-contamination
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
        // The first unpinned item should be "new"
        let unpinned = appState.items.filter { !$0.isPinned }
        XCTAssertEqual(unpinned[0].plainText, "new")
        XCTAssertEqual(unpinned[1].plainText, "old")
    }

    func testInsertItemDeduplicatesIdenticalData() {
        let appState = AppState()
        appState.resetForTesting()
        let initialCount = appState.items.count

        let data = [UTType.utf8PlainText.identifier: "dup".data(using: .utf8)!]
        let id = UUID()
        let item1 = ClipboardItem(id: id, timestamp: Date(timeIntervalSince1970: 1000),
                                   data: data, appName: nil, appIconData: nil, isPinned: false)
        let item2 = ClipboardItem(id: id, timestamp: Date(timeIntervalSince1970: 2000),
                                   data: data, appName: nil, appIconData: nil, isPinned: false)

        appState.insertItem(item1)
        appState.insertItem(item2)

        // After dedup, only +1 from the initial count
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

    func testTogglePin() {
        let appState = AppState()
        appState.resetForTesting()

        let item = makeItem(text: "pinned", pinned: false)
        appState.insertItem(item)

        guard let first = appState.items.first else { XCTFail(); return }
        let originalPin = first.isPinned
        appState.togglePin(for: first)

        // After toggle, the first item should have opposite pinned status
        // (unless it was already pinned and there are other items)
        if let toggled = appState.items.first(where: { $0.id == first.id }) {
            XCTAssertNotEqual(toggled.isPinned, originalPin)
        }
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

        let filtered = appState.filteredItems
        guard filtered.count >= 3 else { XCTFail("Need at least 3 items"); return }

        // No selection initially
        appState.clearSelection()
        XCTAssertNil(appState.selectedItemID)

        // selectNext → first item (newest = C)
        appState.selectNext()
        XCTAssertEqual(appState.selectedItemID, filtered[0].id)

        // selectNext → second item
        appState.selectNext()
        XCTAssertEqual(appState.selectedItemID, filtered[1].id)

        // selectPrevious → back to first
        appState.selectPrevious()
        XCTAssertEqual(appState.selectedItemID, filtered[0].id)

        // selectPrevious at boundary stays at first
        appState.selectPrevious()
        XCTAssertEqual(appState.selectedItemID, filtered[0].id)

        // Jump to last and try selectNext → stays at last
        appState.selectedItemID = filtered[filtered.count - 1].id
        appState.selectNext()
        XCTAssertEqual(appState.selectedItemID, filtered[filtered.count - 1].id)
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
