import Foundation

enum SourceMode: String, CaseIterable, Codable, Identifiable {
    case automatic, manual
    var id: String { rawValue }
    var title: String { self == .automatic ? "Automatisk Codex" : "Manuel indtastning" }
}

enum ThemeChoice: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self { case .system: "Følg systemet"; case .light: "Lyst"; case .dark: "Mørkt" }
    }
}

@MainActor
struct PreferencesStore {
    let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    var selectedProduct: MonitoredProduct {
        get { MonitoredProduct(rawValue: defaults.string(forKey: "selectedProduct") ?? "") ?? .codex }
        nonmutating set { defaults.set(newValue.rawValue, forKey: "selectedProduct") }
    }
    var miniLayout: Bool {
        get { defaults.bool(forKey: "miniLayout") }
        nonmutating set { defaults.set(newValue, forKey: "miniLayout") }
    }
    var alwaysOnTop: Bool {
        get { defaults.bool(forKey: "alwaysOnTop") }
        nonmutating set { defaults.set(newValue, forKey: "alwaysOnTop") }
    }
    var refreshInterval: Int {
        get { min(60, max(1, defaults.object(forKey: "refreshInterval") as? Int ?? 5)) }
        nonmutating set { defaults.set(newValue, forKey: "refreshInterval") }
    }
    var theme: ThemeChoice {
        get { ThemeChoice(rawValue: defaults.string(forKey: "theme") ?? "") ?? .system }
        nonmutating set { defaults.set(newValue.rawValue, forKey: "theme") }
    }
    var cliPath: String {
        get { defaults.string(forKey: "cliPath") ?? "" }
        nonmutating set { defaults.set(newValue, forKey: "cliPath") }
    }
    func mode(for product: MonitoredProduct) -> SourceMode {
        SourceMode(rawValue: defaults.string(forKey: "mode.\(product.rawValue)") ?? "")
            ?? (product == .codex ? .automatic : .manual)
    }
    func saveMode(_ mode: SourceMode, for product: MonitoredProduct) {
        defaults.set(mode.rawValue, forKey: "mode.\(product.rawValue)")
    }
    func group(for product: MonitoredProduct, mode: SourceMode) -> String {
        defaults.string(forKey: "group.\(product.rawValue).\(mode.rawValue)") ?? "default"
    }
    func saveGroup(_ group: String, for product: MonitoredProduct, mode: SourceMode) {
        defaults.set(group, forKey: "group.\(product.rawValue).\(mode.rawValue)")
    }
    func snapshots(for product: MonitoredProduct, mode: SourceMode, markStale: Bool = true) -> [QuotaSnapshot] {
        guard let data = defaults.data(forKey: "snapshots.v1.\(product.rawValue).\(mode.rawValue)"),
              var values = try? JSONDecoder().decode([QuotaSnapshot].self, from: data) else { return [] }
        values = values.filter { $0.product == product }
        if markStale && mode == .automatic {
            for group in values.indices {
                for period in values[group].periods.indices {
                    if values[group].periods[period].updatedAt != nil {
                        values[group].periods[period].status = .stale
                    }
                }
            }
        }
        return values
    }
    func saveSnapshots(_ snapshots: [QuotaSnapshot], for product: MonitoredProduct, mode: SourceMode) throws {
        let safe = snapshots.filter { $0.product == product && !$0.periods.contains(where: { $0.source == .development }) }
        defaults.set(try JSONEncoder().encode(safe), forKey: "snapshots.v1.\(product.rawValue).\(mode.rawValue)")
    }
}
