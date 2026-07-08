import AppKit
import ResetStatCore
import SwiftUI

struct SettingsSectionView: View {
    @ObservedObject var viewModel: UsageViewModel
    @Binding var selectedTab: ProviderTab
    @State private var openCodeGoWorkspaceInput = ""
    @State private var openCodeGoAuthCookieInput = ""
    @State private var openCodeGoSetupMessage: String?
    @State private var openCodeGoSetupMessageIsError = false
    @State private var didLoadConfig = false

    var body: some View {
        SectionBlock {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Settings", detail: "Providers", systemImage: "gearshape", hidesProviderNames: viewModel.hidesProviderNames)

                if viewModel.configuration.setup.showsFirstLaunchSetup {
                    firstLaunchSetupView
                }

                VStack(spacing: 10) {
                    settingsProviderRow(
                        tab: .codex,
                        pathTitle: "Executable",
                        path: codexPathBinding,
                        isEnabled: providerEnabledBinding(.codex)
                    )
                    settingsProviderRow(
                        tab: .cursor,
                        pathTitle: "State database",
                        path: cursorPathBinding,
                        isEnabled: providerEnabledBinding(.cursor)
                    )
                    settingsProviderRow(
                        tab: .devin,
                        pathTitle: "State database",
                        path: devinPathBinding,
                        isEnabled: providerEnabledBinding(.devin)
                    )
                    settingsProviderRow(
                        tab: .openCodeGo,
                        pathTitle: "Config file",
                        path: openCodeGoPathBinding,
                        isEnabled: providerEnabledBinding(.openCodeGo)
                    )
                    openCodeGoDashboardConfigView
                }

                Divider()

                Picker("Menu bar", selection: menuBarDisplayBinding) {
                    Text("Logos").tag(MenuBarDisplay.logos)
                    Text("Countdowns").tag(MenuBarDisplay.countdowns)
                    Text("Hidden").tag(MenuBarDisplay.hidden)
                }
                .pickerStyle(.segmented)
                .font(.caption.weight(.semibold))

                HStack {
                    Button("Reset all settings") {
                        viewModel.resetConfigurationToDefaults()
                        selectedTab = .overview
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    Spacer()
                    Text("Saved automatically")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .onAppear {
            if !didLoadConfig {
                didLoadConfig = true
                loadOpenCodeGoDashboardConfig()
            }
        }
    }

    private var firstLaunchSetupView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "checklist")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 16)
                Text("First setup")
                    .font(.caption.weight(.semibold))
                Spacer()
                Button {
                    completeFirstLaunchSetup()
                } label: {
                    Label("Done", systemImage: "checkmark")
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }

            Text("Detected providers are ready. Add OpenCode Go auth below or finish with the current setup.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.accentColor.opacity(0.09))
        )
    }

    private var openCodeGoDashboardConfigView: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: providerIcon("key", hidesProviderNames: viewModel.hidesProviderNames))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                Text(providerName("OpenCode Go dashboard", privateName: "Provider 4 dashboard", hidesProviderNames: viewModel.hidesProviderNames))
                    .font(.caption.weight(.semibold))
                Spacer()
                Button {
                    openOpenCodeGoDashboard()
                } label: {
                    Label("Open", systemImage: "globe")
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }

            TextField("Workspace ID or dashboard url", text: $openCodeGoWorkspaceInput)
                .textFieldStyle(.roundedBorder)
                .font(.caption)

            SecureField("auth cookie", text: $openCodeGoAuthCookieInput)
                .textFieldStyle(.roundedBorder)
                .font(.caption)

            HStack {
                Button {
                    reloadOpenCodeGoDashboardConfig()
                } label: {
                    Label("Reload", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .font(.caption)

                Spacer()

                Button {
                    saveOpenCodeGoDashboardConfig()
                } label: {
                    Label("Save & refresh", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .disabled(!canSaveOpenCodeGoDashboardConfig)
            }

            if let openCodeGoSetupMessage {
                StatusLine(
                    icon: openCodeGoSetupMessageIsError ? "exclamationmark.triangle" : "checkmark.circle",
                    color: openCodeGoSetupMessageIsError ? .orange : .green,
                    text: openCodeGoSetupMessage
                )
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.secondary.opacity(0.07))
        )
    }

    private func settingsProviderRow(
        tab: ProviderTab,
        pathTitle: String,
        path: Binding<String>,
        isEnabled: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Toggle("", isOn: isEnabled)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                Image(systemName: providerIcon(tab.systemImage, hidesProviderNames: viewModel.hidesProviderNames))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                Text(providerName(tab.displayName, privateName: tab.privateName, hidesProviderNames: viewModel.hidesProviderNames))
                    .font(.caption.weight(.semibold))
                Spacer()
                Button("Choose...") {
                    choosePath(for: tab)
                }
                .buttonStyle(.borderless)
                .font(.caption)
                Button("Reset") {
                    resetProviderPath(tab)
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }

            Text(pathTitle)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)

            TextField(pathTitle, text: path)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .disabled(!isEnabled.wrappedValue)

            if let warning = pathWarning(for: tab) {
                StatusLine(icon: "exclamationmark.triangle", color: .orange, text: warning)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.secondary.opacity(0.07))
        )
    }

    private var codexPathBinding: Binding<String> {
        Binding(
            get: { viewModel.configuration.providers.codex.executablePath },
            set: { value in
                viewModel.updateConfiguration { $0.providers.codex.executablePath = value }
            }
        )
    }

    private var cursorPathBinding: Binding<String> {
        Binding(
            get: { viewModel.configuration.providers.cursor.stateDatabasePath },
            set: { value in
                viewModel.updateConfiguration { $0.providers.cursor.stateDatabasePath = value }
            }
        )
    }

    private var devinPathBinding: Binding<String> {
        Binding(
            get: { viewModel.configuration.providers.devin.stateDatabasePath },
            set: { value in
                viewModel.updateConfiguration { $0.providers.devin.stateDatabasePath = value }
            }
        )
    }

    private var openCodeGoPathBinding: Binding<String> {
        Binding(
            get: { viewModel.configuration.providers.openCodeGo.configPath },
            set: { value in
                viewModel.updateConfiguration { $0.providers.openCodeGo.configPath = value }
            }
        )
    }

    private var menuBarDisplayBinding: Binding<MenuBarDisplay> {
        Binding(
            get: { viewModel.configuration.privacy.menuBarDisplay },
            set: { value in
                viewModel.updateConfiguration { $0.privacy.menuBarDisplay = value }
            }
        )
    }

    private func providerEnabledBinding(_ tab: ProviderTab) -> Binding<Bool> {
        Binding(
            get: { viewModel.isProviderEnabled(tab) },
            set: { value in
                viewModel.updateConfiguration { configuration in
                    switch tab {
                    case .codex:
                        configuration.providers.codex.isEnabled = value
                    case .cursor:
                        configuration.providers.cursor.isEnabled = value
                    case .devin:
                        configuration.providers.devin.isEnabled = value
                    case .openCodeGo:
                        configuration.providers.openCodeGo.isEnabled = value
                    case .overview, .settings:
                        break
                    }
                }
                if !value, selectedTab == tab {
                    selectedTab = .overview
                }
            }
        )
    }

    private func choosePath(for tab: ProviderTab) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = tab == .codex
        panel.canChooseFiles = true
        panel.prompt = "Choose"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        let path: String
        if tab == .codex, url.pathExtension == "app" {
            path = url.appendingPathComponent("Contents/Resources/codex").path
        } else {
            path = url.path
        }

        viewModel.updateConfiguration { configuration in
            switch tab {
            case .codex:
                configuration.providers.codex.executablePath = path
            case .cursor:
                configuration.providers.cursor.stateDatabasePath = path
            case .devin:
                configuration.providers.devin.stateDatabasePath = path
            case .openCodeGo:
                configuration.providers.openCodeGo.configPath = path
            case .overview, .settings:
                break
            }
        }
    }

    private func resetProviderPath(_ tab: ProviderTab) {
        viewModel.updateConfiguration { configuration in
            let defaults = ResetStatConfiguration.defaults
            switch tab {
            case .codex:
                configuration.providers.codex.executablePath = defaults.providers.codex.executablePath
            case .cursor:
                configuration.providers.cursor.stateDatabasePath = defaults.providers.cursor.stateDatabasePath
            case .devin:
                configuration.providers.devin.stateDatabasePath = defaults.providers.devin.stateDatabasePath
            case .openCodeGo:
                configuration.providers.openCodeGo.configPath = defaults.providers.openCodeGo.configPath
            case .overview, .settings:
                break
            }
        }
    }

    private func pathWarning(for tab: ProviderTab) -> String? {
        switch tab {
        case .codex:
            let path = viewModel.configuration.providers.codex.executablePath
            if !FileManager.default.fileExists(atPath: path) {
                return "Path does not exist."
            }
            if !FileManager.default.isExecutableFile(atPath: path) {
                return "Path is not executable."
            }
            return nil
        case .cursor:
            return fileWarning(path: viewModel.configuration.providers.cursor.stateDatabasePath)
        case .devin:
            return fileWarning(path: viewModel.configuration.providers.devin.stateDatabasePath)
        case .openCodeGo:
            let path = viewModel.configuration.providers.openCodeGo.configPath
            if let warning = fileWarning(path: path) {
                return warning
            }
            return openCodeGoConfigWarning(path: path)
        case .overview, .settings:
            return nil
        }
    }

    private func fileWarning(path: String) -> String? {
        FileManager.default.fileExists(atPath: path) ? nil : "Path does not exist."
    }

    private func openCodeGoConfigWarning(path: String) -> String? {
        OpenCodeGoProviderConfiguration(isEnabled: true, configPath: path).validationWarning
    }

    private var openCodeGoConfigURL: URL {
        URL(fileURLWithPath: viewModel.configuration.providers.openCodeGo.configPath)
    }

    private var canSaveOpenCodeGoDashboardConfig: Bool {
        !OpenCodeGoDashboardCredentials.normalizedWorkspaceId(from: openCodeGoWorkspaceInput).isEmpty &&
            !OpenCodeGoDashboardCredentials.normalizedAuthCookie(from: openCodeGoAuthCookieInput).isEmpty
    }

    private func completeFirstLaunchSetup() {
        viewModel.updateConfiguration { configuration in
            configuration.setup.showsFirstLaunchSetup = false
        }
    }

    private func loadOpenCodeGoDashboardConfig() {
        guard let credentials = OpenCodeGoDashboardConfigFile.loadIfPresent(from: openCodeGoConfigURL) else {
            return
        }

        openCodeGoWorkspaceInput = credentials.workspaceId
        openCodeGoAuthCookieInput = credentials.authCookie
    }

    private func reloadOpenCodeGoDashboardConfig() {
        guard let credentials = OpenCodeGoDashboardConfigFile.loadIfPresent(from: openCodeGoConfigURL) else {
            showOpenCodeGoSetupMessage("No saved OpenCode Go config found.", isError: true)
            return
        }

        openCodeGoWorkspaceInput = credentials.workspaceId
        openCodeGoAuthCookieInput = credentials.authCookie
        showOpenCodeGoSetupMessage("Loaded saved OpenCode Go config.", isError: false)
    }

    private func saveOpenCodeGoDashboardConfig() {
        do {
            let credentials = try OpenCodeGoDashboardCredentials(
                workspaceInput: openCodeGoWorkspaceInput,
                authCookieInput: openCodeGoAuthCookieInput
            )
            try OpenCodeGoDashboardConfigFile.save(credentials, to: openCodeGoConfigURL)

            openCodeGoWorkspaceInput = credentials.workspaceId
            openCodeGoAuthCookieInput = credentials.authCookie
            viewModel.updateConfiguration { configuration in
                configuration.providers.openCodeGo.isEnabled = true
                configuration.setup.showsFirstLaunchSetup = false
            }
            showOpenCodeGoSetupMessage("Saved OpenCode Go config.", isError: false)
            Task { await viewModel.refresh() }
        } catch let error as LocalizedError {
            showOpenCodeGoSetupMessage(error.errorDescription ?? "OpenCode Go config could not be saved.", isError: true)
        } catch {
            showOpenCodeGoSetupMessage("OpenCode Go config could not be saved.", isError: true)
        }
    }

    private func openOpenCodeGoDashboard() {
        NSWorkspace.shared.open(OpenCodeGoDashboardCredentials.dashboardURL(workspaceId: openCodeGoWorkspaceInput))
    }

    private func showOpenCodeGoSetupMessage(_ message: String, isError: Bool) {
        openCodeGoSetupMessage = message
        openCodeGoSetupMessageIsError = isError
    }
}
