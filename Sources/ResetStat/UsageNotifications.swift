import Foundation
import ResetStatCore
import UserNotifications

struct NotificationRequest: Equatable {
    let identifier: String
    let title: String
    let body: String
}

protocol Notifier: Sendable {
    func deliver(_ request: NotificationRequest) async
}

@MainActor
final class NotificationCoordinator {
    private let notifier: Notifier
    private var previousOverCritical: Set<ProviderTab> = []
    private var previousUrgency: [ProviderTab: UsageFormatting.ExpiryUrgency] = [:]
    private var wasUnavailable: Set<ProviderTab> = []
    private var lastDigestDay: String?

    private static let digestDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    init(notifier: Notifier = SystemNotifier()) {
        self.notifier = notifier
    }

    func sendTestNotification() async {
        await notifier.deliver(NotificationRequest(
            identifier: "test-\(UUID().uuidString)",
            title: "ResetStat test notification",
            body: "If you can see this, notifications are working correctly."
        ))
    }

    func evaluate(
        summaries: [ProviderUsageSummary],
        billingExpiries: [BillingExpiry],
        loadStates: [ProviderTab: UsageViewModel.LoadState],
        configuration: NotificationConfiguration,
        hidesProviderNames: Bool,
        now: Date
    ) async {
        guard configuration.enabled else { return }
        guard !isQuietHours(configuration: configuration, now: now) else { return }

        for summary in summaries {
            let tab = summary.tab
            let isProviderEnabled = isPerProviderEnabled(tab, configuration: configuration)
            guard isProviderEnabled else { continue }

            if configuration.criticalUsage {
                await checkCriticalUsage(summary: summary, tab: tab, hidesProviderNames: hidesProviderNames, configuration: configuration)
            }

            if configuration.providerUnavailable {
                await checkUnavailable(summary: summary, loadState: loadStates[tab] ?? .idle, tab: tab, hidesProviderNames: hidesProviderNames, configuration: configuration)
            }
        }

        if configuration.billingExpiring {
            for entry in billingExpiries {
                let isProviderEnabled = isPerProviderEnabled(entry.tab, configuration: configuration)
                guard isProviderEnabled else { continue }
                await checkBillingExpiry(entry: entry, hidesProviderNames: hidesProviderNames, configuration: configuration)
            }
        }

        if configuration.dailyDigest {
            await checkDailyDigest(
                summaries: summaries,
                billingExpiries: billingExpiries,
                hidesProviderNames: hidesProviderNames,
                configuration: configuration,
                now: now
            )
        }
    }

    private func checkCriticalUsage(
        summary: ProviderUsageSummary,
        tab: ProviderTab,
        hidesProviderNames: Bool,
        configuration: NotificationConfiguration
    ) async {
        let threshold = configuration.criticalThreshold(for: tab)
        let isOverThreshold = summary.percentUsed.map { $0 >= Double(threshold) } ?? false
        let wasOverThreshold = previousOverCritical.contains(tab)

        if isOverThreshold && !wasOverThreshold {
            let name = hidesProviderNames ? tab.privateName : tab.displayName
            let percent = summary.percentUsed.map { Int($0.rounded()) } ?? 0
            let resetText = summary.resetAt.map { UsageFormatting.timeRemainingText(date: $0, now: Date()) } ?? "unknown reset"
            await notifier.deliver(NotificationRequest(
                identifier: "critical-\(tab.rawValue)",
                title: "\(name) usage critical",
                body: "\(percent)% used — resets in \(resetText)"
            ))
        }

        if isOverThreshold {
            previousOverCritical.insert(tab)
        } else {
            previousOverCritical.remove(tab)
        }
    }

    private func checkBillingExpiry(
        entry: BillingExpiry,
        hidesProviderNames: Bool,
        configuration: NotificationConfiguration
    ) async {
        guard let date = entry.date else { return }
        let urgency = entry.urgency
        let previous = previousUrgency[entry.tab] ?? .healthy

        if (urgency == .soon || urgency == .expired) && previous != .soon && previous != .expired {
            let name = hidesProviderNames ? entry.tab.privateName : entry.tab.displayName
            let relativeText = UsageFormatting.relativeDayText(date: date, now: Date())
            let urgencyWord = urgency == .expired ? "expired" : "expiring soon"
            await notifier.deliver(NotificationRequest(
                identifier: "billing-\(entry.tab.rawValue)",
                title: "\(name) renewal \(urgencyWord)",
                body: "\(entry.label) \(relativeText)"
            ))
        }
        previousUrgency[entry.tab] = urgency
    }

    private func checkUnavailable(
        summary: ProviderUsageSummary,
        loadState: UsageViewModel.LoadState,
        tab: ProviderTab,
        hidesProviderNames: Bool,
        configuration: NotificationConfiguration
    ) async {
        let isUnavailable = (isFailedState(loadState) && summary.percentUsed == nil)
        let wasPreviouslyUnavailable = wasUnavailable.contains(tab)

        if isUnavailable && !wasPreviouslyUnavailable {
            let name = hidesProviderNames ? tab.privateName : tab.displayName
            await notifier.deliver(NotificationRequest(
                identifier: "unavailable-\(tab.rawValue)",
                title: "\(name) unavailable",
                body: "Usage data could not be fetched."
            ))
            wasUnavailable.insert(tab)
        } else if !isUnavailable && wasPreviouslyUnavailable {
            wasUnavailable.remove(tab)
        }
    }

    private func checkDailyDigest(
        summaries: [ProviderUsageSummary],
        billingExpiries: [BillingExpiry],
        hidesProviderNames: Bool,
        configuration: NotificationConfiguration,
        now: Date
    ) async {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        guard hour >= configuration.dailyDigestHour else { return }

        let today = Self.digestDayFormatter.string(from: now)
        if lastDigestDay == today { return }
        lastDigestDay = today

        let body = digestBody(
            summaries: summaries,
            billingExpiries: billingExpiries,
            hidesProviderNames: hidesProviderNames,
            now: now
        )

        await notifier.deliver(NotificationRequest(
            identifier: "digest-\(today)",
            title: "Daily usage summary",
            body: body
        ))
    }

    private func digestBody(
        summaries: [ProviderUsageSummary],
        billingExpiries: [BillingExpiry],
        hidesProviderNames: Bool,
        now: Date
    ) -> String {
        let criticalCount = summaries.filter { $0.severity == .critical }.count
        let warningCount = summaries.filter { $0.severity == .warning }.count
        let unavailableCount = summaries.filter { $0.severity == .unavailable }.count
        let healthyCount = summaries.filter { $0.severity == .healthy }.count

        var parts: [String] = []
        if criticalCount > 0 { parts.append("\(criticalCount) critical") }
        if warningCount > 0 { parts.append("\(warningCount) warning") }
        if unavailableCount > 0 { parts.append("\(unavailableCount) unavailable") }

        let expiringSoon = billingExpiries.filter { $0.urgency == .soon || $0.urgency == .expired }
        if !expiringSoon.isEmpty {
            let names = expiringSoon.map { entry -> String in
                hidesProviderNames ? entry.tab.privateName : entry.tab.displayName
            }.joined(separator: ", ")
            parts.append("\(names) renewing soon")
        }

        if parts.isEmpty {
            return "\(healthyCount) provider\(healthyCount == 1 ? "" : "s") healthy."
        }

        let prefix = "\(summaries.count) provider\(summaries.count == 1 ? "" : "s")"
        return "\(prefix) — \(parts.joined(separator: ", "))."
    }

    private func isPerProviderEnabled(_ tab: ProviderTab, configuration: NotificationConfiguration) -> Bool {
        switch tab {
        case .codex: return configuration.perProvider.codex
        case .cursor: return configuration.perProvider.cursor
        case .devin: return configuration.perProvider.devin
        case .openCodeGo: return configuration.perProvider.openCodeGo
        case .overview, .settings: return false
        }
    }

    private func isFailedState(_ state: UsageViewModel.LoadState) -> Bool {
        if case .failed = state { return true }
        return false
    }

    private func isQuietHours(configuration: NotificationConfiguration, now: Date) -> Bool {
        guard let start = configuration.quietHoursStartHour,
              let end = configuration.quietHoursEndHour else {
            return false
        }
        let hour = Calendar.current.component(.hour, from: now)
        if start <= end {
            return hour >= start && hour < end
        }
        return hour >= start || hour < end
    }
}

final class SystemNotifier: Notifier {
    func deliver(_ request: NotificationRequest) async {
        guard Bundle.main.bundlePath.hasSuffix(".app") else { return }
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let notificationRequest = UNNotificationRequest(
            identifier: request.identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(notificationRequest)
        } catch {
            // Notifications may fail if authorization is denied; silently ignore
        }
    }
}
