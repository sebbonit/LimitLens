import Combine
import Foundation

@MainActor
final class ResetStatConfigurationStore: ObservableObject {
    @Published var configuration: ResetStatConfiguration

    let url: URL

    init(url: URL = .defaultResetStatConfigurationURL) {
        self.url = url
        self.configuration = Self.load(from: url)
    }

    func save() {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(configuration)
            try data.write(to: url, options: .atomic)
        } catch {
            assertionFailure("Failed to save ResetStat configuration: \(error)")
        }
    }

    func resetToDefaults() {
        configuration = .defaults
        save()
    }

    private static func load(from url: URL) -> ResetStatConfiguration {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .detected()
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(ResetStatConfiguration.self, from: data)
        } catch {
            preserveInvalidConfiguration(at: url)
            return .defaults
        }
    }

    private static func preserveInvalidConfiguration(at url: URL) {
        let invalidURL = url.deletingLastPathComponent().appendingPathComponent("config.invalid.json")
        try? FileManager.default.removeItem(at: invalidURL)
        try? FileManager.default.moveItem(at: url, to: invalidURL)
    }
}
