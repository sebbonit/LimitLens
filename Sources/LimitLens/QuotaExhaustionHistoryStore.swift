import Foundation
import LimitLensCore

/// Abstraction for quota exhaustion history persistence so the view-model can
/// accept an injectable store in tests.
protocol QuotaExhaustionHistoryStoring: AnyObject {
    var payload: QuotaExhaustionHistoryPayload { get set }
    func save()
    func clear()
}

/// Persists quota exhaustion history to
/// `~/Library/Application Support/LimitLens/quota-exhaustion-history.json`.
///
/// The store is independent from configuration and provider enable/disable
/// state. Malformed data is preserved as `quota-exhaustion-history.invalid.json`
/// and the store recovers with an empty history.
final class QuotaExhaustionHistoryStore: QuotaExhaustionHistoryStoring {
    var payload: QuotaExhaustionHistoryPayload
    let url: URL

    init(url: URL = .defaultQuotaExhaustionHistoryURL) {
        self.url = url
        self.payload = Self.load(from: url)
    }

    /// Atomically writes the current payload to disk.
    func save() {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(payload)
            try data.write(to: url, options: .atomic)
        } catch {
            assertionFailure("Failed to save quota exhaustion history: \(error)")
        }
    }

    /// Clears all history both in-memory and on disk.
    func clear() {
        payload = .empty
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Loading

    private static func load(from url: URL) -> QuotaExhaustionHistoryPayload {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .empty
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(QuotaExhaustionHistoryPayload.self, from: data)
        } catch {
            preserveInvalidHistory(at: url)
            return .empty
        }
    }

    private static func preserveInvalidHistory(at url: URL) {
        let invalidURL = url.deletingLastPathComponent()
            .appendingPathComponent("quota-exhaustion-history.invalid.json")
        try? FileManager.default.removeItem(at: invalidURL)
        try? FileManager.default.moveItem(at: url, to: invalidURL)
    }
}

extension URL {
    static var defaultQuotaExhaustionHistoryURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: "\(NSHomeDirectory())/Library/Application Support")
        let dir = directory.appendingPathComponent("LimitLens", isDirectory: true)
        return dir.appendingPathComponent("quota-exhaustion-history.json")
    }
}
