import Combine
import Foundation

@MainActor
final class QuotaStore: ObservableObject {
    @Published var selectedProduct: MonitoredProduct {
        didSet {
            preferences.selectedProduct = selectedProduct
            sourceMode = automaticSource == nil ? .manual : preferences.mode(for: selectedProduct)
            restoreSelection()
        }
    }
    @Published var sourceMode: SourceMode {
        didSet { preferences.saveMode(sourceMode, for: selectedProduct); restoreSelection() }
    }
    @Published var selectedGroupID = "default" {
        didSet { preferences.saveGroup(selectedGroupID, for: selectedProduct, mode: sourceMode) }
    }
    @Published private(set) var groups: [QuotaSnapshot] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var nextRefreshAt: Date?
    @Published var alwaysOnTop = false { didSet { preferences.alwaysOnTop = alwaysOnTop } }
    @Published var miniLayout: Bool { didSet { preferences.miniLayout = miniLayout } }
    @Published var theme: ThemeChoice { didSet { preferences.theme = theme } }
    @Published var cliPath: String {
        didSet { preferences.cliPath = cliPath; automaticSource?.executablePath = cliPath }
    }
    @Published private(set) var loginMessage: String?
    @Published var refreshInterval = 5 {
        didSet {
            let clamped = min(60, max(1, refreshInterval))
            if refreshInterval != clamped { refreshInterval = clamped; return }
            preferences.refreshInterval = refreshInterval
            var policy = policies[selectedProduct] ?? RefreshPolicy()
            policy.reschedule(at: now(), interval: Double(refreshInterval) * 60,
                              minimum: source.capabilities.minimumRefreshSeconds)
            policies[selectedProduct] = policy
            nextRefreshAt = policy.nextRefreshAt
        }
    }
    private let defaultSource: any QuotaDataSource
    private let automaticSource: CodexQuotaDataSource?
    private let persistData: Bool
    var source: any QuotaDataSource {
        if selectedProduct == .codex, sourceMode == .automatic, let automaticSource { return automaticSource }
        return defaultSource
    }
    var selectionKey: String { selectedProduct.rawValue + ":" + sourceMode.rawValue }
    var supportsAutomatic: Bool { automaticSource != nil && selectedProduct == .codex }
    private let preferences: PreferencesStore
    private let now: () -> Date
    private let sleep: (TimeInterval) async throws -> Void
    private var policies: [MonitoredProduct: RefreshPolicy] = [:]
    var snapshot: QuotaSnapshot {
        groups.first { $0.product == selectedProduct && $0.groupID == selectedGroupID }
            ?? .empty(for: selectedProduct, sourceLabel: source.label)
    }

    init(source: any QuotaDataSource, preferences: PreferencesStore = PreferencesStore(),
         automaticSource: CodexQuotaDataSource? = nil, persistData: Bool = false,
         now: @escaping () -> Date = Date.init,
         sleep: @escaping (TimeInterval) async throws -> Void = { seconds in
             try await Task.sleep(for: .seconds(seconds))
         }) {
        self.defaultSource = source; self.preferences = preferences
        self.automaticSource = automaticSource; self.persistData = persistData
        self.now = now; self.sleep = sleep
        selectedProduct = preferences.selectedProduct
        sourceMode = automaticSource == nil ? .manual : preferences.mode(for: preferences.selectedProduct)
        cliPath = preferences.cliPath
        miniLayout = preferences.miniLayout
        theme = preferences.theme
        alwaysOnTop = preferences.alwaysOnTop
        refreshInterval = preferences.refreshInterval
        automaticSource?.executablePath = preferences.cliPath
        restoreSelection()
        automaticSource?.loginCompleted = { [weak self] in
            self?.loginMessage = "Login gennemført."
            self?.policies.removeValue(forKey: .codex)
            Task { await self?.load() }
        }
    }

    /// A single fetch pipeline is shared by startup, manual, scheduled, reset and wake triggers.
    func load() async {
        guard !isLoading else { return }
        let product = selectedProduct
        let key = selectionKey
        let source = self.source
        preferences.selectedProduct = product
        if groups.first?.product != product { groups = []; selectedGroupID = "default" }
        var policy = policies[product] ?? RefreshPolicy()
        if source.capabilities.canRefresh, !policy.canAttempt(at: now()) {
            nextRefreshAt = policy.notBefore
            return
        }
        isLoading = true; errorMessage = nil
        defer {
            isLoading = false
            if selectionKey != key {
                Task { await self.load() }
            }
        }
        for attempt in 0..<3 {
            guard !Task.isCancelled, selectionKey == key else { return }
            if source.capabilities.canRefresh {
                policy.started(at: now(), interval: Double(refreshInterval) * 60,
                               minimum: source.capabilities.minimumRefreshSeconds)
                policies[product] = policy
                nextRefreshAt = policy.nextRefreshAt
            }
            do {
                let result = try await source.fetch(for: product)
                guard !Task.isCancelled, selectionKey == key else { return }
                groups = result.filter { $0.product == product }
                if !groups.contains(where: { $0.groupID == selectedGroupID }) {
                    selectedGroupID = groups.first?.groupID ?? "default"
                }
                errorMessage = nil
                persistCurrent()
                return
            } catch {
                guard !Task.isCancelled, selectionKey == key else { return }
                markStale()
                if case QuotaFetchError.authenticationRequired = error {
                    errorMessage = "Log ind igen for at hente nye kvoter."
                } else {
                    errorMessage = "Opdatering mislykkedes. Seneste kendte værdier er bevaret."
                }
                guard source.capabilities.canRefresh,
                      let delay = QuotaFetchError.retryDelay(for: error, attempt: attempt) else { return }
                let wait = max(delay, source.capabilities.minimumRefreshSeconds)
                policy.deferUntil(now().addingTimeInterval(wait))
                policies[product] = policy
                nextRefreshAt = policy.nextRefreshAt
                // Never sleep indefinitely or retry earlier than a server-supplied deadline.
                guard attempt < 2, wait <= 30 else { return }
                do { try await sleep(wait) } catch { return }
            }
        }
    }

    func tick() async {
        guard source.capabilities.canRefresh, !isLoading else { return }
        var policy = policies[selectedProduct] ?? RefreshPolicy()
        let due = policy.needsRefresh(at: now(), groups: groups.filter { $0.product == selectedProduct })
        policies[selectedProduct] = policy
        if due { await load() }
    }

    func resumeAfterWake() async {
        // TimelineView recomputes countdowns independently. Manual values require no fetching.
        guard source.capabilities.canRefresh else { return }
        await load()
    }

    func runUpdates() async {
        await load()
        guard source.capabilities.canRefresh else { return }
        while !Task.isCancelled {
            do { try await Task.sleep(for: .seconds(15)) } catch { return }
            await tick()
        }
    }

    private func restoreSelection() {
        groups = persistData && !source.capabilities.isDevelopment
            ? preferences.snapshots(for: selectedProduct, mode: sourceMode) : []
        selectedGroupID = preferences.group(for: selectedProduct, mode: sourceMode)
        nextRefreshAt = nil
        errorMessage = nil
    }

    private func persistCurrent() {
        guard persistData, !source.capabilities.isDevelopment else { return }
        do { try preferences.saveSnapshots(groups, for: selectedProduct, mode: sourceMode) }
        catch { errorMessage = "Værdierne kunne ikke gemmes lokalt." }
    }

    func beginLogin() async -> URL? {
        guard let automaticSource else { return nil }
        do {
            let url = try await automaticSource.login()
            loginMessage = "Gennemfør login i browseren. Kvoterne opdateres bagefter."
            return url
        } catch {
            loginMessage = "Login kunne ikke startes. Kontrollér Codex-installationen og prøv igen."
            return nil
        }
    }

    func shutdown() { automaticSource?.disconnect() }

    private func markStale() {
        for index in groups.indices {
            for period in groups[index].periods.indices where groups[index].periods[period].updatedAt != nil {
                if groups[index].periods[period].source != .manual {
                    groups[index].periods[period].status = .stale
                }
            }
        }
    }

    func saveManual(periods: [QuotaPeriod]) throws {
        guard source.capabilities.supportsManualEntry else { throw CocoaError(.featureUnsupported) }
        let value = QuotaSnapshot(product: selectedProduct, groupID: snapshot.groupID,
                                  groupName: snapshot.groupName, periods: periods, sourceLabel: source.label)
        try source.save(value)
        groups.removeAll { $0.groupID == value.groupID }
        groups.append(value)
        persistCurrent()
    }
}
