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

    var body: some View {
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
