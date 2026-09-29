import Foundation
import Testing
@testable import LimitLensCore

@Suite("OpenCode Go usage client", .serialized)
struct OpenCodeGoUsageClientTests {
    @Test("Login redirect reports an expired session")
    func loginRedirectReportsExpiredSession() async {
        let client = makeClient(legacyDashboard: true) { request in
            let url = URL(string: "https://opencode.ai/console/login")!
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(loginPageHTML.utf8))
        }

        await #expect(
            throws: CodexUsageError.unavailable("OpenCode Go session expired. Update the auth cookie in Settings.")
        ) {
            try await client.fetchSnapshot()
        }
    }

    @Test("Authorization redirect reports an expired session")
    func authorizationRedirectReportsExpiredSession() async {
        let client = makeClient(legacyDashboard: true) { _ in
            let url = URL(string: "https://auth.opencode.ai/authorize?client_id=console")!
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(loginPageHTML.utf8))
        }

        await #expect(
            throws: CodexUsageError.unavailable("OpenCode Go session expired. Update the auth cookie in Settings.")
        ) {
            try await client.fetchSnapshot()
        }
    }

    @Test("Dashboard HTML without usage keeps the not-found error")
    func dashboardWithoutUsageKeepsNotFoundError() async {
        let client = makeClient(legacyDashboard: true) { _ in
            let url = URL(string: "https://opencode.ai/workspace/ws-test/go")!
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("<html><body>No usage here</body></html>".utf8))
        }

        await #expect(
            throws: CodexUsageError.unavailable("OpenCode Go dashboard usage was not found.")
        ) {
            try await client.fetchSnapshot()
        }
    }

    @Test("Dashboard usage HTML returns a snapshot")
    func dashboardUsageReturnsSnapshot() async throws {
        let client = makeClient(legacyDashboard: true) { request in
            let url = request.url!
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if url.path.hasSuffix("/billing") {
                return (response, Data("<html></html>".utf8))
            }
            return (response, Data(usagePageHTML.utf8))
        }

        let snapshot = try await client.fetchSnapshot()

        #expect(snapshot.hasUsage)
        #expect(snapshot.rolling?.usedPercent == 7)
        #expect(snapshot.weekly?.usedPercent == 3)
        #expect(snapshot.monthly?.usedPercent == 1)
    }

    @Test("Current console API returns all three usage windows")
    func consoleAPIReturnsUsage() async throws {
        let client = makeClient { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if request.url!.path == "/console/api/go/status" {
                #expect(request.value(forHTTPHeaderField: "x-org-id") == "ws-test")
                #expect(request.value(forHTTPHeaderField: "Cookie") == "auth=cookie-test")
                return (response, Data(consoleUsageJSON.utf8))
            }
            return (response, Data("<html></html>".utf8))
        }
        let snapshot = try await client.fetchSnapshot()
        #expect(snapshot.rolling?.usedPercent == 0)
        #expect(snapshot.rolling?.resetAt == nil)
        #expect(snapshot.weekly?.usedPercent == 25)
        #expect(snapshot.monthly?.usedPercent == 2)
        #expect(snapshot.monthly?.resetAt == Date(timeIntervalSince1970: 1_790_895_051))
        #expect(snapshot.source == "Console API")
    }

    @Test("API rejects expired credentials with an actionable error")
    func apiUnauthorizedReportsExpiredSession() async {
        let client = makeClient { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"_tag":"Unauthorized"}"#.utf8))
        }
        await #expect(throws: CodexUsageError.unavailable("OpenCode Go session expired. Update the auth cookie in Settings.")) {
            try await client.fetchSnapshot()
        }
    }

    @Test("API without an active subscription reports no active subscription")
    func apiWithoutSubscription() async {
        let client = makeClient { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("null".utf8))
        }
        await #expect(throws: CodexUsageError.unavailable("No active OpenCode Go subscription was found for this workspace.")) {
            try await client.fetchSnapshot()
        }
    }

    @Test("Current console session is sent under its own cookie name")
    func consoleSessionHeader() {
        let config = OpenCodeGoDashboardConfig(workspaceId: "ws-test", authCookie: "__Host-console_session=st_test")
        #expect(config.cookieHeader == "__Host-console_session=st_test")
    }

    // MARK: - Helpers

    private func makeClient(
        legacyDashboard: Bool = false,
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> OpenCodeGoUsageClient {
        StubURLProtocol.handler = { request in
            if legacyDashboard && request.url!.path == "/console/api/go/status" {
                let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (response, Data())
            }
            return try handler(request)
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return OpenCodeGoUsageClient(
            configPath: stubConfigPath(),
            session: URLSession(configuration: configuration)
        )
    }

    private func stubConfigPath() -> String {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenCodeGoTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("opencode-go.json")
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? Data(#"{"workspaceId":"ws-test","authCookie":"cookie-test"}"#.utf8)
            .write(to: url)
        return url.path
    }
}

private let loginPageHTML = """
<!DOCTYPE html>
<html lang="en">
<head><title>OpenCode Console</title></head>
<body><div id="root"></div></body>
</html>
"""

private let usagePageHTML = """
<script>
rollingUsage:$R[1]={usagePercent:7,resetInSec:16080}
weeklyUsage:$R[2]={resetInSec:8640,usagePercent:3}
monthlyUsage:$R[3]={usagePercent:1,resetInSec:2340000}
</script>
"""

private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    // Serialized suite: only one test touches the handler at a time.
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            guard let handler = Self.handler else {
                throw URLError(.unknown)
            }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private let consoleUsageJSON = #"""
{"access":{"meters":{
"fiveHour":{"limitMicroCents":"1200000000","usedMicroCents":"0","resetsAt":null},
"week":{"limitMicroCents":"3000000000","usedMicroCents":"750000000","resetsAt":"2026-10-05T00:00:00.000Z"},
"month":{"limitMicroCents":"6000000000","usedMicroCents":"120000000","resetsAt":"2026-10-01T22:50:51.000Z"}
}}}
"""#
