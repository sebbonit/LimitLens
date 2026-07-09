import Foundation

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
    /// Minimum elapsed seconds between samples to produce a meaningful projection.
    /// Avoids noisy projections from sub-minute refresh intervals.
    private static let minimumElapsedSeconds: TimeInterval = 30

    public static func project(
        currentPercent: Double,
        previousPercent: Double,
        previousTimestamp: Date,
        now: Date,
        resetAt: Date?
    ) -> PaceProjection? {
        let elapsed = now.timeIntervalSince(previousTimestamp)
        guard elapsed >= minimumElapsedSeconds else { return nil }

        let percentChange = currentPercent - previousPercent
        let percentPerMinute = percentChange / (elapsed / 60)

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
}
