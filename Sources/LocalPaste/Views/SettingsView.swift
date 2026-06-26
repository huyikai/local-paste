import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    @State private var groupToDelete: String? = nil
    @State private var showRenameAlert = false
    @State private var renameTarget: String = ""
    @State private var renameText: String = ""
    @State private var newGroupName: String = ""
    @State private var deleteOlderThanDays: Int = 7

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
            aboutTab
                .tabItem {
                    Label(loc("tab.about"), systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 380)
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section {
                Stepper(loc("settings.max.history", appState.maxHistoryCount),
                        value: $appState.maxHistoryCount,
                        in: 50...2000,
                        step: 50)

                Picker(loc("settings.retention"), selection: $appState.historyRetentionDays) {
                    Text(loc("settings.retention.forever")).tag(0)
                    Text(loc("settings.retention.days", 1)).tag(1)
                    Text(loc("settings.retention.days", 7)).tag(7)
                    Text(loc("settings.retention.days", 30)).tag(30)
                    Text(loc("settings.retention.days", 90)).tag(90)
                    Text(loc("settings.retention.days", 365)).tag(365)
                }
                .pickerStyle(.menu)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(loc("settings.storage.location"))
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Spacer()
                        Text(appState.historyStorageSize)
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                    }
                    Text(historyPath)
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                        .padding(6)
                        .background(Color(.textBackgroundColor).opacity(0.5))
                        .cornerRadius(4)
                }

                Divider()

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

                Divider()

                HStack {
                    Picker(loc("settings.delete.older.than"), selection: $deleteOlderThanDays) {
                        Text(loc("settings.retention.days", 1)).tag(1)
                        Text(loc("settings.retention.days", 7)).tag(7)
                        Text(loc("settings.retention.days", 30)).tag(30)
                        Text(loc("settings.retention.days", 90)).tag(90)
                        Text(loc("settings.retention.days", 365)).tag(365)
                    }
                    .pickerStyle(.menu)

                    Button(loc("settings.delete.older.than.confirm")) {
                        appState.clearHistoryOlderThan(days: deleteOlderThanDays)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(appState.items.isEmpty)
                }
            } header: {
                Label(loc("section.history"), systemImage: "clock.arrow.circlepath")
            }

            Section {
                Toggle(isOn: Binding(
                    get: { appState.launchAtLogin },
                    set: { newValue in
                        appState.launchAtLogin = newValue
                        toggleLaunchAtLogin(enabled: newValue)
                    }
                )) {
                    Label(loc("settings.launch.at.login"), systemImage: "power")
                }
            } header: {
                Label(loc("section.startup"), systemImage: "bolt")
            }

            Section {
                Picker(selection: languageBinding, label: Label(loc("settings.language"), systemImage: "globe")) {
                    ForEach(LocalizationService.Language.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Label(loc("settings.language"), systemImage: "globe")
            }
        }
        .formStyle(.grouped)
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
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Image(systemName: "bookmark.slash")
                                .font(.largeTitle)
                                .foregroundColor(.secondary.opacity(0.5))
                            Text(loc("settings.no.groups"))
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .padding(.vertical, 12)
                        Spacer()
                    }
                } else {
                    ForEach(Array(appState.pinGroups.enumerated()), id: \.element) { index, group in
                        HStack(spacing: 6) {
                            Image(systemName: "bookmark.fill")
                                .foregroundColor(.accentColor)
                                .frame(width: 16)
                            Text(group)
                                .fontWeight(.medium)
                            Spacer()
                            Text(loc("items.count", appState.items.filter { $0.pinGroup == group }.count))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.separatorColor).opacity(0.15))
                                .cornerRadius(4)
                            Divider()
                                .frame(height: 16)
                            HStack(spacing: 2) {
                                Button(action: {
                                    renameTarget = group
                                    renameText = group
                                    showRenameAlert = true
                                }) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 11))
                                }
                                .buttonStyle(.plain)
                                .help(loc("rename.group"))
                                if index > 0 {
                                    Button(action: { moveGroupUp(at: index) }) {
                                        Image(systemName: "chevron.up")
                                            .font(.system(size: 11))
                                    }
                                    .buttonStyle(.plain)
                                    .help(loc("move.group.up"))
                                }
                                if index < appState.pinGroups.count - 1 {
                                    Button(action: { moveGroupDown(at: index) }) {
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 11))
                                    }
                                    .buttonStyle(.plain)
                                    .help(loc("move.group.down"))
                                }
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color(.controlBackgroundColor))
                            .cornerRadius(4)
                            Button(role: .destructive, action: { groupToDelete = group }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help(loc("delete.group"))
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 2)
                    }
                }
            } header: {
                Label(loc("section.pin.groups"), systemImage: "bookmark")
            }

            Section {
                HStack(spacing: 8) {
                    TextField(loc("pin.new.group"), text: $newGroupName)
                        .textFieldStyle(.roundedBorder)
                    Button(loc("pin.add")) {
                        let name = newGroupName.trimmingCharacters(in: .whitespaces)
                        guard !name.isEmpty, !appState.pinGroups.contains(name) else { return }
                        appState.pinGroups.append(name)
                        newGroupName = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Label(loc("settings.create.group"), systemImage: "plus.square")
            }
        }
        .formStyle(.grouped)
        .alert(loc("rename.group.title"), isPresented: $showRenameAlert) {
            TextField(loc("rename.group.placeholder"), text: $renameText)
            Button(loc("rename.group.confirm")) {
                let trimmed = renameText.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty, trimmed != renameTarget {
                    appState.renamePinGroup(from: renameTarget, to: trimmed)
                }
            }
            Button(loc("confirm.cancel"), role: .cancel) { }
        } message: {
            Text(loc("rename.group.message", renameTarget))
        }
        .confirmationDialog(
            loc("delete.group.confirm.title"),
            isPresented: Binding(
                get: { groupToDelete != nil },
                set: { if !$0 { groupToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(loc("delete.group.confirm"), role: .destructive) {
                if let group = groupToDelete {
                    appState.deletePinGroup(group)
                }
                groupToDelete = nil
            }
            Button(loc("confirm.cancel"), role: .cancel) {
                groupToDelete = nil
            }
        } message: {
            if let group = groupToDelete {
                Text(loc("delete.group.confirm.message", group))
            }
        }
    }

    private func moveGroupUp(at index: Int) {
        appState.movePinGroup(from: IndexSet(integer: index), to: index - 1)
    }

    private func moveGroupDown(at index: Int) {
        appState.movePinGroup(from: IndexSet(integer: index), to: index + 2)
    }

    // MARK: - Shortcuts

    private var shortcutsTab: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "keyboard")
                        .foregroundColor(.accentColor)
                    Text(loc("settings.show.hide"))
                    Spacer()
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
                Label(loc("section.global.hotkey"), systemImage: "command")
            }

            Section {
                HStack {
                    Label(loc("settings.double.click"), systemImage: "cursorarrow.rays")
                    Spacer()
                    Text(loc("settings.copy.paste"))
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(.vertical, 2)

                HStack {
                    Label(loc("settings.right.click"), systemImage: "cursorarrow")
                    Spacer()
                    Text(loc("settings.context.menu"))
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(.vertical, 2)
            } header: {
                Label(loc("section.inapp.shortcuts"), systemImage: "menubar.rectangle")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - About

    private var aboutTab: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "clipboard")
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)

                    Text(loc("app.name"))
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(appVersion)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(loc("settings.about.description"))
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section {
                VStack(spacing: 8) {
                    Button(loc("settings.check.updates")) {
                        checkForUpdates()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .disabled(appState.updateCheckResult == .checking)

                    switch appState.updateCheckResult {
                    case .checking:
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text(loc("update.checking"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    case .upToDate:
                        Text(loc("update.up.to.date"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    case .newVersion(let version, let url):
                        HStack(spacing: 4) {
                            Text(loc("update.found", version))
                                .font(.caption)
                                .foregroundColor(.accentColor)
                            Button(loc("update.download")) {
                                NSWorkspace.shared.open(url)
                            }
                            .buttonStyle(.link)
                            .font(.caption)
                        }
                    case .error(let message):
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                Button(loc("settings.github")) {
                    openGitHub()
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .frame(maxWidth: .infinity)
            }
        }
        .formStyle(.grouped)
    }

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return loc("settings.version.format", short, build)
    }

    private func checkForUpdates() {
        Task { @MainActor in
            await appState.checkForUpdates()
        }
    }

    private func openGitHub() {
        guard let url = URL(string: "https://github.com/huyikai/local-paste") else { return }
        NSWorkspace.shared.open(url)
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
