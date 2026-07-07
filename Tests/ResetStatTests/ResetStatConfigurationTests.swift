import Foundation
import Testing
@testable import ResetStat

@MainActor
@Suite("ResetStat configuration")
struct ResetStatConfigurationTests {
    @Test("Loads detected defaults when config is missing")
    func loadsDetectedDefaultsWhenMissing() {
        let url = temporaryConfigURL()
        let store = ResetStatConfigurationStore(url: url)

        #expect(store.configuration.providers.codex.executablePath == ResetStatConfiguration.defaults.providers.codex.executablePath)
    }

    @Test("Detected defaults enable only found provider paths")
    func detectedDefaultsEnableFoundProviderPaths() {
        let defaults = ResetStatConfiguration.defaults
        let detected = ResetStatConfiguration.detected(
            fileExists: { path in
                path == defaults.providers.cursor.stateDatabasePath ||
                    path == defaults.providers.openCodeGo.configPath
            },
            isExecutable: { path in
                path == defaults.providers.codex.executablePath
            }
        )

        #expect(detected.providers.codex.isEnabled == true)
        #expect(detected.providers.cursor.isEnabled == true)
        #expect(detected.providers.devin.isEnabled == false)
        #expect(detected.providers.openCodeGo.isEnabled == true)
        #expect(detected.setup.showsFirstLaunchSetup == true)
    }

    @Test("Saves and reloads configuration")
    func savesAndReloadsConfiguration() {
        let url = temporaryConfigURL()
        let store = ResetStatConfigurationStore(url: url)
        store.configuration.providers.codex.isEnabled = false
        store.configuration.providers.cursor.stateDatabasePath = "/tmp/cursor-state.vscdb"
        store.configuration.privacy.menuBarDisplay = .hidden
        store.save()

        let reloaded = ResetStatConfigurationStore(url: url)

        #expect(reloaded.configuration.providers.codex.isEnabled == false)
        #expect(reloaded.configuration.providers.cursor.stateDatabasePath == "/tmp/cursor-state.vscdb")
        #expect(reloaded.configuration.privacy.menuBarDisplay == .hidden)
        #expect(reloaded.configuration.privacy.hidesProviderNames == true)
    }

    @Test("Legacy config defaults setup to dismissed")
    func legacyConfigDefaultsSetupToDismissed() throws {
        let url = temporaryConfigURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(#"{"providers":{"codex":{"isEnabled":true,"executablePath":"/x"},"cursor":{"isEnabled":true,"stateDatabasePath":"/y"},"devin":{"isEnabled":true,"stateDatabasePath":"/z"},"openCodeGo":{"isEnabled":true,"configPath":"/w"}},"privacy":{"menuBarDisplay":"logos"}}"#.utf8).write(to: url)

        let store = ResetStatConfigurationStore(url: url)

        #expect(store.configuration.setup.showsFirstLaunchSetup == false)
    }

    @Test("Legacy hidesProviderNames config migrates to menuBarDisplay")
    func legacyHidesProviderNamesMigratesToMenuBarDisplay() throws {
        let url = temporaryConfigURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(#"{"providers":{"codex":{"isEnabled":true,"executablePath":"/x"},"cursor":{"isEnabled":true,"stateDatabasePath":"/y"},"devin":{"isEnabled":true,"stateDatabasePath":"/z"},"openCodeGo":{"isEnabled":true,"configPath":"/w"}},"privacy":{"hidesProviderNames":true}}"#.utf8).write(to: url)

        let store = ResetStatConfigurationStore(url: url)

        #expect(store.configuration.privacy.menuBarDisplay == .hidden)
        #expect(store.configuration.privacy.hidesProviderNames == true)
    }

    @Test("Legacy visible config migrates to logos menu bar display")
    func legacyVisibleConfigMigratesToLogos() throws {
        let url = temporaryConfigURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(#"{"providers":{"codex":{"isEnabled":true,"executablePath":"/x"},"cursor":{"isEnabled":true,"stateDatabasePath":"/y"},"devin":{"isEnabled":true,"stateDatabasePath":"/z"},"openCodeGo":{"isEnabled":true,"configPath":"/w"}},"privacy":{"hidesProviderNames":false}}"#.utf8).write(to: url)

        let store = ResetStatConfigurationStore(url: url)

        #expect(store.configuration.privacy.menuBarDisplay == .logos)
        #expect(store.configuration.privacy.hidesProviderNames == false)
    }

    @Test("Bad JSON is preserved and defaults are used")
    func badJSONIsPreserved() throws {
        let url = temporaryConfigURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{".utf8).write(to: url)

        let store = ResetStatConfigurationStore(url: url)
        let invalidURL = url.deletingLastPathComponent().appendingPathComponent("config.invalid.json")

        #expect(store.configuration == .defaults)
        #expect(FileManager.default.fileExists(atPath: invalidURL.path))
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test("Reset restores defaults")
    func resetRestoresDefaults() {
        let url = temporaryConfigURL()
        let store = ResetStatConfigurationStore(url: url)
        store.configuration.providers.devin.isEnabled = false
        store.configuration.providers.openCodeGo.configPath = "/tmp/custom.json"
        store.resetToDefaults()

        #expect(store.configuration == .defaults)
        #expect(ResetStatConfigurationStore(url: url).configuration == .defaults)
    }

    @Test("OpenCode Go validation catches missing required fields")
    func openCodeGoValidationCatchesMissingFields() throws {
        let directory = temporaryDirectory()
        let url = directory.appendingPathComponent("opencode-go.json")
        try Data(#"{"workspaceId":"abc"}"#.utf8).write(to: url)

        let config = OpenCodeGoProviderConfiguration(isEnabled: true, configPath: url.path)

        #expect(config.validationWarning == "Config must include workspaceId and authCookie.")
    }

    @Test("OpenCode Go credentials normalize dashboard URL and auth cookie pair")
    func openCodeGoCredentialsNormalizeDashboardURLAndCookiePair() throws {
        let credentials = try OpenCodeGoDashboardCredentials(
            workspaceInput: "https://opencode.ai/workspace/team-123/go?tab=usage",
            authCookieInput: "Cookie: theme=dark; auth=secret-token; other=value"
        )

        #expect(credentials.workspaceId == "team-123")
        #expect(credentials.authCookie == "secret-token")
        #expect(OpenCodeGoDashboardCredentials.normalizedWorkspaceId(from: "https://opencode.ai") == "")
    }

    @Test("OpenCode Go config writer creates private JSON file")
    func openCodeGoConfigWriterCreatesPrivateJSONFile() throws {
        let directory = temporaryDirectory()
        let url = directory.appendingPathComponent("nested/opencode-go.json")
        let credentials = OpenCodeGoDashboardCredentials(workspaceId: "team-123", authCookie: "secret-token")

        try OpenCodeGoDashboardConfigFile.save(credentials, to: url)
        let loaded = try OpenCodeGoDashboardConfigFile.load(from: url)
        let permissions = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int

        #expect(loaded == credentials)
        #expect(permissions == 0o600)
    }

    private func temporaryConfigURL() -> URL {
        temporaryDirectory().appendingPathComponent("config.json")
    }

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ResetStatTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
