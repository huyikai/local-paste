import SwiftUI
import AppKit
import Combine

@main
struct LocalPasteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var cancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "clipboard",
                accessibilityDescription: "LocalPaste"
            )
            button.target = self
            button.action = #selector(statusBarClicked)
        }

        // Update badge when item count changes
        cancellable = AppState.shared?.$items.sink { [weak self] items in
            let count = items.count
            self?.statusItem.button?.title = count > 0 ? " \(count)" : ""
        }
    }

    @objc private func statusBarClicked() {
        AppState.shared?.toggleFloatingPanel()
    }
}
