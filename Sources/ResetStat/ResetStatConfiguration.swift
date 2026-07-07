import Foundation

enum MenuBarDisplay: String, Codable, Equatable, CaseIterable {
    case logos
    case countdowns
    case hidden
}

struct ResetStatConfiguration: Codable, Equatable {
    var providers: ProviderConfiguration
    var privacy: PrivacyConfiguration
    var setup: SetupConfiguration

    init(
        providers: ProviderConfiguration,
        privacy: PrivacyConfiguration,
        setup: SetupConfiguration = SetupConfiguration()
    ) {
        self.providers = providers
        self.privacy = privacy
        self.setup = setup
    }

    static let defaults = ResetStatConfiguration(
        providers: ProviderConfiguration(
            codex: CodexProviderConfiguration(
                isEnabled: true,
                executablePath: "/Applications/Codex.app/Contents/Resources/codex"
            ),
            cursor: CursorProviderConfiguration(
                isEnabled: true,
                stateDatabasePath: "\(NSHomeDirectory())/Library/Application Support/Cursor/User/globalStorage/state.vscdb"
            ),
            devin: DevinProviderConfiguration(
                isEnabled: true,
                stateDatabasePath: "\(NSHomeDirectory())/Library/Application Support/Devin/User/globalStorage/state.vscdb"
            ),
            openCodeGo: OpenCodeGoProviderConfiguration(
                isEnabled: true,
                configPath: "\(NSHomeDirectory())/.config/opencode/opencode-quota/opencode-go.json"
            )
        ),
        privacy: PrivacyConfiguration(menuBarDisplay: .logos)
    )

    enum CodingKeys: String, CodingKey {
        case providers
        case privacy
        case setup
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.providers = try container.decode(ProviderConfiguration.self, forKey: .providers)
        self.privacy = try container.decode(PrivacyConfiguration.self, forKey: .privacy)
        self.setup = try container.decodeIfPresent(SetupConfiguration.self, forKey: .setup) ?? SetupConfiguration()
    }

    static func detected(
        fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) },
        isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) -> ResetStatConfiguration {
        let defaults = ResetStatConfiguration.defaults
        let codexPath = firstMatchingPath(
            [
                defaults.providers.codex.executablePath,
                "\(NSHomeDirectory())/Applications/Codex.app/Contents/Resources/codex"
            ],
            matches: isExecutable
        ) ?? defaults.providers.codex.executablePath
        let cursorPath = firstMatchingPath(
            [
                defaults.providers.cursor.stateDatabasePath,
                "\(NSHomeDirectory())/Library/Application Support/Cursor/User/globalStorage/state.vscdb"
            ],
            matches: fileExists
        ) ?? defaults.providers.cursor.stateDatabasePath
        let devinPath = firstMatchingPath(
            [
                defaults.providers.devin.stateDatabasePath,
                "\(NSHomeDirectory())/Library/Application Support/Devin/User/globalStorage/state.vscdb"
            ],
            matches: fileExists
        ) ?? defaults.providers.devin.stateDatabasePath
        let openCodeGoPath = firstMatchingPath(
            [
                defaults.providers.openCodeGo.configPath,
                "\(NSHomeDirectory())/.config/opencode/opencode-quota/opencode-go.json"
            ],
            matches: fileExists
        ) ?? defaults.providers.openCodeGo.configPath

        return ResetStatConfiguration(
            providers: ProviderConfiguration(
                codex: CodexProviderConfiguration(isEnabled: isExecutable(codexPath), executablePath: codexPath),
                cursor: CursorProviderConfiguration(isEnabled: fileExists(cursorPath), stateDatabasePath: cursorPath),
                devin: DevinProviderConfiguration(isEnabled: fileExists(devinPath), stateDatabasePath: devinPath),
                openCodeGo: OpenCodeGoProviderConfiguration(isEnabled: fileExists(openCodeGoPath), configPath: openCodeGoPath)
            ),
            privacy: defaults.privacy,
            setup: SetupConfiguration(showsFirstLaunchSetup: true)
        )
    }

    private static func firstMatchingPath(_ paths: [String], matches: (String) -> Bool) -> String? {
        paths.first(where: matches)
    }
}

struct SetupConfiguration: Codable, Equatable {
    var showsFirstLaunchSetup: Bool

    init(showsFirstLaunchSetup: Bool = false) {
        self.showsFirstLaunchSetup = showsFirstLaunchSetup
    }
}

struct ProviderConfiguration: Codable, Equatable {
    var codex: CodexProviderConfiguration
    var cursor: CursorProviderConfiguration
    var devin: DevinProviderConfiguration
    var openCodeGo: OpenCodeGoProviderConfiguration
}

struct CodexProviderConfiguration: Codable, Equatable {
    var isEnabled: Bool
    var executablePath: String
}

struct CursorProviderConfiguration: Codable, Equatable {
    var isEnabled: Bool
    var stateDatabasePath: String
}

struct DevinProviderConfiguration: Codable, Equatable {
    var isEnabled: Bool
    var stateDatabasePath: String
}

struct OpenCodeGoProviderConfiguration: Codable, Equatable {
    var isEnabled: Bool
    var configPath: String

    var validationWarning: String? {
        OpenCodeGoDashboardConfigFile.validationWarning(at: URL(fileURLWithPath: configPath))
    }
}

enum OpenCodeGoDashboardCredentialsError: LocalizedError, Equatable {
    case missingWorkspaceId
    case missingAuthCookie

    var errorDescription: String? {
        switch self {
        case .missingWorkspaceId:
            return "Enter an OpenCode workspace ID."
        case .missingAuthCookie:
            return "Enter the opencode.ai auth cookie."
        }
    }
}

struct OpenCodeGoDashboardCredentials: Codable, Equatable {
    var workspaceId: String
    var authCookie: String

    init(workspaceId: String, authCookie: String) {
        self.workspaceId = workspaceId
        self.authCookie = authCookie
    }

    init(workspaceInput: String, authCookieInput: String) throws {
        let workspaceId = Self.normalizedWorkspaceId(from: workspaceInput)
        let authCookie = Self.normalizedAuthCookie(from: authCookieInput)

        guard !workspaceId.isEmpty else {
            throw OpenCodeGoDashboardCredentialsError.missingWorkspaceId
        }
        guard !authCookie.isEmpty else {
            throw OpenCodeGoDashboardCredentialsError.missingAuthCookie
        }

        self.workspaceId = workspaceId
        self.authCookie = authCookie
    }

    static func normalizedWorkspaceId(from input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let withoutFragment = trimmed.split(separator: "#", maxSplits: 1).first.map(String.init) ?? trimmed
        let withoutQuery = withoutFragment.split(separator: "?", maxSplits: 1).first.map(String.init) ?? withoutFragment
        let pathLike = withoutQuery.replacingOccurrences(of: "://", with: "/")
        let parts = pathLike
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty }

        if let workspaceIndex = parts.lastIndex(of: "workspace"),
           parts.indices.contains(workspaceIndex + 1) {
            return percentDecoded(parts[workspaceIndex + 1])
        }

        if parts.last == "go", parts.count >= 2 {
            return percentDecoded(parts[parts.count - 2])
        }

        if withoutQuery.contains("://") || parts.contains(where: { $0.localizedCaseInsensitiveContains("opencode.ai") }) {
            return ""
        }

        return percentDecoded(withoutQuery.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }

    static func normalizedAuthCookie(from input: String) -> String {
        let raw = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmed: String
        if raw.range(of: "Cookie:", options: [.caseInsensitive, .anchored]) != nil {
            trimmed = String(raw.dropFirst("Cookie:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            trimmed = raw
        }
        guard !trimmed.isEmpty else { return "" }

        for pair in trimmed.split(separator: ";") {
            let pieces = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard pieces.count == 2,
                  pieces[0].trimmingCharacters(in: .whitespacesAndNewlines) == "auth" else {
                continue
            }
            return pieces[1].trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return trimmed
    }

    private static func percentDecoded(_ value: String) -> String {
        (value.removingPercentEncoding ?? value)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum OpenCodeGoDashboardConfigFile {
    private struct Payload: Codable {
        let workspaceId: String?
        let authCookie: String?
    }

    static func load(from url: URL) throws -> OpenCodeGoDashboardCredentials {
        let data = try Data(contentsOf: url)
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        return try OpenCodeGoDashboardCredentials(
            workspaceInput: payload.workspaceId ?? "",
            authCookieInput: payload.authCookie ?? ""
        )
    }

    static func loadIfPresent(from url: URL) -> OpenCodeGoDashboardCredentials? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? load(from: url)
    }

    static func save(_ credentials: OpenCodeGoDashboardCredentials, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(credentials)
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    static func validationWarning(at url: URL) -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return "Path does not exist."
        }

        do {
            _ = try load(from: url)
            return nil
        } catch OpenCodeGoDashboardCredentialsError.missingWorkspaceId,
                OpenCodeGoDashboardCredentialsError.missingAuthCookie {
            return "Config must include workspaceId and authCookie."
        } catch {
            return "Config JSON is invalid."
        }
    }
}

struct PrivacyConfiguration: Codable, Equatable {
    var menuBarDisplay: MenuBarDisplay

    var hidesProviderNames: Bool {
        menuBarDisplay == .hidden
    }

    init(menuBarDisplay: MenuBarDisplay = .logos) {
        self.menuBarDisplay = menuBarDisplay
    }

    enum CodingKeys: String, CodingKey {
        case menuBarDisplay
        case hidesProviderNames
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let display = try container.decodeIfPresent(MenuBarDisplay.self, forKey: .menuBarDisplay) {
            self.menuBarDisplay = display
        } else if try container.decodeIfPresent(Bool.self, forKey: .hidesProviderNames) == true {
            self.menuBarDisplay = .hidden
        } else {
            self.menuBarDisplay = .logos
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(menuBarDisplay, forKey: .menuBarDisplay)
    }
}

extension URL {
    static var defaultResetStatConfigurationURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: "\(NSHomeDirectory())/Library/Application Support")
        return directory
            .appendingPathComponent("ResetStat", isDirectory: true)
            .appendingPathComponent("config.json")
    }
}
