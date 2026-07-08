import AppKit
import ResetStatCore
import SwiftUI

struct ResetStatPopover: View {
    @ObservedObject var viewModel: UsageViewModel
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
        .onAppear(perform: prepareSetupView)
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
            OverviewSectionView(
                summaries: viewModel.providerSummaries,
                billingExpiries: viewModel.billingExpiries,
                now: viewModel.now,
                hidesProviderNames: viewModel.hidesProviderNames,
                onSelectTab: { selectedTab = $0 }
            )
        case .codex:
            if let snapshot = viewModel.snapshot {
                CodexSectionView(
                    snapshot: snapshot,
                    now: viewModel.now,
                    hidesProviderNames: viewModel.hidesProviderNames
                )
            } else {
                unavailableView
            }
        case .cursor:
            CursorSectionView(
                snapshot: viewModel.cursorSnapshot,
                state: viewModel.cursorState,
                now: viewModel.now,
                hidesProviderNames: viewModel.hidesProviderNames
            )
        case .devin:
            DevinSectionView(
                snapshots: viewModel.desktopQuotaSnapshots,
                state: viewModel.desktopQuotaState,
                now: viewModel.now,
                hidesProviderNames: viewModel.hidesProviderNames
            )
        case .openCodeGo:
            OpenCodeGoSectionView(
                snapshot: viewModel.openCodeGoSnapshot,
                state: viewModel.openCodeGoState,
                now: viewModel.now,
                hidesProviderNames: viewModel.hidesProviderNames,
                dashboardURL: viewModel.openCodeGoDashboardURL
            )
        case .settings:
            SettingsSectionView(viewModel: viewModel, selectedTab: $selectedTab)
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
                Image(systemName: providerIcon(tab.systemImage, hidesProviderNames: viewModel.hidesProviderNames))
                    .font(.system(size: 10, weight: .semibold))
                Text(providerName(tab.displayName, privateName: tab.privateName, hidesProviderNames: viewModel.hidesProviderNames))
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
        .help(providerName(tab.displayName, privateName: tab.privateName, hidesProviderNames: viewModel.hidesProviderNames))
    }

    private var loadingView: some View {
        StatusLine(icon: "hourglass", color: .secondary, text: "Loading usage...")
            .padding(.vertical, 18)
    }

    private func errorView(message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            switch selectedTab {
            case .overview:
                OverviewSectionView(
                    summaries: viewModel.providerSummaries,
                    billingExpiries: viewModel.billingExpiries,
                    now: viewModel.now,
                    hidesProviderNames: viewModel.hidesProviderNames,
                    onSelectTab: { selectedTab = $0 }
                )
            case .codex:
                if let snapshot = viewModel.snapshot {
                    CodexSectionView(
                        snapshot: snapshot,
                        now: viewModel.now,
                        hidesProviderNames: viewModel.hidesProviderNames
                    )
                }
                SectionBlock {
                    StatusLine(icon: "exclamationmark.circle", color: .orange, text: providerSafeMessage(message, hidesProviderNames: viewModel.hidesProviderNames))
                }
            case .cursor:
                CursorSectionView(
                    snapshot: viewModel.cursorSnapshot,
                    state: viewModel.cursorState,
                    now: viewModel.now,
                    hidesProviderNames: viewModel.hidesProviderNames
                )
            case .devin:
                DevinSectionView(
                    snapshots: viewModel.desktopQuotaSnapshots,
                    state: viewModel.desktopQuotaState,
                    now: viewModel.now,
                    hidesProviderNames: viewModel.hidesProviderNames
                )
            case .openCodeGo:
                OpenCodeGoSectionView(
                    snapshot: viewModel.openCodeGoSnapshot,
                    state: viewModel.openCodeGoState,
                    now: viewModel.now,
                    hidesProviderNames: viewModel.hidesProviderNames,
                    dashboardURL: viewModel.openCodeGoDashboardURL
                )
            case .settings:
                SettingsSectionView(viewModel: viewModel, selectedTab: $selectedTab)
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

    private func prepareSetupView() {
        if viewModel.configuration.setup.showsFirstLaunchSetup {
            selectedTab = .settings
        }
    }
}
