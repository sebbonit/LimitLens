import Foundation

public struct PaceSample: Equatable, Sendable {
    public let percentUsed: Double
    public let timestamp: Date

    public init(percentUsed: Double, timestamp: Date) {
        self.percentUsed = percentUsed
        self.timestamp = timestamp
    }
}

public struct PaceProjection: Equatable, Sendable {
    public let summaryText: String
    public let willExhaustBeforeReset: Bool
    public let projectedExhaustionDate: Date?
    public let projectedPercentAtReset: Double?

    public init(
        summaryText: String,
        willExhaustBeforeReset: Bool,
        projectedExhaustionDate: Date?,
        projectedPercentAtReset: Double?
    ) {
        self.summaryText = summaryText
        self.willExhaustBeforeReset = willExhaustBeforeReset
        self.projectedExhaustionDate = projectedExhaustionDate
        self.projectedPercentAtReset = projectedPercentAtReset
    }
}

public enum PaceEstimateConfidence: String, Equatable, Sendable {
    case collecting
    case low
    case medium
    case high
}

/// One shared pace result for every presentation of the active quota.
///
/// `percentUsedPerDay` drives the chart while `projection` drives the status
/// text, ensuring both surfaces always describe the same underlying rate.
public struct PaceEstimate: Equatable, Sendable {
    public let percentUsedPerDay: Double
    public let projection: PaceProjection?
    public let confidence: PaceEstimateConfidence

    public init(
        percentUsedPerDay: Double,
        projection: PaceProjection?,
        confidence: PaceEstimateConfidence
    ) {
        self.percentUsedPerDay = percentUsedPerDay
        self.projection = projection
        self.confidence = confidence
    }
}

public enum UsagePaceProjection {
    /// A short span is useful for drawing actual usage, but too noisy to
    /// extrapolate. Five minutes keeps refresh jitter from creating alerts.
    private static let minimumRecentElapsedSeconds: TimeInterval = 5 * 60

    /// Whole-cycle rates use at least one hour in their denominator so the
    /// first tiny usage event of a long cycle cannot imply an absurd daily rate.
    private static let minimumCycleElapsedSeconds: TimeInterval = 60 * 60

    /// A drop larger than this between consecutive samples is treated as a
    /// discontinuity (window rollover, plan change, backend recount). Samples
    /// before the drop are discarded so the slope is not corrupted.
    private static let discontinuityDropPercent: Double = 2

    /// Rates below this amount are indistinguishable from provider rounding
    /// noise. This is deliberately expressed per day; the old per-minute
    /// threshold incorrectly called normal weekly usage "stable".
    private static let stableRatePerDay: Double = 0.05

    public static func estimate(
        samples: [PaceSample],
        currentPercentUsed: Double,
        cycleStart: Date?,
        now: Date,
        resetAt: Date?
    ) -> PaceEstimate {
        let currentPercent = max(0, min(100, currentPercentUsed))
        let ordered = normalizedSamples(
            samples,
            currentPercentUsed: currentPercent,
            cycleStart: cycleStart,
            now: now,
            resetAt: resetAt
        )
        let contiguous = trimmedForDiscontinuity(ordered)
        let cycleRate = wholeCycleRate(
            currentPercentUsed: currentPercent,
            cycleStart: cycleStart,
            now: now
        )
        let recent = recentRate(
            samples: contiguous,
            cycleStart: cycleStart,
            now: now,
            resetAt: resetAt
        )

        let rate: Double
        if let recent, let cycleRate {
            // Recent behavior gains influence as its time coverage and sample
            // count improve, but keeps a 20% whole-cycle anchor to avoid a
            // single burst or idle spell swinging the forecast.
            rate = recent.rate * recent.weight + cycleRate * (1 - recent.weight)
        } else {
            rate = recent?.rate ?? cycleRate ?? 0
        }
        let finiteRate = rate.isFinite ? max(rate, 0) : 0
        let confidence = confidence(
            recent: recent,
            hasCycleRate: cycleRate != nil,
            currentPercentUsed: currentPercent
        )
        let paceProjection: PaceProjection?
        if currentPercent >= 100 {
            paceProjection = makeProjection(
                percentUsedPerDay: finiteRate,
                currentPercentUsed: currentPercent,
                now: now,
                resetAt: resetAt
            )
        } else if recent != nil || (cycleRate != nil && confidence != .collecting) {
            paceProjection = makeProjection(
                percentUsedPerDay: finiteRate,
                currentPercentUsed: currentPercent,
                now: now,
                resetAt: resetAt
            )
        } else {
            paceProjection = nil
        }

        return PaceEstimate(
            percentUsedPerDay: finiteRate,
            projection: paceProjection,
            confidence: confidence
        )
    }

    /// Compatibility entry point for callers without cycle metadata. It uses
    /// the same estimator, relying solely on the observed sample span.
    public static func project(
        samples: [PaceSample],
        now: Date,
        resetAt: Date?
    ) -> PaceProjection? {
        guard let newest = samples
            .filter({ $0.percentUsed.isFinite })
            .max(by: { $0.timestamp < $1.timestamp }) else {
            return nil
        }
        return estimate(
            samples: samples,
            currentPercentUsed: newest.percentUsed,
            cycleStart: nil,
            now: now,
            resetAt: resetAt
        ).projection
    }

    private struct RecentRate {
        let rate: Double
        let span: TimeInterval
        let sampleCount: Int
        let weight: Double
        let window: TimeInterval
    }

    private static func normalizedSamples(
        _ samples: [PaceSample],
        currentPercentUsed: Double,
        cycleStart: Date?,
        now: Date,
        resetAt: Date?
    ) -> [PaceSample] {
        let upperBound = min(now, resetAt ?? now)
        var ordered = samples
            .filter {
                guard $0.percentUsed.isFinite,
                      (0 ... 100).contains($0.percentUsed),
                      $0.timestamp <= upperBound else {
                    return false
                }
                if let cycleStart, $0.timestamp < cycleStart {
                    return false
                }
                return true
            }
            .sorted { $0.timestamp < $1.timestamp }

        let current = PaceSample(percentUsed: currentPercentUsed, timestamp: upperBound)
        if let last = ordered.last, abs(last.timestamp.timeIntervalSince(upperBound)) < 1 {
            ordered[ordered.count - 1] = current
        } else {
            ordered.append(current)
        }
        return ordered
    }

    private static func trimmedForDiscontinuity(_ samples: [PaceSample]) -> [PaceSample] {
        guard !samples.isEmpty else { return [] }
        var startIndex = 0
        for index in 1..<samples.count {
            let drop = samples[index - 1].percentUsed - samples[index].percentUsed
            if drop > discontinuityDropPercent {
                startIndex = index
            }
        }
        return Array(samples[startIndex...])
    }

    private static func wholeCycleRate(
        currentPercentUsed: Double,
        cycleStart: Date?,
        now: Date
    ) -> Double? {
        guard let cycleStart, now > cycleStart else { return nil }
        let elapsed = max(now.timeIntervalSince(cycleStart), minimumCycleElapsedSeconds)
        return currentPercentUsed / (elapsed / 86_400)
    }

    private static func recentRate(
        samples: [PaceSample],
        cycleStart: Date?,
        now: Date,
        resetAt: Date?
    ) -> RecentRate? {
        guard samples.count >= 2 else { return nil }
        let cycleDuration = resetAt.flatMap { reset -> TimeInterval? in
            guard let cycleStart, reset > cycleStart else { return nil }
            return reset.timeIntervalSince(cycleStart)
        }
        let maximumWindow: TimeInterval = 24 * 3_600
        let minimumWindow: TimeInterval = 60 * 60
        let fallbackCycleDuration: TimeInterval = 7 * 86_400
        let scaledWindow = (cycleDuration ?? fallbackCycleDuration) * 0.15
        let window = min(maximumWindow, max(minimumWindow, scaledWindow))
        let cutoff = now.addingTimeInterval(-window)
        let inWindow = samples.filter { $0.timestamp >= cutoff }
        var selected = inWindow
        if let predecessor = samples.last(where: { $0.timestamp < cutoff }) {
            selected.insert(predecessor, at: 0)
        }
        guard let first = selected.first,
              let last = selected.last,
              last.timestamp > first.timestamp else {
            return nil
        }

        let span = last.timestamp.timeIntervalSince(first.timestamp)
        guard span >= minimumRecentElapsedSeconds else { return nil }
        let delta = max(last.percentUsed - first.percentUsed, 0)
        let rate = delta / (span / 86_400)
        let coverage = min(span / window, 1)
        let density = min(Double(selected.count - 1) / 3, 1)
        let weight = min(0.8, 0.8 * sqrt(coverage) * (0.5 + 0.5 * density))
        return RecentRate(
            rate: rate,
            span: span,
            sampleCount: selected.count,
            weight: weight,
            window: window
        )
    }

    private static func confidence(
        recent: RecentRate?,
        hasCycleRate: Bool,
        currentPercentUsed: Double
    ) -> PaceEstimateConfidence {
        if currentPercentUsed >= 100 { return .high }
        guard let recent else {
            return hasCycleRate ? .low : .collecting
        }
        if recent.sampleCount >= 4, recent.span >= recent.window * 0.5 {
            return .high
        }
        if recent.sampleCount >= 3, recent.span >= 30 * 60 {
            return .medium
        }
        return .low
    }

    private static func makeProjection(
        percentUsedPerDay: Double,
        currentPercentUsed: Double,
        now: Date,
        resetAt: Date?
    ) -> PaceProjection {
        if currentPercentUsed >= 100 {
            return PaceProjection(
                summaryText: "Limit exhausted",
                willExhaustBeforeReset: true,
                projectedExhaustionDate: now,
                projectedPercentAtReset: 100
            )
        }

        if percentUsedPerDay <= stableRatePerDay {
            return PaceProjection(
                summaryText: "Usage stable",
                willExhaustBeforeReset: false,
                projectedExhaustionDate: nil,
                projectedPercentAtReset: nil
            )
        }

        let daysToExhaustion = (100 - currentPercentUsed) / percentUsedPerDay
        let exhaustionDate = now.addingTimeInterval(daysToExhaustion * 86_400)
        if let resetAt, resetAt > now {
            let daysToReset = resetAt.timeIntervalSince(now) / 86_400
            let projectedAtReset = min(
                100,
                currentPercentUsed + percentUsedPerDay * daysToReset
            )
            if projectedAtReset >= 100 {
                let timeText = UsageFormatting.timeRemainingText(date: exhaustionDate, now: now)
                return PaceProjection(
                    summaryText: "On track to exhaust in ~\(timeText)",
                    willExhaustBeforeReset: true,
                    projectedExhaustionDate: exhaustionDate,
                    projectedPercentAtReset: 100
                )
            }
            let spare = Int((100 - projectedAtReset).rounded())
            return PaceProjection(
                summaryText: "On pace to reset with ~\(spare)% to spare",
                willExhaustBeforeReset: false,
                projectedExhaustionDate: nil,
                projectedPercentAtReset: projectedAtReset
            )
        }

        let timeText = UsageFormatting.timeRemainingText(date: exhaustionDate, now: now)
        return PaceProjection(
            summaryText: "On track to exhaust in ~\(timeText)",
            willExhaustBeforeReset: true,
            projectedExhaustionDate: exhaustionDate,
            projectedPercentAtReset: nil
        )
    }
}
