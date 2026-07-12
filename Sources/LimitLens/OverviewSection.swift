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

    @ViewBuilder
    var body: some View {
        switch appearance {
        case .classic:
            classicOverview
        case .studio:
            studioOverview
        case .terminal:
            terminalOverview
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
            .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(severityColor(summary.severity).opacity(0.13), lineWidth: 1)
            )
            .shadow(color: Color.indigo.opacity(0.07), radius: 8, y: 4)
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
        .background(.white, in: RoundedRectangle(cornerRadius: 14))
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
        .background(.white, in: RoundedRectangle(cornerRadius: 14))
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
