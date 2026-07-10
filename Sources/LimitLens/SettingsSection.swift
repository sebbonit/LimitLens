import AppKit
import LimitLensCore
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
    @State private var collapsedSections: Set<String> = ["diagnostics"]
    @State private var showClearExhaustionConfirmation = false
    @State private var didClearExhaustionHistory = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if viewModel.configuration.setup.showsFirstLaunchSetup {
                    firstLaunchSetupView
                }

                collapsibleSection("providers", title: "Providers", systemImage: "checkmark.circle", detail: "\(enabledProviderCount) of \(ProviderTab.providerCases.count) enabled") {
                    providersContent
                }
                collapsibleSection("opencodego", title: openCodeGoDisplayName, systemImage: providerIcon("key", hidesProviderNames: viewModel.hidesProviderNames)) {
                    openCodeGoAuthContent
                }
                collapsibleSection("menubar", title: "Menu bar", systemImage: "menubar.rectangle") {
                    menuBarContent
                }
                collapsibleSection("refresh", title: "Refresh", systemImage: "arrow.clockwise") {
                    refreshContent
                }
                collapsibleSection("notifications", title: "Notifications", systemImage: "bell") {
                    notificationsContent
                }
                collapsibleSection("diagnostics", title: "Diagnostics", systemImage: "stethoscope") {
                    diagnosticsContent
                }
                resetSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.visible)
        .frame(height: 620)
        .onAppear {
            if !didLoadConfig {
                didLoadConfig = true
                loadOpenCodeGoDashboardConfig()
            }
        }
    }

    @ViewBuilder
    private func collapsibleSection<Content: View>(
        _ id: String,
        title: String,
        systemImage: String,
        detail: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isCollapsed = collapsedSections.contains(id)
        SectionBlock {
            VStack(alignment: .leading, spacing: isCollapsed ? 0 : 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        toggleSection(id)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: systemImage)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Color.secondary.opacity(0.10)))
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if let detail {
                            Text(detail)
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                if !isCollapsed {
                    content()
                }
            }
        }
    }

    private func toggleSection(_ id: String) {
        if collapsedSections.contains(id) {
            collapsedSections.remove(id)
        } else {
            collapsedSections.insert(id)
        }
    }

    // MARK: - Providers

    private var providersContent: some View {
        VStack(spacing: 0) {
            ForEach(Array(ProviderTab.providerCases.enumerated()), id: \.element.id) { index, tab in
                providerRow(tab)
                if index < ProviderTab.providerCases.count - 1 {
                    Divider()
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
                    .scaleEffect(0.8)
                    .labelsHidden()

                Image(systemName: providerIcon(tab.systemImage, hidesProviderNames: viewModel.hidesProviderNames))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isEnabled ? .primary : .secondary)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(isEnabled ? Color.accentColor.opacity(0.10) : Color.secondary.opacity(0.08)))

                VStack(alignment: .leading, spacing: 1) {
                    Text(providerName(tab.displayName, privateName: tab.privateName, hidesProviderNames: viewModel.hidesProviderNames))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(isEnabled ? .primary : .secondary)
                    if hasWarning {
                        Text("Needs attention")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.orange)
                    } else if isEnabled {
                        Text(pathLabel(for: tab))
                            .font(.caption2)
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
            .padding(.vertical, 6)

            if isExpanded, isEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        TextField(pathPlaceholder(for: tab), text: pathBinding(for: tab))
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)

                        Button {
                            choosePath(for: tab)
                        } label: {
                            Image(systemName: "folder")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.borderless)
                        .help("Choose file")

                        Button {
                            resetProviderPath(tab)
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.borderless)
                        .help("Reset to default")
                    }

                    if let warning = pathWarning(for: tab) {
                        StatusLine(icon: "exclamationmark.triangle", color: .orange, text: warning)
                    }
                }
                .padding(.top, 2)
                .padding(.bottom, 8)
                .padding(.leading, 36)
            }
        }
    }

    // MARK: - OpenCode Go Auth

    private var openCodeGoAuthContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button {
                    openOpenCodeGoDashboard()
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Open dashboard")
                Spacer()
            }

            Text("Paste your workspace ID and browser auth cookie to track usage from the web dashboard.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                TextField("Workspace ID or dashboard URL", text: $openCodeGoWorkspaceInput)
                    .textFieldStyle(.roundedBorder)

                SecureField("Auth cookie", text: $openCodeGoAuthCookieInput)
                    .textFieldStyle(.roundedBorder)
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
                .buttonStyle(.bordered)
                .controlSize(.small)
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

    // MARK: - Menu Bar

    private var menuBarContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Display mode")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Picker("Display mode", selection: menuBarDisplayBinding) {
                    Text("Logos").tag(MenuBarDisplay.logos)
                    Text("Countdowns").tag(MenuBarDisplay.countdowns)
                    Text("Auto").tag(MenuBarDisplay.auto)
                    Text("Hidden").tag(MenuBarDisplay.hidden)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text(menuBarDisplayDescription)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if viewModel.configuration.privacy.menuBarDisplay == .auto {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Switch interval")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Picker("Switch interval", selection: autoSwitchIntervalBinding) {
                        ForEach(PrivacyConfiguration.validAutoSwitchIntervals, id: \.self) { seconds in
                            Text("\(seconds)s").tag(seconds)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }

            Toggle("Tint icon by secondary limit", isOn: secondaryTintingBinding)
                .font(.caption.weight(.medium))
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }

    private var menuBarDisplayDescription: String {
        switch viewModel.configuration.privacy.menuBarDisplay {
        case .logos: return "Colored progress rings with provider icons."
        case .countdowns: return "Compact pills with time-remaining text."
        case .auto: return "Alternates between logos and countdowns at the configured interval."
        case .hidden: return "Anonymizes provider names throughout the UI."
        }
    }

    // MARK: - Refresh

    private var refreshContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Interval")
                    .font(.caption.weight(.semibold))
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
                .labelsHidden()

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

            Divider()

            Toggle("Retry on failure", isOn: retryEnabledBinding)
                .font(.caption)

            if viewModel.configuration.refresh.retryEnabled {
                Stepper("Attempts: \(viewModel.configuration.refresh.maxRetryAttempts)",
                        value: retryAttemptsBinding,
                        in: 1...10)
                    .font(.caption)
                    .padding(.leading, 20)
            }
        }
    }

    // MARK: - Diagnostics

    private var diagnosticsContent: some View {
        VStack(spacing: 0) {
            let enabledProviders = ProviderTab.providerCases.filter(viewModel.isProviderEnabled)
            ForEach(Array(enabledProviders.enumerated()), id: \.element.id) { index, tab in
                diagnosticRow(tab)
                if index < enabledProviders.count - 1 {
                    Divider()
                }
            }
        }
    }

    private func diagnosticRow(_ tab: ProviderTab) -> some View {
        let loadState = viewModel.currentLoadState(for: tab)
        let lastFetch = viewModel.lastFetchAt[tab]
        let lastError = viewModel.lastErrors[tab]
        let pathExists = viewModel.providerPathExists(for: tab)
        let testResult = viewModel.diagnosticTestResults[tab]

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: providerIcon(tab.systemImage, hidesProviderNames: viewModel.hidesProviderNames))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.secondary.opacity(0.08)))

                VStack(alignment: .leading, spacing: 1) {
                    Text(providerName(tab.displayName, privateName: tab.privateName, hidesProviderNames: viewModel.hidesProviderNames))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        statusDot(for: loadState, pathExists: pathExists)
                        Text(diagnosticStatusText(for: loadState, pathExists: pathExists))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    viewModel.testProviderConnection(tab)
                } label: {
                    Label("Test", systemImage: "bolt")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.isProviderRefreshing(tab))
            }

            VStack(alignment: .leading, spacing: 3) {
                diagnosticDetailRow(label: "Last fetch", value: lastFetch.map { UsageFormatting.resetText(date: $0, now: viewModel.now) } ?? "Never")
                diagnosticDetailRow(label: "Path", value: pathExists ? "Found" : "Missing")
                if let lastError {
                    diagnosticDetailRow(label: "Error", value: lastError, color: .red)
                }
                if let testResult {
                    diagnosticDetailRow(
                        label: "Test",
                        value: "\(testResult.succeeded ? "OK" : "Failed") · \(testResult.elapsedMillis)ms",
                        color: testResult.succeeded ? .green : .red
                    )
                    if !testResult.succeeded {
                        Text(testResult.message)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .padding(.leading, 50)
                    }
                }
            }
            .padding(.leading, 30)
        }
        .padding(.vertical, 6)
    }

    private func statusDot(for loadState: UsageViewModel.LoadState, pathExists: Bool) -> some View {
        let color: Color = {
            if !pathExists { return .orange }
            switch loadState {
            case .loaded: return .green
            case .failed: return .red
            case .disabled: return .secondary
            case .idle, .loading: return .secondary
            }
        }()
        return Circle()
            .fill(color)
            .frame(width: 6, height: 6)
    }

    private func diagnosticStatusText(for loadState: UsageViewModel.LoadState, pathExists: Bool) -> String {
        if !pathExists { return "Path missing" }
        switch loadState {
        case .loaded: return "Connected"
        case .failed: return "Failed"
        case .disabled: return "Disabled"
        case .idle: return "Idle"
        case .loading: return "Loading"
        }
    }

    private func diagnosticDetailRow(label: String, value: String, color: Color = .secondary) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.tertiary)
                .frame(width: 50, alignment: .leading)
            Text(value)
                .font(.caption2)
                .foregroundStyle(color)
                .lineLimit(1)
        }
    }

    // MARK: - Reset

    private var resetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button("Reset all settings") {
                    viewModel.resetConfigurationToDefaults()
                    selectedTab = .overview
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Spacer()
                Text("Saved automatically")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if showClearExhaustionConfirmation {
                clearExhaustionConfirmationView
            } else {
                HStack {
                    Button("Clear exhaustion history", role: .destructive) {
                        didClearExhaustionHistory = false
                        showClearExhaustionConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Spacer()
                    if didClearExhaustionHistory {
                        Text("Cleared")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    } else if viewModel.exhaustionSummaries.isEmpty {
                        Text("No history")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    } else {
                        Text("\(viewModel.exhaustionSummaries.count) provider\(viewModel.exhaustionSummaries.count == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.top, 2)
    }

    private var clearExhaustionConfirmationView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Clear exhaustion history?")
                .font(.caption.weight(.semibold))
            Text("Removes all recorded quota exhaustion cycles. Configuration and pace projections are not affected.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button("Clear history", role: .destructive) {
                    viewModel.clearExhaustionHistory()
                    showClearExhaustionConfirmation = false
                    didClearExhaustionHistory = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button("Cancel") {
                    showClearExhaustionConfirmation = false
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Spacer()
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.red.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.red.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - First launch

    private var firstLaunchSetupView: some View {
        HStack(spacing: 10) {
            Image(systemName: "checklist")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("First setup")
                    .font(.subheadline.weight(.semibold))
                Text("Detected providers are ready. Add \(providerName("OpenCode Go", privateName: "Provider 4", hidesProviderNames: viewModel.hidesProviderNames)) auth below or finish with the current setup.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button {
                completeFirstLaunchSetup()
            } label: {
                Label("Done", systemImage: "checkmark")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.accentColor.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.accentColor.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Notifications

    private var notificationsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("", isOn: notificationsEnabledBinding)
                .toggleStyle(.switch)
                .labelsHidden()
                .scaleEffect(0.8)

            if viewModel.configuration.notifications.enabled {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Critical usage", isOn: notificationsCriticalBinding)
                            .font(.caption)
                        Toggle("Billing expiring", isOn: notificationsBillingBinding)
                            .font(.caption)
                        Toggle("Provider unavailable", isOn: notificationsUnavailableBinding)
                            .font(.caption)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Per provider")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            notificationProviderToggle(.codex, label: "Codex")
                            notificationProviderToggle(.cursor, label: "Cursor")
                            notificationProviderToggle(.devin, label: "Devin")
                            notificationProviderToggle(.openCodeGo, label: "Go")
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Critical threshold")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        VStack(spacing: 4) {
                            notificationThresholdRow(.codex, label: "Codex")
                            notificationThresholdRow(.cursor, label: "Cursor")
                            notificationThresholdRow(.devin, label: "Devin")
                            notificationThresholdRow(.openCodeGo, label: "Go")
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Quiet hours")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Start")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Picker("", selection: quietHoursStartBinding) {
                                    Text("Off").tag(-1)
                                    ForEach(0..<24, id: \.self) { hour in
                                        Text("\(hour):00").tag(hour)
                                    }
                                }
                                .pickerStyle(.menu)
                                .font(.caption2)
                                .frame(width: 90)
                                .labelsHidden()
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("End")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Picker("", selection: quietHoursEndBinding) {
                                    Text("Off").tag(-1)
                                    ForEach(0..<24, id: \.self) { hour in
                                        Text("\(hour):00").tag(hour)
                                    }
                                }
                                .pickerStyle(.menu)
                                .font(.caption2)
                                .frame(width: 90)
                                .labelsHidden()
                                .disabled(viewModel.configuration.notifications.quietHoursStartHour == nil)
                            }
                            Spacer()
                        }
                    }

                    Divider()

                    Toggle("Daily digest", isOn: notificationsDigestBinding)
                        .font(.caption)

                    if viewModel.configuration.notifications.dailyDigest {
                        HStack(spacing: 8) {
                            Text("Send at")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Picker("Hour", selection: digestHourBinding) {
                                ForEach(0..<24, id: \.self) { hour in
                                    Text("\(hour):00").tag(hour)
                                }
                            }
                            .pickerStyle(.menu)
                            .font(.caption2)
                            .frame(width: 90)
                            .labelsHidden()
                            Spacer()
                        }
                        .padding(.leading, 26)
                    }

                    Divider()

                    HStack {
                        Button {
                            viewModel.sendTestNotification()
                        } label: {
                            Label("Send test notification", systemImage: "bell.badge")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Spacer()

                        if let status = viewModel.notificationTestStatus {
                            Text(status)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if viewModel.notificationNeedsSettings {
                            Button {
                                viewModel.openNotificationSettings()
                            } label: {
                                Label("System Settings", systemImage: "gear")
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                        }
                    }
                }
                .padding(.leading, 26)
            }
        }
    }

    private func notificationProviderToggle(_ tab: ProviderTab, label: String) -> some View {
        Toggle(
            providerName(label, privateName: tab.privateName, hidesProviderNames: viewModel.hidesProviderNames),
            isOn: notificationPerProviderBinding(tab)
        )
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

    private var secondaryTintingBinding: Binding<Bool> {
        Binding(
            get: { viewModel.configuration.privacy.secondaryLimitTintingEnabled },
            set: { value in
                viewModel.updateConfiguration { $0.privacy.secondaryLimitTintingEnabled = value }
            }
        )
    }

    private var autoSwitchIntervalBinding: Binding<Int> {
        Binding(
            get: { viewModel.configuration.privacy.autoSwitchIntervalSeconds },
            set: { value in
                viewModel.updateConfiguration { $0.privacy.autoSwitchIntervalSeconds = value }
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

    private var notificationsDigestBinding: Binding<Bool> {
        Binding(
            get: { viewModel.configuration.notifications.dailyDigest },
            set: { value in
                viewModel.updateConfiguration { $0.notifications.dailyDigest = value }
            }
        )
    }

    private var digestHourBinding: Binding<Int> {
        Binding(
            get: { viewModel.configuration.notifications.dailyDigestHour },
            set: { value in
                viewModel.updateConfiguration { $0.notifications.dailyDigestHour = value }
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
            let defaults = LimitLensConfiguration.defaults
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
        let name = openCodeGoDisplayName
        guard let credentials = OpenCodeGoDashboardConfigFile.loadIfPresent(from: openCodeGoConfigURL) else {
            showOpenCodeGoSetupMessage("No saved \(name) config found.", isError: true)
            return
        }

        openCodeGoWorkspaceInput = credentials.workspaceId
        openCodeGoAuthCookieInput = credentials.authCookie
        showOpenCodeGoSetupMessage("Loaded saved \(name) config.", isError: false)
    }

    private func saveOpenCodeGoDashboardConfig() {
        let name = openCodeGoDisplayName
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
            showOpenCodeGoSetupMessage("Saved \(name) config.", isError: false)
            Task { await viewModel.refresh() }
        } catch let error as LocalizedError {
            showOpenCodeGoSetupMessage(error.errorDescription ?? "\(name) config could not be saved.", isError: true)
        } catch {
            showOpenCodeGoSetupMessage("\(name) config could not be saved.", isError: true)
        }
    }

    private var openCodeGoDisplayName: String {
        providerName("OpenCode Go", privateName: "Provider 4", hidesProviderNames: viewModel.hidesProviderNames)
    }

    private func openOpenCodeGoDashboard() {
        NSWorkspace.shared.open(OpenCodeGoDashboardCredentials.dashboardURL(workspaceId: openCodeGoWorkspaceInput))
    }

    private func showOpenCodeGoSetupMessage(_ message: String, isError: Bool) {
        openCodeGoSetupMessage = message
        openCodeGoSetupMessageIsError = isError
    }
}
