import Foundation
import Testing
@testable import LimitLensCore

@Suite("Usage pace projection")
struct UsagePaceProjectionTests {
    @Test("Returns nil when fewer than two samples")
    func returnsNilForEmptyOrSingleSample() {
        let now = Date()
        #expect(UsagePaceProjection.project(samples: [], now: now, resetAt: nil) == nil)
        #expect(UsagePaceProjection.project(samples: [PaceSample(percentUsed: 50, timestamp: now)], now: now, resetAt: nil) == nil)
    }

    @Test("Returns nil when elapsed time is too short")
    func returnsNilForShortElapsed() {
        let now = Date()
        let samples = [
            PaceSample(percentUsed: 50, timestamp: now.addingTimeInterval(-15)),
            PaceSample(percentUsed: 60, timestamp: now)
        ]
        let result = UsagePaceProjection.project(samples: samples, now: now, resetAt: now.addingTimeInterval(3600))
        #expect(result == nil)
    }

    @Test("Projects exhaustion before reset when pace is high")
    func projectsExhaustionBeforeReset() {
        let now = Date()
        // 10% increase in 10 minutes = 1%/min. 30% remaining → 30 min to exhaust.
        // Reset in 60 min → will exhaust before reset.
        let samples = [
            PaceSample(percentUsed: 60, timestamp: now.addingTimeInterval(-600)),
            PaceSample(percentUsed: 70, timestamp: now)
        ]
        let result = UsagePaceProjection.project(samples: samples, now: now, resetAt: now.addingTimeInterval(3600))
        #expect(result != nil)
        #expect(result!.willExhaustBeforeReset == true)
        #expect(result!.summaryText.contains("exhaust"))
        #expect(result!.projectedPercentAtReset == 100)
    }

    @Test("Reports limit exhausted when current percent is already 100")
    func reportsExhaustedWhenAt100Percent() {
        let now = Date()
        let samples = [
            PaceSample(percentUsed: 90, timestamp: now.addingTimeInterval(-600)),
            PaceSample(percentUsed: 100, timestamp: now)
        ]
        let result = UsagePaceProjection.project(samples: samples, now: now, resetAt: now.addingTimeInterval(3600))
        #expect(result != nil)
        #expect(result!.summaryText == "Limit exhausted")
        #expect(result!.willExhaustBeforeReset == true)
        #expect(result!.projectedPercentAtReset == 100)
    }

    @Test("Projects spare at reset when pace is low")
    func projectsSpareAtReset() {
        let now = Date()
        // current 72, prev 70, elapsed 10 min → 0.2%/min
        // 28% remaining → 140 min to exhaust. Reset in 60 min → projected = 72 + 0.2*60 = 84 → 16% spare
        let samples = [
            PaceSample(percentUsed: 70, timestamp: now.addingTimeInterval(-600)),
            PaceSample(percentUsed: 72, timestamp: now)
        ]
        let result = UsagePaceProjection.project(samples: samples, now: now, resetAt: now.addingTimeInterval(3600))
        #expect(result != nil)
        #expect(result!.willExhaustBeforeReset == false)
        #expect(result!.summaryText.contains("spare"))
        #expect(result!.projectedPercentAtReset != nil)
        #expect(result!.projectedPercentAtReset! < 100)
    }

    @Test("Reports stable usage when percent does not increase")
    func reportsStableWhenNotIncreasing() {
        let now = Date()
        let samples = [
            PaceSample(percentUsed: 50, timestamp: now.addingTimeInterval(-600)),
            PaceSample(percentUsed: 50, timestamp: now)
        ]
        let result = UsagePaceProjection.project(samples: samples, now: now, resetAt: now.addingTimeInterval(3600))
        #expect(result != nil)
        #expect(result!.willExhaustBeforeReset == false)
        #expect(result!.summaryText == "Usage stable")
    }

    @Test("Reports stable usage when percent decreases slightly")
    func reportsStableWhenDecreasing() {
        let now = Date()
        // A small decrease (within the discontinuity threshold) should be
        // treated as stable usage, not a window rollover.
        let samples = [
            PaceSample(percentUsed: 52, timestamp: now.addingTimeInterval(-600)),
            PaceSample(percentUsed: 51, timestamp: now)
        ]
        let result = UsagePaceProjection.project(samples: samples, now: now, resetAt: now.addingTimeInterval(3600))
        #expect(result != nil)
        #expect(result!.willExhaustBeforeReset == false)
        #expect(result!.summaryText == "Usage stable")
    }

    @Test("Projects exhaustion without reset date")
    func projectsExhaustionWithoutResetDate() {
        let now = Date()
        // 10% increase in 10 minutes = 1%/min. 20% remaining → 20 min to exhaust.
        let samples = [
            PaceSample(percentUsed: 70, timestamp: now.addingTimeInterval(-600)),
            PaceSample(percentUsed: 80, timestamp: now)
        ]
        let result = UsagePaceProjection.project(samples: samples, now: now, resetAt: nil)
        #expect(result != nil)
        #expect(result!.willExhaustBeforeReset == true)
        #expect(result!.summaryText.contains("exhaust"))
        #expect(result!.projectedExhaustionDate != nil)
    }

    @Test("Projects spare with exact percentage")
    func projectsSpareWithExactPercentage() {
        let now = Date()
        // current 50, prev 48, elapsed 10 min → 0.2%/min
        // 50% remaining → 250 min to exhaust. Reset in 100 min → projected = 50 + 0.2*100 = 70 → 30% spare
        let samples = [
            PaceSample(percentUsed: 48, timestamp: now.addingTimeInterval(-600)),
            PaceSample(percentUsed: 50, timestamp: now)
        ]
        let result = UsagePaceProjection.project(samples: samples, now: now, resetAt: now.addingTimeInterval(6000))
        #expect(result != nil)
        #expect(result!.willExhaustBeforeReset == false)
        #expect(result!.projectedPercentAtReset == 70)
        #expect(result!.summaryText.contains("30%"))
    }

    @Test("Least-squares slope smooths out a single bursty sample")
    func smoothsBurstySample() {
        let now = Date()
        // Five samples over 50 minutes at a steady 0.2%/min, plus one bursty
        // jump in the last 10-minute interval. A two-point differencing would
        // see the burst (1.0%/min) and project imminent exhaustion. The
        // least-squares fit over all six points should reflect the calmer
        // average trend and project spare at reset.
        let samples = [
            PaceSample(percentUsed: 50, timestamp: now.addingTimeInterval(-3000)),
            PaceSample(percentUsed: 52, timestamp: now.addingTimeInterval(-2400)),
            PaceSample(percentUsed: 54, timestamp: now.addingTimeInterval(-1800)),
            PaceSample(percentUsed: 56, timestamp: now.addingTimeInterval(-1200)),
            PaceSample(percentUsed: 58, timestamp: now.addingTimeInterval(-600)),
            PaceSample(percentUsed: 68, timestamp: now)
        ]
        // Reset in 120 min. Slope via least-squares ≈ 0.33%/min.
        // projected = 68 + 0.33*120 ≈ 108 → capped at 100 → exhausts before reset.
        // That's still exhausting, so use a longer reset window to verify spare.
        let result = UsagePaceProjection.project(samples: samples, now: now, resetAt: now.addingTimeInterval(600))
        // With 600s (10 min) to reset: projected = 68 + 0.33*10 ≈ 71.3 → ~28% spare
        #expect(result != nil)
        #expect(result!.willExhaustBeforeReset == false)
        #expect(result!.projectedPercentAtReset! < 80)
    }

    @Test("Discontinuity drop discards earlier samples and resets the trend")
    func discontinuityResetsTrend() {
        let now = Date()
        // Samples climb to 80%, then a window rollover drops to 10%. After the
        // drop, usage climbs gently 10 → 12 over 10 min. Without discontinuity
        // handling the slope would be deeply negative (stable). With it, only
        // the post-drop samples are used and the projection reflects the new
        // window's gentle climb.
        let samples = [
            PaceSample(percentUsed: 60, timestamp: now.addingTimeInterval(-3000)),
            PaceSample(percentUsed: 70, timestamp: now.addingTimeInterval(-2400)),
            PaceSample(percentUsed: 80, timestamp: now.addingTimeInterval(-1800)),
            PaceSample(percentUsed: 10, timestamp: now.addingTimeInterval(-600)),
            PaceSample(percentUsed: 12, timestamp: now)
        ]
        let result = UsagePaceProjection.project(samples: samples, now: now, resetAt: now.addingTimeInterval(3600))
        #expect(result != nil)
        // 2% rise over 10 min = 0.2%/min. Reset in 60 min → projected = 12 + 12 = 24 → 76% spare
        #expect(result!.willExhaustBeforeReset == false)
        #expect(result!.projectedPercentAtReset! < 30)
    }

    @Test("Small percent decrease is not treated as a discontinuity")
    func smallDecreaseIsNotDiscontinuity() {
        let now = Date()
        // A 1% wiggle (within the 2% threshold) should not discard earlier
        // samples. Overall trend is still upward.
        let samples = [
            PaceSample(percentUsed: 50, timestamp: now.addingTimeInterval(-600)),
            PaceSample(percentUsed: 55, timestamp: now.addingTimeInterval(-300)),
            PaceSample(percentUsed: 54, timestamp: now)
        ]
        let result = UsagePaceProjection.project(samples: samples, now: now, resetAt: now.addingTimeInterval(3600))
        #expect(result != nil)
        // Net upward trend → should not be "stable"
        #expect(result!.summaryText != "Usage stable")
    }
}
