import Foundation
import LimitLensCore
import Testing
@testable import LimitLens

@MainActor
@Suite("Quota exhaustion history store")
struct QuotaExhaustionStoreTests {
    // MARK: - Atomic round-trip persistence

    @Test("Store saves and reloads events across instances")
    func storeRoundTripPersistence() throws {
        let url = temporaryURL()
        let store = QuotaExhaustionHistoryStore(url: url)
        #expect(store.payload.events.isEmpty)

        let event = QuotaExhaustionEvent(
            provider: .codex,
            quotaKind: "Daily",
            cycleStart: Date(timeIntervalSince1970: 1_000_000),
            cycleEnd: Date(timeIntervalSince1970: 1_100_000),
            exhaustedAt: Date(timeIntervalSince1970: 1_050_000),
            durationSeconds: 50_000,
            startEstimated: false
        )
        store.payload = QuotaExhaustionHistoryPayload(events: [event])
        store.save()

        let reloaded = QuotaExhaustionHistoryStore(url: url)
        #expect(reloaded.payload.events.count == 1)
        #expect(reloaded.payload.events.first?.provider == .codex)
        #expect(reloaded.payload.events.first?.quotaKind == "Daily")
        #expect(reloaded.payload.events.first?.durationSeconds == 50_000)

        cleanup(url)
    }

    @Test("Store reloads across app launches with multiple events")
    func storeReloadMultipleEvents() throws {
        let url = temporaryURL()
        let store = QuotaExhaustionHistoryStore(url: url)

        var events: [QuotaExhaustionEvent] = []
        for i in 0..<3 {
            events.append(QuotaExhaustionEvent(
                provider: .cursor,
                quotaKind: "Billing cycle",
                cycleStart: Date(timeIntervalSince1970: TimeInterval(i * 100_000)),
                cycleEnd: Date(timeIntervalSince1970: TimeInterval(i * 100_000 + 100_000)),
                exhaustedAt: Date(timeIntervalSince1970: TimeInterval(i * 100_000 + 50_000)),
                durationSeconds: 50_000,
                startEstimated: i == 1
            ))
        }
        store.payload = QuotaExhaustionHistoryPayload(events: events)
        store.save()

        let reloaded = QuotaExhaustionHistoryStore(url: url)
        #expect(reloaded.payload.events.count == 3)
        #expect(reloaded.payload.version == QuotaExhaustionHistoryPayload.currentVersion)

        cleanup(url)
    }

    // MARK: - Corrupt file recovery

    @Test("Store recovers from corrupt file with empty history")
    func storeRecoversFromCorruptFile() throws {
        let url = temporaryURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("not valid json".utf8).write(to: url)

        let store = QuotaExhaustionHistoryStore(url: url)
        #expect(store.payload.events.isEmpty)
        #expect(store.payload.version == QuotaExhaustionHistoryPayload.currentVersion)

        // Original file should have been moved to invalid backup
        #expect(!FileManager.default.fileExists(atPath: url.path))
        let invalidURL = url.deletingLastPathComponent()
            .appendingPathComponent("quota-exhaustion-history.invalid.json")
        #expect(FileManager.default.fileExists(atPath: invalidURL.path))

        cleanup(url)
        cleanup(invalidURL)
    }

    // MARK: - Clearing

    @Test("Clear removes in-memory events and deletes file")
    func clearRemovesEventsAndFile() throws {
        let url = temporaryURL()
        let store = QuotaExhaustionHistoryStore(url: url)
        store.payload = QuotaExhaustionHistoryPayload(events: [
            QuotaExhaustionEvent(
                provider: .codex, quotaKind: "Daily",
                cycleStart: Date(), cycleEnd: Date().addingTimeInterval(3600),
                exhaustedAt: Date(), durationSeconds: 3600,
                startEstimated: false
            )
        ])
        store.save()
        #expect(FileManager.default.fileExists(atPath: url.path))

        store.clear()
        #expect(store.payload.events.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: url.path))

        cleanup(url)
    }

    @Test("Clear when no file exists does not throw")
    func clearWhenNoFileExists() {
        let url = temporaryURL()
        let store = QuotaExhaustionHistoryStore(url: url)
        store.clear()
        #expect(store.payload.events.isEmpty)
        cleanup(url)
    }

    // MARK: - Missing file

    @Test("Store initializes empty when file does not exist")
    func storeEmptyWhenNoFile() {
        let url = temporaryURL()
        let store = QuotaExhaustionHistoryStore(url: url)
        #expect(store.payload.events.isEmpty)
        cleanup(url)
    }

    // MARK: - Helpers

    private func temporaryURL() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LimitLensTests-\(UUID().uuidString)", isDirectory: true)
        return dir.appendingPathComponent("quota-exhaustion-history.json")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
