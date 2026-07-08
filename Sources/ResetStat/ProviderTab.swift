import AppKit
import ResetStatCore
import SwiftUI

enum ProviderTab: String, CaseIterable, Identifiable {
    case overview
    case codex
    case cursor
    case devin
    case openCodeGo
    case settings

    static let providerCases: [ProviderTab] = [.codex, .cursor, .devin, .openCodeGo]

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .overview: return "Overview"
        case .codex: return "Codex"
        case .cursor: return "Cursor"
        case .devin: return "Devin"
        case .openCodeGo: return "OpenCode Go"
        case .settings: return "Settings"
        }
    }

    var privateName: String {
        switch self {
        case .overview: return "Overview"
        case .codex: return "Provider 1"
        case .cursor: return "Provider 2"
        case .devin: return "Provider 3"
        case .openCodeGo: return "Provider 4"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: return "speedometer"
        case .codex: return "terminal"
        case .cursor: return "cursorarrow"
        case .devin: return "sparkles"
        case .openCodeGo: return "chevron.left.forwardslash.chevron.right"
        case .settings: return "gearshape"
        }
    }

    var dashboardURL: URL? {
        switch self {
        case .codex: return URL(string: "https://chatgpt.com/#settings/AccountSettings")
        case .cursor: return URL(string: "https://www.cursor.com/settings")
        case .devin: return URL(string: "https://windsurf.com/settings")
        case .openCodeGo: return nil
        case .overview, .settings: return nil
        }
    }
}
