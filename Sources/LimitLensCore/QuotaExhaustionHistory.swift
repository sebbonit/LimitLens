import Foundation

/// Identifies which provider an exhaustion event belongs to.
public enum QuotaExhaustionProvider: String, Codable, Equatable, Sendable, CaseIterable {
    case codex
    case cursor
    case devin
    case openCodeGo
}

/// A single recorded quota exhaustion cycle.
///
/// Represents one observed cycle where a provider's overview-priority quota
/// reached 100% usage. Cycles are identified by the combination of provider,
/// quota kind, and cycle end (reset) timestamp.
public struct QuotaExhaustionEvent: Codable, Equatable, Sendable {
    public let provider: QuotaExhaustionProvider
    public let quotaKind: String
    public let cycleStart: Date
    public let cycleEnd: Date
    public let exhaustedAt: Date
    public let durationSeconds: TimeInterval
    public let startEstimated: Bool

    public init(
        provider: QuotaExhaustionProvider,
        quotaKind: String,
        cycleStart: Date,
        cycleEnd: Date,
        exhaustedAt: Date,
        durationSeconds: TimeInterval,
        startEstimated: Bool
    ) {
        self.provider = provider
        self.quotaKind = quotaKind
        self.cycleStart = cycleStart
        self.cycleEnd = cycleEnd
        self.exhaustedAt = exhaustedAt
        self.durationSeconds = durationSeconds
        self.startEstimated = startEstimated
    }

    /// Stable identity used to detect duplicate observations of the same cycle.
    public var cycleIdentity: QuotaExhaustionCycleIdentity {
        QuotaExhaustionCycleIdentity(provider: provider, quotaKind: quotaKind, cycleEnd: cycleEnd)
    }
}

/// Uniquely identifies a single quota cycle.
public struct QuotaExhaustionCycleIdentity: Equatable, Hashable, Sendable {
    public let provider: QuotaExhaustionProvider
    public let quotaKind: String
    public let cycleEnd: Date

    public init(provider: QuotaExhaustionProvider, quotaKind: String, cycleEnd: Date) {
        self.provider = provider
        self.quotaKind = quotaKind
        self.cycleEnd = cycleEnd
    }
}

/// Versioned payload persisted to disk.
public struct QuotaExhaustionHistoryPayload: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public let version: Int
    public let events: [QuotaExhaustionEvent]

    public init(version: Int = QuotaExhaustionHistoryPayload.currentVersion, events: [QuotaExhaustionEvent] = []) {
        self.version = version
        self.events = events
    }

    public static let empty = QuotaExhaustionHistoryPayload()
}

/// Core logic for deriving cycle starts, detecting exhaustion, and averaging.
public enum ExhaustionSpeedCalculator {
    /// Maximum number of exhaustion events retained per provider/quota kind.
    public static let maxEventsPerQuota = 10

    /// Threshold at which a quota is considered near-exhausted and worth
    /// recording. Using 90% instead of exactly 100% avoids missing cycles
    /// that never report a perfect 100% due to refresh-interval granularity.
    public static let exhaustionThreshold: Double = 90

    // MARK: - Cycle start derivation

    /// Derives the cycle start for Codex, Devin, and OpenCode Go by subtracting
    /// the window duration from the reset time.
    public static func cycleStart(resetAt: Date, windowDurationSeconds: TimeInterval) -> Date {
        resetAt.addingTimeInterval(-windowDurationSeconds)
    }

    /// Derives the Cursor cycle start from the reported billing-cycle start if
    /// available, otherwise subtracts one calendar month from the end date and
    /// marks the result as estimated.
    public static func cursorCycleStart(
        billingCycleStart: Date?,
        billingCycleEnd: Date?,
        calendar: Calendar = .current
    ) -> (start: Date, estimated: Bool)? {
        if let billingCycleStart {
            return (billingCycleStart, false)
        }
        guard let billingCycleEnd,
              let start = calendar.date(byAdding: .month, value: -1, to: billingCycleEnd) else {
            return nil
        }
        return (start, true)
    }

    // MARK: - Exhaustion detection

    /// Returns true when the given percentage indicates the quota is
    /// near-exhausted (at or above the configured threshold).
    public static func isExhausted(percentUsed: Double?) -> Bool {
        guard let percentUsed else { return false }
        return percentUsed >= exhaustionThreshold
    }

    // MARK: - Event creation

    /// Creates an exhaustion event if the provided data represents a valid
    /// near-exhausted cycle. Returns nil if the percentage is below the
    /// threshold, dates are invalid, or the duration is non-positive.
    public static func makeEvent(
        provider: QuotaExhaustionProvider,
        quotaKind: String,
        percentUsed: Double?,
        cycleStart: Date?,
        cycleEnd: Date?,
        exhaustedAt: Date,
        startEstimated: Bool = false
    ) -> QuotaExhaustionEvent? {
        guard isExhausted(percentUsed: percentUsed) else { return nil }
        guard let cycleStart, let cycleEnd else { return nil }
        guard cycleEnd > cycleStart else { return nil }
        let duration = exhaustedAt.timeIntervalSince(cycleStart)
        guard duration > 0 else { return nil }
        return QuotaExhaustionEvent(
            provider: provider,
            quotaKind: quotaKind,
            cycleStart: cycleStart,
            cycleEnd: cycleEnd,
            exhaustedAt: exhaustedAt,
            durationSeconds: duration,
            startEstimated: startEstimated
        )
    }

    // MARK: - History management

    /// Returns true if an event for the same cycle identity already exists.
    public static func hasCycleAlreadyBeenRecorded(
        _ events: [QuotaExhaustionEvent],
        identity: QuotaExhaustionCycleIdentity
    ) -> Bool {
        events.contains { $0.cycleIdentity == identity }
    }

    /// Adds a new event (if not a duplicate) and trims to the latest
    /// `maxEventsPerQuota` per provider/quota kind.
    public static func record(
        newEvent: QuotaExhaustionEvent,
        into events: [QuotaExhaustionEvent]
    ) -> [QuotaExhaustionEvent] {
        guard !hasCycleAlreadyBeenRecorded(events, identity: newEvent.cycleIdentity) else {
            return events
        }
        var updated = events
        updated.append(newEvent)
        return trimToLatestPerQuota(updated)
    }

    /// Keeps only the latest `maxEventsPerQuota` events per provider/quota kind,
    /// sorted by exhaustion timestamp (newest last).
    public static func trimToLatestPerQuota(_ events: [QuotaExhaustionEvent]) -> [QuotaExhaustionEvent] {
        var groups: [QuotaExhaustionCycleIdentity.IdentityKey: [QuotaExhaustionEvent]] = [:]
        for event in events {
            let key = QuotaExhaustionCycleIdentity.IdentityKey(
                provider: event.provider,
                quotaKind: event.quotaKind
            )
            groups[key, default: []].append(event)
        }
        var result: [QuotaExhaustionEvent] = []
        for (_, group) in groups {
            let sorted = group.sorted(by: { $0.exhaustedAt < $1.exhaustedAt })
            result.append(contentsOf: sorted.suffix(maxEventsPerQuota))
        }
        return result
    }

    // MARK: - Averaging

    /// Returns the events for a specific provider/quota kind, sorted oldest-first.
    public static func events(
        for provider: QuotaExhaustionProvider,
        quotaKind: String,
        in events: [QuotaExhaustionEvent]
    ) -> [QuotaExhaustionEvent] {
        events
            .filter { $0.provider == provider && $0.quotaKind == quotaKind }
            .sorted(by: { $0.exhaustedAt < $1.exhaustedAt })
    }

    /// Computes the average duration of the given events.
    /// Returns nil if the list is empty.
    public static func averageDuration(of events: [QuotaExhaustionEvent]) -> TimeInterval? {
        guard !events.isEmpty else { return nil }
        let total = events.reduce(0.0) { $0 + $1.durationSeconds }
        return total / Double(events.count)
    }

    /// Returns true if any of the given events used an estimated cycle start.
    public static func anyStartEstimated(in events: [QuotaExhaustionEvent]) -> Bool {
        events.contains { $0.startEstimated }
    }
}

extension QuotaExhaustionCycleIdentity {
    /// Internal key used for grouping events by provider + quota kind (ignoring
    /// the specific cycle end).
    public struct IdentityKey: Hashable, Sendable {
        public let provider: QuotaExhaustionProvider
        public let quotaKind: String
    }

    public var identityKey: IdentityKey {
        IdentityKey(provider: provider, quotaKind: quotaKind)
    }
}

// MARK: - Duration formatting

public extension UsageFormatting {
    /// Formats a duration in seconds as a compact string like "3h 20m" or "2d 4h".
    /// Durations under 1 minute display as "<1m".
    static func durationText(seconds: TimeInterval) -> String {
        guard seconds > 0 else { return "0m" }
        let totalMinutes = Int(seconds / 60)
        let days = totalMinutes / (60 * 24)
        let hours = (totalMinutes % (60 * 24)) / 60
        let minutes = totalMinutes % 60

        if days > 0 {
            return hours > 0 ? "\(days)d \(hours)h" : "\(days)d"
        }
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        return totalMinutes > 0 ? "\(totalMinutes)m" : "<1m"
    }

    /// Formats an average duration, prefixing with "~" when any contributing
    /// event used an estimated cycle start.
    static func averageDurationText(
        seconds: TimeInterval,
        anyEstimated: Bool
    ) -> String {
        let text = durationText(seconds: seconds)
        return anyEstimated ? "~\(text)" : text
    }
}
