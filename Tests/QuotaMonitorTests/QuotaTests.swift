import Foundation

@main
struct QuotaTests {
    static func check(_ condition: @autoclosure () -> Bool, _ label: String) {
        guard condition() else { fatalError("FAIL: \(label)") }
    }
    static func rejects(_ label: String, _ operation: () throws -> Void) {
        do { try operation(); fatalError("FAIL: \(label)") } catch { }
    }
    @MainActor
    static func main() async throws {
        for percent in [-1.0, 101, .nan, .infinity] {
            rejects("Invalid percent") { _ = try QuotaPeriod(kind: .week, remainingPercent: percent) }
        }
        rejects("Missing unit") { _ = try QuotaPeriod(kind: .week, remainingAmount: 12) }
        rejects("Negative amount") { _ = try QuotaPeriod(kind: .week, remainingAmount: -1, unit: "tokens") }
        let empty = QuotaSnapshot.empty(for: .chat, sourceLabel: "Manuel")
        check(empty.periods.count == 2, "Both periods exist")
        check(empty.periods.allSatisfy { $0.remainingPercent == nil }, "Unknown is not zero")
        let zero = try QuotaPeriod(kind: .fiveHours, remainingPercent: 0, status: .current)
        let partial = QuotaSnapshot(product: .codex, periods: [zero], sourceLabel: "Test")
        check(partial.periods[0].remainingPercent == 0, "Zero is a valid value")
        check(partial.periods[1].remainingPercent == nil, "Partial answer retains unknown")
        let now = Date(timeIntervalSince1970: 100000)
        let value = try QuotaPeriod(kind: .fiveHours, remainingPercent: 5,
                                    resetsAt: now.addingTimeInterval(61), status: .manual)
        check(value.countdown(at: now) == "Nulstilles om 2 min", "Countdown rounds up")
        check(value.displayStatus(at: now.addingTimeInterval(61)) == .awaitingReset, "Expiry")
        check(value.remainingPercent == 5, "No inferred refill")
        check(value.warning != nil, "Critical boundary")
        let warning = try QuotaPeriod(kind: .week, remainingPercent: 20)
        let normal = try QuotaPeriod(kind: .week, remainingPercent: 20.1)
        check(warning.warning != nil && normal.warning == nil, "Warning boundary")
        let source = ManualQuotaDataSource()
        try source.save(QuotaSnapshot(product: .chat, periods: [value], sourceLabel: source.label))
        let chat = try await source.fetch(for: .chat)
        let codex = try await source.fetch(for: .codex)
        check(chat[0].periods[0].remainingPercent == 5, "Manual save")
        check(codex[0].periods[0].remainingPercent == nil, "Products isolated")
        var draft = ManualPeriodDraft(value)
        draft.percent = "101"
        rejects("Draft validation") { _ = try draft.validated(at: now) }
        draft.percent = "12,5"
        let validated = try draft.validated(at: now)
        check(validated.remainingPercent == 12.5, "Danish decimal input")
        draft.enabled = false
        let disabled = try draft.validated(at: now)
        check(disabled.remainingPercent == nil, "Disabled means unknown")
        let unavailable = try QuotaPeriod(kind: .week, status: .unavailable)
        check(unavailable.displayStatus(at: now) == .unavailable, "Unavailable status")
        try timeAndBoundaryTests()
        try persistenceAndParsingTests()
        try await rpcTests()
        try await refreshTests()
        print("PASS: validation, partial data, boundaries, countdown, expiry, product isolation and manual input")
    }
}


@MainActor
final class SimulatedQuotaSource: QuotaDataSource {
    let label = "Simuleret"
    var capabilities = SourceCapabilities(canRefresh: true, supportsManualEntry: false, isDevelopment: false)
    var calls = 0
    var failure: Error?
    var pause: CheckedContinuation<Void, Never>?
    var shouldPause = false
    func fetch(for product: MonitoredProduct) async throws -> [QuotaSnapshot] {
        calls += 1
        if shouldPause { await withCheckedContinuation { pause = $0 } }
        if let failure { throw failure }
        return [QuotaSnapshot(product: product, periods: [
            try QuotaPeriod(kind: .fiveHours, remainingPercent: 20,
                            resetsAt: Date(timeIntervalSince1970: 200000),
                            updatedAt: Date(timeIntervalSince1970: 100000), source: .automatic, status: .current)
        ], sourceLabel: label)]
    }
}

extension QuotaTests {
    @MainActor
    static func refreshTests() async throws {
        var time = Date(timeIntervalSince1970: 100000)
        let expired = QuotaSnapshot(product: .codex, periods: [
            try QuotaPeriod(kind: .fiveHours, remainingPercent: 5, resetsAt: time,
                            source: .automatic, status: .current)
        ], sourceLabel: "Test")
        var policy = RefreshPolicy()
        policy.started(at: time, interval: 300, minimum: 10)
        check(!policy.needsRefresh(at: time, groups: [expired]), "Minimum gap applies to resets")
        check(policy.needsRefresh(at: time.addingTimeInterval(10), groups: [expired]), "Reset triggers fetch")
        check(!policy.needsRefresh(at: time.addingTimeInterval(11), groups: [expired]), "Same reset handled once")
        check(policy.needsRefresh(at: time.addingTimeInterval(300), groups: []), "Periodic refresh due")
        policy.deferUntil(time.addingTimeInterval(900))
        check(!policy.canAttempt(at: time.addingTimeInterval(800)), "Server delay blocks manual and timer")

        let source = SimulatedQuotaSource()
        var sleeps: [TimeInterval] = []
        let store = QuotaStore(source: source, now: { time }, sleep: { delay in
            sleeps.append(delay); time = time.addingTimeInterval(delay)
        })
        await store.load()
        check(source.calls == 1, "Startup fetch")
        await store.tick()
        check(source.calls == 1, "No fetch before interval")
        time = time.addingTimeInterval(300)
        await store.tick()
        check(source.calls == 2, "Periodic refresh")
        source.failure = QuotaFetchError.temporary(retryAfter: nil)
        await store.load()
        check(source.calls == 5, "At most three attempts")
        check(sleeps == [2, 4], "Increasing backoff")
        check(store.snapshot.periods[0].status == .stale, "Failure marks cached data stale")
        check(store.snapshot.periods[0].remainingPercent == 20, "Failure preserves value")
        check(store.snapshot.periods[0].updatedAt == Date(timeIntervalSince1970: 100000), "Failure preserves timestamp")
        time = time.addingTimeInterval(1000)
        source.failure = QuotaFetchError.temporary(retryAfter: 600)
        let before = source.calls
        await store.load()
        check(source.calls == before + 1, "Long retry delay is deferred, not slept")
        await store.resumeAfterWake()
        check(source.calls == before + 1, "Wake respects server delay")
        time = time.addingTimeInterval(600)
        source.failure = QuotaFetchError.authenticationRequired
        await store.load()
        check(source.calls == before + 2, "Authentication failure is not retried")
        source.failure = nil
        await store.resumeAfterWake()
        check(store.snapshot.periods[0].status == .current, "Wake recovers stale state")
        source.shouldPause = true
        let first = Task { await store.load() }
        while source.pause == nil { await Task.yield() }
        let concurrentCount = source.calls
        await store.load()
        await store.tick()
        check(source.calls == concurrentCount, "No overlapping fetches")
        source.pause?.resume(); source.pause = nil
        await first.value
        let manual = ManualQuotaDataSource()
        let manualStore = QuotaStore(source: manual)
        await manualStore.load()
        await manualStore.tick()
        await manualStore.resumeAfterWake()
        check(manualStore.nextRefreshAt == nil, "Manual mode has no automatic fetch schedule")
        print("PASS: refresh scheduling, retry bounds, server delay, wake, stale data and overlap protection")
    }
}


extension QuotaTests {
    @MainActor
    static func persistenceAndParsingTests() throws {
        let suite = "dk.local.chatgpt-monitor.tests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = PreferencesStore(defaults: defaults)
        preferences.selectedProduct = .codex
        preferences.alwaysOnTop = true
        preferences.refreshInterval = 7
        preferences.saveMode(.automatic, for: .codex)
        preferences.saveGroup("codex", for: .codex, mode: .automatic)
        let now = Date(timeIntervalSince1970: 100000)
        let response = Data(#"{"rateLimits":{"limitId":"codex","primary":{"usedPercent":25,"windowDurationMins":10080,"resetsAt":200000},"secondary":{"usedPercent":80,"windowDurationMins":300,"resetsAt":110000}}}"#.utf8)
        let parsed = try CodexQuotaParser.parse(response, at: now)
        check(parsed[0].periods[0].remainingPercent == 20, "Match duration, not primary position")
        check(parsed[0].periods[1].remainingPercent == 75, "Weekly conversion")
        try preferences.saveSnapshots(parsed, for: .codex, mode: .automatic)
        let restored = PreferencesStore(defaults: UserDefaults(suiteName: suite)!)
        let cached = restored.snapshots(for: .codex, mode: .automatic)
        check(cached[0].periods[0].status == .stale, "Restored automatic data is stale")
        check(cached[0].periods[0].updatedAt == now, "Cache retains timestamp")
        check(restored.alwaysOnTop && restored.refreshInterval == 7, "Preferences persist")
        let store = QuotaStore(source: ManualQuotaDataSource(persistence: restored), preferences: restored,
                               automaticSource: CodexQuotaDataSource(path: "/missing"), persistData: true)
        check(store.selectedGroupID == "codex", "Selected quota group persists")
        check(store.snapshot.periods[0].status == .stale, "UI store starts stale")
        store.refreshInterval = 8
        check(restored.refreshInterval == 8, "Interval changes save without recursion")
        store.sourceMode = .manual
        check(store.snapshot.periods[0].remainingPercent == nil, "Manual does not show automatic cache")
        let manual = try QuotaPeriod(kind: .week, remainingPercent: 12.5, updatedAt: now, source: .manual, status: .manual)
        try store.saveManual(periods: [manual])
        let manualSource = ManualQuotaDataSource(persistence: restored)
        let manualCache = restored.snapshots(for: .codex, mode: .manual)
        check(manualCache[0].periods[1].status == .manual, "Manual cache remains manual")
        check(manualCache[0].periods[1].updatedAt == now, "Manual timestamp persists")
        _ = manualSource
        store.sourceMode = .automatic
        check(store.snapshot.periods[0].remainingPercent == 20, "Switch restores isolated automatic cache")
        let malformed = Data(#"{"rateLimits":{"primary":{"usedPercent":true,"windowDurationMins":300},"secondary":{"usedPercent":101,"windowDurationMins":10080}}}"#.utf8)
        let invalid = try CodexQuotaParser.parse(malformed, at: now)
        check(invalid[0].periods.allSatisfy { $0.remainingPercent == nil }, "Invalid remote values stay unknown")
        let partial = try CodexQuotaParser.parse(Data(#"{"rateLimits":{"primary":{"usedPercent":5,"windowDurationMins":300}}}"#.utf8), at: now)
        check(partial[0].periods[1].status == .unavailable, "Missing remote window is unavailable")
        rejects("Corrupt response rejected") { _ = try CodexQuotaParser.parse(Data("{}".utf8), at: now) }
        defaults.set(Data("corrupt".utf8), forKey: "snapshots.v1.codex.automatic")
        check(restored.snapshots(for: .codex, mode: .automatic).isEmpty, "Corrupt cache handled safely")
        let screen = CGRect(x: 0, y: 0, width: 1200, height: 800)
        let moved = WindowPlacement.visibleFrame(CGRect(x: 3000, y: -100, width: 400, height: 600), screens: [screen])
        check(moved.origin.x == 800 && moved.origin.y == 0, "Off-screen window clamped")
        if case QuotaFetchError.authenticationRequired = CodexRPC.classify(["code": 401]) { }
        else { fatalError("Authentication classification") }
        if case QuotaFetchError.temporary(let delay) = CodexRPC.classify(["code": 429, "data": ["retryAfterSeconds": 60]]) {
            check(delay == 60, "Server delay classification")
        } else { fatalError("Throttle classification") }
        print("PASS: Codex parsing, cache validation, source isolation, preferences, stale restore and window placement")
    }
}


extension QuotaTests {
    @MainActor
    static func rpcTests() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("quota-rpc-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let executable = folder.appendingPathComponent("fake-codex")
        let script = #"""
        #!/bin/zsh
        while IFS= read -r message; do
          case "$message" in
            *'"method":"initialize"'*) print -r -- '{"id":1,"result":{}}' ;;
            *rateLimits*) print -r -- '{"id":3,"result":{"rateLimits":{"limitId":"codex","primary":{"usedPercent":9,"windowDurationMins":300,"resetsAt":1793844517},"secondary":{"usedPercent":5,"windowDurationMins":10080,"resetsAt":1794411629}}}}' ;;
            *account*read*) print -r -- '{"id":2,"result":{"account":{"type":"chatgpt"}}}' ;;
            *login*start*)
              print -r -- '{"id":4,"result":{"authUrl":"https://auth.openai.com/test-login"}}'
              print -r -- '{"method":"account/login/completed","params":{"success":true}}' ;;
          esac
        done
        """#
        try script.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        let source = CodexQuotaDataSource(path: executable.path)
        defer { source.disconnect() }
        let values = try await source.fetch(for: .codex)
        check(values[0].periods[0].remainingPercent == 91, "Native subprocess RPC fetch")
        check(values[0].periods[1].remainingPercent == 95, "Native subprocess weekly fetch")
        var loggedIn = false
        source.loginCompleted = { loggedIn = true }
        let url = try await source.login()
        check(url.host == "auth.openai.com", "Login URL validated")
        for _ in 0..<100 where !loggedIn { await Task.yield() }
        check(loggedIn, "Login completion notification")
        print("PASS: native RPC handshake, subprocess fetch and browser login notification")
    }
}


extension QuotaTests {
    static func timeAndBoundaryTests() throws {
        let iso = ISO8601DateFormatter()
        let timezone = TimeZone(identifier: "Europe/Copenhagen")!
        let start = iso.date(from: "2026-03-29T00:30:00Z")!
        let end = iso.date(from: "2026-03-29T01:30:00Z")!
        check(QuotaFormat.date(start, timeZone: timezone) == "29.03.2026 kl. 01:30", "Local time before DST")
        check(QuotaFormat.date(end, timeZone: timezone) == "29.03.2026 kl. 03:30", "Local time after DST")
        let period = try QuotaPeriod(kind: .fiveHours, remainingPercent: 100, resetsAt: end)
        check(period.countdown(at: start) == "Nulstilles om 1 t 0 min", "DST countdown uses absolute time")
        check(period.warning == nil, "Full quota is not a warning")
        let midnight = iso.date(from: "2026-11-04T23:30:00Z")!
        check(QuotaFormat.date(midnight, timeZone: timezone) == "05.11.2026 kl. 00:30", "Local date rollover")
        print("PASS: local 24-hour dates, DST, midnight and 100 percent")
    }
}
