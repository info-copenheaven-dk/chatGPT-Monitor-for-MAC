import AppKit
import SwiftUI

/// Keeps the saved origin visible after monitor changes, without restoring an obsolete content size.
@MainActor
struct WindowStateReader: NSViewRepresentable {
    let alwaysOnTop: Bool
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ view: NSView, context: Context) {
        let coordinator = context.coordinator
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            coordinator.attach(window)
            window.level = alwaysOnTop ? .floating : .normal
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        private weak var window: NSWindow?
        private var restored = false
        private var preferences: UserDefaults {
            UserDefaults(suiteName: "dk.local.chatgpt-monitor.window")!
        }
        func attach(_ window: NSWindow) {
            guard self.window !== window else { return }
            NotificationCenter.default.removeObserver(self)
            self.window = window
            if !restored {
                restored = true
                if let data = preferences.array(forKey: "origin") as? [Double], data.count == 2,
                   data.allSatisfy(\.isFinite) {
                    window.setFrameOrigin(NSPoint(x: data[0], y: data[1]))
                }
                clamp()
            }
            NotificationCenter.default.addObserver(self, selector: #selector(moved), name: NSWindow.didMoveNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSWindow.didResizeNotification, object: window)
        }
        @objc private func moved() {
            guard let window else { return }
            preferences.set([Double(window.frame.minX), Double(window.frame.minY)], forKey: "origin")
        }
        @objc private func screenChanged() { clamp(); moved() }
        private func clamp() {
            guard let window else { return }
            let screens = NSScreen.screens.map(\.visibleFrame)
            let rect = WindowPlacement.visibleFrame(window.frame, screens: screens)
            window.setFrameOrigin(rect.origin)
        }
        deinit { NotificationCenter.default.removeObserver(self) }
    }
}
