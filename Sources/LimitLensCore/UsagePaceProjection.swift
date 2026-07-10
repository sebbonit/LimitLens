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

public enum UsagePaceProjection {
    /// Minimum elapsed seconds between the oldest and newest samples to produce
    /// a meaningful projection. Avoids noisy projections from sub-minute spans.
    private static let minimumElapsedSeconds: TimeInterval = 30

    /// Maximum number of samples retained per provider. Older samples are
    /// discarded so the trend reflects recent behavior rather than the entire
    /// session.
    public static let maxSampleHistory = 6

    /// A drop larger than this between consecutive samples is treated as a
    /// discontinuity (window rollover, plan change, backend recount). Samples
    /// before the drop are discarded so the slope is not corrupted.
    private static let discontinuityDropPercent: Double = 2

    public static func project(
        samples: [PaceSample],
        now: Date,
        resetAt: Date?
    ) -> PaceProjection? {
        guard !samples.isEmpty else { return nil }

        let trimmed = trimmedForDiscontinuity(samples)
        guard trimmed.count >= 2 else { return nil }

        let oldest = trimmed.first!
        let newest = trimmed.last!
        let elapsed = newest.timestamp.timeIntervalSince(oldest.timestamp)
        guard elapsed >= minimumElapsedSeconds else { return nil }

        let percentPerMinute = slope(samples: trimmed)
        let currentPercent = newest.percentUsed

        // Limit is already exhausted — no projection needed.
        if currentPercent >= 100 {
            return PaceProjection(
                summaryText: "Limit exhausted",
                willExhaustBeforeReset: true,
                projectedExhaustionDate: now,
                projectedPercentAtReset: 100
            )
        }

        // Usage is stable or declining (e.g. after a reset window rolls over)
        if percentPerMinute <= 0.01 {
            return PaceProjection(
                summaryText: "Usage stable",
                willExhaustBeforeReset: false,
                projectedExhaustionDate: nil,
                projectedPercentAtReset: nil
            )
        }

        let minutesToExhaustion = (100 - currentPercent) / percentPerMinute
        let exhaustionDate = now.addingTimeInterval(minutesToExhaustion * 60)

        if let resetAt, resetAt > now {
            let minutesToReset = resetAt.timeIntervalSince(now) / 60
            let projectedAtReset = min(100, currentPercent + percentPerMinute * minutesToReset)

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

    /// Discards samples before any discontinuity (a drop exceeding
    /// `discontinuityDropPercent` between consecutive samples). Only the
    /// contiguous tail after the last discontinuity is used for the slope.
    private static func trimmedForDiscontinuity(_ samples: [PaceSample]) -> [PaceSample] {
        var startIndex = 0
        for index in 1..<samples.count {
            let drop = samples[index - 1].percentUsed - samples[index].percentUsed
            if drop > discontinuityDropPercent {
                startIndex = index
            }
        }
        return Array(samples[startIndex...])
    }

    /// Least-squares linear regression slope (percent per minute) over the
    /// given samples. More robust than differencing only the first and last
    /// points, since a single bursty sample has less leverage over the fit.
    private static func slope(samples: [PaceSample]) -> Double {
        guard samples.count >= 2 else { return 0 }

        let base = samples.first!.timestamp.timeIntervalSince1970
        let xs = samples.map { ($0.timestamp.timeIntervalSince1970 - base) / 60 }
        let ys = samples.map { $0.percentUsed }

        let n = Double(samples.count)
        let meanX = xs.reduce(0, +) / n
        let meanY = ys.reduce(0, +) / n

        var numerator = 0.0
        var denominator = 0.0
        for i in 0..<samples.count {
            numerator += (xs[i] - meanX) * (ys[i] - meanY)
            denominator += (xs[i] - meanX) * (xs[i] - meanX)
        }
        guard denominator > 0 else { return 0 }
        return numerator / denominator
    }
}
