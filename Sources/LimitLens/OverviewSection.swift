import AppKit
import LimitLensCore
import SwiftUI

struct OverviewSectionView: View {
    let summaries: [ProviderUsageSummary]
    let billingExpiries: [BillingExpiry]
    let now: Date
    let hidesProviderNames: Bool
    let onSelectTab: (ProviderTab) -> Void
    var paceProjections: [ProviderTab: PaceProjection] = [:]
    var collectingPaceData: Set<ProviderTab> = []
    var exhaustionSummaries: [ExhaustionSpeedSummary] = []
    @Environment(\.appAppearance) private var appearance
    @Environment(\.colorScheme) private var colorScheme

    @ViewBuilder
    var body: some View {
        switch appearance {
        case .classic:
            classicOverview
        case .studio:
            studioOverview
        case .terminal:
            terminalOverview
        case .pulse:
            pulseOverview
        case .harbor:
            harborOverview
        case .constellation:
            constellationOverview
        }
    }

    private var classicOverview: some View {
        SectionBlock {
            VStack(alignment: .leading, spacing: 9) {
                SectionHeader(
                    title: "Overview",
                    detail: overviewDetail,
                    systemImage: "speedometer",
                    hidesProviderNames: hidesProviderNames
                )

                billingExpirySection

                Divider()

                if summaries.isEmpty {
                    StatusLine(icon: "slider.horizontal.3", color: .secondary, text: "No providers enabled.")
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Providers")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        VStack(spacing: 0) {
                            ForEach(Array(summaries.enumerated()), id: \.element.id) { index, summary in
                                overviewRow(summary)
                                if index < summaries.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                }

                Divider()

                exhaustionSpeedSection
            }
        }
    }

    private var studioOverview: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Usage workspace")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text(overviewDetail)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(billingSummaryDetail)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(appearance.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(appearance.accentColor.opacity(0.09), in: Capsule())
            }

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                ForEach(summaries) { summary in
                    studioProviderCard(summary)
                }
            }

            HStack(alignment: .top, spacing: 10) {
                studioBillingPanel
                studioHistoryPanel
            }
        }
    }

    private func studioProviderCard(_ summary: ProviderUsageSummary) -> some View {
        Button {
            onSelectTab(summary.tab)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: providerIcon(summary.tab.systemImage, hidesProviderNames: hidesProviderNames))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(severityColor(summary.severity))
                        .frame(width: 32, height: 32)
                        .background(severityColor(summary.severity).opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                }

                Text(providerName(summary.tab.displayName, privateName: summary.tab.privateName, hidesProviderNames: hidesProviderNames))
                    .font(.headline)
                Text(providerSafeMessage(summary.detail, hidesProviderNames: hidesProviderNames))
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                Text(overviewSupportText(for: summary))
                    .font(.caption2)
                    .foregroundStyle(overviewSupportColor(for: summary))
                    .lineLimit(2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 142, alignment: .topLeading)
            .background(appearance.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(severityColor(summary.severity).opacity(0.13), lineWidth: 1)
            )
            .shadow(color: appearance.studioShadowColor(for: colorScheme), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var studioBillingPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Renewals", systemImage: "calendar")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            ForEach(billingExpiries) { entry in
                billingExpiryCell(entry)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(appearance.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 14))
    }

    private var studioHistoryPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Exhaustion history", systemImage: "bolt")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            if exhaustionSummaries.isEmpty {
                Text("No exhausted cycles yet")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(exhaustionSummaries) { entry in
                    exhaustionSpeedRow(entry)
                }
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(appearance.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 14))
    }

    private var terminalOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            terminalOverviewHeader

            terminalRule("ACTIVE PROVIDERS")

            ForEach(summaries) { summary in
                terminalProviderRow(summary)
            }

            terminalRule("RENEWAL QUEUE")
            terminalBillingGrid
        }
        .padding(12)
        .background(Color.black.opacity(0.20))
        .overlay(Rectangle().stroke(Color.green.opacity(0.34), lineWidth: 1))
    }

    private var pulseOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Live pulse")
                        .font(.title3.weight(.bold))
                    Text(overviewDetail)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(billingSummaryDetail)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(appearance.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(appearance.accentColor.opacity(0.10), in: Capsule())
            }

            VStack(spacing: 8) {
                ForEach(summaries) { summary in
                    pulseProviderRow(summary)
                }
            }

            if summaries.isEmpty {
                StatusLine(icon: "slider.horizontal.3", color: .secondary, text: "No providers enabled.")
            }

            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Renewals")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    ForEach(billingExpiries) { entry in
                        billingExpiryCell(entry)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(appearance.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(appearance.accentColor.opacity(0.12), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Exhaustion")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    if exhaustionSummaries.isEmpty {
                        Text("No exhausted cycles yet")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(exhaustionSummaries.prefix(3)) { entry in
                            exhaustionSpeedRow(entry)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(appearance.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(appearance.accentColor.opacity(0.12), lineWidth: 1)
                )
            }
        }
    }

    private func pulseProviderRow(_ summary: ProviderUsageSummary) -> some View {
        Button {
            onSelectTab(summary.tab)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(severityColor(summary.severity).opacity(0.15), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: (summary.percentUsed ?? 0) / 100)
                        .stroke(severityColor(summary.severity), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: providerIcon(summary.tab.systemImage, hidesProviderNames: hidesProviderNames))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(severityColor(summary.severity))
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(providerName(summary.tab.displayName, privateName: summary.tab.privateName, hidesProviderNames: hidesProviderNames))
                        .font(.subheadline.weight(.semibold))
                    Text(overviewSupportText(for: summary))
                        .font(.caption2)
                        .foregroundStyle(overviewSupportColor(for: summary))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(providerSafeMessage(summary.detail, hidesProviderNames: hidesProviderNames))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(summary.severity == .unavailable ? .secondary : .primary)
                    Text(summary.secondaryDetail.map { providerSafeMessage($0, hidesProviderNames: hidesProviderNames) } ?? "—")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(12)
            .background(appearance.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(severityColor(summary.severity).opacity(0.14), lineWidth: 1)
            )
            .shadow(color: appearance.pulseShadowColor(for: colorScheme), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }

    private var harborOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dock overview")
                        .font(.title3.weight(.semibold))
                    Text(overviewDetail)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(billingSummaryDetail)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(appearance.accentColor)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(appearance.accentColor.opacity(0.10))
                    )
            }

            if summaries.isEmpty {
                StatusLine(icon: "slider.horizontal.3", color: .secondary, text: "No providers enabled.")
            } else {
                VStack(spacing: 7) {
                    ForEach(summaries) { summary in
                        harborProviderRow(summary)
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(billingExpiries) { entry in
                        billingExpiryCell(entry)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(minWidth: 150, alignment: .leading)
                            .background(
                                appearance.cardBackground(for: colorScheme),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(appearance.accentColor.opacity(0.12), lineWidth: 1)
                            )
                    }
                }
            }

            if !exhaustionSummaries.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Exhaustion history")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    ForEach(exhaustionSummaries.prefix(3)) { entry in
                        exhaustionSpeedRow(entry)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(
                    appearance.cardBackground(for: colorScheme),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(appearance.accentColor.opacity(0.12), lineWidth: 1)
                )
            }
        }
    }

    private func harborProviderRow(_ summary: ProviderUsageSummary) -> some View {
        Button {
            onSelectTab(summary.tab)
        } label: {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(severityColor(summary.severity))
                    .frame(width: 3)
                    .padding(.vertical, 8)

                HStack(spacing: 10) {
                    Image(systemName: providerIcon(summary.tab.systemImage, hidesProviderNames: hidesProviderNames))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(severityColor(summary.severity))
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(severityColor(summary.severity).opacity(0.12))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(providerName(summary.tab.displayName, privateName: summary.tab.privateName, hidesProviderNames: hidesProviderNames))
                            .font(.subheadline.weight(.semibold))
                        Text(overviewSupportText(for: summary))
                            .font(.caption2)
                            .foregroundStyle(overviewSupportColor(for: summary))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(providerSafeMessage(summary.detail, hidesProviderNames: hidesProviderNames))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(summary.severity == .unavailable ? .secondary : .primary)
                        if let percent = summary.percentUsed {
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(severityColor(summary.severity).opacity(0.12))
                                    Capsule()
                                        .fill(severityColor(summary.severity))
                                        .frame(width: max(4, geometry.size.width * percent / 100))
                                }
                            }
                            .frame(width: 54, height: 4)
                        } else {
                            Text(summary.secondaryDetail.map { providerSafeMessage($0, hidesProviderNames: hidesProviderNames) } ?? "—")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.leading, 10)
                .padding(.trailing, 12)
                .padding(.vertical, 10)
            }
            .background(
                appearance.cardBackground(for: colorScheme),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(severityColor(summary.severity).opacity(0.14), lineWidth: 1)
            )
            .shadow(color: appearance.harborShadowColor(for: colorScheme), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var constellationOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 18) {
                constellationCore

                VStack(alignment: .leading, spacing: 6) {
                    Text("SIGNAL CONSTELLATION")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.8)
                        .foregroundStyle(appearance.accentColor)
                    Text(overviewDetail == "All clear" ? "Every orbit is holding." : overviewDetail)
                        .font(.system(size: 21, weight: .light, design: .rounded))
                        .foregroundStyle(.white)
                    Text("\(summaries.count) provider nodes · \(billingSummaryDetail.lowercased())")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.44))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("FIELD LOAD")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(Color.white.opacity(0.32))
                    Text(percentText(constellationAverageUsage))
                        .font(.system(size: 28, weight: .ultraLight, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 4)

            if summaries.isEmpty {
                SectionBlock {
                    StatusLine(icon: "slider.horizontal.3", color: .secondary, text: "No providers enabled.")
                }
            } else {
                VStack(spacing: 7) {
                    ForEach(Array(summaries.enumerated()), id: \.element.id) { index, summary in
                        constellationProviderRow(summary, index: index)
                            .padding(.leading, index.isMultiple(of: 2) ? 0 : 24)
                            .padding(.trailing, index.isMultiple(of: 2) ? 24 : 0)
                    }
                }
            }

            HStack(alignment: .top, spacing: 9) {
                constellationRenewalPanel
                constellationHistoryPanel
            }
        }
    }

    private var constellationCore: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                .frame(width: 86, height: 86)

            Circle()
                .trim(from: 0.05, to: 0.58)
                .stroke(
                    AngularGradient(
                        colors: [appearance.accentColor, .cyan, appearance.accentColor],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-35))
                .frame(width: 73, height: 73)
                .shadow(color: appearance.accentColor.opacity(0.55), radius: 8)

            Circle()
                .stroke(appearance.accentColor.opacity(0.20), style: StrokeStyle(lineWidth: 1, dash: [2, 5]))
                .frame(width: 55, height: 55)
                .rotationEffect(.degrees(20))

            Circle()
                .fill(
                    RadialGradient(
                        colors: [appearance.accentColor.opacity(0.42), appearance.accentColor.opacity(0.04)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 22
                    )
                )
                .frame(width: 42, height: 42)

            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)

            Circle()
                .fill(Color.cyan)
                .frame(width: 6, height: 6)
                .shadow(color: .cyan, radius: 5)
                .offset(x: 37, y: -15)

            Circle()
                .fill(appearance.accentColor)
                .frame(width: 5, height: 5)
                .shadow(color: appearance.accentColor, radius: 5)
                .offset(x: -29, y: 30)
        }
        .frame(width: 92, height: 92)
    }

    private func constellationProviderRow(_ summary: ProviderUsageSummary, index: Int) -> some View {
        let tint = severityColor(summary.severity)
        let percent = min(max(summary.percentUsed ?? 0, 0), 100)
        return Button {
            onSelectTab(summary.tab)
        } label: {
            HStack(spacing: 11) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.14))
                        .frame(width: 34, height: 34)
                    Circle()
                        .trim(from: 0, to: max(0.04, percent / 100))
                        .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 31, height: 31)
                    Image(systemName: providerIcon(summary.tab.systemImage, hidesProviderNames: hidesProviderNames))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(tint)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(String(format: "%02d", index + 1))
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundStyle(appearance.accentColor)
                        Text(providerName(summary.tab.displayName, privateName: summary.tab.privateName, hidesProviderNames: hidesProviderNames).uppercased())
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(0.8)
                            .foregroundStyle(Color.white.opacity(0.82))
                    }
                    Text(overviewSupportText(for: summary))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(overviewSupportColor(for: summary))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(0..<12, id: \.self) { segment in
                        Capsule()
                            .fill(Double(segment) < percent / (100.0 / 12.0) ? tint : Color.white.opacity(0.07))
                            .frame(width: 3, height: segment.isMultiple(of: 3) ? 14 : 8)
                    }
                }
                .frame(height: 14, alignment: .bottom)

                Text(providerSafeMessage(summary.detail, hidesProviderNames: hidesProviderNames))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(summary.severity == .unavailable ? Color.white.opacity(0.42) : .white)
                    .frame(minWidth: 92, alignment: .trailing)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [tint.opacity(0.10), Color.white.opacity(0.022)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: ConstellationPanelShape(cornerRadius: 16, cut: 14)
            )
            .overlay(
                ConstellationPanelShape(cornerRadius: 16, cut: 14)
                    .stroke(tint.opacity(0.22), lineWidth: 1)
            )
            .overlay(alignment: index.isMultiple(of: 2) ? .leading : .trailing) {
                Circle()
                    .fill(tint)
                    .frame(width: 5, height: 5)
                    .shadow(color: tint, radius: 5)
                    .offset(x: index.isMultiple(of: 2) ? -2 : 2)
            }
        }
        .buttonStyle(.plain)
    }

    private var constellationRenewalPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            constellationPanelTitle("INCOMING WINDOWS", icon: "calendar")
            if billingExpiries.isEmpty {
                Text("No enabled providers")
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.38))
            } else {
                ForEach(billingExpiries.prefix(4)) { entry in
                    billingExpiryCell(entry)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            Color.white.opacity(0.028),
            in: ConstellationPanelShape(cornerRadius: 16, cut: 13)
        )
        .overlay(
            ConstellationPanelShape(cornerRadius: 16, cut: 13)
                .stroke(appearance.accentColor.opacity(0.18), lineWidth: 1)
        )
    }

    private var constellationHistoryPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            constellationPanelTitle("ORBIT MEMORY", icon: "clock.arrow.circlepath")
            if exhaustionSummaries.isEmpty {
                Text("No exhausted cycles yet")
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.38))
            } else {
                ForEach(exhaustionSummaries.prefix(3)) { entry in
                    exhaustionSpeedRow(entry)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            Color.white.opacity(0.028),
            in: ConstellationPanelShape(cornerRadius: 16, cut: 13)
        )
        .overlay(
            ConstellationPanelShape(cornerRadius: 16, cut: 13)
                .stroke(Color.cyan.opacity(0.13), lineWidth: 1)
        )
    }

    private func constellationPanelTitle(_ title: String, icon: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(appearance.accentColor)
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundStyle(Color.white.opacity(0.48))
            Spacer()
            Circle()
                .fill(Color.cyan.opacity(0.7))
                .frame(width: 3, height: 3)
        }
    }

    private var constellationAverageUsage: Double? {
        let values = summaries.compactMap(\.percentUsed)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private var terminalOverviewHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("SYSTEM OVERVIEW")
                .font(.system(size: 17, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(red: 0.76, green: 1, blue: 0.79))
            Spacer()
            Text("STATUS: \(overviewDetail.uppercased())")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.green)
        }
    }

    private func terminalProviderRow(_ summary: ProviderUsageSummary) -> some View {
        Button {
            onSelectTab(summary.tab)
        } label: {
            HStack(spacing: 10) {
                Text(terminalProviderIndex(summary.tab))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(providerName(summary.tab.displayName, privateName: summary.tab.privateName, hidesProviderNames: hidesProviderNames).uppercased())
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(red: 0.76, green: 1, blue: 0.79))
                    Text(overviewSupportText(for: summary).uppercased())
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Color.green.opacity(0.58))
                        .lineLimit(1)
                }
                Spacer()
                Text(providerSafeMessage(summary.detail, hidesProviderNames: hidesProviderNames).uppercased())
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(severityColor(summary.severity))
                    .monospacedDigit()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(Color.green.opacity(0.035))
            .overlay(Rectangle().stroke(Color.green.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var terminalBillingGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
            ForEach(billingExpiries) { entry in
                billingExpiryCell(entry)
                    .padding(7)
                    .background(Color.black.opacity(0.24))
                    .overlay(Rectangle().stroke(Color.green.opacity(0.16), lineWidth: 1))
            }
        }
    }

    private func terminalProviderIndex(_ tab: ProviderTab) -> String {
        switch tab {
        case .codex: return "01"
        case .cursor: return "02"
        case .devin: return "03"
        case .openCodeGo: return "04"
        case .overview, .settings: return "00"
        }
    }

    private func terminalRule(_ label: String) -> some View {
        HStack(spacing: 8) {
            Text("// \(label)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.green.opacity(0.72))
            Rectangle().fill(Color.green.opacity(0.24)).frame(height: 1)
        }
    }

    private var overviewDetail: String {
        let criticalCount = summaries.filter { $0.severity == .critical }.count
        if criticalCount > 0 {
            return "\(criticalCount) critical"
        }

        let warningCount = summaries.filter { $0.severity == .warning }.count
        if warningCount > 0 {
            return "\(warningCount) warning"
        }

        let unavailableCount = summaries.filter { $0.severity == .unavailable }.count
        if unavailableCount > 0 {
            return "\(unavailableCount) unavailable"
        }

        return summaries.isEmpty ? "Configure providers" : "All clear"
    }

    private func overviewRow(_ summary: ProviderUsageSummary) -> some View {
        Button {
            onSelectTab(summary.tab)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: providerIcon(summary.tab.systemImage, hidesProviderNames: hidesProviderNames))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(severityColor(summary.severity))
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(severityColor(summary.severity).opacity(0.12)))

                VStack(alignment: .leading, spacing: 1) {
                    Text(providerName(summary.tab.displayName, privateName: summary.tab.privateName, hidesProviderNames: hidesProviderNames))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(overviewSupportText(for: summary))
                        .font(.caption2)
                        .foregroundStyle(overviewSupportColor(for: summary))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(providerSafeMessage(summary.detail, hidesProviderNames: hidesProviderNames))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(summary.severity == .unavailable ? .secondary : .primary)
                    Text(summary.secondaryDetail.map { providerSafeMessage($0, hidesProviderNames: hidesProviderNames) } ?? "—")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func overviewSupportText(for summary: ProviderUsageSummary) -> String {
        let status: String
        if let projection = paceProjections[summary.tab] {
            status = projection.summaryText
        } else if collectingPaceData.contains(summary.tab) {
            status = "Collecting pace data"
        } else {
            status = ""
        }
        let detail = providerSafeMessage(summary.subdetail, hidesProviderNames: hidesProviderNames)
        return status.isEmpty ? detail : "\(detail) · \(status)"
    }

    private func overviewSupportColor(for summary: ProviderUsageSummary) -> Color {
        if let projection = paceProjections[summary.tab], projection.willExhaustBeforeReset {
            return .orange
        }
        return collectingPaceData.contains(summary.tab) ? Color.secondary.opacity(0.65) : .secondary
    }

    private var exhaustionSpeedSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Exhaustion speed")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if exhaustionSummaries.isEmpty {
                StatusLine(icon: "clock", color: .secondary, text: "No exhausted cycles yet")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(exhaustionSummaries.enumerated()), id: \.element.id) { index, entry in
                        exhaustionSpeedRow(entry)
                        if index < exhaustionSummaries.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func exhaustionSpeedRow(_ entry: ExhaustionSpeedSummary) -> some View {
        HStack(spacing: 8) {
            Image(systemName: providerIcon(entry.tab.systemImage, hidesProviderNames: hidesProviderNames))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.secondary.opacity(0.10)))

            VStack(alignment: .leading, spacing: 1) {
                Text(providerName(entry.tab.displayName, privateName: entry.tab.privateName, hidesProviderNames: hidesProviderNames))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(providerSafeMessage(entry.quotaLabel, hidesProviderNames: hidesProviderNames))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 1) {
                Text(providerSafeMessage(entry.averageText, hidesProviderNames: hidesProviderNames))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Text("\(entry.cycleCount) cycle\(entry.cycleCount == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private var billingExpirySection: some View {
        VStack(alignment: .leading, spacing: 5) {
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
                columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                spacing: 2
            ) {
                if billingExpiries.isEmpty {
                    Text("No enabled providers")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(billingExpiries) { entry in
                        billingExpiryCell(entry)
                    }
                }
            }
        }
    }

    private func billingExpiryCell(_ entry: BillingExpiry) -> some View {
        let primaryText: String = entry.date.map { UsageFormatting.resetText(date: $0, now: now) } ?? entry.amountText ?? "—"
        let secondaryText: String = entry.date.map { UsageFormatting.relativeDayText(date: $0, now: now) } ?? entry.detailText ?? "No billing"
        let primaryColor: Color = entry.date == nil && entry.amountText == nil ? .secondary : (entry.date == nil ? .primary : expiryColor(entry.urgency))
        return HStack(spacing: 6) {
            Image(systemName: providerIcon(entry.tab.systemImage, hidesProviderNames: hidesProviderNames))
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(expiryColor(entry.urgency))
                .frame(width: 12)
            VStack(alignment: .leading, spacing: 0) {
                Text(providerShortName(entry.tab, hidesProviderNames: hidesProviderNames))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(entry.label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 2)
            VStack(alignment: .trailing, spacing: 0) {
                Text(primaryText)
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(primaryColor)
                    .lineLimit(1)
                Text(secondaryText)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var billingSummaryDetail: String {
        let expiring = billingExpiries.filter { $0.urgency == .expired || $0.urgency == .soon }.count
        if expiring > 0 { return "\(expiring) expiring soon" }
        let warn = billingExpiries.filter { $0.urgency == .warning }.count
        if warn > 0 { return "\(warn) within 2w" }
        let healthy = billingExpiries.filter { $0.urgency == .healthy }.count
        if healthy > 0 { return "Up to date" }
        return "—"
    }
}
