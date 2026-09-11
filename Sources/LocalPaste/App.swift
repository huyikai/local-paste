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

extension Notification.Name {
    /// Posted by AppState.init once the singleton exists. AppDelegate must
    /// subscribe lazily because @StateObject initializes on first body
    /// evaluation, which may happen after applicationDidFinishLaunching.
    static let appStateDidBecomeAvailable = Notification.Name("appStateDidBecomeAvailable")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var cancellable: AnyCancellable?
    /// Strong ref for the lifetime of the process; AppState.shared itself
    /// stays weak so views/tests can hold their own instances.
    private var appState: AppState?

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

        // The singleton may already exist (body evaluated first) or may
        /// appear later — handle both orders.
        if let appState = AppState.shared {
            subscribeToBadge(appState)
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(appStateDidBecomeAvailable),
            name: .appStateDidBecomeAvailable, object: nil
        )
    }

    @objc private func appStateDidBecomeAvailable(_ notification: Notification) {
        guard let appState = notification.object as? AppState else { return }
        subscribeToBadge(appState)
    }

    private func subscribeToBadge(_ appState: AppState) {
        guard cancellable == nil else { return }
        self.appState = appState
        cancellable = appState.$items.sink { [weak self] items in
            let count = items.count
            self?.statusItem.button?.title = count > 0 ? " \(count)" : ""
        }
    }

    @objc private func statusBarClicked() {
        appState?.toggleFloatingPanel()
    }
}
