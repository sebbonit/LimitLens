import AppKit
import ResetStatCore
import SwiftUI

@main
struct ResetStatApp: App {
    @StateObject private var viewModel = UsageViewModel()

    var body: some Scene {
        MenuBarExtra {
            ResetStatPopover(viewModel: viewModel)
                .frame(width: 460)
        } label: {
            MenuBarStatusLabel(status: viewModel.menuBarStatus)
                .task {
                    viewModel.start()
                }
        }
        .menuBarExtraStyle(.window)
    }
}

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
}

struct ResetStatPopover: View {
    @ObservedObject var viewModel: UsageViewModel
    @State private var showsResetCreditDetails = false
    @State private var selectedTab: ProviderTab = .overview

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            tabBar
            contentView

            footer
        }
        .padding(16)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 12) {
            SMark()
            VStack(alignment: .leading, spacing: 2) {
                Text("ResetStat")
                    .font(.headline.weight(.semibold))
                Text("Personal AI Usage Dashboard")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .help("Refresh")
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .overview:
            overviewSection
        case .codex:
            if let snapshot = viewModel.snapshot {
                codexSection(snapshot)
            } else {
                unavailableView
            }
        case .cursor:
            cursorSection
        case .devin:
            desktopQuotaSection
        case .openCodeGo:
            openCodeGoSection
        case .settings:
            settingsSection
        }
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(viewModel.visibleTabs) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.bottom, 2)
    }

    private func tabButton(for tab: ProviderTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 5) {
                Image(systemName: providerIcon(tab.systemImage))
                    .font(.system(size: 10, weight: .semibold))
                Text(providerName(tab.displayName, privateName: tab.privateName))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : Color(nsColor: .controlBackgroundColor))
            )
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
        .help(providerName(tab.displayName, privateName: tab.privateName))
    }

    private var loadingView: some View {
        StatusLine(icon: "hourglass", color: .secondary, text: "Loading usage...")
            .padding(.vertical, 18)
    }

    private func errorView(message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            switch selectedTab {
            case .overview:
                overviewSection
            case .codex:
                if let snapshot = viewModel.snapshot {
                    codexSection(snapshot)
                }
                SectionBlock {
                    StatusLine(icon: "exclamationmark.circle", color: .orange, text: providerSafeMessage(message))
                }
            case .cursor:
                cursorSection
            case .devin:
                desktopQuotaSection
            case .openCodeGo:
                openCodeGoSection
            case .settings:
                settingsSection
            }
        }
    }

    private var unavailableView: some View {
        SectionBlock {
            Text("Usage data is temporarily unavailable.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
        }
    }

    private var footer: some View {
        HStack {
            if let fetchedAt = latestFetchDate {
                Text("Updated \(fetchedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button {
                selectedTab = .settings
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(selectedTab == .settings ? Color.accentColor : Color.secondary.opacity(0.75))
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.borderless)
            .help("Settings")
            Button {
                viewModel.updateConfiguration { configuration in
                    let modes: [MenuBarDisplay] = [.logos, .countdowns, .hidden]
                    let current = configuration.privacy.menuBarDisplay
                    let index = modes.firstIndex(of: current).map { ($0 + 1) % modes.count } ?? 0
                    configuration.privacy.menuBarDisplay = modes[index]
                }
            } label: {
                Image(systemName: menuBarDisplayIcon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(menuBarDisplay == .logos ? Color.secondary.opacity(0.75) : Color.accentColor)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.borderless)
            .help(menuBarDisplayHelp)
            Button("Quit") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
    }

    private var latestFetchDate: Date? {
        ([viewModel.snapshot?.fetchedAt, viewModel.cursorSnapshot?.fetchedAt, viewModel.openCodeGoSnapshot?.fetchedAt]
            + viewModel.desktopQuotaSnapshots.map(\.fetchedAt))
            .compactMap(\.self)
            .max()
    }

    private var metricColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
    }

    private var overviewSection: some View {
        SectionBlock {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(
                    title: "Overview",
                    detail: overviewDetail,
                    systemImage: "speedometer"
                )

                billingExpirySection

                Divider()

                if viewModel.providerSummaries.isEmpty {
                    StatusLine(icon: "slider.horizontal.3", color: .secondary, text: "No providers enabled.")
                } else {
                    VStack(spacing: 8) {
                        ForEach(viewModel.providerSummaries) { summary in
                            overviewRow(summary)
                        }
                    }
                }
            }
        }
    }

    private var overviewDetail: String {
        let criticalCount = viewModel.providerSummaries.filter { $0.severity == .critical }.count
        if criticalCount > 0 {
            return "\(criticalCount) critical"
        }

        let warningCount = viewModel.providerSummaries.filter { $0.severity == .warning }.count
        if warningCount > 0 {
            return "\(warningCount) warning"
        }

        let unavailableCount = viewModel.providerSummaries.filter { $0.severity == .unavailable }.count
        if unavailableCount > 0 {
            return "\(unavailableCount) unavailable"
        }

        return viewModel.providerSummaries.isEmpty ? "Configure providers" : "All clear"
    }

    private func overviewRow(_ summary: ProviderUsageSummary) -> some View {
        Button {
            selectedTab = summary.tab
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(severityColor(summary.severity).opacity(0.16))
                    Image(systemName: providerIcon(summary.tab.systemImage))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(severityColor(summary.severity))
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(providerName(summary.tab.displayName, privateName: summary.tab.privateName))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(providerSafeMessage(summary.subdetail))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(providerSafeMessage(summary.detail))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(summary.severity == .unavailable ? .secondary : .primary)
                    if let secondaryDetail = summary.secondaryDetail {
                        Text(providerSafeMessage(secondaryDetail))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    } else {
                        Text(" ")
                            .font(.caption2.weight(.medium))
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var billingExpirySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Billing & renewals")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(billingSummaryDetail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                spacing: 8
            ) {
                if viewModel.billingExpiries.isEmpty {
                    Text("No enabled providers")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(viewModel.billingExpiries) { entry in
                        billingExpiryCell(entry)
                    }
                }
            }
        }
    }

    private func billingExpiryCell(_ entry: BillingExpiry) -> some View {
        let primaryText: String = entry.date.map { UsageFormatting.resetText(date: $0, now: viewModel.now) } ?? entry.amountText ?? "—"
        let secondaryText: String = entry.date.map { UsageFormatting.relativeDayText(date: $0, now: viewModel.now) } ?? entry.detailText ?? "No billing"
        let primaryColor: Color = entry.date == nil && entry.amountText == nil ? .secondary : (entry.date == nil ? .primary : expiryColor(entry.urgency))
        return HStack(spacing: 8) {
            Image(systemName: providerIcon(entry.tab.systemImage))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(expiryColor(entry.urgency))
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text(providerShortName(entry.tab))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(entry.label)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(primaryText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(primaryColor)
                    .lineLimit(1)
                Text(secondaryText)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private var billingSummaryDetail: String {
        let expiring = viewModel.billingExpiries.filter { $0.urgency == .expired || $0.urgency == .soon }.count
        if expiring > 0 { return "\(expiring) expiring soon" }
        let warn = viewModel.billingExpiries.filter { $0.urgency == .warning }.count
        if warn > 0 { return "\(warn) within 2w" }
        let healthy = viewModel.billingExpiries.filter { $0.urgency == .healthy }.count
        if healthy > 0 { return "Up to date" }
        return "—"
    }

    private func expiryColor(_ urgency: UsageFormatting.ExpiryUrgency) -> Color {
        switch urgency {
        case .expired: return .red
        case .soon: return .orange
        case .warning: return .yellow
        case .healthy: return .green
        case .unknown: return .secondary
        }
    }

    private func providerShortName(_ tab: ProviderTab) -> String {
        if viewModel.hidesProviderNames {
            switch tab {
            case .codex: return "P1"
            case .cursor: return "P2"
            case .devin: return "P3"
            case .openCodeGo: return "P4"
            default: return tab.privateName
            }
        }
        switch tab {
        case .codex: return "Codex"
        case .cursor: return "Cursor"
        case .devin: return "Devin"
        case .openCodeGo: return "Go"
        default: return tab.displayName
        }
    }

    private func codexSection(_ snapshot: ResetStatSnapshot) -> some View {
        SectionBlock {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(
                    title: providerName("Codex", privateName: "Provider 1"),
                    detail: codexHeaderDetail(snapshot),
                    systemImage: "terminal"
                )

                VStack(spacing: 10) {
                    resetWindowView(title: "Primary", window: snapshot.rateLimit.primary, tint: .blue)
                    resetWindowView(title: "Secondary", window: snapshot.rateLimit.secondary, tint: .cyan)
                }

                Divider()

                resetCreditsView(snapshot.resetCredits)

                LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 10) {
                    MetricTile(
                        title: "Lifetime tokens",
                        value: UsageFormatting.compactNumber(snapshot.tokenUsage?.lifetimeTokens)
                    )
                    MetricTile(
                        title: "Peak daily",
                        value: UsageFormatting.compactNumber(snapshot.tokenUsage?.peakDailyTokens)
                    )
                    MetricTile(
                        title: "Current streak",
                        value: streakText(snapshot.tokenUsage?.currentStreakDays)
                    )
                }

                if !snapshot.dailyUsageBuckets.isEmpty {
                    Divider()
                    DailyUsageChart(buckets: snapshot.dailyUsageBuckets)
                }
            }
        }
    }

    private func resetCreditsView(_ credits: ResetCreditInfo) -> some View {
        let expiry = resetCreditExpiry(credits)
        let expiringCredits = sortedExpiringCredits(credits)
        let canExpand = !expiringCredits.isEmpty

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Reset credits")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(resetCreditAvailabilityText(credits))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(credits.availableCount)")
                    .font(.callout.weight(.semibold))

                VStack(alignment: .leading, spacing: 2) {
                    Text(expiry.text)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(expiry.color)
                        .lineLimit(1)
                    Text(expiry.detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    showsResetCreditDetails.toggle()
                } label: {
                    HStack(spacing: 4) {
                        if canExpand {
                            Image(systemName: showsResetCreditDetails ? "chevron.up" : "chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!canExpand)
                .help(canExpand ? "Show all reset credit expiries" : "No additional reset credits")
            }

            if showsResetCreditDetails, canExpand {
                VStack(spacing: 7) {
                    ForEach(Array(expiringCredits.enumerated()), id: \.offset) { index, credit in
                        resetCreditDetailRow(index: index, credit: credit)
                    }
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var cursorSection: some View {
        SectionBlock {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(title: providerName("Cursor", privateName: "Provider 2"), detail: cursorHeaderDetail, systemImage: "cursorarrow")

                if let cursor = viewModel.cursorSnapshot {
                    cursorUsageView(cursor)
                } else if case .loading = viewModel.cursorState {
                    StatusLine(icon: "hourglass", color: .secondary, text: "Loading provider usage...")
                } else if case .failed(let message) = viewModel.cursorState {
                    StatusLine(icon: "exclamationmark.circle", color: .orange, text: providerSafeMessage(message))
                } else {
                    StatusLine(icon: "minus.circle", color: .secondary, text: "Provider usage unavailable.")
                }
            }
        }
    }

    private var cursorHeaderDetail: String? {
        if let plan = viewModel.cursorSnapshot?.planName {
            return plan
        }
        if case .failed = viewModel.cursorState {
            return "Unavailable"
        }
        return nil
    }

    @ViewBuilder
    private var desktopQuotaSection: some View {
        SectionBlock {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(
                    title: providerName("Devin", privateName: "Provider 3"),
                    detail: desktopQuotaHeaderDetail,
                    systemImage: "sparkles"
                )

                if !viewModel.desktopQuotaSnapshots.isEmpty {
                    VStack(spacing: 12) {
                        ForEach(viewModel.desktopQuotaSnapshots, id: \.appName) { quota in
                            desktopQuotaView(quota)
                        }
                    }
                } else if case .loading = viewModel.desktopQuotaState {
                    StatusLine(icon: "hourglass", color: .secondary, text: "Checking Devin quota...")
                } else if case .failed(let message) = viewModel.desktopQuotaState {
                    StatusLine(icon: "exclamationmark.circle", color: .orange, text: providerSafeMessage(message))
                } else {
                    StatusLine(icon: "minus.circle", color: .secondary, text: "Devin quota unavailable.")
                }
            }
        }
    }

    private func providerName(_ name: String, privateName: String) -> String {
        viewModel.hidesProviderNames ? privateName : name
    }

    private func providerSafeMessage(_ message: String) -> String {
        guard viewModel.hidesProviderNames else { return message }
        return message
            .replacingOccurrences(of: "Codex", with: "Provider")
            .replacingOccurrences(of: "Cursor", with: "Provider")
            .replacingOccurrences(of: "Devin", with: "Provider")
            .replacingOccurrences(of: "OpenCode Go", with: "Provider")
            .replacingOccurrences(of: "OpenCode", with: "Provider")
    }

    private var desktopQuotaHeaderDetail: String? {
        viewModel.desktopQuotaSnapshots.first?.planName?.nilIfEmpty
    }

    @ViewBuilder
    private var openCodeGoSection: some View {
        SectionBlock {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(
                    title: providerName("OpenCode Go", privateName: "Provider 4"),
                    detail: openCodeGoHeaderDetail,
                    systemImage: "chevron.left.forwardslash.chevron.right"
                )

                if let snapshot = viewModel.openCodeGoSnapshot, snapshot.hasUsage {
                    openCodeGoUsageView(snapshot)
                    if let billing = snapshot.billing {
                        Divider()
                        openCodeGoBillingView(billing)
                    }
                } else if case .loading = viewModel.openCodeGoState {
                    StatusLine(icon: "hourglass", color: .secondary, text: "Checking OpenCode Go usage...")
                } else if case .failed(let message) = viewModel.openCodeGoState {
                    StatusLine(icon: "exclamationmark.circle", color: .orange, text: providerSafeMessage(message))
                } else {
                    StatusLine(icon: "minus.circle", color: .secondary, text: "OpenCode Go usage unavailable.")
                }
            }
        }
    }

    private var openCodeGoHeaderDetail: String? {
        viewModel.openCodeGoSnapshot?.source?.nilIfEmpty ?? "Go"
    }

    private var settingsSection: some View {
        SectionBlock {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(title: "Settings", detail: "Providers", systemImage: "gearshape")

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
                Image(systemName: providerIcon(tab.systemImage))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                Text(providerName(tab.displayName, privateName: tab.privateName))
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

    private var menuBarDisplay: MenuBarDisplay {
        viewModel.menuBarDisplay
    }

    private var menuBarDisplayIcon: String {
        switch menuBarDisplay {
        case .logos: return "circle.grid.2x2"
        case .countdowns: return "timer"
        case .hidden: return "eye.slash"
        }
    }

    private var menuBarDisplayHelp: String {
        switch menuBarDisplay {
        case .logos: return "Menu bar: logos"
        case .countdowns: return "Menu bar: countdowns"
        case .hidden: return "Menu bar: hidden"
        }
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

    private func codexHeaderDetail(_ snapshot: ResetStatSnapshot) -> String? {
        let plan = UsageFormatting.planTitle(snapshot.rateLimit.planType)
        guard let billingDate = snapshot.planExpiresAt else {
            return "\(plan) · Renewal unavailable"
        }
        return "\(plan) · Renews \(UsageFormatting.resetText(date: billingDate, now: viewModel.now))"
    }

    private func sectionHeader(title: String, detail: String?, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: providerIcon(systemImage))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func providerIcon(_ systemImage: String) -> String {
        viewModel.hidesProviderNames ? "circle.grid.2x2" : systemImage
    }

    private func resetWindowView(title: String, window: RateLimitWindow?, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(UsageFormatting.timeRemainingText(timestamp: window?.resetsAt, now: viewModel.now))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            ProgressView(value: Double(window?.usedPercent ?? 0), total: 100)
                .tint(tint)

            HStack {
                Text("\(window?.usedPercent ?? 0)% used")
                Spacer()
                Text("Resets \(UsageFormatting.resetText(timestamp: window?.resetsAt, now: viewModel.now))")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func cursorUsageView(_ cursor: CursorUsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(cursor.usedPercent.rounded()))% used")
                        .font(.title3.weight(.semibold))
                    Text("Resets \(cursorResetText(cursor.billingCycleEnd))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(UsageFormatting.usd(cents: cursor.remainingCents))
                        .font(.callout.weight(.semibold))
                    Text("of \(UsageFormatting.usd(cents: cursor.limitCents)) left")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            ProgressView(value: cursor.usedPercent, total: 100)
                .tint(.purple)

            if cursor.autoPercentUsed != nil || cursor.apiPercentUsed != nil {
                VStack(spacing: 9) {
                    cursorLimitView(
                        title: "Auto",
                        percentUsed: cursor.autoPercentUsed,
                        spendCents: cursor.autoSpendCents,
                        limitCents: cursor.autoLimitCents,
                        tint: .purple
                    )
                    cursorLimitView(
                        title: "API",
                        percentUsed: cursor.apiPercentUsed,
                        spendCents: cursor.apiSpendCents,
                        limitCents: cursor.apiLimitCents,
                        tint: .indigo
                    )
                }
                .padding(.top, 2)
            }
        }
    }

    private func cursorLimitView(
        title: String,
        percentUsed: Double?,
        spendCents: Int?,
        limitCents: Int?,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(percentText(percentUsed))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            ProgressView(value: percentUsed ?? 0, total: 100)
                .tint(tint)

            if spendCents != nil || limitCents != nil {
                HStack {
                    Text("\(UsageFormatting.usd(cents: spendCents)) used")
                    Spacer()
                    Text("Limit \(UsageFormatting.usd(cents: limitCents))")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func desktopQuotaView(_ quota: DesktopQuotaSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            quotaBar(
                title: "Daily",
                usedPercent: quota.dailyUsedPercent,
                isUnavailable: quota.shouldTreatQuotaUsageAsUnavailable,
                resetAt: advancedResetDate(quota.dailyResetAt, interval: 86_400),
                tint: .green
            )
            quotaBar(
                title: "Weekly",
                usedPercent: quota.weeklyUsedPercent,
                isUnavailable: quota.shouldTreatQuotaUsageAsUnavailable,
                resetAt: advancedResetDate(quota.weeklyResetAt, interval: 7 * 86_400),
                tint: .orange
            )

            if quota.overageBalanceMicros != nil || quota.cycleEnd != nil {
                Divider()

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Extra usage balance")
                            .font(.caption.weight(.semibold))
                        if let cycleEnd = quota.cycleEnd {
                            Text("Plan ends \(UsageFormatting.resetText(date: cycleEnd, now: viewModel.now))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text(UsageFormatting.usd(micros: quota.overageBalanceMicros))
                        .font(.caption.weight(.semibold))
                }
            }
        }
    }

    private func openCodeGoUsageView(_ snapshot: OpenCodeGoUsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            openCodeGoUsageBar(title: "Rolling", window: snapshot.rolling, tint: .mint)
            openCodeGoUsageBar(title: "Weekly", window: snapshot.weekly, tint: .orange)
            openCodeGoUsageBar(title: "Monthly", window: snapshot.monthly, tint: .blue)
        }
    }

    private func openCodeGoBillingView(_ billing: OpenCodeGoBilling) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Billing")
                    .font(.caption.weight(.semibold))
                Spacer()
                if billing.autoReloadEnabled {
                    Text("Auto-reload on")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current balance")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(billing.balanceText ?? "—")
                        .font(.callout.weight(.semibold))
                }
                Spacer()
                if let last4 = billing.cardLast4 {
                    HStack(spacing: 4) {
                        Image(systemName: "creditcard")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("•••• \(last4)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !billing.payments.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Payments")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    VStack(spacing: 5) {
                        ForEach(Array(billing.payments.prefix(5).enumerated()), id: \.offset) { _, payment in
                            HStack(alignment: .firstTextBaseline) {
                                Text(payment.dateText.isEmpty ? (payment.date.map { UsageFormatting.resetText(date: $0, now: viewModel.now) } ?? "—") : payment.dateText)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Spacer()
                                Text(payment.amountText.isEmpty ? "—" : payment.amountText)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(payment.refunded ? .secondary : .primary)
                                    .strikethrough(payment.refunded)
                                if payment.refunded {
                                    Text("refunded")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func openCodeGoUsageBar(title: String, window: OpenCodeGoUsageWindow?, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(UsageFormatting.timeRemainingText(date: window?.resetAt, now: viewModel.now))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(window?.resetAt == nil ? .secondary : .primary)
            }

            ProgressView(value: window?.usedPercent ?? 0, total: 100)
                .tint(tint)

            HStack {
                Text(window.map { "\(Int($0.usedPercent.rounded()))% used" } ?? "Usage not reported")
                Spacer()
                Text("Resets \(quotaResetText(window?.resetAt))")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func quotaBar(
        title: String,
        usedPercent: Int?,
        isUnavailable: Bool,
        resetAt: Date?,
        tint: Color
    ) -> some View {
        let displayedPercent = isUnavailable ? nil : usedPercent
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(resetAt.map { UsageFormatting.timeRemainingText(date: $0, now: viewModel.now) } ?? "Unknown")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(resetAt == nil ? .secondary : .primary)
            }

            ProgressView(value: Double(displayedPercent ?? 0), total: 100)
                .tint(tint)

            HStack {
                Text(displayedPercent.map { "\($0)% used" } ?? "Usage not reported")
                Spacer()
                Text("Resets \(quotaResetText(resetAt))")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func resetCreditExpiry(_ credits: ResetCreditInfo) -> (text: String, detail: String, color: Color) {
        guard credits.availableCount > 0 else {
            return ("None available", "No reset credits to spend", .secondary)
        }
        guard let expiresAt = credits.nextExpiringCredit?.expiresAt else {
            return ("Expiry not reported", "Credit dates unavailable", .secondary)
        }

        let text = "Expires \(UsageFormatting.relativeDayText(date: expiresAt, now: viewModel.now))"
        let detail = UsageFormatting.resetText(date: expiresAt, now: viewModel.now)
        switch UsageFormatting.expiryUrgency(expiresAt: expiresAt, now: viewModel.now) {
        case .expired, .soon:
            return (text, detail, .red)
        case .warning:
            return (text, detail, .yellow)
        case .healthy:
            return (text, detail, .green)
        case .unknown:
            return (text, detail, .secondary)
        }
    }

    private func resetCreditAvailabilityText(_ credits: ResetCreditInfo) -> String {
        guard let total = credits.totalEarnedCount, total >= credits.availableCount, total > 0 else {
            return credits.availableCount == 1 ? "1 available" : "\(credits.availableCount) available"
        }
        return "\(credits.availableCount) of \(total) available"
    }

    private func resetCreditDetailRow(index: Int, credit: ResetCredit) -> some View {
        let expiry = resetCreditExpiry(date: credit.expiresAt)

        return HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(credit.title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Credit \(index + 1)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(resetCreditSubtitle(credit))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(expiry.text)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(expiry.color)
                    .lineLimit(1)
                Text(expiry.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func resetCreditExpiry(date: Date?) -> (text: String, detail: String, color: Color) {
        guard let date else {
            return ("Expiry unknown", "Date unavailable", .secondary)
        }

        let text = UsageFormatting.relativeDayText(date: date, now: viewModel.now)
        let detail = UsageFormatting.resetText(date: date, now: viewModel.now)
        switch UsageFormatting.expiryUrgency(expiresAt: date, now: viewModel.now) {
        case .expired, .soon:
            return (text, detail, .red)
        case .warning:
            return (text, detail, .yellow)
        case .healthy:
            return (text, detail, .green)
        case .unknown:
            return (text, detail, .secondary)
        }
    }

    private func resetCreditSubtitle(_ credit: ResetCredit) -> String {
        [credit.resetType, credit.status]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }
            .map { $0.replacingOccurrences(of: "_", with: " ").capitalized }
            .joined(separator: " · ")
            .nilIfEmpty ?? "Reset credit"
    }

    private func sortedExpiringCredits(_ credits: ResetCreditInfo) -> [ResetCredit] {
        credits.credits
            .filter { $0.expiresAt != nil }
            .sorted { ($0.expiresAt ?? .distantFuture) < ($1.expiresAt ?? .distantFuture) }
    }

    private func streakText(_ days: Int64?) -> String {
        guard let days else { return "--" }
        return days == 1 ? "1 day" : "\(days) days"
    }

    private func cursorResetText(_ date: Date?) -> String {
        guard let date else { return "unknown" }
        return UsageFormatting.resetText(date: date, now: viewModel.now)
    }

    private func quotaResetText(_ date: Date?) -> String {
        guard let date else { return "unknown" }
        return UsageFormatting.resetText(date: date, now: viewModel.now)
    }

    private func advancedResetDate(_ date: Date?, interval: TimeInterval) -> Date? {
        guard var date else { return nil }
        while date < viewModel.now {
            date = date.addingTimeInterval(interval)
        }
        return date
    }

    private func quotaPercentText(_ remainingPercent: Int?) -> String {
        guard let remainingPercent else { return "-- remaining" }
        return "\(remainingPercent)% remaining"
    }

    private func percentText(_ value: Double?) -> String {
        guard let value else { return "--" }
        return "\(Int(value.rounded()))%"
    }

    private func severityColor(_ severity: UsageSeverity) -> Color {
        switch severity {
        case .critical:
            return .red
        case .warning:
            return .orange
        case .healthy:
            return .green
        case .unavailable:
            return .secondary
        }
    }
}

private struct MenuBarStatusLabel: View {
    let status: MenuBarStatusSnapshot

    var body: some View {
        Image(nsImage: MenuBarStatusImageRenderer.image(for: status))
            .renderingMode(.original)
            .interpolation(.high)
            .frame(
                width: MenuBarStatusImageRenderer.size(for: status).width,
                height: MenuBarStatusImageRenderer.size(for: status).height
            )
            .help(status.helpText)
            .accessibilityLabel(status.accessibilityLabel)
    }
}

private enum MenuBarStatusImageRenderer {
    private static let height: CGFloat = 18
    private static let ringDiameter: CGFloat = 16
    private static let ringLineWidth: CGFloat = 2.5
    private static let ringGap: CGFloat = 5
    private static let pillHeight: CGFloat = 14
    private static let pillLineWidth: CGFloat = 1.4
    private static let pillMinWidth: CGFloat = 24
    private static let pillHorizontalPadding: CGFloat = 10

    static func size(for status: MenuBarStatusSnapshot) -> NSSize {
        let indicatorCount = max(status.indicators.count, 1)
        if status.menuBarDisplay == .countdowns {
            let pillWidths = status.indicators.map { pillWidth(for: $0) }.reduce(0, +)
            let totalPillWidth = max(pillWidths, pillMinWidth)
            let gaps = CGFloat(max(status.indicators.count - 1, 0)) * ringGap
            return NSSize(width: totalPillWidth + gaps, height: height)
        }
        let width = CGFloat(indicatorCount) * ringDiameter + CGFloat(indicatorCount - 1) * ringGap
        return NSSize(width: width, height: height)
    }

    static func image(for status: MenuBarStatusSnapshot) -> NSImage {
        let size = size(for: status)
        let image = NSImage(size: size)
        image.isTemplate = false
        image.lockFocus()
        defer {
            image.unlockFocus()
            image.isTemplate = false
        }

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        if status.indicators.isEmpty {
            if status.menuBarDisplay == .countdowns {
                drawEmptyStatePill(in: size)
            } else {
                drawEmptyStateRing(in: size)
            }
        } else if status.menuBarDisplay == .countdowns {
            var xOffset: CGFloat = 0
            for indicator in status.indicators {
                let width = pillWidth(for: indicator)
                let center = NSPoint(x: xOffset + width / 2, y: size.height / 2)
                drawCountdownPill(
                    center: center,
                    indicator: indicator,
                    isRefreshing: status.isRefreshing
                )
                xOffset += width + ringGap
            }
        } else {
            for (index, indicator) in status.indicators.enumerated() {
                let x = CGFloat(index) * (ringDiameter + ringGap) + ringDiameter / 2
                let center = NSPoint(x: x, y: size.height / 2)
                drawRing(
                    center: center,
                    indicator: indicator,
                    isRefreshing: status.isRefreshing,
                    hidesProviderNames: status.hidesProviderNames
                )
            }
        }

        return image
    }

    private static func drawEmptyStateRing(in size: NSSize) {
        let center = NSPoint(x: ringDiameter / 2, y: size.height / 2)
        let radius = ringDiameter / 2 - ringLineWidth / 2
        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360, clockwise: false)
        track.lineWidth = ringLineWidth
        track.lineCapStyle = .round
        NSColor.white.withAlphaComponent(0.30).setStroke()
        track.stroke()
    }

    private static func drawEmptyStatePill(in size: NSSize) {
        let pillRect = NSRect(
            x: 0,
            y: (size.height - pillHeight) / 2,
            width: pillMinWidth,
            height: pillHeight
        )
        let path = NSBezierPath(roundedRect: pillRect, xRadius: pillHeight / 2, yRadius: pillHeight / 2)
        NSColor.white.withAlphaComponent(0.30).setStroke()
        path.lineWidth = pillLineWidth
        path.stroke()
    }

    private static func pillWidth(for indicator: MenuBarProviderIndicator) -> CGFloat {
        max(countdownTextSize(for: indicator.countdownText).width + pillHorizontalPadding, pillMinWidth)
    }

    private static func countdownTextAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.systemFont(ofSize: 8, weight: .bold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.92)
        ]
    }

    private static func countdownTextSize(for text: String) -> NSSize {
        (text as NSString).size(withAttributes: countdownTextAttributes())
    }

    private static func drawCountdownPill(
        center: NSPoint,
        indicator: MenuBarProviderIndicator,
        isRefreshing: Bool
    ) {
        let text = indicator.countdownText
        let textSize = countdownTextSize(for: text)
        let pillWidth = max(textSize.width + pillHorizontalPadding, pillMinWidth)
        let pillRect = NSRect(
            x: center.x - pillWidth / 2,
            y: center.y - pillHeight / 2,
            width: pillWidth,
            height: pillHeight
        )
        let path = NSBezierPath(roundedRect: pillRect, xRadius: pillHeight / 2, yRadius: pillHeight / 2)
        let tint = pillTint(for: indicator)

        tint.withAlphaComponent(0.12).setFill()
        path.fill()

        NSColor.white.withAlphaComponent(0.22).setStroke()
        path.lineWidth = pillLineWidth
        path.stroke()

        let percent = max(0, min(100, indicator.percentUsed ?? 0))
        if percent > 0 {
            let progressWidth = pillRect.width * CGFloat(percent / 100)
            let progressRect = NSRect(
                x: pillRect.minX,
                y: pillRect.minY,
                width: progressWidth,
                height: pillRect.height
            )

            NSGraphicsContext.current?.saveGraphicsState()
            defer { NSGraphicsContext.current?.restoreGraphicsState() }

            path.addClip()
            NSBezierPath(rect: progressRect).addClip()

            tint.setStroke()
            path.lineWidth = pillLineWidth + 0.8
            path.stroke()
        }

        (text as NSString).draw(
            at: NSPoint(x: center.x - textSize.width / 2, y: center.y - textSize.height / 2),
            withAttributes: countdownTextAttributes()
        )

        let badgeCenter = NSPoint(x: pillRect.maxX, y: pillRect.maxY)
        if case .stale = indicator.state {
            drawBadge(center: badgeCenter, color: .systemOrange, offset: NSPoint(x: -2.5, y: -2.5))
        } else if isRefreshing {
            drawBadge(center: badgeCenter, color: .systemBlue, offset: NSPoint(x: -2.5, y: -2.5))
        }
    }

    private static func pillTint(for indicator: MenuBarProviderIndicator) -> NSColor {
        switch indicator.state {
        case .loading, .unavailable:
            return .systemGray
        case .healthy:
            return lowUsageColor(for: indicator.tab)
        case .warning, .stale:
            return .systemOrange
        case .critical:
            return .systemRed
        }
    }

    private static func lowUsageColor(for tab: ProviderTab) -> NSColor {
        switch tab {
        case .codex:
            return .systemBlue
        case .cursor:
            return .systemPurple
        case .devin:
            return .systemGreen
        case .openCodeGo:
            return .systemIndigo
        case .overview, .settings:
            return .systemGray
        }
    }

    private static func drawRing(
        center: NSPoint,
        indicator: MenuBarProviderIndicator,
        isRefreshing: Bool,
        hidesProviderNames: Bool
    ) {
        let radius = ringDiameter / 2 - ringLineWidth / 2
        let track = NSBezierPath()
        track.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: 0,
            endAngle: 360,
            clockwise: false
        )
        track.lineWidth = ringLineWidth
        track.lineCapStyle = .round
        NSColor.white.withAlphaComponent(0.22).setStroke()
        track.stroke()

        switch indicator.state {
        case .loading:
            drawArc(center: center, radius: radius, fraction: 0.35, color: .systemBlue)
            drawProviderIcon(for: indicator.tab, center: center, hidesProviderNames: hidesProviderNames)
        case .unavailable:
            drawUnavailable(center: center, radius: radius)
            drawProviderIcon(for: indicator.tab, center: center, hidesProviderNames: hidesProviderNames, alpha: 0.42)
        case .healthy, .warning, .critical, .stale:
            drawProgressArc(center: center, radius: radius, indicator: indicator)
            drawProviderIcon(for: indicator.tab, center: center, hidesProviderNames: hidesProviderNames)
            if case .stale = indicator.state {
                drawBadge(center: center, color: .systemOrange, offset: NSPoint(x: 4.5, y: 4.5))
            } else if isRefreshing {
                drawBadge(center: center, color: .systemBlue, offset: NSPoint(x: 4.5, y: 4.5))
            }
        }
    }

    private static func drawArc(center: NSPoint, radius: CGFloat, fraction: CGFloat, color: NSColor) {
        let clamped = max(0, min(1, fraction))
        guard clamped > 0 else { return }

        let path = NSBezierPath()
        path.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: 90,
            endAngle: 90 - 359.9 * clamped,
            clockwise: true
        )
        path.lineWidth = ringLineWidth
        path.lineCapStyle = .round
        color.setStroke()
        path.stroke()
    }

    private static func drawProgressArc(center: NSPoint, radius: CGFloat, indicator: MenuBarProviderIndicator) {
        let percent = max(0, min(100, indicator.percentUsed ?? 0))
        let fraction = CGFloat(percent / 100)
        guard fraction > 0 else { return }

        if percent >= 70 {
            drawArc(center: center, radius: radius, fraction: fraction, color: .systemRed)
        } else if percent >= 50 {
            drawArc(center: center, radius: radius, fraction: fraction, color: .systemOrange)
        } else {
            drawGradientArc(
                center: center,
                radius: radius,
                fraction: fraction,
                colors: lowUsageGradient(for: indicator.tab)
            )
        }
    }

    private static func drawGradientArc(
        center: NSPoint,
        radius: CGFloat,
        fraction: CGFloat,
        colors: (start: NSColor, end: NSColor)
    ) {
        let clamped = max(0, min(1, fraction))
        guard clamped > 0 else { return }

        let segments = max(2, Int(ceil(clamped * 28)))
        for index in 0..<segments {
            let startProgress = clamped * CGFloat(index) / CGFloat(segments)
            let endProgress = clamped * CGFloat(index + 1) / CGFloat(segments)
            let colorProgress = CGFloat(index) / CGFloat(max(segments - 1, 1))
            let color = interpolatedColor(from: colors.start, to: colors.end, progress: colorProgress)

            let path = NSBezierPath()
            path.appendArc(
                withCenter: center,
                radius: radius,
                startAngle: 90 - 359.9 * startProgress,
                endAngle: 90 - 359.9 * endProgress,
                clockwise: true
            )
            path.lineWidth = ringLineWidth
            path.lineCapStyle = .round
            color.setStroke()
            path.stroke()
        }
    }

    private static func drawUnavailable(center: NSPoint, radius: CGFloat) {
        let slash = NSBezierPath()
        slash.move(to: NSPoint(x: center.x - radius * 0.65, y: center.y - radius * 0.65))
        slash.line(to: NSPoint(x: center.x + radius * 0.65, y: center.y + radius * 0.65))
        slash.lineWidth = 1.8
        slash.lineCapStyle = .round
        NSColor.white.withAlphaComponent(0.55).setStroke()
        slash.stroke()
    }

    private static func drawBadge(center: NSPoint, color: NSColor, offset: NSPoint) {
        let rect = NSRect(x: center.x + offset.x - 2, y: center.y + offset.y - 2, width: 4, height: 4)
        let badge = NSBezierPath(ovalIn: rect)
        color.setFill()
        badge.fill()
    }

    private static func drawProviderIcon(
        for tab: ProviderTab,
        center: NSPoint,
        hidesProviderNames: Bool,
        alpha: CGFloat = 0.82
    ) {
        if tab == .codex && !hidesProviderNames {
            drawPromptIcon(center: center, alpha: alpha)
            return
        }

        let symbolName = hidesProviderNames ? "circle.grid.2x2" : tab.systemImage
        guard let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else {
            drawFallbackIcon(for: tab, center: center, alpha: alpha)
            return
        }

        let configuration = NSImage.SymbolConfiguration(pointSize: iconPointSize(for: tab), weight: .bold)
        let configured = symbol.withSymbolConfiguration(configuration) ?? symbol
        let image = tintedImage(configured, color: NSColor.white.withAlphaComponent(alpha))
        let layout = iconLayout(for: tab, hidesProviderNames: hidesProviderNames)
        let rect = NSRect(
            x: center.x - layout.size.width / 2 + layout.offset.x,
            y: center.y - layout.size.height / 2 + layout.offset.y,
            width: layout.size.width,
            height: layout.size.height
        )
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    }

    private static func drawPromptIcon(center: NSPoint, alpha: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 6.2, weight: .bold),
            .foregroundColor: NSColor.white.withAlphaComponent(alpha)
        ]
        let attributed = NSAttributedString(string: ">_", attributes: attributes)
        let textSize = attributed.size()
        attributed.draw(at: NSPoint(x: center.x - textSize.width / 2, y: center.y - textSize.height / 2))
    }

    private static func drawFallbackIcon(for tab: ProviderTab, center: NSPoint, alpha: CGFloat) {
        let text: String
        switch tab {
        case .codex:
            text = "C"
        case .cursor:
            text = "↖"
        case .devin:
            text = "D"
        case .openCodeGo:
            text = "</"
        case .overview, .settings:
            text = "S"
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 6.5, weight: .bold),
            .foregroundColor: NSColor.white.withAlphaComponent(alpha)
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributed.size()
        attributed.draw(at: NSPoint(x: center.x - textSize.width / 2, y: center.y - textSize.height / 2))
    }

    private static func tintedImage(_ image: NSImage, color: NSColor) -> NSImage {
        let tinted = NSImage(size: image.size)
        tinted.isTemplate = false
        tinted.lockFocus()
        defer {
            tinted.unlockFocus()
            tinted.isTemplate = false
        }

        let rect = NSRect(origin: .zero, size: image.size)
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        color.set()
        rect.fill(using: .sourceAtop)
        return tinted
    }

    private static func iconPointSize(for tab: ProviderTab) -> CGFloat {
        switch tab {
        case .cursor:
            return 7
        case .openCodeGo:
            return 6.2
        default:
            return 7.2
        }
    }

    private static func iconLayout(
        for tab: ProviderTab,
        hidesProviderNames: Bool
    ) -> (size: NSSize, offset: NSPoint) {
        if hidesProviderNames {
            return (NSSize(width: 9, height: 9), NSPoint(x: 0, y: 0))
        }

        switch tab {
        case .cursor:
            return (NSSize(width: 8.2, height: 8.2), NSPoint(x: 0.8, y: -0.25))
        case .devin:
            return (NSSize(width: 8.8, height: 8.8), NSPoint(x: 0, y: -0.1))
        case .openCodeGo:
            return (NSSize(width: 9.4, height: 9.4), NSPoint(x: 0, y: 0))
        default:
            return (NSSize(width: 9, height: 9), NSPoint(x: 0, y: 0))
        }
    }

    private static func progressFraction(_ percentUsed: Double?) -> CGFloat {
        CGFloat(max(0, min(100, percentUsed ?? 0)) / 100)
    }

    private static func lowUsageGradient(for tab: ProviderTab) -> (start: NSColor, end: NSColor) {
        switch tab {
        case .codex:
            return (NSColor.systemTeal, NSColor.systemBlue)
        case .cursor:
            return (NSColor.systemPurple, NSColor.systemPink)
        case .devin:
            return (NSColor.systemGreen, NSColor.systemMint)
        case .openCodeGo:
            return (NSColor.systemIndigo, NSColor.systemCyan)
        case .overview, .settings:
            return (NSColor.systemGray, NSColor.systemBlue)
        }
    }

    private static func interpolatedColor(from start: NSColor, to end: NSColor, progress: CGFloat) -> NSColor {
        let startRGB = start.usingColorSpace(.deviceRGB) ?? start
        let endRGB = end.usingColorSpace(.deviceRGB) ?? end
        let clamped = max(0, min(1, progress))
        return NSColor(
            calibratedRed: startRGB.redComponent + (endRGB.redComponent - startRGB.redComponent) * clamped,
            green: startRGB.greenComponent + (endRGB.greenComponent - startRGB.greenComponent) * clamped,
            blue: startRGB.blueComponent + (endRGB.blueComponent - startRGB.blueComponent) * clamped,
            alpha: startRGB.alphaComponent + (endRGB.alphaComponent - startRGB.alphaComponent) * clamped
        )
    }
}

private struct SectionBlock<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct DailyUsageChart: View {
    let buckets: [AccountTokenUsageDailyBucket]

    private var displayedBuckets: [AccountTokenUsageDailyBucket] {
        Array(buckets.sorted { $0.startDate < $1.startDate }.suffix(14))
    }

    private var maxTokens: Int64 {
        max(displayedBuckets.map(\.tokens).max() ?? 0, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recent Codex tokens")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("\(displayedBuckets.count)d")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(displayedBuckets.enumerated()), id: \.offset) { _, bucket in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.accentColor.opacity(0.78))
                            .frame(height: barHeight(for: bucket.tokens))
                        Text(dayLabel(bucket.startDate))
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 54, alignment: .bottom)
                    .help("\(UsageFormatting.compactNumber(bucket.tokens)) tokens")
                }
            }
            .frame(height: 62)
        }
    }

    private func barHeight(for tokens: Int64) -> CGFloat {
        let ratio = CGFloat(Double(tokens) / Double(maxTokens))
        return max(4, ratio * 42)
    }

    private func dayLabel(_ startDate: String) -> String {
        guard let day = startDate.split(separator: "-").last else { return startDate }
        return String(day)
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    var caption: String?
    var captionColor: Color = .secondary

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(captionColor)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .topLeading)
    }
}

private struct StatusLine: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 16)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SMark: View {
    var body: some View {
        Text("S")
            .font(.system(size: 15, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(red: 0.06, green: 0.11, blue: 0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color(red: 0.22, green: 0.38, blue: 0.58), lineWidth: 1)
            )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
