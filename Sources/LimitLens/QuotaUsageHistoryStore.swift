import Foundation
import LimitLensCore

protocol QuotaUsageHistoryStoring: AnyObject {
    var payload: QuotaUsageHistoryPayload { get set }
    func record(_ sample: QuotaUsageHistorySample, now: Date)
}

final class QuotaUsageHistoryStore: QuotaUsageHistoryStoring {
    var payload: QuotaUsageHistoryPayload
    let url: URL

    init(url: URL = .defaultQuotaUsageHistoryURL) {
        self.url = url
        self.payload = Self.load(from: url)
    }

    func record(_ sample: QuotaUsageHistorySample, now: Date = Date()) {
        payload = QuotaUsageHistoryPayload(
            samples: QuotaUsageHistoryCalculator.recording(
                sample,
                in: payload.samples,
                now: now
            )
        )
        save()
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(payload).write(to: url, options: .atomic)
        } catch {
            assertionFailure("Failed to save quota usage history: \(error)")
        }
    }

    private static func load(from url: URL) -> QuotaUsageHistoryPayload {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return .empty
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode(QuotaUsageHistoryPayload.self, from: data)
            return QuotaUsageHistoryPayload(
                samples: QuotaUsageHistoryCalculator.normalized(decoded.samples)
            )
        } catch {
            let invalidURL = url.deletingLastPathComponent()
                .appendingPathComponent("quota-usage-history.invalid.json")
            try? FileManager.default.removeItem(at: invalidURL)
            try? FileManager.default.moveItem(at: url, to: invalidURL)
            return .empty
        }
    }
}

private extension URL {
    static var defaultQuotaUsageHistoryURL: URL {
        let directory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(
            fileURLWithPath: "\(NSHomeDirectory())/Library/Application Support"
        )
        return directory
            .appendingPathComponent("LimitLens", isDirectory: true)
            .appendingPathComponent("quota-usage-history.json")
    }
}
