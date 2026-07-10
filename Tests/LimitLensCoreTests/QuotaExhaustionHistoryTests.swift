import Foundation
import LimitLensCore
import Testing

@Suite("Quota exhaustion history")
struct QuotaExhaustionHistoryTests {
    // MARK: - Cycle start derivation

    @Test("Cycle start derived from reset time minus window duration")
    func cycleStartFromResetAndDuration() {
        let resetAt = Date(timeIntervalSince1970: 1_000_000)
        let start = ExhaustionSpeedCalculator.cycleStart(
            resetAt: resetAt,
            windowDurationSeconds: 3600
        )
        #expect(start == Date(timeIntervalSince1970: 996_400))
    }

    @Test("Cursor cycle start uses billing cycle start when available")
    func cursorCycleStartFromReportedStart() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let end = Date(timeIntervalSince1970: 1_100_000)
        let result = ExhaustionSpeedCalculator.cursorCycleStart(
            billingCycleStart: start,
            billingCycleEnd: end
        )
        #expect(result?.start == start)
        #expect(result?.estimated == false)
    }

    @Test("Cursor cycle start falls back to one calendar month before end date")
    func cursorCycleStartFallbackOneMonth() {
        let end = Date(timeIntervalSince1970: 1_000_000)
        let result = ExhaustionSpeedCalculator.cursorCycleStart(
            billingCycleStart: nil,
            billingCycleEnd: end
        )
        let expected = Calendar.current.date(byAdding: .month, value: -1, to: end)
        #expect(result?.start == expected)
        #expect(result?.estimated == true)
    }

    @Test("Cursor cycle start returns nil when both dates are missing")
    func cursorCycleStartNilWhenNoDates() {
        let result = ExhaustionSpeedCalculator.cursorCycleStart(
            billingCycleStart: nil,
            billingCycleEnd: nil
        )
        #expect(result == nil)
    }

    // MARK: - Exhaustion detection

    @Test("Exact 90 percent is detected as exhausted")
    func exact90PercentIsExhausted() {
        #expect(ExhaustionSpeedCalculator.isExhausted(percentUsed: 90))
    }

    @Test("Above 90 percent is detected as exhausted")
    func above90PercentIsExhausted() {
        #expect(ExhaustionSpeedCalculator.isExhausted(percentUsed: 100))
        #expect(ExhaustionSpeedCalculator.isExhausted(percentUsed: 105))
    }

    @Test("Below 90 percent is not exhausted")
    func below90PercentIsNotExhausted() {
        #expect(!ExhaustionSpeedCalculator.isExhausted(percentUsed: 89))
    }

    @Test("Nil percent is not exhausted")
    func nilPercentIsNotExhausted() {
        #expect(!ExhaustionSpeedCalculator.isExhausted(percentUsed: nil))
    }

    // MARK: - Event creation

    @Test("makeEvent creates event for exhausted quota with valid dates")
    func makeEventForExhaustedQuota() {
        let cycleStart = Date(timeIntervalSince1970: 1_000_000)
        let cycleEnd = Date(timeIntervalSince1970: 1_100_000)
        let exhaustedAt = Date(timeIntervalSince1970: 1_050_000)
        let event = ExhaustionSpeedCalculator.makeEvent(
            provider: .codex,
            quotaKind: "Daily",
            percentUsed: 100,
            cycleStart: cycleStart,
            cycleEnd: cycleEnd,
            exhaustedAt: exhaustedAt
        )
        #expect(event != nil)
        #expect(event?.provider == .codex)
        #expect(event?.quotaKind == "Daily")
        #expect(event?.durationSeconds == 50_000)
        #expect(event?.startEstimated == false)
    }

    @Test("makeEvent creates event at 90 percent threshold")
    func makeEventAt90PercentThreshold() {
        let event = ExhaustionSpeedCalculator.makeEvent(
            provider: .codex,
            quotaKind: "Daily",
            percentUsed: 90,
            cycleStart: Date(timeIntervalSince1970: 1_000_000),
            cycleEnd: Date(timeIntervalSince1970: 1_100_000),
            exhaustedAt: Date(timeIntervalSince1970: 1_050_000)
        )
        #expect(event != nil)
    }

    @Test("makeEvent returns nil for non-exhausted quota")
    func makeEventReturnsNilForNonExhausted() {
        let event = ExhaustionSpeedCalculator.makeEvent(
            provider: .codex,
            quotaKind: "Daily",
            percentUsed: 89,
            cycleStart: Date(),
            cycleEnd: Date().addingTimeInterval(3600),
            exhaustedAt: Date()
        )
        #expect(event == nil)
    }

    @Test("makeEvent returns nil for invalid dates")
    func makeEventReturnsNilForInvalidDates() {
        let event = ExhaustionSpeedCalculator.makeEvent(
            provider: .codex,
            quotaKind: "Daily",
            percentUsed: 100,
            cycleStart: nil,
            cycleEnd: Date(),
            exhaustedAt: Date()
        )
        #expect(event == nil)
    }

    @Test("makeEvent returns nil when cycle end is before cycle start")
    func makeEventReturnsNilWhenEndBeforeStart() {
        let event = ExhaustionSpeedCalculator.makeEvent(
            provider: .codex,
            quotaKind: "Daily",
            percentUsed: 100,
            cycleStart: Date(timeIntervalSince1970: 1_100_000),
            cycleEnd: Date(timeIntervalSince1970: 1_000_000),
            exhaustedAt: Date()
        )
        #expect(event == nil)
    }

    @Test("makeEvent records startEstimated flag")
    func makeEventRecordsStartEstimated() {
        let event = ExhaustionSpeedCalculator.makeEvent(
            provider: .cursor,
            quotaKind: "Billing cycle",
            percentUsed: 100,
            cycleStart: Date(timeIntervalSince1970: 1_000_000),
            cycleEnd: Date(timeIntervalSince1970: 1_100_000),
            exhaustedAt: Date(timeIntervalSince1970: 1_050_000),
            startEstimated: true
        )
        #expect(event?.startEstimated == true)
    }

    // MARK: - Duplicate detection

    @Test("Duplicate refresh for same cycle does not create new event")
    func duplicateRefreshDoesNotCreateEvent() {
        let cycleEnd = Date(timeIntervalSince1970: 1_100_000)
        let event = QuotaExhaustionEvent(
            provider: .codex,
            quotaKind: "Daily",
            cycleStart: Date(timeIntervalSince1970: 1_000_000),
            cycleEnd: cycleEnd,
            exhaustedAt: Date(timeIntervalSince1970: 1_050_000),
            durationSeconds: 50_000,
            startEstimated: false
        )
        let identity = event.cycleIdentity
        let events = [event]
        #expect(ExhaustionSpeedCalculator.hasCycleAlreadyBeenRecorded(events, identity: identity))
    }

    @Test("New cycle with different reset time creates new event")
    func newCycleCreatesNewEvent() {
        let cycleEnd1 = Date(timeIntervalSince1970: 1_100_000)
        let event1 = QuotaExhaustionEvent(
            provider: .codex,
            quotaKind: "Daily",
            cycleStart: Date(timeIntervalSince1970: 1_000_000),
            cycleEnd: cycleEnd1,
            exhaustedAt: Date(timeIntervalSince1970: 1_050_000),
            durationSeconds: 50_000,
            startEstimated: false
        )
        let identity2 = QuotaExhaustionCycleIdentity(
            provider: .codex,
            quotaKind: "Daily",
            cycleEnd: Date(timeIntervalSince1970: 1_200_000)
        )
        let events = [event1]
        #expect(!ExhaustionSpeedCalculator.hasCycleAlreadyBeenRecorded(events, identity: identity2))
    }

    @Test("record adds new event and ignores duplicates")
    func recordAddsNewIgnoresDuplicates() {
        let cycleEnd = Date(timeIntervalSince1970: 1_100_000)
        let event = QuotaExhaustionEvent(
            provider: .codex,
            quotaKind: "Daily",
            cycleStart: Date(timeIntervalSince1970: 1_000_000),
            cycleEnd: cycleEnd,
            exhaustedAt: Date(timeIntervalSince1970: 1_050_000),
            durationSeconds: 50_000,
            startEstimated: false
        )
        let events = [event]
        let result = ExhaustionSpeedCalculator.record(newEvent: event, into: events)
        #expect(result.count == 1)
    }

    // MARK: - Quota kind separation

    @Test("Events with different quota kinds are tracked separately")
    func quotaKindSeparation() {
        let events = [
            QuotaExhaustionEvent(
                provider: .devin,
                quotaKind: "Daily",
                cycleStart: Date(timeIntervalSince1970: 1_000_000),
                cycleEnd: Date(timeIntervalSince1970: 1_100_000),
                exhaustedAt: Date(timeIntervalSince1970: 1_050_000),
                durationSeconds: 50_000,
                startEstimated: false
            ),
            QuotaExhaustionEvent(
                provider: .devin,
                quotaKind: "Weekly",
                cycleStart: Date(timeIntervalSince1970: 1_000_000),
                cycleEnd: Date(timeIntervalSince1970: 1_700_000),
                exhaustedAt: Date(timeIntervalSince1970: 1_500_000),
                durationSeconds: 500_000,
                startEstimated: false
            )
        ]
        let daily = ExhaustionSpeedCalculator.events(for: .devin, quotaKind: "Daily", in: events)
        let weekly = ExhaustionSpeedCalculator.events(for: .devin, quotaKind: "Weekly", in: events)
        #expect(daily.count == 1)
        #expect(weekly.count == 1)
        #expect(daily.first?.durationSeconds == 50_000)
        #expect(weekly.first?.durationSeconds == 500_000)
    }

    // MARK: - Ten-event retention

    @Test("Only latest 10 events per quota kind are retained")
    func tenEventRetention() {
        var events: [QuotaExhaustionEvent] = []
        for i in 0..<15 {
            let event = QuotaExhaustionEvent(
                provider: .codex,
                quotaKind: "Daily",
                cycleStart: Date(timeIntervalSince1970: TimeInterval(i * 100_000)),
                cycleEnd: Date(timeIntervalSince1970: TimeInterval(i * 100_000 + 100_000)),
                exhaustedAt: Date(timeIntervalSince1970: TimeInterval(i * 100_000 + 50_000)),
                durationSeconds: 50_000,
                startEstimated: false
            )
            events = ExhaustionSpeedCalculator.record(newEvent: event, into: events)
        }
        #expect(events.count == 10)
        let sorted = events.sorted(by: { $0.exhaustedAt < $1.exhaustedAt })
        #expect(sorted.first?.exhaustedAt == Date(timeIntervalSince1970: 550_000))
        #expect(sorted.last?.exhaustedAt == Date(timeIntervalSince1970: 1_450_000))
    }

    @Test("Retention is per quota kind, not global")
    func retentionIsPerQuotaKind() {
        var events: [QuotaExhaustionEvent] = []
        for i in 0..<12 {
            let event = QuotaExhaustionEvent(
                provider: .devin,
                quotaKind: "Daily",
                cycleStart: Date(timeIntervalSince1970: TimeInterval(i * 100_000)),
                cycleEnd: Date(timeIntervalSince1970: TimeInterval(i * 100_000 + 100_000)),
                exhaustedAt: Date(timeIntervalSince1970: TimeInterval(i * 100_000 + 50_000)),
                durationSeconds: 50_000,
                startEstimated: false
            )
            events = ExhaustionSpeedCalculator.record(newEvent: event, into: events)
        }
        for i in 0..<12 {
            let event = QuotaExhaustionEvent(
                provider: .devin,
                quotaKind: "Weekly",
                cycleStart: Date(timeIntervalSince1970: TimeInterval(i * 100_000)),
                cycleEnd: Date(timeIntervalSince1970: TimeInterval(i * 100_000 + 100_000)),
                exhaustedAt: Date(timeIntervalSince1970: TimeInterval(i * 100_000 + 50_000)),
                durationSeconds: 50_000,
                startEstimated: false
            )
            events = ExhaustionSpeedCalculator.record(newEvent: event, into: events)
        }
        let daily = ExhaustionSpeedCalculator.events(for: .devin, quotaKind: "Daily", in: events)
        let weekly = ExhaustionSpeedCalculator.events(for: .devin, quotaKind: "Weekly", in: events)
        #expect(daily.count == 10)
        #expect(weekly.count == 10)
    }

    // MARK: - Average calculation

    @Test("Average duration is computed correctly")
    func averageDurationCalculation() {
        let events = [
            QuotaExhaustionEvent(
                provider: .codex, quotaKind: "Daily",
                cycleStart: Date(timeIntervalSince1970: 0),
                cycleEnd: Date(timeIntervalSince1970: 100_000),
                exhaustedAt: Date(timeIntervalSince1970: 50_000),
                durationSeconds: 50_000,
                startEstimated: false
            ),
            QuotaExhaustionEvent(
                provider: .codex, quotaKind: "Daily",
                cycleStart: Date(timeIntervalSince1970: 0),
                cycleEnd: Date(timeIntervalSince1970: 100_000),
                exhaustedAt: Date(timeIntervalSince1970: 70_000),
                durationSeconds: 70_000,
                startEstimated: false
            )
        ]
        let avg = ExhaustionSpeedCalculator.averageDuration(of: events)
        #expect(avg == 60_000)
    }

    @Test("Average of empty events returns nil")
    func averageOfEmptyEventsReturnsNil() {
        #expect(ExhaustionSpeedCalculator.averageDuration(of: []) == nil)
    }

    @Test("anyStartEstimated detects estimated starts")
    func anyStartEstimatedDetection() {
        let nonEstimated = [
            QuotaExhaustionEvent(
                provider: .cursor, quotaKind: "Billing cycle",
                cycleStart: Date(), cycleEnd: Date().addingTimeInterval(3600),
                exhaustedAt: Date(), durationSeconds: 3600,
                startEstimated: false
            )
        ]
        #expect(!ExhaustionSpeedCalculator.anyStartEstimated(in: nonEstimated))

        let withEstimated = nonEstimated + [
            QuotaExhaustionEvent(
                provider: .cursor, quotaKind: "Billing cycle",
                cycleStart: Date(), cycleEnd: Date().addingTimeInterval(3600),
                exhaustedAt: Date(), durationSeconds: 3600,
                startEstimated: true
            )
        ]
        #expect(ExhaustionSpeedCalculator.anyStartEstimated(in: withEstimated))
    }

    // MARK: - Duration formatting

    @Test("Duration formatting produces compact strings")
    func durationFormatting() {
        #expect(UsageFormatting.durationText(seconds: 0) == "0m")
        #expect(UsageFormatting.durationText(seconds: 30) == "<1m")
        #expect(UsageFormatting.durationText(seconds: 60) == "1m")
        #expect(UsageFormatting.durationText(seconds: 120) == "2m")
        #expect(UsageFormatting.durationText(seconds: 3600) == "1h")
        #expect(UsageFormatting.durationText(seconds: 12_000) == "3h 20m")
        #expect(UsageFormatting.durationText(seconds: 86_400) == "1d")
        #expect(UsageFormatting.durationText(seconds: 187_200) == "2d 4h")
    }

    @Test("Average duration text prefixes ~ when estimated")
    func averageDurationTextEstimatedPrefix() {
        #expect(UsageFormatting.averageDurationText(seconds: 12_000, anyEstimated: false) == "3h 20m")
        #expect(UsageFormatting.averageDurationText(seconds: 12_000, anyEstimated: true) == "~3h 20m")
    }

    // MARK: - Payload

    @Test("Empty payload has current version and no events")
    func emptyPayload() {
        let payload = QuotaExhaustionHistoryPayload.empty
        #expect(payload.version == QuotaExhaustionHistoryPayload.currentVersion)
        #expect(payload.events.isEmpty)
    }

    @Test("Payload round-trips through Codable")
    func payloadCodableRoundTrip() throws {
        let event = QuotaExhaustionEvent(
            provider: .codex,
            quotaKind: "Daily",
            cycleStart: Date(timeIntervalSince1970: 1_000_000),
            cycleEnd: Date(timeIntervalSince1970: 1_100_000),
            exhaustedAt: Date(timeIntervalSince1970: 1_050_000),
            durationSeconds: 50_000,
            startEstimated: false
        )
        let payload = QuotaExhaustionHistoryPayload(events: [event])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(QuotaExhaustionHistoryPayload.self, from: data)
        #expect(decoded == payload)
    }
}
