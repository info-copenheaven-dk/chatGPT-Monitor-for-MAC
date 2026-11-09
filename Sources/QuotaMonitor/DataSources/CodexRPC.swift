import Foundation

/// Newline JSON-RPC over pipes. Raw responses, credentials and stderr are never logged.
@MainActor
final class CodexRPC {
    private let process = Process()
    private let input = Pipe()
    private let output = Pipe()
    private var buffer = Data()
    private var nextID = 0
    private var pending: [Int: CheckedContinuation<Data, Error>] = [:]
    var notification: ((String, Data) -> Void)?
    var running: Bool { process.isRunning }

    func start(path: String) async throws {
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["-c", "cli_auth_credentials_store=\"keyring\"", "app-server"]
        process.standardInput = input; process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        var env = ProcessInfo.processInfo.environment
        env["RUST_LOG"] = "off"
        process.environment = env
        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            Task { @MainActor [weak self] in self?.consume(data) }
        }
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in self?.failAll(QuotaFetchError.unavailable) }
        }
        do { try process.run() } catch { stop(); throw QuotaFetchError.unavailable }
        _ = try await request("initialize", params: ["clientInfo": [
            "name": "chatgpt_quota_monitor", "title": "ChatGPT Monitor", "version": "0.2.0"
        ]])
        try send(["method": "initialized"])
    }

    func request(_ method: String, params: [String: Any]? = nil) async throws -> Data {
        guard running else { throw QuotaFetchError.unavailable }
        nextID += 1
        let id = nextID
        var message: [String: Any] = ["id": id, "method": method]
        if let params { message["params"] = params }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pending[id] = continuation
                do { try send(message) } catch {
                    pending.removeValue(forKey: id)?.resume(throwing: QuotaFetchError.unavailable)
                }
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(30))
                    guard let self, self.pending[id] != nil else { return }
                    self.pending.removeValue(forKey: id)?.resume(throwing: URLError(.timedOut))
                    self.stop()
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.pending.removeValue(forKey: id)?.resume(throwing: CancellationError())
            }
        }
    }

    private func send(_ message: [String: Any]) throws {
        var data = try JSONSerialization.data(withJSONObject: message)
        data.append(10)
        try input.fileHandleForWriting.write(contentsOf: data)
    }

    private func consume(_ data: Data) {
        guard !data.isEmpty else { failAll(QuotaFetchError.unavailable); return }
        buffer.append(data)
        guard buffer.count < 4_000_000 else { stop(); return }
        while let end = buffer.firstIndex(of: 10) {
            let line = buffer[..<end]; buffer.removeSubrange(...end)
            guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { continue }
            if let id = object["id"] as? Int, let continuation = pending.removeValue(forKey: id) {
                if let error = object["error"] as? [String: Any] {
                    continuation.resume(throwing: Self.classify(error))
                } else if let result = object["result"],
                          let payload = try? JSONSerialization.data(withJSONObject: result, options: [.fragmentsAllowed]) {
                    continuation.resume(returning: payload)
                } else { continuation.resume(throwing: QuotaFetchError.unavailable) }
            } else if let method = object["method"] as? String,
                      let params = object["params"], let payload = try? JSONSerialization.data(withJSONObject: params) {
                notification?(method, payload)
            }
        }
    }

    static func classify(_ error: [String: Any]) -> Error {
        let code = error["code"] as? Int ?? 0
        let text = (error["message"] as? String ?? "").lowercased()
        if code == 401 || text.contains("unauthorized") || text.contains("not authenticated") || text.contains("not logged in") {
            return QuotaFetchError.authenticationRequired
        }
        if code == 429 || code == 503 || text.contains("too many requests") {
            let details = error["data"] as? [String: Any]
            let delay = (details?["retryAfterSeconds"] as? NSNumber)?.doubleValue
            return QuotaFetchError.temporary(retryAfter: delay)
        }
        return QuotaFetchError.unavailable
    }

    private func failAll(_ error: Error) {
        let calls = pending.values; pending.removeAll()
        for call in calls { call.resume(throwing: error) }
    }
    func stop() {
        output.fileHandleForReading.readabilityHandler = nil
        process.terminationHandler = nil
        if process.isRunning { process.terminate() }
        try? input.fileHandleForWriting.close()
        failAll(QuotaFetchError.unavailable)
    }
}
