import Foundation
import LimitLensCore

extension UsageViewModel {
    /// Maps a provider tab to its exhaustion-tracking provider identifier.
    func exhaustionProvider(for tab: ProviderTab) -> QuotaExhaustionProvider? {
        switch tab {
        case .codex: return .codex
        case .cursor: return .cursor
        case .devin: return .devin
        case .openCodeGo: return .openCodeGo
        case .overview, .settings: return nil
        }
    }

    /// Checks the overview-priority quota for the given provider after a
    /// successful refresh and records a new exhaustion event if the quota has
    /// reached 100%. Always refreshes the published exhaustion summaries.
    func recordExhaustionIfNeeded(for tab: ProviderTab) {
        guard let provider = exhaustionProvider(for: tab) else {
            updateExhaustionSummaries()
            return
        }
        guard let summary = providerSummaries.first(where: { $0.tab == tab }),
              let quotaKind = summary.quotaKind else {
            updateExhaustionSummaries()
            return
        }

        if ExhaustionSpeedCalculator.isExhausted(percentUsed: summary.percentUsed),
           let cycleStart = summary.cycleStart,
           let cycleEnd = summary.resetAt {
            let event = ExhaustionSpeedCalculator.makeEvent(
                provider: provider,
                quotaKind: quotaKind,
                percentUsed: summary.percentUsed,
                cycleStart: cycleStart,
                cycleEnd: cycleEnd,
                exhaustedAt: Date(),
                startEstimated: summary.cycleStartEstimated
            )
            if let event {
                let originalEvents = historyStore.payload.events
                let updatedEvents = ExhaustionSpeedCalculator.record(
                    newEvent: event,
                    into: originalEvents
                )
                if updatedEvents.count != originalEvents.count {
                    historyStore.payload = QuotaExhaustionHistoryPayload(
                        version: QuotaExhaustionHistoryPayload.currentVersion,
                        events: updatedEvents
                    )
                    historyStore.save()
                }
            }
        }
        updateExhaustionSummaries()
    }

    /// Clears all exhaustion history and updates published summaries.
    func clearExhaustionHistory() {
        historyStore.clear()
        updateExhaustionSummaries()
    }

    /// Recomputes the published exhaustion summaries from the history store and
    /// current provider state. Providers that are temporarily unavailable
    /// retain their persisted averages by falling back to the most recent
    /// event's quota kind.
    func updateExhaustionSummaries() {
        let allEvents = historyStore.payload.events
        let summaries = enabledProviderTabs.compactMap { tab -> ExhaustionSpeedSummary? in
            guard let provider = exhaustionProvider(for: tab) else { return nil }

            let currentSummary = providerSummaries.first(where: { $0.tab == tab })
            let quotaKind = currentSummary?.quotaKind
                ?? mostRecentQuotaKind(for: provider, in: allEvents)

            guard let quotaKind else { return nil }

            let events = ExhaustionSpeedCalculator.events(
                for: provider,
                quotaKind: quotaKind,
                in: allEvents
            )
            guard !events.isEmpty else { return nil }
            guard let avg = ExhaustionSpeedCalculator.averageDuration(of: events) else { return nil }

            let anyEstimated = ExhaustionSpeedCalculator.anyStartEstimated(in: events)
            let avgText = UsageFormatting.averageDurationText(
                seconds: avg,
                anyEstimated: anyEstimated
            )
            let label = currentSummary?.quotaLabel ?? quotaKind

            return ExhaustionSpeedSummary(
                tab: tab,
                quotaLabel: label,
                averageText: "Avg \(avgText)",
                cycleCount: events.count
            )
        }
        exhaustionSummaries = summaries
    }

    /// Returns the quota kind from the most recent event for the given provider,
    /// used as a fallback when the provider is temporarily unavailable.
    private func mostRecentQuotaKind(
        for provider: QuotaExhaustionProvider,
        in events: [QuotaExhaustionEvent]
    ) -> String? {
        events
            .filter { $0.provider == provider }
            .sorted(by: { $0.exhaustedAt < $1.exhaustedAt })
            .last?
            .quotaKind
    }
}
