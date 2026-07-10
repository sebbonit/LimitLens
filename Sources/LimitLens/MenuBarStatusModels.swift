import Foundation
import LimitLensCore
import SwiftUI

struct ProviderUsageSummary: Identifiable {
    let tab: ProviderTab
    let detail: String
    let subdetail: String
    let secondaryDetail: String?
    let secondaryPercentUsed: Double?
    let percentUsed: Double?
    let resetAt: Date?
    let severity: UsageSeverity

    /// Stable identifier for the overview-priority quota kind (e.g. "Daily",
    /// "Weekly", "Rolling", "Billing cycle"). Nil when no quota is loaded.
    let quotaKind: String?
    /// Human-readable label for the tracked quota, shown in the exhaustion
    /// speed section.
    let quotaLabel: String?
    /// Window duration of the selected quota in seconds.
    let windowDurationSeconds: TimeInterval?
    /// Start of the current quota cycle.
    let cycleStart: Date?
    /// True when the cycle start was inferred (Cursor calendar-month fallback).
    let cycleStartEstimated: Bool

    var id: ProviderTab { tab }

    init(
        tab: ProviderTab,
        detail: String,
        subdetail: String,
        secondaryDetail: String?,
        secondaryPercentUsed: Double?,
        percentUsed: Double?,
        resetAt: Date?,
        severity: UsageSeverity,
        quotaKind: String? = nil,
        quotaLabel: String? = nil,
        windowDurationSeconds: TimeInterval? = nil,
        cycleStart: Date? = nil,
        cycleStartEstimated: Bool = false
    ) {
        self.tab = tab
        self.detail = detail
        self.subdetail = subdetail
        self.secondaryDetail = secondaryDetail
        self.secondaryPercentUsed = secondaryPercentUsed
        self.percentUsed = percentUsed
        self.resetAt = resetAt
        self.severity = severity
        self.quotaKind = quotaKind
        self.quotaLabel = quotaLabel
        self.windowDurationSeconds = windowDurationSeconds
        self.cycleStart = cycleStart
        self.cycleStartEstimated = cycleStartEstimated
    }
}

struct BillingExpiry: Identifiable {
    let tab: ProviderTab
    let label: String
    let date: Date?
    let amountText: String?
    let detailText: String?
    let urgency: UsageFormatting.ExpiryUrgency

    var id: ProviderTab { tab }
}

/// Presentation model for the "Exhaustion speed" overview section.
struct ExhaustionSpeedSummary: Identifiable {
    let tab: ProviderTab
    let quotaLabel: String
    let averageText: String
    let cycleCount: Int

    var id: ProviderTab { tab }
}

enum MenuBarIndicatorState: Equatable {
    case loading
    case healthy
    case warning
    case critical
    case stale(UsageSeverity)
    case unavailable
}

struct MenuBarProviderIndicator: Identifiable, Equatable {
    let tab: ProviderTab
    let state: MenuBarIndicatorState
    let percentUsed: Double?
    let secondaryPercentUsed: Double?
    let message: String
    let barGlyph: String
    let countdownText: String

    var id: ProviderTab { tab }
}

struct MenuBarStatusSnapshot: Equatable {
    let title: String
    let severity: UsageSeverity
    let indicators: [MenuBarProviderIndicator]
    let helpText: String
    let accessibilityLabel: String
    let isRefreshing: Bool
    let hidesProviderNames: Bool
    let secondaryLimitTintingEnabled: Bool
    let menuBarDisplay: MenuBarDisplay
}

struct DiagnosticTestResult: Equatable, Identifiable {
    let timestamp: Date
    let succeeded: Bool
    let message: String
    let elapsedMillis: Int

    var id: String { "\(timestamp.timeIntervalSince1970)" }
}

