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

    /// True when keyboard focus is on the group filter row.
    @Published var isGroupFilterFocused = false

    /// Which filter chip is highlighted (0 = "All", 1+ = pinGroups index).
    @Published var focusedFilterIndex = 0

    @Published var isPopoverOpen = false {
        didSet { controller.isPopoverOpen = isPopoverOpen }
    }

    @Published var maxHistoryCount: Int = 200 {
        didSet { saveSettings(); controller.maxHistoryCount = maxHistoryCount }
    }

    /// Days to retain history. 0 = keep forever.
    @Published var historyRetentionDays: Int = 0 {
        didSet { saveSettings(); controller.historyRetentionDays = historyRetentionDays }
    }

    @Published var launchAtLogin: Bool = false {
        didSet { saveSettings() }
    }

    /// Name of the frontmost app before the panel appeared (paste target).
    @Published var targetAppName: String? = nil

    // MARK: - Computed properties (delegated to controller)

    var filteredItems: [ClipboardItem] { controller.filteredItems }
    var displayItems: [ClipboardItem] { controller.displayItems }

    // MARK: - Services

    let pasteboardManager: PasteboardManager
    private let monitor: PasteboardMonitor
    let hotKeyManager: HotKeyManager
    private var floatingPanel: FloatingHistoryPanel?
    let updateChecker = UpdateChecker()

    @Published var updateCheckResult: UpdateCheckResult = .upToDate

    private var updateTimer: Timer?

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
        scheduleAutoUpdateCheck()
    }

    // MARK: - Update check

    /// Perform a manual update check and update the published result.
    @MainActor
    func checkForUpdates() async {
        updateCheckResult = .checking
        updateChecker.lastCheckDate = Date()
        let result = await updateChecker.check()
        updateCheckResult = result
    }

    /// Schedule the first auto-check after a delay, then every 24 hours.
    private func scheduleAutoUpdateCheck() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                await self.performSilentCheck()
            }
        }
        updateTimer = Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                await self.performSilentCheck()
            }
        }
    }

    /// Silent check: only notify if check is due AND a new version is found.
    @MainActor
    private func performSilentCheck() async {
        guard updateChecker.isCheckDue else { return }
        let result = await updateChecker.check()
        updateCheckResult = result

        if case .newVersion(let version, let url) = result {
            showUpdateNotification(version: version, url: url)
        }
    }

    /// Show a native notification alert when a new version is found.
    private func showUpdateNotification(version: String, url: URL) {
        let alert = NSAlert()
        alert.messageText = loc("update.found", version)
        alert.informativeText = loc("update.found.message")
        alert.addButton(withTitle: loc("update.download"))
        alert.addButton(withTitle: loc("update.later"))
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(url)
        }
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
        historyRetentionDays = controller.historyRetentionDays
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

    /// Apply the filter at `focusedFilterIndex`. If `keepFocus` is false (default),
    /// also clear group filter focus and move to the list.
    func applyFilterFromFocus(keepFocus: Bool = false) {
        if focusedFilterIndex == 0 {
            selectedPinGroup = nil
        } else {
            let idx = focusedFilterIndex - 1
            if idx < pinGroups.count {
                selectedPinGroup = pinGroups[idx]
            }
        }
        if !keepFocus {
            isGroupFilterFocused = false
            selectFirstItem()
        }
    }

    func clearSelection() {
        controller.clearSelection()
        selectedItemID = controller.selectedItemID
        selectedItemIDs = controller.selectedItemIDs
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

    /// Remove items older than the given number of days.
    func clearHistoryOlderThan(days: Int) {
        controller.clearHistoryOlderThan(days: days)
        items = controller.items
    }

    /// Human-readable storage size of the history file.
    var historyStorageSize: String {
        controller.store.storageSizeString
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

    func renamePinGroup(from oldName: String, to newName: String) {
        controller.renamePinGroup(from: oldName, to: newName)
        pinGroups = controller.pinGroups
        selectedPinGroup = controller.selectedPinGroup
        items = controller.items
    }

    func movePinGroup(from source: IndexSet, to destination: Int) {
        controller.movePinGroup(from: source, to: destination)
        pinGroups = controller.pinGroups
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

    func performPasteAsPlainText(_ item: ClipboardItem) {
        selectedItemID = item.id
        floatingPanel?.performPasteAsPlainText(appState: self)
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
        UserDefaults.standard.set(historyRetentionDays, forKey: "historyRetentionDays")
        UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
    }

    private func loadSettings() {
        maxHistoryCount = UserDefaults.standard.integer(forKey: "maxHistoryCount")
        if maxHistoryCount == 0 { maxHistoryCount = 200 }
        historyRetentionDays = UserDefaults.standard.integer(forKey: "historyRetentionDays")
        launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
    }

    deinit {
        updateTimer?.invalidate()
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
