import Foundation

@MainActor
final class CodexQuotaDataSource: QuotaDataSource {
    let label = "Automatisk · Codex"
    // Conservative app throttle; not a claim about the service's allowed frequency.
    let capabilities = SourceCapabilities(canRefresh: true, supportsManualEntry: false,
                                          isDevelopment: false, minimumRefreshSeconds: 10)
    var executablePath: String { didSet { if oldValue != executablePath { disconnect() } } }
    private var rpc: CodexRPC?
    private var startup: Task<CodexRPC, Error>?
    var loginCompleted: (() -> Void)?
    private var idleDisconnect: Task<Void, Never>?
    private var loginPending = false

    init(path: String = "") { executablePath = path }

    static func locateExecutable(override: String) -> String? {
        let candidates = override.isEmpty ? [
            "/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/plugins/.plugin-appserver/codex-cli/bin/codex").path
        ] : [override]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private func connection() async throws -> CodexRPC {
        idleDisconnect?.cancel(); idleDisconnect = nil
        if let startup { return try await startup.value }
        if let rpc, rpc.running { return rpc }
        guard let path = Self.locateExecutable(override: executablePath) else { throw QuotaFetchError.unavailable }
        let client = CodexRPC()
        rpc = client
        client.notification = { [weak self] method, data in
            guard method == "account/login/completed",
                  let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            self?.loginPending = false
            if value["success"] as? Bool == true { self?.loginCompleted?() }
            self?.scheduleIdleDisconnect()
        }
        let task = Task {
            try await client.start(path: path)
            return client
        }
        startup = task
        do {
            let result = try await task.value
            startup = nil
            return result
        } catch {
            if rpc === client { disconnect() }
            throw error
        }
    }

    func fetch(for product: MonitoredProduct) async throws -> [QuotaSnapshot] {
        guard product == .codex else { throw QuotaFetchError.unavailable }
        let client = try await connection()
        defer { scheduleIdleDisconnect() }
        let account = try await client.request("account/read", params: ["refreshToken": false])
        guard let value = try JSONSerialization.jsonObject(with: account) as? [String: Any],
              let account = value["account"] as? [String: Any], account["type"] as? String == "chatgpt" else {
            throw QuotaFetchError.authenticationRequired
        }
        let data = try await client.request("account/rateLimits/read")
        return try CodexQuotaParser.parse(data, at: Date())
    }

    func login() async throws -> URL {
        let client = try await connection()
        loginPending = true
        let data: Data
        do { data = try await client.request("account/login/start", params: ["type": "chatgpt"]) }
        catch { loginPending = false; scheduleIdleDisconnect(); throw error }
        guard let value = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let address = value["authUrl"] as? String, let url = URL(string: address),
              url.scheme == "https", ["auth.openai.com", "chatgpt.com", "auth0.openai.com"].contains(url.host ?? "") else {
            loginPending = false; scheduleIdleDisconnect()
            throw QuotaFetchError.unavailable
        }
        return url
    }
    private func scheduleIdleDisconnect() {
        idleDisconnect?.cancel()
        guard !loginPending else { return }
        idleDisconnect = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(10)) } catch { return }
            self?.disconnect()
        }
    }
    func disconnect() {
        idleDisconnect?.cancel(); idleDisconnect = nil
        startup?.cancel(); startup = nil
        rpc?.stop(); rpc = nil
        loginPending = false
    }
}
