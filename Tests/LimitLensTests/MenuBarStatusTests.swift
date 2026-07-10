import Foundation
import LimitLensCore
import Testing
@testable import LimitLens

@MainActor
@Suite("Menu bar status indicators")
struct MenuBarStatusTests {
    @Test("Initial no-data state renders loading title and indicators")
    func initialStateRendersLoadingStatus() {
        let viewModel = makeViewModel()
        let status = viewModel.menuBarStatus

        #expect(status.title == "· · · ·")
        #expect(status.indicators.map(\.state) == [.loading, .loading, .loading, .loading])
    }

    @Test("Critical provider drives title and severity")
    func criticalProviderDrivesTitle() async {
        let viewModel = makeViewModel(
            codex: MockCodexUsageClient(result: .success(codexSnapshot(primaryPercent: 92))),
            cursor: MockCursorUsageClient(result: .success(cursorSnapshot(percent: 25))),
            desktopQuota: MockDesktopQuotaClient(result: .success([desktopQuotaSnapshot(dailyRemainingPercent: 80)])),
            openCodeGo: MockOpenCodeGoUsageClient(result: .success(openCodeGoSnapshot(percent: 5)))
        )

        await viewModel.refresh()
        let status = viewModel.menuBarStatus

        #expect(status.title == "█ ▃ ▂ ▁")
        #expect(status.severity == .critical)
        #expect(status.indicators.first?.state == .critical)
        #expect(status.helpText.contains("Codex Daily 92% used"))
    }

    @Test("Exhausted shortest Codex window drives menu bar ring")
    func exhaustedShortestCodexWindowDrivesMenuBarRing() async {
        let viewModel = makeViewModel(
            codex: MockCodexUsageClient(result: .success(codexSnapshot(
                primaryPercent: 100,
                primaryDurationMinutes: 300,
                secondaryPercent: 15,
                secondaryDurationMinutes: 10_080
            ))),
            cursor: MockCursorUsageClient(result: .success(cursorSnapshot(percent: 25))),
            desktopQuota: MockDesktopQuotaClient(result: .success([desktopQuotaSnapshot(dailyRemainingPercent: 80)])),
            openCodeGo: MockOpenCodeGoUsageClient(result: .success(openCodeGoSnapshot(percent: 5)))
        )

        await viewModel.refresh()
        let codex = viewModel.menuBarStatus.indicators.first { $0.tab == .codex }

        #expect(codex?.percentUsed == 100)
        #expect(codex?.state == .critical)
        #expect(viewModel.menuBarStatus.helpText.contains("Codex 5h 100% used"))
    }

    @Test("Secondary limit percent flows through to menu bar indicator")
    func secondaryPercentFlowsToIndicator() async {
        let viewModel = makeViewModel(
            codex: MockCodexUsageClient(result: .success(codexSnapshot(
                primaryPercent: 30,
                primaryDurationMinutes: 1_440,
                secondaryPercent: 75,
                secondaryDurationMinutes: 10_080
            ))),
            cursor: MockCursorUsageClient(result: .success(cursorSnapshot(percent: 25))),
            desktopQuota: MockDesktopQuotaClient(result: .success([desktopQuotaSnapshot(dailyRemainingPercent: 80)])),
            openCodeGo: MockOpenCodeGoUsageClient(result: .success(openCodeGoSnapshot(percent: 5)))
        )

        await viewModel.refresh()
        let codex = viewModel.menuBarStatus.indicators.first { $0.tab == .codex }

        #expect(codex?.percentUsed == 30)
        #expect(codex?.secondaryPercentUsed == 75)
        #expect(codex?.state == .healthy)
    }

    @Test("Secondary percent is nil when provider has no secondary limit")
    func secondaryPercentNilWithoutSecondaryLimit() async {
        let viewModel = makeViewModel(
            codex: MockCodexUsageClient(result: .success(codexSnapshot(primaryPercent: 42))),
            cursor: MockCursorUsageClient(result: .success(cursorSnapshot(percent: 25))),
            desktopQuota: MockDesktopQuotaClient(result: .success([desktopQuotaSnapshot(dailyRemainingPercent: 80)])),
            openCodeGo: MockOpenCodeGoUsageClient(result: .success(openCodeGoSnapshot(percent: 5)))
        )

        await viewModel.refresh()
        let cursor = viewModel.menuBarStatus.indicators.first { $0.tab == .cursor }

        #expect(cursor?.secondaryPercentUsed == nil)
    }

    @Test("Tinting flag flows through to menu bar snapshot")
    func tintingFlagFlowsToSnapshot() async {
        let viewModel = makeViewModel(
            codex: MockCodexUsageClient(result: .success(codexSnapshot(primaryPercent: 30, secondaryPercent: 75)))
        )

        await viewModel.refresh()
        #expect(viewModel.menuBarStatus.secondaryLimitTintingEnabled == true)

        viewModel.updateConfiguration { $0.privacy.secondaryLimitTintingEnabled = false }
        #expect(viewModel.menuBarStatus.secondaryLimitTintingEnabled == false)
    }

    @Test("Auto display mode resolves to logos or countdowns")
    func autoDisplayModeResolvesToLogosOrCountdowns() async {
        let viewModel = makeViewModel(
            codex: MockCodexUsageClient(result: .success(codexSnapshot(primaryPercent: 30)))
        )

        await viewModel.refresh()
        viewModel.updateConfiguration { $0.privacy.menuBarDisplay = .auto }

        let resolved = viewModel.menuBarStatus.menuBarDisplay
        #expect(resolved == .logos || resolved == .countdowns)
        #expect(resolved != .auto)
    }

    @Test("Warning provider drives title when no provider is critical")
    func warningProviderDrivesTitle() async {
        let viewModel = makeViewModel(
            codex: MockCodexUsageClient(result: .success(codexSnapshot(primaryPercent: 12))),
            cursor: MockCursorUsageClient(result: .success(cursorSnapshot(percent: 72))),
            desktopQuota: MockDesktopQuotaClient(result: .success([desktopQuotaSnapshot(dailyRemainingPercent: 80)])),
            openCodeGo: MockOpenCodeGoUsageClient(result: .success(openCodeGoSnapshot(percent: 5)))
        )

        await viewModel.refresh()
        let status = viewModel.menuBarStatus

        #expect(status.title == "▁ ▆ ▂ ▁")
        #expect(status.severity == .warning)
        #expect(status.indicators.map(\.tab) == [.codex, .cursor, .devin, .openCodeGo])
        #expect(status.indicators[1].state == .warning)
    }

    @Test("Provider failure without cached data renders unavailable state")
    func failureWithoutCachedDataRendersUnavailable() async {
        let viewModel = makeViewModel(
            codex: MockCodexUsageClient(result: .failure(TestError.unavailable)),
            cursor: MockCursorUsageClient(result: .success(cursorSnapshot(percent: 25))),
            desktopQuota: MockDesktopQuotaClient(result: .success([desktopQuotaSnapshot(dailyRemainingPercent: 80)])),
            openCodeGo: MockOpenCodeGoUsageClient(result: .success(openCodeGoSnapshot(percent: 5)))
        )

        await viewModel.refresh()
        let status = viewModel.menuBarStatus

        #expect(status.title == "? ▃ ▂ ▁")
        #expect(status.indicators.first?.state == .unavailable)
        #expect(status.helpText.contains("Codex unavailable"))
    }

    @Test("Provider failure with cached data renders stale state")
    func failureWithCachedDataRendersStale() async {
        let codex = MockCodexUsageClient(result: .success(codexSnapshot(primaryPercent: 42)))
        let viewModel = makeViewModel(
            codex: codex,
            cursor: MockCursorUsageClient(result: .success(cursorSnapshot(percent: 25))),
            desktopQuota: MockDesktopQuotaClient(result: .success([desktopQuotaSnapshot(dailyRemainingPercent: 80)])),
            openCodeGo: MockOpenCodeGoUsageClient(result: .success(openCodeGoSnapshot(percent: 5)))
        )

        await viewModel.refresh()
        codex.result = .failure(TestError.unavailable)
        await viewModel.refresh()
        let status = viewModel.menuBarStatus

        #expect(status.title == "▄ ▃ ▂ ▁")
        #expect(status.indicators.first?.state == .stale(.healthy))
        #expect(status.helpText.contains("Codex Daily 42% used (stale healthy 42%)"))
    }

    @Test("Privacy mode uses provider aliases in help text")
    func privacyModeUsesProviderAliases() async {
        let viewModel = makeViewModel(
            codex: MockCodexUsageClient(result: .success(codexSnapshot(primaryPercent: 42))),
            cursor: MockCursorUsageClient(result: .success(cursorSnapshot(percent: 25))),
            desktopQuota: MockDesktopQuotaClient(result: .success([desktopQuotaSnapshot(dailyRemainingPercent: 80)])),
            openCodeGo: MockOpenCodeGoUsageClient(result: .success(openCodeGoSnapshot(percent: 5)))
        )

        await viewModel.refresh()
        viewModel.updateConfiguration { $0.privacy.menuBarDisplay = .hidden }
        let status = viewModel.menuBarStatus

        #expect(status.hidesProviderNames == true)
        #expect(status.menuBarDisplay == .hidden)
        #expect(status.helpText.contains("Provider 1 Daily 42% used (healthy 42%)"))
        #expect(!status.helpText.contains("Codex"))
    }

    @Test("Countdowns mode populates compact countdown text per indicator")
    func countdownsModePopulatesCountdownText() async {
        let viewModel = makeViewModel(
            codex: MockCodexUsageClient(result: .success(codexSnapshot(primaryPercent: 42, resetsInSeconds: 5_400))),
            cursor: MockCursorUsageClient(result: .success(cursorSnapshot(percent: 25, resetsInSeconds: 9_000))),
            desktopQuota: MockDesktopQuotaClient(result: .success([desktopQuotaSnapshot(dailyRemainingPercent: 80, dailyResetsInSeconds: 90_000)])),
            openCodeGo: MockOpenCodeGoUsageClient(result: .success(openCodeGoSnapshot(percent: 5, resetsInSeconds: 1_200)))
        )

        await viewModel.refresh()
        viewModel.updateConfiguration { $0.privacy.menuBarDisplay = .countdowns }
        let status = viewModel.menuBarStatus

        #expect(status.menuBarDisplay == .countdowns)
        #expect(status.indicators.count == 4)
        #expect(status.indicators[0].countdownText == "1h30m")
        #expect(status.indicators[1].countdownText == "2h30m")
        #expect(status.indicators[2].countdownText == "1d1h")
        #expect(status.indicators[3].countdownText == "20m")
    }

    @Test("Countdowns mode falls back when reset is unknown")
    func countdownsModeFallsBackWhenResetUnknown() async {
        let snapshot = OpenCodeGoUsageSnapshot(
            rolling: OpenCodeGoUsageWindow(usedPercent: 5, resetAt: nil),
            weekly: nil,
            monthly: nil,
            billing: nil,
            source: "Test"
        )
        let viewModel = makeViewModel(
            codex: MockCodexUsageClient(result: .success(codexSnapshot(primaryPercent: 42, resetsInSeconds: 5_400))),
            cursor: MockCursorUsageClient(result: .success(cursorSnapshot(percent: 25, resetsInSeconds: 9_000))),
            desktopQuota: MockDesktopQuotaClient(result: .success([desktopQuotaSnapshot(dailyRemainingPercent: 80, dailyResetsInSeconds: 90_000)])),
            openCodeGo: MockOpenCodeGoUsageClient(result: .success(snapshot))
        )

        await viewModel.refresh()
        viewModel.updateConfiguration { $0.privacy.menuBarDisplay = .countdowns }
        let status = viewModel.menuBarStatus

        #expect(status.indicators.first { $0.tab == .openCodeGo }?.countdownText == "?")
    }

    @Test("Disabled providers are omitted from menu bar indicators")
    func disabledProvidersAreOmitted() async {
        var configuration = LimitLensConfiguration.defaults
        configuration.providers.cursor.isEnabled = false
        configuration.providers.openCodeGo.isEnabled = false
        let viewModel = makeViewModel(
            configuration: configuration,
            codex: MockCodexUsageClient(result: .success(codexSnapshot(primaryPercent: 12))),
            cursor: MockCursorUsageClient(result: .success(cursorSnapshot(percent: 25))),
            desktopQuota: MockDesktopQuotaClient(result: .success([desktopQuotaSnapshot(dailyRemainingPercent: 80)])),
            openCodeGo: MockOpenCodeGoUsageClient(result: .success(openCodeGoSnapshot(percent: 5)))
        )

        await viewModel.refresh()

        #expect(viewModel.menuBarStatus.indicators.map(\.tab) == [.codex, .devin])
        #expect(viewModel.providerSummaries.map(\.tab) == [.codex, .devin])
    }

    @Test("All disabled providers produce empty menu bar status")
    func allDisabledProvidersProduceEmptyStatus() async {
        var configuration = LimitLensConfiguration.defaults
        configuration.providers.codex.isEnabled = false
        configuration.providers.cursor.isEnabled = false
        configuration.providers.devin.isEnabled = false
        configuration.providers.openCodeGo.isEnabled = false
        let viewModel = makeViewModel(configuration: configuration)

        await viewModel.refresh()

        #expect(viewModel.menuBarStatus.title == "–")
        #expect(viewModel.menuBarStatus.helpText == "No providers enabled")
        #expect(viewModel.menuBarStatus.indicators.isEmpty)
    }

    @Test("Indicator order is stable")
    func indicatorOrderIsStable() async {
        let viewModel = makeViewModel(
            codex: MockCodexUsageClient(result: .success(codexSnapshot(primaryPercent: 12))),
            cursor: MockCursorUsageClient(result: .success(cursorSnapshot(percent: 25))),
            desktopQuota: MockDesktopQuotaClient(result: .success([desktopQuotaSnapshot(dailyRemainingPercent: 80)])),
            openCodeGo: MockOpenCodeGoUsageClient(result: .success(openCodeGoSnapshot(percent: 5)))
        )

        await viewModel.refresh()

        #expect(viewModel.menuBarStatus.indicators.map(\.tab) == [.codex, .cursor, .devin, .openCodeGo])
    }

    @Test("Visible tabs omit settings")
    func visibleTabsOmitSettings() {
        let viewModel = makeViewModel()

        #expect(viewModel.visibleTabs == [.overview, .codex, .cursor, .devin, .openCodeGo])
    }

    @Test("Refresh calls do not overlap")
    func refreshCallsDoNotOverlap() async {
        let codex = MockCodexUsageClient(result: .success(codexSnapshot(primaryPercent: 12)), delayNanoseconds: 100_000_000)
        let viewModel = makeViewModel(
            codex: codex,
            cursor: MockCursorUsageClient(result: .success(cursorSnapshot(percent: 25))),
            desktopQuota: MockDesktopQuotaClient(result: .success([desktopQuotaSnapshot(dailyRemainingPercent: 80)])),
            openCodeGo: MockOpenCodeGoUsageClient(result: .success(openCodeGoSnapshot(percent: 5)))
        )

        async let first: Void = viewModel.refresh()
        await Task.yield()
        await viewModel.refresh()
        await first

        #expect(codex.callCount == 1)
    }

    private func makeViewModel(
        configuration: LimitLensConfiguration = {
            var config = LimitLensConfiguration.defaults
            config.refresh.retryEnabled = false
            return config
        }(),
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
            openCodeGoService: openCodeGo
        )
    }
}

private final class MockCodexUsageClient: CodexUsageFetching, @unchecked Sendable {
    var result: Result<LimitLensSnapshot, Error>
    var callCount = 0
    let delayNanoseconds: UInt64

    init(result: Result<LimitLensSnapshot, Error>, delayNanoseconds: UInt64 = 0) {
        self.result = result
        self.delayNanoseconds = delayNanoseconds
    }

    func fetchSnapshot() async throws -> LimitLensSnapshot {
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

private enum TestError: Error {
    case unavailable
}

private func codexSnapshot(
    primaryPercent: Int,
    resetsInSeconds: TimeInterval = 3_600,
    primaryDurationMinutes: Int = 1_440,
    secondaryPercent: Int? = nil,
    secondaryDurationMinutes: Int = 10_080
) -> LimitLensSnapshot {
    let secondaryJSON = secondaryPercent.map {
        """
        {
          "resetsAt": \(Int(Date().addingTimeInterval(86_400).timeIntervalSince1970)),
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
            "resetsAt": \(Int(Date().addingTimeInterval(resetsInSeconds).timeIntervalSince1970)),
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
