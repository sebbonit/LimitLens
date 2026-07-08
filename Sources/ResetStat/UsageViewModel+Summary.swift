import Foundation
import ResetStatCore
import SwiftUI

private struct LimitCandidate {
    let title: String
    let percent: Int
    let resetAt: Date?
    let durationMinutes: Int64
}

extension UsageViewModel {
    var providerSummaries: [ProviderUsageSummary] {
        enabledProviderTabs.compactMap(summary(for:))
    }

    var enabledProviderTabs: [ProviderTab] {
        ProviderTab.providerCases.filter(isProviderEnabled)
    }

    var visibleTabs: [ProviderTab] {
        [.overview] + enabledProviderTabs
    }

    var hidesProviderNames: Bool {
        configuration.privacy.hidesProviderNames
    }

    var menuBarDisplay: MenuBarDisplay {
        configuration.privacy.menuBarDisplay
    }

    var openCodeGoDashboardURL: URL? {
        guard configuration.providers.openCodeGo.isEnabled else { return nil }
        let configPath = configuration.providers.openCodeGo.configPath
        guard let credentials = OpenCodeGoDashboardConfigFile.loadIfPresent(from: URL(fileURLWithPath: configPath)) else {
            return nil
        }
        return OpenCodeGoDashboardCredentials.dashboardURL(workspaceId: credentials.workspaceId)
    }

    var prioritySummary: ProviderUsageSummary? {
        providerSummaries
            .sorted {
                if $0.severity != $1.severity {
                    return $0.severity > $1.severity
                }
                return ($0.percentUsed ?? -1) > ($1.percentUsed ?? -1)
            }
            .first
    }

    var billingExpiries: [BillingExpiry] {
        enabledProviderTabs.compactMap { tab in
            switch tab {
            case .codex:
                return codexBillingExpiry
            case .cursor:
                return cursorBillingExpiry
            case .devin:
                return devinBillingExpiry
            case .openCodeGo:
                return openCodeGoBillingExpiry
            case .overview, .settings:
                return nil
            }
        }
    }

    private var codexBillingExpiry: BillingExpiry {
        let date = snapshot?.planExpiresAt
        return BillingExpiry(
            tab: .codex,
            label: "Renews",
            date: date,
            amountText: nil,
            detailText: nil,
            urgency: UsageFormatting.expiryUrgency(expiresAt: date, now: now)
        )
    }

    private var cursorBillingExpiry: BillingExpiry {
        let date = cursorSnapshot?.billingCycleEnd
        return BillingExpiry(
            tab: .cursor,
            label: "Cycle ends",
            date: date,
            amountText: nil,
            detailText: nil,
            urgency: UsageFormatting.expiryUrgency(expiresAt: date, now: now)
        )
    }

    private var devinBillingExpiry: BillingExpiry {
        let date = desktopQuotaSnapshots.first?.cycleEnd
        return BillingExpiry(
            tab: .devin,
            label: "Cycle ends",
            date: date,
            amountText: nil,
            detailText: nil,
            urgency: UsageFormatting.expiryUrgency(expiresAt: date, now: now)
        )
    }

    private var openCodeGoBillingExpiry: BillingExpiry {
        let billing = openCodeGoSnapshot?.billing
        let lastPayment = billing?.lastPayment
        let balance = billing?.balanceText

        let label: String
        if lastPayment != nil {
            label = "Last payment"
        } else if billing == nil {
            label = "No billing"
        } else {
            label = "No payments"
        }

        return BillingExpiry(
            tab: .openCodeGo,
            label: label,
            date: lastPayment?.date,
            amountText: balance,
            detailText: lastPayment.flatMap { $0.dateText.isEmpty ? nil : $0.dateText },
            urgency: .unknown
        )
    }

    private func summary(for tab: ProviderTab) -> ProviderUsageSummary? {
        switch tab {
        case .codex:
            return codexSummary
        case .cursor:
            return cursorSummary
        case .devin:
            return desktopQuotaSummary
        case .openCodeGo:
            return openCodeGoSummary
        case .overview, .settings:
            return nil
        }
    }

    private var codexSummary: ProviderUsageSummary {
        guard let snapshot else {
            return ProviderUsageSummary(
                tab: .codex,
                detail: loadStateDetail(state, unavailable: "Codex unavailable"),
                subdetail: "Usage not loaded",
                secondaryDetail: nil,
                percentUsed: nil,
                resetAt: nil,
                severity: severity(for: state)
            )
        }

        let candidates = [
            snapshot.rateLimit.primary.map { limitCandidate(title: limitTitle(for: $0, fallback: "Primary"), percent: $0.usedPercent, resetTimestamp: $0.resetsAt, durationMinutes: $0.windowDurationMins) },
            snapshot.rateLimit.secondary.map { limitCandidate(title: limitTitle(for: $0, fallback: "Secondary"), percent: $0.usedPercent, resetTimestamp: $0.resetsAt, durationMinutes: $0.windowDurationMins) }
        ].compactMap(\.self)
        let selected = closestActiveLimit(candidates)
        let resetAt = selected?.resetAt
        let percent = selected.map { Double($0.percent) }

        return ProviderUsageSummary(
            tab: .codex,
            detail: selected.map { "\($0.title) \($0.percent)% used" } ?? "Usage unavailable",
            subdetail: resetAt.map { "Resets \(UsageFormatting.timeRemainingText(date: $0, now: now))" } ?? "Reset unknown",
            secondaryDetail: nextLimit(after: selected, in: candidates).map(limitDetail),
            percentUsed: percent,
            resetAt: resetAt,
            severity: UsageSeverity.from(percentUsed: percent)
        )
    }

    private var cursorSummary: ProviderUsageSummary {
        guard let cursorSnapshot else {
            return ProviderUsageSummary(
                tab: .cursor,
                detail: loadStateDetail(cursorState, unavailable: "Cursor unavailable"),
                subdetail: "Usage not loaded",
                secondaryDetail: nil,
                percentUsed: nil,
                resetAt: nil,
                severity: severity(for: cursorState)
            )
        }

        let percent = cursorSnapshot.usedPercent
        return ProviderUsageSummary(
            tab: .cursor,
            detail: "\(Int(percent.rounded()))% used",
            subdetail: cursorSnapshot.billingCycleEnd.map { "Resets \(UsageFormatting.timeRemainingText(date: $0, now: now))" } ?? "Reset unknown",
            secondaryDetail: nil,
            percentUsed: percent,
            resetAt: cursorSnapshot.billingCycleEnd,
            severity: UsageSeverity.from(percentUsed: percent)
        )
    }

    private var desktopQuotaSummary: ProviderUsageSummary {
        guard let quota = desktopQuotaSnapshots.first else {
            return ProviderUsageSummary(
                tab: .devin,
                detail: loadStateDetail(desktopQuotaState, unavailable: "Devin unavailable"),
                subdetail: "Quota not loaded",
                secondaryDetail: nil,
                percentUsed: nil,
                resetAt: nil,
                severity: severity(for: desktopQuotaState)
            )
        }

        let candidates = [
            (quota.dailyUsedPercent, quota.dailyResetAt, 86_400.0, "Daily", 1_440),
            (quota.weeklyUsedPercent, quota.weeklyResetAt, 7 * 86_400.0, "Weekly", 10_080)
        ].compactMap { percent, resetAt, interval, title, durationMinutes -> LimitCandidate? in
            guard !quota.shouldTreatQuotaUsageAsUnavailable, let percent else { return nil }
            return LimitCandidate(
                title: title,
                percent: percent,
                resetAt: resetAt.map { advancedResetDate($0, interval: interval) },
                durationMinutes: Int64(durationMinutes)
            )
        }
        let selected = closestActiveLimit(candidates)
        let percent = selected.map { Double($0.percent) }
        let resetAt = selected?.resetAt

        return ProviderUsageSummary(
            tab: .devin,
            detail: selected.map { "\($0.title) \($0.percent)% used" } ?? "Usage not reported",
            subdetail: resetAt.map { "Resets \(UsageFormatting.timeRemainingText(date: $0, now: now))" } ?? "Reset unknown",
            secondaryDetail: nextLimit(after: selected, in: candidates).map(limitDetail),
            percentUsed: percent,
            resetAt: resetAt,
            severity: UsageSeverity.from(percentUsed: percent)
        )
    }

    private var openCodeGoSummary: ProviderUsageSummary {
        guard let openCodeGoSnapshot, openCodeGoSnapshot.hasUsage else {
            return ProviderUsageSummary(
                tab: .openCodeGo,
                detail: loadStateDetail(openCodeGoState, unavailable: "OpenCode Go unavailable"),
                subdetail: "Usage not loaded",
                secondaryDetail: nil,
                percentUsed: nil,
                resetAt: nil,
                severity: severity(for: openCodeGoState)
            )
        }

        let candidates = [
            (openCodeGoSnapshot.rolling, "Rolling", 300),
            (openCodeGoSnapshot.weekly, "Weekly", 10_080),
            (openCodeGoSnapshot.monthly, "Monthly", 43_200)
        ].compactMap { window, title, durationMinutes -> LimitCandidate? in
            guard let window else { return nil }
            return LimitCandidate(
                title: title,
                percent: Int(window.usedPercent.rounded()),
                resetAt: window.resetAt,
                durationMinutes: Int64(durationMinutes)
            )
        }
        let selected = closestActiveLimit(candidates)
        let percent = selected.map { Double($0.percent) }

        return ProviderUsageSummary(
            tab: .openCodeGo,
            detail: selected.map { "\($0.title) \($0.percent)% used" } ?? "Usage not reported",
            subdetail: selected?.resetAt.map { "Resets \(UsageFormatting.timeRemainingText(date: $0, now: now))" } ?? "Reset unknown",
            secondaryDetail: nextLimit(after: selected, in: candidates).map(limitDetail),
            percentUsed: percent,
            resetAt: selected?.resetAt,
            severity: UsageSeverity.from(percentUsed: percent)
        )
    }

    private func loadStateDetail(_ state: LoadState, unavailable: String) -> String {
        switch state {
        case .idle, .loading:
            return "Loading"
        case .loaded, .failed:
            return unavailable
        case .disabled:
            return "Disabled"
        }
    }

    private func severity(for state: LoadState) -> UsageSeverity {
        if case .failed = state {
            return .unavailable
        }
        if case .disabled = state {
            return .unavailable
        }
        return .healthy
    }

    private func limitCandidate(title: String, percent: Int, resetTimestamp: Int64?, durationMinutes: Int64?) -> LimitCandidate {
        LimitCandidate(
            title: title,
            percent: max(0, min(100, percent)),
            resetAt: resetTimestamp.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            durationMinutes: durationMinutes ?? Int64.max
        )
    }

    private func closestActiveLimit(_ candidates: [LimitCandidate]) -> LimitCandidate? {
        let sorted = candidates.sorted {
            if $0.durationMinutes != $1.durationMinutes {
                return $0.durationMinutes < $1.durationMinutes
            }
            return $0.percent > $1.percent
        }

        return sorted.first { $0.percent < 100 } ?? sorted.last
    }

    private func nextLimit(after selected: LimitCandidate?, in candidates: [LimitCandidate]) -> LimitCandidate? {
        guard let selected else { return nil }
        return candidates
            .filter { $0.durationMinutes > selected.durationMinutes }
            .sorted {
                if $0.durationMinutes != $1.durationMinutes {
                    return $0.durationMinutes < $1.durationMinutes
                }
                return $0.percent > $1.percent
            }
            .first
    }

    private func limitDetail(_ limit: LimitCandidate) -> String {
        "\(limit.title) \(limit.percent)% used"
    }

    private func limitTitle(for window: RateLimitWindow, fallback: String) -> String {
        guard let minutes = window.windowDurationMins else { return fallback }
        if minutes < 60 {
            return "\(minutes)m"
        }
        if minutes == 1_440 {
            return "Daily"
        }
        if minutes == 10_080 {
            return "Weekly"
        }
        if minutes % 1_440 == 0 {
            return "\(minutes / 1_440)d"
        }
        if minutes % 60 == 0 {
            return "\(minutes / 60)h"
        }
        return fallback
    }

    private func advancedResetDate(_ date: Date, interval: TimeInterval) -> Date {
        var resetDate = date
        while resetDate < now {
            resetDate = resetDate.addingTimeInterval(interval)
        }
        return resetDate
    }

}
