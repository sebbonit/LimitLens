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

    var id: ProviderTab { tab }
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
    let menuBarDisplay: MenuBarDisplay
}

struct DiagnosticTestResult: Equatable, Identifiable {
    let timestamp: Date
    let succeeded: Bool
    let message: String
    let elapsedMillis: Int

    var id: String { "\(timestamp.timeIntervalSince1970)" }
}

