import Foundation
import LimitLensCore
import SwiftUI

extension UsageViewModel {
    var menuBarStatus: MenuBarStatusSnapshot {
        let summaries = providerSummaries
        let indicators = summaries.map { menuBarIndicator(for: $0) }

        let hasUnavailableOrStale = indicators.contains { indicator in
            switch indicator.state {
            case .stale, .unavailable:
                return true
            case .loading, .healthy, .warning, .critical:
                return false
            }
        }

        let title = indicators.isEmpty ? "–" : indicators.map(\.barGlyph).joined(separator: " ")
        let severity = hasUnavailableOrStale
            ? .unavailable
            : (summaries.map(\.severity).max() ?? .healthy)

        let helpText = indicators.isEmpty
            ? "No providers enabled"
            : indicators.map { indicatorHelpText($0) }.joined(separator: ", ")
        return MenuBarStatusSnapshot(
            title: title,
            severity: severity,
            indicators: indicators,
            helpText: helpText,
            accessibilityLabel: helpText,
            isRefreshing: isRefreshing,
            hidesProviderNames: hidesProviderNames,
            menuBarDisplay: menuBarDisplay
        )
    }

    private func menuBarIndicator(for summary: ProviderUsageSummary) -> MenuBarProviderIndicator {
        let state = menuBarIndicatorState(
            loadState: loadState(for: summary.tab),
            hasSnapshot: hasUsableSnapshot(for: summary.tab),
            severity: summary.severity
        )
        return MenuBarProviderIndicator(
            tab: summary.tab,
            state: state,
            percentUsed: summary.percentUsed,
            secondaryPercentUsed: summary.secondaryPercentUsed,
            message: menuBarMessage(for: summary, state: state),
            barGlyph: barGlyph(for: state, percentUsed: summary.percentUsed),
            countdownText: menuBarCountdownText(for: summary, state: state)
        )
    }

    private func menuBarCountdownText(
        for summary: ProviderUsageSummary,
        state: MenuBarIndicatorState
    ) -> String {
        switch state {
        case .loading:
            return "·"
        case .unavailable:
            return "?"
        case .healthy, .warning, .critical, .stale:
            return UsageFormatting.compactCountdownText(date: summary.resetAt, now: now)
        }
    }

    private func menuBarIndicatorState(
        loadState: LoadState,
        hasSnapshot: Bool,
        severity: UsageSeverity
    ) -> MenuBarIndicatorState {
        switch loadState {
        case .idle, .loading:
            return hasSnapshot ? menuBarIndicatorState(for: severity) : .loading
        case .failed:
            return hasSnapshot ? .stale(severity) : .unavailable
        case .loaded:
            return menuBarIndicatorState(for: severity)
        case .disabled:
            return .unavailable
        }
    }

    private func menuBarIndicatorState(for severity: UsageSeverity) -> MenuBarIndicatorState {
        switch severity {
        case .critical:
            return .critical
        case .warning:
            return .warning
        case .healthy:
            return .healthy
        case .unavailable:
            return .unavailable
        }
    }

    private func menuBarMessage(for summary: ProviderUsageSummary, state: MenuBarIndicatorState) -> String {
        let name = hidesProviderNames ? summary.tab.privateName : summary.tab.displayName
        let stateDetail = menuBarStateDetail(state, percentUsed: summary.percentUsed)
        switch state {
        case .loading, .unavailable:
            return "\(name) \(stateDetail)"
        case .healthy, .warning, .critical, .stale:
            return "\(name) \(providerSafeDetail(summary.detail)) (\(stateDetail)), \(providerSafeDetail(summary.subdetail))"
        }
    }

    private func indicatorHelpText(_ indicator: MenuBarProviderIndicator) -> String {
        guard isRefreshing, indicatorShowsCachedData(indicator.state) else {
            return indicator.message
        }

        let name = hidesProviderNames ? indicator.tab.privateName : indicator.tab.displayName
        let detail = menuBarStateDetail(indicator.state, percentUsed: indicator.percentUsed, isRefreshing: true)
        return "\(name) \(detail)"
    }

    private func menuBarStateDetail(
        _ state: MenuBarIndicatorState,
        percentUsed: Double?,
        isRefreshing: Bool = false
    ) -> String {
        let prefix = isRefreshing ? "refreshing " : ""
        switch state {
        case .loading:
            return "loading"
        case .healthy:
            return "\(prefix)healthy\(percentSuffix(percentUsed))"
        case .warning:
            return "\(prefix)warning\(percentSuffix(percentUsed))"
        case .critical:
            return "\(prefix)critical\(percentSuffix(percentUsed))"
        case .stale(let severity):
            return "stale \(severityText(severity))\(percentSuffix(percentUsed))"
        case .unavailable:
            return "unavailable"
        }
    }

    private func indicatorShowsCachedData(_ state: MenuBarIndicatorState) -> Bool {
        switch state {
        case .healthy, .warning, .critical:
            return true
        case .loading, .stale, .unavailable:
            return false
        }
    }

    private func percentSuffix(_ percentUsed: Double?) -> String {
        guard let percentUsed else { return "" }
        return " \(Int(percentUsed.rounded()))%"
    }

    private func providerSafeDetail(_ detail: String) -> String {
        guard hidesProviderNames else { return detail }
        return detail
            .replacingOccurrences(of: "Codex", with: "Provider")
            .replacingOccurrences(of: "Cursor", with: "Provider")
            .replacingOccurrences(of: "Devin", with: "Provider")
            .replacingOccurrences(of: "OpenCode Go", with: "Provider")
            .replacingOccurrences(of: "OpenCode", with: "Provider")
    }

    private func barGlyph(for state: MenuBarIndicatorState, percentUsed: Double?) -> String {
        switch state {
        case .loading:
            return "·"
        case .unavailable:
            return "?"
        case .healthy, .warning, .critical, .stale:
            return usageBarGlyph(percentUsed: percentUsed)
        }
    }

    private func usageBarGlyph(percentUsed: Double?) -> String {
        guard let percentUsed else { return "?" }
        let clamped = max(0, min(100, percentUsed))
        switch clamped {
        case 0..<12.5:
            return "▁"
        case 12.5..<25:
            return "▂"
        case 25..<37.5:
            return "▃"
        case 37.5..<50:
            return "▄"
        case 50..<62.5:
            return "▅"
        case 62.5..<75:
            return "▆"
        case 75..<87.5:
            return "▇"
        default:
            return "█"
        }
    }

    private func severityText(_ severity: UsageSeverity) -> String {
        switch severity {
        case .critical:
            return "critical"
        case .warning:
            return "warning"
        case .healthy:
            return "healthy"
        case .unavailable:
            return "unavailable"
        }
    }

    private func loadState(for tab: ProviderTab) -> LoadState {
        switch tab {
        case .codex:
            return state
        case .cursor:
            return cursorState
        case .devin:
            return desktopQuotaState
        case .openCodeGo:
            return openCodeGoState
        case .overview, .settings:
            return .loaded
        }
    }

    private func hasUsableSnapshot(for tab: ProviderTab) -> Bool {
        switch tab {
        case .codex:
            return snapshot != nil
        case .cursor:
            return cursorSnapshot != nil
        case .devin:
            return !desktopQuotaSnapshots.isEmpty
        case .openCodeGo:
            return openCodeGoSnapshot?.hasUsage == true
        case .overview, .settings:
            return true
        }
    }

}
