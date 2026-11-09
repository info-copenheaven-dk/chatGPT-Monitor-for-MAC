import Foundation

struct ManualPeriodDraft: Identifiable {
    let kind: QuotaPeriod.Kind
    var enabled: Bool
    var percent: String
    var resetsAt: Date
    var id: String { kind.rawValue }
    var title: String { kind == .fiveHours ? "5 timer" : "Uge" }
    init(_ period: QuotaPeriod) {
        kind = period.kind
        enabled = period.remainingPercent != nil
        percent = period.remainingPercent.map { String($0) } ?? ""
        resetsAt = period.resetsAt ?? Date().addingTimeInterval(kind == .fiveHours ? 18000 : 604800)
    }
    func validated(at now: Date) throws -> QuotaPeriod {
        guard enabled else { return try QuotaPeriod(kind: kind, source: .manual) }
        guard let value = Double(percent.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")) else {
            throw QuotaValidationError.percent
        }
        return try QuotaPeriod(kind: kind, remainingPercent: value, resetsAt: resetsAt,
                               updatedAt: now, source: .manual, status: .manual)
    }
}

