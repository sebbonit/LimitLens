import Foundation
import Testing
@testable import LimitLensCore

@Suite("Quota usage history")
struct QuotaUsageHistoryTests {
    @Test("Keeps valid samples from the last 90 days")
    func normalizesHistory() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let reset = now.addingTimeInterval(86_400)
        let valid = QuotaUsageHistorySample(
            provider: .codex,
            observedAt: now,
            percentUsed: 42,
            resetsAt: reset
        )
        let expired = QuotaUsageHistorySample(
            provider: .codex,
            observedAt: now.addingTimeInterval(-(91 * 86_400)),
            percentUsed: 20,
            resetsAt: reset
        )
        let invalid = QuotaUsageHistorySample(
            provider: .cursor,
            observedAt: now,
            percentUsed: 101,
            resetsAt: reset
        )

        let result = QuotaUsageHistoryCalculator.normalized(
            [valid, valid, expired, invalid],
            now: now
        )

        #expect(result == [valid])
    }

    @Test("Returns only samples from the requested provider and cycle")
    func filtersCurrentCycle() {
        let reset = Date(timeIntervalSince1970: 2_000_100_000)
        let earlier = QuotaUsageHistorySample(
            provider: .cursor,
            observedAt: reset.addingTimeInterval(-200),
            percentUsed: 12,
            resetsAt: reset
        )
        let later = QuotaUsageHistorySample(
            provider: .cursor,
            observedAt: reset.addingTimeInterval(-100),
            percentUsed: 18,
            resetsAt: reset
        )
        let otherProvider = QuotaUsageHistorySample(
            provider: .codex,
            observedAt: reset.addingTimeInterval(-50),
            percentUsed: 30,
            resetsAt: reset
        )

        let result = QuotaUsageHistoryCalculator.currentCycleSamples(
            provider: .cursor,
            resetsAt: reset,
            in: [later, otherProvider, earlier]
        )

        #expect(result == [earlier, later])
    }

    @Test("Averages burn rates from prior cycles")
    func averagesHistoricalRates() {
        let currentReset = Date(timeIntervalSince1970: 2_000_000_000)
        let priorResetA = currentReset.addingTimeInterval(-7 * 86_400)
        let priorResetB = currentReset.addingTimeInterval(-14 * 86_400)
        let samples = [
            sample(used: 10, daysBeforeReset: 2, reset: priorResetA),
            sample(used: 30, daysBeforeReset: 1, reset: priorResetA),
            sample(used: 20, daysBeforeReset: 3, reset: priorResetB),
            sample(used: 60, daysBeforeReset: 1, reset: priorResetB),
            sample(used: 5, daysBeforeReset: 1, reset: currentReset)
        ]

        let rate = QuotaUsageHistoryCalculator.historicalPercentUsedPerDay(
            provider: .codex,
            excludingResetAt: currentReset,
            in: samples
        )

        // Both prior cycles burn 20 percentage points per day.
        #expect(rate == 20)
    }

    private func sample(
        used: Double,
        daysBeforeReset: Int,
        reset: Date
    ) -> QuotaUsageHistorySample {
        QuotaUsageHistorySample(
            provider: .codex,
            observedAt: reset.addingTimeInterval(-Double(daysBeforeReset) * 86_400),
            percentUsed: used,
            resetsAt: reset
        )
    }
}
