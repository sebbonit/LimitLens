import Foundation

public enum QuotaUsageHistoryProvider: String, Codable, Equatable, Hashable, Sendable {
    case codex
    case cursor
}

public struct QuotaUsageHistorySample: Codable, Equatable, Hashable, Sendable {
    public let provider: QuotaUsageHistoryProvider
    public let observedAt: Date
    public let percentUsed: Double
    public let resetsAt: Date

    public init(
        provider: QuotaUsageHistoryProvider,
        observedAt: Date,
        percentUsed: Double,
        resetsAt: Date
    ) {
        self.provider = provider
        self.observedAt = observedAt
        self.percentUsed = percentUsed
        self.resetsAt = resetsAt
    }
}

public struct QuotaUsageHistoryPayload: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public let version: Int
    public let samples: [QuotaUsageHistorySample]

    public init(
        version: Int = QuotaUsageHistoryPayload.currentVersion,
        samples: [QuotaUsageHistorySample] = []
    ) {
        self.version = version
        self.samples = samples
    }

    public static let empty = QuotaUsageHistoryPayload()
}

public enum QuotaUsageHistoryCalculator {
    public static let retention: TimeInterval = 90 * 86_400

    public static func normalized(
        _ samples: [QuotaUsageHistorySample],
        now: Date = Date()
    ) -> [QuotaUsageHistorySample] {
        let cutoff = now.addingTimeInterval(-retention)
        return Array(Set(samples.filter {
            $0.observedAt >= cutoff
                && $0.observedAt <= $0.resetsAt
                && $0.percentUsed.isFinite
                && (0 ... 100).contains($0.percentUsed)
        }))
        .sorted {
            if $0.observedAt != $1.observedAt {
                return $0.observedAt < $1.observedAt
            }
            if $0.provider != $1.provider {
                return $0.provider.rawValue < $1.provider.rawValue
            }
            return $0.resetsAt < $1.resetsAt
        }
    }

    public static func recording(
        _ sample: QuotaUsageHistorySample,
        in samples: [QuotaUsageHistorySample],
        now: Date = Date()
    ) -> [QuotaUsageHistorySample] {
        normalized(samples + [sample], now: now)
    }

    public static func currentCycleSamples(
        provider: QuotaUsageHistoryProvider,
        resetsAt: Date,
        in samples: [QuotaUsageHistorySample]
    ) -> [QuotaUsageHistorySample] {
        samples
            .filter { $0.provider == provider && $0.resetsAt == resetsAt }
            .sorted { $0.observedAt < $1.observedAt }
    }

    /// Average percentage used per day across previously observed cycles.
    public static func historicalPercentUsedPerDay(
        provider: QuotaUsageHistoryProvider,
        excludingResetAt currentResetAt: Date,
        in samples: [QuotaUsageHistorySample]
    ) -> Double? {
        let previous = samples.filter {
            $0.provider == provider && $0.resetsAt != currentResetAt
        }
        let rates = Dictionary(grouping: previous, by: \.resetsAt).values.compactMap { cycle -> Double? in
            let ordered = cycle.sorted { $0.observedAt < $1.observedAt }
            guard let first = ordered.first,
                  let last = ordered.last,
                  last.observedAt > first.observedAt else {
                return nil
            }
            let elapsedDays = last.observedAt.timeIntervalSince(first.observedAt) / 86_400
            guard elapsedDays > 0 else { return nil }
            return max((last.percentUsed - first.percentUsed) / elapsedDays, 0)
        }
        guard !rates.isEmpty else { return nil }
        return rates.reduce(0, +) / Double(rates.count)
    }
}
