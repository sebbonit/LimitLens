import Foundation

public protocol OpenCodeGoUsageFetching: Sendable {
    func fetchSnapshot() async throws -> OpenCodeGoUsageSnapshot
}

public final class OpenCodeGoUsageClient: OpenCodeGoUsageFetching, @unchecked Sendable {
    private let configPath: String
    private let session: URLSession

    public init(
        configPath: String = "\(NSHomeDirectory())/.config/opencode/opencode-quota/opencode-go.json",
        session: URLSession = .shared
    ) {
        self.configPath = configPath
        self.session = session
    }

    public func fetchSnapshot() async throws -> OpenCodeGoUsageSnapshot {
        guard let config = try OpenCodeGoDashboardConfig.resolve(configPath: configPath) else {
            throw CodexUsageError.unavailable("Configure OpenCode Go dashboard auth in Settings.")
        }

        async let usageTask = scrapeDashboard(config: config)
        async let billingTask = scrapeBilling(config: config)

        var snapshot = try await usageTask
        snapshot = OpenCodeGoUsageSnapshot(
            rolling: snapshot.rolling,
            weekly: snapshot.weekly,
            monthly: snapshot.monthly,
            billing: await billingTask,
            source: snapshot.source,
            fetchedAt: snapshot.fetchedAt
        )
        return snapshot
    }

    private func scrapeDashboard(config: OpenCodeGoDashboardConfig) async throws -> OpenCodeGoUsageSnapshot {
        let url = URL(string: "https://opencode.ai/workspace/\(config.workspaceId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? config.workspaceId)/go")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Gecko/20100101 Firefox/148.0", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        request.setValue("auth=\(config.authCookie)", forHTTPHeaderField: "Cookie")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw CodexUsageError.unavailable("OpenCode Go dashboard is temporarily unavailable.")
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw CodexUsageError.unavailable("OpenCode Go dashboard response was invalid.")
        }

        let parsed = OpenCodeGoDashboardParser.snapshot(from: html, now: Date(), source: "Dashboard")
        guard parsed.hasUsage else {
            throw CodexUsageError.unavailable("OpenCode Go dashboard usage was not found.")
        }
        return parsed
    }

    private func scrapeBilling(config: OpenCodeGoDashboardConfig) async -> OpenCodeGoBilling? {
        let encoded = config.workspaceId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? config.workspaceId
        let url = URL(string: "https://opencode.ai/workspace/\(encoded)/billing")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Gecko/20100101 Firefox/148.0", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        request.setValue("auth=\(config.authCookie)", forHTTPHeaderField: "Cookie")

        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            return nil
        }
        return OpenCodeGoBillingParser.billing(from: html)
    }
}

struct OpenCodeGoDashboardConfig: Equatable {
    let workspaceId: String
    let authCookie: String

    static func resolve(configPath: String, environment: [String: String] = ProcessInfo.processInfo.environment) throws -> OpenCodeGoDashboardConfig? {
        if let workspaceId = environment["OPENCODE_GO_WORKSPACE_ID"]?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
           let authCookie = environment["OPENCODE_GO_AUTH_COOKIE"]?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
            return OpenCodeGoDashboardConfig(workspaceId: workspaceId, authCookie: authCookie)
        }

        guard FileManager.default.fileExists(atPath: configPath) else { return nil }
        let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
        let config = try JSONDecoder().decode(OpenCodeGoConfigFile.self, from: data)
        guard let workspaceId = config.workspaceId?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
              let authCookie = config.authCookie?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty else {
            return nil
        }
        return OpenCodeGoDashboardConfig(workspaceId: workspaceId, authCookie: authCookie)
    }
}

private struct OpenCodeGoConfigFile: Decodable {
    let workspaceId: String?
    let authCookie: String?
}

enum OpenCodeGoDashboardParser {
    static func snapshot(from html: String, now: Date, source: String?) -> OpenCodeGoUsageSnapshot {
        let solid = OpenCodeGoUsageSnapshot(
            rolling: parseSolidWindow(name: "rollingUsage", html: html, now: now),
            weekly: parseSolidWindow(name: "weeklyUsage", html: html, now: now),
            monthly: parseSolidWindow(name: "monthlyUsage", html: html, now: now),
            source: source,
            fetchedAt: now
        )
        if solid.hasUsage {
            return solid
        }

        let slots = parseDataSlotWindows(html: html, now: now)
        return OpenCodeGoUsageSnapshot(
            rolling: slots["rolling"],
            weekly: slots["weekly"],
            monthly: slots["monthly"],
            source: source,
            fetchedAt: now
        )
    }

    private static func parseSolidWindow(name: String, html: String, now: Date) -> OpenCodeGoUsageWindow? {
        let number = #"(-?\d+(?:\.\d+)?)"#
        let pctFirst = #"\#(name):\$R\[\d+\]=\{[^}]*usagePercent:\#(number)[^}]*resetInSec:\#(number)[^}]*\}"#
        let resetFirst = #"\#(name):\$R\[\d+\]=\{[^}]*resetInSec:\#(number)[^}]*usagePercent:\#(number)[^}]*\}"#

        if let match = firstMatch(pattern: pctFirst, in: html),
           let usage = Double(match[0]),
           let resetSeconds = Double(match[1]) {
            return window(usedPercent: usage, resetSeconds: resetSeconds, now: now)
        }

        if let match = firstMatch(pattern: resetFirst, in: html),
           let resetSeconds = Double(match[0]),
           let usage = Double(match[1]) {
            return window(usedPercent: usage, resetSeconds: resetSeconds, now: now)
        }

        return nil
    }

    private static func parseDataSlotWindows(html: String, now: Date) -> [String: OpenCodeGoUsageWindow] {
        let parts = html.components(separatedBy: #"data-slot="usage-item""#)
        guard parts.count > 1 else { return [:] }

        var result: [String: OpenCodeGoUsageWindow] = [:]
        for part in parts.dropFirst() {
            guard let label = firstMatch(pattern: #"data-slot="usage-label">([^<]+)<"#, in: part)?.first?.lowercased(),
                  let usedText = firstMatch(pattern: #"data-slot="usage-value">[^0-9]*(\d+(?:\.\d+)?)"#, in: part)?.first,
                  let usedPercent = Double(usedText),
                  let resetMatch = firstMatch(pattern: #"data-slot="(reset-time|reset-now)">([\s\S]*?)</span>"#, in: part) else {
                continue
            }

            let resetSeconds = resetMatch[0] == "reset-now" ? 0 : parseHumanDuration(resetMatch[1])
            guard let resetSeconds else { continue }

            if label.contains("rolling") {
                result["rolling"] = window(usedPercent: usedPercent, resetSeconds: resetSeconds, now: now)
            } else if label.contains("weekly") {
                result["weekly"] = window(usedPercent: usedPercent, resetSeconds: resetSeconds, now: now)
            } else if label.contains("monthly") {
                result["monthly"] = window(usedPercent: usedPercent, resetSeconds: resetSeconds, now: now)
            }
        }
        return result
    }

    private static func parseHumanDuration(_ text: String) -> Double? {
        let normalized = text
            .replacingOccurrences(of: #"<!--\$-->"#, with: "")
            .replacingOccurrences(of: #"<!--/-->"#, with: "")
            .replacingOccurrences(of: #"Resets?\s*in\s*"#, with: "", options: .regularExpression)
            .lowercased()

        var seconds: Double = 0
        var found = false
        for (unit, multiplier) in [("days?", 86_400.0), ("hours?", 3_600.0), ("minutes?", 60.0), ("seconds?", 1.0)] {
            if let value = firstMatch(pattern: #"(\d+(?:\.\d+)?)\s*\#(unit)"#, in: normalized)?.first,
               let number = Double(value) {
                seconds += number * multiplier
                found = true
            }
        }
        return found ? seconds : nil
    }

    private static func window(usedPercent: Double, resetSeconds: Double, now: Date) -> OpenCodeGoUsageWindow {
        OpenCodeGoUsageWindow(
            usedPercent: usedPercent,
            resetAt: now.addingTimeInterval(max(0, resetSeconds))
        )
    }

    private static func firstMatch(pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range), match.numberOfRanges > 1 else {
            return nil
        }

        return (1..<match.numberOfRanges).compactMap { index in
            guard let range = Range(match.range(at: index), in: text) else { return nil }
            return String(text[range])
        }
    }
}

enum OpenCodeGoBillingParser {
    static func billing(from html: String) -> OpenCodeGoBilling? {
        let balance = firstMatch(pattern: #"data-slot="balance-value"[^>]*>(.*?)</span>"#, in: html)?
            .first
            .map { stripSolid($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { cleanAmount($0) }
            .flatMap { $0.isEmpty ? nil : $0 }

        let cardLast4 = firstMatch(pattern: #"data-slot="number">(\d{3,4})<"#, in: html)?.first

        let autoReload: Bool = {
            let state = firstMatch(pattern: #"Auto reload is.*?<b>(enabled|disabled)</b>"#, in: html)?.first
            return state == "enabled"
        }()

        let payments = parsePayments(html: html)

        let result = OpenCodeGoBilling(
            balanceText: balance,
            cardLast4: cardLast4,
            autoReloadEnabled: autoReload,
            payments: payments
        )

        return result.hasData ? result : nil
    }

    private static func parsePayments(html: String) -> [OpenCodeGoPayment] {
        let parts = html.components(separatedBy: #"data-slot="payment-date""#)
        guard parts.count > 1 else { return [] }

        return parts.dropFirst().compactMap { chunk in
            guard let id = firstMatch(pattern: #"data-slot="payment-id">([^<]+)<"#, in: chunk)?.first else {
                return nil
            }
            let title = firstMatch(pattern: #"title="([^"]+)""#, in: chunk)?.first
            let dateText = firstMatch(pattern: #"[^>]*>([^<]*)<"#, in: chunk)?.first?.trimmingCharacters(in: .whitespacesAndNewlines)
            let amount = firstMatch(pattern: #"data-slot="payment-amount"[^>]*>.*?(\$[\d.,]+)"#, in: chunk)?.first
            let refunded = firstMatch(pattern: #"data-refunded="(true|false)""#, in: chunk)?.first == "true"

            return OpenCodeGoPayment(
                id: id,
                amountText: amount ?? "",
                date: title.flatMap(parseDate),
                dateText: dateText ?? "",
                refunded: refunded
            )
        }
    }

    private static let paymentDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "EEE, MMM d, yyyy, h:mm:ss a z"
        return formatter
    }()

    private static func parseDate(_ title: String) -> Date? {
        paymentDateFormatter.date(from: title)
    }

    private static func stripSolid(_ text: String) -> String {
        text.replacingOccurrences(of: "<!--$-->", with: "")
            .replacingOccurrences(of: "<!--/-->", with: "")
            .replacingOccurrences(of: "<!--$--", with: "")
    }

    private static func cleanAmount(_ text: String) -> String {
        guard let match = text.range(of: #"\$[\d.,]+"#, options: .regularExpression) else {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(text[match])
    }

    private static func firstMatch(pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range), match.numberOfRanges > 1 else {
            return nil
        }

        return (1..<match.numberOfRanges).compactMap { index in
            guard let range = Range(match.range(at: index), in: text) else { return nil }
            return String(text[range])
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
