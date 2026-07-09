import Foundation
import ResetStatCore
import Testing
@testable import ResetStat

@MainActor
@Suite("Notification coordinator")
struct UsageNotificationTests {
    @Test("Critical usage transition fires notification")
    func criticalUsageTransitionFiresNotification() async {
        let notifier = RecordingNotifier()
        let coordinator = NotificationCoordinator(notifier: notifier)

        var config = NotificationConfiguration()
        config.enabled = true

        let summary = makeSummary(tab: .codex, severity: .healthy, percentUsed: 50)
        await coordinator.evaluate(
            summaries: [summary],
            billingExpiries: [],
            loadStates: [.codex: .loaded],
            configuration: config,
            hidesProviderNames: false,
            now: Date()
        )

        let criticalSummary = makeSummary(tab: .codex, severity: .critical, percentUsed: 92)
        await coordinator.evaluate(
            summaries: [criticalSummary],
            billingExpiries: [],
            loadStates: [.codex: .loaded],
            configuration: config,
            hidesProviderNames: false,
            now: Date()
        )

        #expect(notifier.requests.count == 1)
        #expect(notifier.requests[0].identifier == "critical-codex")
        #expect(notifier.requests[0].title.contains("Codex"))
        #expect(notifier.requests[0].title.contains("critical"))
    }

    @Test("Repeated critical state does not fire again")
    func repeatedCriticalDoesNotFireAgain() async {
        let notifier = RecordingNotifier()
        let coordinator = NotificationCoordinator(notifier: notifier)

        var config = NotificationConfiguration()
        config.enabled = true

        let criticalSummary = makeSummary(tab: .codex, severity: .critical, percentUsed: 92)

        await coordinator.evaluate(summaries: [criticalSummary], billingExpiries: [], loadStates: [.codex: .loaded], configuration: config, hidesProviderNames: false, now: Date())
        await coordinator.evaluate(summaries: [criticalSummary], billingExpiries: [], loadStates: [.codex: .loaded], configuration: config, hidesProviderNames: false, now: Date())

        #expect(notifier.requests.count == 1)
    }

    @Test("Recovery from critical does not fire")
    func recoveryFromCriticalDoesNotFire() async {
        let notifier = RecordingNotifier()
        let coordinator = NotificationCoordinator(notifier: notifier)

        var config = NotificationConfiguration()
        config.enabled = true

        await coordinator.evaluate(summaries: [makeSummary(tab: .codex, severity: .critical, percentUsed: 92)], billingExpiries: [], loadStates: [.codex: .loaded], configuration: config, hidesProviderNames: false, now: Date())
        await coordinator.evaluate(summaries: [makeSummary(tab: .codex, severity: .healthy, percentUsed: 40)], billingExpiries: [], loadStates: [.codex: .loaded], configuration: config, hidesProviderNames: false, now: Date())

        #expect(notifier.requests.count == 1)
    }

    @Test("Disabled notifications suppress all")
    func disabledNotificationsSuppressAll() async {
        let notifier = RecordingNotifier()
        let coordinator = NotificationCoordinator(notifier: notifier)

        let config = NotificationConfiguration(enabled: false)

        await coordinator.evaluate(summaries: [makeSummary(tab: .codex, severity: .critical, percentUsed: 92)], billingExpiries: [], loadStates: [.codex: .loaded], configuration: config, hidesProviderNames: false, now: Date())

        #expect(notifier.requests.isEmpty)
    }

    @Test("Per-provider flag suppresses notification")
    func perProviderFlagSuppressesNotification() async {
        let notifier = RecordingNotifier()
        let coordinator = NotificationCoordinator(notifier: notifier)

        var config = NotificationConfiguration()
        config.enabled = true
        config.perProvider.codex = false

        await coordinator.evaluate(summaries: [makeSummary(tab: .codex, severity: .critical, percentUsed: 92)], billingExpiries: [], loadStates: [.codex: .loaded], configuration: config, hidesProviderNames: false, now: Date())

        #expect(notifier.requests.isEmpty)
    }

    @Test("Billing expiry transition fires notification")
    func billingExpiryTransitionFiresNotification() async {
        let notifier = RecordingNotifier()
        let coordinator = NotificationCoordinator(notifier: notifier)

        var config = NotificationConfiguration()
        config.enabled = true

        let healthyExpiry = makeBillingExpiry(tab: .codex, urgency: .healthy, date: Date().addingTimeInterval(30 * 86_400))
        await coordinator.evaluate(summaries: [], billingExpiries: [healthyExpiry], loadStates: [:], configuration: config, hidesProviderNames: false, now: Date())

        let soonExpiry = makeBillingExpiry(tab: .codex, urgency: .soon, date: Date().addingTimeInterval(3 * 86_400))
        await coordinator.evaluate(summaries: [], billingExpiries: [soonExpiry], loadStates: [:], configuration: config, hidesProviderNames: false, now: Date())

        #expect(notifier.requests.count == 1)
        #expect(notifier.requests[0].identifier == "billing-codex")
        #expect(notifier.requests[0].title.contains("renewal"))
    }

    @Test("Provider unavailable transition fires notification")
    func providerUnavailableTransitionFiresNotification() async {
        let notifier = RecordingNotifier()
        let coordinator = NotificationCoordinator(notifier: notifier)

        var config = NotificationConfiguration()
        config.enabled = true

        let loadedSummary = makeSummary(tab: .codex, severity: .healthy, percentUsed: 40)
        await coordinator.evaluate(summaries: [loadedSummary], billingExpiries: [], loadStates: [.codex: .loaded], configuration: config, hidesProviderNames: false, now: Date())

        let unavailableSummary = makeSummary(tab: .codex, severity: .unavailable, percentUsed: nil)
        await coordinator.evaluate(summaries: [unavailableSummary], billingExpiries: [], loadStates: [.codex: .failed("error")], configuration: config, hidesProviderNames: false, now: Date())

        #expect(notifier.requests.count == 1)
        #expect(notifier.requests[0].identifier == "unavailable-codex")
        #expect(notifier.requests[0].title.contains("unavailable"))
    }

    @Test("Quiet hours suppress notifications")
    func quietHoursSuppressNotifications() async {
        let notifier = RecordingNotifier()
        let coordinator = NotificationCoordinator(notifier: notifier)

        var config = NotificationConfiguration()
        config.enabled = true
        config.quietHoursStartHour = 22
        config.quietHoursEndHour = 7

        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 23))!

        await coordinator.evaluate(summaries: [makeSummary(tab: .codex, severity: .critical, percentUsed: 92)], billingExpiries: [], loadStates: [.codex: .loaded], configuration: config, hidesProviderNames: false, now: now)

        #expect(notifier.requests.isEmpty)
    }

    @Test("Quiet hours wrap-around suppresses overnight")
    func quietHoursWrapAroundSuppressesOvernight() async {
        let notifier = RecordingNotifier()
        let coordinator = NotificationCoordinator(notifier: notifier)

        var config = NotificationConfiguration()
        config.enabled = true
        config.quietHoursStartHour = 22
        config.quietHoursEndHour = 7

        let midnight = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 0))!
        let noon = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 12))!

        await coordinator.evaluate(summaries: [makeSummary(tab: .codex, severity: .critical, percentUsed: 92)], billingExpiries: [], loadStates: [.codex: .loaded], configuration: config, hidesProviderNames: false, now: midnight)
        #expect(notifier.requests.isEmpty)

        await coordinator.evaluate(summaries: [makeSummary(tab: .cursor, severity: .critical, percentUsed: 95)], billingExpiries: [], loadStates: [.cursor: .loaded], configuration: config, hidesProviderNames: false, now: noon)
        #expect(notifier.requests.count == 1)
    }

    @Test("Hides provider names uses private names in notification title")
    func hidesProviderNamesUsesPrivateNames() async {
        let notifier = RecordingNotifier()
        let coordinator = NotificationCoordinator(notifier: notifier)

        var config = NotificationConfiguration()
        config.enabled = true

        await coordinator.evaluate(summaries: [makeSummary(tab: .codex, severity: .critical, percentUsed: 92)], billingExpiries: [], loadStates: [.codex: .loaded], configuration: config, hidesProviderNames: true, now: Date())

        #expect(notifier.requests.count == 1)
        #expect(notifier.requests[0].title.contains("Provider 1"))
        #expect(!notifier.requests[0].title.contains("Codex"))
    }

    @Test("Critical usage flag disabled suppresses critical notifications")
    func criticalUsageFlagDisabledSuppressesCritical() async {
        let notifier = RecordingNotifier()
        let coordinator = NotificationCoordinator(notifier: notifier)

        var config = NotificationConfiguration()
        config.enabled = true
        config.criticalUsage = false

        await coordinator.evaluate(summaries: [makeSummary(tab: .codex, severity: .critical, percentUsed: 92)], billingExpiries: [], loadStates: [.codex: .loaded], configuration: config, hidesProviderNames: false, now: Date())

        #expect(notifier.requests.isEmpty)
    }

    @Test("Custom critical threshold fires below default 90%")
    func customThresholdFiresBelowDefault() async {
        let notifier = RecordingNotifier()
        let coordinator = NotificationCoordinator(notifier: notifier)

        var config = NotificationConfiguration()
        config.enabled = true
        config.thresholds.codex = 50

        // 60% is below the default 90% but above the custom 50% threshold
        let summary = makeSummary(tab: .codex, severity: .warning, percentUsed: 60)
        await coordinator.evaluate(
            summaries: [summary],
            billingExpiries: [],
            loadStates: [.codex: .loaded],
            configuration: config,
            hidesProviderNames: false,
            now: Date()
        )

        #expect(notifier.requests.count == 1)
        #expect(notifier.requests[0].identifier == "critical-codex")
        #expect(notifier.requests[0].body.contains("60%"))
    }

    @Test("Custom critical threshold does not fire when below threshold")
    func customThresholdDoesNotFireBelowThreshold() async {
        let notifier = RecordingNotifier()
        let coordinator = NotificationCoordinator(notifier: notifier)

        var config = NotificationConfiguration()
        config.enabled = true
        config.thresholds.codex = 80

        // 75% is below the custom 80% threshold
        let summary = makeSummary(tab: .codex, severity: .warning, percentUsed: 75)
        await coordinator.evaluate(
            summaries: [summary],
            billingExpiries: [],
            loadStates: [.codex: .loaded],
            configuration: config,
            hidesProviderNames: false,
            now: Date()
        )

        #expect(notifier.requests.isEmpty)
    }

    @Test("Per-provider threshold only affects configured provider")
    func perProviderThresholdOnlyAffectsConfiguredProvider() async {
        let notifier = RecordingNotifier()
        let coordinator = NotificationCoordinator(notifier: notifier)

        var config = NotificationConfiguration()
        config.enabled = true
        config.thresholds.codex = 50
        // Cursor uses default 90%

        let codexSummary = makeSummary(tab: .codex, severity: .warning, percentUsed: 55)
        let cursorSummary = makeSummary(tab: .cursor, severity: .warning, percentUsed: 55)

        await coordinator.evaluate(
            summaries: [codexSummary, cursorSummary],
            billingExpiries: [],
            loadStates: [.codex: .loaded, .cursor: .loaded],
            configuration: config,
            hidesProviderNames: false,
            now: Date()
        )

        #expect(notifier.requests.count == 1)
        #expect(notifier.requests[0].identifier == "critical-codex")
    }

    @Test("Nil threshold uses default 90%")
    func nilThresholdUsesDefault() async {
        let notifier = RecordingNotifier()
        let coordinator = NotificationCoordinator(notifier: notifier)

        var config = NotificationConfiguration()
        config.enabled = true
        // thresholds left as nil defaults

        // 89% should not fire with default 90%
        let summary = makeSummary(tab: .codex, severity: .warning, percentUsed: 89)
        await coordinator.evaluate(
            summaries: [summary],
            billingExpiries: [],
            loadStates: [.codex: .loaded],
            configuration: config,
            hidesProviderNames: false,
            now: Date()
        )

        #expect(notifier.requests.isEmpty)
    }
}

private final class RecordingNotifier: Notifier, @unchecked Sendable {
    var requests: [NotificationRequest] = []

    func deliver(_ request: NotificationRequest) async {
        requests.append(request)
    }
}

private func makeSummary(tab: ProviderTab, severity: UsageSeverity, percentUsed: Double?) -> ProviderUsageSummary {
    ProviderUsageSummary(
        tab: tab,
        detail: "Test",
        subdetail: "Test subdetail",
        secondaryDetail: nil,
        percentUsed: percentUsed,
        resetAt: Date().addingTimeInterval(3_600),
        severity: severity
    )
}

private func makeBillingExpiry(tab: ProviderTab, urgency: UsageFormatting.ExpiryUrgency, date: Date?) -> BillingExpiry {
    BillingExpiry(
        tab: tab,
        label: "Renews",
        date: date,
        amountText: nil,
        detailText: nil,
        urgency: urgency
    )
}
