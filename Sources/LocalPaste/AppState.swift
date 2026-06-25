import Foundation
import AppKit
import UniformTypeIdentifiers

/// Shared application state that flows through the environment.
/// Owns services (monitor, hotkey, panel) and delegates data management
/// to ClipboardDataController for testability.
final class AppState: ObservableObject {

    // MARK: - Data controller

    /// All data management logic is delegated here.
    let controller: ClipboardDataController

    // MARK: - Published properties (synced with controller)

    @Published var items: [ClipboardItem] = []

    @Published var searchQuery: String = "" {
        didSet { controller.searchQuery = searchQuery }
    }

    @Published var selectedItemID: UUID?

    @Published var selectedItemIDs: Set<UUID> = [] {
        didSet { controller.selectedItemIDs = selectedItemIDs }
    }

    @Published var pinGroups: [String] = ["General"] {
        didSet { controller.pinGroups = pinGroups }
    }

    @Published var selectedPinGroup: String? = nil {
        didSet { controller.selectedPinGroup = selectedPinGroup }
    }

    @Published var isSearchFocused = false {
        didSet { controller.isSearchFocused = isSearchFocused }
    }

    @Published var isPopoverOpen = false {
        didSet { controller.isPopoverOpen = isPopoverOpen }
    }

    @Published var maxHistoryCount: Int = 200 {
        didSet { saveSettings(); controller.maxHistoryCount = maxHistoryCount }
    }

    @Published var launchAtLogin: Bool = false {
        didSet { saveSettings() }
    }

    // MARK: - Computed properties (delegated to controller)

    var filteredItems: [ClipboardItem] { controller.filteredItems }
    var displayItems: [ClipboardItem] { controller.displayItems }

    // MARK: - Services

    let pasteboardManager: PasteboardManager
    private let monitor: PasteboardMonitor
    let hotKeyManager: HotKeyManager
    private var floatingPanel: FloatingHistoryPanel?

    // MARK: - Init

    /// Production init — creates real services.
    init() {
        let store = HistoryStore()
        self.pasteboardManager = PasteboardManager()
        self.controller = ClipboardDataController(store: store, pasteboardManager: pasteboardManager)
        self.monitor = PasteboardMonitor(pasteboardManager: pasteboardManager)
        self.hotKeyManager = HotKeyManager()

        syncFromController()

        monitor.delegate = self
        monitor.start()

        hotKeyManager.onHotKeyPressed = { [weak self] in
            DispatchQueue.main.async {
                self?.toggleFloatingPanel()
            }
        }
        _ = hotKeyManager.register()

        AppState.shared = self
        loadSettings()
    }

    /// Testing init — injects a fully configured controller.
    /// Does NOT start the monitor, register hotkeys, or set up forwarding.
    init(controller: ClipboardDataController) {
        self.controller = controller
        self.pasteboardManager = controller.pasteboardManager
        self.monitor = PasteboardMonitor(pasteboardManager: pasteboardManager)
        self.hotKeyManager = HotKeyManager()

        syncFromController()

        AppState.shared = self
        loadSettings()
    }

    static private(set) weak var shared: AppState?

    // MARK: - Sync

    /// Copy controller's current state to our @Published properties.
    private func syncFromController() {
        items = controller.items
        searchQuery = controller.searchQuery
        selectedItemID = controller.selectedItemID
        selectedItemIDs = controller.selectedItemIDs
        pinGroups = controller.pinGroups
        selectedPinGroup = controller.selectedPinGroup
        isSearchFocused = controller.isSearchFocused
        isPopoverOpen = controller.isPopoverOpen
        maxHistoryCount = controller.maxHistoryCount
    }

    // MARK: - Public methods (delegate to controller)

    /// Every method that mutates controller state also syncs the relevant
    /// published properties back so views observe changes immediately.

    func selectNext() {
        controller.selectNext()
        selectedItemID = controller.selectedItemID
    }

    func selectPrevious() {
        controller.selectPrevious()
        selectedItemID = controller.selectedItemID
    }

    func selectFirstItem() {
        controller.selectFirstItem()
        selectedItemID = controller.selectedItemID
    }

    func clearSelection() {
        controller.clearSelection()
        selectedItemID = controller.selectedItemID
    }

    func insertItem(_ item: ClipboardItem) {
        controller.insertItem(item)
        items = controller.items
    }

    func deleteItem(_ item: ClipboardItem) {
        controller.deleteItem(item)
        items = controller.items
    }

    func clearHistory() {
        controller.clearHistory()
        items = controller.items
    }

    func deleteSelectedItems() {
        controller.selectedItemIDs = selectedItemIDs
        controller.deleteSelectedItems()
        items = controller.items
        selectedItemIDs = controller.selectedItemIDs
    }

    func moveItems(from source: IndexSet, to destination: Int) {
        controller.moveItems(from: source, to: destination)
        items = controller.items
    }

    func setPinGroup(for item: ClipboardItem, group: String?) {
        controller.setPinGroup(for: item, group: group)
        items = controller.items
        pinGroups = controller.pinGroups
    }

    func deletePinGroup(_ group: String) {
        controller.deletePinGroup(group)
        pinGroups = controller.pinGroups
        selectedPinGroup = controller.selectedPinGroup
        items = controller.items
    }

    func copyItemToPasteboard(_ item: ClipboardItem) {
        controller.copyItemToPasteboard(item)
        items = controller.items
    }

    func pasteSelectedAsPlainText() {
        controller.pasteSelectedAsPlainText()
        items = controller.items
    }

    // MARK: - Paste flow (requires panel)

    func performPaste(_ item: ClipboardItem) {
        selectedItemID = item.id
        floatingPanel?.performPaste(appState: self)
    }

    func pasteSelected() {
        guard let id = selectedItemID,
              let item = items.first(where: { $0.id == id }) else { return }
        copyItemToPasteboard(item)
        dismissFloatingPanel()
    }

    // MARK: - Floating panel (⌥⌘V)

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

    func dismissFloatingPanel() {
        floatingPanel?.hideImmediately()
        clearSelection()
    }

    // MARK: - Settings

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
