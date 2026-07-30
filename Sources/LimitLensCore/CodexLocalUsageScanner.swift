import Foundation

public struct CodexLocalUsagePeriod: Equatable, Sendable {
    public let inputTokens: Int64
    public let cachedInputTokens: Int64
    public let outputTokens: Int64
    public let totalTokens: Int64
    public let estimatedCostUSD: Double
    public let unpricedTokens: Int64

    public init(
        inputTokens: Int64,
        cachedInputTokens: Int64,
        outputTokens: Int64,
        totalTokens: Int64,
        estimatedCostUSD: Double,
        unpricedTokens: Int64
    ) {
        self.inputTokens = inputTokens
        self.cachedInputTokens = cachedInputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
        self.estimatedCostUSD = estimatedCostUSD
        self.unpricedTokens = unpricedTokens
    }

    public var hasCompleteCostEstimate: Bool {
        unpricedTokens == 0
    }

    public var hasAnyCostEstimate: Bool {
        totalTokens == 0 || unpricedTokens < totalTokens
    }
}

public struct CodexLocalUsageSummary: Equatable, Sendable {
    public let last24Hours: CodexLocalUsagePeriod
    public let last7Days: CodexLocalUsagePeriod
    public let last30Days: CodexLocalUsagePeriod

    public init(
        last24Hours: CodexLocalUsagePeriod,
        last7Days: CodexLocalUsagePeriod,
        last30Days: CodexLocalUsagePeriod
    ) {
        self.last24Hours = last24Hours
        self.last7Days = last7Days
        self.last30Days = last30Days
    }
}

public protocol CodexLocalUsageScanning: Sendable {
    func scan(now: Date) async -> CodexLocalUsageSummary?
}

/// Reads token deltas from Codex's local JSONL session logs.
///
/// The scanner keeps an in-memory, append-aware cache because a month of logs
/// can be large. Archived files are parsed once; active files only parse newly
/// appended complete lines on subsequent refreshes.
public actor CodexLocalUsageScanner: CodexLocalUsageScanning {
    public static let shared = CodexLocalUsageScanner()

    private struct FileCache {
        var parsedByteCount: UInt64
        var currentModel: String?
        var lastCumulativeTokens: Int64?
        var records: [UsageRecord]
    }

    private struct UsageRecord: Sendable {
        let timestamp: Date
        let inputTokens: Int64
        let cachedInputTokens: Int64
        let outputTokens: Int64
        let totalTokens: Int64
        let estimatedCostUSD: Double?
    }

    private struct Pricing {
        let inputPerMillion: Double
        let cachedInputPerMillion: Double
        let outputPerMillion: Double

        func cost(input: Int64, cachedInput: Int64, output: Int64) -> Double {
            let cached = min(max(cachedInput, 0), max(input, 0))
            let uncached = max(input - cached, 0)
            return (
                Double(uncached) * inputPerMillion
                    + Double(cached) * cachedInputPerMillion
                    + Double(max(output, 0)) * outputPerMillion
            ) / 1_000_000
        }
    }

    private struct LogEnvelope: Decodable {
        struct Payload: Decodable {
            struct TokenInfo: Decodable {
                struct Usage: Decodable {
                    let inputTokens: Int64
                    let cachedInputTokens: Int64
                    let outputTokens: Int64
                    let totalTokens: Int64

                    private enum CodingKeys: String, CodingKey {
                        case inputTokens = "input_tokens"
                        case cachedInputTokens = "cached_input_tokens"
                        case outputTokens = "output_tokens"
                        case totalTokens = "total_tokens"
                    }
                }

                let lastTokenUsage: Usage?
                let totalTokenUsage: Usage?

                private enum CodingKeys: String, CodingKey {
                    case lastTokenUsage = "last_token_usage"
                    case totalTokenUsage = "total_token_usage"
                }
            }

            let type: String?
            let model: String?
            let info: TokenInfo?
        }

        let timestamp: String?
        let type: String
        let payload: Payload
    }

    private let codexHomeURL: URL
    private let fileManager: FileManager
    private let decoder = JSONDecoder()
    private var fileCache: [String: FileCache] = [:]

    public init(
        codexHomeURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true),
        fileManager: FileManager = .default
    ) {
        self.codexHomeURL = codexHomeURL
        self.fileManager = fileManager
    }

    public func scan(now: Date = Date()) async -> CodexLocalUsageSummary? {
        let cutoff = now.addingTimeInterval(-30 * 86_400)
        let files = recentLogFiles(modifiedSince: cutoff)
        guard !files.isEmpty else {
            fileCache.removeAll()
            return nil
        }

        var livePaths = Set<String>()
        var allRecords: [UsageRecord] = []

        for fileURL in files {
            guard !Task.isCancelled else { return nil }
            let path = fileURL.path
            livePaths.insert(path)

            let attributes = try? fileManager.attributesOfItem(atPath: path)
            let fileSize = (attributes?[.size] as? NSNumber)?.uint64Value ?? 0
            var cached = fileCache[path] ?? FileCache(
                parsedByteCount: 0,
                currentModel: nil,
                lastCumulativeTokens: nil,
                records: []
            )

            if fileSize < cached.parsedByteCount {
                cached = FileCache(
                    parsedByteCount: 0,
                    currentModel: nil,
                    lastCumulativeTokens: nil,
                    records: []
                )
            }
            if fileSize > cached.parsedByteCount {
                parseAppendedLines(
                    at: fileURL,
                    fileSize: fileSize,
                    cache: &cached
                )
                fileCache[path] = cached
            }

            allRecords.append(contentsOf: cached.records)
        }

        fileCache = fileCache.filter { livePaths.contains($0.key) }

        return CodexLocalUsageSummary(
            last24Hours: aggregate(
                allRecords,
                since: now.addingTimeInterval(-86_400),
                through: now
            ),
            last7Days: aggregate(
                allRecords,
                since: now.addingTimeInterval(-7 * 86_400),
                through: now
            ),
            last30Days: aggregate(allRecords, since: cutoff, through: now)
        )
    }

    private func recentLogFiles(modifiedSince cutoff: Date) -> [URL] {
        let roots = [
            codexHomeURL.appendingPathComponent("sessions", isDirectory: true),
            codexHomeURL.appendingPathComponent("archived_sessions", isDirectory: true)
        ]
        let keys: [URLResourceKey] = [.isRegularFileKey, .contentModificationDateKey]

        return roots.flatMap { root -> [URL] in
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                return []
            }

            return enumerator.compactMap { item in
                guard let url = item as? URL,
                      url.pathExtension == "jsonl",
                      let values = try? url.resourceValues(forKeys: Set(keys)),
                      values.isRegularFile == true,
                      (values.contentModificationDate ?? .distantPast) >= cutoff else {
                    return nil
                }
                return url
            }
        }
    }

    private func parseAppendedLines(
        at fileURL: URL,
        fileSize: UInt64,
        cache: inout FileCache
    ) {
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return }
        defer { try? handle.close() }

        do {
            try handle.seek(toOffset: cache.parsedByteCount)
        } catch {
            return
        }

        var remaining = fileSize - cache.parsedByteCount
        var pending = Data()

        while remaining > 0 {
            guard !Task.isCancelled else { return }
            let requestedLength = Int(min(remaining, 256 * 1_024))
            guard let chunk = try? handle.read(upToCount: requestedLength),
                  !chunk.isEmpty else {
                return
            }
            pending.append(chunk)
            remaining -= UInt64(chunk.count)

            guard let lastNewline = pending.lastIndex(of: 0x0A) else {
                continue
            }
            let completeData = pending[...lastNewline]
            for line in completeData.split(separator: 0x0A, omittingEmptySubsequences: true) {
                parse(line: line, cache: &cache)
            }
            cache.parsedByteCount += UInt64(completeData.count)
            pending = Data(pending[pending.index(after: lastNewline)...])
        }
    }

    private func parse(line: Data.SubSequence, cache: inout FileCache) {
        guard lineContainsRelevantEvent(line),
              let envelope = try? decoder.decode(LogEnvelope.self, from: Data(line)) else {
            return
        }

        if envelope.type == "turn_context" {
            cache.currentModel = envelope.payload.model
            return
        }
        guard envelope.type == "event_msg",
              envelope.payload.type == "token_count",
              let timestampText = envelope.timestamp,
              let timestamp = Self.parseTimestamp(timestampText),
              let info = envelope.payload.info,
              let usage = info.lastTokenUsage else {
            return
        }
        if let cumulativeTokens = info.totalTokenUsage?.totalTokens {
            guard cumulativeTokens != cache.lastCumulativeTokens else { return }
            cache.lastCumulativeTokens = cumulativeTokens
        }

        let input = max(usage.inputTokens, 0)
        let cachedInput = min(max(usage.cachedInputTokens, 0), input)
        let output = max(usage.outputTokens, 0)
        let total = max(usage.totalTokens, input + output)
        let cost = Self.pricing(for: cache.currentModel)?.cost(
            input: input,
            cachedInput: cachedInput,
            output: output
        )
        cache.records.append(
            UsageRecord(
                timestamp: timestamp,
                inputTokens: input,
                cachedInputTokens: cachedInput,
                outputTokens: output,
                totalTokens: total,
                estimatedCostUSD: cost
            )
        )
    }

    private func lineContainsRelevantEvent(_ line: Data.SubSequence) -> Bool {
        line.range(of: Data(#""type":"turn_context""#.utf8)) != nil
            || (
                line.range(of: Data(#""type":"event_msg""#.utf8)) != nil
                    && line.range(of: Data(#""type":"token_count""#.utf8)) != nil
            )
    }

    private func aggregate(
        _ records: [UsageRecord],
        since cutoff: Date,
        through now: Date
    ) -> CodexLocalUsagePeriod {
        var input: Int64 = 0
        var cachedInput: Int64 = 0
        var output: Int64 = 0
        var total: Int64 = 0
        var estimatedCost = 0.0
        var unpriced: Int64 = 0

        for record in records where record.timestamp >= cutoff && record.timestamp <= now {
            input += record.inputTokens
            cachedInput += record.cachedInputTokens
            output += record.outputTokens
            total += record.totalTokens
            if let cost = record.estimatedCostUSD {
                estimatedCost += cost
            } else {
                unpriced += record.totalTokens
            }
        }

        return CodexLocalUsagePeriod(
            inputTokens: input,
            cachedInputTokens: cachedInput,
            outputTokens: output,
            totalTokens: total,
            estimatedCostUSD: estimatedCost,
            unpricedTokens: unpriced
        )
    }

    private static func parseTimestamp(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }
        return ISO8601DateFormatter().date(from: value)
    }

    private static func pricing(for model: String?) -> Pricing? {
        guard let model = model?.lowercased() else { return nil }

        if model == "gpt-5.6" || model.hasPrefix("gpt-5.6-sol") {
            return Pricing(inputPerMillion: 5, cachedInputPerMillion: 0.5, outputPerMillion: 30)
        }
        if model.hasPrefix("gpt-5.6-terra") {
            return Pricing(inputPerMillion: 2.5, cachedInputPerMillion: 0.25, outputPerMillion: 15)
        }
        if model.hasPrefix("gpt-5.6-luna") {
            return Pricing(inputPerMillion: 1, cachedInputPerMillion: 0.1, outputPerMillion: 6)
        }
        if model == "gpt-5.5" || model.hasPrefix("gpt-5.5-20") {
            return Pricing(inputPerMillion: 5, cachedInputPerMillion: 0.5, outputPerMillion: 30)
        }
        if model == "gpt-5.4" || model.hasPrefix("gpt-5.4-20") {
            return Pricing(inputPerMillion: 2.5, cachedInputPerMillion: 0.25, outputPerMillion: 15)
        }
        if model.hasPrefix("gpt-5.3-codex") || model.hasPrefix("gpt-5.2-codex") {
            return Pricing(inputPerMillion: 1.75, cachedInputPerMillion: 0.175, outputPerMillion: 14)
        }
        if model.hasPrefix("gpt-5.1-codex-mini") {
            return Pricing(inputPerMillion: 0.25, cachedInputPerMillion: 0.025, outputPerMillion: 2)
        }
        if model.hasPrefix("gpt-5.1-codex") || model.hasPrefix("gpt-5-codex") {
            return Pricing(inputPerMillion: 1.25, cachedInputPerMillion: 0.125, outputPerMillion: 10)
        }
        if model.hasPrefix("codex-mini-latest") {
            return Pricing(inputPerMillion: 1.5, cachedInputPerMillion: 0.375, outputPerMillion: 6)
        }
        return nil
    }
}
