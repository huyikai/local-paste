import SwiftUI
import AppKit
import Quartz

/// A floating, always-on-top panel that shows clipboard history when the
/// global hotkey (⌥⌘V) is pressed.
final class FloatingHistoryPanel: NSPanel {

    // MARK: - Properties

    private var appState: AppState?
    private var localEventMonitor: Any?
    /// The frontmost application before our panel appeared, so we can restore focus.
    private var previousAppBeforePanel: NSRunningApplication?
    /// Temporary file URL for Quick Look preview.
    private var tempPreviewURL: URL?

    // MARK: - Init

    init(appState: AppState) {
        let panelRect = NSRect(x: 0, y: 0, width: 420, height: 500)

        super.init(
            contentRect: panelRect,
            styleMask: [.nonactivatingPanel, .titled,
                        .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        self.appState = appState

        // Panel behavior
        self.isFloatingPanel = true
        self.level = .floating
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = true
        self.hidesOnDeactivate = false
        self.title = "LocalPaste"

        // Ensure it stays above other windows
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Content
        let contentView = HistoryPanelContentView().environmentObject(appState)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = panelRect
        self.contentView = hostingView

        // Notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: self
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResignKey(_:)),
            name: NSWindow.didResignKeyNotification,
            object: self
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: self
        )
    }

    // MARK: - Window lifecycle

    @objc func windowDidBecomeKey(_ notification: Notification) {
        installKeyboardMonitor()
        // Register as Quick Look data source for this panel
        QLPreviewPanel.shared().dataSource = self
    }

    @objc func windowDidResignKey(_ notification: Notification) {
        closeQuickLookIfNeeded()
        hide()
        appState?.clearSelection()
    }

    @objc func windowWillClose(_ notification: Notification) {
        cleanupTempPreview()
        removeKeyboardMonitor()
        appState?.clearSelection()
    }

    // MARK: - Keyboard monitor

    private func installKeyboardMonitor() {
        guard localEventMonitor == nil else { return }

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isKeyWindow else { return event }
            return self.handleKeyEvent(event)
        }
    }

    private func removeKeyboardMonitor() {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        guard let appState = appState else { return event }

        let keyCode = Int(event.keyCode)

        // ⌘⇧V — paste as plain text
        if keyCode == 9 && event.modifierFlags.contains([.command, .shift]) && !event.modifierFlags.contains(.option) {
            appState.pasteSelectedAsPlainText()
            hide()
            appState.clearSelection()
            return nil
        }

        switch keyCode {
        case 125: // Down arrow
            appState.selectNext()
            return nil
        case 126: // Up arrow
            appState.selectPrevious()
            return nil
        case 36: // Enter / Return
            performPaste(appState: appState)
            return nil
        case 49: // Space — Quick Look
            openQuickLook(appState: appState)
            return nil
        case 53: // Escape
            closeQuickLookIfNeeded()
            hide()
            appState.clearSelection()
            return nil
        default:
            return event
        }
    }

    private func performPaste(appState: AppState) {
        guard let id = appState.selectedItemID,
              let item = appState.items.first(where: { $0.id == id }) else { return }

        // 1. Write to pasteboard (also moves item to top)
        appState.copyItemToPasteboard(item)

        // 2. Hide panel immediately (no fade) so target app can receive events
        let previousApp = previousAppBeforePanel
        hideImmediately()
        appState.clearSelection()

        // 3. Restore focus to the previous app, then post ⌘V
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            previousApp?.activate(options: .activateIgnoringOtherApps)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.postCommandV()
            }
        }
    }

    private func postCommandV() {
        guard let targetApp = previousAppBeforePanel else { return }
        let pid = targetApp.processIdentifier
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.postToPid(pid)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.postToPid(pid)
    }

    // MARK: - Quick Look

    private func openQuickLook(appState: AppState) {
        guard let id = appState.selectedItemID,
              let item = appState.items.first(where: { $0.id == id }) else { return }

        // Build a temp file based on the dominant content type
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL: URL

        if item.image != nil, let pngData = item.data[UTType.png.identifier] {
            tempURL = tempDir.appendingPathComponent("localpaste-preview.png")
            try? pngData.write(to: tempURL)
        } else if let rtfData = item.rtfData {
            tempURL = tempDir.appendingPathComponent("localpaste-preview.rtf")
            try? rtfData.write(to: tempURL)
        } else if let htmlData = item.htmlData {
            tempURL = tempDir.appendingPathComponent("localpaste-preview.html")
            try? htmlData.write(to: tempURL)
        } else if let text = item.plainText {
            tempURL = tempDir.appendingPathComponent("localpaste-preview.txt")
            try? text.write(to: tempURL, atomically: true, encoding: .utf8)
        } else {
            return // No previewable content
        }

        tempPreviewURL = tempURL

        // Show Quick Look panel
        if QLPreviewPanel.shared().isVisible {
            QLPreviewPanel.shared().reloadData()
        } else {
            QLPreviewPanel.shared().makeKeyAndOrderFront(nil)
        }
    }

    private func closeQuickLookIfNeeded() {
        if QLPreviewPanel.shared().isVisible {
            QLPreviewPanel.shared().orderOut(nil)
        }
        cleanupTempPreview()
    }

    private func cleanupTempPreview() {
        if let url = tempPreviewURL {
            try? FileManager.default.removeItem(at: url)
            tempPreviewURL = nil
        }
    }

    // MARK: - Quick Look data source conformance

    // MARK: - Actions

    /// Show the panel at the center of the screen.
    func show() {
        // Save the currently active app so we can restore focus when pasting
        previousAppBeforePanel = NSWorkspace.shared.frontmostApplication

        center()
        alphaValue = 0
        makeKeyAndOrderFront(nil)

        // Fade in
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1.0
        }

        // NOTE: do NOT call NSApp.activate here — the panel uses
        // .nonactivatingPanel style so it can receive keyboard events
        // without stealing focus from the app the user was working in.

        // Select first item after a short delay to ensure UI is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.appState?.selectFirstItem()
        }
    }

    /// Hide the panel (with fade animation).
    func hide() {
        hide(animated: true)
    }

    /// Hide the panel immediately without animation (used before paste).
    func hideImmediately() {
        hide(animated: false)
    }

    private func hide(animated: Bool) {
        closeQuickLookIfNeeded()

        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.12
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                self.animator().alphaValue = 0.0
            } completionHandler: {
                self.orderOut(nil)
            }
        } else {
            orderOut(nil)
        }

        removeKeyboardMonitor()
    }

    /// Toggle visibility.
    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    // MARK: - Cleanup

    deinit {
        removeKeyboardMonitor()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Quick Look data source

extension FloatingHistoryPanel: QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        tempPreviewURL != nil ? 1 : 0
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        tempPreviewURL as QLPreviewItem?
    }

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        return true
    }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = self
        panel.delegate = self
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        cleanupTempPreview()
    }
}

/// SwiftUI content inside the floating panel.
struct HistoryPanelContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            SearchBarView(text: $searchText)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .onChange(of: searchText) { newValue in
                    appState.searchQuery = newValue
                    appState.selectFirstItem()
                }

            Divider()

            ScrollViewReader { proxy in
                List(selection: $appState.selectedItemIDs) {
                    ForEach(appState.filteredItems) { item in
                        ItemRowView(item: item)
                            .environmentObject(appState)
                            .id(item.id)
                            .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                            .listRowSeparator(.hidden)
                    }
                    .onMove(perform: appState.moveItems)
                }
                .listStyle(.plain)
                .onChange(of: appState.selectedItemID) { newID in
                    guard let id = newID else { return }
                    withAnimation {
                        proxy.scrollTo(id, anchor: .center)
                    }
                    appState.selectedItemIDs = [id]
                }
            }

            Divider()

            // Footer
            HStack {
                Text("\(appState.filteredItems.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if appState.selectedItemIDs.count > 1 {
                    Button(action: { appState.deleteSelectedItems() }) {
                        Label("Delete \(appState.selectedItemIDs.count)", systemImage: "trash")
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                } else {
                    Text("↑↓ move  ⏎ paste  esc close")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Clear") { appState.clearHistory() }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .disabled(appState.items.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(minWidth: 400, minHeight: 400)
    }
}
