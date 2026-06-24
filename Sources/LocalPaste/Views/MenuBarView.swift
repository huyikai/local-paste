import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            SearchBarView(text: $appState.searchQuery)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()

            // History list
            HistoryListView()

            Divider()

            // Footer actions
            HStack {
                Button(action: { appState.clearHistory() }) {
                    Label("Clear History", systemImage: "trash")
                }
                .buttonStyle(.plain)
                .disabled(appState.items.isEmpty)

                Spacer()

                Button(action: { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) }) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)

                Button(action: quitApp) {
                    Image(systemName: "power")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(width: 360, height: 480)
    }

    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
