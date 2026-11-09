import Foundation

/// Scheduling is separate from fetching so time and reset behaviour can be tested without timers.
struct RefreshPolicy {
    private(set) var nextRefreshAt: Date?
    private(set) var notBefore: Date?
    private var handledResets: Set<String> = []

    func canAttempt(at now: Date) -> Bool { notBefore.map { now >= $0 } ?? true }

    mutating func started(at now: Date, interval: TimeInterval, minimum: TimeInterval) {
        nextRefreshAt = now.addingTimeInterval(max(interval, minimum))
        notBefore = now.addingTimeInterval(max(0, minimum))
    }

    mutating func deferUntil(_ date: Date) {
        notBefore = max(notBefore ?? date, date)
        nextRefreshAt = max(nextRefreshAt ?? date, date)
    }

    mutating func reschedule(at now: Date, interval: TimeInterval, minimum: TimeInterval) {
        nextRefreshAt = max(now.addingTimeInterval(max(interval, minimum)), notBefore ?? now)
    }

    mutating func needsRefresh(at now: Date, groups: [QuotaSnapshot]) -> Bool {
        guard canAttempt(at: now) else { return false }
        let resets = groups.flatMap { group in
            group.periods.compactMap { period -> String? in
                guard period.source != .manual, let reset = period.resetsAt, reset <= now else { return nil }
                return "\(group.id):\(period.id):\(reset.timeIntervalSince1970)"
            }
        }
        let unseen = Set(resets).subtracting(handledResets)
        if !unseen.isEmpty {
            handledResets.formUnion(unseen)
            return true
        }
        return nextRefreshAt.map { now >= $0 } ?? true
    }
}

enum QuotaFetchError: Error {
    /// Adapters classify transient errors and supply a server-requested minimum wait when available.
    case temporary(retryAfter: TimeInterval?)
    case authenticationRequired
    case unavailable

    static func retryDelay(for error: Error, attempt: Int) -> TimeInterval? {
        let serverDelay: TimeInterval?
        if case let QuotaFetchError.temporary(retryAfter) = error {
            serverDelay = retryAfter
        } else if let url = error as? URLError,
                  [.timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost,
                   .notConnectedToInternet, .dnsLookupFailed].contains(url.code) {
            serverDelay = nil
        } else { return nil }
        let backoff = pow(2.0, Double(attempt)) * 2
        guard let delay = serverDelay, delay.isFinite, delay >= 0 else { return backoff }
        return max(backoff, delay)
    }
}
