import SwiftUI
import AppKit

/// A floating, always-on-top panel that shows clipboard history when the
/// global hotkey (⌥⌘V) is pressed.
final class FloatingHistoryPanel: NSPanel {

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

        // Panel behavior
        self.isFloatingPanel = true
        self.level = .floating
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = true
        self.hidesOnDeactivate = false

        // Ensure it stays above other windows
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Content
        let hostingView = NSHostingView(rootView: HistoryPanelContentView().environmentObject(appState))
        hostingView.frame = panelRect
        self.contentView = hostingView

        // Close when focus is lost (e.g., clicking elsewhere)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResignKey(_:)),
            name: NSWindow.didResignKeyNotification,
            object: self
        )
    }

    // MARK: - Actions

    /// Show the panel at the center of the screen.
    func show() {
        center()
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Hide the panel.
    func hide() {
        orderOut(nil)
    }

    /// Toggle visibility.
    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    // MARK: - Notification

    @objc private func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    deinit {
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
                }

            Divider()

            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(appState.filteredItems) { item in
                        ItemRowView(item: item)
                            .environmentObject(appState)
                    }
                }
                .padding(.vertical, 4)
            }

            Divider()

            // Footer
            HStack {
                Text("\(appState.filteredItems.count) items")
                    .font(.caption)
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
