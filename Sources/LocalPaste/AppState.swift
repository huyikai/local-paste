import Foundation
import AppKit
import UniformTypeIdentifiers

/// Shared application state that flows through the environment.
final class AppState: ObservableObject {

    // MARK: - Published properties

    /// All clipboard history entries (pinned first, then newest).
    @Published var items: [ClipboardItem] = []

    /// Current search query (empty = show all)
    @Published var searchQuery: String = ""

    /// Maximum number of history entries to keep
    @Published var maxHistoryCount: Int = 200 {
        didSet { saveSettings(); enforceLimit() }
    }

    /// Whether the user has opted in to launch at login
    @Published var launchAtLogin: Bool = false {
        didSet { saveSettings() }
    }

    /// The filtered list based on searchQuery
    var filteredItems: [ClipboardItem] {
        if searchQuery.isEmpty {
            return items
        }
        return items.filter { item in
            item.matches(query: searchQuery)
        }
    }

    // MARK: - Selection (keyboard navigation)

    /// The currently highlighted item ID, or nil if none.
    @Published var selectedItemID: UUID?

    /// True when the search field has keyboard focus — Space/arrows
    /// should be passed through for typing, not interpreted as shortcuts.
    @Published var isSearchFocused = false

    /// Select the next item in `filteredItems`.
    func selectNext() {
        guard let current = selectedItemID else {
            selectedItemID = filteredItems.first?.id
            return
        }
        guard let idx = filteredItems.firstIndex(where: { $0.id == current }),
              idx + 1 < filteredItems.count else { return }
        selectedItemID = filteredItems[idx + 1].id
    }

    /// Select the previous item in `filteredItems`.
    func selectPrevious() {
        guard let current = selectedItemID else {
            selectedItemID = filteredItems.first?.id
            return
        }
        guard let idx = filteredItems.firstIndex(where: { $0.id == current }),
              idx > 0 else { return }
        selectedItemID = filteredItems[idx - 1].id
    }

    /// Paste the currently selected item and dismiss the panel.
    /// Note: the full paste flow (write clipboard + restore focus + ⌘V)
    /// is performed by FloatingHistoryPanel.performPaste().
    func pasteSelected() {
        guard let id = selectedItemID,
              let item = items.first(where: { $0.id == id }) else { return }
        copyItemToPasteboard(item)
        dismissFloatingPanel()
    }

    // MARK: - Multi-select & batch operations

    /// IDs of items currently multi-selected (via Cmd/Shift+click in List).
    @Published var selectedItemIDs: Set<UUID> = []

    /// Paste the selected item as plain text only (⌘⇧V).
    func pasteSelectedAsPlainText() {
        guard let id = selectedItemID,
              let item = items.first(where: { $0.id == id }),
              let text = item.plainText else { return }

        pasteboardManager.writeData([UTType.utf8PlainText.identifier: text.data(using: .utf8)!], order: [UTType.utf8PlainText.identifier])

        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            var refreshed = items.remove(at: idx)
            refreshed.timestamp = Date()
            insertSorted(refreshed)
            saveToDisk()
        }
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

    /// Select the first item (called when panel opens).
    func selectFirstItem() {
        selectedItemID = filteredItems.first?.id
    }

    /// Clear the selection (called when panel closes).
    func clearSelection() {
        selectedItemID = nil
    }

    // MARK: - Services

    let pasteboardManager: PasteboardManager
    private let monitor: PasteboardMonitor
    private let store: HistoryStore
    private let hotKeyManager: HotKeyManager
    private var floatingPanel: FloatingHistoryPanel?

    // MARK: - Init

    init() {
        pasteboardManager = PasteboardManager()
        store = HistoryStore()
        monitor = PasteboardMonitor(pasteboardManager: pasteboardManager)
        hotKeyManager = HotKeyManager()
        items = store.load()
        monitor.delegate = self
        monitor.start()

        hotKeyManager.onHotKeyPressed = { [weak self] in
            DispatchQueue.main.async {
                self?.toggleFloatingPanel()
            }
        }
        _ = hotKeyManager.register()

        // Expose globally for AppDelegate
        AppState.shared = self

        // Restore user preferences
        loadSettings()
    }

    static private(set) weak var shared: AppState?

    // MARK: - Public methods

    /// Insert a new item at the beginning of the list (pinned items come first).
    func insertItem(_ item: ClipboardItem) {
        // Deduplicate: if the exact same data already exists, remove the old entry
        // and update its position.
        if let existingIndex = items.firstIndex(where: { $0.data == item.data }) {
            var updated = items[existingIndex]
            updated.timestamp = item.timestamp
            items.remove(at: existingIndex)
            // Re-insert at the top of its (pinned/unpinned) section
            insertSorted(updated)
        } else {
            insertSorted(item)
        }

        enforceLimit()
        saveToDisk()
    }

    // MARK: - Floating panel (⌥⌘V)

    /// Show or hide the floating history panel.
    func toggleFloatingPanel() {
        if floatingPanel == nil {
            floatingPanel = FloatingHistoryPanel(appState: self)
        }
        floatingPanel?.toggle()
        if floatingPanel?.isVisible == true {
            selectFirstItem()
        } else {
            clearSelection()
        }
    }

    /// Dismiss the floating panel.
    func dismissFloatingPanel() {
        floatingPanel?.hideImmediately()
        clearSelection()
    }

    #if DEBUG
    /// Reset state for unit testing — stops monitor and clears storage.
    func resetForTesting() {
        monitor.stop()
        items.removeAll()
        selectedItemID = nil
        selectedItemIDs.removeAll()
        searchQuery = ""
        store.save([])
    }
    #endif

    /// Copy an item back to the system pasteboard.
    func copyItemToPasteboard(_ item: ClipboardItem) {
        pasteboardManager.copyToPasteboard(item)
        // Move the item to the top of history
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            var refreshed = items.remove(at: idx)
            refreshed.timestamp = Date()
            insertSorted(refreshed)
            saveToDisk()
        }
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

    /// Toggle pin status.
    func togglePin(for item: ClipboardItem) {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx].isPinned.toggle()
            sortItems()
            saveToDisk()
        }
    }

    // MARK: - Private helpers

    private func insertSorted(_ item: ClipboardItem) {
        items.append(item)
        sortItems()
    }

    private func sortItems() {
        items.sort { a, b in
            if a.isPinned != b.isPinned {
                return a.isPinned && !b.isPinned
            }
            return a.timestamp > b.timestamp
        }
    }

    private func enforceLimit() {
        if items.count > maxHistoryCount {
            let pinned = items.filter(\.isPinned)
            let unpinned = items.filter { !$0.isPinned }.prefix(maxHistoryCount - pinned.count)
            items = Array(pinned + unpinned)
        }
    }

    private func saveToDisk() {
        store.save(items, limit: maxHistoryCount)
    }

    private func saveSettings() {
        UserDefaults.standard.set(maxHistoryCount, forKey: "maxHistoryCount")
        UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
    }

    private func loadSettings() {
        maxHistoryCount = UserDefaults.standard.integer(forKey: "maxHistoryCount")
        if maxHistoryCount == 0 { maxHistoryCount = 200 }
        launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
    }

    deinit {
        monitor.stop()
        hotKeyManager.unregister()
    }
}

// MARK: - PasteboardMonitor Delegate

extension AppState: PasteboardMonitor.Delegate {
    func pasteboardMonitor(_ monitor: PasteboardMonitor, didCapture item: ClipboardItem) {
        DispatchQueue.main.async { [weak self] in
            self?.insertItem(item)
        }
    }

    func pasteboardMonitorDidDetectOwnWrite(_ monitor: PasteboardMonitor) {
        // Our own write — nothing special needed
    }
}
