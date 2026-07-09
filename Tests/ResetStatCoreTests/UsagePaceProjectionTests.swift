import Foundation
import Testing
@testable import ResetStatCore

@Suite("Usage pace projection")
struct UsagePaceProjectionTests {
    @Test("Returns nil when elapsed time is too short")
    func returnsNilForShortElapsed() {
        let now = Date()
        let result = UsagePaceProjection.project(
            currentPercent: 60,
            previousPercent: 50,
            previousTimestamp: now.addingTimeInterval(-60),
            now: now,
            resetAt: now.addingTimeInterval(3600)
        )
        #expect(result == nil)
    }

    @Test("Projects exhaustion before reset when pace is high")
    func projectsExhaustionBeforeReset() {
        let now = Date()
        // 10% increase in 10 minutes = 1%/min. 30% remaining → 30 min to exhaust.
        // Reset in 60 min → will exhaust before reset.
        let result = UsagePaceProjection.project(
            currentPercent: 70,
            previousPercent: 60,
            previousTimestamp: now.addingTimeInterval(-600),
            now: now,
            resetAt: now.addingTimeInterval(3600)
        )
        #expect(result != nil)
        #expect(result!.willExhaustBeforeReset == true)
        #expect(result!.summaryText.contains("exhaust"))
        #expect(result!.projectedPercentAtReset == 100)
    }

    @Test("Projects spare at reset when pace is low")
    func projectsSpareAtReset() {
        let now = Date()
        // 5% increase in 10 minutes = 0.5%/min. 80% remaining → 160 min to exhaust.
        // Reset in 60 min → projected at reset = 75 + 0.5*60 = 105, capped at 100...
        // Let me recalculate: current 75, prev 70, elapsed 10 min → 0.5%/min
        // 25% remaining → 50 min to exhaust. Reset in 120 min → exhausts before reset.
        // Need slower pace: current 72, prev 70, elapsed 10 min → 0.2%/min
        // 28% remaining → 140 min to exhaust. Reset in 60 min → projected = 72 + 0.2*60 = 84 → 16% spare
        let result = UsagePaceProjection.project(
            currentPercent: 72,
            previousPercent: 70,
            previousTimestamp: now.addingTimeInterval(-600),
            now: now,
            resetAt: now.addingTimeInterval(3600)
        )
        #expect(result != nil)
        #expect(result!.willExhaustBeforeReset == false)
        #expect(result!.summaryText.contains("spare"))
        #expect(result!.projectedPercentAtReset != nil)
        #expect(result!.projectedPercentAtReset! < 100)
    }

    @Test("Reports stable usage when percent does not increase")
    func reportsStableWhenNotIncreasing() {
        let now = Date()
        let result = UsagePaceProjection.project(
            currentPercent: 50,
            previousPercent: 50,
            previousTimestamp: now.addingTimeInterval(-600),
            now: now,
            resetAt: now.addingTimeInterval(3600)
        )
        #expect(result != nil)
        #expect(result!.willExhaustBeforeReset == false)
        #expect(result!.summaryText == "Usage stable")
    }

    @Test("Reports stable usage when percent decreases")
    func reportsStableWhenDecreasing() {
        let now = Date()
        let result = UsagePaceProjection.project(
            currentPercent: 40,
            previousPercent: 60,
            previousTimestamp: now.addingTimeInterval(-600),
            now: now,
            resetAt: now.addingTimeInterval(3600)
        )
        #expect(result != nil)
        #expect(result!.willExhaustBeforeReset == false)
        #expect(result!.summaryText == "Usage stable")
    }

    @Test("Projects exhaustion without reset date")
    func projectsExhaustionWithoutResetDate() {
        let now = Date()
        // 10% increase in 10 minutes = 1%/min. 20% remaining → 20 min to exhaust.
        let result = UsagePaceProjection.project(
            currentPercent: 80,
            previousPercent: 70,
            previousTimestamp: now.addingTimeInterval(-600),
            now: now,
            resetAt: nil
        )
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
        let result = UsagePaceProjection.project(
            currentPercent: 50,
            previousPercent: 48,
            previousTimestamp: now.addingTimeInterval(-600),
            now: now,
            resetAt: now.addingTimeInterval(6000)
        )
        #expect(result != nil)
        #expect(result!.willExhaustBeforeReset == false)
        #expect(result!.projectedPercentAtReset == 70)
        #expect(result!.summaryText.contains("30%"))
    }
}
