import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label(loc("tab.general"), systemImage: "gearshape")
                }
            groupsTab
                .tabItem {
                    Label(loc("tab.groups"), systemImage: "bookmark")
                }
            shortcutsTab
                .tabItem {
                    Label(loc("tab.shortcuts"), systemImage: "keyboard")
                }
        }
        .frame(width: 420, height: 300)
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section {
                Stepper(loc("settings.max.history", appState.maxHistoryCount),
                        value: $appState.maxHistoryCount,
                        in: 50...2000,
                        step: 50)

                HStack {
                    Text(loc("settings.storage.location"))
                        .foregroundColor(.secondary)
                    Text(historyPath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Button(loc("settings.clear.all")) {
                    appState.clearHistory()
                }
                .disabled(appState.items.isEmpty)

                HStack(spacing: 8) {
                    Button(loc("settings.export")) {
                        exportHistory()
                    }
                    .disabled(appState.items.isEmpty)

                    Button(loc("settings.import")) {
                        importHistory()
                    }
                }
            } header: {
                Text(loc("section.history"))
            }

            Section {
                Toggle(isOn: Binding(
                    get: { appState.launchAtLogin },
                    set: { newValue in
                        appState.launchAtLogin = newValue
                        toggleLaunchAtLogin(enabled: newValue)
                    }
                )) {
                    Text(loc("settings.launch.at.login"))
                }
            } header: {
                Text(loc("section.startup"))
            }

            Section {
                Picker(selection: languageBinding, label: Text(loc("settings.language"))) {
                    ForEach(LocalizationService.Language.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text(loc("settings.language"))
            }
        }
        .padding()
    }

    private var languageBinding: Binding<LocalizationService.Language> {
        Binding(
            get: { LocalizationService.shared.selectedLanguage },
            set: { newValue in
                if newValue != LocalizationService.shared.selectedLanguage {
                    LocalizationService.shared.applyLanguage(newValue)
                }
            }
        )
    }

    // MARK: - Groups

    private var groupsTab: some View {
        Form {
            Section {
                if appState.pinGroups.isEmpty {
                    Text(loc("settings.no.groups"))
                        .foregroundColor(.secondary)
                        .font(.caption)
                } else {
                    ForEach(appState.pinGroups, id: \.self) { group in
                        HStack {
                            Image(systemName: "bookmark")
                                .foregroundColor(.accentColor)
                            Text(group)
                            Spacer()
                            Text(loc("items.count", appState.items.filter { $0.pinGroup == group }.count))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Button(action: { appState.deletePinGroup(group) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help(loc("delete.group"))
                        }
                        .padding(.vertical, 2)
                    }
                }
            } header: {
                Text(loc("section.pin.groups"))
            }
        }
        .padding()
    }

    // MARK: - Shortcuts

    private var shortcutsTab: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "keyboard")
                    Text(loc("settings.show.hide"))
                    Spacer()
                    // HotKeyManager is lazy-initialized via AppState
                    HotKeyRecorderView(
                        currentDescription: appState.hotKeyManager.currentDescription,
                        onRecord: { keyCode, modifiers in
                            appState.hotKeyManager.save(keyCode: keyCode, modifiers: modifiers)
                            appState.hotKeyManager.reload()
                        }
                    )
                }
                .padding(.vertical, 4)

                Text(loc("settings.hotkey.hint"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text(loc("section.global.hotkey"))
            }

            Section {
                HStack {
                    Text(loc("settings.double.click"))
                    Spacer()
                    Text(loc("settings.copy.paste"))
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(.vertical, 2)

                HStack {
                    Text(loc("settings.right.click"))
                    Spacer()
                    Text(loc("settings.context.menu"))
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(.vertical, 2)
            } header: {
                Text(loc("section.inapp.shortcuts"))
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

            Text(loc("app.name"))
                .font(.title2)
                .fontWeight(.semibold)

            Text(loc("settings.version"))
                .font(.caption)
                .foregroundColor(.secondary)

            Text(loc("settings.about.description"))
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
                print("SettingsView: failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
            }
        }
    }

    // MARK: - Export / Import

    /// Export all history to a JSON file via NSSavePanel.
    private func exportHistory() {
        let panel = NSSavePanel()
        panel.title = loc("export.title")
        panel.nameFieldStringValue = "LocalPaste-history.json"
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let store = HistoryStore(maxItems: appState.maxHistoryCount)
        guard let data = store.exportJSON(appState.items) else { return }

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            print("SettingsView: export failed: \(error)")
        }
    }

    /// Import history from a JSON file via NSOpenPanel.
    private func importHistory() {
        let panel = NSOpenPanel()
        panel.title = loc("import.title")
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let store = HistoryStore(maxItems: appState.maxHistoryCount)
        guard let data = try? Data(contentsOf: url),
              let imported = store.importJSON(from: data),
              !imported.isEmpty else {
            // Show alert for invalid file
            let alert = NSAlert()
            alert.messageText = loc("import.invalid.title")
            alert.informativeText = loc("import.invalid.message")
            alert.runModal()
            return
        }

        // Confirm before merging
        let alert = NSAlert()
        alert.messageText = loc("import.confirm.title")
        alert.informativeText = loc("import.confirm.message", imported.count)
        alert.addButton(withTitle: loc("import.confirm.import"))
        alert.addButton(withTitle: loc("import.confirm.cancel"))

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        // Merge: insert imported items (dedup by data content)
        for item in imported {
            appState.insertItem(item)
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
