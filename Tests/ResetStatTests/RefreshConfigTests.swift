import Foundation
import ResetStatCore
import Testing
@testable import ResetStat

@MainActor
@Suite("Refresh configurability")
struct RefreshConfigTests {
    @Test("Per-provider refresh updates lastFetchAt for that provider only")
    func perProviderRefreshUpdatesLastFetchAt() async {
        let codex = MockCodexUsageClient(result: .success(codexSnapshot(primaryPercent: 42)))
        let viewModel = makeViewModel(codex: codex)

        await viewModel.refreshProvider(.codex)

        #expect(viewModel.lastFetchAt[.codex] != nil)
        #expect(viewModel.lastFetchAt[.cursor] == nil)
        #expect(viewModel.lastFetchAt[.devin] == nil)
        #expect(viewModel.lastFetchAt[.openCodeGo] == nil)
        #expect(codex.callCount == 1)
    }

    @Test("Full refresh updates lastFetchAt for all enabled providers")
    func fullRefreshUpdatesAllLastFetchAt() async {
        let viewModel = makeViewModel(
            codex: MockCodexUsageClient(result: .success(codexSnapshot(primaryPercent: 42))),
            cursor: MockCursorUsageClient(result: .success(cursorSnapshot(percent: 25))),
            desktopQuota: MockDesktopQuotaClient(result: .success([desktopQuotaSnapshot(dailyRemainingPercent: 80)])),
            openCodeGo: MockOpenCodeGoUsageClient(result: .success(openCodeGoSnapshot(percent: 5)))
        )

        await viewModel.refresh()

        #expect(viewModel.lastFetchAt[.codex] != nil)
        #expect(viewModel.lastFetchAt[.cursor] != nil)
        #expect(viewModel.lastFetchAt[.devin] != nil)
        #expect(viewModel.lastFetchAt[.openCodeGo] != nil)
    }

    @Test("Per-provider refresh does not refresh other providers")
    func perProviderRefreshDoesNotRefreshOthers() async {
        let codex = MockCodexUsageClient(result: .success(codexSnapshot(primaryPercent: 42)))
        let cursor = CountingCursorClient(result: .success(cursorSnapshot(percent: 25)))
        let viewModel = makeViewModel(codex: codex, cursor: cursor)

        await viewModel.refreshProvider(.codex)

        #expect(codex.callCount == 1)
        #expect(cursor.callCount == 0)
    }

    @Test("Per-provider refresh is gated by isRefreshing for that provider")
    func perProviderRefreshIsGatedByIsRefreshing() async {
        let codex = MockCodexUsageClient(result: .success(codexSnapshot(primaryPercent: 42)), delayNanoseconds: 100_000_000)
        let viewModel = makeViewModel(codex: codex)

        async let first: Void = viewModel.refreshProvider(.codex)
        await Task.yield()
        await viewModel.refreshProvider(.codex)
        await first

        #expect(codex.callCount == 1)
    }

    @Test("Retry succeeds on second attempt when retry is enabled")
    func retrySucceedsOnSecondAttempt() async {
        let codex = RetryableCodexClient(failureCount: 1, snapshot: codexSnapshot(primaryPercent: 42))
        var config = ResetStatConfiguration.defaults
        config.refresh.retryEnabled = true
        config.refresh.maxRetryAttempts = 3
        let viewModel = UsageViewModel(
            configuration: config,
            service: codex,
            cursorService: MockCursorUsageClient(result: .success(cursorSnapshot(percent: 25))),
            desktopQuotaService: MockDesktopQuotaClient(result: .success([desktopQuotaSnapshot(dailyRemainingPercent: 80)])),
            openCodeGoService: MockOpenCodeGoUsageClient(result: .success(openCodeGoSnapshot(percent: 5)))
        )
        viewModel.retryDelayProvider = { _ in 0 }

        await viewModel.refreshProvider(.codex)

        #expect(viewModel.state == .loaded)
        #expect(codex.attemptCount == 2)
        #expect(viewModel.lastFetchAt[.codex] != nil)
    }

    @Test("Retry exhausts attempts and reports failure")
    func retryExhaustsAttemptsAndReportsFailure() async {
        let codex = RetryableCodexClient(failureCount: 10, snapshot: codexSnapshot(primaryPercent: 42))
        var config = ResetStatConfiguration.defaults
        config.refresh.retryEnabled = true
        config.refresh.maxRetryAttempts = 2
        let viewModel = UsageViewModel(
            configuration: config,
            service: codex,
            cursorService: MockCursorUsageClient(result: .success(cursorSnapshot(percent: 25))),
            desktopQuotaService: MockDesktopQuotaClient(result: .success([desktopQuotaSnapshot(dailyRemainingPercent: 80)])),
            openCodeGoService: MockOpenCodeGoUsageClient(result: .success(openCodeGoSnapshot(percent: 5)))
        )
        viewModel.retryDelayProvider = { _ in 0 }

        await viewModel.refreshProvider(.codex)

        #expect(codex.attemptCount == 2)
        if case .failed = viewModel.state {
            // expected
        } else {
            Issue.record("Expected failed state after exhausting retries")
        }
    }

    @Test("Retry disabled calls operation once")
    func retryDisabledCallsOnce() async {
        let codex = RetryableCodexClient(failureCount: 10, snapshot: codexSnapshot(primaryPercent: 42))
        var config = ResetStatConfiguration.defaults
        config.refresh.retryEnabled = false
        let viewModel = UsageViewModel(
            configuration: config,
            service: codex,
            cursorService: MockCursorUsageClient(result: .success(cursorSnapshot(percent: 25))),
            desktopQuotaService: MockDesktopQuotaClient(result: .success([desktopQuotaSnapshot(dailyRemainingPercent: 80)])),
            openCodeGoService: MockOpenCodeGoUsageClient(result: .success(openCodeGoSnapshot(percent: 5)))
        )

        await viewModel.refreshProvider(.codex)

        #expect(codex.attemptCount == 1)
    }

    private func makeViewModel(
        configuration: ResetStatConfiguration = {
            var config = ResetStatConfiguration.defaults
            config.refresh.retryEnabled = false
            return config
        }(),
        codex: CodexUsageFetching = MockCodexUsageClient(result: .failure(TestError.unavailable)),
        cursor: CursorUsageFetching = MockCursorUsageClient(result: .failure(TestError.unavailable)),
        desktopQuota: DesktopQuotaFetching = MockDesktopQuotaClient(result: .failure(TestError.unavailable)),
        openCodeGo: OpenCodeGoUsageFetching = MockOpenCodeGoUsageClient(result: .failure(TestError.unavailable))
    ) -> UsageViewModel {
        UsageViewModel(
            configuration: configuration,
            service: codex,
            cursorService: cursor,
            desktopQuotaService: desktopQuota,
            openCodeGoService: openCodeGo
        )
    }
}

private final class MockCodexUsageClient: CodexUsageFetching, @unchecked Sendable {
    var result: Result<ResetStatSnapshot, Error>
    var callCount = 0
    let delayNanoseconds: UInt64

    init(result: Result<ResetStatSnapshot, Error>, delayNanoseconds: UInt64 = 0) {
        self.result = result
        self.delayNanoseconds = delayNanoseconds
    }

    func fetchSnapshot() async throws -> ResetStatSnapshot {
        callCount += 1
        if delayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }
        return try result.get()
    }
}

private final class MockCursorUsageClient: CursorUsageFetching, @unchecked Sendable {
    let result: Result<CursorUsageSnapshot, Error>

    init(result: Result<CursorUsageSnapshot, Error>) {
        self.result = result
    }

    func fetchSnapshot() async throws -> CursorUsageSnapshot {
        try result.get()
    }
}

private final class MockDesktopQuotaClient: DesktopQuotaFetching, @unchecked Sendable {
    let result: Result<[DesktopQuotaSnapshot], Error>

    init(result: Result<[DesktopQuotaSnapshot], Error>) {
        self.result = result
    }

    func fetchSnapshots() async throws -> [DesktopQuotaSnapshot] {
        try result.get()
    }
}

private final class MockOpenCodeGoUsageClient: OpenCodeGoUsageFetching, @unchecked Sendable {
    let result: Result<OpenCodeGoUsageSnapshot, Error>

    init(result: Result<OpenCodeGoUsageSnapshot, Error>) {
        self.result = result
    }

    func fetchSnapshot() async throws -> OpenCodeGoUsageSnapshot {
        try result.get()
    }
}

private final class CountingCursorClient: CursorUsageFetching, @unchecked Sendable {
    let result: Result<CursorUsageSnapshot, Error>
    var callCount = 0

    init(result: Result<CursorUsageSnapshot, Error>) {
        self.result = result
    }

    func fetchSnapshot() async throws -> CursorUsageSnapshot {
        callCount += 1
        return try result.get()
    }
}

private final class RetryableCodexClient: CodexUsageFetching, @unchecked Sendable {
    let failureCount: Int
    let snapshot: ResetStatSnapshot
    var attemptCount = 0

    init(failureCount: Int, snapshot: ResetStatSnapshot) {
        self.failureCount = failureCount
        self.snapshot = snapshot
    }

    func fetchSnapshot() async throws -> ResetStatSnapshot {
        attemptCount += 1
        if attemptCount <= failureCount {
            throw TestError.unavailable
        }
        return snapshot
    }
}

private enum TestError: Error {
    case unavailable
}

private func codexSnapshot(primaryPercent: Int, resetsInSeconds: TimeInterval = 3_600) -> ResetStatSnapshot {
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

    return ResetStatSnapshot(
        rateLimit: rateLimit,
        resetCredits: ResetCreditInfo(availableCount: 0, totalEarnedCount: nil, credits: []),
        tokenUsage: nil
    )
}

private func cursorSnapshot(percent: Double, resetsInSeconds: TimeInterval = 86_400) -> CursorUsageSnapshot {
    CursorUsageSnapshot(
        planName: "Pro",
        price: "$20/mo",
        includedAmountCents: 2_000,
        billingCycleStart: nil,
        billingCycleEnd: Date().addingTimeInterval(resetsInSeconds),
        remainingCents: nil,
        limitCents: nil,
        totalPercentUsed: percent,
        autoSpendCents: nil,
        autoLimitCents: nil,
        autoPercentUsed: nil,
        apiSpendCents: nil,
        apiLimitCents: nil,
        apiPercentUsed: nil,
        displayMessage: nil
    )
}

private func desktopQuotaSnapshot(dailyRemainingPercent: Int, dailyResetsInSeconds: TimeInterval = 86_400) -> DesktopQuotaSnapshot {
    DesktopQuotaSnapshot(
        appName: "Devin Desktop",
        planName: "Pro",
        billingStrategy: "quota",
        cycleStart: nil,
        cycleEnd: Date().addingTimeInterval(86_400 * 20),
        dailyRemainingPercent: dailyRemainingPercent,
        weeklyRemainingPercent: 80,
        dailyResetAt: Date().addingTimeInterval(dailyResetsInSeconds),
        weeklyResetAt: Date().addingTimeInterval(86_400 * 7),
        overageBalanceMicros: nil
    )
}

private func openCodeGoSnapshot(percent: Double, resetsInSeconds: TimeInterval = 3_600) -> OpenCodeGoUsageSnapshot {
    OpenCodeGoUsageSnapshot(
        rolling: OpenCodeGoUsageWindow(usedPercent: percent, resetAt: Date().addingTimeInterval(resetsInSeconds)),
        weekly: nil,
        monthly: nil,
        billing: nil,
        source: "Test"
    )
}

private func decodeJSON<T: Decodable>(_ json: String, as type: T.Type = T.self) -> T {
    do {
        return try JSONDecoder().decode(T.self, from: Data(json.utf8))
    } catch {
        Issue.record("Failed to decode test JSON: \(error)")
        fatalError("Failed to decode test JSON")
    }
}
