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
    @State private var expandedProvider: ProviderTab?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.configuration.setup.showsFirstLaunchSetup {
                firstLaunchSetupView
            }

            providersSection
            openCodeGoAuthSection
            menuBarSection
            refreshSection
            notificationsSection
            resetSection
        }
        .onAppear {
            if !didLoadConfig {
                didLoadConfig = true
                loadOpenCodeGoDashboardConfig()
            }
        }
    }

    // MARK: - Providers

    private var providersSection: some View {
        SectionBlock {
            VStack(alignment: .leading, spacing: 10) {
                settingsSectionHeader(
                    title: "Providers",
                    systemImage: "checkmark.circle",
                    detail: "\(enabledProviderCount) of \(ProviderTab.providerCases.count) enabled"
                )

                VStack(spacing: 6) {
                    ForEach(ProviderTab.providerCases) { tab in
                        providerRow(tab)
                    }
                }
            }
        }
    }

    private func providerRow(_ tab: ProviderTab) -> some View {
        let isEnabled = viewModel.isProviderEnabled(tab)
        let isExpanded = expandedProvider == tab
        let hasWarning = pathWarning(for: tab) != nil

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Toggle("", isOn: providerEnabledBinding(tab))
                    .toggleStyle(.switch)
                    .scaleEffect(0.75)
                    .labelsHidden()

                Image(systemName: providerIcon(tab.systemImage, hidesProviderNames: viewModel.hidesProviderNames))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isEnabled ? .primary : .secondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 1) {
                    Text(providerName(tab.displayName, privateName: tab.privateName, hidesProviderNames: viewModel.hidesProviderNames))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isEnabled ? .primary : .secondary)
                    if hasWarning {
                        Text("Needs attention")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.orange)
                    } else if isEnabled {
                        Text(pathLabel(for: tab))
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        expandedProvider = isExpanded ? nil : tab
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .disabled(!isEnabled)
            }
            .padding(.vertical, 4)

            if isExpanded, isEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        TextField(pathPlaceholder(for: tab), text: pathBinding(for: tab))
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)

                        Button {
                            choosePath(for: tab)
                        } label: {
                            Image(systemName: "folder")
                        }
                        .buttonStyle(.borderless)
                        .help("Choose file")

                        Button {
                            resetProviderPath(tab)
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                        }
                        .buttonStyle(.borderless)
                        .help("Reset to default")
                    }

                    if let warning = pathWarning(for: tab) {
                        StatusLine(icon: "exclamationmark.triangle", color: .orange, text: warning)
                    }
                }
                .padding(.top, 4)
                .padding(.leading, 34)
                .padding(.bottom, 4)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.secondary.opacity(0.06))
        )
    }

    // MARK: - OpenCode Go Auth

    private var openCodeGoAuthSection: some View {
        SectionBlock {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    settingsSectionHeader(
                        title: providerName("OpenCode Go", privateName: "Provider 4", hidesProviderNames: viewModel.hidesProviderNames),
                        systemImage: providerIcon("key", hidesProviderNames: viewModel.hidesProviderNames),
                        detail: nil
                    )
                    Spacer()
                    Button {
                        openOpenCodeGoDashboard()
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.borderless)
                    .help("Open dashboard")
                }

                Text("Paste your workspace ID and browser auth cookie to track usage from the web dashboard.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 6) {
                    TextField("Workspace ID or dashboard URL", text: $openCodeGoWorkspaceInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)

                    SecureField("Auth cookie", text: $openCodeGoAuthCookieInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                }

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
        }
    }

    // MARK: - Menu Bar

    private var menuBarSection: some View {
        SectionBlock {
            VStack(alignment: .leading, spacing: 10) {
                settingsSectionHeader(
                    title: "Menu bar",
                    systemImage: "menubar.rectangle",
                    detail: nil
                )

                Picker("Display mode", selection: menuBarDisplayBinding) {
                    Text("Logos").tag(MenuBarDisplay.logos)
                    Text("Countdowns").tag(MenuBarDisplay.countdowns)
                    Text("Hidden").tag(MenuBarDisplay.hidden)
                }
                .pickerStyle(.segmented)
                .font(.caption.weight(.semibold))

                Text(menuBarDisplayDescription)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var menuBarDisplayDescription: String {
        switch viewModel.configuration.privacy.menuBarDisplay {
        case .logos: return "Colored progress rings with provider icons."
        case .countdowns: return "Compact pills with time-remaining text."
        case .hidden: return "Anonymizes provider names throughout the UI."
        }
    }

    // MARK: - Refresh

    private var refreshSection: some View {
        SectionBlock {
            VStack(alignment: .leading, spacing: 10) {
                settingsSectionHeader(
                    title: "Refresh",
                    systemImage: "arrow.clockwise",
                    detail: nil
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text("Interval")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Picker("Interval", selection: refreshIntervalPickerBinding) {
                        Text("1m").tag(60)
                        Text("3m").tag(180)
                        Text("5m").tag(300)
                        Text("15m").tag(900)
                        Text("30m").tag(1800)
                        Text("Custom").tag(0)
                    }
                    .pickerStyle(.segmented)
                    .font(.caption.weight(.semibold))

                    if viewModel.configuration.refresh.intervalSeconds > 1800
                        || !RefreshConfiguration.validIntervals.contains(viewModel.configuration.refresh.intervalSeconds)
                    {
                        HStack(spacing: 8) {
                            Text("Custom")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Stepper(
                                "\(viewModel.configuration.refresh.intervalSeconds / 60) min",
                                value: refreshCustomMinutesBinding,
                                in: 1...60
                            )
                            .font(.caption)
                        }
                        .padding(.leading, 4)
                    }
                }

                Toggle("Retry on failure", isOn: retryEnabledBinding)
                    .font(.caption)

                if viewModel.configuration.refresh.retryEnabled {
                    Stepper("Attempts: \(viewModel.configuration.refresh.maxRetryAttempts)",
                            value: retryAttemptsBinding,
                            in: 1...10)
                        .font(.caption)
                }
            }
        }
    }

    // MARK: - Reset

    private var resetSection: some View {
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

    // MARK: - First launch

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
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.accentColor.opacity(0.09))
        )
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        SectionBlock {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    settingsSectionHeader(
                        title: "Notifications",
                        systemImage: "bell",
                        detail: nil
                    )
                    Toggle("", isOn: notificationsEnabledBinding)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .scaleEffect(0.75)
                }

                if viewModel.configuration.notifications.enabled {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Critical usage", isOn: notificationsCriticalBinding)
                            .font(.caption2)
                        Toggle("Billing expiring", isOn: notificationsBillingBinding)
                            .font(.caption2)
                        Toggle("Provider unavailable", isOn: notificationsUnavailableBinding)
                            .font(.caption2)

                        Divider()

                        Button {
                            viewModel.sendTestNotification()
                        } label: {
                            Label("Send test notification", systemImage: "bell.badge")
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)

                        if let status = viewModel.notificationTestStatus {
                            Text(status)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            if viewModel.notificationNeedsSettings {
                                Button {
                                    viewModel.openNotificationSettings()
                                } label: {
                                    Label("Open System Settings", systemImage: "gear")
                                }
                                .buttonStyle(.borderless)
                                .font(.caption)
                            }
                        }

                        Divider()

                        Text("Per provider")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            notificationProviderToggle(.codex, label: "Codex")
                            notificationProviderToggle(.cursor, label: "Cursor")
                            notificationProviderToggle(.devin, label: "Devin")
                            notificationProviderToggle(.openCodeGo, label: "Go")
                        }

                        Divider()

                        Text("Critical threshold")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)

                        VStack(spacing: 4) {
                            notificationThresholdRow(.codex, label: "Codex")
                            notificationThresholdRow(.cursor, label: "Cursor")
                            notificationThresholdRow(.devin, label: "Devin")
                            notificationThresholdRow(.openCodeGo, label: "Go")
                        }

                        Divider()

                        HStack(spacing: 8) {
                            Text("Quiet hours")
                                .font(.caption2.weight(.semibold))
                            Spacer()
                            Picker("Start", selection: quietHoursStartBinding) {
                                Text("Off").tag(-1)
                                ForEach(0..<24, id: \.self) { hour in
                                    Text("\(hour):00").tag(hour)
                                }
                            }
                            .pickerStyle(.menu)
                            .font(.caption2)
                            .frame(width: 65)
                            Picker("End", selection: quietHoursEndBinding) {
                                Text("Off").tag(-1)
                                ForEach(0..<24, id: \.self) { hour in
                                    Text("\(hour):00").tag(hour)
                                }
                            }
                            .pickerStyle(.menu)
                            .font(.caption2)
                            .frame(width: 65)
                            .disabled(viewModel.configuration.notifications.quietHoursStartHour == nil)
                        }
                    }
                    .padding(.leading, 26)
                }
            }
        }
    }

    private func notificationProviderToggle(_ tab: ProviderTab, label: String) -> some View {
        Toggle(label, isOn: notificationPerProviderBinding(tab))
            .font(.caption2)
    }

    private func notificationThresholdRow(_ tab: ProviderTab, label: String) -> some View {
        HStack(spacing: 8) {
            Text(providerName(label, privateName: tab.privateName, hidesProviderNames: viewModel.hidesProviderNames))
                .font(.caption2)
                .frame(width: 80, alignment: .leading)
            Spacer()
            Picker("", selection: notificationThresholdEnabledBinding(tab)) {
                Text("Default (90%)").tag(false)
                Text("Custom").tag(true)
            }
            .pickerStyle(.menu)
            .font(.caption2)
            .frame(width: 120)
            .labelsHidden()

            if notificationThresholdEnabledBinding(tab).wrappedValue {
                Stepper(
                    "\(notificationThresholdValueBinding(tab).wrappedValue)%",
                    value: notificationThresholdValueBinding(tab),
                    in: 1...100
                )
                .font(.caption2)
                .frame(width: 70)
            }
        }
    }

    private func notificationThresholdEnabledBinding(_ tab: ProviderTab) -> Binding<Bool> {
        Binding(
            get: { notificationThresholdValue(tab) != nil },
            set: { enabled in
                viewModel.updateConfiguration {
                    let value = enabled ? NotificationConfiguration.defaultCriticalThreshold : nil
                    switch tab {
                    case .codex: $0.notifications.thresholds.codex = value
                    case .cursor: $0.notifications.thresholds.cursor = value
                    case .devin: $0.notifications.thresholds.devin = value
                    case .openCodeGo: $0.notifications.thresholds.openCodeGo = value
                    case .overview, .settings: break
                    }
                }
            }
        )
    }

    private func notificationThresholdValueBinding(_ tab: ProviderTab) -> Binding<Int> {
        Binding(
            get: { notificationThresholdValue(tab) ?? NotificationConfiguration.defaultCriticalThreshold },
            set: { value in
                viewModel.updateConfiguration {
                    switch tab {
                    case .codex: $0.notifications.thresholds.codex = value
                    case .cursor: $0.notifications.thresholds.cursor = value
                    case .devin: $0.notifications.thresholds.devin = value
                    case .openCodeGo: $0.notifications.thresholds.openCodeGo = value
                    case .overview, .settings: break
                    }
                }
            }
        )
    }

    private func notificationThresholdValue(_ tab: ProviderTab) -> Int? {
        switch tab {
        case .codex: return viewModel.configuration.notifications.thresholds.codex
        case .cursor: return viewModel.configuration.notifications.thresholds.cursor
        case .devin: return viewModel.configuration.notifications.thresholds.devin
        case .openCodeGo: return viewModel.configuration.notifications.thresholds.openCodeGo
        case .overview, .settings: return nil
        }
    }

    // MARK: - Helpers

    private func settingsSectionHeader(title: String, systemImage: String, detail: String?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            if let detail {
                Text(detail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var enabledProviderCount: Int {
        ProviderTab.providerCases.filter(viewModel.isProviderEnabled).count
    }

    private func pathLabel(for tab: ProviderTab) -> String {
        switch tab {
        case .codex: return "Executable"
        case .cursor: return "State database"
        case .devin: return "State database"
        case .openCodeGo: return "Config file"
        case .overview, .settings: return ""
        }
    }

    private func pathPlaceholder(for tab: ProviderTab) -> String {
        pathLabel(for: tab)
    }

    private func pathBinding(for tab: ProviderTab) -> Binding<String> {
        switch tab {
        case .codex: return codexPathBinding
        case .cursor: return cursorPathBinding
        case .devin: return devinPathBinding
        case .openCodeGo: return openCodeGoPathBinding
        case .overview, .settings:
            return .constant("")
        }
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

    private var refreshIntervalBinding: Binding<Int> {
        Binding(
            get: { viewModel.configuration.refresh.intervalSeconds },
            set: { value in
                viewModel.updateConfiguration { $0.refresh.intervalSeconds = value }
            }
        )
    }

    private var refreshIntervalPickerBinding: Binding<Int> {
        Binding(
            get: {
                let current = viewModel.configuration.refresh.intervalSeconds
                if RefreshConfiguration.validIntervals.contains(current) {
                    return current
                }
                return 0 // Custom
            },
            set: { value in
                if value == 0 {
                    // Switching to custom — keep current value if already custom, otherwise default to 10m
                    let current = viewModel.configuration.refresh.intervalSeconds
                    if RefreshConfiguration.validIntervals.contains(current) {
                        viewModel.updateConfiguration { $0.refresh.intervalSeconds = 600 }
                    }
                } else {
                    viewModel.updateConfiguration { $0.refresh.intervalSeconds = value }
                }
            }
        )
    }

    private var refreshCustomMinutesBinding: Binding<Int> {
        Binding(
            get: { viewModel.configuration.refresh.intervalSeconds / 60 },
            set: { minutes in
                viewModel.updateConfiguration { $0.refresh.intervalSeconds = max(1, minutes) * 60 }
            }
        )
    }

    private var retryEnabledBinding: Binding<Bool> {
        Binding(
            get: { viewModel.configuration.refresh.retryEnabled },
            set: { value in
                viewModel.updateConfiguration { $0.refresh.retryEnabled = value }
            }
        )
    }

    private var retryAttemptsBinding: Binding<Int> {
        Binding(
            get: { viewModel.configuration.refresh.maxRetryAttempts },
            set: { value in
                viewModel.updateConfiguration { $0.refresh.maxRetryAttempts = value }
            }
        )
    }

    private var notificationsEnabledBinding: Binding<Bool> {
        Binding(
            get: { viewModel.configuration.notifications.enabled },
            set: { value in viewModel.setNotificationsEnabled(value) }
        )
    }

    private var notificationsCriticalBinding: Binding<Bool> {
        Binding(
            get: { viewModel.configuration.notifications.criticalUsage },
            set: { value in viewModel.updateConfiguration { $0.notifications.criticalUsage = value } }
        )
    }

    private var notificationsBillingBinding: Binding<Bool> {
        Binding(
            get: { viewModel.configuration.notifications.billingExpiring },
            set: { value in viewModel.updateConfiguration { $0.notifications.billingExpiring = value } }
        )
    }

    private var notificationsUnavailableBinding: Binding<Bool> {
        Binding(
            get: { viewModel.configuration.notifications.providerUnavailable },
            set: { value in viewModel.updateConfiguration { $0.notifications.providerUnavailable = value } }
        )
    }

    private func notificationPerProviderBinding(_ tab: ProviderTab) -> Binding<Bool> {
        Binding(
            get: {
                switch tab {
                case .codex: return viewModel.configuration.notifications.perProvider.codex
                case .cursor: return viewModel.configuration.notifications.perProvider.cursor
                case .devin: return viewModel.configuration.notifications.perProvider.devin
                case .openCodeGo: return viewModel.configuration.notifications.perProvider.openCodeGo
                case .overview, .settings: return false
                }
            },
            set: { value in
                viewModel.updateConfiguration {
                    switch tab {
                    case .codex: $0.notifications.perProvider.codex = value
                    case .cursor: $0.notifications.perProvider.cursor = value
                    case .devin: $0.notifications.perProvider.devin = value
                    case .openCodeGo: $0.notifications.perProvider.openCodeGo = value
                    case .overview, .settings: break
                    }
                }
            }
        )
    }

    private var quietHoursStartBinding: Binding<Int> {
        Binding(
            get: { viewModel.configuration.notifications.quietHoursStartHour ?? -1 },
            set: { value in
                viewModel.updateConfiguration {
                    $0.notifications.quietHoursStartHour = value >= 0 ? value : nil
                }
            }
        )
    }

    private var quietHoursEndBinding: Binding<Int> {
        Binding(
            get: { viewModel.configuration.notifications.quietHoursEndHour ?? -1 },
            set: { value in
                viewModel.updateConfiguration {
                    $0.notifications.quietHoursEndHour = value >= 0 ? value : nil
                }
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
