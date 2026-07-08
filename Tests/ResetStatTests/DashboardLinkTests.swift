import Foundation
import Testing
@testable import ResetStat

@MainActor
@Suite("Dashboard deep links")
struct DashboardLinkTests {
    @Test("Provider tabs expose dashboard URLs for providers only")
    func providerTabsExposeDashboardURLs() {
        #expect(ProviderTab.codex.dashboardURL != nil)
        #expect(ProviderTab.cursor.dashboardURL != nil)
        #expect(ProviderTab.devin.dashboardURL != nil)
        #expect(ProviderTab.openCodeGo.dashboardURL == nil)
        #expect(ProviderTab.overview.dashboardURL == nil)
        #expect(ProviderTab.settings.dashboardURL == nil)
    }

    @Test("Dashboard URLs are valid HTTPS endpoints")
    func dashboardURLsAreValidHTTPS() throws {
        for tab in ProviderTab.providerCases where tab != .openCodeGo {
            let url = try #require(tab.dashboardURL)
            #expect(url.scheme == "https")
        }
    }

    @Test("OpenCode Go dashboard URL builder handles empty workspace ID")
    func openCodeGoDashboardURLHandlesEmptyWorkspaceId() {
        let url = OpenCodeGoDashboardCredentials.dashboardURL(workspaceId: "")
        #expect(url.absoluteString == "https://opencode.ai")
    }

    @Test("OpenCode Go dashboard URL builder encodes workspace ID")
    func openCodeGoDashboardURLEncodesWorkspaceId() {
        let url = OpenCodeGoDashboardCredentials.dashboardURL(workspaceId: "team-123")
        #expect(url.absoluteString == "https://opencode.ai/workspace/team-123/go")
    }

    @Test("OpenCode Go dashboard URL builder normalizes full dashboard URL input")
    func openCodeGoDashboardURLNormalizesFullInput() {
        let url = OpenCodeGoDashboardCredentials.dashboardURL(
            workspaceId: "https://opencode.ai/workspace/team-456/go?tab=usage"
        )
        #expect(url.absoluteString == "https://opencode.ai/workspace/team-456/go")
    }

    @Test("OpenCode Go dashboard URL builder percent-encodes special characters")
    func openCodeGoDashboardURLPercentEncodesSpecialCharacters() {
        let url = OpenCodeGoDashboardCredentials.dashboardURL(workspaceId: "team test")
        #expect(url.absoluteString == "https://opencode.ai/workspace/team%20test/go")
    }
}
