import Foundation

enum MenuBarDisplay: String, Codable, Equatable, CaseIterable {
    case logos
    case countdowns
    case hidden
}

struct ResetStatConfiguration: Codable, Equatable {
    var providers: ProviderConfiguration
    var privacy: PrivacyConfiguration

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
            privacy: defaults.privacy
        )
    }

    private static func firstMatchingPath(_ paths: [String], matches: (String) -> Bool) -> String? {
        paths.first(where: matches)
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
        guard FileManager.default.fileExists(atPath: configPath) else {
            return "Path does not exist."
        }

        struct Config: Decodable {
            let workspaceId: String?
            let authCookie: String?
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
            let config = try JSONDecoder().decode(Config.self, from: data)
            if config.workspaceId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false ||
                config.authCookie?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                return "Config must include workspaceId and authCookie."
            }
            return nil
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
