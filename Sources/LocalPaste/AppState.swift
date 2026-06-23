import Foundation
import AppKit

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

        // Set up the monitor
        monitor = PasteboardMonitor(pasteboardManager: pasteboardManager)

        // Set up hotkey
        hotKeyManager = HotKeyManager()

        // Load saved history
        items = store.load()

        // Set delegate and start monitoring
        monitor.delegate = self
        monitor.start()

        // Register global hotkey (⌥⌘V)
        hotKeyManager.onHotKeyPressed = { [weak self] in
            DispatchQueue.main.async {
                self?.toggleFloatingPanel()
            }
        }
        _ = hotKeyManager.register()
    }

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
        // Sync search query
        floatingPanel?.toggle()
    }

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
            // Re-sort to move pinned items up
            items.sort { a, b in
                if a.isPinned != b.isPinned {
                    return a.isPinned && !b.isPinned
                }
                return a.timestamp > b.timestamp
            }
            saveToDisk()
        }
    }

    // MARK: - Private helpers

    private func insertSorted(_ item: ClipboardItem) {
        // Find the right position: pinned items first (timestamp desc)
        // then unpinned items (timestamp desc)
        if item.isPinned {
            if let firstUnpin = items.firstIndex(where: { !$0.isPinned }) {
                items.insert(item, at: firstUnpin)
            } else {
                items.append(item)
            }
        } else {
            items.append(item)
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
        store.save(items)
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
