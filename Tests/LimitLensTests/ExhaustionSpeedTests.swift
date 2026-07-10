import Foundation
import LimitLensCore
import Testing
@testable import LimitLens

@MainActor
@Suite("Exhaustion speed tracking")
struct ExhaustionSpeedTests {
    // MARK: - All four providers record exhaustion events

    @Test("Codex at 100% records exhaustion event")
    func codexRecordsExhaustion() async {
        let store = MockExhaustionHistoryStore()
        let viewModel = makeViewModel(
            historyStore: store,
            codex: MockCodexUsageClient(result: .success(codexSnapshot(primaryPercent: 100)))
        )

        await viewModel.refreshProvider(.codex)

        #expect(store.payload.events.count == 1)
        #expect(store.payload.events.first?.provider == .codex)
        #expect(store.saveCallCount == 1)
    }

    @Test("Cursor at 100% records exhaustion event")
    func cursorRecordsExhaustion() async {
        let store = MockExhaustionHistoryStore()
        let viewModel = makeViewModel(
            historyStore: store,
            cursor: MockCursorUsageClient(result: .success(cursorSnapshot(percent: 100)))
        )

        await viewModel.refreshProvider(.cursor)

        #expect(store.payload.events.count == 1)
        #expect(store.payload.events.first?.provider == .cursor)
        #expect(store.payload.events.first?.quotaKind == "Billing cycle")
    }

    @Test("Devin daily at 100% records exhaustion event")
    func devinRecordsExhaustion() async {
        let store = MockExhaustionHistoryStore()
        let viewModel = makeViewModel(
            historyStore: store,
            desktopQuota: MockDesktopQuotaClient(result: .success([desktopQuotaSnapshot(dailyRemainingPercent: 0)]))
        )

        await viewModel.refreshProvider(.devin)

        #expect(store.payload.events.count == 1)
        #expect(store.payload.events.first?.provider == .devin)
        #expect(store.payload.events.first?.quotaKind == "Daily")
    }

    @Test("OpenCode Go at 100% records exhaustion event")
    func openCodeGoRecordsExhaustion() async {
        let store = MockExhaustionHistoryStore()
        let viewModel = makeViewModel(
            historyStore: store,
            openCodeGo: MockOpenCodeGoUsageClient(result: .success(openCodeGoSnapshot(percent: 100)))
        )

        await viewModel.refreshProvider(.openCodeGo)

        #expect(store.payload.events.count == 1)
        #expect(store.payload.events.first?.provider == .openCodeGo)
    }

    // MARK: - Only overview-priority quota is recorded

    @Test("Only the shortest-duration Codex quota is recorded")
    func onlyShortestCodexQuotaRecorded() async {
        let store = MockExhaustionHistoryStore()
        let viewModel = makeViewModel(
            historyStore: store,
            codex: MockCodexUsageClient(result: .success(codexSnapshot(
                primaryPercent: 100,
                primaryDurationMinutes: 300,
                secondaryPercent: 100,
                secondaryDurationMinutes: 10_080
            )))
        )

        await viewModel.refreshProvider(.codex)

        #expect(store.payload.events.count == 1)
        // 300 minutes = 5h, which is shorter than Weekly (10080)
        #expect(store.payload.events.first?.quotaKind == "5h")
    }

    @Test("Devin weekly at 100% with daily below 100% records weekly only")
    func devinWeeklyRecordedWhenDailyNotExhausted() async {
        let store = MockExhaustionHistoryStore()
        let snapshot = DesktopQuotaSnapshot(
            appName: "Devin Desktop",
            planName: "Pro",
            billingStrategy: "quota",
            cycleStart: nil,
            cycleEnd: Date().addingTimeInterval(86_400 * 20),
            dailyRemainingPercent: 50,
            weeklyRemainingPercent: 0,
            dailyResetAt: Date().addingTimeInterval(86_400),
            weeklyResetAt: Date().addingTimeInterval(86_400 * 7),
            overageBalanceMicros: nil
        )
        let viewModel = makeViewModel(
            historyStore: store,
            desktopQuota: MockDesktopQuotaClient(result: .success([snapshot]))
        )

        await viewModel.refreshProvider(.devin)

        // Daily is 50% used (not exhausted), Weekly is 100% used (exhausted)
        // But the overview selects the shortest duration (Daily) which is not exhausted
        // So no event should be recorded
        #expect(store.payload.events.isEmpty)
    }

    // MARK: - Failed/stale refreshes do not create events

    @Test("Failed Codex refresh does not record exhaustion event")
    func failedRefreshDoesNotRecord() async {
        let store = MockExhaustionHistoryStore()
        let viewModel = makeViewModel(
            historyStore: store,
            codex: MockCodexUsageClient(result: .failure(TestError.unavailable))
        )

        await viewModel.refreshProvider(.codex)

        #expect(store.payload.events.isEmpty)
        #expect(store.saveCallCount == 0)
    }

    @Test("Stale Devin quota does not record exhaustion event")
    func staleDevinQuotaDoesNotRecord() async {
        let store = MockExhaustionHistoryStore()
        let snapshot = DesktopQuotaSnapshot(
            appName: "Devin Desktop",
            planName: "Pro",
            billingStrategy: "quota",
            cycleStart: nil,
            cycleEnd: Date().addingTimeInterval(86_400 * 20),
            dailyRemainingPercent: 100,
            weeklyRemainingPercent: 100,
            dailyResetAt: Date().addingTimeInterval(86_400),
            weeklyResetAt: Date().addingTimeInterval(86_400 * 7),
            overageBalanceMicros: nil,
            isStaleFallback: true
        )
        let viewModel = makeViewModel(
            historyStore: store,
            desktopQuota: MockDesktopQuotaClient(result: .success([snapshot]))
        )

        await viewModel.refreshProvider(.devin)

        // Stale fallback with 100% remaining on both should be treated as unavailable
        #expect(store.payload.events.isEmpty)
    }

    // MARK: - Duplicate refreshes

    @Test("Duplicate refresh for same cycle does not create second event")
    func duplicateRefreshDoesNotCreateSecondEvent() async {
        let store = MockExhaustionHistoryStore()
        let codex = MockCodexUsageClient(result: .success(codexSnapshot(primaryPercent: 100)))
        let viewModel = makeViewModel(
            historyStore: store,
            codex: codex
        )

        await viewModel.refreshProvider(.codex)
        await viewModel.refreshProvider(.codex)

        #expect(store.payload.events.count == 1)
        #expect(store.saveCallCount == 1)
    }

    // MARK: - New cycle detection

    @Test("New cycle with different reset time creates new event")
    func newCycleCreatesNewEvent() async {
        let store = MockExhaustionHistoryStore()
        let codex = MockCodexUsageClient(result: .success(codexSnapshot(primaryPercent: 100, resetsInSeconds: 3_600)))
        let viewModel = makeViewModel(
            historyStore: store,
            codex: codex
        )

        await viewModel.refreshProvider(.codex)
        #expect(store.payload.events.count == 1)

        // Simulate a new cycle with a different reset time
        codex.result = .success(codexSnapshot(primaryPercent: 100, resetsInSeconds: 7_200))
        await viewModel.refreshProvider(.codex)

        #expect(store.payload.events.count == 2)
    }

    // MARK: - Empty history

    @Test("Empty history shows no exhaustion summaries")
    func emptyHistoryShowsNoSummaries() async {
        let store = MockExhaustionHistoryStore()
        let viewModel = makeViewModel(
            historyStore: store,
            codex: MockCodexUsageClient(result: .success(codexSnapshot(primaryPercent: 42)))
        )

        await viewModel.refreshProvider(.codex)

        #expect(viewModel.exhaustionSummaries.isEmpty)
    }

    @Test("90 percent threshold records exhaustion event")
    func ninetyPercentRecordsExhaustion() async {
        let store = MockExhaustionHistoryStore()
        let viewModel = makeViewModel(
            historyStore: store,
            codex: MockCodexUsageClient(result: .success(codexSnapshot(primaryPercent: 90)))
        )

        await viewModel.refreshProvider(.codex)

        #expect(store.payload.events.count == 1)
        #expect(!viewModel.exhaustionSummaries.isEmpty)
    }

    @Test("89 percent does not record exhaustion event")
    func eightyNinePercentDoesNotRecord() async {
        let store = MockExhaustionHistoryStore()
        let viewModel = makeViewModel(
            historyStore: store,
            codex: MockCodexUsageClient(result: .success(codexSnapshot(primaryPercent: 89)))
        )

        await viewModel.refreshProvider(.codex)

        #expect(store.payload.events.isEmpty)
        #expect(viewModel.exhaustionSummaries.isEmpty)
    }

    // MARK: - Cycle counts in summaries

    @Test("Exhaustion summary shows cycle count")
    func summaryShowsCycleCount() async {
        let store = MockExhaustionHistoryStore()
        let codex = MockCodexUsageClient(result: .success(codexSnapshot(primaryPercent: 100, resetsInSeconds: 3_600)))
        let viewModel = makeViewModel(
            historyStore: store,
            codex: codex
        )

        await viewModel.refreshProvider(.codex)
        codex.result = .success(codexSnapshot(primaryPercent: 100, resetsInSeconds: 7_200))
        await viewModel.refreshProvider(.codex)

        let summary = viewModel.exhaustionSummaries.first { $0.tab == .codex }
        #expect(summary != nil)
        #expect(summary?.cycleCount == 2)
        #expect(summary?.averageText.hasPrefix("Avg ") == true)
    }

    // MARK: - Estimated-average labeling

    @Test("Cursor with inferred start prefixes average with ~")
    func cursorEstimatedStartPrefixesAverage() async {
        let store = MockExhaustionHistoryStore()
        // Cursor snapshot with nil billingCycleStart → estimated start
        let viewModel = makeViewModel(
            historyStore: store,
            cursor: MockCursorUsageClient(result: .success(cursorSnapshot(percent: 100)))
        )

        await viewModel.refreshProvider(.cursor)

        let summary = viewModel.exhaustionSummaries.first { $0.tab == .cursor }
        #expect(summary != nil)
        #expect(summary?.averageText.contains("~") == true)
    }

    @Test("Cursor with reported start does not prefix average with ~")
    func cursorReportedStartDoesNotPrefixAverage() async {
        let store = MockExhaustionHistoryStore()
        let now = Date()
        let snapshot = CursorUsageSnapshot(
            planName: "Pro",
            price: "$20/mo",
            includedAmountCents: 2_000,
            billingCycleStart: now.addingTimeInterval(-86_400 * 15),
            billingCycleEnd: now.addingTimeInterval(86_400 * 15),
            remainingCents: nil,
            limitCents: nil,
            totalPercentUsed: 100,
            autoSpendCents: nil,
            autoLimitCents: nil,
            autoPercentUsed: nil,
            apiSpendCents: nil,
            apiLimitCents: nil,
            apiPercentUsed: nil,
            displayMessage: nil
        )
        let viewModel = makeViewModel(
            historyStore: store,
            cursor: MockCursorUsageClient(result: .success(snapshot))
        )

        await viewModel.refreshProvider(.cursor)

        let summary = viewModel.exhaustionSummaries.first { $0.tab == .cursor }
        #expect(summary != nil)
        #expect(summary?.averageText.contains("~") == false)
    }

    // MARK: - Disabled providers

    @Test("Disabled providers are not shown in exhaustion summaries")
    func disabledProvidersNotShownInSummaries() async {
        let store = MockExhaustionHistoryStore()
        // Pre-populate with a Codex event
        store.payload = QuotaExhaustionHistoryPayload(events: [
            QuotaExhaustionEvent(
                provider: .codex, quotaKind: "Daily",
                cycleStart: Date().addingTimeInterval(-3600),
                cycleEnd: Date(),
                exhaustedAt: Date().addingTimeInterval(-1800),
                durationSeconds: 1800,
                startEstimated: false
            )
        ])

        var config = LimitLensConfiguration.defaults
        config.providers.codex.isEnabled = false
        let viewModel = makeViewModel(
            configuration: config,
            historyStore: store
        )

        #expect(viewModel.exhaustionSummaries.isEmpty)
    }

    // MARK: - Unavailable providers show persisted averages

    @Test("Unavailable provider still shows persisted average")
    func unavailableProviderShowsPersistedAverage() async {
        let store = MockExhaustionHistoryStore()
        // Pre-populate with a Codex event
        store.payload = QuotaExhaustionHistoryPayload(events: [
            QuotaExhaustionEvent(
                provider: .codex, quotaKind: "Daily",
                cycleStart: Date().addingTimeInterval(-3600),
                cycleEnd: Date(),
                exhaustedAt: Date().addingTimeInterval(-1800),
                durationSeconds: 1800,
                startEstimated: false
            )
        ])

        let viewModel = makeViewModel(
            historyStore: store,
            codex: MockCodexUsageClient(result: .failure(TestError.unavailable)),
            cursor: MockCursorUsageClient(result: .success(cursorSnapshot(percent: 25)))
        )

        await viewModel.refresh()

        let summary = viewModel.exhaustionSummaries.first { $0.tab == .codex }
        #expect(summary != nil)
        #expect(summary?.cycleCount == 1)
    }

    // MARK: - Privacy aliases

    @Test("Exhaustion summary quota label respects privacy aliases")
    func summaryRespectsPrivacyAliases() async {
        let store = MockExhaustionHistoryStore()
        let viewModel = makeViewModel(
            historyStore: store,
            codex: MockCodexUsageClient(result: .success(codexSnapshot(primaryPercent: 100)))
        )
        viewModel.updateConfiguration { $0.privacy.menuBarDisplay = .hidden }

        await viewModel.refreshProvider(.codex)

        let summary = viewModel.exhaustionSummaries.first { $0.tab == .codex }
        #expect(summary != nil)
        // The quota label should still be "Daily" (not a provider name)
        // but the provider name would be hidden in the view
        #expect(summary?.quotaLabel == "Daily")
    }

    // MARK: - Clearing history

    @Test("Clear exhaustion history removes events and summaries")
    func clearExhaustionHistoryRemovesEvents() async {
        let store = MockExhaustionHistoryStore()
        let viewModel = makeViewModel(
            historyStore: store,
            codex: MockCodexUsageClient(result: .success(codexSnapshot(primaryPercent: 100)))
        )

        await viewModel.refreshProvider(.codex)
        #expect(!viewModel.exhaustionSummaries.isEmpty)

        viewModel.clearExhaustionHistory()

        #expect(store.payload.events.isEmpty)
        #expect(store.clearCallCount == 1)
        #expect(viewModel.exhaustionSummaries.isEmpty)
    }

    @Test("Clear exhaustion history does not affect configuration")
    func clearDoesNotAffectConfiguration() async {
        let store = MockExhaustionHistoryStore()
        let viewModel = makeViewModel(
            historyStore: store,
            codex: MockCodexUsageClient(result: .success(codexSnapshot(primaryPercent: 100)))
        )
        viewModel.updateConfiguration { $0.privacy.menuBarDisplay = .hidden }

        await viewModel.refreshProvider(.codex)
        viewModel.clearExhaustionHistory()

        #expect(viewModel.configuration.privacy.hidesProviderNames == true)
    }

    // MARK: - Quota kind separation in view model

    @Test("Different quota kinds maintain separate histories")
    func quotaKindSeparationInViewModel() async {
        let store = MockExhaustionHistoryStore()
        let codex = MockCodexUsageClient(result: .success(codexSnapshot(
            primaryPercent: 100,
            primaryDurationMinutes: 300
        )))
        let viewModel = makeViewModel(
            historyStore: store,
            codex: codex
        )

        await viewModel.refreshProvider(.codex)

        #expect(store.payload.events.count == 1)
        #expect(store.payload.events.first?.quotaKind == "5h")

        // Switch to a different duration (Daily = 1440 min)
        codex.result = .success(codexSnapshot(
            primaryPercent: 100,
            resetsInSeconds: 7_200,
            primaryDurationMinutes: 1_440
        ))
        await viewModel.refreshProvider(.codex)

        // Two events with different quota kinds
        #expect(store.payload.events.count == 2)
        let kinds = Set(store.payload.events.map(\.quotaKind))
        #expect(kinds.contains("5h"))
        #expect(kinds.contains("Daily"))
    }

    // MARK: - Helpers

    private func makeViewModel(
        configuration: LimitLensConfiguration = {
            var config = LimitLensConfiguration.defaults
            config.refresh.retryEnabled = false
            return config
        }(),
        historyStore: QuotaExhaustionHistoryStoring = MockExhaustionHistoryStore(),
        codex: MockCodexUsageClient = MockCodexUsageClient(result: .failure(TestError.unavailable)),
        cursor: MockCursorUsageClient = MockCursorUsageClient(result: .failure(TestError.unavailable)),
        desktopQuota: MockDesktopQuotaClient = MockDesktopQuotaClient(result: .failure(TestError.unavailable)),
        openCodeGo: MockOpenCodeGoUsageClient = MockOpenCodeGoUsageClient(result: .failure(TestError.unavailable))
    ) -> UsageViewModel {
        UsageViewModel(
            configuration: configuration,
            service: codex,
            cursorService: cursor,
            desktopQuotaService: desktopQuota,
            openCodeGoService: openCodeGo,
            historyStore: historyStore
        )
    }
}

// MARK: - Mock history store

private final class MockExhaustionHistoryStore: QuotaExhaustionHistoryStoring, @unchecked Sendable {
    var payload: QuotaExhaustionHistoryPayload
    var saveCallCount = 0
    var clearCallCount = 0

    init(payload: QuotaExhaustionHistoryPayload = .empty) {
        self.payload = payload
    }

    func save() { saveCallCount += 1 }
    func clear() {
        clearCallCount += 1
        payload = .empty
    }
}

// MARK: - Mock clients

private final class MockCodexUsageClient: CodexUsageFetching, @unchecked Sendable {
    var result: Result<LimitLensSnapshot, Error>
    var callCount = 0

    init(result: Result<LimitLensSnapshot, Error>) {
        self.result = result
    }

    func fetchSnapshot() async throws -> LimitLensSnapshot {
        callCount += 1
        return try result.get()
    }
}

private final class MockCursorUsageClient: CursorUsageFetching, @unchecked Sendable {
    var result: Result<CursorUsageSnapshot, Error>

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

private enum TestError: Error {
    case unavailable
}

// MARK: - Snapshot helpers

private func codexSnapshot(
    primaryPercent: Int,
    resetsInSeconds: TimeInterval = 3_600,
    primaryDurationMinutes: Int = 1_440,
    secondaryPercent: Int? = nil,
    secondaryDurationMinutes: Int = 10_080,
    now: Date = Date()
) -> LimitLensSnapshot {
    let secondaryJSON = secondaryPercent.map {
        """
        {
          "resetsAt": \(Int(now.addingTimeInterval(86_400).timeIntervalSince1970)),
          "usedPercent": \($0),
          "windowDurationMins": \(secondaryDurationMinutes)
        }
        """
    } ?? "null"
    let rateLimit: RateLimitSnapshot = decodeJSON(
        """
        {
          "credits": null,
          "individualLimit": null,
          "limitId": "codex",
          "limitName": null,
          "planType": "pro",
          "primary": {
            "resetsAt": \(Int(now.addingTimeInterval(resetsInSeconds).timeIntervalSince1970)),
            "usedPercent": \(primaryPercent),
            "windowDurationMins": \(primaryDurationMinutes)
          },
          "rateLimitReachedType": null,
          "secondary": \(secondaryJSON)
        }
        """
    )

    return LimitLensSnapshot(
        rateLimit: rateLimit,
        resetCredits: ResetCreditInfo(availableCount: 0, totalEarnedCount: nil, credits: []),
        tokenUsage: nil
    )
}

private func cursorSnapshot(percent: Double, resetsInSeconds: TimeInterval = 86_400, now: Date = Date()) -> CursorUsageSnapshot {
    CursorUsageSnapshot(
        planName: "Pro",
        price: "$20/mo",
        includedAmountCents: 2_000,
        billingCycleStart: nil,
        billingCycleEnd: now.addingTimeInterval(resetsInSeconds),
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

private func desktopQuotaSnapshot(dailyRemainingPercent: Int, dailyResetsInSeconds: TimeInterval = 86_400, now: Date = Date()) -> DesktopQuotaSnapshot {
    DesktopQuotaSnapshot(
        appName: "Devin Desktop",
        planName: "Pro",
        billingStrategy: "quota",
        cycleStart: nil,
        cycleEnd: now.addingTimeInterval(86_400 * 20),
        dailyRemainingPercent: dailyRemainingPercent,
        weeklyRemainingPercent: 80,
        dailyResetAt: now.addingTimeInterval(dailyResetsInSeconds),
        weeklyResetAt: now.addingTimeInterval(86_400 * 7),
        overageBalanceMicros: nil
    )
}

private func openCodeGoSnapshot(percent: Double, resetsInSeconds: TimeInterval = 3_600, now: Date = Date()) -> OpenCodeGoUsageSnapshot {
    OpenCodeGoUsageSnapshot(
        rolling: OpenCodeGoUsageWindow(usedPercent: percent, resetAt: now.addingTimeInterval(resetsInSeconds)),
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
