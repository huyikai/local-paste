import SwiftUI

@main
struct LocalPasteApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            if appState.items.isEmpty {
                Image(systemName: "clipboard")
            } else {
                HStack(spacing: 1) {
                    Image(systemName: "clipboard")
                    Text("\(min(appState.items.count, 99))")
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                }
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
