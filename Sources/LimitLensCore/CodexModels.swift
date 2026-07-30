import Foundation

public struct RateLimitWindow: Codable, Equatable, Sendable {
    public let resetsAt: Int64?
    public let usedPercent: Int
    public let windowDurationMins: Int64?
}

public struct CreditsSnapshot: Codable, Equatable, Sendable {
    public let balance: String?
    public let hasCredits: Bool
    public let unlimited: Bool
}

public struct SpendControlLimitSnapshot: Codable, Equatable, Sendable {
    public let limit: String
    public let remainingPercent: Int
    public let resetsAt: Int64
    public let used: String
}

public struct RateLimitSnapshot: Codable, Equatable, Sendable {
    public let credits: CreditsSnapshot?
    public let individualLimit: SpendControlLimitSnapshot?
    public let limitId: String?
    public let limitName: String?
    public let planType: String?
    public let primary: RateLimitWindow?
    public let rateLimitReachedType: String?
    public let secondary: RateLimitWindow?
}

public struct RateLimitResetCreditsSummary: Codable, Equatable, Sendable {
    public let availableCount: Int
    public let expiresAt: Int64?
    public let credits: [RateLimitResetCreditSnapshot]?
}

public struct RateLimitResetCreditSnapshot: Codable, Equatable, Sendable {
    public let id: String
    public let resetType: String
    public let status: String
    public let grantedAt: Int64
    public let expiresAt: Int64?
    public let title: String?
    public let description: String?
}

public struct ResetCreditInfo: Equatable, Sendable {
    public let availableCount: Int
    public let totalEarnedCount: Int?
    public let credits: [ResetCredit]

    public init(availableCount: Int, totalEarnedCount: Int?, credits: [ResetCredit]) {
        self.availableCount = availableCount
        self.totalEarnedCount = totalEarnedCount
        self.credits = credits
    }

    public init(summary: RateLimitResetCreditsSummary?) {
        self.availableCount = summary?.availableCount ?? 0
        self.totalEarnedCount = nil
        if let credits = summary?.credits {
            self.credits = credits.map { credit in
                ResetCredit(
                    id: credit.id,
                    resetType: credit.resetType,
                    status: credit.status,
                    grantedAt: Date(timeIntervalSince1970: TimeInterval(credit.grantedAt)),
                    expiresAt: credit.expiresAt.map { Date(timeIntervalSince1970: TimeInterval($0)) },
                    title: credit.title,
                    description: credit.description
                )
            }
        } else if let expiresAt = summary?.expiresAt {
            self.credits = [
                ResetCredit(
                    id: nil,
                    resetType: nil,
                    status: nil,
                    grantedAt: nil,
                    expiresAt: Date(timeIntervalSince1970: TimeInterval(expiresAt)),
                    title: nil,
                    description: nil
                )
            ]
        } else {
            self.credits = []
        }
    }

    public var nextExpiringCredit: ResetCredit? {
        credits
            .filter { $0.expiresAt != nil }
            .sorted { ($0.expiresAt ?? .distantFuture) < ($1.expiresAt ?? .distantFuture) }
            .first
    }
}

public struct ResetCredit: Equatable, Sendable {
    public let id: String?
    public let resetType: String?
    public let status: String?
    public let grantedAt: Date?
    public let expiresAt: Date?
    public let title: String?
    public let description: String?

    public init(
        id: String?,
        resetType: String?,
        status: String?,
        grantedAt: Date?,
        expiresAt: Date?,
        title: String?,
        description: String?
    ) {
        self.id = id
        self.resetType = resetType
        self.status = status
        self.grantedAt = grantedAt
        self.expiresAt = expiresAt
        self.title = title
        self.description = description
    }
}

public struct GetAccountRateLimitsResponse: Codable, Equatable, Sendable {
    public let rateLimitResetCredits: RateLimitResetCreditsSummary?
    public let rateLimits: RateLimitSnapshot
    public let rateLimitsByLimitId: [String: RateLimitSnapshot]?

    public var preferredRateLimit: RateLimitSnapshot {
        rateLimitsByLimitId?["codex"] ?? rateLimits
    }
}

public struct AccountTokenUsageDailyBucket: Codable, Equatable, Sendable {
    public let startDate: String
    public let tokens: Int64

    public init(startDate: String, tokens: Int64) {
        self.startDate = startDate
        self.tokens = tokens
    }
}

public struct AccountTokenUsageSummary: Codable, Equatable, Sendable {
    public let currentStreakDays: Int64?
    public let lifetimeTokens: Int64?
    public let longestRunningTurnSec: Int64?
    public let longestStreakDays: Int64?
    public let peakDailyTokens: Int64?
}

public struct GetAccountTokenUsageResponse: Codable, Equatable, Sendable {
    public let dailyUsageBuckets: [AccountTokenUsageDailyBucket]?
    public let summary: AccountTokenUsageSummary
}

public struct LimitLensSnapshot: Equatable, Sendable {
    public let rateLimit: RateLimitSnapshot
    public let resetCredits: ResetCreditInfo
    public let planExpiresAt: Date?
    public let tokenUsage: AccountTokenUsageSummary?
    public let dailyUsageBuckets: [AccountTokenUsageDailyBucket]
    public let localUsage: CodexLocalUsageSummary?
    public let fetchedAt: Date

    public init(
        rateLimit: RateLimitSnapshot,
        resetCredits: ResetCreditInfo,
        planExpiresAt: Date? = nil,
        tokenUsage: AccountTokenUsageSummary?,
        dailyUsageBuckets: [AccountTokenUsageDailyBucket] = [],
        localUsage: CodexLocalUsageSummary? = nil,
        fetchedAt: Date = Date()
    ) {
        self.rateLimit = rateLimit
        self.resetCredits = resetCredits
        self.planExpiresAt = planExpiresAt
        self.tokenUsage = tokenUsage
        self.dailyUsageBuckets = dailyUsageBuckets
        self.localUsage = localUsage
        self.fetchedAt = fetchedAt
    }

    public func replacingLocalUsage(_ localUsage: CodexLocalUsageSummary?) -> LimitLensSnapshot {
        LimitLensSnapshot(
            rateLimit: rateLimit,
            resetCredits: resetCredits,
            planExpiresAt: planExpiresAt,
            tokenUsage: tokenUsage,
            dailyUsageBuckets: dailyUsageBuckets,
            localUsage: localUsage,
            fetchedAt: fetchedAt
        )
    }
}

public struct CursorUsageSnapshot: Equatable, Sendable {
    public let planName: String?
    public let price: String?
    public let includedAmountCents: Int?
    public let billingCycleStart: Date?
    public let billingCycleEnd: Date?
    public let remainingCents: Int?
    public let limitCents: Int?
    public let totalPercentUsed: Double?
    public let autoSpendCents: Int?
    public let autoLimitCents: Int?
    public let autoPercentUsed: Double?
    public let apiSpendCents: Int?
    public let apiLimitCents: Int?
    public let apiPercentUsed: Double?
    public let displayMessage: String?
    public let fetchedAt: Date

    public init(
        planName: String?,
        price: String?,
        includedAmountCents: Int?,
        billingCycleStart: Date?,
        billingCycleEnd: Date?,
        remainingCents: Int?,
        limitCents: Int?,
        totalPercentUsed: Double?,
        autoSpendCents: Int?,
        autoLimitCents: Int?,
        autoPercentUsed: Double?,
        apiSpendCents: Int?,
        apiLimitCents: Int?,
        apiPercentUsed: Double?,
        displayMessage: String?,
        fetchedAt: Date = Date()
    ) {
        self.planName = planName
        self.price = price
        self.includedAmountCents = includedAmountCents
        self.billingCycleStart = billingCycleStart
        self.billingCycleEnd = billingCycleEnd
        self.remainingCents = remainingCents
        self.limitCents = limitCents
        self.totalPercentUsed = totalPercentUsed
        self.autoSpendCents = autoSpendCents
        self.autoLimitCents = autoLimitCents
        self.autoPercentUsed = autoPercentUsed
        self.apiSpendCents = apiSpendCents
        self.apiLimitCents = apiLimitCents
        self.apiPercentUsed = apiPercentUsed
        self.displayMessage = displayMessage
        self.fetchedAt = fetchedAt
    }

    public var usedPercent: Double {
        if let totalPercentUsed {
            return max(0, min(100, totalPercentUsed))
        }
        guard let remainingCents, let limitCents, limitCents > 0 else {
            return 0
        }
        return max(0, min(100, Double(limitCents - remainingCents) / Double(limitCents) * 100))
    }
}

public struct DesktopQuotaSnapshot: Equatable, Sendable {
    public let appName: String
    public let planName: String?
    public let billingStrategy: String?
    public let cycleStart: Date?
    public let cycleEnd: Date?
    public let dailyRemainingPercent: Int?
    public let weeklyRemainingPercent: Int?
    public let dailyResetAt: Date?
    public let weeklyResetAt: Date?
    public let overageBalanceMicros: Int64?
    public let isStaleFallback: Bool
    public let fetchedAt: Date

    public init(
        appName: String,
        planName: String?,
        billingStrategy: String?,
        cycleStart: Date?,
        cycleEnd: Date?,
        dailyRemainingPercent: Int?,
        weeklyRemainingPercent: Int?,
        dailyResetAt: Date?,
        weeklyResetAt: Date?,
        overageBalanceMicros: Int64?,
        isStaleFallback: Bool = false,
        fetchedAt: Date = Date()
    ) {
        self.appName = appName
        self.planName = planName
        self.billingStrategy = billingStrategy
        self.cycleStart = cycleStart
        self.cycleEnd = cycleEnd
        self.dailyRemainingPercent = dailyRemainingPercent
        self.weeklyRemainingPercent = weeklyRemainingPercent
        self.dailyResetAt = dailyResetAt
        self.weeklyResetAt = weeklyResetAt
        self.overageBalanceMicros = overageBalanceMicros
        self.isStaleFallback = isStaleFallback
        self.fetchedAt = fetchedAt
    }

    public var dailyUsedPercent: Int? {
        if let dailyRemainingPercent {
            return max(0, min(100, 100 - dailyRemainingPercent))
        }
        return dailyResetAt == nil ? nil : 100
    }

    public var weeklyUsedPercent: Int? {
        if let weeklyRemainingPercent {
            return max(0, min(100, 100 - weeklyRemainingPercent))
        }
        return weeklyResetAt == nil ? nil : 100
    }

    public var shouldTreatQuotaUsageAsUnavailable: Bool {
        isStaleFallback && dailyRemainingPercent == 100 && weeklyRemainingPercent == 100
    }
}

public struct OpenCodeGoUsageSnapshot: Equatable, Sendable {
    public let rolling: OpenCodeGoUsageWindow?
    public let weekly: OpenCodeGoUsageWindow?
    public let monthly: OpenCodeGoUsageWindow?
    public let billing: OpenCodeGoBilling?
    public let source: String?
    public let fetchedAt: Date

    public init(
        rolling: OpenCodeGoUsageWindow?,
        weekly: OpenCodeGoUsageWindow?,
        monthly: OpenCodeGoUsageWindow?,
        billing: OpenCodeGoBilling? = nil,
        source: String? = nil,
        fetchedAt: Date = Date()
    ) {
        self.rolling = rolling
        self.weekly = weekly
        self.monthly = monthly
        self.billing = billing
        self.source = source
        self.fetchedAt = fetchedAt
    }

    public var hasUsage: Bool {
        rolling != nil || weekly != nil || monthly != nil
    }
}

public struct OpenCodeGoUsageWindow: Equatable, Sendable {
    public let usedPercent: Double
    public let resetAt: Date?

    public init(usedPercent: Double, resetAt: Date?) {
        self.usedPercent = max(0, min(100, usedPercent))
        self.resetAt = resetAt
    }
}

public struct OpenCodeGoPayment: Equatable, Sendable {
    public let id: String
    public let amountText: String
    public let date: Date?
    public let dateText: String
    public let refunded: Bool

    public init(id: String, amountText: String, date: Date?, dateText: String, refunded: Bool) {
        self.id = id
        self.amountText = amountText
        self.date = date
        self.dateText = dateText
        self.refunded = refunded
    }
}

public struct OpenCodeGoBilling: Equatable, Sendable {
    public let balanceText: String?
    public let cardLast4: String?
    public let autoReloadEnabled: Bool
    public let payments: [OpenCodeGoPayment]

    public init(balanceText: String?, cardLast4: String?, autoReloadEnabled: Bool, payments: [OpenCodeGoPayment]) {
        self.balanceText = balanceText
        self.cardLast4 = cardLast4
        self.autoReloadEnabled = autoReloadEnabled
        self.payments = payments
    }

    public var lastPayment: OpenCodeGoPayment? {
        payments.first
    }

    public var hasData: Bool {
        balanceText != nil || cardLast4 != nil || !payments.isEmpty
    }

    /// Estimates the next billing date from payment history.
    ///
    /// Computes all consecutive gaps between non-refunded payments, snaps each to
    /// the nearest common billing cycle (monthly ~30d, weekly ~7d, daily), and uses
    /// the smallest snapped gap as the billing interval. Falls back to 30 days when
    /// no gaps are available. Then advances from the last payment date into the future.
    public var nextPaymentDate: Date? {
        let validPayments = payments.filter { !$0.refunded }
        guard let last = validPayments.first, let lastDate = last.date else { return nil }

        let sortedDates = validPayments.compactMap(\.date).sorted(by: >)
        let rawGaps = zip(sortedDates, sortedDates.dropFirst())
            .map { $0.timeIntervalSince($1) }
            .filter { $0 > 0 }

        let interval: TimeInterval
        if rawGaps.isEmpty {
            interval = 30 * 86_400
        } else {
            interval = rawGaps.map { Self.snapToBillingCycle($0) }.min() ?? 30 * 86_400
        }

        var next = lastDate.addingTimeInterval(interval)
        let now = Date()
        while next < now {
            next = next.addingTimeInterval(interval)
        }
        return next
    }

    /// Snaps a raw gap to the nearest common billing cycle if it's approximately
    /// a whole multiple of that cycle (within 2 days tolerance).
    /// E.g. 61 days → 30 days (2× monthly), 14 days → 7 days (2× weekly).
    private static func snapToBillingCycle(_ raw: TimeInterval) -> TimeInterval {
        let day: TimeInterval = 86_400
        let days = raw / day

        for cycle in [30.0, 7.0, 1.0] {
            let multiple = days / cycle
            let rounded = multiple.rounded()
            if rounded >= 1 && abs(days - rounded * cycle) <= 2 {
                return cycle * day
            }
        }
        return raw
    }
}
