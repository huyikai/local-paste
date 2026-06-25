import Foundation
import AppKit
import UniformTypeIdentifiers

/// Manages clipboard history data — items, search, pin groups, keyboard navigation,
/// and multi-select. Injects HistoryStore for persistence and PasteboardManager for
/// clipboard I/O so the class is fully testable without side effects.
final class ClipboardDataController: ObservableObject {

    // MARK: - Published properties

    /// All clipboard history entries (pinned first, then newest).
    @Published var items: [ClipboardItem] = []

    /// Current search query (empty = show all)
    @Published var searchQuery: String = ""

    /// The currently highlighted item ID, or nil if none.
    @Published var selectedItemID: UUID?

    /// IDs of items currently multi-selected (via Cmd/Shift+click in List).
    @Published var selectedItemIDs: Set<UUID> = []

    /// Available pin groups (the user can create custom ones).
    @Published var pinGroups: [String] = ["General"]

    /// Currently selected group filter ("All" or a group name). nil = "All".
    @Published var selectedPinGroup: String? = nil

    /// True when the search field has keyboard focus.
    @Published var isSearchFocused = false

    /// True when a popover is open.
    @Published var isPopoverOpen = false

    /// Maximum history entries to keep.
    var maxHistoryCount: Int = 200

    // MARK: - Dependencies

    private let store: HistoryStore
    let pasteboardManager: PasteboardManager

    // MARK: - Init

    init(store: HistoryStore, pasteboardManager: PasteboardManager) {
        self.store = store
        self.pasteboardManager = pasteboardManager
        self.items = store.load()
        self.maxHistoryCount = store.maxItems
        loadPinGroups()
    }

    /// Convenience init for production use (default store and manager).
    convenience init() {
        self.init(store: HistoryStore(), pasteboardManager: PasteboardManager())
    }

    // MARK: - Computed properties

    /// The filtered list based on searchQuery
    var filteredItems: [ClipboardItem] {
        if searchQuery.isEmpty {
            return items
        }
        return items.filter { item in
            item.matches(query: searchQuery)
        }
    }

    /// Filtered items respecting pin group selection.
    var displayItems: [ClipboardItem] {
        let base = searchQuery.isEmpty ? items : filteredItems
        guard let group = selectedPinGroup else { return base }
        return base.filter { $0.pinGroup == group }
    }

    // MARK: - Item operations

    /// Insert a new item at the beginning of the list (pinned items come first).
    func insertItem(_ item: ClipboardItem) {
        if let existingIndex = items.firstIndex(where: { $0.data == item.data }) {
            var updated = items[existingIndex]
            updated.timestamp = item.timestamp
            items.remove(at: existingIndex)
            insertSorted(updated)
        } else {
            insertSorted(item)
        }
        enforceLimit()
        saveToDisk()
    }

    /// Delete a single item.
    func deleteItem(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        saveToDisk()
    }

    /// Clear the entire history.
    func clearHistory() {
        items.removeAll()
        saveToDisk()
    }

    /// Delete all currently multi-selected items.
    func deleteSelectedItems() {
        items.removeAll { selectedItemIDs.contains($0.id) }
        selectedItemIDs.removeAll()
        saveToDisk()
    }

    /// Move items for drag-to-reorder.
    func moveItems(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        saveToDisk()
    }

    // MARK: - Clipboard operations

    /// Copy an item back to the system pasteboard and refresh its timestamp.
    func copyItemToPasteboard(_ item: ClipboardItem) {
        pasteboardManager.copyToPasteboard(item)
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            var refreshed = items.remove(at: idx)
            refreshed.timestamp = Date()
            insertSorted(refreshed)
            saveToDisk()
        }
    }

    /// Paste the selected item as plain text only.
    func pasteSelectedAsPlainText() {
        guard let id = selectedItemID,
              let item = items.first(where: { $0.id == id }),
              let text = item.plainText else { return }

        pasteboardManager.writeData([UTType.utf8PlainText.identifier: text.data(using: .utf8)!],
                                     order: [UTType.utf8PlainText.identifier])

        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            var refreshed = items.remove(at: idx)
            refreshed.timestamp = Date()
            insertSorted(refreshed)
            saveToDisk()
        }
    }

    // MARK: - Pin groups

    func setPinGroup(for item: ClipboardItem, group: String?) {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx].pinGroup = group
        }
        if let g = group, !pinGroups.contains(g) {
            pinGroups.append(g)
        }
        items = items.map { $0 }
        saveToDisk()
    }

    func deletePinGroup(_ group: String) {
        pinGroups.removeAll { $0 == group }
        for idx in items.indices where items[idx].pinGroup == group {
            items[idx].pinGroup = nil
        }
        if selectedPinGroup == group { selectedPinGroup = nil }
        items = items.map { $0 }
        saveToDisk()
    }

    // MARK: - Keyboard navigation

    /// Select the first item in `displayItems`.
    func selectFirstItem() {
        selectedItemID = displayItems.first?.id
    }

    /// Clear the selection.
    func clearSelection() {
        selectedItemID = nil
    }

    /// Select the next item in `displayItems`.
    func selectNext() {
        guard let current = selectedItemID else {
            selectedItemID = displayItems.first?.id
            return
        }
        guard let idx = displayItems.firstIndex(where: { $0.id == current }),
              idx + 1 < displayItems.count else { return }
        selectedItemID = displayItems[idx + 1].id
    }

    /// Select the previous item in `displayItems`.
    func selectPrevious() {
        guard let current = selectedItemID else {
            selectedItemID = displayItems.first?.id
            return
        }
        guard let idx = displayItems.firstIndex(where: { $0.id == current }),
              idx > 0 else { return }
        selectedItemID = displayItems[idx - 1].id
    }

    // MARK: - Private helpers

    private func insertSorted(_ item: ClipboardItem) {
        items.append(item)
        sortItems()
    }

    private func sortItems() {
        items = items.sorted { $0.timestamp > $1.timestamp }
    }

    private func enforceLimit() {
        if items.count > maxHistoryCount {
            items = Array(items.prefix(maxHistoryCount))
        }
    }

    private func saveToDisk() {
        store.save(items, limit: maxHistoryCount)
    }

    private func loadPinGroups() {
        if let saved = UserDefaults.standard.stringArray(forKey: "pinGroups"), !saved.isEmpty {
            pinGroups = saved
        }
    }
}
