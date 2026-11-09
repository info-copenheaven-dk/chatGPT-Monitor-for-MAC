import Foundation

struct SourceCapabilities: Sendable {
    let canRefresh: Bool
    let supportsManualEntry: Bool
    let isDevelopment: Bool
    var minimumRefreshSeconds: TimeInterval = 0
}

@MainActor
protocol QuotaDataSource {
    var label: String { get }
    var capabilities: SourceCapabilities { get }
    func fetch(for product: MonitoredProduct) async throws -> [QuotaSnapshot]
    func save(_ snapshot: QuotaSnapshot) throws
}

extension QuotaDataSource {
    func save(_ snapshot: QuotaSnapshot) throws { throw CocoaError(.featureUnsupported) }
}

@MainActor
final class ManualQuotaDataSource: QuotaDataSource {
    let label = "Manuel indtastning"
    let capabilities = SourceCapabilities(canRefresh: false, supportsManualEntry: true, isDevelopment: false)
    private var snapshots: [MonitoredProduct: [QuotaSnapshot]] = [:]
    private let persistence: PreferencesStore?
    init(persistence: PreferencesStore? = nil) { self.persistence = persistence }
    func fetch(for product: MonitoredProduct) async throws -> [QuotaSnapshot] {
        snapshots[product] ?? persistence?.snapshots(for: product, mode: .manual) ?? [.empty(for: product, sourceLabel: label)]
    }
    func save(_ snapshot: QuotaSnapshot) throws {
        var groups = snapshots[snapshot.product] ?? persistence?.snapshots(for: snapshot.product, mode: .manual) ?? []
        groups.removeAll { $0.groupID == snapshot.groupID }
        groups.append(snapshot)
        try persistence?.saveSnapshots(groups, for: snapshot.product, mode: .manual)
        snapshots[snapshot.product] = groups
    }
}

#if DEBUG
@MainActor
struct DevelopmentQuotaDataSource: QuotaDataSource {
    let label = "Udviklingsdata – ikke kontodata"
    let capabilities = SourceCapabilities(canRefresh: true, supportsManualEntry: false, isDevelopment: true)
    private let referenceDate = Date()
    func fetch(for product: MonitoredProduct) async throws -> [QuotaSnapshot] {
        let first = QuotaSnapshot(product: product, periods: [
            try QuotaPeriod(kind: .fiveHours, remainingPercent: 20, remainingAmount: 12, unit: "beskeder",
                            resetsAt: referenceDate.addingTimeInterval(8100), updatedAt: referenceDate,
                            source: .development, status: .current),
            try QuotaPeriod(kind: .week, remainingPercent: 5,
                            resetsAt: referenceDate.addingTimeInterval(400000), updatedAt: referenceDate,
                            source: .development, status: .current)
        ], sourceLabel: label)
        let second = QuotaSnapshot(product: product, groupID: "extra", groupName: "Ekstra kvote (demo)", periods: [
            try QuotaPeriod(kind: .fiveHours, remainingPercent: 65,
                            resetsAt: referenceDate.addingTimeInterval(-60), updatedAt: referenceDate,
                            source: .development, status: .stale),
            try QuotaPeriod(kind: .week, source: .development, status: .unavailable)
        ], sourceLabel: label)
        return [first, second]
    }
}
#endif
