import AppKit
import LimitLensCore
import SwiftUI

struct LimitLensPopover: View {
    @ObservedObject var viewModel: UsageViewModel
    @State private var selectedTab: ProviderTab = .overview
    @Environment(\.colorScheme) private var colorScheme

    private var appearance: AppAppearance {
        viewModel.configuration.appearance
    }

    var body: some View {
        Group {
            switch appearance {
            case .classic:
                classicLayout
            case .studio:
                sidebarLayout
            case .terminal:
                sidebarLayout
                    .environment(\.colorScheme, .dark)
                    .foregroundStyle(Color(red: 0.76, green: 1, blue: 0.79))
            case .pulse:
                pulseLayout
            case .harbor:
                harborLayout
            case .constellation:
                constellationLayout
                    .environment(\.colorScheme, .dark)
            }
        }
        .environment(\.appAppearance, appearance)
        .fontDesign(appearance == .terminal ? .monospaced : .default)
        .tint(appearance.accentColor)
        .preferredColorScheme(appearance.preferredColorScheme)
        .frame(width: appearance.popoverWidth)
        .background(appearance.windowBackground(for: colorScheme))
        .onAppear(perform: prepareSetupView)
    }

    private var classicLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            tabBar
            contentView
            footer
        }
        .padding(appearance.outerPadding)
    }

    private var pulseLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            pulseHeader
            contentView
            footer
            bottomTabBar
        }
        .padding(appearance.outerPadding)
    }

    private var harborLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            harborHeader
            segmentedTabBar
            contentView
            footer
        }
        .padding(appearance.outerPadding)
    }

    private var constellationLayout: some View {
        HStack(alignment: .top, spacing: 0) {
            constellationRail

            VStack(alignment: .leading, spacing: 12) {
                constellationHeader
                contentView
                constellationFooter
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.075, green: 0.062, blue: 0.145).opacity(0.96),
                        Color(red: 0.035, green: 0.032, blue: 0.080).opacity(0.98)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: ConstellationPanelShape(cornerRadius: 24, cut: 28)
            )
            .overlay(
                ConstellationPanelShape(cornerRadius: 24, cut: 28)
                    .stroke(
                        LinearGradient(
                            colors: [
                                appearance.accentColor.opacity(0.42),
                                Color.cyan.opacity(0.13),
                                appearance.accentColor.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: appearance.constellationShadowColor(for: colorScheme), radius: 22, x: -4, y: 8)
        }
        .padding(appearance.outerPadding)
        .background(constellationField)
    }

    private var constellationField: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.020, green: 0.018, blue: 0.050),
                    Color(red: 0.048, green: 0.028, blue: 0.095),
                    Color(red: 0.018, green: 0.035, blue: 0.070)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Ellipse()
                .stroke(appearance.accentColor.opacity(0.12), lineWidth: 1)
                .frame(width: 410, height: 170)
                .rotationEffect(.degrees(-24))
                .offset(x: 210, y: -150)

            Ellipse()
                .stroke(Color.cyan.opacity(0.08), lineWidth: 1)
                .frame(width: 330, height: 115)
                .rotationEffect(.degrees(18))
                .offset(x: -230, y: 230)

            VStack {
                HStack {
                    Circle()
                        .fill(appearance.accentColor.opacity(0.70))
                        .frame(width: 3, height: 3)
                        .shadow(color: appearance.accentColor, radius: 5)
                    Spacer()
                    Circle()
                        .fill(Color.cyan.opacity(0.6))
                        .frame(width: 2, height: 2)
                }
                Spacer()
                HStack {
                    Spacer()
                    Circle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 2, height: 2)
                }
            }
            .padding(30)
        }
    }

    private var constellationRail: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(appearance.accentColor.opacity(0.28), lineWidth: 1)
                    Circle()
                        .trim(from: 0.12, to: 0.82)
                        .stroke(appearance.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-62))
                    LimitLensMark()
                        .padding(6)
                }
                .frame(width: 35, height: 35)

                VStack(alignment: .leading, spacing: 0) {
                    Text("LIMIT")
                    Text("LENS")
                        .foregroundStyle(appearance.accentColor)
                }
                .font(.system(size: 9, weight: .black, design: .rounded))
                .tracking(1.3)
            }

            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                appearance.accentColor.opacity(0.50),
                                Color.cyan.opacity(0.24),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 1)
                    .padding(.leading, 17)
                    .padding(.vertical, 18)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array((viewModel.visibleTabs + [.settings]).enumerated()), id: \.element.id) { index, tab in
                        constellationRailButton(tab, index: index)
                    }
                }
            }

            Spacer(minLength: 4)
        }
        .padding(.vertical, 10)
        .frame(width: 112, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func constellationRailButton(_ tab: ProviderTab, index: Int) -> some View {
        let isSelected = selectedTab == tab
        let label = providerName(
            tab.displayName,
            privateName: tab.privateName,
            hidesProviderNames: viewModel.hidesProviderNames
        )
        return Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? appearance.accentColor : Color(red: 0.045, green: 0.038, blue: 0.09))
                        .frame(width: isSelected ? 34 : 30, height: isSelected ? 34 : 30)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? appearance.accentColor.opacity(0.65) : Color.white.opacity(0.10), lineWidth: 1)
                        )
                        .shadow(color: isSelected ? appearance.accentColor.opacity(0.60) : .clear, radius: 8)
                    Image(systemName: providerIcon(tab.systemImage, hidesProviderNames: viewModel.hidesProviderNames))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.48))
                }
                .frame(width: 35, height: 35)

                VStack(alignment: .leading, spacing: 1) {
                    Text(String(format: "%02d", index))
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(isSelected ? appearance.accentColor : Color.white.opacity(0.24))
                    Text(label)
                        .font(.system(size: 9, weight: isSelected ? .bold : .medium, design: .rounded))
                        .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.44))
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 2)
            .padding(.leading, 0)
            .padding(.trailing, 5)
            .frame(width: 108, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                Group {
                    if isSelected {
                        ConstellationPanelShape(cornerRadius: 12, cut: 9)
                            .fill(appearance.accentColor.opacity(0.10))
                    }
                }
            )
            .overlay(alignment: .trailing) {
                if isSelected {
                    Capsule()
                        .fill(Color.cyan.opacity(0.75))
                        .frame(width: 2, height: 14)
                        .shadow(color: .cyan, radius: 4)
                }
            }
        }
        .buttonStyle(.plain)
        .help(label)
    }

    private var constellationHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("FIELD")
                    Circle()
                        .fill(appearance.accentColor)
                        .frame(width: 4, height: 4)
                    Text(String(format: "%02d", constellationTabIndex))
                }
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(appearance.accentColor)

                Text(
                    providerName(
                        selectedTab.displayName,
                        privateName: selectedTab.privateName,
                        hidesProviderNames: viewModel.hidesProviderNames
                    )
                )
                .font(.system(size: 25, weight: .light, design: .rounded))
                .foregroundStyle(.white)
            }

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 5, height: 5)
                    .shadow(color: .cyan, radius: 5)
                Text("\(viewModel.providerSummaries.count) NODES LIVE")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(Color.white.opacity(0.52))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.035), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))

            Button {
                Task { await viewModel.refresh() }
            } label: {
                ZStack {
                    Circle()
                        .stroke(appearance.accentColor.opacity(0.18), lineWidth: 1)
                    Circle()
                        .trim(from: 0.05, to: 0.68)
                        .stroke(
                            AngularGradient(colors: [appearance.accentColor, .cyan], center: .center),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                        .rotationEffect(.degrees(35))
                        .padding(4)
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 36, height: 36)
            }
            .buttonStyle(CompactHitTargetButtonStyle())
            .help("Refresh all providers")
        }
    }

    private var constellationFooter: some View {
        HStack(spacing: 8) {
            if let fetchedAt = latestFetchDate {
                Circle()
                    .fill(Color.cyan.opacity(0.8))
                    .frame(width: 4, height: 4)
                Text("SYNC \(fetchedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(Color.white.opacity(0.38))
                    .monospacedDigit()
            }

            Spacer()

            Button {
                selectedTab = .settings
            } label: {
                Image(systemName: "gearshape")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(CompactHitTargetButtonStyle())
            .foregroundStyle(selectedTab == .settings ? appearance.accentColor : Color.white.opacity(0.46))
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
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(CompactHitTargetButtonStyle())
            .foregroundStyle(menuBarDisplay == .logos ? Color.white.opacity(0.46) : appearance.accentColor)
            .help(menuBarDisplayHelp)

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(CompactHitTargetButtonStyle())
            .foregroundStyle(Color.white.opacity(0.46))
            .help("Quit")
        }
    }

    private var constellationTabIndex: Int {
        (viewModel.visibleTabs + [.settings]).firstIndex(of: selectedTab) ?? 0
    }

    private var harborHeader: some View {
        HStack(spacing: 10) {
            LimitLensMark()
                .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text("LimitLens")
                    .font(.subheadline.weight(.semibold))
                Text("Harbor · \(selectedTab.displayName)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(appearance.accentColor)
            }

            Spacer()

            Button {
                Task { await viewModel.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(appearance.accentColor)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(appearance.accentColor.opacity(0.12))
                    )
            }
            .buttonStyle(CompactHitTargetButtonStyle())
            .help("Refresh all providers")
        }
    }

    private var segmentedTabBar: some View {
        HStack(spacing: 2) {
            ForEach(viewModel.visibleTabs) { tab in
                harborTabButton(for: tab)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(appearance.panelBackground(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(appearance.accentColor.opacity(0.16), lineWidth: 1)
        )
    }

    private func harborTabButton(for tab: ProviderTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            Text(
                providerName(
                    tab.displayName,
                    privateName: tab.privateName,
                    hidesProviderNames: viewModel.hidesProviderNames
                )
            )
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(isSelected ? Color.white : Color.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? appearance.accentColor : .clear)
            )
        }
        .buttonStyle(.plain)
        .help(
            providerName(
                tab.displayName,
                privateName: tab.privateName,
                hidesProviderNames: viewModel.hidesProviderNames
            )
        )
    }

    private var pulseHeader: some View {
        HStack(spacing: 10) {
            LimitLensMark()
                .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text("LimitLens")
                    .font(.subheadline.weight(.semibold))
                Text(selectedTab.displayName)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(appearance.accentColor)
            }

            Spacer()

            Button {
                Task { await viewModel.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(appearance.accentColor)
                    .frame(width: 28, height: 28)
                    .background(
                        Capsule()
                            .fill(appearance.accentColor.opacity(0.12))
                    )
            }
            .buttonStyle(CompactHitTargetButtonStyle())
            .help("Refresh all providers")
        }
    }

    private var bottomTabBar: some View {
        HStack(spacing: 4) {
            ForEach(viewModel.visibleTabs) { tab in
                bottomTabButton(for: tab)
            }
            bottomTabButton(for: .settings)
        }
        .padding(5)
        .background(
            Capsule(style: .continuous)
                .fill(appearance.panelBackground(for: colorScheme))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(appearance.accentColor.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: appearance.pulseShadowColor(for: colorScheme), radius: 8, y: 3)
    }

    private func bottomTabButton(for tab: ProviderTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            Image(systemName: providerIcon(tab.systemImage, hidesProviderNames: viewModel.hidesProviderNames))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : Color.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .contentShape(Rectangle())
                .background(
                    Capsule()
                        .fill(isSelected ? appearance.accentColor : .clear)
                )
        }
        .buttonStyle(.plain)
        .help(providerName(tab.displayName, privateName: tab.privateName, hidesProviderNames: viewModel.hidesProviderNames))
    }

    private var sidebarLayout: some View {
        HStack(alignment: .top, spacing: appearance == .studio ? 14 : 8) {
            sideNavigation

            VStack(alignment: .leading, spacing: appearance == .studio ? 12 : 8) {
                workspaceHeader
                contentView
                footer
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(appearance.outerPadding)
    }

    private var workspaceHeader: some View {
        HStack(spacing: 8) {
            if appearance == .studio {
                Text("LIMITLENS / LIVE WORKSPACE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(.secondary)
            } else {
                Text("$")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(.green)
                Text("limitlens --view \(selectedTab.rawValue)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.green.opacity(0.72))
            }
            Spacer()
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: appearance == .terminal ? 1 : 8)
                            .fill(appearance.accentColor.opacity(0.10))
                    )
            }
            .buttonStyle(CompactHitTargetButtonStyle())
            .help("Refresh all providers")
        }
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
            .buttonStyle(CompactHitTargetButtonStyle())
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
                    isCollectingPaceData: viewModel.collectingPaceData.contains(.codex),
                    paceChart: viewModel.quotaPaceChart(for: .codex)
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
                isCollectingPaceData: viewModel.collectingPaceData.contains(.cursor),
                paceChart: viewModel.quotaPaceChart(for: .cursor)
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
                isCollectingPaceData: viewModel.collectingPaceData.contains(.devin),
                paceChart: viewModel.quotaPaceChart(for: .devin)
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
                isCollectingPaceData: viewModel.collectingPaceData.contains(.openCodeGo),
                paceChart: viewModel.quotaPaceChart(for: .openCodeGo)
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

    private var sideNavigation: some View {
        VStack(alignment: appearance == .terminal ? .center : .leading, spacing: 8) {
            if appearance == .studio {
                HStack(spacing: 8) {
                    LimitLensMark()
                        .frame(width: 26, height: 26)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("LimitLens")
                            .font(.subheadline.weight(.semibold))
                        Text("Workspace")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 5)
                .padding(.bottom, 5)
            } else {
                LimitLensMark()
                    .frame(width: 24, height: 24)
                    .padding(.bottom, 4)
            }

            ForEach(viewModel.visibleTabs) { tab in
                sideNavigationButton(for: tab)
            }

            Divider()
                .padding(.vertical, 2)

            sideNavigationButton(for: .settings)
        }
        .padding(appearance == .terminal ? 6 : 8)
        .frame(width: appearance == .terminal ? 48 : 144, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: appearance.panelCornerRadius, style: .continuous)
                .fill(appearance.panelBackground(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: appearance.panelCornerRadius, style: .continuous)
                .stroke(appearance.accentColor.opacity(appearance == .terminal ? 0.30 : 0.10), lineWidth: appearance == .terminal ? 1 : 0.5)
        )
    }

    private func sideNavigationButton(for tab: ProviderTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 7) {
                Image(systemName: providerIcon(tab.systemImage, hidesProviderNames: viewModel.hidesProviderNames))
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 18, height: 18)
                if appearance == .studio {
                    Text(providerName(tab.displayName, privateName: tab.privateName, hidesProviderNames: viewModel.hidesProviderNames))
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(isSelected ? appearance.accentColor : Color.secondary)
            .padding(.horizontal, appearance == .terminal ? 4 : 7)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: appearance == .terminal ? .center : .leading)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: appearance == .terminal ? 1 : 8)
                    .fill(isSelected ? appearance.accentColor.opacity(0.13) : .clear)
            )
        }
        .buttonStyle(.plain)
        .help(providerName(tab.displayName, privateName: tab.privateName, hidesProviderNames: viewModel.hidesProviderNames))
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
            .contentShape(Rectangle())
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
                        onRefresh: { Task { await viewModel.refreshProvider(.codex) } },
                        paceProjection: viewModel.paceProjections[.codex],
                        isCollectingPaceData: viewModel.collectingPaceData.contains(.codex),
                        paceChart: viewModel.quotaPaceChart(for: .codex)
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
                    onRefresh: { Task { await viewModel.refreshProvider(.cursor) } },
                    paceProjection: viewModel.paceProjections[.cursor],
                    isCollectingPaceData: viewModel.collectingPaceData.contains(.cursor),
                    paceChart: viewModel.quotaPaceChart(for: .cursor)
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
                    isCollectingPaceData: viewModel.collectingPaceData.contains(.devin),
                    paceChart: viewModel.quotaPaceChart(for: .devin)
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
                    isCollectingPaceData: viewModel.collectingPaceData.contains(.openCodeGo),
                    paceChart: viewModel.quotaPaceChart(for: .openCodeGo)
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
            HStack(spacing: 6) {
                if let fetchedAt = latestFetchDate {
                    Text("Synced \(fetchedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                    Text("·")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Text(appVersionLabel)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .help("Running version")
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
            .buttonStyle(CompactHitTargetButtonStyle())
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
            .buttonStyle(CompactHitTargetButtonStyle())
            .help(menuBarDisplayHelp)
            Button("Quit") {
                NSApp.terminate(nil)
            }
            .buttonStyle(CompactHitTargetButtonStyle())
            .font(.caption)
        }
    }

    private var appVersionLabel: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        return "v\(version)"
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
