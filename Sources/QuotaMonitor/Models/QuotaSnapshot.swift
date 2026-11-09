import Foundation

enum MonitoredProduct: String, CaseIterable, Identifiable, Codable, Sendable {
    case codex, chat
    var id: String { rawValue }
    var title: String { self == .codex ? "Codex / ChatGPT Work" : "ChatGPT-chat" }
}

enum QuotaSource: String, Codable, Sendable { case automatic, manual, development }
enum QuotaStatus: String, Codable, Sendable {
    case current = "Aktuel", manual = "Manuel", unknown = "Ukendt"
    case unavailable = "Ikke tilgængelig", stale = "Forældet"
    case awaitingReset = "Afventer bekræftet nulstilling"
}

enum QuotaValidationError: LocalizedError {
    case percent, amount, date
    var errorDescription: String? {
        switch self {
        case .percent: "Procent skal være et tal mellem 0 og 100."
        case .amount: "Resterende antal skal være positivt eller nul og have en enhed."
        case .date: "Nulstilling skal være en gyldig dato."
        }
    }
}

struct QuotaPeriod: Identifiable, Codable, Sendable {
    enum Kind: String, CaseIterable, Codable, Sendable { case fiveHours, week }
    let kind: Kind
    let remainingPercent: Double?
    let remainingAmount: Double?
    let unit: String?
    let resetsAt: Date?
    let updatedAt: Date?
    let source: QuotaSource
    var status: QuotaStatus
    var id: String { kind.rawValue }
    var title: String { kind == .fiveHours ? "5 timer" : "Uge" }

    init(kind: Kind, remainingPercent: Double? = nil, remainingAmount: Double? = nil,
         unit: String? = nil, resetsAt: Date? = nil, updatedAt: Date? = nil,
         source: QuotaSource = .manual, status: QuotaStatus = .unknown) throws {
        if let percent = remainingPercent, !percent.isFinite || !(0...100).contains(percent) {
            throw QuotaValidationError.percent
        }
        if let amount = remainingAmount,
           !amount.isFinite || amount < 0 || (unit?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
            throw QuotaValidationError.amount
        }
        if let date = resetsAt, !date.timeIntervalSince1970.isFinite { throw QuotaValidationError.date }
        if let date = updatedAt, !date.timeIntervalSince1970.isFinite { throw QuotaValidationError.date }
        self.kind = kind; self.remainingPercent = remainingPercent
        self.remainingAmount = remainingAmount; self.unit = unit
        self.resetsAt = resetsAt; self.updatedAt = updatedAt; self.source = source; self.status = status
    }

    func displayStatus(at now: Date) -> QuotaStatus {
        if status == .unavailable { return .unavailable }
        if let resetsAt, resetsAt <= now { return .awaitingReset }
        return status
    }

    var warning: String? {
        guard let percent = remainingPercent else { return nil }
        return percent <= 5 ? "Kritisk – højst 5 % tilbage" : percent <= 20 ? "Lav kvote – højst 20 % tilbage" : nil
    }

    func countdown(at now: Date) -> String {
        guard let resetsAt else { return "Nulstillingstidspunkt ukendt" }
        let seconds = resetsAt.timeIntervalSince(now)
        guard seconds > 0 else { return "Afventer bekræftet nulstilling" }
        let minutes = Int(ceil(seconds / 60))
        let days = minutes / 1440, hours = (minutes % 1440) / 60, rest = minutes % 60
        return "Nulstilles om " + (days > 0 ? "\(days) d " : "") + (hours > 0 ? "\(hours) t " : "") + "\(rest) min"
    }
}

struct QuotaSnapshot: Identifiable, Codable, Sendable {
    let product: MonitoredProduct
    let groupID: String
    let groupName: String
    var periods: [QuotaPeriod]
    let sourceLabel: String
    var id: String { product.rawValue + ":" + groupID }

    init(product: MonitoredProduct, groupID: String = "default", groupName: String = "Generel kvote",
         periods: [QuotaPeriod], sourceLabel: String) {
        self.product = product; self.groupID = groupID; self.groupName = groupName
        // Always expose both periods, including partial responses.
        self.periods = QuotaPeriod.Kind.allCases.map { kind in
            periods.first(where: { $0.kind == kind }) ?? (try! QuotaPeriod(kind: kind))
        }
        self.sourceLabel = sourceLabel
    }

    static func empty(for product: MonitoredProduct, sourceLabel: String) -> Self {
        Self(product: product, periods: [], sourceLabel: sourceLabel)
    }
}


extension QuotaPeriod {
    enum CodingKeys: String, CodingKey {
        case kind, remainingPercent, remainingAmount, unit, resetsAt, updatedAt, source, status
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(kind: c.decode(Kind.self, forKey: .kind),
                      remainingPercent: c.decodeIfPresent(Double.self, forKey: .remainingPercent),
                      remainingAmount: c.decodeIfPresent(Double.self, forKey: .remainingAmount),
                      unit: c.decodeIfPresent(String.self, forKey: .unit),
                      resetsAt: c.decodeIfPresent(Date.self, forKey: .resetsAt),
                      updatedAt: c.decodeIfPresent(Date.self, forKey: .updatedAt),
                      source: c.decode(QuotaSource.self, forKey: .source),
                      status: c.decode(QuotaStatus.self, forKey: .status))
    }
}
extension QuotaSnapshot {
    enum CodingKeys: String, CodingKey { case product, groupID, groupName, periods, sourceLabel }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(product: try c.decode(MonitoredProduct.self, forKey: .product),
                  groupID: try c.decode(String.self, forKey: .groupID),
                  groupName: try c.decode(String.self, forKey: .groupName),
                  periods: try c.decode([QuotaPeriod].self, forKey: .periods),
                  sourceLabel: try c.decode(String.self, forKey: .sourceLabel))
    }
}
