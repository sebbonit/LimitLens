import Foundation
import Testing
@testable import LimitLensCore

@Suite("Codex local usage scanner")
struct CodexLocalUsageScannerTests {
    @Test("Builds rolling token and model-aware cost windows")
    func buildsRollingWindows() async throws {
        let home = try makeCodexHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let now = isoDate("2026-07-30T12:00:00Z")
        let logURL = home
            .appendingPathComponent("sessions/2026/07/30", isDirectory: true)
            .appendingPathComponent("rollout.jsonl")
        try FileManager.default.createDirectory(
            at: logURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let lines = [
            turnContext(model: "gpt-5.6-sol"),
            tokenCount(
                timestamp: "2026-07-30T10:00:00Z",
                input: 1_000_000,
                cachedInput: 200_000,
                output: 100_000,
                total: 1_100_000,
                cumulativeTotal: 1_100_000
            ),
            turnContext(model: "gpt-5.6-terra"),
            tokenCount(
                timestamp: "2026-07-27T12:00:01Z",
                input: 400_000,
                cachedInput: 100_000,
                output: 50_000,
                total: 450_000,
                cumulativeTotal: 1_550_000
            ),
            turnContext(model: "gpt-5.6-luna"),
            tokenCount(
                timestamp: "2026-07-20T12:00:00Z",
                input: 200_000,
                cachedInput: 50_000,
                output: 20_000,
                total: 220_000,
                cumulativeTotal: 1_770_000
            )
        ]
        try (lines.joined(separator: "\n") + "\n").write(
            to: logURL,
            atomically: true,
            encoding: .utf8
        )

        let summary = await CodexLocalUsageScanner(codexHomeURL: home).scan(now: now)

        #expect(summary?.last24Hours.totalTokens == 1_100_000)
        #expect(summary?.last7Days.totalTokens == 1_550_000)
        #expect(summary?.last30Days.totalTokens == 1_770_000)
        #expect(abs((summary?.last24Hours.estimatedCostUSD ?? 0) - 7.1) < 0.000_001)
        #expect(abs((summary?.last7Days.estimatedCostUSD ?? 0) - 8.625) < 0.000_001)
        #expect(abs((summary?.last30Days.estimatedCostUSD ?? 0) - 8.9) < 0.000_001)
        #expect(summary?.last30Days.hasCompleteCostEstimate == true)
    }

    @Test("Marks tokens from unknown models as unpriced")
    func marksUnknownModelsAsUnpriced() async throws {
        let home = try makeCodexHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let logURL = home.appendingPathComponent("archived_sessions/rollout.jsonl")
        try FileManager.default.createDirectory(
            at: logURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let content = [
            turnContext(model: "gpt-5.6-sol"),
            tokenCount(
                timestamp: "2026-07-30T10:00:00Z",
                input: 100,
                cachedInput: 0,
                output: 10,
                total: 110,
                cumulativeTotal: 110
            ),
            turnContext(model: "third-party-model"),
            tokenCount(
                timestamp: "2026-07-30T11:00:00Z",
                input: 200,
                cachedInput: 0,
                output: 20,
                total: 220,
                cumulativeTotal: 330
            )
        ].joined(separator: "\n") + "\n"
        try content.write(to: logURL, atomically: true, encoding: .utf8)

        let summary = await CodexLocalUsageScanner(codexHomeURL: home).scan(
            now: isoDate("2026-07-30T12:00:00Z")
        )

        #expect(summary?.last24Hours.totalTokens == 330)
        #expect(summary?.last24Hours.unpricedTokens == 220)
        #expect(summary?.last24Hours.hasCompleteCostEstimate == false)
        #expect(summary?.last24Hours.hasAnyCostEstimate == true)
    }

    @Test("Only parses appended complete lines after the first scan")
    func parsesAppendedCompleteLines() async throws {
        let home = try makeCodexHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let logURL = home.appendingPathComponent("sessions/rollout.jsonl")
        try FileManager.default.createDirectory(
            at: logURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let initial = turnContext(model: "gpt-5.6-luna") + "\n"
            + tokenCount(
                timestamp: "2026-07-30T10:00:00Z",
                input: 100,
                cachedInput: 0,
                output: 10,
                total: 110,
                cumulativeTotal: 110
            ) + "\n"
        try initial.write(to: logURL, atomically: true, encoding: .utf8)

        let scanner = CodexLocalUsageScanner(codexHomeURL: home)
        let now = isoDate("2026-07-30T12:00:00Z")
        let first = await scanner.scan(now: now)
        #expect(first?.last24Hours.totalTokens == 110)

        let handle = try FileHandle(forWritingTo: logURL)
        try handle.seekToEnd()
        let appended = tokenCount(
            timestamp: "2026-07-30T11:00:00Z",
            input: 200,
            cachedInput: 0,
            output: 20,
            total: 220,
            cumulativeTotal: 330
        ) + "\n"
        try handle.write(contentsOf: Data(appended.utf8))
        try handle.close()

        let second = await scanner.scan(now: now)
        #expect(second?.last24Hours.totalTokens == 330)
    }

    @Test("Ignores duplicated final token-count events")
    func ignoresDuplicatedFinalCounts() async throws {
        let home = try makeCodexHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let logURL = home.appendingPathComponent("sessions/rollout.jsonl")
        try FileManager.default.createDirectory(
            at: logURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let repeated = tokenCount(
            timestamp: "2026-07-30T10:00:00Z",
            input: 100,
            cachedInput: 20,
            output: 10,
            total: 110,
            cumulativeTotal: 110
        )
        let content = [
            turnContext(model: "gpt-5.6-sol"),
            repeated,
            repeated.replacingOccurrences(
                of: "2026-07-30T10:00:00Z",
                with: "2026-07-30T10:00:01Z"
            )
        ].joined(separator: "\n") + "\n"
        try content.write(to: logURL, atomically: true, encoding: .utf8)

        let summary = await CodexLocalUsageScanner(codexHomeURL: home).scan(
            now: isoDate("2026-07-30T12:00:00Z")
        )

        #expect(summary?.last24Hours.totalTokens == 110)
        #expect(summary?.last24Hours.inputTokens == 100)
        #expect(summary?.last24Hours.outputTokens == 10)
    }

    private func makeCodexHome() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("limitlens-usage-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func turnContext(model: String) -> String {
        #"{"timestamp":"2026-07-30T09:00:00Z","type":"turn_context","payload":{"model":"\#(model)"}}"#
    }

    private func tokenCount(
        timestamp: String,
        input: Int64,
        cachedInput: Int64,
        output: Int64,
        total: Int64,
        cumulativeTotal: Int64
    ) -> String {
        """
        {"timestamp":"\(timestamp)","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":\(input),"cached_input_tokens":\(cachedInput),"output_tokens":\(output),"reasoning_output_tokens":0,"total_tokens":\(total)},"total_token_usage":{"input_tokens":0,"cached_input_tokens":0,"output_tokens":0,"reasoning_output_tokens":0,"total_tokens":\(cumulativeTotal)}}}}
        """
    }

    private func isoDate(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}
