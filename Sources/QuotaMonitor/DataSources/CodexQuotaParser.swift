import Foundation
import CoreFoundation

enum CodexQuotaParser {
    private static func number(_ value: Any?) -> Double? {
        guard let value = value as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID() else { return nil }
        return value.doubleValue
    }
    static func parse(_ data: Data, at now: Date) throws -> [QuotaSnapshot] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw QuotaFetchError.unavailable
        }
        var buckets = root["rateLimitsByLimitId"] as? [String: Any] ?? [:]
        if buckets.isEmpty, let single = root["rateLimits"] as? [String: Any] {
            buckets[single["limitId"] as? String ?? "codex"] = single
        }
        guard !buckets.isEmpty else { throw QuotaFetchError.unavailable }
        return buckets.keys.sorted().compactMap { key in
            guard let bucket = buckets[key] as? [String: Any] else { return nil }
            let windows = [bucket["primary"], bucket["secondary"]].compactMap { $0 as? [String: Any] }
            let periods = QuotaPeriod.Kind.allCases.map { kind -> QuotaPeriod in
                let minutes = kind == .fiveHours ? 300 : 10080
                guard let window = windows.first(where: { number($0["windowDurationMins"]) == Double(minutes) }) else {
                    return try! QuotaPeriod(kind: kind, source: .automatic, status: .unavailable)
                }
                let used = number(window["usedPercent"])
                let percent = used.flatMap { $0.isFinite && (0...100).contains($0) ? 100 - $0 : nil }
                let seconds = number(window["resetsAt"])
                let reset = seconds.flatMap { $0.isFinite && $0 > 0 ? Date(timeIntervalSince1970: $0) : nil }
                return try! QuotaPeriod(kind: kind, remainingPercent: percent, resetsAt: reset,
                                        updatedAt: now, source: .automatic,
                                        status: percent == nil ? .unknown : .current)
            }
            return QuotaSnapshot(product: .codex, groupID: key,
                                 groupName: bucket["limitName"] as? String ?? key,
                                 periods: periods, sourceLabel: "Automatisk · Codex")
        }
    }
}
