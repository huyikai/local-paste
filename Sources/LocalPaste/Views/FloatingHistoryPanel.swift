import SwiftUI
import AppKit

/// A floating, always-on-top panel that shows clipboard history when the
/// global hotkey (⌥⌘V) is pressed.
final class FloatingHistoryPanel: NSPanel {

    // MARK: - Properties

    private var appState: AppState?
    private var localEventMonitor: Any?
    /// The frontmost application before our panel appeared, so we can restore focus.
    private var previousAppBeforePanel: NSRunningApplication?

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

    @objc private func windowDidBecomeKey(_ notification: Notification) {
        installKeyboardMonitor()
    }

    @objc private func windowDidResignKey(_ notification: Notification) {
        hide()
        appState?.clearSelection()
    }

    @objc private func windowWillClose(_ notification: Notification) {
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

        switch Int(event.keyCode) {
        case 125: // Down arrow
            appState.selectNext()
            return nil
        case 126: // Up arrow
            appState.selectPrevious()
            return nil
        case 36: // Enter / Return
            performPaste(appState: appState)
            return nil
        case 53: // Escape
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

        // 2. Hide the panel
        let previousApp = previousAppBeforePanel
        hide()
        appState.clearSelection()

        // 3. Restore focus to the previous app, then post ⌘V
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            previousApp?.activate(options: .activateIgnoringOtherApps)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                self.postCommandV()
            }
        }
    }

    private func postCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }

    // MARK: - Actions

    /// Show the panel at the center of the screen.
    func show() {
        // Save the currently active app so we can restore focus when pasting
        previousAppBeforePanel = NSWorkspace.shared.frontmostApplication

        center()
        makeKeyAndOrderFront(nil)
        // NOTE: do NOT call NSApp.activate here — the panel uses
        // .nonactivatingPanel style so it can receive keyboard events
        // without stealing focus from the app the user was working in.

        // Select first item after a short delay to ensure UI is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.appState?.selectFirstItem()
        }
    }

    /// Hide the panel.
    func hide() {
        orderOut(nil)
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
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(appState.filteredItems) { item in
                            ItemRowView(item: item)
                                .environmentObject(appState)
                                .id(item.id)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onChange(of: appState.selectedItemID) { newID in
                    guard let id = newID else { return }
                    withAnimation {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }

            Divider()

            // Footer
            HStack {
                Text("\(appState.filteredItems.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("↑↓ move  ⏎ paste  esc close")
                    .font(.caption2)
                    .foregroundColor(.secondary)
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
