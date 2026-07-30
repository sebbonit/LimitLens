import Foundation

public protocol CodexUsageFetching: Sendable {
    func fetchSnapshot() async throws -> LimitLensSnapshot
}

public final class CodexAppServerClient: CodexUsageFetching, @unchecked Sendable {
    public let executablePath: String
    public let appVersion: String
    private let resetCreditFetcher: ResetCreditFetching
    private let accountFetcher: CodexAccountFetching
    private let requestTimeout: Duration

    public init(
        executablePath: String = "/Applications/ChatGPT.app/Contents/Resources/codex",
        appVersion: String = "1.0.0",
        resetCreditFetcher: ResetCreditFetching = BackendResetCreditClient(),
        accountFetcher: CodexAccountFetching = BackendCodexAccountClient(),
        requestTimeout: Duration = .seconds(15)
    ) {
        self.executablePath = executablePath
        self.appVersion = appVersion
        self.resetCreditFetcher = resetCreditFetcher
        self.accountFetcher = accountFetcher
        self.requestTimeout = requestTimeout
    }

    public func fetchSnapshot() async throws -> LimitLensSnapshot {
        guard FileManager.default.isExecutableFile(atPath: executablePath) else {
            throw CodexUsageError.codexNotFound(path: executablePath)
        }

        let session = JSONRPCProcessSession(
            executablePath: executablePath,
            requestTimeout: requestTimeout
        )
        try session.start()
        defer { session.terminate() }

        let initializeParams: [String: Any] = [
            "clientInfo": [
                "name": "resetstat",
                "title": "LimitLens",
                "version": appVersion
            ],
            "capabilities": [
                "experimentalApi": true
            ]
        ]

        let _: EmptyResult = try await session.request(
            method: "initialize",
            params: initializeParams,
            as: EmptyResult.self
        )

        let rateLimits: GetAccountRateLimitsResponse = try await session.request(
            method: "account/rateLimits/read",
            params: NSNull(),
            as: GetAccountRateLimitsResponse.self
        )

        let usage: GetAccountTokenUsageResponse? = try? await session.request(
            method: "account/usage/read",
            params: NSNull(),
            as: GetAccountTokenUsageResponse.self
        )
        try Task.checkCancellation()

        let resetCredits = (try? await resetCreditFetcher.fetchResetCredits())
            ?? ResetCreditInfo(summary: rateLimits.rateLimitResetCredits)
        try Task.checkCancellation()
        let account = try? await accountFetcher.fetchAccountInfo()
        try Task.checkCancellation()
        let fetchedAt = Date()

        return LimitLensSnapshot(
            rateLimit: rateLimits.preferredRateLimit,
            resetCredits: resetCredits,
            planExpiresAt: account?.planExpiresAt,
            tokenUsage: usage?.summary,
            dailyUsageBuckets: usage?.dailyUsageBuckets ?? [],
            fetchedAt: fetchedAt
        )
    }
}

private struct EmptyResult: Decodable {
    init(from decoder: Decoder) throws {}
}

private struct JSONRPCEnvelope<Result: Decodable>: Decodable {
    let result: Result
}

private final class JSONRPCProcessSession: @unchecked Sendable {
    private let executablePath: String
    private let process = Process()
    private let inputPipe = Pipe()
    private let outputPipe = Pipe()
    private let store = JSONRPCResponseStore()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let requestTimeout: Duration
    private var nextId = 1
    private var readerTask: Task<Void, Never>?

    init(executablePath: String, requestTimeout: Duration) {
        self.executablePath = executablePath
        self.requestTimeout = requestTimeout
    }

    func start() throws {
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = ["app-server", "--stdio"]
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice
        try process.run()

        let reader = outputPipe.fileHandleForReading
        readerTask = Task.detached(priority: .utility) { [store] in
            var buffer = Data()
            while true {
                let chunk = reader.readData(ofLength: 1)
                if chunk.isEmpty {
                    if !buffer.isEmpty {
                        await store.receive(line: buffer)
                    }
                    break
                }

                if chunk.first == 10 {
                    await store.receive(line: buffer)
                    buffer.removeAll(keepingCapacity: true)
                } else {
                    buffer.append(chunk)
                }
            }
            await store.finish(
                error: .unavailable("Codex app-server stopped before replying.")
            )
        }
    }

    func terminate() {
        readerTask?.cancel()
        if process.isRunning {
            process.terminate()
        }
    }

    func request<Result: Decodable>(method: String, params: Any, as type: Result.Type) async throws -> Result {
        let id = nextId
        nextId += 1

        let request: [String: Any] = [
            "id": id,
            "method": method,
            "params": params
        ]

        let data = try JSONSerialization.data(withJSONObject: request)
        inputPipe.fileHandleForWriting.write(data)
        inputPipe.fileHandleForWriting.write(Data([10]))

        let responseData = try await store.response(for: id, timeout: requestTimeout)
        return try decoder.decode(JSONRPCEnvelope<Result>.self, from: responseData).result
    }
}

private actor JSONRPCResponseStore {
    private var pendingResponses: [Int: Data] = [:]
    private var pendingErrors: [Int: Error] = [:]
    private var continuations: [Int: CheckedContinuation<Data, Error>] = [:]
    private var timeoutTasks: [Int: Task<Void, Never>] = [:]
    private var cancelledResponseIDs: Set<Int> = []
    private var terminalError: CodexUsageError?

    func response(for id: Int, timeout: Duration) async throws -> Data {
        try Task.checkCancellation()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                if cancelledResponseIDs.remove(id) != nil {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                if let terminalError {
                    continuation.resume(throwing: terminalError)
                    return
                }
                if let response = pendingResponses.removeValue(forKey: id) {
                    continuation.resume(returning: response)
                    return
                }
                if let error = pendingErrors.removeValue(forKey: id) {
                    continuation.resume(throwing: error)
                    return
                }

                continuations[id] = continuation
                timeoutTasks[id] = Task { [weak self] in
                    do {
                        try await Task.sleep(for: timeout)
                    } catch {
                        return
                    }
                    await self?.failResponse(
                        id: id,
                        error: CodexUsageError.unavailable("Codex app-server did not respond in time.")
                    )
                }
            }
        } onCancel: {
            Task { await self.cancelResponse(id: id) }
        }
    }

    func receive(line: Data) {
        guard !line.isEmpty,
              let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              let id = object["id"] as? Int else {
            return
        }

        if let error = object["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "Codex app-server returned an error."
            resume(id: id, result: .failure(CodexUsageError.fromServerMessage(message)))
            return
        }

        resume(id: id, result: .success(line))
    }

    private func resume(id: Int, result: Result<Data, Error>) {
        timeoutTasks.removeValue(forKey: id)?.cancel()
        if let continuation = continuations.removeValue(forKey: id) {
            switch result {
            case .success(let data):
                continuation.resume(returning: data)
            case .failure(let error):
                continuation.resume(throwing: error)
            }
            return
        }

        if case .success(let data) = result {
            pendingResponses[id] = data
        } else if case .failure(let error) = result {
            pendingErrors[id] = error
        }
    }

    private func failResponse(id: Int, error: Error) {
        resume(id: id, result: .failure(error))
    }

    private func cancelResponse(id: Int) {
        timeoutTasks.removeValue(forKey: id)?.cancel()
        pendingResponses[id] = nil
        pendingErrors[id] = nil
        if let continuation = continuations.removeValue(forKey: id) {
            continuation.resume(throwing: CancellationError())
        } else {
            cancelledResponseIDs.insert(id)
        }
    }

    func finish(error: CodexUsageError) {
        terminalError = error
        let waiting = continuations
        continuations.removeAll()
        timeoutTasks.values.forEach { $0.cancel() }
        timeoutTasks.removeAll()
        pendingResponses.removeAll()
        pendingErrors.removeAll()
        for continuation in waiting.values {
            continuation.resume(throwing: error)
        }
    }
}
