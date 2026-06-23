import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            shortcutsTab
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 420, height: 280)
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section("History") {
                Stepper("Maximum history: \(appState.maxHistoryCount) items",
                        value: $appState.maxHistoryCount,
                        in: 50...2000,
                        step: 50)

                HStack {
                    Text("Storage location:")
                        .foregroundColor(.secondary)
                    Text(historyPath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Button("Clear All History") {
                    appState.clearHistory()
                }
                .disabled(appState.items.isEmpty)
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: Binding(
                    get: { appState.launchAtLogin },
                    set: { newValue in
                        appState.launchAtLogin = newValue
                        toggleLaunchAtLogin(enabled: newValue)
                    }
                ))
            }
        }
        .padding()
    }

    // MARK: - Shortcuts

    private var shortcutsTab: some View {
        Form {
            Section("Global Hotkey") {
                HStack {
                    Image(systemName: "keyboard")
                    Text("Show / Hide clipboard history")
                    Spacer()
                    KeyboardShortcutView(key: "V", modifiers: ["⌥", "⌘"])
                }
                .padding(.vertical, 4)

                Text("Press ⌥⌘V anywhere to open the clipboard history overlay.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("In-App Shortcuts") {
                HStack {
                    Text("Double-click item")
                    Spacer()
                    Text("Copy & Paste")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(.vertical, 2)

                HStack {
                    Text("Right-click item")
                    Spacer()
                    Text("Context menu")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(.vertical, 2)
            }
        }
        .padding()
    }

    // MARK: - About

    private var aboutTab: some View {
        VStack(spacing: 12) {
            Image(systemName: "clipboard")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("LocalPaste")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Version 1.0.0")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("A local clipboard history manager.\nAll data stays on your machine.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private var historyPath: String {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory,
                                              in: .userDomainMask)
        return paths.first?.appendingPathComponent("LocalPaste/history.json").path ?? ""
    }

    private func toggleLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to toggle launch at login: \(error)")
            }
        }
    }
}

/// A simple visual representation of a keyboard shortcut.
struct KeyboardShortcutView: View {
    let key: String
    let modifiers: [String]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(modifiers, id: \.self) { mod in
                Text(mod)
                    .font(.caption)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(4)
            }
            Text(key.uppercased())
                .font(.caption)
                .fontWeight(.bold)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(4)
        }
    }
}
