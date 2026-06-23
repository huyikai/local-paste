import Foundation
import AppKit

/// Polls the system pasteboard on a configurable interval and notifies
/// the delegate when new content is available.
///
/// NSPasteboard does not provide a native callback mechanism, so polling
/// `changeCount` is the standard approach used by all clipboard managers.
final class PasteboardMonitor {

    // MARK: - Types

    protocol Delegate: AnyObject {
        func pasteboardMonitor(_ monitor: PasteboardMonitor, didCapture item: ClipboardItem)
        func pasteboardMonitorDidDetectOwnWrite(_ monitor: PasteboardMonitor)
    }

    // MARK: - Properties

    weak var delegate: Delegate?

    private let pasteboardManager: PasteboardManager
    private var timer: Timer?
    private let interval: TimeInterval

    /// Whether the monitor is currently polling.
    private(set) var isRunning = false

    // MARK: - Init

    init(pasteboardManager: PasteboardManager,
         interval: TimeInterval = 0.5) {
        self.pasteboardManager = pasteboardManager
        self.interval = interval
    }

    // MARK: - Start / Stop

    func start() {
        guard !isRunning else { return }

        isRunning = true

        // Do an initial capture to populate history
        if let item = pasteboardManager.forceCapture() {
            delegate?.pasteboardMonitor(self, didCapture: item)
        }

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }

        // Ensure the timer fires even during scroll events / menu tracking
        RunLoop.current.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    // MARK: - Polling

    private func checkPasteboard() {
        // If the pasteboard hasn't changed, do nothing
        guard pasteboardManager.hasChanged else { return }

        // Try to capture the content
        if let item = pasteboardManager.captureCurrentContent() {
            delegate?.pasteboardMonitor(self, didCapture: item)
        } else {
            // The change was from our own write — no action needed
            delegate?.pasteboardMonitorDidDetectOwnWrite(self)
        }
    }

    // MARK: - Cleanup

    deinit {
        stop()
    }
}
