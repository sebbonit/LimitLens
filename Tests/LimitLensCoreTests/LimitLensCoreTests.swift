import Foundation
import Testing
@testable import LimitLensCore

@Suite("LimitLens core parsing")
struct LimitLensCoreTests {
    @Test("Decodes rate limits and prefers the Codex bucket")
    func decodesAndPrefersCodexBucket() throws {
        let response = try decodeFixture("rate_limits_full", as: GetAccountRateLimitsResponse.self)

        #expect(response.rateLimitResetCredits?.availableCount == 2)
        #expect(response.rateLimitResetCredits?.expiresAt == 1_784_000_000)
        #expect(response.preferredRateLimit.limitId == "codex")
        #expect(response.preferredRateLimit.planType == "pro")
        #expect(response.preferredRateLimit.primary?.usedPercent == 20)
        #expect(response.preferredRateLimit.secondary?.usedPercent == 10)
    }

    @Test("Falls back to the legacy rate limit snapshot")
    func fallsBackToLegacySnapshot() throws {
        let response = try decodeFixture("rate_limits_fallback", as: GetAccountRateLimitsResponse.self)

        #expect(response.preferredRateLimit.limitId == "fallback")
        #expect(response.preferredRateLimit.secondary == nil)
        #expect(response.preferredRateLimit.primary?.resetsAt == nil)
    }

    @Test("Decodes reset-credit details from the current Codex response")
    func decodesCurrentResetCreditDetails() throws {
        let response = try decodeFixture("rate_limits_current", as: GetAccountRateLimitsResponse.self)
        let resetCredits = ResetCreditInfo(summary: response.rateLimitResetCredits)

        #expect(resetCredits.availableCount == 1)
        #expect(resetCredits.credits.first?.id == "credit-1")
        #expect(resetCredits.credits.first?.resetType == "codexRateLimits")
        #expect(resetCredits.credits.first?.grantedAt == Date(timeIntervalSince1970: 1_781_000_000))
        #expect(resetCredits.credits.first?.expiresAt == Date(timeIntervalSince1970: 1_782_000_000))
    }

    @Test("Decodes token usage summary")
    func decodesUsageSummary() throws {
        let response = try decodeFixture("usage", as: GetAccountTokenUsageResponse.self)

        #expect(response.summary.lifetimeTokens == 1_234_567)
        #expect(response.summary.peakDailyTokens == 500_000)
        #expect(response.summary.currentStreakDays == 3)
        #expect(response.dailyUsageBuckets?.first?.startDate == "2026-06-30")
    }

    @Test("Snapshot retains Codex daily usage buckets")
    func snapshotRetainsDailyUsageBuckets() throws {
        let response = try decodeFixture("usage", as: GetAccountTokenUsageResponse.self)
        let rateLimit = RateLimitSnapshot(
            credits: nil,
            individualLimit: nil,
            limitId: "codex",
            limitName: nil,
            planType: "pro",
            primary: nil,
            rateLimitReachedType: nil,
            secondary: nil
        )
        let snapshot = LimitLensSnapshot(
            rateLimit: rateLimit,
            resetCredits: ResetCreditInfo(availableCount: 0, totalEarnedCount: nil, credits: []),
            tokenUsage: response.summary,
            dailyUsageBuckets: response.dailyUsageBuckets ?? []
        )

        #expect(snapshot.dailyUsageBuckets.count == 1)
        #expect(snapshot.dailyUsageBuckets.first?.tokens == 500_000)
    }

    @Test("Decodes Cursor usage and plan info")
    func decodesCursorUsageAndPlanInfo() throws {
        let usage = try decodeFixture("cursor_current_period_usage", as: CursorCurrentPeriodUsageResponse.self)
        let plan = try decodeFixture("cursor_plan_info", as: CursorPlanInfoResponse.self)
        let snapshot = usage.snapshot(plan: plan.planInfo)

        #expect(snapshot.planName == "Pro")
        #expect(snapshot.price == "$20/mo")
        #expect(snapshot.remainingCents == 1_500)
        #expect(snapshot.limitCents == 2_000)
        #expect(snapshot.usedPercent == 25)
        #expect(snapshot.autoSpendCents == 200)
        #expect(snapshot.autoLimitCents == 1_000)
        #expect(snapshot.autoPercentUsed == 10.5)
        #expect(snapshot.apiSpendCents == 300)
        #expect(snapshot.apiLimitCents == 1_000)
        #expect(snapshot.apiPercentUsed == 14.5)
        #expect(snapshot.billingCycleEnd == Date(timeIntervalSince1970: 1_784_850_897))
    }

    @Test("Computes Cursor usage percent when total percent is absent")
    func computesCursorUsagePercentFallback() {
        let snapshot = CursorUsageSnapshot(
            planName: "Pro",
            price: nil,
            includedAmountCents: 2_000,
            billingCycleStart: nil,
            billingCycleEnd: nil,
            remainingCents: 500,
            limitCents: 2_000,
            totalPercentUsed: nil,
            autoSpendCents: nil,
            autoLimitCents: nil,
            autoPercentUsed: nil,
            apiSpendCents: nil,
            apiLimitCents: nil,
            apiPercentUsed: nil,
            displayMessage: nil
        )

        #expect(snapshot.usedPercent == 75)
    }

    @Test("Decodes flat Devin Desktop quota cache")
    func decodesFlatDesktopQuotaCache() throws {
        let response = try decodeFixture("desktop_quota_flat", as: DesktopQuotaPlanInfo.self)
        let snapshot = response.snapshot(appName: "Devin Desktop")

        #expect(snapshot.appName == "Devin Desktop")
        #expect(snapshot.planName == "Pro")
        #expect(snapshot.billingStrategy == "quota")
        #expect(snapshot.dailyRemainingPercent == 100)
        #expect(snapshot.weeklyRemainingPercent == 80)
        #expect(snapshot.dailyUsedPercent == 0)
        #expect(snapshot.weeklyUsedPercent == 20)
        #expect(snapshot.dailyResetAt == Date(timeIntervalSince1970: 1_782_201_600))
        #expect(snapshot.cycleEnd == Date(timeIntervalSince1970: 1_784_319_524))
    }

    @Test("Decodes nested Devin quota cache")
    func decodesNestedDesktopQuotaCache() throws {
        let response = try decodeFixture("desktop_quota_nested", as: DesktopQuotaPlanInfo.self)
        let snapshot = response.snapshot(appName: "Devin Desktop")

        #expect(snapshot.appName == "Devin Desktop")
        #expect(snapshot.planName == "Teams")
        #expect(snapshot.dailyRemainingPercent == 66)
        #expect(snapshot.weeklyRemainingPercent == 80)
        #expect(snapshot.dailyUsedPercent == 34)
        #expect(snapshot.weeklyUsedPercent == 20)
        #expect(snapshot.weeklyResetAt == Date(timeIntervalSince1970: 1_776_585_600))
    }

    @Test("Treats missing Devin remaining percent with reset time as exhausted")
    func treatsMissingDesktopRemainingPercentAsExhausted() {
        let snapshot = DesktopQuotaSnapshot(
            appName: "Devin Desktop",
            planName: "Pro",
            billingStrategy: "quota",
            cycleStart: nil,
            cycleEnd: nil,
            dailyRemainingPercent: nil,
            weeklyRemainingPercent: 50,
            dailyResetAt: Date(timeIntervalSince1970: 1_783_238_400),
            weeklyResetAt: Date(timeIntervalSince1970: 1_783_238_400),
            overageBalanceMicros: nil
        )

        #expect(snapshot.dailyUsedPercent == 100)
        #expect(snapshot.weeklyUsedPercent == 50)
        #expect(snapshot.shouldTreatQuotaUsageAsUnavailable == false)
    }

    @Test("Parses OpenCode Go Solid dashboard usage")
    func parsesOpenCodeGoSolidDashboardUsage() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let html = #"""
        <script>
        rollingUsage:$R[1]={usagePercent:7,resetInSec:16080}
        weeklyUsage:$R[2]={resetInSec:8640,usagePercent:3}
        monthlyUsage:$R[3]={usagePercent:1,resetInSec:2340000}
        </script>
        """#

        let snapshot = OpenCodeGoDashboardParser.snapshot(from: html, now: now, source: "Test")

        #expect(snapshot.rolling?.usedPercent == 7)
        #expect(snapshot.rolling?.resetAt == now.addingTimeInterval(16_080))
        #expect(snapshot.weekly?.usedPercent == 3)
        #expect(snapshot.weekly?.resetAt == now.addingTimeInterval(8_640))
        #expect(snapshot.monthly?.usedPercent == 1)
        #expect(snapshot.monthly?.resetAt == now.addingTimeInterval(2_340_000))
    }

    @Test("Parses OpenCode Go data-slot dashboard usage")
    func parsesOpenCodeGoDataSlotDashboardUsage() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let html = #"""
        <div data-slot="usage-item">
          <span data-slot="usage-label">Rolling Usage</span>
          <span data-slot="usage-value">7%</span>
          <span data-slot="reset-time">Resets in 4 hours 28 minutes</span>
        </div>
        <div data-slot="usage-item">
          <span data-slot="usage-label">Weekly Usage</span>
          <span data-slot="usage-value">3%</span>
          <span data-slot="reset-time">Resets in 2 hours 24 minutes</span>
        </div>
        <div data-slot="usage-item">
          <span data-slot="usage-label">Monthly Usage</span>
          <span data-slot="usage-value">1%</span>
          <span data-slot="reset-time">Resets in 27 days 1 hour</span>
        </div>
        """#

        let snapshot = OpenCodeGoDashboardParser.snapshot(from: html, now: now, source: "Test")

        #expect(snapshot.rolling?.usedPercent == 7)
        #expect(snapshot.rolling?.resetAt == now.addingTimeInterval(16_080))
        #expect(snapshot.weekly?.usedPercent == 3)
        #expect(snapshot.weekly?.resetAt == now.addingTimeInterval(8_640))
        #expect(snapshot.monthly?.usedPercent == 1)
        #expect(snapshot.monthly?.resetAt == now.addingTimeInterval(2_336_400))
    }

    @Test("Parses OpenCode Go billing page")
    func parsesOpenCodeGoBilling() {
        let html = #"""
        <span data-slot="balance-value">$<!--$-->0.00<!--/--></span>
        <span data-slot="secret">••••</span><span data-slot="number">2809</span>
        <p>Auto reload is<!--$--> <b>disabled</b>. Enable to automatically reload when balance is low.</p>
        <table data-slot="payments-table-element"><thead><tr><th>Date</th><th>Payment ID</th><th>Amount</th><th>Receipt</th></tr></thead><tbody>
        <tr><td data-slot="payment-date" title="Wed, Jul 1, 2026, 11:51:42 PM UTC">Jul 1, 11:51 PM</td><td data-slot="payment-id">pay_01KWG1GY4GW96V8E2V4C9J41RJ</td><td data-slot="payment-amount" data-refunded="false">$10.00</td><td data-slot="payment-receipt"><button>View</button></td></tr>
        <tr><td data-slot="payment-date" title="Fri, May 1, 2026, 10:50:56 PM UTC">May 1, 10:50 PM</td><td data-slot="payment-id">pay_01KQJVSTAG6XX6Z4D7AT6EM8Z3</td><td data-slot="payment-amount" data-refunded="true">$5.00</td><td data-slot="payment-receipt"><button>View</button></td></tr>
        </tbody></table>
        """#

        let billing = OpenCodeGoBillingParser.billing(from: html)

        #expect(billing?.balanceText == "$0.00")
        #expect(billing?.cardLast4 == "2809")
        #expect(billing?.autoReloadEnabled == false)
        #expect(billing?.payments.count == 2)
        #expect(billing?.payments.first?.id == "pay_01KWG1GY4GW96V8E2V4C9J41RJ")
        #expect(billing?.payments.first?.amountText == "$10.00")
        #expect(billing?.payments.first?.dateText == "Jul 1, 11:51 PM")
        #expect(billing?.payments.first?.refunded == false)
        let firstDate = Date(timeIntervalSince1970: 1_782_949_902)
        #expect(billing?.payments.first?.date == firstDate)
        #expect(billing?.payments.last?.refunded == true)
    }

    @Test("Parses OpenCode Go billing when auto reload is enabled")
    func parsesOpenCodeGoBillingAutoReloadEnabled() {
        let html = #"""
        <span data-slot="balance-value">$<!--$-->12.50<!--/--></span>
        <p>Auto reload is<!--$--> <b>enabled</b>. Reload $20 when balance drops below $5.</p>
        """#

        let billing = OpenCodeGoBillingParser.billing(from: html)

        #expect(billing?.balanceText == "$12.50")
        #expect(billing?.autoReloadEnabled == true)
        #expect(billing?.payments.isEmpty == true)
    }

    @Test("Returns nil billing when no billing data is present")
    func returnsNilBillingWhenEmpty() {
        let html = #"<html><body><h1>Not a billing page</h1></body></html>"#
        #expect(OpenCodeGoBillingParser.billing(from: html) == nil)
    }

    @Test("Estimates next payment date from two monthly payments")
    func estimatesNextPaymentDateFromTwoPayments() {
        let now = Date(timeIntervalSince1970: 1_782_949_902) // Jul 1, 2026 23:51 UTC
        let lastDate = now
        let previousDate = lastDate.addingTimeInterval(-30 * 86_400) // ~Jun 1
        let billing = OpenCodeGoBilling(
            balanceText: nil,
            cardLast4: nil,
            autoReloadEnabled: false,
            payments: [
                OpenCodeGoPayment(id: "p1", amountText: "$10", date: lastDate, dateText: "", refunded: false),
                OpenCodeGoPayment(id: "p2", amountText: "$10", date: previousDate, dateText: "", refunded: false)
            ]
        )
        let next = billing.nextPaymentDate
        #expect(next != nil)
        // 30-day gap snaps to 30-day monthly cycle
        #expect(next == lastDate.addingTimeInterval(30 * 86_400))
    }

    @Test("Snaps 61-day gap to monthly cycle instead of using raw gap")
    func snapsLargeGapToMonthlyCycle() {
        // Simulates the user's real data: Jul 2 and May 2 (61-day gap, missing June payment)
        let lastDate = Date(timeIntervalSince1970: 1_782_949_902) // Jul 1, 2026
        let previousDate = lastDate.addingTimeInterval(-61 * 86_400) // May 1, 2026
        let billing = OpenCodeGoBilling(
            balanceText: nil,
            cardLast4: nil,
            autoReloadEnabled: false,
            payments: [
                OpenCodeGoPayment(id: "p1", amountText: "$10", date: lastDate, dateText: "", refunded: false),
                OpenCodeGoPayment(id: "p2", amountText: "$10", date: previousDate, dateText: "", refunded: false)
            ]
        )
        let next = billing.nextPaymentDate
        #expect(next != nil)
        // 61 days ≈ 2×30 → snaps to 30-day cycle, not 61-day raw gap
        #expect(next == lastDate.addingTimeInterval(30 * 86_400))
        // Should NOT be 61 days later
        #expect(next != lastDate.addingTimeInterval(61 * 86_400))
    }

    @Test("Advances next payment date into the future when last payment is old")
    func advancesNextPaymentDateIntoFuture() {
        let now = Date()
        let lastDate = now.addingTimeInterval(-70 * 86_400) // 70 days ago
        let previousDate = lastDate.addingTimeInterval(-30 * 86_400) // 100 days ago
        let billing = OpenCodeGoBilling(
            balanceText: nil,
            cardLast4: nil,
            autoReloadEnabled: false,
            payments: [
                OpenCodeGoPayment(id: "p1", amountText: "$10", date: lastDate, dateText: "", refunded: false),
                OpenCodeGoPayment(id: "p2", amountText: "$10", date: previousDate, dateText: "", refunded: false)
            ]
        )
        let next = billing.nextPaymentDate
        #expect(next != nil)
        #expect(next! > now)
    }

    @Test("Falls back to 30-day interval with a single payment")
    func fallsBackTo30DayIntervalWithSinglePayment() {
        let lastDate = Date().addingTimeInterval(-10 * 86_400) // 10 days ago
        let billing = OpenCodeGoBilling(
            balanceText: nil,
            cardLast4: nil,
            autoReloadEnabled: false,
            payments: [
                OpenCodeGoPayment(id: "p1", amountText: "$10", date: lastDate, dateText: "", refunded: false)
            ]
        )
        let next = billing.nextPaymentDate
        #expect(next != nil)
        // 10 days ago + 30 days = 20 days from now
        let expected = lastDate.addingTimeInterval(30 * 86_400)
        #expect(next == expected)
    }

    @Test("Returns nil next payment date when no valid payments exist")
    func returnsNilNextPaymentDateWhenNoPayments() {
        let billing = OpenCodeGoBilling(
            balanceText: "$5.00",
            cardLast4: "1234",
            autoReloadEnabled: false,
            payments: []
        )
        #expect(billing.nextPaymentDate == nil)
    }

    @Test("Ignores refunded payments when estimating next payment date")
    func ignoresRefundedPaymentsWhenEstimating() {
        let now = Date()
        let lastDate = now.addingTimeInterval(-10 * 86_400)
        let billing = OpenCodeGoBilling(
            balanceText: nil,
            cardLast4: nil,
            autoReloadEnabled: false,
            payments: [
                OpenCodeGoPayment(id: "p1", amountText: "$10", date: lastDate, dateText: "", refunded: true),
                OpenCodeGoPayment(id: "p2", amountText: "$10", date: lastDate.addingTimeInterval(-30 * 86_400), dateText: "", refunded: false)
            ]
        )
        // The only non-refunded payment is p2 (40 days ago), so next = p2 + 30d = 10 days ago → advance to +30d = 20 days from now
        let next = billing.nextPaymentDate
        #expect(next != nil)
        #expect(next! > now)
    }

    @Test("Decodes backend reset-credit expirations")
    func decodesBackendResetCreditExpirations() throws {
        let response = try decodeFixture("reset_credits_backend", as: BackendResetCreditsResponse.self, decoder: .resetStatBackend)
        let info = response.asResetCreditInfo

        #expect(info.availableCount == 2)
        #expect(info.totalEarnedCount == 2)
        #expect(info.credits.count == 2)
        #expect(info.nextExpiringCredit?.id == "credit-1")
        #expect(info.nextExpiringCredit?.expiresAt == ISO8601DateFormatter().date(from: "2026-07-02T08:15:00Z"))
    }

    @Test("Decodes Codex account entitlement renewal")
    func decodesCodexAccountEntitlementRenewal() throws {
        let response = try decodeFixture("codex_accounts_check", as: BackendCodexAccountResponse.self, decoder: .resetStatBackend)

        #expect(response.planExpiresAt == ISO8601DateFormatter().date(from: "2026-07-14T22:09:02Z"))
    }

    @Test("Chooses the closest reset credit expiry")
    func choosesClosestResetCreditExpiry() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let info = ResetCreditInfo(
            availableCount: 3,
            totalEarnedCount: 3,
            credits: [
                resetCredit(id: "later", expiresAt: now.addingTimeInterval(20 * 86_400)),
                resetCredit(id: "closest", expiresAt: now.addingTimeInterval(2 * 86_400)),
                resetCredit(id: "middle", expiresAt: now.addingTimeInterval(10 * 86_400))
            ]
        )

        #expect(info.nextExpiringCredit?.id == "closest")
    }

    @Test("Maps reset credit expiry urgency thresholds")
    func mapsResetCreditExpiryUrgencyThresholds() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        #expect(UsageFormatting.expiryUrgency(expiresAt: nil, now: now) == .unknown)
        #expect(UsageFormatting.expiryUrgency(expiresAt: now.addingTimeInterval(-60), now: now) == .expired)
        #expect(UsageFormatting.expiryUrgency(expiresAt: now.addingTimeInterval(6.9 * 86_400), now: now) == .soon)
        #expect(UsageFormatting.expiryUrgency(expiresAt: now.addingTimeInterval(15 * 86_400), now: now) == .warning)
        #expect(UsageFormatting.expiryUrgency(expiresAt: now.addingTimeInterval(15.1 * 86_400), now: now) == .healthy)
    }

    @Test("Formats reset timestamps and missing reset values")
    func formatsResetValues() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_782_900_000)

        #expect(UsageFormatting.timeRemainingText(timestamp: 1_783_000_000, now: now) == "1d 3h")
        #expect(UsageFormatting.timeRemainingText(date: Date(timeIntervalSince1970: 1_783_000_000), now: now) == "1d 3h")
        #expect(UsageFormatting.timeRemainingText(timestamp: nil, now: now) == "Unknown")
        #expect(UsageFormatting.resetText(timestamp: nil, now: now, calendar: calendar) == "Reset time unavailable")
        #expect(UsageFormatting.percentRemaining(usedPercent: 35) == 65)
    }

    @Test("Formats compact countdown text for menu bar")
    func formatsCompactCountdownText() {
        let now = Date(timeIntervalSince1970: 1_782_900_000)

        #expect(UsageFormatting.compactCountdownText(date: nil, now: now) == "?")
        #expect(UsageFormatting.compactCountdownText(date: now.addingTimeInterval(-60), now: now) == "now")
        #expect(UsageFormatting.compactCountdownText(date: now.addingTimeInterval(15 * 60), now: now) == "15m")
        #expect(UsageFormatting.compactCountdownText(date: now.addingTimeInterval(90 * 60), now: now) == "1h30m")
        #expect(UsageFormatting.compactCountdownText(date: now.addingTimeInterval(60 * 60), now: now) == "1h")
        #expect(UsageFormatting.compactCountdownText(date: now.addingTimeInterval(25 * 3_600), now: now) == "1d1h")
        #expect(UsageFormatting.compactCountdownText(date: now.addingTimeInterval(86_400), now: now) == "1d")
    }

    @Test("Compact countdown rounds to nearest minute")
    func compactCountdownRoundsToNearestMinute() {
        let now = Date(timeIntervalSince1970: 1_782_900_000)

        // 5h minus 10s should round up to 5h, not truncate to 4h59m
        #expect(UsageFormatting.compactCountdownText(date: now.addingTimeInterval(5 * 3_600 - 10), now: now) == "5h")
        // 5h minus 31s should round down to 4h59m
        #expect(UsageFormatting.compactCountdownText(date: now.addingTimeInterval(5 * 3_600 - 31), now: now) == "4h59m")
        // 90m plus 29s should still round to 1h30m
        #expect(UsageFormatting.compactCountdownText(date: now.addingTimeInterval(90 * 60 + 29), now: now) == "1h30m")
    }

    @Test("Formats relative day text")
    func formatsRelativeDayText() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = ISO8601DateFormatter().date(from: "2026-07-07T12:00:00Z")!

        #expect(UsageFormatting.relativeDayText(date: ISO8601DateFormatter().date(from: "2026-07-07T20:00:00Z"), now: now, calendar: calendar) == "later today")
        #expect(UsageFormatting.relativeDayText(date: ISO8601DateFormatter().date(from: "2026-07-08T08:00:00Z"), now: now, calendar: calendar) == "tomorrow")
        #expect(UsageFormatting.relativeDayText(date: ISO8601DateFormatter().date(from: "2026-07-12T08:00:00Z"), now: now, calendar: calendar) == "in 5d")
        #expect(UsageFormatting.relativeDayText(date: ISO8601DateFormatter().date(from: "2026-07-06T08:00:00Z"), now: now, calendar: calendar) == "yesterday")
    }

    @Test("Formats Cursor usage amounts as USD")
    func formatsCursorUsageAmountsAsUSD() {
        #expect(UsageFormatting.usd(cents: 2_000) == "$20")
        #expect(UsageFormatting.usd(cents: 1_234) == "$12.34")
        #expect(UsageFormatting.usd(cents: nil) == "--")
        #expect(UsageFormatting.usd(micros: -82_287) == "$-0.08")
    }

    @Test("Maps auth-like app-server errors to sign-in state")
    func mapsAuthErrors() {
        #expect(CodexUsageError.fromServerMessage("authentication required") == .notSignedIn)
        #expect(CodexUsageError.fromServerMessage("API key auth is not supported") == .notSignedIn)
        #expect(CodexUsageError.fromServerMessage("something else") == .protocolError("something else"))
    }

    private func decodeFixture<T: Decodable>(_ name: String, as type: T.Type, decoder: JSONDecoder = JSONDecoder()) throws -> T {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        let data = try Data(contentsOf: url)
        return try decoder.decode(T.self, from: data)
    }

    private func resetCredit(id: String, expiresAt: Date) -> ResetCredit {
        ResetCredit(
            id: id,
            resetType: "rate_limit",
            status: "available",
            grantedAt: nil,
            expiresAt: expiresAt,
            title: nil,
            description: nil
        )
    }
}
