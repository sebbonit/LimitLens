import AppKit
import LimitLensCore
import SwiftUI

struct LimitLensPopover: View {
    @ObservedObject var viewModel: UsageViewModel
    @State private var selectedTab: ProviderTab = .overview

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            tabBar
            contentView
            footer
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear(perform: prepareSetupView)
    }

    private var header: some View {
        HStack(spacing: 9) {
            LimitLensMark()
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 0) {
                Text("LimitLens")
                    .font(.subheadline.weight(.semibold))
                Text("Usage monitor")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.secondary.opacity(0.10)))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Refresh all providers")
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
                onSelectTab: { selectedTab = $0 },
                paceProjections: viewModel.paceProjections,
                collectingPaceData: viewModel.collectingPaceData,
                exhaustionSummaries: viewModel.exhaustionSummaries
            )
        case .codex:
            if let snapshot = viewModel.snapshot {
                CodexSectionView(
                    snapshot: snapshot,
                    now: viewModel.now,
                    hidesProviderNames: viewModel.hidesProviderNames,
                    isRefreshing: viewModel.isProviderRefreshing(.codex),
                    lastUpdated: viewModel.lastFetchAt[.codex],
                    onRefresh: { Task { await viewModel.refreshProvider(.codex) } },
                    paceProjection: viewModel.paceProjections[.codex],
                    isCollectingPaceData: viewModel.collectingPaceData.contains(.codex)
                )
            } else {
                unavailableView
            }
        case .cursor:
            CursorSectionView(
                snapshot: viewModel.cursorSnapshot,
                state: viewModel.cursorState,
                now: viewModel.now,
                hidesProviderNames: viewModel.hidesProviderNames,
                isRefreshing: viewModel.isProviderRefreshing(.cursor),
                lastUpdated: viewModel.lastFetchAt[.cursor],
                onRefresh: { Task { await viewModel.refreshProvider(.cursor) } },
                paceProjection: viewModel.paceProjections[.cursor],
                isCollectingPaceData: viewModel.collectingPaceData.contains(.cursor)
            )
        case .devin:
            DevinSectionView(
                snapshots: viewModel.desktopQuotaSnapshots,
                state: viewModel.desktopQuotaState,
                now: viewModel.now,
                hidesProviderNames: viewModel.hidesProviderNames,
                isRefreshing: viewModel.isProviderRefreshing(.devin),
                lastUpdated: viewModel.lastFetchAt[.devin],
                onRefresh: { Task { await viewModel.refreshProvider(.devin) } },
                paceProjection: viewModel.paceProjections[.devin],
                isCollectingPaceData: viewModel.collectingPaceData.contains(.devin)
            )
        case .openCodeGo:
            OpenCodeGoSectionView(
                snapshot: viewModel.openCodeGoSnapshot,
                state: viewModel.openCodeGoState,
                now: viewModel.now,
                hidesProviderNames: viewModel.hidesProviderNames,
                dashboardURL: viewModel.openCodeGoDashboardURL,
                isRefreshing: viewModel.isProviderRefreshing(.openCodeGo),
                lastUpdated: viewModel.lastFetchAt[.openCodeGo],
                onRefresh: { Task { await viewModel.refreshProvider(.openCodeGo) } },
                paceProjection: viewModel.paceProjections[.openCodeGo],
                isCollectingPaceData: viewModel.collectingPaceData.contains(.openCodeGo)
            )
        case .settings:
            SettingsSectionView(viewModel: viewModel, selectedTab: $selectedTab)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 3) {
            ForEach(viewModel.visibleTabs) { tab in
                tabButton(for: tab)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
        )
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
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.primary.opacity(0.08) : .clear)
            )
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
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
                        hidesProviderNames: viewModel.hidesProviderNames,
                        isRefreshing: viewModel.isProviderRefreshing(.codex),
                        lastUpdated: viewModel.lastFetchAt[.codex],
                        onRefresh: { Task { await viewModel.refreshProvider(.codex) } }
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
                    hidesProviderNames: viewModel.hidesProviderNames,
                    isRefreshing: viewModel.isProviderRefreshing(.cursor),
                    lastUpdated: viewModel.lastFetchAt[.cursor],
                    onRefresh: { Task { await viewModel.refreshProvider(.cursor) } }
                )
            case .devin:
                DevinSectionView(
                    snapshots: viewModel.desktopQuotaSnapshots,
                    state: viewModel.desktopQuotaState,
                    now: viewModel.now,
                    hidesProviderNames: viewModel.hidesProviderNames,
                    isRefreshing: viewModel.isProviderRefreshing(.devin),
                    lastUpdated: viewModel.lastFetchAt[.devin],
                    onRefresh: { Task { await viewModel.refreshProvider(.devin) } }
                )
            case .openCodeGo:
                OpenCodeGoSectionView(
                    snapshot: viewModel.openCodeGoSnapshot,
                    state: viewModel.openCodeGoState,
                    now: viewModel.now,
                    hidesProviderNames: viewModel.hidesProviderNames,
                    dashboardURL: viewModel.openCodeGoDashboardURL,
                    isRefreshing: viewModel.isProviderRefreshing(.openCodeGo),
                    lastUpdated: viewModel.lastFetchAt[.openCodeGo],
                    onRefresh: { Task { await viewModel.refreshProvider(.openCodeGo) } }
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
                Text("Synced \(fetchedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .monospacedDigit()
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
        case .auto: return "arrow.triangle.2.circlepath"
        case .hidden: return "eye.slash"
        }
    }

    private var menuBarDisplayHelp: String {
        switch menuBarDisplay {
        case .logos: return "Menu bar: logos"
        case .countdowns: return "Menu bar: countdowns"
        case .auto: return "Menu bar: auto-switch"
        case .hidden: return "Menu bar: hidden"
        }
    }

    private func prepareSetupView() {
        if viewModel.configuration.setup.showsFirstLaunchSetup {
            selectedTab = .settings
        }
    }
}
