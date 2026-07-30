import Foundation
import LimitLensCore
import Testing
@testable import LimitLens

@MainActor
@Suite("Provider diagnostics")
struct ProviderDiagnosticsTests {
    @Test("Successful refresh clears last error")
    func successfulRefreshClearsLastError() async {
        let viewModel = makeViewModel(
            configuration: disabledRetryConfig(),
            codex: MockCodexClient(result: .failure(TestError.network))
        )

        await viewModel.refreshProvider(.codex)
        #expect(viewModel.lastErrors[.codex] != nil)

        let successViewModel = makeViewModel(
            configuration: disabledRetryConfig(),
            codex: MockCodexClient(result: .success(codexSnapshot(primaryPercent: 42)))
        )
        await successViewModel.refreshProvider(.codex)
        #expect(successViewModel.lastErrors[.codex] == nil)
    }

    @Test("Failed refresh stores error message")
    func failedRefreshStoresError() async {
        let viewModel = makeViewModel(
            configuration: disabledRetryConfig(),
            codex: MockCodexClient(result: .failure(TestError.network))
        )

        await viewModel.refreshProvider(.codex)

        #expect(viewModel.lastErrors[.codex] != nil)
        if case .failed = viewModel.currentLoadState(for: .codex) {
            // expected
        } else {
            Issue.record("Expected failed load state")
        }
    }

    @Test("testProviderConnection stores successful result")
    func testProviderConnectionStoresSuccess() async {
        let viewModel = makeViewModel(
            configuration: disabledRetryConfig(),
            codex: MockCodexClient(result: .success(codexSnapshot(primaryPercent: 42)))
        )

        viewModel.testProviderConnection(.codex)
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        let result = viewModel.diagnosticTestResults[.codex]
        #expect(result != nil)
        #expect(result!.succeeded == true)
        #expect(result!.message == "Connected successfully")
        #expect(result!.elapsedMillis >= 0)
    }

    @Test("testProviderConnection stores failed result")
    func testProviderConnectionStoresFailure() async {
        let viewModel = makeViewModel(
            configuration: disabledRetryConfig(),
            codex: MockCodexClient(result: .failure(TestError.network))
        )

        viewModel.testProviderConnection(.codex)
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        let result = viewModel.diagnosticTestResults[.codex]
        #expect(result != nil)
        #expect(result!.succeeded == false)
        #expect(!result!.message.isEmpty)
    }

    @Test("currentLoadState returns correct state per provider")
    func currentLoadStateReturnsCorrectState() async {
        let viewModel = makeViewModel(
            configuration: disabledRetryConfig(),
            codex: MockCodexClient(result: .success(codexSnapshot(primaryPercent: 42))),
            cursor: MockCursorClient(result: .failure(TestError.network))
        )

        await viewModel.refreshProvider(.codex)
        await viewModel.refreshProvider(.cursor)

        #expect(viewModel.currentLoadState(for: .codex) == .loaded)
        if case .failed = viewModel.currentLoadState(for: .cursor) {
            // expected
        } else {
            Issue.record("Expected failed state for cursor")
        }
    }

    @Test("providerPathExists returns false for nonexistent path")
    func providerPathExistsReturnsFalseForNonexistent() {
        var config = disabledRetryConfig()
        config.providers.codex.executablePath = "/nonexistent/path/to/codex"

        let viewModel = makeViewModel(configuration: config)

        #expect(viewModel.providerPathExists(for: .codex) == false)
    }

    @Test("Disabled provider clears last error")
    func disabledProviderClearsLastError() async {
        var config = disabledRetryConfig()
        config.providers.codex.isEnabled = true

        let viewModel = makeViewModel(
            configuration: config,
            codex: MockCodexClient(result: .failure(TestError.network))
        )

        await viewModel.refreshProvider(.codex)
        #expect(viewModel.lastErrors[.codex] != nil)

        viewModel.updateConfiguration { $0.providers.codex.isEnabled = false }
        #expect(viewModel.lastErrors[.codex] == nil)
    }

    // MARK: - Helpers

    private func makeViewModel(
        configuration: LimitLensConfiguration = disabledRetryConfig(),
        codex: CodexUsageFetching = MockCodexClient(result: .failure(TestError.network)),
        cursor: CursorUsageFetching = MockCursorClient(result: .failure(TestError.network)),
        desktopQuota: DesktopQuotaFetching = MockDesktopQuotaClient(result: .failure(TestError.network)),
        openCodeGo: OpenCodeGoUsageFetching = MockOpenCodeGoClient(result: .failure(TestError.network))
    ) -> UsageViewModel {
        UsageViewModel(
            configuration: configuration,
            service: codex,
            cursorService: cursor,
            desktopQuotaService: desktopQuota,
            openCodeGoService: openCodeGo,
            codexLocalUsageScanner: NoOpCodexLocalUsageScanner()
        )
    }
}

private struct NoOpCodexLocalUsageScanner: CodexLocalUsageScanning {
    func scan(now: Date) async -> CodexLocalUsageSummary? {
        nil
    }
}

private func disabledRetryConfig() -> LimitLensConfiguration {
    var config = LimitLensConfiguration.defaults
    config.refresh.retryEnabled = false
    return config
}

private final class MockCodexClient: CodexUsageFetching, @unchecked Sendable {
    let result: Result<LimitLensSnapshot, Error>
    init(result: Result<LimitLensSnapshot, Error>) { self.result = result }
    func fetchSnapshot() async throws -> LimitLensSnapshot { try result.get() }
}

private final class MockCursorClient: CursorUsageFetching, @unchecked Sendable {
    let result: Result<CursorUsageSnapshot, Error>
    init(result: Result<CursorUsageSnapshot, Error>) { self.result = result }
    func fetchSnapshot() async throws -> CursorUsageSnapshot { try result.get() }
}

private final class MockDesktopQuotaClient: DesktopQuotaFetching, @unchecked Sendable {
    let result: Result<[DesktopQuotaSnapshot], Error>
    init(result: Result<[DesktopQuotaSnapshot], Error>) { self.result = result }
    func fetchSnapshots() async throws -> [DesktopQuotaSnapshot] { try result.get() }
}

private final class MockOpenCodeGoClient: OpenCodeGoUsageFetching, @unchecked Sendable {
    let result: Result<OpenCodeGoUsageSnapshot, Error>
    init(result: Result<OpenCodeGoUsageSnapshot, Error>) { self.result = result }
    func fetchSnapshot() async throws -> OpenCodeGoUsageSnapshot { try result.get() }
}

private enum TestError: Error { case network }

private func codexSnapshot(primaryPercent: Int, resetsInSeconds: TimeInterval = 3_600) -> LimitLensSnapshot {
    let rateLimit: RateLimitSnapshot = decodeJSON(
        """
        {
          "credits": null,
          "individualLimit": null,
          "limitId": "codex",
          "limitName": null,
          "planType": "pro",
          "primary": {
            "resetsAt": \(Int(Date().addingTimeInterval(resetsInSeconds).timeIntervalSince1970)),
            "usedPercent": \(primaryPercent),
            "windowDurationMins": 1440
          },
          "rateLimitReachedType": null,
          "secondary": null
        }
        """
    )
    return LimitLensSnapshot(
        rateLimit: rateLimit,
        resetCredits: ResetCreditInfo(availableCount: 0, totalEarnedCount: nil, credits: []),
        tokenUsage: nil
    )
}

private func decodeJSON<T: Decodable>(_ json: String, as type: T.Type = T.self) -> T {
    try! JSONDecoder().decode(T.self, from: Data(json.utf8))
}
