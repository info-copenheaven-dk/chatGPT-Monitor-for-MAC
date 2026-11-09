import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct QuotaMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var store: QuotaStore

    init() {
        #if DEBUG
        if CommandLine.arguments.contains("--demo") {
            let demoPreferences = PreferencesStore(defaults: UserDefaults(suiteName: "dk.local.chatgpt-monitor.demo")!)
            _store = StateObject(wrappedValue: QuotaStore(source: DevelopmentQuotaDataSource(), preferences: demoPreferences))
            return
        }
        #endif
        let preferences = PreferencesStore()
        _store = StateObject(wrappedValue: QuotaStore(
            source: ManualQuotaDataSource(persistence: preferences), preferences: preferences,
            automaticSource: CodexQuotaDataSource(path: preferences.cliPath), persistData: true))
    }

    var body: some Scene {
        Window("ChatGPT-forbrug", id: "main") {
            ContentView(store: store)
        }
        .windowResizability(.contentSize)
    }
}
