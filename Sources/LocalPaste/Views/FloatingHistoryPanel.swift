import SwiftUI
import AppKit
import Combine

/// A floating, always-on-top panel that shows clipboard history when the
/// global hotkey (⌥⌘V) is pressed.
final class FloatingHistoryPanel: NSPanel {

    // MARK: - Properties

    private var appState: AppState?
    private var localEventMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

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
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: self
        )
    }

    // MARK: - Window lifecycle

    @objc private func windowDidBecomeKey(_ notification: Notification) {
        installKeyboardMonitor()
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
            appState.pasteSelected()
            return nil
        case 53: // Escape
            hide()
            appState.clearSelection()
            return nil
        default:
            return event
        }
    }

    // MARK: - Actions

    /// Show the panel at the center of the screen.
    func show() {
        center()
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

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
