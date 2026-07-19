import Foundation
import Testing
@testable import LimitLens

@MainActor
@Suite("LimitLens configuration")
struct LimitLensConfigurationTests {
    @Test("Loads detected defaults when config is missing")
    func loadsDetectedDefaultsWhenMissing() {
        let url = temporaryConfigURL()
        let store = LimitLensConfigurationStore(url: url)

        #expect(store.configuration.providers.codex.executablePath == LimitLensConfiguration.defaults.providers.codex.executablePath)
    }

    @Test("Detected defaults enable only found provider paths")
    func detectedDefaultsEnableFoundProviderPaths() {
        let defaults = LimitLensConfiguration.defaults
        let detected = LimitLensConfiguration.detected(
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

    @Test("Legacy Codex app path migrates to the ChatGPT app bundle")
    func legacyCodexPathMigratesToChatGPTBundle() throws {
        let url = temporaryConfigURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        var configuration = LimitLensConfiguration.defaults
        configuration.providers.codex.executablePath = LimitLensConfiguration.legacyCodexExecutablePaths[0]
        try JSONEncoder().encode(configuration).write(to: url)

        let store = LimitLensConfigurationStore(
            url: url,
            isExecutable: { $0 == LimitLensConfiguration.currentCodexExecutablePath }
        )

        #expect(store.configuration.providers.codex.executablePath == LimitLensConfiguration.currentCodexExecutablePath)
        let persisted = try JSONDecoder().decode(
            LimitLensConfiguration.self,
            from: Data(contentsOf: url)
        )
        #expect(persisted.providers.codex.executablePath == LimitLensConfiguration.currentCodexExecutablePath)
    }

    @Test("Custom Codex paths are not replaced automatically")
    func customCodexPathIsPreserved() {
        var configuration = LimitLensConfiguration.defaults
        configuration.providers.codex.executablePath = "/custom/codex"

        let migrated = configuration.migrateLegacyCodexExecutablePath(
            isExecutable: { $0 == LimitLensConfiguration.currentCodexExecutablePath }
        )

        #expect(migrated == false)
        #expect(configuration.providers.codex.executablePath == "/custom/codex")
    }

    @Test("Saves and reloads configuration")
    func savesAndReloadsConfiguration() {
        let url = temporaryConfigURL()
        let store = LimitLensConfigurationStore(url: url)
        store.configuration.providers.codex.isEnabled = false
        store.configuration.providers.cursor.stateDatabasePath = "/tmp/cursor-state.vscdb"
        store.configuration.privacy.menuBarDisplay = .hidden
        store.configuration.appearance = .terminal
        store.save()

        let reloaded = LimitLensConfigurationStore(url: url)

        #expect(reloaded.configuration.providers.codex.isEnabled == false)
        #expect(reloaded.configuration.providers.cursor.stateDatabasePath == "/tmp/cursor-state.vscdb")
        #expect(reloaded.configuration.privacy.menuBarDisplay == .hidden)
        #expect(reloaded.configuration.privacy.hidesProviderNames == true)
        #expect(reloaded.configuration.appearance == .terminal)
    }

    @Test("Persists pulse appearance")
    func persistsPulseAppearance() {
        let url = temporaryConfigURL()
        let store = LimitLensConfigurationStore(url: url)
        store.configuration.appearance = .pulse
        store.save()

        let reloaded = LimitLensConfigurationStore(url: url)
        #expect(reloaded.configuration.appearance == .pulse)
        #expect(AppAppearance.allCases.map(\.rawValue) == ["classic", "studio", "terminal", "pulse", "harbor"])
    }

    @Test("Persists harbor appearance")
    func persistsHarborAppearance() {
        let url = temporaryConfigURL()
        let store = LimitLensConfigurationStore(url: url)
        store.configuration.appearance = .harbor
        store.save()

        let reloaded = LimitLensConfigurationStore(url: url)
        #expect(reloaded.configuration.appearance == .harbor)
    }

    @Test("Legacy config defaults setup to dismissed")
    func legacyConfigDefaultsSetupToDismissed() throws {
        let url = temporaryConfigURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(#"{"providers":{"codex":{"isEnabled":true,"executablePath":"/x"},"cursor":{"isEnabled":true,"stateDatabasePath":"/y"},"devin":{"isEnabled":true,"stateDatabasePath":"/z"},"openCodeGo":{"isEnabled":true,"configPath":"/w"}},"privacy":{"menuBarDisplay":"logos"}}"#.utf8).write(to: url)

        let store = LimitLensConfigurationStore(url: url)

        #expect(store.configuration.setup.showsFirstLaunchSetup == false)
        #expect(store.configuration.appearance == .classic)
    }

    @Test("Legacy hidesProviderNames config migrates to menuBarDisplay")
    func legacyHidesProviderNamesMigratesToMenuBarDisplay() throws {
        let url = temporaryConfigURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(#"{"providers":{"codex":{"isEnabled":true,"executablePath":"/x"},"cursor":{"isEnabled":true,"stateDatabasePath":"/y"},"devin":{"isEnabled":true,"stateDatabasePath":"/z"},"openCodeGo":{"isEnabled":true,"configPath":"/w"}},"privacy":{"hidesProviderNames":true}}"#.utf8).write(to: url)

        let store = LimitLensConfigurationStore(url: url)

        #expect(store.configuration.privacy.menuBarDisplay == .hidden)
        #expect(store.configuration.privacy.hidesProviderNames == true)
    }

    @Test("Legacy visible config migrates to logos menu bar display")
    func legacyVisibleConfigMigratesToLogos() throws {
        let url = temporaryConfigURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(#"{"providers":{"codex":{"isEnabled":true,"executablePath":"/x"},"cursor":{"isEnabled":true,"stateDatabasePath":"/y"},"devin":{"isEnabled":true,"stateDatabasePath":"/z"},"openCodeGo":{"isEnabled":true,"configPath":"/w"}},"privacy":{"hidesProviderNames":false}}"#.utf8).write(to: url)

        let store = LimitLensConfigurationStore(url: url)

        #expect(store.configuration.privacy.menuBarDisplay == .logos)
        #expect(store.configuration.privacy.hidesProviderNames == false)
    }

    @Test("Bad JSON is preserved and defaults are used")
    func badJSONIsPreserved() throws {
        let url = temporaryConfigURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{".utf8).write(to: url)

        let store = LimitLensConfigurationStore(url: url)
        let invalidURL = url.deletingLastPathComponent().appendingPathComponent("config.invalid.json")

        #expect(store.configuration == .defaults)
        #expect(FileManager.default.fileExists(atPath: invalidURL.path))
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test("Reset restores defaults")
    func resetRestoresDefaults() {
        let url = temporaryConfigURL()
        let store = LimitLensConfigurationStore(url: url)
        store.configuration.providers.devin.isEnabled = false
        store.configuration.providers.openCodeGo.configPath = "/tmp/custom.json"
        store.resetToDefaults()

        #expect(store.configuration == .defaults)
        #expect(LimitLensConfigurationStore(url: url).configuration == .defaults)
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

    @Test("Defaults include refresh and notification configuration")
    func defaultsIncludeRefreshAndNotificationConfiguration() {
        let defaults = LimitLensConfiguration.defaults

        #expect(defaults.refresh.intervalSeconds == 300)
        #expect(defaults.refresh.retryEnabled == true)
        #expect(defaults.refresh.maxRetryAttempts == 3)
        #expect(defaults.notifications.enabled == false)
        #expect(defaults.notifications.criticalUsage == true)
        #expect(defaults.notifications.billingExpiring == true)
        #expect(defaults.notifications.providerUnavailable == true)
        #expect(defaults.notifications.quietHoursStartHour == nil)
        #expect(defaults.notifications.quietHoursEndHour == nil)
        #expect(defaults.notifications.perProvider == PerProviderNotificationFlags())
        #expect(defaults.notifications.thresholds == PerProviderThresholds())
        #expect(defaults.notifications.criticalThreshold(for: .codex) == 90)
        #expect(defaults.notifications.dailyDigest == false)
        #expect(defaults.notifications.dailyDigestHour == 9)
    }

    @Test("Privacy config round-trips secondary tinting and auto-switch fields")
    func privacyConfigRoundTripsNewFields() {
        let url = temporaryConfigURL()
        let store = LimitLensConfigurationStore(url: url)
        store.configuration.privacy.menuBarDisplay = .auto
        store.configuration.privacy.secondaryLimitTintingEnabled = false
        store.configuration.privacy.autoSwitchIntervalSeconds = 15
        store.save()

        let reloaded = LimitLensConfigurationStore(url: url)

        #expect(reloaded.configuration.privacy.menuBarDisplay == .auto)
        #expect(reloaded.configuration.privacy.secondaryLimitTintingEnabled == false)
        #expect(reloaded.configuration.privacy.autoSwitchIntervalSeconds == 15)
    }

    @Test("Auto-switch interval sanitizes invalid values to nearest valid option")
    func autoSwitchIntervalSanitizesInvalidValues() {
        #expect(PrivacyConfiguration.sanitizedAutoSwitchInterval(7) == 5)
        #expect(PrivacyConfiguration.sanitizedAutoSwitchInterval(20) == 15)
        #expect(PrivacyConfiguration.sanitizedAutoSwitchInterval(45) == 30)
        #expect(PrivacyConfiguration.sanitizedAutoSwitchInterval(10) == 10)
    }

    @Test("Legacy config without new privacy fields uses defaults")
    func legacyConfigWithoutNewPrivacyFieldsUsesDefaults() throws {
        let url = temporaryConfigURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(#"{"providers":{"codex":{"isEnabled":true,"executablePath":"/x"},"cursor":{"isEnabled":true,"stateDatabasePath":"/y"},"devin":{"isEnabled":true,"stateDatabasePath":"/z"},"openCodeGo":{"isEnabled":true,"configPath":"/w"}},"privacy":{"menuBarDisplay":"logos"}}"#.utf8).write(to: url)

        let store = LimitLensConfigurationStore(url: url)

        #expect(store.configuration.privacy.secondaryLimitTintingEnabled == true)
        #expect(store.configuration.privacy.autoSwitchIntervalSeconds == 10)
    }

    @Test("Per-provider thresholds round-trip through save and reload")
    func perProviderThresholdsRoundTrip() {
        let url = temporaryConfigURL()
        let store = LimitLensConfigurationStore(url: url)
        store.configuration.notifications.thresholds.codex = 50
        store.configuration.notifications.thresholds.cursor = 75
        store.save()

        let reloaded = LimitLensConfigurationStore(url: url)

        #expect(reloaded.configuration.notifications.thresholds.codex == 50)
        #expect(reloaded.configuration.notifications.thresholds.cursor == 75)
        #expect(reloaded.configuration.notifications.thresholds.devin == nil)
        #expect(reloaded.configuration.notifications.thresholds.openCodeGo == nil)
        #expect(reloaded.configuration.notifications.criticalThreshold(for: .codex) == 50)
        #expect(reloaded.configuration.notifications.criticalThreshold(for: .devin) == 90)
    }

    @Test("Daily digest configuration round-trips through save and reload")
    func dailyDigestRoundTrips() {
        let url = temporaryConfigURL()
        let store = LimitLensConfigurationStore(url: url)
        store.configuration.notifications.dailyDigest = true
        store.configuration.notifications.dailyDigestHour = 14
        store.save()

        let reloaded = LimitLensConfigurationStore(url: url)

        #expect(reloaded.configuration.notifications.dailyDigest == true)
        #expect(reloaded.configuration.notifications.dailyDigestHour == 14)
    }

    @Test("Daily digest hour clamps to valid range")
    func dailyDigestHourClamps() throws {
        let tooHigh = #"{"enabled":true,"dailyDigest":true,"dailyDigestHour":99}"#
        let config = try JSONDecoder().decode(NotificationConfiguration.self, from: Data(tooHigh.utf8))
        #expect(config.dailyDigestHour == 23)

        let tooLow = #"{"enabled":true,"dailyDigest":true,"dailyDigestHour":-5}"#
        let config2 = try JSONDecoder().decode(NotificationConfiguration.self, from: Data(tooLow.utf8))
        #expect(config2.dailyDigestHour == 0)
    }

    @Test("Refresh interval round-trips through save and reload")
    func refreshIntervalRoundTrips() {
        let url = temporaryConfigURL()
        let store = LimitLensConfigurationStore(url: url)
        store.configuration.refresh.intervalSeconds = 900
        store.configuration.refresh.retryEnabled = false
        store.configuration.refresh.maxRetryAttempts = 5
        store.save()

        let reloaded = LimitLensConfigurationStore(url: url)

        #expect(reloaded.configuration.refresh.intervalSeconds == 900)
        #expect(reloaded.configuration.refresh.retryEnabled == false)
        #expect(reloaded.configuration.refresh.maxRetryAttempts == 5)
    }

    @Test("Notification configuration round-trips through save and reload")
    func notificationConfigurationRoundTrips() {
        let url = temporaryConfigURL()
        let store = LimitLensConfigurationStore(url: url)
        store.configuration.notifications.enabled = true
        store.configuration.notifications.criticalUsage = false
        store.configuration.notifications.quietHoursStartHour = 22
        store.configuration.notifications.quietHoursEndHour = 7
        store.configuration.notifications.perProvider.codex = false
        store.save()

        let reloaded = LimitLensConfigurationStore(url: url)

        #expect(reloaded.configuration.notifications.enabled == true)
        #expect(reloaded.configuration.notifications.criticalUsage == false)
        #expect(reloaded.configuration.notifications.quietHoursStartHour == 22)
        #expect(reloaded.configuration.notifications.quietHoursEndHour == 7)
        #expect(reloaded.configuration.notifications.perProvider.codex == false)
        #expect(reloaded.configuration.notifications.perProvider.cursor == true)
    }

    @Test("Legacy config without refresh or notifications keys uses defaults")
    func legacyConfigDefaultsRefreshAndNotifications() throws {
        let url = temporaryConfigURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(#"{"providers":{"codex":{"isEnabled":true,"executablePath":"/x"},"cursor":{"isEnabled":true,"stateDatabasePath":"/y"},"devin":{"isEnabled":true,"stateDatabasePath":"/z"},"openCodeGo":{"isEnabled":true,"configPath":"/w"}},"privacy":{"menuBarDisplay":"logos"}}"#.utf8).write(to: url)

        let store = LimitLensConfigurationStore(url: url)

        #expect(store.configuration.refresh == RefreshConfiguration())
        #expect(store.configuration.notifications == NotificationConfiguration())
    }

    @Test("Refresh interval sanitizes invalid values to nearest valid interval")
    func refreshIntervalSanitizesInvalidValues() {
        #expect(RefreshConfiguration.sanitizedInterval(60) == 60)
        #expect(RefreshConfiguration.sanitizedInterval(180) == 180)
        #expect(RefreshConfiguration.sanitizedInterval(300) == 300)
        #expect(RefreshConfiguration.sanitizedInterval(900) == 900)
        #expect(RefreshConfiguration.sanitizedInterval(1800) == 1800)
        // Custom values are clamped to 1–60 minute range
        #expect(RefreshConfiguration.sanitizedInterval(100) == 100)
        #expect(RefreshConfiguration.sanitizedInterval(200) == 200)
        #expect(RefreshConfiguration.sanitizedInterval(600) == 600)
        #expect(RefreshConfiguration.sanitizedInterval(1200) == 1200)
        #expect(RefreshConfiguration.sanitizedInterval(0) == 60)
        #expect(RefreshConfiguration.sanitizedInterval(9999) == 3600)
    }

    @Test("Refresh configuration clamps invalid values on decode")
    func refreshConfigurationClampsOnDecode() throws {
        let json = #"{"intervalSeconds":12345,"retryEnabled":false,"maxRetryAttempts":-2}"#
        let config = try JSONDecoder().decode(RefreshConfiguration.self, from: Data(json.utf8))

        #expect(config.intervalSeconds == 3600)
        #expect(config.retryEnabled == false)
        #expect(config.maxRetryAttempts == 0)
    }

    private func temporaryConfigURL() -> URL {
        temporaryDirectory().appendingPathComponent("config.json")
    }

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LimitLensTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
